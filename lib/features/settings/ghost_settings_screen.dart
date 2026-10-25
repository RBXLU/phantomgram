import 'package:flutter/material.dart';

import '../../core/services.dart';

class GhostSettingsScreen extends StatelessWidget {
  const GhostSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Призрачный режим')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final g = settings.ghost;
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Призрачный режим'),
                subtitle: const Text('Быстрый переключатель — значок глаза на главном экране'),
                value: g.enabled,
                onChanged: (v) => settings.update((s) => s.ghost.enabled = v),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Не показывать «в сети»'),
                subtitle: const Text('Клиент не сообщает серверу, что вы онлайн'),
                value: g.hideOnline,
                onChanged: g.enabled ? (v) => settings.update((s) => s.ghost.hideOnline = v) : null,
              ),
              SwitchListTile(
                title: const Text('Офлайн сразу после отправки'),
                subtitle: const Text(
                  'Telegram сам ставит «в сети», когда вы пишете. '
                  'Клиент тут же отправляет «не в сети»',
                ),
                value: g.offlineAfterSend,
                onChanged: g.enabled && g.hideOnline
                    ? (v) => settings.update((s) => s.ghost.offlineAfterSend = v)
                    : null,
              ),
              SwitchListTile(
                title: const Text('Читать без отметки «прочитано»'),
                subtitle: const Text('Отметить вручную: меню чата → «Отметить прочитанным»'),
                value: g.noReadReceipts,
                onChanged: g.enabled ? (v) => settings.update((s) => s.ghost.noReadReceipts = v) : null,
              ),
              SwitchListTile(
                title: const Text('Не показывать «печатает…»'),
                value: g.hideTyping,
                onChanged: g.enabled ? (v) => settings.update((s) => s.ghost.hideTyping = v) : null,
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Ограничения: ответ, реакция или голосование всё равно видны собеседнику. '
                  'Если в приватности Telegram у вас «Последняя активность: никто», '
                  'вы тоже не видите чужой статус — это правило сервера.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
