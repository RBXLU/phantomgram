import '../core/td_client.dart';

/// Sample account for the demo mode: a handful of chats that show off every
/// v0.1 feature (deleted and edited messages, local pins, spam in archive).
/// Answers TDLib requests the way the real library would for this data.
class DemoBackend {
  DemoBackend({DateTime? now}) : _now = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;

  final int _now;
  static const myId = 1;
  static const anyaChat = 101;
  static const deletedMessageId = 1004;
  static const editedMessageId = 1005;

  late final _users = <TdObject>[
    _user(myId, 'Максим', contact: false),
    _user(101, 'Аня'),
    _user(102, 'Мама'),
    _user(103, 'Саша', last: 'Петров'),
    _user(104, 'Дима'),
    _user(105, 'Лена'),
    _user(106, 'Олег'),
    _user(201, 'Крипто', last: 'сигналы 🚀', contact: false),
    _user(202, 'Бонус', last: 'Казино', contact: false),
  ];

  late final Map<int, List<TdObject>> _history = {
    anyaChat: [
      _msg(anyaChat, 1001, 'Привет! Ты завтра на презентацию идёшь?', from: 101, ago: 7200),
      _msg(anyaChat, 1002, 'Да, к 10 буду', out: true, ago: 7100),
      _msg(anyaChat, 1003, 'Супер, я займу места в первом ряду', from: 101, ago: 7000),
      _msg(anyaChat, editedMessageId, 'Встречаемся у входа в 9:45', from: 101, ago: 6500, edited: true),
      _msg(anyaChat, 1006, 'Ок, договорились 👍', out: true, ago: 6000),
      _msg(anyaChat, 1007, 'Кстати, как тебе новый клиент?', from: 101, ago: 400),
      _msg(anyaChat, 1008, 'Огонь, призрачный режим вообще топ 👻', out: true, ago: 300),
      _msg(anyaChat, 1009, 'А удалённые сообщения правда видно?', from: 101, ago: 120),
      _msg(anyaChat, 1010, 'Покажи завтра 😄', from: 101, ago: 60),
    ],
    -200: [
      _msg(-200, 2001, 'Всем привет, напоминаю про отчёт к пятнице', from: 104, ago: 5400),
      _msg(-200, 2002, '🖼 Фото Черновик слайдов', from: 105, ago: 4000),
      _msg(-200, 2003, 'Принял, сделаю', out: true, ago: 3900),
      _msg(-200, 2004, 'Созвон перенесли на 15:00', from: 104, ago: 900),
    ],
    -300: [
      _msg(-300, 3001, 'Вышла TDLib 1.8.69: новые методы для прокси и бизнес-аккаунтов', ago: 1800, channel: true),
    ],
    102: [
      _msg(102, 4001, 'Ты поел?', from: 102, ago: 10800),
      _msg(102, 4002, 'Да, всё хорошо. Позвоню вечером', out: true, ago: 10700),
    ],
    -400: [
      _msg(-400, 5001, 'Как там сборка под iOS?', from: 106, ago: 20000),
      _msg(-400, 5002, 'Залил первую версию 🚀', out: true, ago: 19000),
    ],
    103: [_msg(103, 6001, '🎤 Голосовое сообщение', from: 103, ago: 86400)],
    -500: [_msg(-500, 7001, '🖼 Фото Афиша на пятницу', from: 105, ago: 90000)],
    106: [_msg(106, 8001, 'Отправил ключи, проверь', from: 106, ago: 172800)],
    201: [_msg(201, 9001, 'Пассивный доход от 300\$ в день! Пиши в лс t.me/xxx', from: 201, ago: 3000)],
    202: [_msg(202, 9101, 'Тебе бонус 500 FS 🎰 Забирай: bonus-casino.top', from: 202, ago: 50000)],
  };

  late final _chats = <TdObject>[
    _chat(anyaChat, 'Аня', _private(101), order: 900, unread: 2, readOutbox: 1006),
    _chat(-200, 'Работа 💼', _group(), order: 990, unread: 12, muted: true, pinned: true),
    _chat(-300, 'Новости технологий', _channel(), order: 800, unread: 48, muted: true),
    _chat(102, 'Мама', _private(102), order: 700, readOutbox: 4002),
    _chat(-400, 'Phantomgram — разработка', _group(), order: 600, readOutbox: 5002),
    _chat(103, 'Саша Петров', _private(103), order: 500, unread: 1),
    _chat(-500, 'Кино по пятницам', _group(), order: 400),
    _chat(106, 'Олег', {'@type': 'chatTypeSecret', 'secret_chat_id': 7, 'user_id': 106}, order: 300),
    _chat(201, 'Крипто сигналы 🚀', _private(201), order: 200, unread: 1, list: chatListArchive),
    _chat(202, 'Бонус Казино', _private(202), order: 100, unread: 1, list: chatListArchive),
  ];

