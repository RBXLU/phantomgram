import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/settings.dart';
import '../../core/td_client.dart';
import '../../core/td_text.dart';

class MessageVersion {
  const MessageVersion(this.text, this.date);

  final String text;
  final int date;
}

class ArchivedMessage {
  ArchivedMessage({
    required this.id,
    required this.chatId,
    required this.date,
    required this.sender,
    required this.senderName,
    required this.outgoing,
    required this.kind,
    required String text,
  }) : versions = [MessageVersion(text, date)];

  final int id;
  final int chatId;
  final int date;

  /// `u<id>` for users, `c<id>` for chats.
  final String sender;
  final String senderName;
  final bool outgoing;
  final String kind;

  /// Oldest first; the last one is the current text.
  final List<MessageVersion> versions;
  int? deletedAt;

  String get text => versions.last.text;
  bool get isDeleted => deletedAt != null;
  bool get wasEdited => versions.length > 1;
}

/// Keeps a local copy of every message the client sees so that deleted
/// messages and previous versions of edited ones stay readable.
///
/// Storage is an append-only JSON-lines log per chat. It only knows about
/// messages that reached this device while the app was running or that were
/// loaded from history: Telegram never sends the content of a message that
/// was deleted before we saw it.
class MessageArchive {
  MessageArchive(Stream<TdObject> updates, this.settings, this.directory) {
    _sub = updates.listen(_onUpdate);
    _flushTimer = Timer.periodic(const Duration(seconds: 2), (_) => flush());
  }

  final AppSettings settings;
  final Directory directory;
  late final StreamSubscription<TdObject> _sub;
  late final Timer _flushTimer;

  final _pending = <int, StringBuffer>{};
  final _loaded = <int, Map<int, ArchivedMessage>>{};
  final _loading = <int, Future<Map<int, ArchivedMessage>>>{};
  final _changes = StreamController<int>.broadcast();

  /// Emits a chat id whenever something in that chat was archived.
  Stream<int> get changes => _changes.stream;

  bool get _enabled => settings.archive.saveDeleted || settings.archive.saveEdits;

  void _onUpdate(TdObject u) {
    if (!_enabled) return;
    switch (u['@type']) {
      case 'updateNewMessage':
        final m = u['message'] as TdObject;
        // Outgoing messages get their real id in updateMessageSendSucceeded.
        if (m['sending_state'] == null) recordMessage(m);
      case 'updateMessageSendSucceeded':
        recordMessage(u['message'] as TdObject);
      case 'updateMessageContent':
        if (!settings.archive.saveEdits) return;
        final content = u['new_content'] as Map;
        _append(u['chat_id'] as int, {
          't': 'e',
          'id': u['message_id'],
          'd': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'x': contentText(content),
        });
      case 'updateDeleteMessages':
        if (!settings.archive.saveDeleted) return;
        // from_cache: TDLib only evicted them locally, nothing was deleted.
        if (u['is_permanent'] != true || u['from_cache'] == true) return;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        for (final id in (u['message_ids'] as List).cast<int>()) {
          _append(u['chat_id'] as int, {'t': 'x', 'id': id, 'd': now});
        }
    }
  }

  void recordMessage(TdObject m, {String? senderName}) {
    if (!_enabled) return;
    final sender = m['sender_id'] as Map?;
    final userId = senderUserId(sender);
    _append(m['chat_id'] as int, {
      't': 'm',
      'id': m['id'],
      'd': m['date'],
      's': userId != null ? 'u$userId' : 'c${senderChatId(sender)}',
      'n': ?senderName,
      'o': m['is_outgoing'] == true,
      'k': contentKind(m['content'] as Map),
      'x': contentText(m['content'] as Map),
    });
  }

  void recordMessages(Iterable<TdObject> messages) {
    for (final m in messages) {
      recordMessage(m);
    }
  }

  void _append(int chatId, Map<String, dynamic> record) {
    (_pending[chatId] ??= StringBuffer()).writeln(jsonEncode(record));
    final loaded = _loaded[chatId];
    if (loaded != null) _apply(loaded, chatId, record);
    if (record['t'] != 'm') _changes.add(chatId);
  }

  File _file(int chatId) => File(p.join(directory.path, '$chatId.jsonl'));

  Future<void> flush() async {
    if (_pending.isEmpty) return;
    final batch = Map.of(_pending);
    _pending.clear();
    await directory.create(recursive: true);
    for (final e in batch.entries) {
      await _file(e.key).writeAsString(e.value.toString(), mode: FileMode.append, flush: true);
    }
  }

  /// Every archived message of a chat, by id.
  Future<Map<int, ArchivedMessage>> chat(int chatId) {
    final loaded = _loaded[chatId];
    if (loaded != null) return Future.value(loaded);
    return _loading[chatId] ??= _load(chatId);
  }

  Future<Map<int, ArchivedMessage>> _load(int chatId) async {
    await flush();
    final messages = <int, ArchivedMessage>{};
    final file = _file(chatId);
    final lines = [
      if (await file.exists()) ...await file.readAsLines(),
      // Records that arrived while the file was being read.
      ...?_pending[chatId]?.toString().split('\n'),
    ];
    for (final line in lines) {
      if (line.isEmpty) continue;
      try {
        _apply(messages, chatId, jsonDecode(line) as Map);
      } catch (_) {
        // A torn last line after a crash; skip it.
      }
    }
    _loaded[chatId] = messages;
    _loading.remove(chatId);
    return messages;
  }

  static void _apply(Map<int, ArchivedMessage> messages, int chatId, Map r) {
    final id = r['id'] as int;
    final existing = messages[id];
    switch (r['t']) {
      case 'm':
        if (existing == null) {
          messages[id] = ArchivedMessage(
            id: id,
            chatId: chatId,
            date: r['d'] as int,
            sender: r['s'] as String,
            senderName: r['n'] as String? ?? '',
            outgoing: r['o'] as bool? ?? false,
            kind: r['k'] as String,
            text: r['x'] as String,
          );
        } else {
          // Seen again with different text: it was edited while we were away.
          _addVersion(existing, r['x'] as String, r['d'] as int);
        }
      case 'e':
        if (existing != null) _addVersion(existing, r['x'] as String, r['d'] as int);
      case 'x':
        existing?.deletedAt ??= r['d'] as int;
    }
  }

  static void _addVersion(ArchivedMessage m, String text, int date) {
    if (m.text != text) m.versions.add(MessageVersion(text, date));
  }

  Future<List<ArchivedMessage>> deletedIn(int chatId) async =>
      (await chat(chatId)).values.where((m) => m.isDeleted).toList()..sort((a, b) => a.id.compareTo(b.id));

  /// Deleted messages across all chats, newest deletion first.
  Future<List<ArchivedMessage>> allDeleted({int limit = 500}) async {
    await flush();
    if (!await directory.exists()) return const [];
    final result = <ArchivedMessage>[];
    await for (final entity in directory.list()) {
      final name = p.basenameWithoutExtension(entity.path);
      final chatId = int.tryParse(name);
      if (chatId == null) continue;
      result.addAll(await deletedIn(chatId));
    }
    result.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return result.take(limit).toList();
  }

  Future<void> clear() async {
    _pending.clear();
    _loaded.clear();
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> dispose() async {
    _flushTimer.cancel();
    await _sub.cancel();
    await flush();
    await _changes.close();
  }
}
