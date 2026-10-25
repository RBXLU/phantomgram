import 'package:flutter_test/flutter_test.dart';
import 'package:phantomgram/features/proxy/proxy_link.dart';
import 'package:phantomgram/features/proxy/proxy_ranking.dart';

ProxyLink _link(int i) => ProxyLink(server: '10.0.0.$i', port: 443, secret: '0123456789abcdef0123456789abcdef');

void main() {
  test('median, jitter and success rate', () {
    final m = ProxyMeasurement(_link(1), [100, null, 300, 200]);
    expect(m.successRate, 0.75);
    expect(m.medianMs, 200);
    expect(m.jitterMs, 200);
    expect(ProxyMeasurement(_link(1), [null, null]).medianMs, isNull);
  });

  test('stable proxy beats a faster lossy one', () {
    final stable = ProxyMeasurement(_link(1), [120, 125, 122]);
    final lossy = ProxyMeasurement(_link(2), [80, null, 82]);
    expect(proxyScore(stable), lessThan(proxyScore(lossy)));
  });

  test('ranks, drops dead and mostly-dead proxies, keeps top N', () {
    final ranked = rankProxies([
      ProxyMeasurement(_link(1), [300, 310, 305]),
      ProxyMeasurement(_link(2), [null, null, null]),
      ProxyMeasurement(_link(3), [50, 55, 52]),
      ProxyMeasurement(_link(4), [60, null, null]),
      ProxyMeasurement(_link(5), [90, 400, 95]),
      ProxyMeasurement(_link(6), [100, 101, 99]),
      ProxyMeasurement(_link(7), [200, 210, 205]),
      ProxyMeasurement(_link(8), [150, 150, 150]),
    ], top: 5);
    expect(ranked.map((r) => r.link.server), ['10.0.0.3', '10.0.0.6', '10.0.0.8', '10.0.0.7', '10.0.0.5']);
    expect(ProxyScore.fromJson(ranked.first.toJson()).link, ranked.first.link);
  });

  test('rotation is due once per interval', () {
    final t0 = DateTime(2026, 1, 1, 12);
    const hour = Duration(hours: 1);
    expect(rotationDue(lastRotation: null, now: t0, interval: hour), isTrue);
    expect(rotationDue(lastRotation: t0, now: t0.add(const Duration(minutes: 59)), interval: hour), isFalse);
    expect(rotationDue(lastRotation: t0, now: t0.add(hour), interval: hour), isTrue);
  });

  test('failover wraps around', () {
    expect(nextProxyIndex(0, 5), 1);
    expect(nextProxyIndex(4, 5), 0);
    expect(nextProxyIndex(0, 0), -1);
  });
}
