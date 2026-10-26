import 'package:flutter/cupertino.dart';

import 'look.dart';

/// Inset grouped section, as in the iOS Settings app (larger iOS 26 corners).
class IosSection extends StatelessWidget {
  const IosSection({super.key, required this.children, this.header, this.footer, this.dividerInset = 60});

  final String? header;
  final String? footer;
  final List<Widget> children;

  /// Where separators start; 60 lines up with text after an icon tile.
  final double dividerInset;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(left: dividerInset),
            child: Container(height: 0.5, color: look.separator),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Text(
                header!,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: look.label),
              ),
            ),
          if (rows.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: ColoredBox(
                color: look.card,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
              ),
            ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: Text(footer!, style: TextStyle(fontSize: 13, height: 1.3, color: look.secondaryLabel)),
            ),
        ],
      ),
    );
  }
}

/// Coloured rounded-square icon, like the ones in iOS Settings.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, this.color, {super.key, this.size = 30});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.27)),
    child: Icon(icon, color: const Color(0xFFFFFFFF), size: size * 0.62),
  );
}

class IosRow extends StatefulWidget {
  const IosRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron,
    this.destructive = false,
    this.accent = false,
    this.centered = false,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  /// Grey text before the chevron ("Вкл", "5", …).
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Defaults to true when the row is tappable and has no trailing widget.
  final bool? chevron;
  final bool destructive;

  /// Accent-coloured title, for "Add …" rows.
  final bool accent;
  final bool centered;
  final bool enabled;

  @override
  State<IosRow> createState() => _IosRowState();
}

class _IosRowState extends State<IosRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final look = Look.of(context);
    final tappable = widget.onTap != null && widget.enabled;
    final titleColor = !widget.enabled
        ? look.tertiaryLabel
        : widget.destructive
        ? LookData.destructive
        : widget.accent
        ? look.accent
        : look.label;
    final showChevron = widget.chevron ?? (tappable && widget.trailing == null && !widget.centered);

    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: look.compact ? 8 : 11),
      child: Row(
        children: [
          if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: widget.centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.title, style: TextStyle(fontSize: 17, color: titleColor, letterSpacing: -0.4)),
                if (widget.subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      widget.subtitle!,
                      style: TextStyle(fontSize: 13, height: 1.3, color: look.secondaryLabel),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.value != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(widget.value!, style: TextStyle(fontSize: 17, color: look.secondaryLabel)),
            ),
          if (widget.trailing != null) Padding(padding: const EdgeInsets.only(left: 8), child: widget.trailing),
          if (showChevron)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(CupertinoIcons.chevron_forward, size: 17, color: look.tertiaryLabel),
            ),
        ],
      ),
    );

    if (!tappable) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _pressed ? look.fill : const Color(0x00000000),
        child: content,
      ),
    );
  }
}

/// Switch row.
class IosSwitchRow extends StatelessWidget {
  const IosSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => IosRow(
    title: title,
    subtitle: subtitle,
    leading: leading,
    enabled: onChanged != null,
    trailing: CupertinoSwitch(value: value, activeTrackColor: LookData.green, onChanged: onChanged),
    chevron: false,
    onTap: onChanged == null ? null : () => onChanged!(!value),
  );
}
