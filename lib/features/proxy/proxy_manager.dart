import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/settings.dart';
import '../../core/td_client.dart';
import '../../core/td_text.dart';
import 'proxy_link.dart';
import 'proxy_ranking.dart';

/// Keeps the best MTProto proxies active.
///
/// Every [ProxySettings.intervalMinutes] (one hour by default) it gathers
/// candidates from the user's sources, pings each one several times through
/// TDLib, keeps the top [ProxySettings.topCount] by [proxyScore] and enables
/// the best. If the active proxy stops connecting, it fails over to the next
/// one in the top list; when the whole list is dead it re-selects early.
///
/// MTProxy has no way to download a test file outside Telegram itself, so
/// "speed" is judged from round-trip time, jitter and packet loss — the
/// things that actually limit throughput through a shared proxy.
class ProxyManager extends ChangeNotifier {
  ProxyManager(this.td, this.settings, {http.Client? httpClient, DateTime Function()? clock})
    : _http = httpClient ?? http.Client(),
      _now = clock ?? DateTime.now;

  static const _comment = 'phantomgram-auto';
  static const pingsPerProxy = 3;
  static const pingTimeout = Duration(seconds: 5);
  static const maxCandidates = 200;
  static const parallelPings = 12;
  static const failoverAfter = Duration(seconds: 20);

  final TdClient td;
  final AppSettings settings;
  final http.Client _http;
  final DateTime Function() _now;

  Timer? _tick;
  Timer? _failoverTimer;
  StreamSubscription<TdObject>? _connSub;
  final _tdIds = <String, int>{};
  int _failoversSinceReady = 0;

  bool busy = false;
  int progressDone = 0;
  int progressTotal = 0;
  String? lastError;
  int lastCandidateCount = 0;

  ProxySettings get _cfg => settings.proxy;
  List<ProxyScore> get selected => _cfg.selected;
  int get activeIndex => _cfg.activeIndex;

  void start() {
    _tick ??= Timer.periodic(const Duration(minutes: 1), (_) => _maybeRotate());
    _connSub ??= td.on('updateConnectionState').listen(_onConnectionState);
    if (_cfg.autoEnabled) {
      if (_cfg.selected.isNotEmpty) unawaited(_applyToTdlib());
      _maybeRotate();
    }
  }

  void _maybeRotate() {
    if (!_cfg.autoEnabled || busy) return;
    if (rotationDue(
      lastRotation: _cfg.lastRotation,
      now: _now(),
      interval: Duration(minutes: _cfg.intervalMinutes),
    )) {
      unawaited(rotate());
    }
  }

  Future<void> setAutoEnabled(bool enabled) async {
    settings.update((s) => s.proxy.autoEnabled = enabled);
    if (enabled) {
      await rotate();
    } else {
      await _removeAutoProxies();
      await td.send({'@type': 'disableProxy'}).catchError((Object _) => const <String, dynamic>{});
    }
    notifyListeners();
  }

