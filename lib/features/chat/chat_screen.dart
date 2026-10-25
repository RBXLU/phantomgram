import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services.dart';
import '../../core/td_client.dart';
import '../../core/td_text.dart';
import '../antispam/spam_rules.dart';
import '../archive/message_archive.dart';
import '../chats/chat_store.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final int chatId;

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
    _toast('Отмечено прочитанным');
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: s.chats, builder: (context, _) => _buildScaffold(context));
  }

  Widget _buildScaffold(BuildContext context) {
    final info = chat;
    final ids = _messages.keys.toList()..sort((a, b) => b.compareTo(a));
    final ghostRead = s.ghost.skipReadReceipts;
    final canWrite = info != null && info.kind != ChatKind.channel;
    final readOutbox = info?.raw['last_read_outbox_message_id'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(info?.title ?? ''),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'read') _markReadNow();
              if (v == 'pin') {
                s.settings.toggleLocalPin(chatId);
                setState(() {});
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'read', child: Text('Отметить прочитанным')),
              PopupMenuItem(
                value: 'pin',
                child: Text(s.chats.isLocallyPinned(chatId) ? 'Открепить (локально)' : 'Закрепить локально'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (ghostRead)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.visibility_off),
                title: const Text('Призрачный режим: собеседник не узнает, что вы прочитали'),
                trailing: TextButton(onPressed: _markReadNow, child: const Text('Прочитать')),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              itemCount: ids.length,
              itemBuilder: (context, i) {
                final m = _messages[ids[i]]!;
                return MessageBubble(
                  message: m,
                  isGroup: info?.kind == ChatKind.group,
                  deleted: _deleted.contains(m['id']),
                  archived: _archived[m['id']],
                  read: m['is_outgoing'] == true && (m['id'] as int) <= readOutbox,
                  rules: s.settings.spam,
                  senderName: s.chats.senderName(m['sender_id'] as Map?),
                );
              },
            ),
          ),
          if (canWrite)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composer,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.send,
                        onChanged: _onTyping,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Сообщение',
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isGroup,
    required this.deleted,
    required this.archived,
    required this.read,
    required this.rules,
    required this.senderName,
  });

  final TdObject message;
  final bool isGroup;
  final bool deleted;
  final ArchivedMessage? archived;
  final bool read;
  final SpamRules rules;
  final String senderName;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final style = ChatStyle.of(context);
    final theme = Theme.of(context);
    final outgoing = m['is_outgoing'] == true;
    final text = contentText(m['content'] as Map);
    final hiddenBy = _revealed ? null : hiddenWordIn(text, widget.rules);
    final edited = (m['edit_date'] as int? ?? 0) > 0 || (widget.archived?.wasEdited ?? false);
    final bg = outgoing ? style.outgoingBubble : style.incomingBubble;
    final fg = outgoing ? style.onOutgoingBubble : style.onIncomingBubble;
    final meta = TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.65));
    final pending = m['sending_state'] != null;

    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Opacity(
          opacity: widget.deleted ? 0.75 : 1,
          child: GestureDetector(
            onLongPress: () => _menu(context, text),
            onTap: hiddenBy != null ? () => setState(() => _revealed = true) : null,
            child: Container(
              margin: EdgeInsets.symmetric(vertical: style.compact ? 1.5 : 3),
              padding: EdgeInsets.fromLTRB(12, style.compact ? 5 : 8, 12, style.compact ? 4 : 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(style.bubbleRadius),
                border: widget.deleted ? Border.all(color: theme.colorScheme.error, width: 1.2) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isGroup && !outgoing && widget.senderName.isNotEmpty)
                    Text(
                      widget.senderName,
                      style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                    ),
                  if (hiddenBy != null)
                    Text(
                      'Скрыто: содержит «$hiddenBy». Нажмите, чтобы показать',
                      style: TextStyle(color: fg, fontStyle: FontStyle.italic),
                    )
                  else
                    Text(text, style: TextStyle(color: fg, fontSize: 15)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.deleted) ...[
                        Icon(Icons.delete_outline, size: 13, color: theme.colorScheme.error),
                        Text(' удалено  ', style: meta.copyWith(color: theme.colorScheme.error)),
                      ],
                      if (edited) Text('изм. ', style: meta),
                      Text(formatTime(m['date'] as int, seconds: style.showSeconds), style: meta),
                      if (outgoing && !widget.deleted)
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Icon(
                            pending ? Icons.schedule : (widget.read ? Icons.done_all : Icons.done),
                            size: 14,
                            color: fg.withValues(alpha: 0.65),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, String text) async {
    final versions = widget.archived?.versions ?? const <MessageVersion>[];
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Копировать'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            if (versions.length > 1)
              ListTile(
                leading: const Icon(Icons.history),
                title: Text('История правок (${versions.length})'),
                onTap: () => Navigator.pop(context, 'history'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: text));
      case 'history':
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('История правок'),
            content: SizedBox(
              width: 400,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final (i, v) in versions.indexed)
                    ListTile(
                      title: SelectableText(v.text),
                      subtitle: Text(
                        i == 0
                            ? 'Оригинал · ${formatTime(v.date)}'
                            : 'Правка $i · ${formatShortDate(v.date)} ${formatTime(v.date)}',
                      ),
                    ),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть'))],
          ),
        );
    }
  }
}
