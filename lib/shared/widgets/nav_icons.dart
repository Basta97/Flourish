import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The four tab glyphs, drawn on a 24-unit grid with round caps so they read
/// as one family.
enum NavGlyph { home, ledger, accounts, insights }

/// A tab icon that fills in when selected and plays a short flourish each
/// time it becomes selected: the roof settles, receipt lines write
/// themselves, a card slides into the wallet, the chart line draws.
///
/// [fill] (0–1) blends outline → solid; [flourish] (0–1) drives the
/// one-shot detail animation and rests at 1. [cutout] paints details that
/// sit on top of the solid shape, normally the bar's background.
class NavIcon extends StatelessWidget {
  const NavIcon({
    super.key,
    required this.glyph,
    required this.color,
    required this.cutout,
    this.fill = 0,
    this.flourish = 1,
    this.size = 24,
  });

  final NavGlyph glyph;
  final Color color;
  final Color cutout;
  final double fill;
  final double flourish;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _NavIconPainter(glyph, color, cutout, fill, flourish),
    );
  }
}

class _NavIconPainter extends CustomPainter {
  _NavIconPainter(this.glyph, this.color, this.cutout, this.fill, this.t);

  final NavGlyph glyph;
  final Color color;
  final Color cutout;
  final double fill;
  final double t;

  late final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.9
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  late final Paint _solid = Paint()
    ..style = PaintingStyle.fill
    ..color = color.withValues(alpha: color.a * fill);

  /// Details on top of the body: the icon color while outlined, the cutout
  /// color once solid, so they stay visible either way.
  late final Paint _detail = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.9
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = Color.lerp(color, cutout, fill)!;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    switch (glyph) {
      case NavGlyph.home:
        _home(canvas);
      case NavGlyph.ledger:
        _ledger(canvas);
      case NavGlyph.accounts:
        _accounts(canvas);
      case NavGlyph.insights:
        _insights(canvas);
    }
  }

  // Overshoots once and settles, for the little "pop" details.
  double get _pop => t >= 1 ? 0 : math.sin(t * math.pi) * (1 - t);

  void _body(Canvas canvas, Path path) {
    if (fill > 0) canvas.drawPath(path, _solid);
    canvas.drawPath(path, _stroke);
  }

  /// Draws the first [progress] of [path].
  void _drawPartial(Canvas canvas, Path path, double progress, Paint paint) {
    if (progress <= 0) return;
    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final ui.PathMetric metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  void _home(Canvas canvas) {
    // The roof dips and springs back as the tab is chosen.
    final lift = -2.2 * _pop;
    final house = Path()
      ..moveTo(4, 10.6)
      ..lineTo(12, 4 + lift)
      ..lineTo(20, 10.6)
      ..lineTo(20, 18.5)
      ..quadraticBezierTo(20, 20.5, 18, 20.5)
      ..lineTo(6, 20.5)
      ..quadraticBezierTo(4, 20.5, 4, 18.5)
      ..close();
    _body(canvas, house);
    final door = Path()
      ..moveTo(10, 20.5)
      ..lineTo(10, 16.2)
      ..quadraticBezierTo(10, 14.8, 12, 14.8)
      ..quadraticBezierTo(14, 14.8, 14, 16.2)
      ..lineTo(14, 20.5);
    canvas.drawPath(door, _detail);
  }

  void _ledger(Canvas canvas) {
    final receipt = Path()
      ..moveTo(6.5, 3.5)
      ..lineTo(17.5, 3.5)
      ..quadraticBezierTo(19, 3.5, 19, 5)
      ..lineTo(19, 20.5)
      ..lineTo(16.7, 19)
      ..lineTo(14.3, 20.5)
      ..lineTo(12, 19)
      ..lineTo(9.7, 20.5)
      ..lineTo(7.3, 19)
      ..lineTo(5, 20.5)
      ..lineTo(5, 5)
      ..quadraticBezierTo(5, 3.5, 6.5, 3.5)
      ..close();
    _body(canvas, receipt);
    // The lines write themselves one after another.
    const lines = [(8.5, 8.4, 15.5), (8.5, 11.9, 15.5), (8.5, 15.4, 12.5)];
    for (var i = 0; i < lines.length; i++) {
      final (x0, y, x1) = lines[i];
      final start = i * 0.18;
      final p = ((t - start) / (1 - start * 2)).clamp(0.0, 1.0);
      _drawPartial(
        canvas,
        Path()
          ..moveTo(x0, y)
          ..lineTo(x1, y),
        Curves.easeOutCubic.transform(p),
        _detail,
      );
    }
  }

  void _accounts(Canvas canvas) {
    // A card rises out of the wallet and drops back in.
    final rise = -3.2 * _pop;
    final card = RRect.fromLTRBR(
      6.5,
      3.6 + rise,
      17.5,
      10,
      const Radius.circular(1.6),
    );
    canvas.drawRRect(card, _stroke);
    final wallet = Path()
      ..addRRect(
        RRect.fromLTRBR(3.5, 7.2, 20.5, 20.5, const Radius.circular(3.2)),
      );
    // The wallet always covers the bottom of the card behind it.
    canvas.drawPath(wallet, Paint()..color = Color.lerp(cutout, color, fill)!);
    canvas.drawPath(wallet, _stroke);
    final clasp = RRect.fromLTRBR(
      14.5,
      11.6,
      20.5,
      16.1,
      const Radius.circular(2),
    );
    canvas.drawRRect(clasp, _detail);
    canvas.drawCircle(
      const Offset(17.1, 13.85),
      0.9,
      Paint()..color = _detail.color,
    );
  }

  void _insights(Canvas canvas) {
    final line = Path()
      ..moveTo(4, 16.5)
      ..lineTo(8.8, 11.2)
      ..lineTo(12.6, 14.2)
      ..lineTo(19.5, 6.8);
    if (fill > 0) {
      final area = Path.from(line)
        ..lineTo(19.5, 19.5)
        ..lineTo(4, 19.5)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, 7),
            const Offset(0, 20),
            [
              color.withValues(alpha: color.a * 0.55 * fill),
              color.withValues(alpha: 0),
            ],
          ),
      );
    }
    // Baseline, then the trend line drawn left to right.
    canvas.drawLine(const Offset(4, 20), const Offset(20, 20), _stroke);
    _drawPartial(canvas, line, Curves.easeInOutCubic.transform(t), _stroke);
    // A spark at the peak once the line arrives.
    final spark = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
    if (spark > 0) {
      canvas.drawCircle(
        const Offset(19.5, 6.8),
        1.9 * Curves.easeOutBack.transform(spark),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_NavIconPainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.cutout != cutout ||
      old.fill != fill ||
      old.t != t;
}
