import 'package:flutter/cupertino.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/services.dart';
import '../../ui/glass.dart';
import '../../ui/ios_list.dart';
import '../../ui/ios_page.dart';
import '../../ui/look.dart';
import '../proxy/proxy_screen.dart';
import 'auth_controller.dart';
import 'splash_screen.dart';

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
        final step = _step(context, auth);
        return IosPage(
          title: '',
          showBack: false,
          actions: [
            GlassButton(
              icon: CupertinoIcons.globe,
              semanticLabel: 'Прокси',
              onPressed: () =>
                  Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => const ProxyScreen())),
            ),
          ],
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Icon(step.icon, size: 64, color: Look.of(context).accent),
                      const SizedBox(height: 16),
                      _Title(step.title, step.subtitle),
                      ...step.body,
                      if (auth.error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                          child: Text(
                            auth.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: LookData.destructive, fontSize: 15),
                          ),
                        ),
                      if (step.action != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: IosPrimaryButton(
                            label: step.action!.$1,
                            loading: auth.sending,
                            onPressed: step.action!.$2,
                          ),
                        ),
                      for (final (label, onPressed) in step.links)
                        CupertinoButton(onPressed: auth.sending ? null : onPressed, child: Text(label)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _fields(List<Widget> fields, {String? footer}) =>
      IosSection(dividerInset: 16, footer: footer, children: fields);

  _Step _step(BuildContext context, AuthController auth) {
    final state = auth.state;
    final back = ('Другой номер', auth.restart);
    switch (auth.stateType) {
      case 'authorizationStateWaitPhoneNumber':
        void submit() => auth.submitPhone(_input.text);
        return _Step(
          icon: CupertinoIcons.paperplane_fill,
          title: 'Вход в Telegram',
          subtitle: 'Введите номер телефона в международном формате',
          body: [
            _fields([
              SectionTextField(
                controller: _input,
                placeholder: '+7 999 123-45-67',
                keyboardType: TextInputType.phone,
                autofocus: true,
                onSubmitted: (_) => submit(),
              ),
            ]),
          ],
          action: ('Получить код', submit),
          links: [('Войти по QR-коду', auth.requestQr)],
        );
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
        return _Step(
          icon: CupertinoIcons.chat_bubble_text_fill,
          title: info?['phone_number'] as String? ?? 'Код',
          subtitle: where,
          body: [
            _fields([
              SectionTextField(
                controller: _input,
                placeholder: 'Код',
                keyboardType: TextInputType.number,
                autofocus: true,
                onSubmitted: (_) => submit(),
              ),
            ]),
          ],
          action: ('Войти', submit),
          links: [back],
        );
      case 'authorizationStateWaitEmailAddress':
        void submit() => auth.submitEmail(_input.text);
        return _Step(
          icon: CupertinoIcons.envelope_fill,
          title: 'Почта для входа',
          subtitle: 'Telegram просит привязать e-mail',
          body: [
            _fields([
              SectionTextField(
                controller: _input,
                placeholder: 'E-mail',
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                onSubmitted: (_) => submit(),
              ),
            ]),
          ],
          action: ('Далее', submit),
          links: [back],
        );
      case 'authorizationStateWaitEmailCode':
        final pattern = (state['code_info'] as Map?)?['email_address_pattern'] as String? ?? '';
        void submit() => auth.submitEmailCode(_input.text);
        return _Step(
          icon: CupertinoIcons.envelope_open_fill,
          title: 'Код из письма',
          subtitle: 'Отправлен на $pattern',
          body: [
            _fields([
              SectionTextField(
                controller: _input,
                placeholder: 'Код',
                keyboardType: TextInputType.number,
                autofocus: true,
                onSubmitted: (_) => submit(),
              ),
            ]),
          ],
          action: ('Войти', submit),
          links: [back],
        );
      case 'authorizationStateWaitPassword':
        final hint = state['password_hint'] as String? ?? '';
        void submit() => auth.submitPassword(_input.text);
        return _Step(
          icon: CupertinoIcons.lock_fill,
          title: 'Облачный пароль',
          subtitle: hint.isEmpty ? 'Включена двухэтапная проверка' : 'Подсказка: $hint',
          body: [
            _fields([
              SectionTextField(
                controller: _input,
                placeholder: 'Пароль',
                obscure: true,
                autofocus: true,
                onSubmitted: (_) => submit(),
              ),
            ]),
          ],
          action: ('Войти', submit),
          links: [back],
        );
      case 'authorizationStateWaitRegistration':
        void submit() => auth.register(_input.text, _second.text);
        return _Step(
          icon: CupertinoIcons.person_crop_circle_fill_badge_plus,
          title: 'Регистрация',
          subtitle: 'Этот номер ещё не в Telegram',
          body: [
            _fields([
              SectionTextField(controller: _input, placeholder: 'Имя', autofocus: true),
              SectionTextField(
                controller: _second,
                placeholder: 'Фамилия (необязательно)',
                onSubmitted: (_) => submit(),
              ),
            ]),
          ],
          action: ('Создать аккаунт', submit),
          links: [back],
        );
      case 'authorizationStateWaitOtherDeviceConfirmation':
        final link = state['link'] as String? ?? '';
        return _Step(
          icon: CupertinoIcons.qrcode_viewfinder,
          title: 'Вход по QR-коду',
          subtitle: 'Telegram на телефоне → Настройки → Устройства → Подключить устройство',
          body: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(26)),
                child: QrImageView(data: link, size: 220),
              ),
            ),
          ],
          links: [back],
        );
      default:
        return _Step(
          icon: CupertinoIcons.antenna_radiowaves_left_right,
          title: 'Подключение…',
          subtitle: auth.stateType,
        );
    }
  }
}

class _Step {
  _Step({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.body = const [],
    this.action,
    this.links = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> body;
  final (String, VoidCallback)? action;
  final List<(String, VoidCallback)> links;
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: look.label),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: look.secondaryLabel),
          ),
        ],
      ),
    );
  }
}
