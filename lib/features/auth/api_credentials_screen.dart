import 'package:flutter/material.dart';

import '../../core/settings.dart';

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
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Icon(Icons.blur_on, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text('Phantomgram', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              const SelectableText(
                'Для подключения к Telegram нужны ключи приложения.\n'
                '1. Откройте my.telegram.org и войдите.\n'
                '2. API development tools → создайте приложение.\n'
                '3. Скопируйте сюда App api_id и App api_hash.\n\n'
                'Ключи хранятся только на этом устройстве.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _id,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'api_id', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hash,
                decoration: const InputDecoration(labelText: 'api_hash', border: OutlineInputBorder()),
                onSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('Продолжить')),
            ],
          ),
        ),
      ),
    );
  }
}
