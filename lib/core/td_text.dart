import 'td_client.dart';

/// Short kind name for a MessageContent, used in the archive and previews.
String contentKind(Map content) {
  final type = content['@type'] as String? ?? '';
  return type.startsWith('message') ? type.substring(7) : type;
}

/// Human-readable text for a MessageContent (Russian UI labels).
String contentText(Map content) {
  String caption() {
    final c = content['caption'];
    return c is Map ? (c['text'] as String? ?? '') : '';
  }

  String withLabel(String label) {
    final c = caption();
    return c.isEmpty ? label : '$label $c';
  }

  switch (content['@type']) {
    case 'messageText':
      return (content['text'] as Map?)?['text'] as String? ?? '';
    case 'messagePhoto':
      return withLabel('🖼 Фото');
    case 'messageVideo':
      return withLabel('🎬 Видео');
    case 'messageAnimation':
      return withLabel('GIF');
    case 'messageDocument':
      final name = (content['document'] as Map?)?['file_name'] as String?;
      return withLabel('📎 ${name ?? 'Файл'}');
    case 'messageAudio':
      final audio = content['audio'] as Map?;
      final title = audio?['title'] as String? ?? '';
      return withLabel('🎵 ${title.isEmpty ? 'Аудио' : title}');
    case 'messageVoiceNote':
      return withLabel('🎤 Голосовое сообщение');
    case 'messageVideoNote':
      return '⏺ Видеосообщение';
    case 'messageSticker':
      final emoji = (content['sticker'] as Map?)?['emoji'] as String? ?? '';
      return '$emoji Стикер'.trim();
    case 'messageLocation':
      return '📍 Геопозиция';
    case 'messageContact':
      final c = content['contact'] as Map?;
      return '👤 ${c?['first_name'] ?? ''} ${c?['phone_number'] ?? ''}'.trim();
    case 'messagePoll':
      final q = (content['poll'] as Map?)?['question'];
      final text = q is Map ? q['text'] : q;
      return '📊 ${text ?? 'Опрос'}';
    case 'messageCall':
      return '📞 Звонок';
    case 'messageChatAddMembers':
      return 'добавил(а) участников';
    case 'messageChatJoinByLink':
      return 'присоединился(-ась) по ссылке';
    case 'messageChatDeleteMember':
      return 'покинул(а) чат';
    case 'messagePinMessage':
      return '📌 закрепил(а) сообщение';
    case 'messageChatChangeTitle':
      return 'изменил(а) название чата';
    case 'messageChatChangePhoto':
      return 'изменил(а) фото чата';
    case 'messageContactRegistered':
      return 'теперь в Telegram';
    case 'messageUnsupported':
      return 'Сообщение не поддерживается';
    default:
      return contentKind(content);
  }
}

/// All URLs in a formatted text: plain links plus hidden text-link targets.
List<String> formattedTextUrls(Map? text) {
  if (text == null) return const [];
  final raw = text['text'] as String? ?? '';
  final urls = <String>[];
  for (final e in (text['entities'] as List?) ?? const []) {
    final type = (e as Map)['type'] as Map?;
    if (type == null) continue;
    if (type['@type'] == 'textEntityTypeTextUrl') {
      urls.add(type['url'] as String);
    } else if (type['@type'] == 'textEntityTypeUrl') {
      urls.add(_slice(raw, e['offset'] as int, e['length'] as int));
    }
  }
  return urls;
}

/// TDLib offsets are in UTF-16 code units, which is what Dart strings use.
String _slice(String s, int offset, int length) {
  final end = offset + length;
  if (offset < 0 || end > s.length) return '';
  return s.substring(offset, end);
}

/// Plain text plus every link target in a MessageContent.
String searchableContentText(Map content) {
  final parts = <String>[contentText(content)];
  final text = content['text'] ?? content['caption'];
  if (text is Map) parts.addAll(formattedTextUrls(text));
  return parts.join('\n');
}

int? senderUserId(Map? sender) => sender?['@type'] == 'messageSenderUser' ? sender!['user_id'] as int : null;

int? senderChatId(Map? sender) => sender?['@type'] == 'messageSenderChat' ? sender!['chat_id'] as int : null;

TdObject inputText(String text) => {'@type': 'inputMessageText', 'text': formattedText(text)};

String userDisplayName(Map? user) {
  if (user == null) return '';
  final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
  return name.isEmpty ? 'Удалённый аккаунт' : name;
}

String formatTime(int unixSeconds, {bool seconds = false}) {
  final d = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  String two(int v) => v.toString().padLeft(2, '0');
  final hm = '${two(d.hour)}:${two(d.minute)}';
  return seconds ? '$hm:${two(d.second)}' : hm;
}

/// "22:17" for today, "24.10 22:17" otherwise.
String formatDateTime(int unixSeconds, {DateTime? now}) {
  final date = formatShortDate(unixSeconds, now: now);
  final time = formatTime(unixSeconds);
  return date == time ? time : '$date $time';
}

/// Time for today, day.month otherwise (chat list style).
String formatShortDate(int unixSeconds, {DateTime? now}) {
  final d = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  final n = now ?? DateTime.now();
  if (d.year == n.year && d.month == n.month && d.day == n.day) {
    return formatTime(unixSeconds);
  }
  String two(int v) => v.toString().padLeft(2, '0');
  return d.year == n.year ? '${two(d.day)}.${two(d.month)}' : '${two(d.day)}.${two(d.month)}.${d.year % 100}';
}

const _monthsGenitive = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// Date separator in a chat: "Сегодня", "Вчера", "24 октября", "8 марта 2025".
String formatDayHeader(int unixSeconds, {DateTime? now}) {
  final d = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  final n = now ?? DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  final base = '${d.day} ${_monthsGenitive[d.month - 1]}';
  return d.year == n.year ? base : '$base ${d.year}';
}

bool sameDay(int a, int b) {
  final x = DateTime.fromMillisecondsSinceEpoch(a * 1000);
  final y = DateTime.fromMillisecondsSinceEpoch(b * 1000);
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// "в сети", "был(а) в 21:40", "был(а) недавно" for a TDLib UserStatus.
String userStatusText(Map? status, {DateTime? now}) => switch (status?['@type']) {
  'userStatusOnline' => 'в сети',
  'userStatusOffline' => _lastSeen(status!['was_online'] as int? ?? 0, now ?? DateTime.now()),
  'userStatusRecently' => 'был(а) недавно',
  'userStatusLastWeek' => 'был(а) на этой неделе',
  'userStatusLastMonth' => 'был(а) в этом месяце',
  _ => 'был(а) давно',
};

String _lastSeen(int unixSeconds, DateTime now) {
  final header = formatDayHeader(unixSeconds, now: now);
  final time = formatTime(unixSeconds);
  return switch (header) {
    'Сегодня' => 'был(а) в $time',
    'Вчера' => 'был(а) вчера в $time',
    _ => 'был(а) $header',
  };
}

/// "+7 999 123-45-67" for Russian/Kazakh numbers, "+" and the bare digits otherwise.
String formatPhone(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11 && d.startsWith('7')) {
    return '+7 ${d.substring(1, 4)} ${d.substring(4, 7)}-${d.substring(7, 9)}-${d.substring(9)}';
  }
  return '+$d';
}
