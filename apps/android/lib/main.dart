import 'package:flutter/material.dart';
import 'package:screenscrab_shared/screenscrab_shared.dart';

void main() {
  runApp(const ScreenscrabAndroidApp());
}

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
  ConnectionStateValue _state = ConnectionStateValue.disconnected;
  final List<DeviceEndpoint> _devices = <DeviceEndpoint>[
    DeviceEndpoint(
      deviceId: 'tailnet-win-01',
      name: 'Workstation',
      address: '100.64.10.21',
      mode: AppMode.host,
      lastSeenUtc: DateTime.now().toUtc(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screenscrab Android'),
        actions: <Widget>[
          IconButton(
            onPressed: () => setState(() => _state = ConnectionStateValue.connecting),
            icon: const Icon(Icons.link),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Client status', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text('Connection: ${_state.name}'),
                  const SizedBox(height: 8),
                  const Text('Touch is translated to mouse input through the native bridge.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(() => _state = ConnectionStateValue.connected),
                    child: const Text('Connect to selected host'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Tailnet hosts', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  for (final DeviceEndpoint device in _devices)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.computer),
                      title: Text(device.name),
                      subtitle: Text(device.address),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Android client surface: screen decoding, playback, touch translation, keyboard input, clipboard sync, and file transfer hooks are intentionally isolated for native implementation.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
