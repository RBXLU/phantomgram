import 'package:flutter/material.dart';

import '../../core/settings.dart';

/// Extra visual knobs that are not part of Material's ThemeData.
class ChatStyle extends ThemeExtension<ChatStyle> {
  const ChatStyle({
    required this.outgoingBubble,
    required this.onOutgoingBubble,
    required this.incomingBubble,
    required this.onIncomingBubble,
    required this.bubbleRadius,
    required this.compact,
    required this.showSeconds,
  });

  final Color outgoingBubble;
  final Color onOutgoingBubble;
  final Color incomingBubble;
  final Color onIncomingBubble;
  final double bubbleRadius;
  final bool compact;
  final bool showSeconds;

  static ChatStyle of(BuildContext context) => Theme.of(context).extension<ChatStyle>()!;

  @override
  ChatStyle copyWith({
    Color? outgoingBubble,
    Color? onOutgoingBubble,
    Color? incomingBubble,
    Color? onIncomingBubble,
    double? bubbleRadius,
    bool? compact,
    bool? showSeconds,
  }) => ChatStyle(
    outgoingBubble: outgoingBubble ?? this.outgoingBubble,
    onOutgoingBubble: onOutgoingBubble ?? this.onOutgoingBubble,
    incomingBubble: incomingBubble ?? this.incomingBubble,
    onIncomingBubble: onIncomingBubble ?? this.onIncomingBubble,
    bubbleRadius: bubbleRadius ?? this.bubbleRadius,
    compact: compact ?? this.compact,
    showSeconds: showSeconds ?? this.showSeconds,
  );

  @override
  ChatStyle lerp(ChatStyle? other, double t) {
    if (other == null) return this;
    return ChatStyle(
      outgoingBubble: Color.lerp(outgoingBubble, other.outgoingBubble, t)!,
      onOutgoingBubble: Color.lerp(onOutgoingBubble, other.onOutgoingBubble, t)!,
      incomingBubble: Color.lerp(incomingBubble, other.incomingBubble, t)!,
      onIncomingBubble: Color.lerp(onIncomingBubble, other.onIncomingBubble, t)!,
      bubbleRadius: bubbleRadius + (other.bubbleRadius - bubbleRadius) * t,
      compact: t < 0.5 ? compact : other.compact,
      showSeconds: t < 0.5 ? showSeconds : other.showSeconds,
    );
  }
}

ThemeMode themeModeOf(ThemeSettings s) => switch (s.mode) {
  ThemeModeSetting.system => ThemeMode.system,
  ThemeModeSetting.light => ThemeMode.light,
  ThemeModeSetting.dark => ThemeMode.dark,
};

ThemeData buildTheme(ThemeSettings s, Brightness brightness) {
  var scheme = ColorScheme.fromSeed(seedColor: Color(s.seedColor), brightness: brightness);
  if (brightness == Brightness.dark && s.amoled) {
    scheme = scheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF111111),
    );
  }
  final outgoing = s.outgoingBubbleColor != null ? Color(s.outgoingBubbleColor!) : scheme.primaryContainer;
  final onOutgoing = ThemeData.estimateBrightnessForColor(outgoing) == Brightness.dark ? Colors.white : Colors.black;
  final density = s.compact ? VisualDensity.compact : VisualDensity.standard;
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: density,
    scaffoldBackgroundColor: scheme.surface,
    listTileTheme: ListTileThemeData(dense: s.compact),
    extensions: [
      ChatStyle(
        outgoingBubble: outgoing,
        onOutgoingBubble: onOutgoing,
        incomingBubble: scheme.surfaceContainerHighest,
        onIncomingBubble: scheme.onSurface,
        bubbleRadius: s.bubbleRadius,
        compact: s.compact,
        showSeconds: s.showSeconds,
      ),
    ],
  );
}

const themePresets = <String, int>{
  'Telegram': 0xFF2AABEE,
  'Изумруд': 0xFF10B981,
  'Фиолетовый': 0xFF8B5CF6,
  'Закат': 0xFFF97316,
  'Роза': 0xFFE11D48,
  'Графит': 0xFF64748B,
  'Лимон': 0xFFCADB2B,
  'Океан': 0xFF0E7490,
};
