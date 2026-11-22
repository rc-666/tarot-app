import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Static card face. Art comes from `assets/cards/<id>.webp` (Rider–Waite 1909 scans, to be supplied);
/// until then a placeholder frame is drawn, as in the lo-fi designs.
class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.width, this.cardId, this.name, this.reversed = false, this.showName = true});
  final double width;
  final String? cardId; // null = face down
  final String? name;
  final bool reversed;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final size = AppSize.card(width);
    final faceDown = cardId == null;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.primary, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(5),
      child: faceDown ? _back() : _front(size),
    );
  }

  Widget _back() => Container(
        decoration: BoxDecoration(border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(3)),
        alignment: Alignment.center,
        child: Icon(Icons.nightlight_round, color: AppColors.primary, size: width * 0.16), // placeholder crescent
      );

  Widget _front(Size size) {
    final art = Image.asset(
      'assets/cards/$cardId.webp',
      fit: BoxFit.cover,
      cacheWidth: (width * 3).round(), // keeps memory low on 2 GB phones
      errorBuilder: (_, __, ___) => CustomPaint(painter: _PlaceholderArt(), child: const SizedBox.expand()),
    );
    return Column(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: reversed ? Transform.rotate(angle: math.pi, child: art) : art,
        ),
      ),
      if (showName && name != null && width >= 80)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(name!, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: AppColors.textPrimary, height: 1.15)),
        ),
    ]);
  }
}

class _PlaceholderArt extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = AppColors.divider);
    final p = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    c.drawLine(Offset.zero, Offset(s.width, s.height), p);
    c.drawLine(Offset(s.width, 0), Offset(0, s.height), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The reveal (spec 5): lift 4 dp (120 ms) → flip on Y with perspective, face swaps at 90° (500 ms)
/// → settle + gold hairline traced clockwise (300 ms). Transform + one AnimationController only.
/// With "Remove animations" on, the card turns face up instantly.
class RevealCard extends StatefulWidget {
  const RevealCard({
    super.key,
    required this.width,
    required this.revealed,
    required this.animate,
    required this.cardId,
    required this.name,
    required this.reversed,
    this.onTap,
    this.onRevealed,
  });
  final double width;
  final bool revealed;
  final bool animate; // false on 5h (reopened)
  final String cardId;
  final String name;
  final bool reversed;
  final VoidCallback? onTap;
  final VoidCallback? onRevealed; // after the flip ends (name + panel fade in then)

  @override
  State<RevealCard> createState() => _RevealCardState();
}

class _RevealCardState extends State<RevealCard> with SingleTickerProviderStateMixin {
  static const _lift = 120, _flip = 500, _settle = 300;
  static const _total = _lift + _flip + _settle;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: _total));
  late final Animation<double> _liftA = CurvedAnimation(parent: _c, curve: const Interval(0, _lift / _total, curve: Curves.easeOut));
  late final Animation<double> _flipA =
      CurvedAnimation(parent: _c, curve: const Interval(_lift / _total, (_lift + _flip) / _total, curve: AppMotion.flipCurve));
  late final Animation<double> _settleA =
      CurvedAnimation(parent: _c, curve: const Interval((_lift + _flip) / _total, 1, curve: Curves.easeOut));
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    if (widget.revealed) _c.value = 1;
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_notified) {
        _notified = true;
        widget.onRevealed?.call();
      }
    });
    _c.addListener(() {
      // Report the reveal when the flip ends, before the hairline finishes (spec step 4).
      if (!_notified && _c.value >= (_lift + _flip) / _total) {
        _notified = true;
        widget.onRevealed?.call();
      }
    });
  }

  @override
  void didUpdateWidget(RevealCard old) {
    super.didUpdateWidget(old);
    if (widget.revealed && !old.revealed) {
      final reduce = MediaQuery.of(context).disableAnimations;
      if (!widget.animate || reduce) {
        _c.value = 1;
        if (!_notified) {
          _notified = true;
          widget.onRevealed?.call();
        }
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return GestureDetector(
      onTap: widget.revealed ? null : widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final angle = _flipA.value * math.pi;
            final showFront = _flipA.value >= 0.5;
            final lift = -4.0 * (_liftA.value - _settleA.value);
            Widget face = CardFace(
              width: widget.width,
              cardId: showFront ? widget.cardId : null,
              name: showFront && _c.value > 0.99 ? widget.name : null,
              reversed: widget.reversed,
            );
            if (showFront) face = Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: face);
            final hairline = (reduce || !widget.animate) ? 0.0 : _settleA.value;
            // Hairline sits outside the rotation so it traces clockwise on screen.
            return Transform.translate(
              offset: Offset(0, lift),
              child: CustomPaint(
                foregroundPainter: hairline > 0 && hairline < 1 ? _Hairline(hairline) : null,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  child: face,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Hairline extends CustomPainter {
  _Hairline(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(AppRadius.card)));
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_Hairline old) => old.t != t;
}
