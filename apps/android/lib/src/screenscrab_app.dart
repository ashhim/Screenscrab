import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenscrab_shared/screenscrab_shared.dart';

import 'android_bridge.dart';
import 'remote_session_client.dart';

class ScreenscrabAndroidApp extends StatelessWidget {
  const ScreenscrabAndroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Screenscrab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const AndroidHomePage(),
    );
  }
}

class AndroidHomePage extends StatefulWidget {
  const AndroidHomePage({super.key});

  @override
  State<AndroidHomePage> createState() => _AndroidHomePageState();
}

class _AndroidHomePageState extends State<AndroidHomePage> {
  final AndroidScreenscrabBridge _bridge = AndroidScreenscrabBridge();
  late final RemoteSessionClient _client;
  final TextEditingController _clipboardController = TextEditingController();
  final List<DeviceEndpoint> _hosts = <DeviceEndpoint>[];

  Timer? _timer;
  ConnectionStateValue _state = ConnectionStateValue.disconnected;
  String _platformVersion = 'unknown';
  String _clipboardText = '';
  String _lastAction = 'Idle';
  TailnetRuntimeStatus _tailnetStatus = const TailnetRuntimeStatus(
    mode: 'signed_out',
    loginUrl: '',
    identity: TailnetIdentity(deviceName: 'Screenscrab Android'),
    peers: <TailnetPeer>[],
    lastError: '',
  );
  String _lastStatus = 'Disconnected';
  bool _audioEnabled = true;
  bool _clipboardSyncEnabled = true;
  int _framesReceived = 0;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _client = RemoteSessionClient(
      bridge: _bridge,
      onConnectionStateChanged: (ConnectionStateValue state) {
        if (!mounted) {
          return;
        }
        setState(() => _state = state);
      },
      onStatus: (String message) {
        if (!mounted) {
          return;
        }
        setState(() => _lastStatus = message);
      },
      onError: (String message) {
        if (!mounted) {
          return;
        }
        setState(() {
          _lastStatus = message;
          _lastAction = message;
        });
      },
    );
    _bootstrap();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.disconnect();
    _clipboardController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final String version = await _bridge.platformVersion();
    if (!mounted) {
      return;
    }
    setState(() => _platformVersion = version);
    await _refresh();
  }

  Future<void> _refresh() async {
    final String clipboard = await _bridge.readClipboardText();
    if (!mounted) {
      return;
    }
    setState(() {
      _clipboardText = clipboard;
      _clipboardController.text = clipboard;
      _framesReceived = _client.framesReceived;
      _tailnetStatus = TailnetRuntimeStatus(
        mode:
            _state == ConnectionStateValue.connected
                ? 'signed_in'
                : (_state == ConnectionStateValue.connecting
                    ? 'signing_in'
                    : 'signed_out'),
        loginUrl: '',
        identity: TailnetIdentity(
          deviceName: 'Screenscrab Android',
          signedIn: _state == ConnectionStateValue.connected,
        ),
        peers: _hosts
            .map(
              (DeviceEndpoint device) => TailnetPeer(
                name: device.name,
                address: device.address,
                online: true,
              ),
            )
            .toList(growable: false),
        lastError: _lastStatus,
      );
    });
  }

  Future<void> _connect() async {
    await _client.connect(host: 'screenscrab-host.local', port: 4545);
    if (!mounted) {
      return;
    }
    setState(() {
      _lastAction = 'Connecting to discovered host';
      _lastStatus = 'Connection requested';
    });
  }

  Future<void> _disconnect() async {
    await _client.disconnect();
    if (!mounted) {
      return;
    }
    setState(() {
      _state = ConnectionStateValue.disconnected;
      _lastAction = 'Disconnected';
      _lastStatus = 'Disconnected';
    });
  }

  Future<void> _syncClipboard() async {
    final bool ok = await _bridge.setClipboardText(_clipboardController.text);
    if (_clipboardSyncEnabled) {
      await _client.syncClipboard(_clipboardController.text);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _lastAction = ok ? 'Clipboard synced' : 'Clipboard sync failed';
    });
  }

  Future<void> _playAudioProbe() async {
    final bool ok = await _bridge.playAudio();
    if (!mounted) {
      return;
    }
    setState(() {
      _lastAction = ok ? 'Audio path ready' : 'Audio init failed';
    });
  }

  Future<void> _sendTouch(
    Offset localPosition,
    String action,
    Size surfaceSize,
  ) async {
    if (action == 'wheel') {
      await _client.sendWheel(delta: 120);
    } else if (action == 'down') {
      await _client.sendMouseButton(
        localPosition: localPosition,
        surfaceSize: surfaceSize,
        down: true,
        button: 1,
      );
    } else if (action == 'up') {
      await _client.sendMouseButton(
        localPosition: localPosition,
        surfaceSize: surfaceSize,
        down: false,
        button: 1,
      );
    } else {
      await _client.sendMousePosition(localPosition, surfaceSize);
    }
    if (!mounted) {
      return;
    }
    setState(
      () =>
          _lastAction =
              'Touch $action at ${localPosition.dx.toStringAsFixed(0)}, ${localPosition.dy.toStringAsFixed(0)}',
    );
  }

  int _windowsVirtualKey(LogicalKeyboardKey key) {
    final String label = key.keyLabel;
    if (label.length == 1) {
      final int code = label.toUpperCase().codeUnitAt(0);
      if ((code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5A)) {
        return code;
      }
    }
    if (key == LogicalKeyboardKey.enter) return 0x0D;
    if (key == LogicalKeyboardKey.escape) return 0x1B;
    if (key == LogicalKeyboardKey.backspace) return 0x08;
    if (key == LogicalKeyboardKey.tab) return 0x09;
    if (key == LogicalKeyboardKey.space) return 0x20;
    if (key == LogicalKeyboardKey.arrowLeft) return 0x25;
    if (key == LogicalKeyboardKey.arrowUp) return 0x26;
    if (key == LogicalKeyboardKey.arrowRight) return 0x27;
    if (key == LogicalKeyboardKey.arrowDown) return 0x28;
    if (key == LogicalKeyboardKey.delete) return 0x2E;
    if (key == LogicalKeyboardKey.home) return 0x24;
    if (key == LogicalKeyboardKey.end) return 0x23;
    if (key == LogicalKeyboardKey.pageUp) return 0x21;
    if (key == LogicalKeyboardKey.pageDown) return 0x22;
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight)
      return 0x10;
    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight)
      return 0x11;
    if (key == LogicalKeyboardKey.altLeft || key == LogicalKeyboardKey.altRight)
      return 0x12;
    return 0;
  }

  void _sendKeyEvent(KeyEvent event) {
    final int virtualKey = _windowsVirtualKey(event.logicalKey);
    if (virtualKey == 0) {
      return;
    }
    _client.sendKeyEvent(keyCode: virtualKey, down: event is KeyDownEvent);
  }

  Widget _buildRemoteSurface(ThemeData theme) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size surfaceSize = Size(constraints.maxWidth, 280);
        return Listener(
          onPointerSignal: (PointerSignalEvent event) {
            if (event is PointerScrollEvent) {
              _sendTouch(event.localPosition, 'wheel', surfaceSize);
            }
          },
          child: GestureDetector(
            onTapDown:
                (TapDownDetails details) =>
                    _sendTouch(details.localPosition, 'down', surfaceSize),
            onTapUp:
                (TapUpDetails details) =>
                    _sendTouch(details.localPosition, 'up', surfaceSize),
            onPanDown:
                (DragDownDetails details) =>
                    _sendTouch(details.localPosition, 'down', surfaceSize),
            onPanUpdate:
                (DragUpdateDetails details) =>
                    _sendTouch(details.localPosition, 'move', surfaceSize),
            onSecondaryTapDown:
                (TapDownDetails details) =>
                    _sendTouch(details.localPosition, 'down', surfaceSize),
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.surfaceContainerHighest,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    AndroidView(
                      viewType: 'screenscrab/remote_display',
                      creationParamsCodec: StandardMessageCodec(),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.78,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            _state == ConnectionStateValue.connected
                                ? 'Live remote display'
                                : 'Connect to stream the desktop',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screenscrab Android'),
        actions: <Widget>[
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Client status', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _StatusPill(label: 'State', value: _state.name),
                      _StatusPill(
                        label: 'Audio',
                        value: _audioEnabled ? 'enabled' : 'off',
                      ),
                      _StatusPill(
                        label: 'Clipboard',
                        value: _clipboardSyncEnabled ? 'enabled' : 'off',
                      ),
                      _StatusPill(
                        label: 'Frames',
                        value: _framesReceived.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Platform: $_platformVersion'),
                  Text('Last action: $_lastAction'),
                  Text('Status: $_lastStatus'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Embedded tailnet',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _tailnetStatus.identity.signedIn
                        ? 'Signed in and ready to connect to a discovered peer.'
                        : 'Sign in by joining the embedded tailnet and then connect to a peer from the list below.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      FilledButton(
                        onPressed: _connect,
                        child: const Text('Connect'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _disconnect,
                        child: const Text('Disconnect'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Focus(
            focusNode: _keyboardFocusNode,
            autofocus: true,
            onKeyEvent: (FocusNode node, KeyEvent event) {
              _sendKeyEvent(event);
              return KeyEventResult.ignored;
            },
            child: _buildRemoteSurface(theme),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text('Clipboard', style: theme.textTheme.headlineSmall),
                      const Spacer(),
                      IconButton(
                        onPressed: _syncClipboard,
                        icon: const Icon(Icons.sync),
                        tooltip: 'Sync clipboard',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clipboardController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Clipboard text',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Last clipboard from host: $_clipboardText'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Discovered hosts',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (_hosts.isEmpty)
                    Text(
                      'Peers will appear here after the embedded runtime discovers them.',
                    )
                  else
                    for (final DeviceEndpoint device in _hosts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.computer),
                        title: Text(device.name),
                        subtitle: Text(
                          '${device.address} | ${device.mode.name}',
                        ),
                        trailing: FilledButton.tonal(
                          onPressed:
                              () => _client.connect(
                                host: device.address,
                                port: 4545,
                              ),
                          child: const Text('Open'),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: SwitchListTile(
                  value: _audioEnabled,
                  onChanged: (bool value) {
                    setState(() => _audioEnabled = value);
                    if (value) {
                      _playAudioProbe();
                    }
                  },
                  title: const Text('Audio'),
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  value: _clipboardSyncEnabled,
                  onChanged:
                      (bool value) =>
                          setState(() => _clipboardSyncEnabled = value),
                  title: const Text('Clipboard sync'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}
