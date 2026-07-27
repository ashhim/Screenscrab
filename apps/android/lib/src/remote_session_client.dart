import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:screenscrab_shared/screenscrab_shared.dart';

import 'android_bridge.dart';

class RemoteFrameMetadata {
  const RemoteFrameMetadata({
    required this.monitorIndex,
    required this.width,
    required this.height,
    required this.strideBytes,
    required this.frameId,
  });

  final int monitorIndex;
  final int width;
  final int height;
  final int strideBytes;
  final int frameId;

  factory RemoteFrameMetadata.fromBytes(Uint8List bytes) {
    final ByteData data = ByteData.sublistView(bytes);
    return RemoteFrameMetadata(
      monitorIndex: data.getUint32(0, Endian.little),
      width: data.getUint32(4, Endian.little),
      height: data.getUint32(8, Endian.little),
      strideBytes: data.getUint32(12, Endian.little),
      frameId: data.getUint64(16, Endian.little).toInt(),
    );
  }
}

class RemoteSessionClient {
  RemoteSessionClient({
    required AndroidScreenscrabBridge bridge,
    required void Function(ConnectionStateValue state) onConnectionStateChanged,
    required void Function(String message) onStatus,
    required void Function(String message) onError,
  })  : _bridge = bridge,
        _onConnectionStateChanged = onConnectionStateChanged,
        _onStatus = onStatus,
        _onError = onError;

  final AndroidScreenscrabBridge _bridge;
  final void Function(ConnectionStateValue state) _onConnectionStateChanged;
  final void Function(String message) _onStatus;
  final void Function(String message) _onError;

  Socket? _socket;
  StreamSubscription<List<int>>? _subscription;
  final List<int> _buffer = <int>[];
  RemoteFrameMetadata? _pendingMetadata;
  int _framesReceived = 0;

  int get framesReceived => _framesReceived;
  RemoteFrameMetadata? get pendingMetadata => _pendingMetadata;
  bool get connected => _socket != null;

