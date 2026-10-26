import 'package:flutter/cupertino.dart';

import '../../core/services.dart';
import '../../ui/glass.dart';
import '../../ui/ios_list.dart';
import '../../ui/ios_page.dart';
import '../../ui/look.dart';

class GhostSettingsScreen extends StatelessWidget {
  const GhostSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final g = settings.ghost;
        final look = Look.of(context);
        return IosPage(
          title: 'Призрачный режим',
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 20),
                child: Column(
                  children: [
                    SizedBox.square(
                      dimension: 96,
                      child: Glass(
                        tint: g.enabled ? look.accent.withValues(alpha: 0.85) : null,
                        child: Icon(
                          CupertinoIcons.eye_slash_fill,
                          size: 44,
                          color: g.enabled ? const Color(0xFFFFFFFF) : look.secondaryLabel,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Читайте и будьте онлайн незаметно',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: look.label),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Быстрое включение — кнопка с глазом над списком чатов.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: look.secondaryLabel),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                children: [
                  IosSwitchRow(
                    title: 'Призрачный режим',
                    value: g.enabled,
                    onChanged: (v) => settings.update((s) => s.ghost.enabled = v),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                header: 'Что скрывать',
                dividerInset: 16,
                footer:
                    'Ответ, реакция или голос в опросе всё равно видны собеседнику. Если в приватности '
                    'Telegram у вас «Последняя активность: никто», вы тоже не видите чужой статус — '
                    'это правило сервера.',
                children: [
                  IosSwitchRow(
                    title: 'Статус «в сети»',
                    subtitle: 'Клиент не сообщает серверу, что вы онлайн',
                    value: g.hideOnline,
                    onChanged: g.enabled ? (v) => settings.update((s) => s.ghost.hideOnline = v) : null,
                  ),
                  IosSwitchRow(
                    title: 'Офлайн после отправки',
                    subtitle: 'Telegram ставит «в сети», когда вы пишете; клиент сразу отправляет «не в сети»',
                    value: g.offlineAfterSend,
                    onChanged: g.enabled && g.hideOnline
                        ? (v) => settings.update((s) => s.ghost.offlineAfterSend = v)
                        : null,
                  ),
                  IosSwitchRow(
                    title: 'Отметки «прочитано»',
                    subtitle: 'Прочитать вручную: плашка в чате или свайп по чату вправо',
                    value: g.noReadReceipts,
                    onChanged: g.enabled ? (v) => settings.update((s) => s.ghost.noReadReceipts = v) : null,
                  ),
                  IosSwitchRow(
                    title: '«Печатает…»',
                    value: g.hideTyping,
                    onChanged: g.enabled ? (v) => settings.update((s) => s.ghost.hideTyping = v) : null,
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
