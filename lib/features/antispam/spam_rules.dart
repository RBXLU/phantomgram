/// User-configurable anti-spam rules. Pure data + evaluation, no TDLib.
class SpamRules {
  SpamRules({
    this.enabled = true,
    this.serverAutoArchive = true,
    this.strangerLinks = true,
    this.strangerNoPhoto = false,
    this.scamFake = true,
    List<String>? keywords,
    List<String>? hiddenWords,
  }) : keywords = keywords ?? List.of(defaultSpamKeywords),
       hiddenWords = hiddenWords ?? [];

  bool enabled;

  /// Telegram's own "archive and mute new chats from non-contacts".
  bool serverAutoArchive;
  bool strangerLinks;
  bool strangerNoPhoto;
  bool scamFake;
  List<String> keywords;

  /// Messages containing these words are collapsed in every chat.
  List<String> hiddenWords;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'serverAutoArchive': serverAutoArchive,
    'strangerLinks': strangerLinks,
    'strangerNoPhoto': strangerNoPhoto,
    'scamFake': scamFake,
    'keywords': keywords,
    'hiddenWords': hiddenWords,
  };

  static SpamRules fromJson(Map json) => SpamRules(
    enabled: json['enabled'] as bool? ?? true,
    serverAutoArchive: json['serverAutoArchive'] as bool? ?? true,
    strangerLinks: json['strangerLinks'] as bool? ?? true,
    strangerNoPhoto: json['strangerNoPhoto'] as bool? ?? false,
    scamFake: json['scamFake'] as bool? ?? true,
    keywords: (json['keywords'] as List?)?.cast<String>(),
    hiddenWords: (json['hiddenWords'] as List?)?.cast<String>(),
  );
}

const defaultSpamKeywords = [
  'заработ',
  'инвестиц',
  'пассивный доход',
  'казино',
  'ставки',
  'букмекер',
  'выиграл',
  'розыгрыш',
  'airdrop',
  'giveaway',
  'onlyfans',
  'интим',
  'знакомства',
  'удаленная работа',
  'удалённая работа',
  'перейди по ссылке',
];

/// What we know about the first messages of a new private chat.
class SpamCandidate {
  const SpamCandidate({
    required this.text,
    required this.isContact,
    required this.hasProfilePhoto,
    required this.isScam,
    required this.isFake,
    required this.isBot,
    required this.hasOutgoingMessages,
  });

  /// Message text including hidden link targets.
  final String text;
  final bool isContact;
  final bool hasProfilePhoto;
  final bool isScam;
  final bool isFake;
  final bool isBot;

  /// We wrote to them before: never treat as spam.
  final bool hasOutgoingMessages;
}

final _urlPattern = RegExp(
  r'(https?://|www\.|t\.me/|tg://|\b[a-z0-9-]+\.(ru|com|net|org|io|xyz|top|site|online|shop|me|info|cc|ly)\b)',
  caseSensitive: false,
);

/// Returns the reasons the chat looks like spam, or an empty list.
List<String> evaluateSpam(SpamCandidate c, SpamRules rules) {
  if (!rules.enabled || c.isContact || c.isBot || c.hasOutgoingMessages) {
    return const [];
  }
  final reasons = <String>[];
  if (rules.scamFake && (c.isScam || c.isFake)) {
    reasons.add(c.isScam ? 'помечен Telegram как SCAM' : 'помечен Telegram как FAKE');
  }
  final lower = c.text.toLowerCase();
  for (final k in rules.keywords) {
    final word = k.trim().toLowerCase();
    if (word.isNotEmpty && lower.contains(word)) {
      reasons.add('стоп-слово «$word»');
      break;
    }
  }
  if (rules.strangerLinks && _urlPattern.hasMatch(c.text)) {
    reasons.add('ссылка от незнакомца');
  }
  if (rules.strangerNoPhoto && !c.hasProfilePhoto) {
    reasons.add('незнакомец без аватарки');
  }
  return reasons;
}

/// Whether a message should be collapsed because of [SpamRules.hiddenWords].
String? hiddenWordIn(String text, SpamRules rules) {
  if (rules.hiddenWords.isEmpty) return null;
  final lower = text.toLowerCase();
  for (final w in rules.hiddenWords) {
    final word = w.trim().toLowerCase();
    if (word.isNotEmpty && lower.contains(word)) return word;
  }
  return null;
}
