import 'package:flutter/cupertino.dart';

import '../core/settings.dart';

/// Resolved visual tokens for the current theme: iOS system colours plus the
/// user's accent, bubbles, wallpaper and Liquid Glass tint.
class LookData {
  LookData._({
    required this.dark,
    required this.accent,
    required this.bg,
    required this.groupedBg,
    required this.card,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.separator,
    required this.fill,
    required this.outgoing,
    required this.onOutgoing,
    required this.incoming,
    required this.onIncoming,
    required this.wallpaper,
    required this.bubbleRadius,
    required this.compact,
    required this.showSeconds,
    required this.glassTint,
  });

  factory LookData.from(ThemeSettings t, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final accent = Color(t.seedColor);
    final out = t.outgoingBubbleColor != null ? Color(t.outgoingBubbleColor!) : accent;
    final outGradient = [_shift(out, 0.10), out];
    final black = dark && t.amoled;
    return LookData._(
      dark: dark,
      accent: accent,
      bg: dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      groupedBg: dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      card: black ? const Color(0xFF0B0B0C) : (dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF)),
      label: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
      secondaryLabel: dark ? const Color(0x99EBEBF5) : const Color(0x993C3C43),
      tertiaryLabel: dark ? const Color(0x4DEBEBF5) : const Color(0x4D3C3C43),
      separator: dark ? const Color(0x99545458) : const Color(0x4A3C3C43),
      fill: dark ? const Color(0x5C787880) : const Color(0x33787880),
      outgoing: outGradient,
      onOutgoing: _luminance(out) > 0.6 ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      incoming: black ? const Color(0xFF161618) : (dark ? const Color(0xFF262628) : const Color(0xFFFFFFFF)),
      onIncoming: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
      wallpaper: (wallpapers[t.wallpaper.clamp(0, wallpapers.length - 1)]).colors(dark, black),
      bubbleRadius: t.bubbleRadius,
      compact: t.compact,
      showSeconds: t.showSeconds,
      glassTint: t.glassTint,
    );
  }

  final bool dark;
  final Color accent;
  final Color bg;
  final Color groupedBg;
  final Color card;
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color separator;
  final Color fill;
  final List<Color> outgoing;
  final Color onOutgoing;
  final Color incoming;
  final Color onIncoming;
  final List<Color> wallpaper;
  final double bubbleRadius;
  final bool compact;
  final bool showSeconds;
  final double glassTint;

  static const destructive = Color(0xFFFF3B30);
  static const green = Color(0xFF34C759);
  static const orange = Color(0xFFFF9500);

  /// Glass body colour: more opaque as the tint slider moves to "tinted".
  Color get glass =>
      dark ? Color.fromRGBO(44, 44, 48, 0.28 + 0.5 * glassTint) : Color.fromRGBO(255, 255, 255, 0.38 + 0.5 * glassTint);

  /// iOS 27 diffuses busy content behind glass more strongly than iOS 26.
  double get glassBlur => 14 + 16 * glassTint;

  Color get glassRim => dark ? const Color(0x33FFFFFF) : const Color(0xB3FFFFFF);

  static Color _shift(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static double _luminance(Color c) => c.computeLuminance();
}

class Look extends InheritedWidget {
  const Look({super.key, required this.data, required super.child});

  final LookData data;

  static LookData of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Look>()!.data;

  @override
  bool updateShouldNotify(Look oldWidget) => true;
}

class Wallpaper {
  const Wallpaper(this.name, this.light, this.dark);

  final String name;
  final List<int> light;
  final List<int> dark;

  List<Color> colors(bool isDark, bool black) {
    if (isDark && black) return const [Color(0xFF000000), Color(0xFF000000), Color(0xFF000000)];
    return (isDark ? dark : light).map(Color.new).toList();
  }
}

const wallpapers = [
  Wallpaper('Небо', [0xFFC9DDF6, 0xFFE3D7F5, 0xFFD3ECEF], [0xFF0E1A2B, 0xFF1B1430, 0xFF0F2328]),
  Wallpaper('Мята', [0xFFD3F2E0, 0xFFEAF5CB, 0xFFCDEBF0], [0xFF0C201A, 0xFF1A2410, 0xFF0B1E24]),
  Wallpaper('Закат', [0xFFFAD9C7, 0xFFF7C9DC, 0xFFE4D5F7], [0xFF2A160F, 0xFF2A1020, 0xFF1C1430]),
  Wallpaper('Графит', [0xFFE6E7EB, 0xFFD9DBE1, 0xFFEEF0F3], [0xFF141416, 0xFF1C1C20, 0xFF101012]),
  Wallpaper('Без обоев', [0xFFF2F2F7, 0xFFF2F2F7, 0xFFF2F2F7], [0xFF000000, 0xFF000000, 0xFF000000]),
];

/// iOS system colours offered as accents.
const accentPresets = <String, int>{
  'Синий': 0xFF007AFF,
  'Индиго': 0xFF5856D6,
  'Фиолетовый': 0xFFAF52DE,
  'Розовый': 0xFFFF2D55,
  'Красный': 0xFFFF3B30,
  'Оранжевый': 0xFFFF9500,
  'Зелёный': 0xFF34C759,
  'Бирюзовый': 0xFF30B0C7,
  'Графит': 0xFF8E8E93,
};

Brightness brightnessFor(ThemeSettings t, Brightness platform) => switch (t.mode) {
  ThemeModeSetting.system => platform,
  ThemeModeSetting.light => Brightness.light,
  ThemeModeSetting.dark => Brightness.dark,
};
