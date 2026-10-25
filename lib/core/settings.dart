import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/antispam/spam_rules.dart';
import '../features/proxy/proxy_ranking.dart';

class GhostSettings {
  bool enabled = false;
  bool hideOnline = true;
  bool noReadReceipts = true;
  bool hideTyping = true;
  bool offlineAfterSend = true;

  bool get shouldHideOnline => enabled && hideOnline;
  bool get shouldSkipRead => enabled && noReadReceipts;
  bool get shouldHideTyping => enabled && hideTyping;
  bool get shouldGoOfflineAfterSend => shouldHideOnline && offlineAfterSend;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'hideOnline': hideOnline,
    'noReadReceipts': noReadReceipts,
    'hideTyping': hideTyping,
    'offlineAfterSend': offlineAfterSend,
  };

  void load(Map json) {
    enabled = json['enabled'] as bool? ?? enabled;
    hideOnline = json['hideOnline'] as bool? ?? hideOnline;
    noReadReceipts = json['noReadReceipts'] as bool? ?? noReadReceipts;
    hideTyping = json['hideTyping'] as bool? ?? hideTyping;
    offlineAfterSend = json['offlineAfterSend'] as bool? ?? offlineAfterSend;
  }
}

class ArchiveSettings {
  bool saveDeleted = true;
  bool saveEdits = true;

  Map<String, dynamic> toJson() => {'saveDeleted': saveDeleted, 'saveEdits': saveEdits};

  void load(Map json) {
    saveDeleted = json['saveDeleted'] as bool? ?? saveDeleted;
    saveEdits = json['saveEdits'] as bool? ?? saveEdits;
  }
}

class ProxySettings {
  bool autoEnabled = false;

  /// http(s) URLs of proxy lists, or `@channel` usernames.
  List<String> sources = [];
  List<String> manualLinks = [];
  int intervalMinutes = 60;
  int topCount = 5;
  List<ProxyScore> selected = [];
  int activeIndex = 0;
  DateTime? lastRotation;

  Map<String, dynamic> toJson() => {
    'autoEnabled': autoEnabled,
    'sources': sources,
    'manualLinks': manualLinks,
    'intervalMinutes': intervalMinutes,
    'topCount': topCount,
    'selected': selected.map((s) => s.toJson()).toList(),
    'activeIndex': activeIndex,
    'lastRotation': lastRotation?.millisecondsSinceEpoch,
  };

  void load(Map json) {
    autoEnabled = json['autoEnabled'] as bool? ?? autoEnabled;
    sources = (json['sources'] as List?)?.cast<String>() ?? sources;
    manualLinks = (json['manualLinks'] as List?)?.cast<String>() ?? manualLinks;
    intervalMinutes = json['intervalMinutes'] as int? ?? intervalMinutes;
    topCount = json['topCount'] as int? ?? topCount;
    selected = [for (final s in (json['selected'] as List?) ?? const []) ProxyScore.fromJson(s as Map)];
    activeIndex = json['activeIndex'] as int? ?? 0;
    final last = json['lastRotation'] as int?;
    lastRotation = last == null ? null : DateTime.fromMillisecondsSinceEpoch(last);
  }
}

enum ThemeModeSetting { system, light, dark }

class ThemeSettings {
  ThemeModeSetting mode = ThemeModeSetting.system;
  int seedColor = 0xFF2AABEE;

