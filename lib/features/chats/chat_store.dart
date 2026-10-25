import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/settings.dart';
import '../../core/td_client.dart';

enum ChatKind { private, secret, group, channel }

class ChatPos {
  const ChatPos(this.order, this.isPinned);

  final int order;
  final bool isPinned;
}

class ChatInfo {
  ChatInfo(this.id, this.raw);

  final int id;
  TdObject raw;
  final positions = <String, ChatPos>{};

  String get title => raw['title'] as String? ?? '';
  Map get type => raw['type'] as Map;

  ChatKind get kind => switch (type['@type']) {
    'chatTypePrivate' => ChatKind.private,
    'chatTypeSecret' => ChatKind.secret,
    'chatTypeSupergroup' when type['is_channel'] == true => ChatKind.channel,
    _ => ChatKind.group,
  };

  int? get privateUserId => type['user_id'] as int?;
  TdObject? get lastMessage => raw['last_message'] as TdObject?;
  int get unreadCount => raw['unread_count'] as int? ?? 0;
  bool get isMarkedUnread => raw['is_marked_as_unread'] as bool? ?? false;
  int get unreadMentions => raw['unread_mention_count'] as int? ?? 0;
  bool get isMuted => ((raw['notification_settings'] as Map?)?['mute_for'] as int? ?? 0) > 0;
  int? get smallPhotoFileId => ((raw['photo'] as Map?)?['small'] as Map?)?['id'] as int?;
  String? get minithumbnail => ((raw['photo'] as Map?)?['minithumbnail'] as Map?)?['data'] as String?;
}

/// Mirrors chats, users, files and connection state from TDLib updates.
class ChatStore extends ChangeNotifier {
  ChatStore(this.td, this.settings) {
    _sub = td.updates.listen(_onUpdate);
    settings.addListener(_scheduleNotify);
  }

  final TdClient td;
  final AppSettings settings;
  late final StreamSubscription<TdObject> _sub;

  final chats = <int, ChatInfo>{};
  final users = <int, TdObject>{};
  final _files = <int, TdObject>{};
  final _downloading = <int>{};
  String connectionState = 'connectionStateConnecting';
  int? myUserId;
  bool _notifyScheduled = false;
  final _loadedLists = <String>{};

  void _onUpdate(TdObject u) {
    switch (u['@type']) {
      case 'updateNewChat':
        final raw = u['chat'] as TdObject;
        final chat = ChatInfo(raw['id'] as int, raw);
        for (final p in (raw['positions'] as List?) ?? const []) {
          _applyPosition(chat, p as Map);
        }
        chats[chat.id] = chat;
      case 'updateChatPosition':
        final chat = chats[u['chat_id']];
        if (chat != null) _applyPosition(chat, u['position'] as Map);
      case 'updateChatLastMessage':
        final chat = chats[u['chat_id']];
        if (chat == null) break;
        chat.raw['last_message'] = u['last_message'];
        for (final p in (u['positions'] as List?) ?? const []) {
          _applyPosition(chat, p as Map);
        }
      case 'updateChatTitle':
        chats[u['chat_id']]?.raw['title'] = u['title'];
      case 'updateChatPhoto':
        chats[u['chat_id']]?.raw['photo'] = u['photo'];
      case 'updateChatReadInbox':
        chats[u['chat_id']]?.raw['unread_count'] = u['unread_count'];
      case 'updateChatReadOutbox':
        chats[u['chat_id']]?.raw['last_read_outbox_message_id'] = u['last_read_outbox_message_id'];
      case 'updateChatIsMarkedAsUnread':
        chats[u['chat_id']]?.raw['is_marked_as_unread'] = u['is_marked_as_unread'];
      case 'updateChatUnreadMentionCount':
        chats[u['chat_id']]?.raw['unread_mention_count'] = u['unread_mention_count'];
      case 'updateChatNotificationSettings':
        chats[u['chat_id']]?.raw['notification_settings'] = u['notification_settings'];
      case 'updateUser':
        final user = u['user'] as TdObject;
        users[user['id'] as int] = user;
      case 'updateFile':
        final file = u['file'] as TdObject;
        _files[file['id'] as int] = file;
      case 'updateConnectionState':
        connectionState = (u['state'] as Map)['@type'] as String;
      case 'updateOption':
        if (u['name'] == 'my_id') {
          myUserId = int.tryParse('${(u['value'] as Map)['value']}');
        }
        return;
      default:
        return;
    }
    _scheduleNotify();
  }

  void _applyPosition(ChatInfo chat, Map pos) {
    final key = chatListKey(pos['list'] as Map);
    final order = int.parse('${pos['order']}');
    if (order == 0) {
      chat.positions.remove(key);
    } else {
      chat.positions[key] = ChatPos(order, pos['is_pinned'] as bool? ?? false);
    }
  }

  /// Coalesces bursts of updates into one rebuild per frame.
  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    Timer(const Duration(milliseconds: 50), () {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  /// Chats of a list: local pins first (unlimited, this device only), then
  /// Telegram's own order (server pins are part of it).
  List<ChatInfo> listChats(String key) {
    final pins = settings.localPins;
    final pinned = <ChatInfo>[];
    for (final id in pins) {
      final c = chats[id];
      if (c != null && c.positions.containsKey(key)) pinned.add(c);
    }
    final rest = chats.values.where((c) => c.positions.containsKey(key) && !pins.contains(c.id)).toList()
      ..sort((a, b) => b.positions[key]!.order.compareTo(a.positions[key]!.order));
    return [...pinned, ...rest];
  }

  bool isLocallyPinned(int chatId) => settings.localPins.contains(chatId);

  Future<void> loadMore(TdObject list, {int limit = 100}) async {
    final key = chatListKey(list);
    if (_loadedLists.contains(key)) return;
    try {
      await td.send({'@type': 'loadChats', 'chat_list': list, 'limit': limit});
    } on TdError catch (e) {
      // 404: everything is already loaded.
      if (e.code == 404) _loadedLists.add(key);
    }
  }

  /// Local path of a small file, starting the download if needed.
  String? filePath(int fileId) {
    final file = _files[fileId];
    final local = file?['local'] as Map?;
    if (local?['is_downloading_completed'] == true) return local!['path'] as String;
    if (_downloading.add(fileId)) {
      td.post({
        '@type': 'downloadFile',
        'file_id': fileId,
        'priority': 1,
        'offset': 0,
        'limit': 0,
        'synchronous': false,
      });
    }
    return null;
  }

  String senderName(Map? sender) {
    if (sender == null) return '';
    if (sender['@type'] == 'messageSenderUser') {
      final user = users[sender['user_id']];
      if (user == null) return '';
      return '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    }
    return chats[sender['chat_id']]?.title ?? '';
  }

  @override
  void dispose() {
    _sub.cancel();
    settings.removeListener(_scheduleNotify);
    super.dispose();
  }
}
