import 'package:flutter/cupertino.dart';

import '../../core/settings.dart';
import '../../ui/ios_list.dart';
import '../../ui/ios_page.dart';
import '../../ui/look.dart';
import 'splash_screen.dart';

/// Every Telegram client needs its own api_id/api_hash from my.telegram.org.
class ApiCredentialsScreen extends StatefulWidget {
  const ApiCredentialsScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<ApiCredentialsScreen> createState() => _ApiCredentialsScreenState();
}

class _ApiCredentialsScreenState extends State<ApiCredentialsScreen> {
  late final _id = TextEditingController(text: widget.settings.apiId?.toString() ?? '');
  late final _hash = TextEditingController(text: widget.settings.apiHash ?? '');
  String? _error;

  void _save() {
    final id = int.tryParse(_id.text.trim());
    final hash = _hash.text.trim();
    if (id == null || id <= 0) {
      setState(() => _error = 'api_id — это число');
      return;
    }
    if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(hash)) {
      setState(() => _error = 'api_hash — 32 символа из 0-9 и a-f');
      return;
    }
    widget.settings.update((s) {
      s.apiId = id;
      s.apiHash = hash.toLowerCase();
    });
  }

  @override
  void dispose() {
    _id.dispose();
    _hash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    return IosPage(
      title: 'Phantomgram',
      showBack: false,
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const AppIcon(),
                  const SizedBox(height: 20),
                  Text(
                    'Добро пожаловать',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: look.label),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 8, 32, 12),
                    child: Text(
                      'Для подключения к Telegram нужны ключи приложения. Они хранятся только на этом устройстве.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: look.secondaryLabel),
                    ),
                  ),
                  IosSection(
                    dividerInset: 16,
                    footer:
                        'my.telegram.org → API development tools → создайте приложение и скопируйте '
                        'App api_id и App api_hash.',
                    children: [
                      SectionTextField(controller: _id, placeholder: 'api_id', keyboardType: TextInputType.number),
                      SectionTextField(controller: _hash, placeholder: 'api_hash', onSubmitted: (_) => _save()),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: const TextStyle(color: LookData.destructive, fontSize: 15)),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: IosPrimaryButton(label: 'Продолжить', onPressed: _save),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
