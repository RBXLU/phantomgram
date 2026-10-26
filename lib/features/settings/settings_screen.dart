import 'package:flutter/cupertino.dart';

import '../../core/services.dart';
import '../../core/td_text.dart';
import '../../ui/feedback.dart';
import '../../ui/glass.dart';
import '../../ui/ios_list.dart';
import '../../ui/ios_page.dart';
import '../../ui/look.dart';
import '../../widgets/chat_avatar.dart';
import '../antispam/antispam_screen.dart';
import '../archive/archive_screen.dart';
import '../auth/auth_controller.dart';
import '../proxy/proxy_screen.dart';
import '../theme/theme_editor_screen.dart';
import 'ghost_settings_screen.dart';
import 'local_pins_screen.dart';

/// Settings tab.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    void open(Widget screen) => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => screen));

    return ListenableBuilder(
      listenable: Listenable.merge([s.settings, s.proxy, s.chats]),
      builder: (context, _) {
        final st = s.settings;
        final look = Look.of(context);
        final me = s.chats.users[s.chats.myUserId];
        final username = ((me?['usernames'] as Map?)?['active_usernames'] as List?)?.cast<String>().firstOrNull;
        final phone = me?['phone_number'] as String? ?? '';
        return IosPage(
          title: 'Настройки',
          largeTitle: true,
          showBack: false,
          bottomInset: 84,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Column(
                  children: [
                    Avatar(
                      id: s.chats.myUserId ?? 0,
                      title: userDisplayName(me),
                      size: 92,
                      image: photoImage(
                        s.chats,
                        ((me?['profile_photo'] as Map?)?['small'] as Map?)?['id'] as int?,
                        null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      me == null ? 'Аккаунт' : userDisplayName(me),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: look.label),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [if (phone.isNotEmpty) formatPhone(phone), if (username != null) '@$username'].join(' · '),
                      style: TextStyle(fontSize: 15, color: look.secondaryLabel),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                header: 'Telegram',
                children: [
                  IosRow(
                    leading: const IconTile(CupertinoIcons.eye_slash_fill, Color(0xFF5856D6)),
                    title: 'Призрачный режим',
                    value: st.ghost.enabled ? 'Вкл.' : 'Выкл.',
                    onTap: () => open(const GhostSettingsScreen()),
                  ),
                  IosRow(
                    leading: const IconTile(CupertinoIcons.trash_fill, LookData.destructive),
                    title: 'Удалённые сообщения',
                    value: st.archive.saveDeleted || st.archive.saveEdits ? 'Вкл.' : 'Выкл.',
                    onTap: () => open(const ArchiveScreen()),
                  ),
                  IosRow(
                    leading: const IconTile(CupertinoIcons.shield_fill, LookData.green),
                    title: 'Антиспам',
                    value: st.spam.enabled ? '${st.spamLog.length}' : 'Выкл.',
                    onTap: () => open(const AntiSpamScreen()),
                  ),
                  IosRow(
                    leading: const IconTile(CupertinoIcons.globe, Color(0xFF007AFF)),
                    title: 'Прокси',
                    value: st.proxy.autoEnabled ? 'Авто · топ-${st.proxy.topCount}' : 'Выкл.',
                    onTap: () => open(const ProxyScreen()),
                  ),
                  IosRow(
                    leading: const IconTile(CupertinoIcons.pin_fill, LookData.orange),
                    title: 'Закреплённые чаты',
                    value: '${st.localPins.length}',
                    onTap: () => open(const LocalPinsScreen()),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                children: [
                  IosRow(
                    leading: const IconTile(CupertinoIcons.paintbrush_fill, Color(0xFFFF2D55)),
                    title: 'Оформление',
                    value: wallpapers[st.theme.wallpaper.clamp(0, wallpapers.length - 1)].name,
                    onTap: () => open(const ThemeEditorScreen()),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(
              child: IosSection(
                header: 'TikTok',
                footer: 'В следующей версии: веб-версия со своей темой и напоминанием про огонёк.',
                children: [
                  IosRow(
                    leading: IconTile(CupertinoIcons.music_note_2, Color(0xFF1C1C1E)),
                    title: 'TikTok',
                    value: 'Скоро',
                    enabled: false,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                header: 'Аккаунт',
                footer:
                    'Phantomgram $appVersion · неофициальный клиент Telegram на TDLib, не связан с Telegram FZ-LLC.',
                children: [
                  IosRow(
                    leading: const IconTile(CupertinoIcons.lock_shield_fill, Color(0xFF8E8E93)),
                    title: 'Ключи API',
                    value: 'api_id ${st.apiId}',
                  ),
                  IosRow(
                    title: 'Выйти',
                    destructive: true,
                    centered: true,
                    onTap: () async {
                      final ok = await confirm(
                        context,
                        title: 'Выйти из аккаунта?',
                        message: 'Локальные закрепы и архив удалённых сообщений останутся на устройстве.',
                        action: 'Выйти',
                        destructive: true,
                      );
                      if (ok) await s.auth.logOut();
                    },
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
