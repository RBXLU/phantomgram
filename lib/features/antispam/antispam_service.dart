import 'dart:async';

import '../../core/settings.dart';
import '../../core/td_client.dart';
import '../../core/td_text.dart';
import '../chats/chat_store.dart';
import 'spam_rules.dart';

/// Moves spam chats straight to the archive.
///
/// Two layers: Telegram's own "archive new chats from non-contacts" (applied
/// server-side, works even when the app is closed) and local rules evaluated
/// on every incoming private message from a stranger.
class AntiSpamService {
  AntiSpamService(this.td, this.settings, this.store) {
    _sub = td.on('updateNewMessage').listen((u) {
      _check(u['message'] as TdObject).catchError((Object _) {});
    });
    settings.addListener(_syncServerSetting);
    _syncServerSetting();
  }

  final TdClient td;
  final AppSettings settings;
  final ChatStore store;
  late final StreamSubscription<TdObject> _sub;
  final _checked = <int>{};
  bool? _serverSettingSent;

  SpamRules get rules => settings.spam;

  Future<void> _syncServerSetting() async {
    final want = rules.enabled && rules.serverAutoArchive;
    if (_serverSettingSent == want) return;
    _serverSettingSent = want;
    try {
      final current = await td.send({'@type': 'getArchiveChatListSettings'});
      await td.send({
        '@type': 'setArchiveChatListSettings',
        'settings': {...current, 'archive_and_mute_new_chats_from_unknown_users': want},
      });
    } on TdError {
      // Unavailable for some accounts unless Telegram enables it
      // (option can_archive_and_mute_new_chats_from_unknown_users).
    }
  }

  Future<void> _check(TdObject message) async {
    if (!rules.enabled || message['is_outgoing'] == true) return;
    final chatId = message['chat_id'] as int;
    final chat = store.chats[chatId];
    if (chat == null || chat.kind != ChatKind.private) return;
    if (!chat.positions.containsKey('main')) return; // already archived
    if (store.isLocallyPinned(chatId)) return;
    final userId = senderUserId(message['sender_id'] as Map?);
    if (userId == null || userId == store.myUserId) return;
    // Judge a chat once per session; its later messages are the same sender.
    if (!_checked.add(chatId)) return;

    final user = store.users[userId] ?? await td.send({'@type': 'getUser', 'user_id': userId});
    if (user['is_contact'] == true) return;
    final verification = user['verification_status'] as Map?;
    final text = searchableContentText(message['content'] as Map);

    final quick = SpamCandidate(
      text: text,
      isContact: false,
      hasProfilePhoto: user['profile_photo'] != null,
      isScam: verification?['is_scam'] == true,
      isFake: verification?['is_fake'] == true,
      isBot: (user['type'] as Map?)?['@type'] == 'userTypeBot',
      hasOutgoingMessages: false,
    );
    if (evaluateSpam(quick, rules).isEmpty) return;

    // Only now pay for a history request: never archive someone we talked to.
    final hasOutgoing = await _hasOutgoing(chatId);
    final reasons = evaluateSpam(
      SpamCandidate(
        text: quick.text,
        isContact: false,
        hasProfilePhoto: quick.hasProfilePhoto,
        isScam: quick.isScam,
        isFake: quick.isFake,
        isBot: quick.isBot,
        hasOutgoingMessages: hasOutgoing,
      ),
      rules,
    );
    if (reasons.isEmpty) return;
    await moveToArchive(chatId);
    settings.addSpamLog(SpamLogEntry(chatId: chatId, title: chat.title, reasons: reasons, date: DateTime.now()));
  }

  Future<bool> _hasOutgoing(int chatId) async {
    try {
      final history = await td.send({
        '@type': 'getChatHistory',
        'chat_id': chatId,
        'from_message_id': 0,
        'offset': 0,
        'limit': 50,
        'only_local': false,
      });
      return ((history['messages'] as List?) ?? const []).any((m) => (m as Map)['is_outgoing'] == true);
    } on TdError {
      return true; // when unsure, leave the chat alone
    }
  }

  Future<void> moveToArchive(int chatId) async {
    await td.send({'@type': 'addChatToList', 'chat_id': chatId, 'chat_list': chatListArchive});
  }

  Future<void> moveToMain(int chatId) async {
    await td.send({'@type': 'addChatToList', 'chat_id': chatId, 'chat_list': chatListMain});
  }

  void dispose() {
    _sub.cancel();
    settings.removeListener(_syncServerSetting);
  }
}
