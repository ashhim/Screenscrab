import 'package:screenscrab_shared/screenscrab_shared.dart';
import 'package:test/test.dart';

void main() {
  group('Tailnet runtime status parsing', () {
    test('parses identity, login URL, and discovered peers', () {
      final TailnetRuntimeStatus status = TailnetRuntimeStatus.fromJson(
        <String, dynamic>{
          'mode': 'signed_in',
          'loginUrl': 'https://tailscale.com/login',
          'identity': <String, dynamic>{
            'accountEmail': 'demo@example.com',
            'tailnetName': 'work',
            'deviceName': 'desktop',
            'deviceId': 'abc123',
            'tailscaleIp': '100.64.0.10',
            'signedIn': true,
          },
          'peers': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'phone',
              'address': '100.64.0.11',
              'online': true,
              'latencyMs': 21,
              'platform': 'android',
            },
          ],
        },
      );

      expect(status.mode, 'signed_in');
      expect(status.loginUrl, 'https://tailscale.com/login');
      expect(status.identity.deviceName, 'desktop');
      expect(status.identity.signedIn, isTrue);
      expect(status.peers, hasLength(1));
      expect(status.peers.single.name, 'phone');
      expect(status.peers.single.online, isTrue);
    });
  });
}
