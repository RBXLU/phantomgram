import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/settings.dart';
import 'app_theme.dart';

class ThemeEditorScreen extends StatelessWidget {
  const ThemeEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оформление'),
        actions: [
          TextButton(
            onPressed: () => settings.update((s) => s.theme.load(ThemeSettings().toJson())),
            child: const Text('Сбросить'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final t = settings.theme;
          void set(void Function(ThemeSettings t) change) => settings.update((s) => change(s.theme));
          return ListView(
            children: [
              const _Preview(),
              const ListTile(title: Text('Тема')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ThemeModeSetting>(
                  segments: const [
                    ButtonSegment(value: ThemeModeSetting.system, label: Text('Авто')),
                    ButtonSegment(value: ThemeModeSetting.light, label: Text('Светлая')),
                    ButtonSegment(value: ThemeModeSetting.dark, label: Text('Тёмная')),
                  ],
                  selected: {t.mode},
                  onSelectionChanged: (v) => set((t) => t.mode = v.first),
                ),
              ),
              SwitchListTile(
                title: const Text('AMOLED — чисто чёрный фон'),
                value: t.amoled,
                onChanged: (v) => set((t) => t.amoled = v),
              ),
              const ListTile(title: Text('Акцентный цвет')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final e in themePresets.entries)
                      _ColorDot(
                        color: Color(e.value),
                        label: e.key,
                        selected: t.seedColor == e.value,
                        onTap: () => set((t) => t.seedColor = e.value),
                      ),
                  ],
                ),
              ),
              const ListTile(title: Text('Цвет моих сообщений')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ColorDot(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      label: 'Как тема',
                      selected: t.outgoingBubbleColor == null,
                      onTap: () => set((t) => t.outgoingBubbleColor = null),
                    ),
                    for (final c in _bubbleColors)
                      _ColorDot(
                        color: Color(c),
                        selected: t.outgoingBubbleColor == c,
                        onTap: () => set((t) => t.outgoingBubbleColor = c),
                      ),
                  ],
                ),
              ),
              _SliderTile(
                title: 'Скругление пузырей',
                value: t.bubbleRadius,
                min: 0,
                max: 28,
                label: '${t.bubbleRadius.round()}',
                onChanged: (v) => set((t) => t.bubbleRadius = v),
              ),
              _SliderTile(
                title: 'Размер текста',
                value: t.fontScale,
                min: 0.8,
                max: 1.4,
                label: '${(t.fontScale * 100).round()}%',
                onChanged: (v) => set((t) => t.fontScale = v),
              ),
              SwitchListTile(
                title: const Text('Компактный режим'),
                subtitle: const Text('Плотнее список чатов и сообщения'),
                value: t.compact,
                onChanged: (v) => set((t) => t.compact = v),
              ),
              SwitchListTile(
                title: const Text('Время с секундами'),
                value: t.showSeconds,
                onChanged: (v) => set((t) => t.showSeconds = v),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

const _bubbleColors = [
  0xFFEEFFDE, // classic Telegram green
  0xFFDCF3FF,
  0xFFFFE4F1,
  0xFFFFF4CC,
  0xFF2B5278,
  0xFF3E2A5C,
  0xFF1F4D3A,
  0xFF5A2B2B,
];

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final style = ChatStyle.of(context);
    Widget bubble(String text, bool out) => Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: style.compact ? 2 : 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: out ? style.outgoingBubble : style.incomingBubble,
          borderRadius: BorderRadius.circular(style.bubbleRadius),
        ),
        child: Text(text, style: TextStyle(color: out ? style.onOutgoingBubble : style.onIncomingBubble, fontSize: 15)),
      ),
    );
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [bubble('Привет! Как тебе новая тема?', false), bubble('Огонь 🔥 Пузыри как раз как я хотел', true)],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.selected, required this.onTap, this.label});

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final dot = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent, width: 3),
        ),
      ),
    );
    return label == null ? dot : Tooltip(message: label!, child: dot);
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('$title: $label'),
      subtitle: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
    );
  }
}
