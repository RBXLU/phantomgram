import 'package:flutter/cupertino.dart';

import '../../core/services.dart';
import '../../core/td_text.dart';
import '../../ui/feedback.dart';
import '../../ui/ios_list.dart';
import '../../ui/ios_page.dart';
import '../../ui/look.dart';
import 'spam_rules.dart';

class AntiSpamScreen extends StatelessWidget {
  const AntiSpamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final settings = s.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final r = settings.spam;
        final look = Look.of(context);
        void set(void Function(SpamRules r) change) => settings.update((st) => change(st.spam));

        Future<void> editWords(String title, List<String> words, void Function(List<String>) save) async {
          final result = await promptText(
            context,
            title: title,
            message: 'По одному слову или фразе на строку',
            initial: words.join('\n'),
            lines: 6,
            action: 'Сохранить',
          );
          if (result == null) return;
          save(result.split('\n').map((w) => w.trim()).where((w) => w.isNotEmpty).toList());
        }

        return IosPage(
          title: 'Антиспам',
          slivers: [
            SliverToBoxAdapter(
              child: IosSection(
                dividerInset: 16,
                footer: 'Серверная настройка работает, даже когда клиент закрыт. Доступна не всем аккаунтам.',
                children: [
                  IosSwitchRow(
                    title: 'Спам сразу в архив',
                    value: r.enabled,
                    onChanged: (v) => set((r) => r.enabled = v),
                  ),
                  IosSwitchRow(
                    title: 'Новые чаты от незнакомцев',
                    subtitle: 'Архивировать и отключать уведомления (Telegram)',
                    value: r.serverAutoArchive,
                    onChanged: r.enabled ? (v) => set((r) => r.serverAutoArchive = v) : null,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                header: 'Правила для незнакомцев',
                dividerInset: 16,
                footer: 'Чаты с контактами, ботами и теми, кому вы уже писали, не трогаются никогда.',
                children: [
                  IosSwitchRow(
                    title: 'Помечены как SCAM / FAKE',
                    value: r.scamFake,
                    onChanged: r.enabled ? (v) => set((r) => r.scamFake = v) : null,
                  ),
                  IosSwitchRow(
                    title: 'Присылают ссылку',
                    value: r.strangerLinks,
                    onChanged: r.enabled ? (v) => set((r) => r.strangerLinks = v) : null,
                  ),
                  IosSwitchRow(
                    title: 'Без аватарки',
                    subtitle: 'Строгое правило, может задеть обычных людей',
                    value: r.strangerNoPhoto,
                    onChanged: r.enabled ? (v) => set((r) => r.strangerNoPhoto = v) : null,
                  ),
                  IosRow(
                    title: 'Стоп-слова',
                    value: '${r.keywords.length}',
                    onTap: () => editWords('Стоп-слова', r.keywords, (w) => set((r) => r.keywords = w)),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                header: 'Во всех чатах',
                dividerInset: 16,
                footer: 'Сообщения с этими словами сворачиваются; нажмите, чтобы показать.',
                children: [
                  IosRow(
                    title: 'Скрывать сообщения со словами',
                    value: r.hiddenWords.isEmpty ? 'Нет' : '${r.hiddenWords.length}',
                    onTap: () => editWords('Скрывать со словами', r.hiddenWords, (w) => set((r) => r.hiddenWords = w)),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                header: 'Журнал',
                dividerInset: 16,
                children: [
                  if (settings.spamLog.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Пока ничего не отправлено в архив', style: TextStyle(color: look.secondaryLabel)),
                    ),
                  for (final e in settings.spamLog)
                    IosRow(
                      title: e.title,
                      subtitle: '${e.reasons.join(', ')}\n${formatDateTime(e.date.millisecondsSinceEpoch ~/ 1000)}',
                      trailing: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 32),
                        onPressed: () async {
                          await s.antispam.moveToMain(e.chatId);
                          settings.update((st) => st.spamLog.remove(e));
                          if (context.mounted) showToast(context, 'Чат «${e.title}» возвращён');
                        },
                        child: const Text('Не спам', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                  if (settings.spamLog.isNotEmpty)
                    IosRow(
                      title: 'Очистить журнал',
                      destructive: true,
                      centered: true,
                      onTap: () => settings.update((st) => st.spamLog.clear()),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
