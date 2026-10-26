import 'package:flutter/cupertino.dart';

import '../../core/services.dart';
import '../../core/settings.dart';
import '../../ui/glass.dart';
import '../../ui/ios_list.dart';
import '../../ui/ios_page.dart';
import '../../ui/look.dart';
import '../chat/message_bubble.dart';

class ThemeEditorScreen extends StatelessWidget {
  const ThemeEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final t = settings.theme;
        final look = Look.of(context);
        void set(void Function(ThemeSettings t) change) => settings.update((s) => change(s.theme));
        return IosPage(
          title: 'Оформление',
          actions: [
            GlassButton(
              icon: CupertinoIcons.arrow_counterclockwise,
              semanticLabel: 'Сбросить',
              onPressed: () => set((t) => t.load(ThemeSettings().toJson())),
            ),
          ],
          slivers: [
            const SliverToBoxAdapter(child: _Preview()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                child: CupertinoSlidingSegmentedControl<ThemeModeSetting>(
                  groupValue: t.mode,
                  onValueChanged: (v) => set((t) => t.mode = v!),
                  children: const {
                    ThemeModeSetting.system: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Авто')),
                    ThemeModeSetting.light: Text('Светлая'),
                    ThemeModeSetting.dark: Text('Тёмная'),
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                header: 'Liquid Glass',
                dividerInset: 16,
                footer: 'Как в iOS 27: от прозрачного стекла к матовому, более читаемому.',
                children: [
                  _SliderRow(
                    left: 'Прозрачное',
                    right: 'Матовое',
                    value: t.glassTint,
                    onChanged: (v) => set((t) => t.glassTint = v),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                header: 'Акцентный цвет',
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final e in accentPresets.entries)
                          _ColorDot(
                            colors: [Color(e.value)],
                            selected: t.seedColor == e.value,
                            onTap: () => set((t) => t.seedColor = e.value),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                header: 'Обои чата',
                children: [
                  SizedBox(
                    height: 132,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(14),
                      children: [
                        for (final (i, w) in wallpapers.indexed)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: GestureDetector(
                              onTap: () => set((t) => t.wallpaper = i),
                              child: Column(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: t.wallpaper == i ? look.accent : look.separator,
                                        width: t.wallpaper == i ? 2.5 : 0.5,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: WallpaperBackground(colors: w.colors(look.dark, false)),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(w.name, style: TextStyle(fontSize: 11, color: look.secondaryLabel)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                header: 'Сообщения',
                dividerInset: 16,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _ColorDot(
                          colors: [look.accent],
                          label: 'Как акцент',
                          selected: t.outgoingBubbleColor == null,
                          onTap: () => set((t) => t.outgoingBubbleColor = null),
                        ),
                        for (final c in _bubbleColors)
                          _ColorDot(
                            colors: [Color(c)],
                            selected: t.outgoingBubbleColor == c,
                            onTap: () => set((t) => t.outgoingBubbleColor = c),
                          ),
                      ],
                    ),
                  ),
                  _SliderRow(
                    left: 'Скругление',
                    right: '${t.bubbleRadius.round()}',
                    value: (t.bubbleRadius - 4) / 20,
                    onChanged: (v) => set((t) => t.bubbleRadius = 4 + v * 20),
                  ),
                  _SliderRow(
                    left: 'Размер текста',
                    right: '${(t.fontScale * 100).round()}%',
                    value: (t.fontScale - 0.8) / 0.6,
                    onChanged: (v) => set((t) => t.fontScale = 0.8 + v * 0.6),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                dividerInset: 16,
                children: [
                  IosSwitchRow(
                    title: 'Компактный режим',
                    value: t.compact,
                    onChanged: (v) => set((t) => t.compact = v),
                  ),
                  IosSwitchRow(
                    title: 'Чёрный AMOLED',
                    subtitle: 'В тёмной теме',
                    value: t.amoled,
                    onChanged: (v) => set((t) => t.amoled = v),
                  ),
                  IosSwitchRow(
                    title: 'Время с секундами',
                    value: t.showSeconds,
                    onChanged: (v) => set((t) => t.showSeconds = v),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Classic Telegram green, iMessage blue, and a few more.
const _bubbleColors = [0xFF4FAE4E, 0xFF34AADC, 0xFF5E5CE6, 0xFFBF5AF2, 0xFFFF6482, 0xFFFF9F0A, 0xFF636366];

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    Widget bubble(String text, bool out, {bool last = true}) => Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: out ? 40 : 6, right: out ? 6 : 40, top: 3),
        child: CustomPaint(
          painter: BubblePainter(
            colors: out ? look.outgoing : [look.incoming],
            outgoing: out,
            first: true,
            last: last,
            radius: look.bubbleRadius,
            shadow: !look.dark,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(text, style: TextStyle(fontSize: 16, color: out ? look.onOutgoing : look.onIncoming)),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: SizedBox(
          height: 190,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const WallpaperBackground(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Center(
                      child: GlassPill(
                        child: Text('Сегодня', style: TextStyle(fontSize: 13, color: look.label)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    bubble('Привет! Как тебе новая тема?', false),
                    bubble('Огонь 🔥', true, last: false),
                    bubble('Стекло как в iOS 27', true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.colors, required this.selected, required this.onTap, this.label});

  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? colors.first : const Color(0x00000000), width: 2.5),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: colors.first),
            child: selected ? Icon(CupertinoIcons.checkmark_alt, size: 18, color: look.bg) : null,
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.left, required this.right, required this.value, required this.onChanged});

  final String left;
  final String right;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              Text(left, style: TextStyle(fontSize: 15, color: look.label)),
              const Spacer(),
              Text(right, style: TextStyle(fontSize: 15, color: look.secondaryLabel)),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlider(value: value.clamp(0, 1), onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
