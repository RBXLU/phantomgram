import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/td_text.dart';
import '../chat/chat_screen.dart';
import 'message_archive.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  Future<List<ArchivedMessage>>? _deleted;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deleted ??= AppScope.of(context).archive.allDeleted();
  }

  void _refresh() => setState(() => _deleted = AppScope.of(context).archive.allDeleted());

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Удалённые и изменённые'),
        actions: [
          IconButton(
            tooltip: 'Очистить сохранённое',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Удалить локальный архив?'),
                  content: const Text('Сохранённые копии удалённых сообщений и история правок пропадут.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
                  ],
                ),
              );
              if (ok == true) {
                await s.archive.clear();
                _refresh();
              }
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: s.settings,
        builder: (context, _) => Column(
          children: [
            SwitchListTile(
              title: const Text('Сохранять удалённые сообщения'),
              subtitle: const Text('Остаются в чате с красной рамкой и пометкой «удалено»'),
              value: s.settings.archive.saveDeleted,
              onChanged: (v) => s.settings.update((st) => st.archive.saveDeleted = v),
            ),
            SwitchListTile(
              title: const Text('Сохранять историю правок'),
              subtitle: const Text('Долгое нажатие на «изм.» сообщение → «История правок»'),
              value: s.settings.archive.saveEdits,
              onChanged: (v) => s.settings.update((st) => st.archive.saveEdits = v),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Сохраняется только то, что дошло до этого устройства: если сообщение удалили, '
                'пока клиент был закрыт и не успел его получить, восстановить его нельзя.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<ArchivedMessage>>(
                future: _deleted,
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final list = snap.data!;
                  if (list.isEmpty) return const Center(child: Text('Удалённых сообщений пока нет'));
                  return RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final m = list[i];
                        final chat = s.chats.chats[m.chatId];
                        return ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: Text(m.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${chat?.title ?? m.chatId} · удалено '
                            '${formatShortDate(m.deletedAt!)} ${formatTime(m.deletedAt!)}',
                          ),
                          onTap: chat == null
                              ? null
                              : () =>
                                    Navigator.of(context)
                                        .push(MaterialPageRoute<void>(builder: (_) => ChatScreen(chatId: m.chatId))),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