  /// Re-scans sources, measures every candidate and installs the new top list.
  Future<void> rotate() async {
    if (busy) return;
    busy = true;
    lastError = null;
    progressDone = 0;
    progressTotal = 0;
    notifyListeners();
    try {
      final candidates = await collectCandidates();
      lastCandidateCount = candidates.length;
      if (candidates.isEmpty) {
        lastError = 'Не найдено ни одного прокси. Добавьте источники или ссылки.';
        return;
      }
      final measurements = await _measureAll(candidates);
      final top = rankProxies(measurements, top: _cfg.topCount);
      if (top.isEmpty) {
        lastError = 'Ни один из ${candidates.length} прокси не ответил. Оставлены прежние.';
        return;
      }
      settings.update((s) {
        s.proxy.selected = top;
        s.proxy.activeIndex = 0;
        s.proxy.lastRotation = _now();
      });
      await _applyToTdlib();
    } catch (e) {
      lastError = 'Ошибка подбора: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<List<ProxyLink>> collectCandidates() async {
    final found = <ProxyLink>{};
    for (final link in _cfg.manualLinks) {
      found.addAll(extractProxyLinks(link));
    }
    // Previous winners compete again, so a good proxy is not lost just
    // because its source went offline.
    found.addAll(_cfg.selected.map((s) => s.link));
    for (final source in _cfg.sources) {
      try {
        final text = isChannelSource(source) ? await _fetchChannel(channelUsername(source)) : await _fetchUrl(source);
        found.addAll(extractProxyLinks(text));
      } catch (e) {
        debugPrint('Proxy source $source failed: $e');
      }
    }
    return found.take(maxCandidates).toList();
  }

  Future<String> _fetchUrl(String url) async {
    final response = await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    return response.body;
  }

  /// Text, hidden links and button URLs of a channel's recent posts.
  Future<String> _fetchChannel(String username) async {
    final chat = await td.send({'@type': 'searchPublicChat', 'username': username});
    final chatId = chat['id'] as int;
    final buffer = StringBuffer();
    var fromId = 0;
    var seen = 0;
    while (seen < 100) {
      final page = await td.send({
        '@type': 'getChatHistory',
        'chat_id': chatId,
        'from_message_id': fromId,
        'offset': 0,
        'limit': 50,
        'only_local': false,
      });
      final messages = ((page['messages'] as List?) ?? const []).cast<TdObject>();
      if (messages.isEmpty) break;
      for (final m in messages) {
        buffer.writeln(searchableContentText(m['content'] as Map));
        for (final url in _buttonUrls(m['reply_markup'] as Map?)) {
          buffer.writeln(url);
        }
      }
      seen += messages.length;
      fromId = messages.last['id'] as int;
    }
    return buffer.toString();
  }

  static Iterable<String> _buttonUrls(Map? markup) sync* {
    if (markup?['@type'] != 'replyMarkupInlineKeyboard') return;
    for (final row in (markup!['rows'] as List?) ?? const []) {
      for (final button in row as List) {
        final type = (button as Map)['type'] as Map?;
        if (type?['@type'] == 'inlineKeyboardButtonTypeUrl') yield type!['url'] as String;
      }
    }
  }

  Future<List<ProxyMeasurement>> _measureAll(List<ProxyLink> links) async {
    progressTotal = links.length;
    notifyListeners();
    final results = <ProxyMeasurement>[];
    var next = 0;
    Future<void> worker() async {
      while (next < links.length) {
        final link = links[next++];
        results.add(await _measure(link));
        progressDone++;
        notifyListeners();
      }
    }

    await Future.wait(List.generate(parallelPings, (_) => worker()));
    return results;
  }

  Future<ProxyMeasurement> _measure(ProxyLink link) async {
    final pings = <double?>[];
    for (var i = 0; i < pingsPerProxy; i++) {
      try {
        final r = await td.send({'@type': 'pingProxy', 'proxy': link.toTd()}, timeout: pingTimeout);
        pings.add((r['seconds'] as num).toDouble() * 1000);
      } catch (_) {
        pings.add(null);
        // A proxy that does not answer the first ping rarely recovers; do
        // not spend two more timeouts on it.
        if (i == 0) {
          pings.addAll(List.filled(pingsPerProxy - 1, null));
          break;
        }
      }
    }
    return ProxyMeasurement(link, pings);
  }

  Future<void> _removeAutoProxies() async {
    try {
      final added = await td.send({'@type': 'getProxies'});
      for (final p in (added['proxies'] as List?) ?? const []) {
        if ((p as Map)['comment'] == _comment) {
          await td.send({'@type': 'removeProxy', 'proxy_id': p['id']});
        }
      }
    } on TdError {
      // Nothing to clean up.
    }
    _tdIds.clear();
  }

  Future<void> _applyToTdlib() async {
    await _removeAutoProxies();
    final top = _cfg.selected;
    for (var i = 0; i < top.length; i++) {
      final added = await td.send({
        '@type': 'addProxy',
        'proxy': top[i].link.toTd(),
        'enable': i == _cfg.activeIndex,
        'comment': _comment,
      });
      _tdIds[top[i].link.key] = added['id'] as int;
    }
    _failoversSinceReady = 0;
    notifyListeners();
  }

  void _onConnectionState(TdObject u) {
    final state = (u['state'] as Map)['@type'];
    if (state == 'connectionStateReady') {
      _failoverTimer?.cancel();
      _failoverTimer = null;
      _failoversSinceReady = 0;
    } else if (state == 'connectionStateConnectingToProxy' && _cfg.autoEnabled && _failoverTimer == null) {
      _failoverTimer = Timer(failoverAfter, () {
        _failoverTimer = null;
        unawaited(switchToNext());
      });
    }
  }

  /// Enables the next proxy of the top list; re-selects if all of them failed.
  Future<void> switchToNext() async {
    final top = _cfg.selected;
    if (top.isEmpty) return;
    _failoversSinceReady++;
    if (_failoversSinceReady >= top.length) {
      await rotate();
      return;
    }
    await activate(nextProxyIndex(_cfg.activeIndex, top.length));
  }

  Future<void> activate(int index) async {
    final top = _cfg.selected;
    if (index < 0 || index >= top.length) return;
    settings.update((s) => s.proxy.activeIndex = index);
    final id = _tdIds[top[index].link.key];
    if (id == null) {
      await _applyToTdlib();
    } else {
      await td.send({'@type': 'enableProxy', 'proxy_id': id});
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _failoverTimer?.cancel();
    _connSub?.cancel();
    _http.close();
    super.dispose();
  }
}

bool isChannelSource(String source) {
  final s = source.trim();
  return s.startsWith('@') || RegExp(r'^https?://(t|telegram)\.me/(?!proxy)[A-Za-z0-9_]+/?$').hasMatch(s);
}

String channelUsername(String source) {
  final s = source.trim();
  if (s.startsWith('@')) return s.substring(1);
  return Uri.parse(s).pathSegments.firstWhere((seg) => seg.isNotEmpty);
}
