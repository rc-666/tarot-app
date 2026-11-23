import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/cards.dart';
import '../../theme/app_theme.dart';

/// One deck card (card-deck-spec.md): art + gold frame + live text, on a 240 × 403 design grid.
/// Face down when [cardId] is null. Below 120 dp wide it uses the plain frame and no text on the
/// card; the caller shows the name as UI text under it. Reversed turns only the art.
class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.width, this.cardId, this.name, this.reversed = false});
  final double width;
  final String? cardId; // deck id (m19, c03, ...); null = face down
  final String? name; // translated card name; shown on full-size cards as "THE SUN."
  final bool reversed;

  static const _w = 240.0; // design grid width (card is 240 × 403)
  static bool isThumb(double width) => width < 120;

  /// Images the reveal needs, decoded ahead so the flip never waits (spec: precacheImage).
  static Future<void> precache(BuildContext context, Iterable<String> ids, double width) {
    final thumb = isThumb(width);
    final px = (192 * width / _w * MediaQuery.devicePixelRatioOf(context)).round(); // same size the card decodes
    return Future.wait([
      for (final id in ids) precacheImage(ResizeImage(AssetImage('assets/deck/art/$id.webp'), width: px), context),
      precacheImage(AssetImage(thumb ? 'assets/deck/frame/frame_thumb.png' : 'assets/deck/frame/frame.png'), context),
      precacheImage(AssetImage(thumb ? 'assets/deck/back/back_thumb.webp' : 'assets/deck/back/back.webp'), context),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final size = AppSize.card(width);
    final thumb = isThumb(width);
    final id = cardId;
    if (id == null) {
      return Image.asset(thumb ? 'assets/deck/back/back_thumb.webp' : 'assets/deck/back/back.webp',
          width: size.width, height: size.height, fit: BoxFit.fill);
    }
    final k = size.width / _w; // design unit -> dp
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget art = Image.asset('assets/deck/art/$id.webp', fit: BoxFit.fill, cacheWidth: (192 * k * dpr).round());
    if (reversed) art = RotatedBox(quarterTurns: 2, child: art);
    final numeral = cardNumeral(id);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(children: [
        Positioned(left: 24 * k, top: 52 * k, width: 192 * k, height: 298 * k, child: art),
        Positioned.fill(
          child: Image.asset(thumb ? 'assets/deck/frame/frame_thumb.png' : 'assets/deck/frame/frame.png', fit: BoxFit.fill),
        ),
        if (!thumb && numeral.isNotEmpty)
          Positioned(left: 0, right: 0, top: 22 * k, height: 20 * k, child: _text(numeral, 17 * k, 1 * k, const Color(0xFF3A2412))),
        if (!thumb && name != null)
          Positioned(
            left: 34 * k, // max width 172
            right: 34 * k,
            top: 359 * k,
            height: 18 * k,
            child: _text('${name!.toUpperCase()}.', 15 * k, 2 * k, const Color(0xFFE6CB98)),
          ),
      ]),
    );
  }

  static Widget _text(String t, double size, double spacing, Color color) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(t,
            maxLines: 1,
            textScaler: TextScaler.noScaling, // part of the card art; the card itself scales
            style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.w600, fontSize: size, letterSpacing: spacing, color: color, height: 1)),
      );

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
              name: widget.name,
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
