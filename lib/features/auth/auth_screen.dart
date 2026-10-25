import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/services.dart';
import '../proxy/proxy_screen.dart';
import 'auth_controller.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _input = TextEditingController();
  final _second = TextEditingController();
  AuthController? _auth;
  String? _lastState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = AppScope.of(context).auth;
    if (auth == _auth) return;
    _auth?.removeListener(_onAuthChanged);
    _auth = auth..addListener(_onAuthChanged);
    _lastState = auth.stateType;
  }

  /// A new step starts with empty fields.
  void _onAuthChanged() {
    if (_lastState == _auth!.stateType) return;
    _lastState = _auth!.stateType;
    _input.clear();
    _second.clear();
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    _input.dispose();
    _second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: 'Прокси',
                icon: const Icon(Icons.vpn_lock_outlined),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProxyScreen())),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  ..._step(context, auth),
                  if (auth.error != null) ...[
                    const SizedBox(height: 12),
                    Text(auth.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  if (auth.sending) ...[const SizedBox(height: 16), const Center(child: CircularProgressIndicator())],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _title(BuildContext context, String title, [String? subtitle]) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
      if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle, textAlign: TextAlign.center)],
      const SizedBox(height: 20),
    ],
  );

  Widget _field(
    String label,
    VoidCallback submit, {
    TextEditingController? controller,
    bool obscure = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller ?? _input,
      obscureText: obscure,
      keyboardType: keyboard,
      autofocus: controller == null,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      onSubmitted: (_) => submit(),
    ),
  );

  List<Widget> _step(BuildContext context, AuthController auth) {
    final state = auth.state;
    Widget button(String label, VoidCallback onPressed) =>
        FilledButton(onPressed: auth.sending ? null : onPressed, child: Text(label));
    Widget back() => TextButton(onPressed: auth.restart, child: const Text('Другой номер'));

    switch (auth.stateType) {
      case 'authorizationStateWaitPhoneNumber':
        void submit() => auth.submitPhone(_input.text);
        return [
          _title(context, 'Вход в Telegram', 'Введите номер телефона в международном формате'),
          _field('+7 999 123-45-67', submit, keyboard: TextInputType.phone),
          button('Получить код', submit),
          TextButton(onPressed: auth.requestQr, child: const Text('Войти по QR-коду')),
        ];
      case 'authorizationStateWaitCode':
        final info = state['code_info'] as Map?;
        final type = (info?['type'] as Map?)?['@type'] as String? ?? '';
        final where = switch (type) {
          'authenticationCodeTypeTelegramMessage' => 'Код отправлен в Telegram на другом устройстве',
          'authenticationCodeTypeSms' => 'Код отправлен по SMS',
          'authenticationCodeTypeCall' => 'Сейчас поступит звонок с кодом',
          'authenticationCodeTypeFragment' => 'Код отправлен через fragment.com',
          _ => 'Введите полученный код',
        };
        void submit() => auth.submitCode(_input.text);
        return [
          _title(context, info?['phone_number'] as String? ?? 'Код', where),
          _field('Код', submit, keyboard: TextInputType.number),
          button('Войти', submit),
          back(),
        ];
      case 'authorizationStateWaitEmailAddress':
        void submit() => auth.submitEmail(_input.text);
        return [
          _title(context, 'Почта для входа', 'Telegram просит привязать e-mail'),
          _field('E-mail', submit, keyboard: TextInputType.emailAddress),
          button('Далее', submit),
          back(),
        ];
      case 'authorizationStateWaitEmailCode':
        final pattern = (state['code_info'] as Map?)?['email_address_pattern'] as String? ?? '';
        void submit() => auth.submitEmailCode(_input.text);
        return [
          _title(context, 'Код из письма', 'Отправлен на $pattern'),
          _field('Код', submit, keyboard: TextInputType.number),
          button('Войти', submit),
          back(),
        ];
      case 'authorizationStateWaitPassword':
        final hint = state['password_hint'] as String? ?? '';
        void submit() => auth.submitPassword(_input.text);
        return [
          _title(context, 'Облачный пароль', hint.isEmpty ? 'Включена двухэтапная проверка' : 'Подсказка: $hint'),
          _field('Пароль', submit, obscure: true),
          button('Войти', submit),
          back(),
        ];
      case 'authorizationStateWaitRegistration':
        void submit() => auth.register(_input.text, _second.text);
        return [
          _title(context, 'Регистрация', 'Этот номер ещё не в Telegram'),
          _field('Имя', submit),
          _field('Фамилия (необязательно)', submit, controller: _second),
          button('Создать аккаунт', submit),
          back(),
        ];
      case 'authorizationStateWaitOtherDeviceConfirmation':
        final link = state['link'] as String? ?? '';
        return [
          _title(context, 'Вход по QR-коду', 'Telegram на телефоне → Настройки → Устройства → Подключить устройство'),
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(data: link, size: 240),
            ),
          ),
          const SizedBox(height: 12),
          back(),
        ];
      default:
        return [_title(context, 'Подключение…', auth.stateType)];
    }
  }
}
