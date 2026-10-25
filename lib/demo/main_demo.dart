// Demo mode: the real UI on sample data, no Telegram account or TDLib needed.
//
//   flutter run -t lib/demo/main_demo.dart
//
// Options (environment variable on desktop, --dart-define anywhere):
//   DEMO_SCREEN   list | chat | settings | proxy | theme | ghost | archive
//   DEMO_PLATFORM ios — iOS look (title alignment, scrolling, transitions) and
//                 a drawn status bar, for previewing the iPhone layout on a desktop
//   DEMO_DARK     1 — dark theme
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../core/services.dart';
import '../core/settings.dart';
import '../core/td_client.dart';
import '../features/archive/archive_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/proxy/proxy_link.dart';
import '../features/proxy/proxy_ranking.dart';
import '../features/proxy/proxy_screen.dart';
import '../features/settings/ghost_settings_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/theme/theme_editor_screen.dart';
import 'demo_backend.dart';

String _option(String name) {
  final fromEnv = Platform.environment[name];
  if (fromEnv != null) return fromEnv;
  return switch (name) {
    'DEMO_SCREEN' => const String.fromEnvironment('DEMO_SCREEN'),
    'DEMO_PLATFORM' => const String.fromEnvironment('DEMO_PLATFORM'),
    'DEMO_DARK' => const String.fromEnvironment('DEMO_DARK'),
    _ => '',
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ios = _option('DEMO_PLATFORM') == 'ios';
  if (ios) debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

  final settings = demoSettings(dark: _option('DEMO_DARK') == '1');
  final navigator = GlobalKey<NavigatorState>();
  final app = PhantomApp(settings: settings, startServices: startDemoServices, navigatorKey: navigator);
  runApp(ios ? IosPreviewFrame(dark: _option('DEMO_DARK') == '1', child: app) : app);

  final screen = switch (_option('DEMO_SCREEN')) {
    'chat' => const ChatScreen(chatId: DemoBackend.anyaChat),
    'settings' => const SettingsScreen(),
    'proxy' => const ProxyScreen(),
    'theme' => const ThemeEditorScreen(),
    'ghost' => const GhostSettingsScreen(),
    'archive' => const ArchiveScreen(),
    _ => null,
  };
  if (screen != null) {
    // Wait for the demo account to "log in" before opening the screen.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    navigator.currentState?.push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

Future<Services> startDemoServices(AppSettings settings) async {
  final backend = DemoBackend();
  final td = TdClient.fake(backend.handle);
  final dir = await Directory.systemTemp.createTemp('phantomgram_demo');
  final services = await Services.start(settings, td: td, dataDir: dir);
  backend.seed(td);
  return services;
}

AppSettings demoSettings({bool dark = false}) {
  final s = AppSettings.memory()
    ..apiId = 1
    ..apiHash = '0' * 32
    ..localPins = [DemoBackend.anyaChat];
  s.ghost.enabled = true;
  s.theme.mode = dark ? ThemeModeSetting.dark : ThemeModeSetting.light;
  s.spam.hiddenWords = ['реклама'];
  s.spamLog = [
    SpamLogEntry(
      chatId: 201,
      title: 'Крипто сигналы 🚀',
      reasons: ['стоп-слово «пассивный доход»', 'ссылка от незнакомца'],
      date: DateTime.now().subtract(const Duration(minutes: 50)),
    ),
    SpamLogEntry(
      chatId: 202,
      title: 'Бонус Казино',
      reasons: ['ссылка от незнакомца'],
      date: DateTime.now().subtract(const Duration(hours: 14)),
    ),
  ];
  final p = s.proxy
    ..autoEnabled = true
    ..sources = ['@mtproxy_list_demo', 'https://example.org/mtproxy.txt']
    ..lastRotation = DateTime.now().subtract(const Duration(minutes: 17))
    ..activeIndex = 0;
  const secret = 'ee0123456789abcdef0123456789abcdef676f6f676c652e636f6d';
  ProxyScore score(String host, double ping, double jitter, double ok) => ProxyScore(
    link: ProxyLink(server: host, port: 443, secret: secret),
    pingMs: ping,
    jitterMs: jitter,
    successRate: ok,
    score: ping + jitter / 2,
  );
  p.selected = [
    score('de1.mtp.example.net', 38, 4, 1),
    score('nl2.mtp.example.net', 45, 9, 1),
    score('fi1.mtp.example.net', 52, 6, 1),
    score('pl3.mtp.example.net', 61, 14, 1),
    score('se1.mtp.example.net', 74, 11, 1),
  ];
  return s;
}

/// Draws an iPhone-like status bar and home indicator and reserves the same
/// safe-area insets an iPhone 15 has, so the layout matches the device.
class IosPreviewFrame extends StatelessWidget {
  const IosPreviewFrame({super.key, required this.child, this.dark = false});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    const insets = EdgeInsets.only(top: 54, bottom: 34);
    final fg = dark ? Colors.white : Colors.black;
    return MediaQuery(
      data: media.copyWith(padding: insets, viewPadding: insets),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 54,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 18, 28, 0),
                  child: Row(
                    children: [
                      Text(
                        '9:41',
                        style: TextStyle(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.signal_cellular_alt, size: 17, color: fg),
                      const SizedBox(width: 5),
                      Icon(Icons.wifi, size: 17, color: fg),
                      const SizedBox(width: 5),
                      Icon(Icons.battery_full, size: 19, color: fg),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 134,
                    height: 5,
                    decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
