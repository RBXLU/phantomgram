// Talks to a real libtdjson. Skipped unless TDJSON_PATH points at one:
//   TDJSON_PATH=packages/tdjson_native/prebuilt/linux/libtdjson.so flutter test test/tdlib_smoke_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phantomgram/core/td_client.dart';

void main() {
  final lib = Platform.environment['TDJSON_PATH'];

  test(
    'client starts, accepts parameters and asks for a phone number',
    () async {
      final td = await TdClient.start(logVerbosity: 0);
      final dir = await Directory.systemTemp.createTemp('tdlib_smoke');
      final states = <String>[];
      final waitingForPhone = td
          .on('updateAuthorizationState')
          .map((u) => (u['authorization_state'] as Map)['@type'] as String)
          .map((s) {
            states.add(s);
            if (s == 'authorizationStateWaitTdlibParameters') {
              td.post({
                '@type': 'setTdlibParameters',
                'database_directory': '${dir.path}/db',
                'files_directory': '${dir.path}/files',
                'database_encryption_key': '',
                'use_message_database': true,
                'api_id': 1, // dummy: the test never logs in
                'api_hash': '00000000000000000000000000000000',
                'system_language_code': 'ru',
                'device_model': 'smoke-test',
                'system_version': 'linux',
                'application_version': '0.1.0',
              });
            }
            return s;
          })
          .firstWhere((s) => s == 'authorizationStateWaitPhoneNumber');
      await waitingForPhone.timeout(const Duration(seconds: 30));
      expect(states.first, 'authorizationStateWaitTdlibParameters');

      final version = await td.send({'@type': 'getOption', 'name': 'version'});
      expect(version['value'], isA<Map>());

      // Errors come back as TdError, matched to the right request.
      await expectLater(td.send({'@type': 'checkAuthenticationCode', 'code': '1'}), throwsA(isA<TdError>()));

      // pingProxy must fail cleanly for an unreachable proxy.
      await expectLater(
        td.send({
          '@type': 'pingProxy',
          'proxy': {
            '@type': 'proxy',
            'server': '127.0.0.1',
            'port': 9,
            'type': {'@type': 'proxyTypeMtproto', 'secret': '0123456789abcdef0123456789abcdef'},
          },
        }, timeout: const Duration(seconds: 20)),
        throwsA(anything),
      );

      await td.close();
      await dir.delete(recursive: true);
    },
    skip: lib == null ? 'TDJSON_PATH is not set' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
