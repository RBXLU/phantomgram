import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phantomgram/core/settings.dart';
import 'package:phantomgram/core/td_client.dart';
import 'package:phantomgram/features/archive/message_archive.dart';

TdObject _msg(int id, String text, {int chat = 1, Object? sending}) => {
  '@type': 'message',
  'id': id,
  'chat_id': chat,
  'date': 1700000000 + id,
  'is_outgoing': false,
  'sending_state': sending,
  'sender_id': {'@type': 'messageSenderUser', 'user_id': 42},
  'content': {'@type': 'messageText', 'text': formattedText(text)},
};

void main() {
  late Directory dir;
  late StreamController<TdObject> updates;
  late AppSettings settings;
  late MessageArchive archive;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('archive_test');
    updates = StreamController<TdObject>.broadcast(sync: true);
    settings = AppSettings.memory();
    archive = MessageArchive(updates.stream, settings, dir);
  });

  tearDown(() async {
    await archive.dispose();
    await updates.close();
    await dir.delete(recursive: true);
  });

  test('keeps deleted messages and edit history across restarts', () async {
    updates.add({'@type': 'updateNewMessage', 'message': _msg(10, 'первая версия')});
    updates.add({'@type': 'updateNewMessage', 'message': _msg(11, 'останется')});
    updates.add({
      '@type': 'updateMessageContent',
      'chat_id': 1,
      'message_id': 10,
      'new_content': {'@type': 'messageText', 'text': formattedText('вторая версия')},
    });
    updates.add({
      '@type': 'updateDeleteMessages',
      'chat_id': 1,
      'message_ids': [10],
      'is_permanent': true,
      'from_cache': false,
    });
    // Cache eviction is not a deletion.
    updates.add({
      '@type': 'updateDeleteMessages',
      'chat_id': 1,
      'message_ids': [11],
      'is_permanent': false,
      'from_cache': true,
    });
    await archive.dispose();

    final reopened = MessageArchive(const Stream.empty(), settings, dir);
    final chat = await reopened.chat(1);
    expect(chat[10]!.isDeleted, isTrue);
    expect(chat[10]!.versions.map((v) => v.text), ['первая версия', 'вторая версия']);
    expect(chat[11]!.isDeleted, isFalse);
    expect((await reopened.allDeleted()).map((m) => m.id), [10]);
    await reopened.dispose();
    archive = MessageArchive(const Stream.empty(), settings, dir);
  });

  test('pending outgoing messages are recorded only after send succeeded', () async {
    updates.add({
      '@type': 'updateNewMessage',
      'message': _msg(-1, 'hi', sending: {'@type': 'messageSendingStatePending'}),
    });
    updates.add({'@type': 'updateMessageSendSucceeded', 'old_message_id': -1, 'message': _msg(20, 'hi')});
    final chat = await archive.chat(1);
    expect(chat.keys, [20]);
  });

  test('a message seen again with other text counts as edited', () async {
    archive.recordMessage(_msg(30, 'до'));
    await archive.flush();
    archive.recordMessage(_msg(30, 'после'));
    final chat = await archive.chat(1);
    expect(chat[30]!.wasEdited, isTrue);
    expect(chat[30]!.text, 'после');
  });

  test('does nothing when both options are off', () async {
    settings.archive
      ..saveDeleted = false
      ..saveEdits = false;
    updates.add({'@type': 'updateNewMessage', 'message': _msg(40, 'x')});
    expect(await archive.chat(1), isEmpty);
  });
}