  Future<void> connect({
    required String host,
    required int port,
  }) async {
    await disconnect();
    _onConnectionStateChanged(ConnectionStateValue.connecting);
    _onStatus('Connecting to $host:$port');
    try {
      final Socket socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      socket.setOption(SocketOption.tcpNoDelay, true);
      _socket = socket;
      _subscription = socket.listen(
        _onData,
        onError: _onSocketError,
        onDone: _onSocketDone,
        cancelOnError: true,
      );
      _sendInitialHandshake();
      _onConnectionStateChanged(ConnectionStateValue.connected);
      _onStatus('Connected to $host:$port');
    } catch (error) {
      _onConnectionStateChanged(ConnectionStateValue.error);
      _onError('Connect failed: $error');
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    _pendingMetadata = null;
    _buffer.clear();
    await _subscription?.cancel();
    _subscription = null;
    _socket?.destroy();
    _socket = null;
    _onConnectionStateChanged(ConnectionStateValue.disconnected);
  }

  Future<void> sendMousePosition(Offset localPosition, Size surfaceSize) async {
    if (_socket == null) {
      return;
    }
    final RemoteFrameMetadata? metadata = _pendingMetadata;
    final int remoteWidth = metadata?.width ?? surfaceSize.width.round().clamp(1, 10000).toInt();
    final int remoteHeight = metadata?.height ?? surfaceSize.height.round().clamp(1, 10000).toInt();
    final int x = surfaceSize.width <= 0
        ? 0
        : (localPosition.dx * remoteWidth / surfaceSize.width).round().clamp(0, remoteWidth - 1);
    final int y = surfaceSize.height <= 0
        ? 0
        : (localPosition.dy * remoteHeight / surfaceSize.height).round().clamp(0, remoteHeight - 1);
    _socket!.add(
      SessionCodec.mouseEvent(x: x, y: y, wheelDelta: 0, buttons: 0, flags: 0).encode(),
    );
  }

  Future<void> sendMouseButton({required Offset localPosition, required Size surfaceSize, required bool down, required int button}) async {
    if (_socket == null) {
      return;
    }
    final RemoteFrameMetadata? metadata = _pendingMetadata;
    final int remoteWidth = metadata?.width ?? surfaceSize.width.round().clamp(1, 10000).toInt();
    final int remoteHeight = metadata?.height ?? surfaceSize.height.round().clamp(1, 10000).toInt();
    final int x = surfaceSize.width <= 0
        ? 0
        : (localPosition.dx * remoteWidth / surfaceSize.width).round().clamp(0, remoteWidth - 1);
    final int y = surfaceSize.height <= 0
        ? 0
        : (localPosition.dy * remoteHeight / surfaceSize.height).round().clamp(0, remoteHeight - 1);
    _socket!.add(
      SessionCodec.mouseEvent(
        x: x,
        y: y,
        wheelDelta: 0,
        buttons: button,
        flags: 0x2 | (down ? 0x1 : 0x0),
      ).encode(),
    );
  }

  Future<void> sendWheel({required int delta}) async {
    if (_socket == null) {
      return;
    }
    _socket!.add(
      SessionCodec.mouseEvent(x: 0, y: 0, wheelDelta: delta, buttons: 0, flags: 0x4).encode(),
    );
  }

  Future<void> sendKeyEvent({required int keyCode, required bool down}) async {
    if (_socket == null) {
      return;
    }
    _socket!.add(SessionCodec.keyEvent(virtualKey: keyCode, scanCode: 0, down: down).encode());
  }

  Future<void> syncClipboard(String text) async {
    if (_socket == null) {
      return;
    }
    _socket!.add(SessionCodec.clipboardText(text).encode());
  }

  void _sendInitialHandshake() {
    final Socket? socket = _socket;
    if (socket == null) {
      return;
    }
    final SessionCapabilities capabilities = const SessionCapabilities(
      video: true,
      audio: true,
      clipboard: true,
      input: true,
      fileTransfer: true,
      multiMonitor: true,
      lockedScreen: true,
    );
    socket.add(
      SessionCodec.hello(
        apiVersion: 1,
        protocolVersion: 1,
        capabilities: capabilities,
      ).encode(),
    );
    socket.add(
      SessionCodec.capabilities(
        host: capabilities,
        client: capabilities,
      ).encode(),
    );
  }

  void _onData(List<int> chunk) {
    _buffer.addAll(chunk);
    while (_buffer.length >= 24) {
      final Uint8List view = Uint8List.fromList(_buffer);
      int packetLength;
      try {
        packetLength = WirePacket.totalLength(view);
      } catch (error) {
        _onError('Wire decode error: $error');
        _buffer.clear();
        return;
      }
      if (_buffer.length < packetLength) {
        return;
      }
      final Uint8List packetBytes = Uint8List.fromList(_buffer.sublist(0, packetLength));
      _buffer.removeRange(0, packetLength);
      final WirePacket packet = WirePacket.decode(packetBytes);
      unawaited(_handlePacket(packet));
    }
  }

  Future<void> _handlePacket(WirePacket packet) async {
    switch (packet.type) {
      case MessageType.hello:
        _onStatus('Host hello received');
        break;
      case MessageType.capabilities:
        _onStatus('Capabilities negotiated');
        break;
      case MessageType.frameMetadata:
        _pendingMetadata = RemoteFrameMetadata.fromBytes(packet.payload);
        break;
      case MessageType.videoFrame:
        final RemoteFrameMetadata? metadata = _pendingMetadata;
        if (metadata == null) {
          return;
        }
        final bool ok = await _bridge.renderFrame(
          packet.payload,
          width: metadata.width,
          height: metadata.height,
          strideBytes: metadata.strideBytes,
        );
        if (ok) {
          _framesReceived += 1;
        }
        break;
      case MessageType.ping:
        if (packet.payload.length >= 8) {
          final int nonce = ByteData.sublistView(packet.payload).getUint64(0, Endian.little).toInt();
          _socket?.add(SessionCodec.pong(nonce).encode());
        }
        break;
      case MessageType.clipboardSync:
        _onStatus('Clipboard sync received');
        break;
      case MessageType.disconnect:
        _onStatus('Disconnected by host');
        await disconnect();
        break;
      case MessageType.sessionStart:
      case MessageType.sessionStop:
      case MessageType.audioFrame:
      case MessageType.inputEvent:
      case MessageType.fileOffer:
      case MessageType.fileChunk:
      case MessageType.deviceList:
      case MessageType.pong:
      case MessageType.error:
        break;
    }
  }

  void _onSocketError(Object error) {
    _onConnectionStateChanged(ConnectionStateValue.error);
    _onError('Socket error: $error');
  }

  Future<void> _onSocketDone() async {
    _onConnectionStateChanged(ConnectionStateValue.disconnected);
    _onStatus('Connection closed');
    await disconnect();
  }
}
