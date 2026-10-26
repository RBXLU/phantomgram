import 'package:flutter/cupertino.dart';

import 'glass.dart';
import 'look.dart';

/// A page in the iOS 26/27 style: content scrolls under floating glass
/// buttons; an optional large title collapses into a centred inline title.
class IosPage extends StatefulWidget {
  const IosPage({
    super.key,
    required this.title,
    required this.slivers,
    this.largeTitle = false,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
    this.background,
    this.bottomInset = 0,
    this.controller,
  });

  final String title;

  /// Shown under the large title (e.g. "Подключение…").
  final Widget? subtitle;
  final List<Widget> slivers;
  final bool largeTitle;
  final List<Widget> actions;
  final bool showBack;
  final Color? background;

  /// Extra space at the bottom for floating bars (tab bar, composer).
  final double bottomInset;
  final ScrollController? controller;

  @override
  State<IosPage> createState() => _IosPageState();
}

class _IosPageState extends State<IosPage> {
  late final ScrollController _scroll = widget.controller ?? ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final collapsed = _scroll.hasClients && _scroll.offset > 36;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    if (widget.controller == null) _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final media = MediaQuery.of(context);
    final top = media.padding.top;
    final bg = widget.background ?? look.groupedBg;
    final canPop = widget.showBack && Navigator.of(context).canPop();
    final showInlineTitle = !widget.largeTitle || _collapsed;

    return ColoredBox(
      color: bg,
      child: Stack(
        children: [
          CupertinoScrollbar(
            controller: _scroll,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: top + 60)),
                if (widget.largeTitle)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.37,
                              color: look.label,
                            ),
                          ),
                          ?widget.subtitle,
                        ],
                      ),
                    ),
                  ),
                ...widget.slivers,
                SliverToBoxAdapter(child: SizedBox(height: media.padding.bottom + 24 + widget.bottomInset)),
              ],
            ),
          ),
          // Soft scroll-edge fade under the floating controls.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + 64,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [bg, bg.withValues(alpha: 0.85), bg.withValues(alpha: 0)],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 6,
            left: 16,
            right: 16,
            height: 44,
            child: Row(
              children: [
                if (canPop)
                  GlassButton(
                    icon: CupertinoIcons.chevron_back,
                    semanticLabel: 'Назад',
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                else
                  SizedBox(width: widget.actions.isEmpty ? 0 : 44.0 * widget.actions.length),
                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: showInlineTitle ? 1 : 0,
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: look.label),
                    ),
                  ),
                ),
                if (widget.actions.isEmpty)
                  SizedBox(width: canPop ? 44 : 0)
                else ...[
                  for (final a in widget.actions) Padding(padding: const EdgeInsets.only(left: 8), child: a),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width filled capsule, the iOS primary action button.
class IosPrimaryButton extends StatelessWidget {
  const IosPrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(26),
        color: look.accent,
        disabledColor: look.fill,
        onPressed: loading ? null : onPressed,
        child: loading
            ? const CupertinoActivityIndicator(color: Color(0xFFFFFFFF))
            : Text(
                label,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)),
              ),
      ),
    );
  }
}
