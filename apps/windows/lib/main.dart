import 'package:flutter/material.dart';
import 'package:screenscrab_shared/screenscrab_shared.dart';

void main() {
  runApp(const ScreenscrabWindowsApp());
}

class ScreenscrabWindowsApp extends StatelessWidget {
  const ScreenscrabWindowsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Screenscrab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: const WindowsHomePage(),
    );
  }
}

class WindowsHomePage extends StatefulWidget {
  const WindowsHomePage({super.key});

  @override
  State<WindowsHomePage> createState() => _WindowsHomePageState();
}

class _WindowsHomePageState extends State<WindowsHomePage> {
  AppMode _mode = AppMode.host;
  ConnectionStateValue _state = ConnectionStateValue.disconnected;
  int _monitorIndex = 0;
  bool _audioEnabled = true;
  bool _clipboardEnabled = true;
  final List<DeviceEndpoint> _devices = <DeviceEndpoint>[
    DeviceEndpoint(
      deviceId: 'tailnet-host-01',
      name: 'Workstation',
      address: '100.64.10.21',
      mode: AppMode.host,
      lastSeenUtc: DateTime.now().toUtc(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screenscrab Windows'),
        actions: <Widget>[
          SegmentedButton<AppMode>(
            segments: const <ButtonSegment<AppMode>>[
              ButtonSegment<AppMode>(value: AppMode.host, label: Text('Host')),
              ButtonSegment<AppMode>(value: AppMode.client, label: Text('Client')),
            ],
            selected: <AppMode>{_mode},
            onSelectionChanged: (Set<AppMode> value) {
              setState(() => _mode = value.first);
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth > 960;
            final Widget overview = _OverviewCard(
              mode: _mode,
              state: _state,
              audioEnabled: _audioEnabled,
              clipboardEnabled: _clipboardEnabled,
              monitorIndex: _monitorIndex,
              onStart: () => setState(() => _state = ConnectionStateValue.connected),
              onStop: () => setState(() => _state = ConnectionStateValue.disconnected),
              onToggleAudio: (bool value) => setState(() => _audioEnabled = value),
              onToggleClipboard: (bool value) => setState(() => _clipboardEnabled = value),
              onMonitorChanged: (int value) => setState(() => _monitorIndex = value),
            );
            final Widget devices = _DeviceList(devices: _devices);
            return isWide
                ? Row(
                    children: <Widget>[
                      Expanded(flex: 3, child: overview),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: devices),
                    ],
                  )
                : ListView(
                    children: <Widget>[
                      overview,
                      const SizedBox(height: 16),
                      devices,
                    ],
                  );
          },
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: const Text(
          'Tailscale-only networking, native engine via FFI, no backend service.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.mode,
    required this.state,
    required this.audioEnabled,
    required this.clipboardEnabled,
    required this.monitorIndex,
    required this.onStart,
    required this.onStop,
    required this.onToggleAudio,
    required this.onToggleClipboard,
    required this.onMonitorChanged,
  });

  final AppMode mode;
  final ConnectionStateValue state;
  final bool audioEnabled;
  final bool clipboardEnabled;
  final int monitorIndex;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final ValueChanged<bool> onToggleAudio;
  final ValueChanged<bool> onToggleClipboard;
  final ValueChanged<int> onMonitorChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Session overview', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _StatChip(label: 'Mode', value: mode.name),
                _StatChip(label: 'State', value: state.name),
                _StatChip(label: 'Monitor', value: 'Monitor ${monitorIndex + 1}'),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                FilledButton(onPressed: onStart, child: const Text('Start Session')),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: onStop, child: const Text('Stop Session')),
              ],
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              value: audioEnabled,
              onChanged: onToggleAudio,
              title: const Text('Audio streaming'),
            ),
            SwitchListTile(
              value: clipboardEnabled,
              onChanged: onToggleClipboard,
              title: const Text('Clipboard sync'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: monitorIndex,
              decoration: const InputDecoration(labelText: 'Selected monitor'),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 0, child: Text('Monitor 1')),
                DropdownMenuItem<int>(value: 1, child: Text('Monitor 2')),
                DropdownMenuItem<int>(value: 2, child: Text('Monitor 3')),
              ],
              onChanged: (int? value) {
                if (value != null) {
                  onMonitorChanged(value);
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Implementation status: UI shell, shared protocol, and native engine scaffold are wired. Capture, codec, audio, and input backends are isolated for native implementation.',
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices});

  final List<DeviceEndpoint> devices;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Tailnet devices', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            for (final DeviceEndpoint device in devices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.computer),
                title: Text(device.name),
                subtitle: Text('${device.address} • ${device.mode.name}'),
                trailing: Text(device.lastSeenUtc.toIso8601String()),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}
