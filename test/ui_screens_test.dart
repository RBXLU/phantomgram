// Renders every screen on demo data, phone- and desktop-sized. Layout
// overflows and exceptions fail the test.
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phantomgram/app.dart';
import 'package:phantomgram/core/services.dart';
import 'package:phantomgram/core/settings.dart';
import 'package:phantomgram/core/td_client.dart';
import 'package:phantomgram/demo/demo_backend.dart';
import 'package:phantomgram/demo/main_demo.dart';
import 'package:phantomgram/features/antispam/antispam_screen.dart';
import 'package:phantomgram/features/archive/archive_screen.dart';
import 'package:phantomgram/features/chat/chat_screen.dart';
import 'package:phantomgram/features/proxy/proxy_screen.dart';
import 'package:phantomgram/features/settings/ghost_settings_screen.dart';
import 'package:phantomgram/features/settings/local_pins_screen.dart';
import 'package:phantomgram/features/theme/theme_editor_screen.dart';

Future<Services> _start(AppSettings settings) async {
  final backend = DemoBackend();
  final td = TdClient.fake(backend.handle);
  final services = await Services.start(
    settings,
    td: td,
    dataDir: Directory('${Directory.systemTemp.path}/phantomgram_ui_test'),
  );
  backend.seed(td);
  return services;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('phone screens render (${dark ? 'dark' : 'light'})', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        PhantomApp(
          settings: demoSettings(dark: dark),
          startServices: _start,
          navigatorKey: navigator,
        ),
      );
      await _settle(tester);
      expect(find.text('Аня'), findsWidgets);
      expect(find.text('Чаты'), findsWidgets);

      for (final screen in <Widget>[
        const ChatScreen(chatId: DemoBackend.anyaChat),
        const ChatScreen(chatId: -200),
        const ChatScreen(chatId: -300),
        const GhostSettingsScreen(),
        const ArchiveScreen(),
        const AntiSpamScreen(),
        const ProxyScreen(),
        const ThemeEditorScreen(),
        const LocalPinsScreen(),
      ]) {
        navigator.currentState!.push(CupertinoPageRoute<void>(builder: (_) => screen));
        await _settle(tester);
        navigator.currentState!.pop();
        await _settle(tester);
      }

      await tester.tap(find.text('Настройки'));
      await _settle(tester);
      expect(find.text('Призрачный режим'), findsWidgets);
      await tester.tap(find.text('Архив'));
      await _settle(tester);
      expect(find.text('Крипто сигналы 🚀'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
    });
  }

  testWidgets('desktop shows the chat next to the list', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(PhantomApp(settings: demoSettings(), startServices: _start));
    await _settle(tester);
    expect(find.text('Выберите чат'), findsOneWidget);
    await tester.tap(find.text('Аня').first);
    await _settle(tester);
    expect(find.text('Покажи завтра 😄'), findsOneWidget);
    expect(find.text('Выберите чат'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _settle(tester);
  });
}
