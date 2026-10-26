import 'package:flutter/cupertino.dart';

import '../../core/services.dart';
import '../../core/td_text.dart';
import '../../ui/feedback.dart';
import '../../ui/glass.dart';
import '../../ui/ios_list.dart';
import '../../ui/ios_page.dart';
import '../../ui/look.dart';
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
    return ListenableBuilder(
      listenable: s.settings,
      builder: (context, _) {
        final look = Look.of(context);
        return IosPage(
          title: 'Удалённые и изменённые',
          actions: [
            GlassButton(
              icon: CupertinoIcons.trash,
              semanticLabel: 'Очистить',
              onPressed: () async {
                final ok = await confirm(
                  context,
                  title: 'Очистить локальный архив?',
                  message: 'Сохранённые копии удалённых сообщений и история правок пропадут.',
                  action: 'Очистить',
                  destructive: true,
                );
                if (ok) {
                  await s.archive.clear();
                  _refresh();
                }
              },
            ),
          ],
          slivers: [
            SliverToBoxAdapter(
              child: IosSection(
                dividerInset: 16,
                footer:
                    'Сохраняется только то, что дошло до этого устройства: если сообщение удалили, пока '
                    'клиент был закрыт и не успел его получить, восстановить его нельзя.',
                children: [
                  IosSwitchRow(
                    title: 'Сохранять удалённые',
                    subtitle: 'Остаются в чате с красной рамкой',
                    value: s.settings.archive.saveDeleted,
                    onChanged: (v) => s.settings.update((st) => st.archive.saveDeleted = v),
                  ),
                  IosSwitchRow(
                    title: 'Сохранять историю правок',
                    subtitle: 'Долгое нажатие на сообщение → «История правок»',
                    value: s.settings.archive.saveEdits,
                    onChanged: (v) => s.settings.update((st) => st.archive.saveEdits = v),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: FutureBuilder<List<ArchivedMessage>>(
                future: _deleted,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(padding: EdgeInsets.all(24), child: CupertinoActivityIndicator());
                  }
                  final list = snap.data!;
                  return IosSection(
                    header: 'Удалённые сообщения',
                    dividerInset: 16,
                    children: [
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Пока ничего не удаляли', style: TextStyle(color: look.secondaryLabel)),
                        ),
                      for (final m in list)
                        IosRow(
                          title: m.text,
                          subtitle:
                              '${s.chats.chats[m.chatId]?.title ?? m.chatId} · удалено ${formatDateTime(m.deletedAt!)}',
                          onTap: s.chats.chats[m.chatId] == null
                              ? null
                              : () =>
                                    Navigator.of(context)
                                        .push(CupertinoPageRoute<void>(builder: (_) => ChatScreen(chatId: m.chatId))),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
