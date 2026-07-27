import 'package:screenscrab_shared/screenscrab_shared.dart';
import 'package:test/test.dart';

void main() {
  group('NetworkRuntimeStatus', () {
    test('parses sign-in and peer discovery payloads', () {
      final NetworkRuntimeStatus status = NetworkRuntimeStatus.fromJson(
        <String, dynamic>{
          'started': true,
          'signedIn': true,
          'accountEmail': 'user@example.com',
          'tailnetName': 'demo.ts.net',
          'deviceName': 'Screenscrab Host',
          'deviceId': 'abc123',
          'tailscaleIp': '100.64.0.10',
          'peerCount': 1,
          'loginUrl': 'https://login.tailscale.com',
          'lastErrorMessage': '',
          'peers': <Map<String, dynamic>>[
            <String, dynamic>{
              'nodeId': 'node-1',
              'name': 'Workstation',
              'address': '100.64.0.11',
              'platform': 'windows',
              'online': true,
              'latencyMs': 12,
              'quality': 99,
            },
          ],
        },
      );

      expect(status.signedIn, isTrue);
      expect(status.tailnetName, 'demo.ts.net');
      expect(status.peers.single.name, 'Workstation');
      expect(status.peers.single.online, isTrue);
    });
  });
}
