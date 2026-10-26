import 'package:flutter/cupertino.dart';

import '../../ui/look.dart';

/// The app icon: accent gradient squircle with a ghost-eye glyph.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final hsl = HSLColor.fromColor(look.accent);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.235),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hsl.withLightness((hsl.lightness + 0.15).clamp(0, 1)).toColor(), look.accent],
        ),
        boxShadow: [BoxShadow(color: look.accent.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Icon(CupertinoIcons.eye_slash_fill, size: size * 0.5, color: const Color(0xFFFFFFFF)),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    return ColoredBox(
      color: look.groupedBg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(),
            const SizedBox(height: 24),
            if (message == null)
              const CupertinoActivityIndicator(radius: 12)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: look.secondaryLabel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    return ColoredBox(
      color: look.groupedBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 56, color: LookData.orange),
              const SizedBox(height: 16),
              Text(
                'Не удалось запустить TDLib',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: look.label),
              ),
              const SizedBox(height: 10),
              Text(
                '$error\n\nПроверьте, что libtdjson собрана: scripts/build_tdlib_linux.sh '
                '(или scripts/build_tdlib_ios.sh для iOS).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: look.secondaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text field that sits inside an [IosSection] card.
class SectionTextField extends StatelessWidget {
  const SectionTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.keyboardType,
    this.obscure = false,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      obscureText: obscure,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: null,
      style: TextStyle(fontSize: 17, color: look.label),
      placeholderStyle: TextStyle(fontSize: 17, color: look.tertiaryLabel),
    );
  }
}
