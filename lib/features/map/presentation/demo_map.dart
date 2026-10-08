import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../activity/domain/activity.dart';

/// A clearly labelled, offline illustration. It never represents live city data.
class DemoMap extends StatelessWidget {
  const DemoMap({
    super.key,
    this.points = const [],
    this.territories = true,
    this.decorative = false,
    this.controller,
  });
  final List<RoutePoint> points;
  final bool territories, decorative;
  final TransformationController? controller;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => InteractiveViewer(
      transformationController: controller,
      minScale: 1,
      maxScale: 3,
      panEnabled: !decorative,
      scaleEnabled: !decorative,
      child: CustomPaint(
        size: Size(c.maxWidth, c.maxHeight),
        painter: _CityPainter(points, territories, decorative),
      ),
    ),
  );
}

class _CityPainter extends CustomPainter {
  _CityPainter(this.points, this.territories, this.decorative);
  final List<RoutePoint> points;
  final bool territories, decorative;
  void text(
    Canvas canvas,
    String label,
    Offset at, {
    Color color = AppColors.muted,
    double size = 10,
    double angle = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w600,
          letterSpacing: .3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  Path hex(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 3 * i + math.pi / 6;
      final o = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF10161A),
    );
    final random = math.Random(18);
    canvas.save();
    canvas.translate(w * .48, h * .43);
    canvas.rotate(-.29);
    for (var x = -9; x < 10; x++) {
      for (var y = -12; y < 13; y++) {
        final rect = Rect.fromLTWH(x * 43.0 + 5, y * 47.0 + 5, 32, 36);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()
            ..color = random.nextDouble() < .14
                ? const Color(0xFF18251D)
                : const Color(0xFF1B2228),
        );
        if (random.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(
              rect.left + 5,
              rect.top + 7,
              rect.width - 10,
              rect.height - 14,
            ),
            Paint()..color = const Color(0xFF21292F),
          );
        }
      }
    }
    final road = Paint()
      ..color = const Color(0xFF2C353B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    for (var x = -10; x < 11; x += 3) {
      canvas.drawLine(Offset(x * 43.0, -h), Offset(x * 43.0, h), road);
    }
    for (var y = -12; y < 13; y += 4) {
      canvas.drawLine(Offset(-w, y * 47.0), Offset(w, y * 47.0), road);
    }
    canvas.restore();
    final river = Path()
      ..moveTo(-w * .15, h * .12)
      ..cubicTo(w * .15, h * .12, w * .12, h * .35, w * .04, h * .42)
      ..cubicTo(-w * .04, h * .5, w * .2, h * .59, w * .13, h * .72)
      ..cubicTo(w * .08, h * .82, w * .27, h * .84, w * .19, h * 1.1);
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFF172D38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .15,
    );
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFF1D3C4B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .10,
    );
    if (territories) {
      final regions = [
        (Offset(w * .51, h * .39), AppColors.flame, 3),
        (Offset(w * .86, h * .17), AppColors.purple, 2),
        (Offset(w * .81, h * .68), AppColors.green, 2),
      ];
      for (final region in regions) {
        const r = 15.0;
        for (var q = -region.$3; q <= region.$3; q++) {
          for (var j = -region.$3; j <= region.$3; j++) {
            if ((q + j).abs() > region.$3) continue;
            final center =
                region.$1 + Offset(math.sqrt(3) * r * (q + j / 2), 1.5 * r * j);
            final path = hex(center, r - 1.2);
            canvas.drawPath(
              path,
              Paint()..color = region.$2.withValues(alpha: .11),
            );
            canvas.drawPath(
              path,
              Paint()
                ..color = region.$2.withValues(alpha: .4)
                ..style = PaintingStyle.stroke
                ..strokeWidth = .8,
            );
          }
        }
        canvas.drawPath(
          hex(region.$1, 15 * region.$3.toDouble()),
          Paint()
            ..color = region.$2.withValues(alpha: .12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
      }
      text(
        canvas,
        'БЕРІК ТҰЛҒА',
        Offset(w * .51, h * .35),
        color: AppColors.flame,
        size: 11,
      );
      text(
        canvas,
        '12 400 м²',
        Offset(w * .51, h * .385),
        color: AppColors.text,
        size: 9,
      );
      text(
        canvas,
        'NOMAD',
        Offset(w * .86, h * .17),
        color: AppColors.purple,
        size: 9,
      );
      text(
        canvas,
        'QADAM',
        Offset(w * .81, h * .68),
        color: AppColors.green,
        size: 9,
      );
    }
    text(
      canvas,
      'СЫРДАРИЯ',
      Offset(w * .07, h * .55),
      color: const Color(0xFF5C8496),
      size: 9,
      angle: 1.1,
    );
    text(
      canvas,
      'Абай даңғылы',
      Offset(w * .52, h * .20),
      size: 10,
      angle: -.29,
    );
    text(
      canvas,
      'Желтоқсан көшесі',
      Offset(w * .69, h * .53),
      size: 9,
      angle: -.29,
    );
    text(
      canvas,
      'Орталық саябақ',
      Offset(w * .29, h * .70),
      color: const Color(0xFF6A8A77),
      size: 9,
    );
    text(
      canvas,
      'ҚЫЗЫЛОРДА',
      Offset(w * .5, h * .10),
      color: const Color(0xFF74818B),
      size: 12,
    );
    Offset project(RoutePoint p) => Offset(
      w * .51 + (p.longitude - AppConfig.cityLongitude) * w * 75,
      h * .41 - (p.latitude - AppConfig.cityLatitude) * h * 85,
    );
    final route = points.where((p) => p.accepted).toList();
    if (route.length > 1) {
      final path = Path();
      for (var i = 0; i < route.length; i++) {
        final o = project(route[i]);
        if (i == 0 || route[i].segmentStart) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.flame.withValues(alpha: .4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.flame
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawCircle(
        project(route.first),
        5,
        Paint()..color = AppColors.green,
      );
    }
    final user = route.isEmpty ? Offset(w * .52, h * .44) : project(route.last);
    canvas.drawCircle(
      user,
      23,
      Paint()..color = AppColors.flame.withValues(alpha: .10),
    );
    canvas.drawCircle(
      user,
      14,
      Paint()..color = AppColors.flame.withValues(alpha: .14),
    );
    canvas.drawCircle(user, 7, Paint()..color = AppColors.flame);
    canvas.drawCircle(
      user,
      7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Dark gradients give floating controls a quiet, readable backdrop.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: .65),
            Colors.transparent,
            Colors.transparent,
            AppColors.background.withValues(alpha: .8),
          ],
          stops: const [0, .18, .64, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_CityPainter old) =>
      old.points != points || old.territories != territories;
}
