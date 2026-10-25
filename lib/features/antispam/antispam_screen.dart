import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/td_text.dart';
import 'spam_rules.dart';

class AntiSpamScreen extends StatelessWidget {
  const AntiSpamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final settings = s.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Антиспам')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final r = settings.spam;
          void set(void Function(SpamRules r) change) => settings.update((st) => change(st.spam));
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Спам сразу в архив'),
                value: r.enabled,
                onChanged: (v) => set((r) => r.enabled = v),
              ),
              SwitchListTile(
                title: const Text('Архивировать новые чаты от незнакомцев'),
                subtitle: const Text(
                  'Настройка Telegram: работает даже когда клиент закрыт. '
                  'Доступна не всем аккаунтам',
                ),
                value: r.serverAutoArchive,
                onChanged: r.enabled ? (v) => set((r) => r.serverAutoArchive = v) : null,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text('Локальные правила для личных сообщений от незнакомцев:'),
              ),
              CheckboxListTile(
                title: const Text('Помечены Telegram как SCAM / FAKE'),
                value: r.scamFake,
                onChanged: r.enabled ? (v) => set((r) => r.scamFake = v!) : null,
              ),
              CheckboxListTile(
                title: const Text('Содержат ссылку'),
                value: r.strangerLinks,
                onChanged: r.enabled ? (v) => set((r) => r.strangerLinks = v!) : null,
              ),
              CheckboxListTile(
                title: const Text('Отправитель без аватарки'),
                subtitle: const Text('Строгое правило, может задеть обычных людей'),
                value: r.strangerNoPhoto,
                onChanged: r.enabled ? (v) => set((r) => r.strangerNoPhoto = v!) : null,
              ),
              _WordsTile(
                title: 'Стоп-слова',
                subtitle: 'Сообщение от незнакомца с таким словом → чат в архив',
                words: r.keywords,
                onChanged: (w) => set((r) => r.keywords = w),
              ),
              _WordsTile(
                title: 'Скрывать сообщения со словами',
                subtitle: 'Во всех чатах и группах сообщение сворачивается',
                words: r.hiddenWords,
                onChanged: (w) => set((r) => r.hiddenWords = w),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Чаты с контактами, ботами и теми, кому вы уже писали, не трогаются никогда.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Журнал'),
                trailing: settings.spamLog.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => settings.update((st) => st.spamLog.clear()),
                        child: const Text('Очистить'),
                      ),
              ),
              if (settings.spamLog.isEmpty) const ListTile(title: Text('Пока ничего не отправлено в архив')),
              for (final e in settings.spamLog)
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: Text(e.title),
                  subtitle: Text(
                    '${e.reasons.join(', ')}\n'
                    '${formatDateTime(e.date.millisecondsSinceEpoch ~/ 1000)}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Не спам — вернуть',
                    icon: const Icon(Icons.unarchive_outlined),
                    onPressed: () async {
                      await s.antispam.moveToMain(e.chatId);
                      settings.update((st) => st.spamLog.remove(e));
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WordsTile extends StatelessWidget {
  const _WordsTile({required this.title, required this.subtitle, required this.words, required this.onChanged});

  final String title;
  final String subtitle;
  final List<String> words;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        words.isEmpty ? subtitle : '$subtitle\n${words.join(', ')}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: words.isNotEmpty,
      trailing: const Icon(Icons.edit_outlined),
      onTap: () async {
        final controller = TextEditingController(text: words.join('\n'));
        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              maxLines: 10,
              decoration: const InputDecoration(hintText: 'По одному слову или фразе на строку'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Сохранить')),
            ],
          ),
        );
        controller.dispose();
        if (result == null) return;
        onChanged(result.split('\n').map((w) => w.trim()).where((w) => w.isNotEmpty).toList());
      },
    );
  }
}
