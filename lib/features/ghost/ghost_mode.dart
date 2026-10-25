import 'package:flutter/widgets.dart';

import '../../core/settings.dart';
import '../../core/td_client.dart';

/// Decides what presence signals the client sends to Telegram.
///
/// - "online": TDLib only reports us online while the `online` option is
///   true, so in ghost mode we never set it.
/// - read receipts: messages are marked read only through `viewMessages`;
///   in ghost mode the chat screen does not call it.
/// - typing: `sendChatAction` is never sent in ghost mode.
///
/// Telegram's server may still mark you online right after you *send* a
/// message; [afterMessageSent] immediately reports offline again.
class GhostMode with WidgetsBindingObserver {
  GhostMode(this.td, this.settings) {
    WidgetsBinding.instance.addObserver(this);
    settings.addListener(_apply);
    _apply();
  }

  final TdClient td;
  final AppSettings settings;
  bool _foreground = true;
  bool? _sentOnline;

  GhostSettings get _ghost => settings.ghost;

  bool get skipReadReceipts => _ghost.shouldSkipRead;
  bool get hideTyping => _ghost.shouldHideTyping;

  void _apply() {
    _setOnline(_foreground && !_ghost.shouldHideOnline);
  }

  void _setOnline(bool online, {bool force = false}) {
    if (!force && _sentOnline == online) return;
    _sentOnline = online;
    td.post({'@type': 'setOption', 'name': 'online', 'value': boolOption(online)});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _apply();
  }

  void afterMessageSent() {
    if (!_ghost.shouldGoOfflineAfterSend) return;
    // TDLib ignores setting an option to its current value, so flip it to
    // get a fresh "offline" packet out. We are already shown online by the
    // server at this point, so the short "online" costs nothing.
    _setOnline(true, force: true);
    _setOnline(false, force: true);
  }

  /// Marks the chat read up to [lastMessageId], even in ghost mode.
  Future<void> markRead(int chatId, int lastMessageId) => td.send({
    '@type': 'viewMessages',
    'chat_id': chatId,
    'message_ids': [lastMessageId],
    'source': {'@type': 'messageSourceChatHistory'},
    'force_read': true,
  });

  /// Normal-mode read receipts for messages visible on screen.
  void viewed(int chatId, List<int> messageIds) {
    if (skipReadReceipts || messageIds.isEmpty) return;
    td.post({
      '@type': 'viewMessages',
      'chat_id': chatId,
      'message_ids': messageIds,
      'source': {'@type': 'messageSourceChatHistory'},
      'force_read': false,
    });
  }

  void typing(int chatId) {
    if (hideTyping) return;
    td.post({
      '@type': 'sendChatAction',
      'chat_id': chatId,
      'topic_id': null,
      'business_connection_id': '',
      'action': {'@type': 'chatActionTyping'},
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    settings.removeListener(_apply);
  }
}