  /// Pushes the initial state, then replays a deletion and an edit so the
  /// local archive has something to show.
  void seed(TdClient td) {
    td.emit({
      '@type': 'updateOption',
      'name': 'my_id',
      'value': {'@type': 'optionValueInteger', 'value': '$myId'},
    });
    for (final u in _users) {
      td.emit({'@type': 'updateUser', 'user': u});
    }
    for (final c in _chats) {
      td.emit({'@type': 'updateNewChat', 'chat': c});
    }
    td.emit({
      '@type': 'updateConnectionState',
      'state': {'@type': 'connectionStateReady'},
    });

    td.emit({
      '@type': 'updateNewMessage',
      'message': _msg(anyaChat, editedMessageId, 'Встречаемся у входа в 9:30', from: 101, ago: 6500),
    });
    td.emit({
      '@type': 'updateMessageContent',
      'chat_id': anyaChat,
      'message_id': editedMessageId,
      'new_content': _text('Встречаемся у входа в 9:45'),
    });
    td.emit({
      '@type': 'updateNewMessage',
      'message': _msg(anyaChat, deletedMessageId, 'Ой, это не тебе было 🙈', from: 101, ago: 6800),
    });
    td.emit({
      '@type': 'updateDeleteMessages',
      'chat_id': anyaChat,
      'message_ids': [deletedMessageId],
      'is_permanent': true,
      'from_cache': false,
    });
    td.emit({
      '@type': 'updateAuthorizationState',
      'authorization_state': {'@type': 'authorizationStateReady'},
    });
  }

  int _proxyIds = 0;

  TdObject handle(TdObject request) {
    switch (request['@type']) {
      case 'getChatHistory':
        final all = _history[request['chat_id']] ?? const [];
        final from = request['from_message_id'] as int;
        final limit = request['limit'] as int;
        final page = all.reversed.where((m) => from == 0 || (m['id'] as int) <= from).take(limit).toList();
        return {'@type': 'messages', 'total_count': page.length, 'messages': page};
      case 'loadChats':
        return {'@type': 'error', 'code': 404, 'message': 'Not Found'};
      case 'getArchiveChatListSettings':
        return {
          '@type': 'archiveChatListSettings',
          'archive_and_mute_new_chats_from_unknown_users': true,
          'keep_unmuted_chats_archived': false,
          'keep_chats_from_folders_archived': false,
        };
      case 'getProxies':
        return {'@type': 'addedProxies', 'proxies': <dynamic>[]};
      case 'addProxy':
        return {'@type': 'addedProxy', 'id': ++_proxyIds};
      case 'getUser':
        return _users.firstWhere((u) => u['id'] == request['user_id']);
      case 'sendMessage':
        final chatId = request['chat_id'] as int;
        final text = ((request['input_message_content'] as Map)['text'] as Map)['text'] as String;
        return _msg(chatId, 99000 + _proxyIds++, text, out: true, ago: 0);
      default:
        return {'@type': 'ok'};
    }
  }

  static TdObject _user(int id, String first, {String last = '', bool contact = true}) => {
    '@type': 'user',
    'id': id,
    'first_name': first,
    'last_name': last,
    'is_contact': contact,
    'type': {'@type': 'userTypeRegular'},
    'verification_status': null,
  };

  static TdObject _private(int userId) => {'@type': 'chatTypePrivate', 'user_id': userId};
  static TdObject _group() => {'@type': 'chatTypeSupergroup', 'supergroup_id': 1, 'is_channel': false};
  static TdObject _channel() => {'@type': 'chatTypeSupergroup', 'supergroup_id': 2, 'is_channel': true};

  static TdObject _text(String text) => {'@type': 'messageText', 'text': formattedText(text)};

  TdObject _msg(
    int chatId,
    int id,
    String text, {
    int? from,
    bool out = false,
    required int ago,
    bool edited = false,
    bool channel = false,
  }) {
    final TdObject content = text.startsWith('🖼 Фото ')
        ? {'@type': 'messagePhoto', 'caption': formattedText(text.replaceFirst('🖼 Фото ', ''))}
        : text.startsWith('🎤')
        ? {'@type': 'messageVoiceNote', 'caption': formattedText('')}
        : _text(text);
    return {
      '@type': 'message',
      'id': id,
      'chat_id': chatId,
      'date': _now - ago,
      'edit_date': edited ? _now - ago + 120 : 0,
      'is_outgoing': out,
      'is_channel_post': channel,
      'sending_state': null,
      'sender_id': channel
          ? {'@type': 'messageSenderChat', 'chat_id': chatId}
          : {'@type': 'messageSenderUser', 'user_id': out ? myId : from ?? chatId},
      'content': content,
    };
  }

  TdObject _chat(
    int id,
    String title,
    TdObject type, {
    required int order,
    int unread = 0,
    int readOutbox = 0,
    bool muted = false,
    bool pinned = false,
    TdObject list = chatListMain,
  }) => {
    '@type': 'chat',
    'id': id,
    'title': title,
    'type': type,
    'photo': null,
    'unread_count': unread,
    'last_read_outbox_message_id': readOutbox,
    'is_marked_as_unread': false,
    'unread_mention_count': 0,
    'notification_settings': {'mute_for': muted ? 2147483647 : 0},
    'last_message': (_history[id] ?? const []).lastOrNull,
    'positions': [
      {'@type': 'chatPosition', 'list': list, 'order': '$order', 'is_pinned': pinned},
    ],
  };
}
