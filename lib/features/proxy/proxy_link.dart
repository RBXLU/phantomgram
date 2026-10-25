import 'dart:convert';

/// An MTProto proxy as found in `tg://proxy?...` / `https://t.me/proxy?...`.
class ProxyLink {
  const ProxyLink({required this.server, required this.port, required this.secret});

  final String server;
  final int port;

  /// Always lowercase hex, which TDLib accepts for every secret flavour.
  final String secret;

  String get key => '$server:$port:$secret';

  String toLink() => 'tg://proxy?server=$server&port=$port&secret=$secret';

  Map<String, dynamic> toTd() => {
    '@type': 'proxy',
    'server': server,
    'port': port,
    'type': {'@type': 'proxyTypeMtproto', 'secret': secret},
  };

  Map<String, dynamic> toJson() => {'server': server, 'port': port, 'secret': secret};

  static ProxyLink fromJson(Map json) =>
      ProxyLink(server: json['server'] as String, port: json['port'] as int, secret: json['secret'] as String);

  @override
  bool operator ==(Object other) => other is ProxyLink && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => '$server:$port';
}

final _linkPattern = RegExp(
  r'''(?:tg://proxy|https?://(?:www\.)?(?:t|telegram)\.me/proxy)\?[^\s"'<>\)\]]+''',
  caseSensitive: false,
);
final _hostPattern = RegExp(r'^[A-Za-z0-9.\-]+$|^\[?[0-9A-Fa-f:]+\]?$');
final _hexPattern = RegExp(r'^[0-9a-fA-F]+$');
final _base64UrlPattern = RegExp(r'^[A-Za-z0-9_\-+/]+=*$');

/// Finds every MTProto proxy link in arbitrary text (plain lists, HTML pages,
/// channel posts). Invalid links are skipped; duplicates are removed while
/// keeping the original order.
List<ProxyLink> extractProxyLinks(String text) {
  final seen = <String>{};
  final result = <ProxyLink>[];
  for (final match in _linkPattern.allMatches(text)) {
    final link = parseProxyLink(match.group(0)!);
    if (link != null && seen.add(link.key)) result.add(link);
  }
  return result;
}

ProxyLink? parseProxyLink(String raw) {
  final cleaned = raw.replaceAll('&amp;', '&').trim();
  final q = cleaned.indexOf('?');
  if (q < 0) return null;
  final params = <String, String>{};
  for (final pair in cleaned.substring(q + 1).split('&')) {
    final eq = pair.indexOf('=');
    if (eq <= 0) continue;
    try {
      params[pair.substring(0, eq).toLowerCase()] = Uri.decodeQueryComponent(pair.substring(eq + 1));
    } on ArgumentError {
      return null;
    }
  }
  final server = params['server']?.trim() ?? '';
  final port = int.tryParse(params['port'] ?? '');
  final secret = normalizeSecret(params['secret'] ?? '');
  if (server.isEmpty || !_hostPattern.hasMatch(server)) return null;
  if (port == null || port <= 0 || port > 65535) return null;
  if (secret == null) return null;
  return ProxyLink(server: server.toLowerCase(), port: port, secret: secret);
}

/// Converts a proxy secret to lowercase hex. Accepts hex and base64(url).
/// Valid secrets are 16 bytes, optionally prefixed with `dd`, or `ee` + 16
/// bytes + a fake-TLS domain.
String? normalizeSecret(String secret) {
  final s = secret.trim();
  if (s.isEmpty) return null;
  String hex;
  if (_hexPattern.hasMatch(s) && s.length.isEven) {
    hex = s.toLowerCase();
  } else if (_base64UrlPattern.hasMatch(s)) {
    try {
      final normalized = base64Url.normalize(s.replaceAll('+', '-').replaceAll('/', '_'));
      hex = base64Url.decode(normalized).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } on FormatException {
      return null;
    }
  } else {
    return null;
  }
  final bytes = hex.length ~/ 2;
  if (bytes == 16) return hex;
  if (bytes == 17 && hex.startsWith('dd')) return hex;
  if (bytes > 17 && hex.startsWith('ee')) return hex;
  return null;
}