  /// null: derived from [seedColor].
  int? outgoingBubbleColor;
  double bubbleRadius = 16;
  double fontScale = 1.0;
  bool compact = false;
  bool showSeconds = false;
  bool amoled = false;

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'seedColor': seedColor,
    'outgoingBubbleColor': outgoingBubbleColor,
    'bubbleRadius': bubbleRadius,
    'fontScale': fontScale,
    'compact': compact,
    'showSeconds': showSeconds,
    'amoled': amoled,
  };

  void load(Map json) {
    mode = ThemeModeSetting.values.asNameMap()[json['mode']] ?? mode;
    seedColor = json['seedColor'] as int? ?? seedColor;
    outgoingBubbleColor = json['outgoingBubbleColor'] as int?;
    bubbleRadius = (json['bubbleRadius'] as num?)?.toDouble() ?? bubbleRadius;
    fontScale = (json['fontScale'] as num?)?.toDouble() ?? fontScale;
    compact = json['compact'] as bool? ?? compact;
    showSeconds = json['showSeconds'] as bool? ?? showSeconds;
    amoled = json['amoled'] as bool? ?? amoled;
  }
}

class SpamLogEntry {
  SpamLogEntry({required this.chatId, required this.title, required this.reasons, required this.date});

  final int chatId;
  final String title;
  final List<String> reasons;
  final DateTime date;

  Map<String, dynamic> toJson() => {
    'chatId': chatId,
    'title': title,
    'reasons': reasons,
    'date': date.millisecondsSinceEpoch,
  };

  static SpamLogEntry fromJson(Map json) => SpamLogEntry(
    chatId: json['chatId'] as int,
    title: json['title'] as String,
    reasons: (json['reasons'] as List).cast<String>(),
    date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
  );
}

/// Every user setting, persisted as one JSON blob.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  static const _key = 'phantomgram.settings.v1';
  static const maxSpamLog = 200;

  final SharedPreferences? _prefs;

  int? apiId;
  String? apiHash;
  final ghost = GhostSettings();
  final archive = ArchiveSettings();
  var spam = SpamRules();
  final proxy = ProxySettings();
  final theme = ThemeSettings();

  /// Chat ids pinned on this device only, in display order. No limit.
  List<int> localPins = [];
  List<SpamLogEntry> spamLog = [];

  /// In-memory settings for tests.
  factory AppSettings.memory() => AppSettings._(null);

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings._(prefs);
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        settings._fromJson(jsonDecode(raw) as Map);
      } catch (e) {
        debugPrint('Settings are corrupted, using defaults: $e');
      }
    }
    return settings;
  }

  bool get hasApiCredentials => apiId != null && (apiHash?.isNotEmpty ?? false);

  void _fromJson(Map json) {
    apiId = json['apiId'] as int?;
    apiHash = json['apiHash'] as String?;
    ghost.load(json['ghost'] as Map? ?? const {});
    archive.load(json['archive'] as Map? ?? const {});
    if (json['spam'] is Map) spam = SpamRules.fromJson(json['spam'] as Map);
    proxy.load(json['proxy'] as Map? ?? const {});
    theme.load(json['theme'] as Map? ?? const {});
    localPins = (json['localPins'] as List?)?.cast<int>() ?? [];
    spamLog = [for (final e in (json['spamLog'] as List?) ?? const []) SpamLogEntry.fromJson(e as Map)];
  }

  Map<String, dynamic> toJson() => {
    'apiId': apiId,
    'apiHash': apiHash,
    'ghost': ghost.toJson(),
    'archive': archive.toJson(),
    'spam': spam.toJson(),
    'proxy': proxy.toJson(),
    'theme': theme.toJson(),
    'localPins': localPins,
    'spamLog': spamLog.map((e) => e.toJson()).toList(),
  };

  /// Applies [change], persists and notifies listeners.
  void update(void Function(AppSettings s) change) {
    change(this);
    _prefs?.setString(_key, jsonEncode(toJson()));
    notifyListeners();
  }

  void toggleLocalPin(int chatId) => update((s) {
    if (!s.localPins.remove(chatId)) s.localPins.insert(0, chatId);
  });

  void addSpamLog(SpamLogEntry entry) => update((s) {
    s.spamLog.insert(0, entry);
    if (s.spamLog.length > maxSpamLog) s.spamLog.removeRange(maxSpamLog, s.spamLog.length);
  });
}
