import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../core/services.dart';
import '../../core/td_client.dart';
import '../../core/td_text.dart';
import '../../ui/feedback.dart';
import '../../ui/glass.dart';
import '../../ui/look.dart';
import '../../widgets/chat_avatar.dart';
import '../archive/message_archive.dart';
import '../chats/chat_store.dart';
import 'message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId, this.embedded = false});

  final int chatId;

  /// Shown next to the chat list on wide screens: no back button.
  final bool embedded;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final Services s;
  final _messages = <int, TdObject>{};
  final _deleted = <int>{};
  Map<int, ArchivedMessage> _archived = const {};
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<TdObject>? _updates;
  StreamSubscription<int>? _archiveChanges;
  bool _loading = false;
  bool _reachedEnd = false;
  DateTime _lastTyping = DateTime(0);

  int get chatId => widget.chatId;
  ChatInfo? get chat => s.chats.chats[chatId];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_updates != null) return;
    s = AppScope.of(context);
    s.td.post({'@type': 'openChat', 'chat_id': chatId});
    _updates = s.td.updates.where((u) => u['chat_id'] == chatId || _messageChat(u) == chatId).listen(_onUpdate);
    _archiveChanges = s.archive.changes.where((id) => id == chatId).listen((_) => _reloadArchive());
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadOlder();
    });
    _reloadArchive();
    _loadOlder();
  }

  static int? _messageChat(TdObject u) => (u['message'] as Map?)?['chat_id'] as int?;

  Future<void> _reloadArchive() async {
    final archived = await s.archive.chat(chatId);
    if (!mounted) return;
    setState(() {
      _archived = archived;
      _mergeArchivedDeleted();
    });
  }

  /// Deleted messages we archived earlier are shown in place, marked.
  void _mergeArchivedDeleted() {
    if (!s.settings.archive.saveDeleted) return;
    final oldest = _messages.isEmpty ? null : _messages.keys.reduce((a, b) => a < b ? a : b);
    for (final m in _archived.values) {
      if (!m.isDeleted || _messages.containsKey(m.id)) continue;
      if (!_reachedEnd && (oldest == null || m.id < oldest)) continue;
      _messages[m.id] = _fromArchive(m);
      _deleted.add(m.id);
    }
  }

  static TdObject _fromArchive(ArchivedMessage m) => {
    'id': m.id,
    'chat_id': m.chatId,
    'date': m.date,
    'is_outgoing': m.outgoing,
    'sender_id': m.sender.startsWith('u')
        ? {'@type': 'messageSenderUser', 'user_id': int.parse(m.sender.substring(1))}
        : {'@type': 'messageSenderChat', 'chat_id': int.tryParse(m.sender.substring(1)) ?? 0},
    'content': {'@type': 'messageText', 'text': formattedText(m.text)},
    'edit_date': m.wasEdited ? m.versions.last.date : 0,
  };

  Future<void> _loadOlder() async {
    if (_loading || _reachedEnd) return;
    _loading = true;
    try {
      var fromId = _oldestRealId() ?? 0;
      var received = 0;
      // TDLib answers from its local cache first and may return just a few
      // messages; keep asking until a screenful arrived.
      for (var attempt = 0; attempt < 3 && received < 30; attempt++) {
        final page = await s.td.send({
          '@type': 'getChatHistory',
          'chat_id': chatId,
          'from_message_id': fromId,
          'offset': 0,
          'limit': 50,
          'only_local': false,
        });
        final list = ((page['messages'] as List?) ?? const []).cast<TdObject>();
        // from_message_id itself is included in the answer, so a page with
        // nothing new means the beginning of the chat.
        final fresh = list.where((m) => !_messages.containsKey(m['id'])).toList();
        if (fresh.isEmpty) {
          _reachedEnd = true;
          break;
        }
        for (final m in fresh) {
          _messages[m['id'] as int] = m;
        }
        s.archive.recordMessages(fresh);
        received += fresh.length;
        fromId = list.last['id'] as int;
      }
      _markViewed();
      if (mounted) setState(_mergeArchivedDeleted);
    } on TdError catch (e) {
      _toast('Не удалось загрузить историю: ${e.message}');
    } finally {
      _loading = false;
    }
  }

  int? _oldestRealId() {
    int? oldest;
    for (final e in _messages.entries) {
      if (_deleted.contains(e.key)) continue;
      if (oldest == null || e.key < oldest) oldest = e.key;
    }
    return oldest;
  }

  void _markViewed() {
    final incoming =
        _messages.values
            .where((m) => m['is_outgoing'] != true && !_deleted.contains(m['id']))
            .map((m) => m['id'] as int)
            .toList()
          ..sort();
    if (incoming.isEmpty) return;
    s.ghost.viewed(chatId, incoming.sublist(incoming.length > 50 ? incoming.length - 50 : 0));
  }

  void _onUpdate(TdObject u) {
    switch (u['@type']) {
      case 'updateNewMessage':
        final m = u['message'] as TdObject;
        _messages[m['id'] as int] = m;
        if (m['is_outgoing'] != true) s.ghost.viewed(chatId, [m['id'] as int]);
      case 'updateMessageSendSucceeded':
        _messages.remove(u['old_message_id']);
        final m = u['message'] as TdObject;
        _messages[m['id'] as int] = m;
      case 'updateMessageSendFailed':
        final m = u['message'] as TdObject;
        _messages[m['id'] as int] = m;
        _toast('Сообщение не отправлено: ${(u['error'] as Map?)?['message'] ?? ''}');
      case 'updateMessageContent':
        _messages[u['message_id']]?['content'] = u['new_content'];
      case 'updateMessageEdited':
        _messages[u['message_id']]?['edit_date'] = u['edit_date'];
      case 'updateDeleteMessages':
        if (u['is_permanent'] != true || u['from_cache'] == true) return;
        for (final id in (u['message_ids'] as List).cast<int>()) {
          if (s.settings.archive.saveDeleted) {
            if (_messages.containsKey(id)) _deleted.add(id);
          } else {
            _messages.remove(id);
          }
        }
      default:
        return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    try {
      await s.td.send({'@type': 'sendMessage', 'chat_id': chatId, 'input_message_content': inputText(text)});
      s.ghost.afterMessageSent();
    } on TdError catch (e) {
      _composer.text = text;
      _toast('Ошибка отправки: ${e.message}');
    }
  }

  void _onTyping(String _) {
    final now = DateTime.now();
    if (now.difference(_lastTyping) < const Duration(seconds: 4)) return;
    _lastTyping = now;
    s.ghost.typing(chatId);
  }

  Future<void> _markReadNow() async {
    final last = chat?.lastMessage?['id'] as int?;
    if (last == null) return;
    await s.ghost.markRead(chatId, last);
    if (mounted) showToast(context, 'Отмечено прочитанным', icon: CupertinoIcons.checkmark_alt);
  }

  void _toast(String text) {
    if (mounted) showToast(context, text);
  }

  @override
  void dispose() {
    s.td.post({'@type': 'closeChat', 'chat_id': chatId});
    _updates?.cancel();
    _archiveChanges?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: s.chats, builder: (context, _) => _buildPage(context));

  /// Oldest first, with day separators and sender grouping resolved.
  List<ChatEntry> _entries() {
    final ids = _messages.keys.toList()..sort();
    final entries = <ChatEntry>[];
    for (var i = 0; i < ids.length; i++) {
      final m = _messages[ids[i]]!;
      final prev = i > 0 ? _messages[ids[i - 1]] : null;
      final next = i + 1 < ids.length ? _messages[ids[i + 1]] : null;
      final date = m['date'] as int;
      if (prev == null || !sameDay(prev['date'] as int, date)) entries.add(ChatEntry.day(date));
      entries.add(
        ChatEntry.message(m, first: prev == null || !_sameGroup(prev, m), last: next == null || !_sameGroup(m, next)),
      );
    }
    return entries;
  }

  static bool _sameGroup(TdObject a, TdObject b) =>
      a['is_outgoing'] == b['is_outgoing'] &&
      _senderKey(a) == _senderKey(b) &&
      sameDay(a['date'] as int, b['date'] as int) &&
      ((b['date'] as int) - (a['date'] as int)).abs() < 600;

  static String _senderKey(TdObject m) {
    final sender = m['sender_id'] as Map?;
    return '${sender?['user_id'] ?? sender?['chat_id']}';
  }

  String _subtitle(ChatInfo? info) {
    if (info == null) return '';
    return switch (info.kind) {
      ChatKind.private || ChatKind.secret => userStatusText(s.chats.users[info.privateUserId]?['status'] as Map?),
      ChatKind.group => 'группа',
      ChatKind.channel => 'канал',
    };
  }

  Future<void> _chatMenu() async {
    final pinned = s.chats.isLocallyPinned(chatId);
    final action = await actionSheet<String>(
      context,
      title: chat?.title,
      actions: [
        const SheetAction('Отметить прочитанным', 'read'),
        SheetAction(pinned ? 'Открепить' : 'Закрепить (без лимита, на этом устройстве)', 'pin'),
      ],
    );
    if (action == 'read') await _markReadNow();
    if (action == 'pin') s.settings.toggleLocalPin(chatId);
  }

  Widget _buildPage(BuildContext context) {
    final look = Look.of(context);
    final media = MediaQuery.of(context);
    final info = chat;
    final entries = _entries().reversed.toList();
    final ghostRead = s.ghost.skipReadReceipts;
    final canWrite = info != null && info.kind != ChatKind.channel;
    final readOutbox = info?.raw['last_read_outbox_message_id'] as int? ?? 0;
    final isGroup = info?.kind == ChatKind.group;
    final top = media.padding.top;
    final headerHeight = top + 64 + (ghostRead ? 46 : 0);
    final bottom = media.padding.bottom + media.viewInsets.bottom;

    return ColoredBox(
      color: look.bg,
      child: Stack(
        children: [
          const Positioned.fill(child: WallpaperBackground()),
          Positioned.fill(
            child: ListView.builder(
              controller: _scroll,
              reverse: true,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              // Visual insets: header on top, composer at the bottom.
              padding: EdgeInsets.fromLTRB(8, headerHeight + 8, 8, bottom + 66),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                if (e.message == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: GlassPill(
                        child: Text(
                          formatDayHeader(e.date),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: look.label),
                        ),
                      ),
                    ),
                  );
                }
                final m = e.message!;
                final sender = m['sender_id'] as Map?;
                final senderUser = senderUserId(sender);
                return MessageBubble(
                  message: m,
                  firstInGroup: e.first,
                  lastInGroup: e.last,
                  showSender: isGroup,
                  senderName: s.chats.senderName(sender),
                  senderId: senderUser ?? senderChatId(sender) ?? 0,
                  senderAvatar: !isGroup
                      ? null
                      : Avatar(
                          id: senderUser ?? 0,
                          title: s.chats.senderName(sender),
                          size: 32,
                          image: photoImage(
                            s.chats,
                            ((s.chats.users[senderUser]?['profile_photo'] as Map?)?['small'] as Map?)?['id'] as int?,
                            null,
                          ),
                        ),
                  deleted: _deleted.contains(m['id']),
                  archived: _archived[m['id']],
                  read: m['is_outgoing'] == true && (m['id'] as int) <= readOutbox,
                  rules: s.settings.spam,
                  onLongPress: () => _messageMenu(m),
                );
              },
            ),
          ),
          // Header: fade, glass back button, title capsule, avatar.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + 70,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [look.wallpaper.first.withValues(alpha: 0.9), look.wallpaper.first.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 6,
            left: 12,
            right: 12,
            height: 48,
            child: Row(
              children: [
                if (!widget.embedded)
                  GlassButton(
                    icon: CupertinoIcons.chevron_back,
                    semanticLabel: 'Назад',
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                else
                  const SizedBox(width: 44),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _chatMenu,
                      child: Glass(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              info?.title ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: look.label),
                            ),
                            Text(
                              _subtitle(info),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12,
                                color: _subtitle(info) == 'в сети' ? look.accent : look.secondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _chatMenu,
                  child: info == null ? const SizedBox(width: 44) : ChatAvatar(chat: info, store: s.chats, size: 44),
                ),
              ],
            ),
          ),
          if (ghostRead)
            Positioned(
              top: top + 62,
              left: 16,
              right: 16,
              child: Center(
                child: Glass(
                  padding: const EdgeInsets.only(left: 14, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.eye_slash_fill, size: 16, color: look.secondaryLabel),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Прочтение не отправляется',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: look.label),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 36),
                        onPressed: _markReadNow,
                        child: const Text('Прочитать', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 10,
            right: 10,
            bottom: bottom + 8,
            child: canWrite ? _composerBar(look) : _readOnlyBar(look),
          ),
        ],
      ),
    );
  }

  Widget _composerBar(LookData look) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _composer,
    builder: (context, value, _) {
      final hasText = value.text.trim().isNotEmpty;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Glass(
              radius: 22,
              child: CupertinoTextField(
                controller: _composer,
                placeholder: 'Сообщение',
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.send,
                onChanged: _onTyping,
                onSubmitted: (_) => _send(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: null,
                style: TextStyle(fontSize: 17, color: look.label),
                placeholderStyle: TextStyle(fontSize: 17, color: look.tertiaryLabel),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedScale(
            duration: const Duration(milliseconds: 160),
            scale: hasText ? 1 : 0.85,
            child: SizedBox.square(
              dimension: 44,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(22),
                color: hasText ? look.accent : look.fill,
                onPressed: hasText ? _send : null,
                disabledColor: look.fill,
                child: Icon(
                  CupertinoIcons.arrow_up,
                  size: 22,
                  color: hasText ? const Color(0xFFFFFFFF) : look.tertiaryLabel,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _readOnlyBar(LookData look) => Center(
    child: GlassPill(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Text('Канал · только чтение', style: TextStyle(fontSize: 15, color: look.secondaryLabel)),
    ),
  );

  Future<void> _messageMenu(TdObject m) async {
    final text = contentText(m['content'] as Map);
    final versions = _archived[m['id']]?.versions ?? const <MessageVersion>[];
    final action = await actionSheet<String>(
      context,
      actions: [
        const SheetAction('Копировать', 'copy'),
        if (versions.length > 1) SheetAction('История правок (${versions.length})', 'history'),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) showToast(context, 'Скопировано', icon: CupertinoIcons.doc_on_doc);
      case 'history':
        await showEditHistory(context, versions);
    }
  }
}

class ChatEntry {
  ChatEntry.day(this.date) : message = null, first = false, last = false;

  ChatEntry.message(TdObject this.message, {required this.first, required this.last}) : date = message['date'] as int;

  final TdObject? message;
  final int date;
  final bool first;
  final bool last;
}
