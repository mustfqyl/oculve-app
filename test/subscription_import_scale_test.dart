import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/vpn/profile.dart';

void main() {
  test('large imports preserve distinct servers and the first duplicate name', () {
    for (final count in [2000, 10000]) {
      final documents = List.generate(
        count,
        (index) => {
          'remarks': 'Node $index',
          'outbounds': [
            {
              'protocol': 'vless',
              'settings': {
                'vnext': [
                  {
                    'address': 'example.invalid',
                    'port': 443,
                    'users': [
                      {
                        'id':
                            '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
                      },
                    ],
                  },
                ],
              },
            },
          ],
        },
      );
      final body = jsonEncode([
        ...documents,
        {...documents.first, 'remarks': 'Replacement name'},
      ]);
      expect(utf8.encode(body).length, lessThan(2 * 1024 * 1024));
      final timer = Stopwatch()..start();
      final profiles = VpnProfile.parseSubscription(body);
      timer.stop();
      expect(profiles, hasLength(count));
      expect(profiles.first.name, 'Node 0');
      expect(profiles.last.name, 'Node ${count - 1}');
      expect(profiles.map((profile) => profile.id).toSet(), hasLength(count));
      // A diagnostic benchmark, never a flaky time-based assertion.
      debugPrint(
        'IMPORT count=$count bytes=${utf8.encode(body).length} ms=${timer.elapsedMilliseconds}',
      );
    }
  });
}
