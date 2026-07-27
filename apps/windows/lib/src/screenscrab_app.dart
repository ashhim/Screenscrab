import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screenscrab_shared/screenscrab_shared.dart';

import 'engine_bridge.dart';

class ScreenscrabWindowsApp extends StatelessWidget {
  const ScreenscrabWindowsApp({super.key, this.enableDiagnostics = true});

  final bool enableDiagnostics;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Screenscrab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: WindowsHomePage(enableDiagnostics: enableDiagnostics),
    );
  }
}

class WindowsHomePage extends StatefulWidget {
  const WindowsHomePage({super.key, this.enableDiagnostics = true});

  final bool enableDiagnostics;

  @override
  State<WindowsHomePage> createState() => _WindowsHomePageState();
}

class _WindowsHomePageState extends State<WindowsHomePage> {
  final ScreenscrabEngineBridge _engine = ScreenscrabEngineBridge();
  final TextEditingController _deviceNameController = TextEditingController(
    text: 'Screenscrab Host',
  );
  final List<DeviceEndpoint> _devices = <DeviceEndpoint>[];
  final List<NetworkPeer> _runtimePeers = <NetworkPeer>[];

  Timer? _pollTimer;
  ConnectionStateValue _connectionState = ConnectionStateValue.disconnected;
  EngineRuntimeStatus _status = const EngineRuntimeStatus(
    apiVersion: 1,
    protocolVersion: 1,
    mode: 'stopped',
    transportState: 'offline',
    engineLoaded: false,
    sessionActive: false,
    tailscaleReachable: false,
    captureActive: false,
    inputEnabled: false,
    clipboardEnabled: false,
    audioEnabled: false,
    monitorIndex: 0,
    port: 4545,
    framesSent: 0,
    endpoint: '',
    encoder: 'none',
    lastError: 0,
    lastErrorMessage: '',
  );
  String _engineVersion = 'unknown';
  int _apiVersion = 0;
  int _protocolVersion = 0;
  EngineCapabilities? _capabilities;
  NetworkRuntimeStatus _tailnetStatus = const NetworkRuntimeStatus(
    mode: 'signed_out',
    state: 'offline',
    connectionState: 'disconnected',
    loginUrl: '',
    identity: NetworkIdentity(deviceName: 'Screenscrab Host'),
    peers: <NetworkPeer>[],
    lastError: '',
  );
  String _diagnosticMessage = 'Starting diagnostics...';
  bool _tailscaleCommandPresent = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.enableDiagnostics) {
      _bootstrap();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _refreshDiagnostics(),
      );
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _engine.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _engine.initialize();
    await _refreshDiagnostics();
  }

  Future<void> _refreshDiagnostics() async {
    final EngineRuntimeStatus? status = _engine.currentStatus();
    final NetworkRuntimeStatus? runtimeStatus = _engine.runtimeStatus();
    final String version = _engine.version ?? 'not-loaded';
    final int apiVersion = _engine.apiVersion;
    final int protocolVersion = _engine.protocolVersion;
    final EngineCapabilities? capabilities = _engine.capabilities;
    final String message = _engine.lastErrorMessage ?? 'ok';
    bool tailscalePresent = false;

    try {
      final ProcessResult result = await Process.run('tailscale', <String>[
        'status',
        '--json',
      ]);
      tailscalePresent = result.exitCode == 0;
    } on ProcessException {
      tailscalePresent = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (status != null) {
        _status = status;
        _connectionState =
            status.sessionActive
                ? ConnectionStateValue.connected
                : ConnectionStateValue.disconnected;
      }
      _engineVersion = version;
      _apiVersion = apiVersion;
      _protocolVersion = protocolVersion;
      _capabilities = capabilities;
      _diagnosticMessage = message;
      _tailscaleCommandPresent = tailscalePresent;
      if (runtimeStatus != null) {
        _runtimePeers
          ..clear()
          ..addAll(runtimeStatus.peers);
        _tailnetStatus = runtimeStatus;
      } else {
        _tailnetStatus = NetworkRuntimeStatus(
          mode:
              _status.sessionActive || _status.tailscaleReachable
                  ? 'signed_in'
                  : (_status.lastErrorMessage.isEmpty
                      ? 'signed_out'
                      : 'signing_in'),
          state:
              _status.sessionActive || _status.tailscaleReachable
                  ? 'signed_in'
                  : (_status.lastErrorMessage.isEmpty
                      ? 'signed_out'
                      : 'signing_in'),
          connectionState:
              _status.sessionActive || _status.tailscaleReachable
                  ? 'connected'
                  : (_status.lastErrorMessage.isEmpty
                      ? 'disconnected'
                      : 'connecting'),
          loginUrl:
              _status.endpoint.isEmpty ? '' : 'tailscale://${_status.endpoint}',
          identity: NetworkIdentity(
            deviceName:
                _deviceNameController.text.trim().isEmpty
                    ? 'Screenscrab Host'
                    : _deviceNameController.text.trim(),
            deviceId: _engineVersion,
            signedIn: _status.sessionActive || _status.tailscaleReachable,
          ),
          peers:
              _runtimePeers.isEmpty
                  ? _devices
                      .map(
                        (DeviceEndpoint device) => NetworkPeer(
                          name: device.name,
                          address: device.address,
                          online: true,
                        ),
                      )
                      .toList(growable: false)
                  : _runtimePeers,
          lastError:
              _status.lastErrorMessage.isEmpty
                  ? _diagnosticMessage
                  : _status.lastErrorMessage,
        );
      }
    });
  }

  Future<void> _startSession() async {
    setState(() => _busy = true);
    try {
      if (!_tailnetStatus.identity.signedIn) {
        await _engine.beginSignIn();
      }
      await _engine.refreshRuntime();
      await _refreshDiagnostics();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _stopSession() async {
    setState(() => _busy = true);
    try {
      await _engine.stop();
      await _refreshDiagnostics();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _connectToPeer(NetworkPeer peer) async {
    setState(() => _busy = true);
    try {
      await _engine.connectPeer(
        peer.name.isEmpty ? peer.address : peer.name,
        4545,
      );
      await _engine.refreshRuntime();
      await _refreshDiagnostics();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screenscrab Windows'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(
                label: Text(_engineVersion),
                avatar: const Icon(Icons.developer_board, size: 18),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth > 1050;
            final Widget leftColumn = _buildControlPanel(theme);
            final Widget rightColumn = _buildStatusPanel(theme);
            return isWide
                ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 3, child: leftColumn),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: rightColumn),
                  ],
                )
                : ListView(
                  children: <Widget>[
                    leftColumn,
                    const SizedBox(height: 16),
                    rightColumn,
                  ],
                );
          },
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Text(
          'Version $_engineVersion | API ${_status.apiVersion} | Wire ${_status.protocolVersion} | Engine ${_status.engineLoaded ? 'loaded' : 'unloaded'} | Transport ${_status.transportState}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildControlPanel(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Session Dashboard', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              'Use the embedded runtime to sign in, review your identity, and connect to discovered peers.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deviceNameController,
              decoration: const InputDecoration(labelText: 'Device name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _busy ? null : _startSession,
                  icon: const Icon(Icons.login),
                  label: Text(
                    _tailnetStatus.identity.signedIn ? 'Refresh' : 'Sign in',
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _stopSession,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Embedded tailnet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    _tailnetStatus.identity.signedIn
                        ? 'Your host is signed in and ready to discover peers.'
                        : 'Sign in to join the embedded tailnet and discover peers.',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _busy ? null : _startSession,
                        icon: const Icon(Icons.login),
                        label: Text(
                          _tailnetStatus.identity.signedIn
                              ? 'Refresh'
                              : 'Sign in',
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _stopSession,
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                      ),
                    ],
                  ),
                  if (_tailnetStatus.loginUrl.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text('Login URL: ${_tailnetStatus.loginUrl}'),
                  ],
                  const SizedBox(height: 8),
                  Text('Identity: ${_tailnetStatus.identity.deviceName}'),
                  Text('Runtime state: ${_tailnetStatus.state}'),
                  Text('Connection state: ${_tailnetStatus.connectionState}'),
                  Text(
                    'Account: ${_tailnetStatus.identity.accountEmail.isEmpty ? 'pending' : _tailnetStatus.identity.accountEmail}',
                  ),
                  Text(
                    'Tailnet: ${_tailnetStatus.identity.tailnetName.isEmpty ? 'not joined' : _tailnetStatus.identity.tailnetName}',
                  ),
                  Text('Peers: ${_tailnetStatus.peers.length}'),
                  if (_tailnetStatus.peers.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    ..._tailnetStatus.peers.map(
                      (NetworkPeer peer) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '${peer.name.isEmpty ? peer.address : peer.name} ${peer.online ? '●' : '○'}',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  _busy ? null : () => _connectToPeer(peer),
                              child: const Text('Connect'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel(ThemeData theme) {
    final Color accent = _status.sessionActive ? Colors.green : Colors.blueGrey;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Engine Status', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _StatusChip(label: 'Loaded', value: _status.engineLoaded),
                _StatusChip(label: 'Session', value: _status.sessionActive),
                _StatusChip(
                  label: 'Tailnet',
                  value: _status.tailscaleReachable || _tailscaleCommandPresent,
                ),
                _StatusChip(label: 'Capture', value: _status.captureActive),
                _StatusChip(label: 'Input', value: _status.inputEnabled),
                _StatusChip(
                  label: 'Clipboard',
                  value: _status.clipboardEnabled,
                ),
                _StatusChip(label: 'Audio', value: _status.audioEnabled),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'API v$_apiVersion | Wire v$_protocolVersion | Encoder ${_status.encoder}',
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: accent,
                child: const Icon(Icons.settings_ethernet),
              ),
              title: Text('Mode: ${_status.mode}'),
              subtitle: Text(
                'Transport ${_status.transportState} | Monitor ${_status.monitorIndex + 1} | Frames ${_status.framesSent}',
              ),
            ),
            Text(
              'Native message: ${_status.lastErrorMessage.isEmpty ? _diagnosticMessage : _status.lastErrorMessage}',
            ),
            Text('UI state: ${_connectionState.name}'),
            Text(
              'Endpoint: ${_status.endpoint.isEmpty ? 'local' : _status.endpoint}',
            ),
            if (_capabilities != null) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _TextChip('Video', _capabilities!.capture),
                  _TextChip('Encode', _capabilities!.encode),
                  _TextChip('Input', _capabilities!.input),
                  _TextChip('Clipboard', _capabilities!.clipboard),
                  _TextChip('Files', _capabilities!.fileTransfer),
                  _TextChip('Audio', _capabilities!.audio),
                  _TextChip('Monitors', _capabilities!.multiMonitor),
                ],
              ),
            ],
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Discovered devices'),
              initiallyExpanded: true,
              children: <Widget>[
                for (final DeviceEndpoint device in _devices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.computer),
                    title: Text(device.name),
                    subtitle: Text('${device.address} | ${device.mode.name}'),
                    trailing: Text(device.lastSeenUtc.toIso8601String()),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.value});

  final String label;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(value ? Icons.check_circle : Icons.cancel, size: 18),
      label: Text('$label: ${value ? 'yes' : 'no'}'),
    );
  }
}

class _TextChip extends StatelessWidget {
  const _TextChip(this.label, this.value);

  final String label;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: ${value ? 'yes' : 'no'}'));
  }
}
