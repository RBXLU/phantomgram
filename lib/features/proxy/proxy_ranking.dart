import 'dart:math' as math;

import 'proxy_link.dart';

/// Result of pinging one proxy several times. `null` entries are failures.
class ProxyMeasurement {
  ProxyMeasurement(this.link, this.pingsMs);

  final ProxyLink link;
  final List<double?> pingsMs;

  List<double> get _ok => pingsMs.whereType<double>().toList()..sort();

  double get successRate => pingsMs.isEmpty ? 0 : _ok.length / pingsMs.length;

  double? get medianMs {
    final ok = _ok;
    if (ok.isEmpty) return null;
    final mid = ok.length ~/ 2;
    return ok.length.isOdd ? ok[mid] : (ok[mid - 1] + ok[mid]) / 2;
  }

  /// Spread of round trips; high jitter means an unstable, congested link.
  double get jitterMs {
    final ok = _ok;
    if (ok.length < 2) return 0;
    return ok.last - ok.first;
  }
}

/// A proxy that made it into the top list.
class ProxyScore {
  const ProxyScore({
    required this.link,
    required this.pingMs,
    required this.jitterMs,
    required this.successRate,
    required this.score,
  });

  final ProxyLink link;
  final double pingMs;
  final double jitterMs;
  final double successRate;

  /// Lower is better.
  final double score;

  Map<String, dynamic> toJson() => {
    'link': link.toJson(),
    'ping': pingMs,
    'jitter': jitterMs,
    'success': successRate,
    'score': score,
  };

  static ProxyScore fromJson(Map json) => ProxyScore(
    link: ProxyLink.fromJson(json['link'] as Map),
    pingMs: (json['ping'] as num).toDouble(),
    jitterMs: (json['jitter'] as num).toDouble(),
    successRate: (json['success'] as num).toDouble(),
    score: (json['score'] as num).toDouble(),
  );
}

/// Effective latency: median ping, penalised for jitter and lost pings.
///
/// A proxy that answers 3/3 at 120 ms beats one that answers 2/3 at 80 ms:
/// every lost round trip on MTProto costs a reconnect, which is far slower
/// than a few extra milliseconds. Jitter is a proxy for congestion, which is
/// what actually limits download speed through a shared MTProxy.
double proxyScore(ProxyMeasurement m) {
  final median = m.medianMs;
  if (median == null) return double.infinity;
  final lossPenalty = 1 / math.pow(m.successRate, 2);
  return (median + 0.5 * m.jitterMs) * lossPenalty;
}

/// Picks the [top] best proxies. Proxies answering fewer than
/// [minSuccessRate] of pings are dropped entirely.
List<ProxyScore> rankProxies(Iterable<ProxyMeasurement> measurements, {int top = 5, double minSuccessRate = 0.5}) {
  final scored = <ProxyScore>[];
  for (final m in measurements) {
    final median = m.medianMs;
    if (median == null || m.successRate < minSuccessRate) continue;
    scored.add(
      ProxyScore(link: m.link, pingMs: median, jitterMs: m.jitterMs, successRate: m.successRate, score: proxyScore(m)),
    );
  }
  scored.sort((a, b) => a.score.compareTo(b.score));
  return scored.take(top).toList();
}

/// Whether the hourly (or user-configured) re-selection is due.
bool rotationDue({required DateTime? lastRotation, required DateTime now, required Duration interval}) =>
    lastRotation == null || now.difference(lastRotation) >= interval;

/// Next proxy to try after [current] failed; wraps around the top list.
int nextProxyIndex(int current, int count) => count == 0 ? -1 : (current + 1) % count;
