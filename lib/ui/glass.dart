import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import 'look.dart';

/// A Liquid Glass surface: blurs what is behind it, adds a tinted body, a
/// specular sheen from the top-left and a bright rim, and floats on a soft
/// shadow. Flutter cannot refract light like iOS does, so this is the closest
/// honest approximation.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 999,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Overrides the glass body colour (e.g. accent-tinted active buttons).
  final Color? tint;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, look.dark ? 0.35 : 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: look.glassBlur, sigmaY: look.glassBlur),
          child: DecoratedBox(
            decoration: BoxDecoration(color: tint ?? look.glass, borderRadius: shape),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                border: Border.all(color: look.glassRim, width: 0.8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.fromRGBO(255, 255, 255, look.dark ? 0.10 : 0.35), const Color(0x00FFFFFF)],
                  stops: const [0, 0.6],
                ),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round glass button, the iOS 26/27 navigation bar style.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.size = 44,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Accent-filled glass, for toggles that are on.
  final bool active;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: Glass(
          tint: active ? look.accent.withValues(alpha: 0.85) : null,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.square(size),
            onPressed: onPressed,
            child: Icon(
              icon,
              size: size * 0.46,
              color: active ? const Color(0xFFFFFFFF) : (onPressed == null ? look.tertiaryLabel : look.label),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small glass capsule with text, for date separators and banners.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Glass(shadow: false, padding: padding, child: child);
}

/// Telegram-style soft gradient wallpaper behind chats.
class WallpaperBackground extends StatelessWidget {
  const WallpaperBackground({super.key, this.colors});

  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final c = colors ?? Look.of(context).wallpaper;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.8, -0.6),
              radius: 0.9,
              colors: [c[1].withValues(alpha: 0.9), c[1].withValues(alpha: 0)],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.9, 0.7),
              radius: 0.8,
              colors: [c[2].withValues(alpha: 0.9), c[2].withValues(alpha: 0)],
            ),
          ),
        ),
      ],
    );
  }
}

/// Telegram iOS avatar gradients (top → bottom).
const avatarGradients = [
  [Color(0xFFFF885E), Color(0xFFFF516A)],
  [Color(0xFFFFCD6A), Color(0xFFFFA85C)],
  [Color(0xFF82B1FF), Color(0xFF665FFF)],
  [Color(0xFFA0DE7E), Color(0xFF54CB68)],
  [Color(0xFF53EDD6), Color(0xFF28C9B7)],
  [Color(0xFF72D5FD), Color(0xFF2A9EF1)],
  [Color(0xFFE0A2F3), Color(0xFFD669ED)],
];

List<Color> avatarGradientFor(int id) => avatarGradients[id.abs() % avatarGradients.length];

final _letter = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// First letters of the first two words that start with a letter or digit,
/// so "Работа 💼" gives "Р" and "Phantomgram — разработка" gives "PР".
String initials(String title) {
  final letters = <String>[];
  for (final word in title.trim().split(RegExp(r'\s+'))) {
    final first = word.runes.isEmpty ? '' : String.fromCharCode(word.runes.first);
    if (_letter.hasMatch(first)) letters.add(first);
    if (letters.length == 2) break;
  }
  if (letters.isEmpty) {
    final runes = title.trim().runes;
    return runes.isEmpty ? '?' : String.fromCharCode(runes.first);
  }
  return letters.join().toUpperCase();
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.id, required this.title, this.image, this.size = 56});

  final int id;
  final String title;
  final ImageProvider? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final g = avatarGradientFor(id);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: g),
        image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: image != null
          ? null
          : Text(
              initials(title),
              style: TextStyle(
                color: const Color(0xFFFFFFFF),
                fontSize: size * 0.38,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
    );
  }
}

/// Telegram's double check mark (two overlapping ticks).
class Checks extends StatelessWidget {
  const Checks({super.key, required this.read, required this.color, this.size = 15});

  final bool read;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tick = Icon(CupertinoIcons.checkmark_alt, size: size, color: color);
    if (!read) return SizedBox(width: size, child: tick);
    return SizedBox(
      width: size * 1.45,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, child: tick),
          Positioned(left: size * 0.45, child: tick),
        ],
      ),
    );
  }
}
