import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../features/antispam/antispam_service.dart';
import '../features/archive/message_archive.dart';
import '../features/auth/auth_controller.dart';
import '../features/chats/chat_store.dart';
import '../features/ghost/ghost_mode.dart';
import '../features/proxy/proxy_manager.dart';
import 'settings.dart';
import 'td_client.dart';

/// Everything that lives as long as one TDLib client.
class Services {
  Services._({
    required this.settings,
    required this.td,
    required this.auth,
    required this.chats,
    required this.archive,
    required this.ghost,
    required this.antispam,
    required this.proxy,
  });

  final AppSettings settings;
  final TdClient td;
  final AuthController auth;
  final ChatStore chats;
  final MessageArchive archive;
  final GhostMode ghost;
  final AntiSpamService antispam;
  final ProxyManager proxy;

  static Future<Services> start(AppSettings settings) async {
    final dataDir = await getApplicationSupportDirectory();
    final td = await TdClient.start();
    // Subscribers are attached synchronously right after start, before the
    // receive isolate gets a chance to deliver the first update.
    final chats = ChatStore(td, settings);
    final services = Services._(
      settings: settings,
      td: td,
      auth: AuthController(td, settings, dataDir),
      chats: chats,
      archive: MessageArchive(td.updates, settings, Directory(p.join(dataDir.path, 'archive'))),
      ghost: GhostMode(td, settings),
      antispam: AntiSpamService(td, settings, chats),
      proxy: ProxyManager(td, settings),
    );
    services.proxy.start();
    return services;
  }

  Future<void> dispose() async {
    proxy.dispose();
    antispam.dispose();
    ghost.dispose();
    await archive.dispose();
    chats.dispose();
    auth.dispose();
    await td.close();
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final Services services;

  static Services of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
