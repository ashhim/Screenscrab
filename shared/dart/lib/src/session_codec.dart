import 'dart:convert';
import 'dart:typed_data';

import 'protocol.dart';

class SessionCapabilities {
  const SessionCapabilities({
    required this.video,
    required this.audio,
    required this.clipboard,
    required this.input,
    required this.fileTransfer,
    required this.multiMonitor,
    required this.lockedScreen,
  });

  final bool video;
  final bool audio;
  final bool clipboard;
  final bool input;
  final bool fileTransfer;
  final bool multiMonitor;
  final bool lockedScreen;

  int toBitmask() {
    int mask = 0;
    if (video) mask |= 1 << 0;
    if (audio) mask |= 1 << 1;
    if (clipboard) mask |= 1 << 2;
    if (input) mask |= 1 << 3;
    if (fileTransfer) mask |= 1 << 4;
    if (multiMonitor) mask |= 1 << 5;
    if (lockedScreen) mask |= 1 << 6;
    return mask;
  }
}

class SessionCodec {
  static WirePacket hello({
    required int apiVersion,
    required int protocolVersion,
    required SessionCapabilities capabilities,
  }) {
    final ByteData payload = ByteData(12);
    payload.setUint32(0, apiVersion, Endian.little);
    payload.setUint32(4, protocolVersion, Endian.little);
    payload.setUint32(8, capabilities.toBitmask(), Endian.little);
    return WirePacket(
      type: MessageType.hello,
      payload: payload.buffer.asUint8List(),
      timestampUtc: DateTime.now().toUtc(),
    );
  }

  static WirePacket capabilities({
    required SessionCapabilities host,
    required SessionCapabilities client,
  }) {
    final ByteData payload = ByteData(8);
    payload.setUint32(0, host.toBitmask(), Endian.little);
    payload.setUint32(4, client.toBitmask(), Endian.little);
    return WirePacket(
      type: MessageType.capabilities,
      payload: payload.buffer.asUint8List(),
      timestampUtc: DateTime.now().toUtc(),
    );
  }

  static WirePacket frameMetadata({
    required int monitorIndex,
    required int width,
    required int height,
    required int strideBytes,
    required int frameId,
  }) {
    final ByteData payload = ByteData(24);
    payload.setUint32(0, monitorIndex, Endian.little);
    payload.setUint32(4, width, Endian.little);
    payload.setUint32(8, height, Endian.little);
    payload.setUint32(12, strideBytes, Endian.little);
    payload.setUint64(16, frameId, Endian.little);
    return WirePacket(
      type: MessageType.frameMetadata,
      payload: payload.buffer.asUint8List(),
      timestampUtc: DateTime.now().toUtc(),
    );
  }

  static WirePacket ping(int nonce) {
    final ByteData payload = ByteData(8);
    payload.setUint64(0, nonce, Endian.little);
    return WirePacket(
      type: MessageType.ping,
      payload: payload.buffer.asUint8List(),
      timestampUtc: DateTime.now().toUtc(),
    );
  }

  static WirePacket pong(int nonce) => ping(nonce).copyWith(type: MessageType.pong);

  static WirePacket mouseEvent({
    required int x,
    required int y,
    required int wheelDelta,
    required int buttons,
    required int flags,
  }) {
    final ByteData payload = ByteData(24);
    payload.setUint32(0, 0, Endian.little);
    payload.setInt32(4, x, Endian.little);
    payload.setInt32(8, y, Endian.little);
    payload.setInt32(12, wheelDelta, Endian.little);
    payload.setUint32(16, buttons, Endian.little);
    payload.setUint32(20, flags, Endian.little);
    return WirePacket(
      type: MessageType.inputEvent,
      payload: payload.buffer.asUint8List(),
      timestampUtc: DateTime.now().toUtc(),
    );
  }

  static WirePacket keyEvent({
    required int virtualKey,
    required int scanCode,
    required bool down,
  }) {
    final ByteData payload = ByteData(16);
    payload.setUint32(0, 1, Endian.little);
    payload.setUint32(4, virtualKey, Endian.little);
    payload.setUint32(8, scanCode, Endian.little);
    payload.setUint32(12, down ? 1 : 0, Endian.little);
    return WirePacket(
      type: MessageType.inputEvent,
      payload: payload.buffer.asUint8List(),
      timestampUtc: DateTime.now().toUtc(),
    );
  }

  static WirePacket clipboardText(String text) {
    final List<int> data = utf8.encode(text);
    final ByteData header = ByteData(4 + data.length);
    header.setUint32(0, 1, Endian.little);
    header.buffer.asUint8List().setAll(4, data);
    return WirePacket(
      type: MessageType.clipboardSync,
      payload: header.buffer.asUint8List(),
      timestampUtc: DateTime.now().toUtc(),
    );
  }

  static WirePacket disconnect({required int reasonCode, required String reason}) {
    final List<int> reasonBytes = utf8.encode(reason);
    final ByteData header = ByteData(8 + reasonBytes.length);
    header.setUint32(0, reasonCode, Endian.little);
    header.setUint32(4, reasonBytes.length, Endian.little);
    header.buffer.asUint8List().setAll(8, reasonBytes);
    return WirePacket(
      type: MessageType.disconnect,
      payload: header.buffer.asUint8List(),
      timestampUtc: DateTime.now().toUtc(),
    );
  }
}

extension on WirePacket {
  WirePacket copyWith({
    MessageType? type,
    Uint8List? payload,
    DateTime? timestampUtc,
    int? flags,
  }) {
    return WirePacket(
      type: type ?? this.type,
      payload: payload ?? this.payload,
      timestampUtc: timestampUtc ?? this.timestampUtc,
      flags: flags ?? this.flags,
    );
  }
}
