import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenscrab_shared/screenscrab_shared.dart';

import 'android_bridge.dart';

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
  final TextEditingController _hostController = TextEditingController(text: '100.64.10.21');
  final TextEditingController _portController = TextEditingController(text: '4545');
  final TextEditingController _clipboardController = TextEditingController();
  final List<DeviceEndpoint> _hosts = <DeviceEndpoint>[
    DeviceEndpoint(
      deviceId: 'tailnet-win-01',
      name: 'Workstation',
      address: '100.64.10.21',
      mode: AppMode.host,
      lastSeenUtc: DateTime.now().toUtc(),
    ),
  ];

  Timer? _timer;
  ConnectionStateValue _state = ConnectionStateValue.disconnected;
  String _platformVersion = 'unknown';
  String _clipboardText = '';
  String _lastAction = 'Idle';
  bool _audioEnabled = true;
  bool _clipboardSyncEnabled = true;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hostController.dispose();
    _portController.dispose();
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
    });
  }

  Future<void> _connect() async {
    setState(() => _state = ConnectionStateValue.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) {
      return;
    }
    setState(() {
      _state = ConnectionStateValue.connected;
      _lastAction = 'Connected to ${_hostController.text}:${_portController.text}';
    });
  }

  Future<void> _disconnect() async {
    setState(() {
      _state = ConnectionStateValue.disconnected;
      _lastAction = 'Disconnected';
    });
  }

  Future<void> _syncClipboard() async {
    final bool ok = await _bridge.setClipboardText(_clipboardController.text);
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

  Future<void> _sendTouch(Offset localPosition, String action) async {
    await _bridge.touchToMouse(x: localPosition.dx, y: localPosition.dy, action: action);
    if (!mounted) {
      return;
    }
    setState(() => _lastAction = 'Touch $action at ${localPosition.dx.toStringAsFixed(0)}, ${localPosition.dy.toStringAsFixed(0)}');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screenscrab Android'),
        actions: <Widget>[
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
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
                      _StatusPill(label: 'Audio', value: _audioEnabled ? 'enabled' : 'off'),
                      _StatusPill(label: 'Clipboard', value: _clipboardSyncEnabled ? 'enabled' : 'off'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Platform: $_platformVersion'),
                  Text('Last action: $_lastAction'),
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
                  Text('Remote Session', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(labelText: 'Host address'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Port'),
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
              _bridge.sendKeyEvent(
                keyCode: event.logicalKey.keyId,
                down: event is KeyDownEvent,
              );
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              onPanDown: (DragDownDetails details) => _sendTouch(details.localPosition, 'down'),
              onPanUpdate: (DragUpdateDetails details) => _sendTouch(details.localPosition, 'move'),
              onTapUp: (TapUpDetails details) => _sendTouch(details.localPosition, 'tap'),
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[theme.colorScheme.primaryContainer, theme.colorScheme.surfaceContainerHighest],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: const Center(
                  child: Text(
                    'Remote screen surface\n(native decoder hookup pending)',
                    textAlign: TextAlign.center,
                  ),
                ),
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
                    decoration: const InputDecoration(labelText: 'Clipboard text'),
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
                  Text('Discovered hosts', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  for (final DeviceEndpoint device in _hosts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.computer),
                      title: Text(device.name),
                      subtitle: Text(device.address),
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
                  onChanged: (bool value) => setState(() => _clipboardSyncEnabled = value),
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
