import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'glass.dart';
import 'look.dart';

OverlayEntry? _toast;
Timer? _toastTimer;

/// Glass capsule notification near the top of the screen (replaces snack bars).
void showToast(BuildContext context, String text, {IconData? icon}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _toastTimer?.cancel();
  _toast?.remove();
  final entry = OverlayEntry(
    builder: (context) {
      final look = Look.of(context);
      return Positioned(
        top: MediaQuery.of(context).padding.top + 60,
        left: 24,
        right: 24,
        child: IgnorePointer(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Opacity(
                opacity: t.clamp(0, 1),
                child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
              ),
              child: Glass(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 18, color: look.label), const SizedBox(width: 8)],
                    Flexible(
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: look.label, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  _toast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(const Duration(milliseconds: 2400), () {
    if (_toast == entry) {
      entry.remove();
      _toast = null;
    }
  });
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  required String action,
  bool destructive = false,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Text input dialog. Returns null on cancel.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? message,
  String placeholder = '',
  String initial = '',
  String action = 'Готово',
  int lines = 1,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showCupertinoDialog<String>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(title),
      content: Column(
        children: [
          if (message != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(message)),
          CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: placeholder,
            minLines: lines,
            maxLines: lines,
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

class SheetAction<T> {
  const SheetAction(this.label, this.value, {this.destructive = false});

  final String label;
  final T value;
  final bool destructive;
}

Future<T?> actionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<SheetAction<T>> actions,
}) => showCupertinoModalPopup<T>(
  context: context,
  builder: (context) => CupertinoActionSheet(
    title: title == null ? null : Text(title),
    message: message == null ? null : Text(message),
    actions: [
      for (final a in actions)
        CupertinoActionSheetAction(
          isDestructiveAction: a.destructive,
          onPressed: () => Navigator.pop(context, a.value),
          child: Text(a.label),
        ),
    ],
    cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
  ),
);
