import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../core/td_client.dart';
import '../../core/td_text.dart';
import '../../ui/glass.dart';
import '../../ui/look.dart';
import '../antispam/spam_rules.dart';
import '../archive/message_archive.dart';

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.firstInGroup,
    required this.lastInGroup,
    required this.showSender,
    required this.senderName,
    required this.senderId,
    required this.deleted,
    required this.archived,
    required this.read,
    required this.rules,
    required this.onLongPress,
    this.senderAvatar,
  });

  final TdObject message;
  final bool firstInGroup;
  final bool lastInGroup;

  /// Group chats: name above the first bubble, avatar next to the last.
  final bool showSender;
  final String senderName;
  final int senderId;
  final Widget? senderAvatar;
  final bool deleted;
  final ArchivedMessage? archived;
  final bool read;
  final SpamRules rules;
  final VoidCallback onLongPress;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final look = Look.of(context);
    final outgoing = m['is_outgoing'] == true;
    final text = contentText(m['content'] as Map);
    final hiddenBy = _revealed ? null : hiddenWordIn(text, widget.rules);
    final edited = (m['edit_date'] as int? ?? 0) > 0 || (widget.archived?.wasEdited ?? false);
    final pending = m['sending_state'] != null;
    final fg = outgoing ? look.onOutgoing : look.onIncoming;
    final metaColor = outgoing ? fg.withValues(alpha: 0.75) : look.secondaryLabel;
    final time = formatTime(m['date'] as int, seconds: look.showSeconds);
    final metaStyle = TextStyle(fontSize: 12, color: metaColor);
    final textStyle = TextStyle(fontSize: 17, height: 1.25, color: fg, letterSpacing: -0.4);

    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.deleted) ...[
          const Icon(CupertinoIcons.trash_fill, size: 12, color: LookData.destructive),
          const SizedBox(width: 2),
          const Text('удалено ', style: TextStyle(fontSize: 12, color: LookData.destructive)),
        ],
        if (edited) Text('изм. ', style: metaStyle),
        Text(time, style: metaStyle),
        if (outgoing && !widget.deleted) ...[
          const SizedBox(width: 3),
          pending
              ? Icon(CupertinoIcons.clock, size: 13, color: metaColor)
              : Checks(read: widget.read, color: metaColor, size: 14),
        ],
      ],
    );
    final metaPainter = TextPainter(
      text: TextSpan(text: '${widget.deleted ? 'удалено ' : ''}${edited ? 'изм. ' : ''}$time', style: metaStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final metaWidth = metaPainter.width + (widget.deleted ? 14 : 0) + (outgoing && !widget.deleted ? 24 : 0) + 6;

    final body = hiddenBy != null
        ? Text(
            'Скрыто: содержит «$hiddenBy». Нажмите, чтобы показать',
            style: textStyle.copyWith(fontStyle: FontStyle.italic, fontSize: 15),
          )
        : Stack(
            children: [
              Text.rich(
                TextSpan(
                  text: text,
                  children: [WidgetSpan(child: SizedBox(width: metaWidth, height: 12))],
                ),
                style: textStyle,
              ),
              Positioned(right: 0, bottom: 0, child: meta),
            ],
          );

    final radius = look.bubbleRadius;
    final bubble = CustomPaint(
      painter: BubblePainter(
        colors: outgoing ? look.outgoing : [look.incoming],
        outgoing: outgoing,
        first: widget.firstInGroup,
        last: widget.lastInGroup,
        radius: radius,
        border: widget.deleted ? LookData.destructive.withValues(alpha: 0.8) : null,
        shadow: !look.dark,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, look.compact ? 5 : 7, 12, look.compact ? 5 : 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showSender && widget.firstInGroup && !outgoing && widget.senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  widget.senderName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: avatarGradientFor(widget.senderId).last,
                  ),
                ),
              ),
            body,
          ],
        ),
      ),
    );

    final withAvatar = widget.showSender && !outgoing;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth * 0.8, 540.0) - (withAvatar ? 38 : 0);
        return Padding(
          padding: EdgeInsets.only(
            top: widget.firstInGroup ? (look.compact ? 4 : 7) : 2,
            left: outgoing ? 0 : 6,
            right: outgoing ? 6 : 0,
          ),
          child: Row(
            mainAxisAlignment: outgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (withAvatar) ...[
                SizedBox(width: 32, child: widget.lastInGroup ? widget.senderAvatar : null),
                const SizedBox(width: 6),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Opacity(
                  opacity: widget.deleted ? 0.78 : 1,
                  child: GestureDetector(
                    onLongPress: widget.onLongPress,
                    onTap: hiddenBy != null ? () => setState(() => _revealed = true) : null,
                    child: bubble,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Rounded bubble with an iMessage/Telegram-style tail on the last bubble of
/// a group. Corners next to neighbours in the same group are tightened.
class BubblePainter extends CustomPainter {
  BubblePainter({
    required this.colors,
    required this.outgoing,
    required this.first,
    required this.last,
    required this.radius,
    this.border,
    this.shadow = false,
  });

  final List<Color> colors;
  final bool outgoing;
  final bool first;
  final bool last;
  final double radius;
  final Color? border;
  final bool shadow;

  Path _path(Size size) {
    final w = size.width;
    final h = size.height;
    final r = math.min(radius, h / 2);
    final tight = math.min(6.0, r);
    final outerTop = Radius.circular(first ? r : tight);
    final outerBottom = Radius.circular(last ? 4 : tight);
    final inner = Radius.circular(r);
    final body = RRect.fromLTRBAndCorners(
      0,
      0,
      w,
      h,
      topLeft: outgoing ? inner : outerTop,
      bottomLeft: outgoing ? inner : outerBottom,
      topRight: outgoing ? outerTop : inner,
      bottomRight: outgoing ? outerBottom : inner,
    );
    final path = Path()..addRRect(body);
    if (!last) return path;
    final tail = Path();
    if (outgoing) {
      tail
        ..moveTo(w - 12, h)
        ..lineTo(w + 6, h)
        ..quadraticBezierTo(w + 0.5, h - 2.5, w, h - 13)
        ..lineTo(w - 12, h - 13)
        ..close();
    } else {
      tail
        ..moveTo(12, h)
        ..lineTo(-6, h)
        ..quadraticBezierTo(-0.5, h - 2.5, 0, h - 13)
        ..lineTo(12, h - 13)
        ..close();
    }
    return Path.combine(PathOperation.union, path, tail);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    if (shadow) {
      canvas.drawShadow(path, const Color(0x33000000), 1.2, false);
    }
    final paint = Paint()..isAntiAlias = true;
    if (colors.length > 1) {
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(Offset.zero & size);
    } else {
      paint.color = colors.first;
    }
    canvas.drawPath(path, paint);
    if (border != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = border!,
      );
    }
  }

  @override
  bool shouldRepaint(BubblePainter old) =>
      old.colors != colors ||
      old.first != first ||
      old.last != last ||
      old.radius != radius ||
      old.border != border ||
      old.outgoing != outgoing;
}

Future<void> showEditHistory(BuildContext context, List<MessageVersion> versions) => showCupertinoModalPopup<void>(
  context: context,
  builder: (context) {
    final look = Look.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(8),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        decoration: BoxDecoration(color: look.card, borderRadius: BorderRadius.circular(30)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'История правок',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: look.label),
                    ),
                  ),
                  CupertinoButton(onPressed: () => Navigator.pop(context), child: const Text('Готово')),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  for (final (i, v) in versions.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i == 0 ? 'Оригинал · ${formatDateTime(v.date)}' : 'Правка $i · ${formatDateTime(v.date)}',
                            style: TextStyle(fontSize: 13, color: look.secondaryLabel),
                          ),
                          const SizedBox(height: 4),
                          Text(v.text, style: TextStyle(fontSize: 17, color: look.label)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
);
