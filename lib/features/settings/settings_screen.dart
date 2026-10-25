import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../antispam/antispam_screen.dart';
import '../archive/archive_screen.dart';
import '../auth/auth_controller.dart';
import '../proxy/proxy_screen.dart';
import '../theme/theme_editor_screen.dart';
import 'ghost_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.settings, s.proxy]),
        builder: (context, _) {
          final st = s.settings;
          return ListView(
            children: [
              const _Section('Telegram'),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Призрачный режим'),
                subtitle: Text(st.ghost.enabled ? 'Включён' : 'Выключен'),
                onTap: () => open(const GhostSettingsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.restore_from_trash_outlined),
                title: const Text('Удалённые и изменённые'),
                subtitle: Text(
                  st.archive.saveDeleted || st.archive.saveEdits ? 'Сохраняются на устройстве' : 'Не сохраняются',
                ),
                onTap: () => open(const ArchiveScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Антиспам'),
                subtitle: Text(st.spam.enabled ? 'Спам → архив · в журнале ${st.spamLog.length}' : 'Выключен'),
                onTap: () => open(const AntiSpamScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.vpn_lock_outlined),
                title: const Text('Прокси (MTProxy)'),
                subtitle: Text(
                  st.proxy.autoEnabled
                      ? 'Автоподбор: топ-${st.proxy.topCount}, смена каждые ${st.proxy.intervalMinutes} мин'
                      : 'Автоподбор выключен',
                ),
                onTap: () => open(const ProxyScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Оформление'),
                subtitle: const Text('Цвета, пузыри, шрифт, компактный режим'),
                onTap: () => open(const ThemeEditorScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: const Text('Локальные закрепы'),
                subtitle: Text(
                  '${st.localPins.length} · без лимита, только на этом устройстве. '
                  'Долгое нажатие на чат → «Закрепить локально»',
                ),
              ),
              const _Section('TikTok'),
              const ListTile(
                enabled: false,
                leading: Icon(Icons.music_note_outlined),
                title: Text('TikTok'),
                subtitle: Text('В следующей версии: веб-версия со своей темой и напоминанием про огонёк'),
              ),
              const _Section('Аккаунт'),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('api_id / api_hash'),
                subtitle: Text('api_id ${st.apiId}'),
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                title: Text('Выйти', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Выйти из аккаунта?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Выйти')),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    await s.auth.logOut();
                  }
                },
              ),
              const AboutListTile(
                icon: Icon(Icons.info_outline),
                applicationName: 'Phantomgram',
                applicationVersion: appVersion,
                aboutBoxChildren: [Text('Неофициальный клиент Telegram на TDLib. Не связан с Telegram FZ-LLC.')],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      title,
      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
    ),
  );
}
