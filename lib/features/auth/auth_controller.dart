import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/settings.dart';
import '../../core/td_client.dart';

const appVersion = '0.1.0';

/// Follows updateAuthorizationState and answers the parts that need no user
/// input (TDLib parameters).
class AuthController extends ChangeNotifier {
  AuthController(this.td, this.settings, this.dataDir) {
    _sub = td.on('updateAuthorizationState').listen((u) {
      state = u['authorization_state'] as TdObject;
      if (stateType == 'authorizationStateWaitTdlibParameters') _sendParameters();
      notifyListeners();
    });
  }

  final TdClient td;
  final AppSettings settings;
  final Directory dataDir;
  late final StreamSubscription<TdObject> _sub;

  TdObject state = const {'@type': 'authorizationStateWaitTdlibParameters'};
  String? error;
  bool sending = false;

  String get stateType => state['@type'] as String;
  bool get isReady => stateType == 'authorizationStateReady';
  bool get isClosed => stateType == 'authorizationStateClosed';

  Future<void> _sendParameters() async {
    try {
      await td.send({
        '@type': 'setTdlibParameters',
        'use_test_dc': false,
        'database_directory': p.join(dataDir.path, 'tdlib', 'db'),
        'files_directory': p.join(dataDir.path, 'tdlib', 'files'),
        'database_encryption_key': '',
        'use_file_database': true,
        'use_chat_info_database': true,
        'use_message_database': true,
        'use_secret_chats': true,
        'api_id': settings.apiId,
        'api_hash': settings.apiHash,
        'system_language_code': 'ru',
        'device_model': 'Phantomgram ${Platform.operatingSystem}',
        'system_version': Platform.operatingSystemVersion,
        'application_version': appVersion,
      });
    } on TdError catch (e) {
      error = 'TDLib не принял параметры: ${e.message}';
      notifyListeners();
    }
  }

  /// Runs an auth step, exposing progress and the Telegram error text.
  Future<void> _step(TdObject request) async {
    sending = true;
    error = null;
    notifyListeners();
    try {
      await td.send(request);
    } on TdError catch (e) {
      error = describeAuthError(e.message);
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> submitPhone(String phone) => _step({
    '@type': 'setAuthenticationPhoneNumber',
    'phone_number': phone.replaceAll(RegExp(r'[\s()\-]'), ''),
    'settings': null,
  });

  Future<void> submitCode(String code) => _step({'@type': 'checkAuthenticationCode', 'code': code.trim()});

  Future<void> submitEmail(String email) =>
      _step({'@type': 'setAuthenticationEmailAddress', 'email_address': email.trim()});

  Future<void> submitEmailCode(String code) => _step({
    '@type': 'checkAuthenticationEmailCode',
    'code': {'@type': 'emailAddressAuthenticationCode', 'code': code.trim()},
  });

  Future<void> submitPassword(String password) => _step({'@type': 'checkAuthenticationPassword', 'password': password});

  Future<void> register(String firstName, String lastName) => _step({
    '@type': 'registerUser',
    'first_name': firstName.trim(),
    'last_name': lastName.trim(),
    'disable_notification': false,
  });

  Future<void> requestQr() => _step({'@type': 'requestQrCodeAuthentication', 'other_user_ids': <int>[]});

  /// Goes back to the phone number screen from any later step.
  Future<void> restart() async {
    await td.send({'@type': 'logOut'}).catchError((Object _) => const <String, dynamic>{});
  }

  Future<void> logOut() => restart();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

String describeAuthError(String message) => switch (message) {
  'PHONE_NUMBER_INVALID' => 'Неверный номер телефона',
  'PHONE_CODE_INVALID' => 'Неверный код',
  'PHONE_CODE_EXPIRED' => 'Код устарел, запросите новый',
  'PASSWORD_HASH_INVALID' => 'Неверный пароль',
  'PHONE_NUMBER_BANNED' => 'Номер заблокирован в Telegram',
  'API_ID_INVALID' => 'Неверный api_id / api_hash — проверьте их в настройках',
  'EMAIL_CODE_INVALID' => 'Неверный код из письма',
  _ when message.startsWith('FLOOD_WAIT') => 'Слишком много попыток, подождите ${message.split('_').last} c',
  _ when message.startsWith('Too Many Requests') => 'Слишком много попыток, попробуйте позже',
  _ => message,
};
