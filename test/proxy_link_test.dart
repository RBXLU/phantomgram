import 'package:flutter_test/flutter_test.dart';
import 'package:phantomgram/features/proxy/proxy_link.dart';
import 'package:phantomgram/features/proxy/proxy_manager.dart';

void main() {
  const hex = '0123456789abcdef0123456789abcdef';

  test('parses tg:// and t.me links, HTML-escaped ampersands', () {
    final links = extractProxyLinks('''
      <a href="https://t.me/proxy?server=1.2.3.4&amp;port=443&amp;secret=$hex">Connect</a>
      tg://proxy?server=Proxy.Example.com&port=8443&secret=dd$hex
      https://telegram.me/proxy?port=80&secret=$hex&server=5.6.7.8
    ''');
    expect(links.map((l) => l.toString()), ['1.2.3.4:443', 'proxy.example.com:8443', '5.6.7.8:80']);
    expect(links[1].secret, 'dd$hex');
  });

  test('deduplicates identical proxies', () {
    final text = 'tg://proxy?server=a.b&port=1&secret=$hex tg://proxy?server=A.B&port=1&secret=${hex.toUpperCase()}';
    expect(extractProxyLinks(text), hasLength(1));
  });

  test('rejects broken links', () {
    expect(parseProxyLink('tg://proxy?server=a.b&port=0&secret=$hex'), isNull);
    expect(parseProxyLink('tg://proxy?server=a.b&port=99999&secret=$hex'), isNull);
    expect(parseProxyLink('tg://proxy?server=&port=443&secret=$hex'), isNull);
    expect(parseProxyLink('tg://proxy?server=a.b&port=443&secret=abc'), isNull);
    expect(parseProxyLink('tg://proxy?server=bad host&port=443&secret=$hex'), isNull);
  });

  test('normalizes secrets', () {
    expect(normalizeSecret(hex.toUpperCase()), hex);
    expect(normalizeSecret('dd$hex'), 'dd$hex');
    // ee + 16 bytes + "google.com"
    final tls = 'ee$hex${'google.com'.codeUnits.map((c) => c.toRadixString(16)).join()}';
    expect(normalizeSecret(tls), tls);
    // base64url of the fake-TLS secret above
    expect(normalizeSecret('7gEjRWeJq83vASNFZ4mrze9nb29nbGUuY29t'), tls);
    expect(normalizeSecret('ab$hex'), isNull, reason: '17 bytes must start with dd');
    expect(normalizeSecret(''), isNull);
  });

  test('round-trips through JSON and TDLib shape', () {
    final link = parseProxyLink('tg://proxy?server=1.1.1.1&port=443&secret=$hex')!;
    expect(ProxyLink.fromJson(link.toJson()), link);
    expect(link.toTd()['type'], {'@type': 'proxyTypeMtproto', 'secret': hex});
    expect(parseProxyLink(link.toLink()), link);
  });

  test('channel sources', () {
    expect(isChannelSource('@proxies'), isTrue);
    expect(isChannelSource('https://t.me/proxies'), isTrue);
    expect(isChannelSource('https://t.me/proxy?server=a'), isFalse);
    expect(isChannelSource('https://example.com/list.txt'), isFalse);
    expect(channelUsername('@proxies'), 'proxies');
    expect(channelUsername('https://t.me/proxies/'), 'proxies');
  });
}
