import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConePainter extends CustomPainter {
  final Color startColor;
  final Color endColor;
  ConePainter({
    this.startColor = const Color(0xCC1976D2),
    this.endColor = const Color(0x001976D2),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: [startColor, endColor],
        radius: 1.0,
      ).createShader(Rect.fromCircle(center: Offset(size.width/2, size.height/2), radius: size.width/2))
      ..style = PaintingStyle.fill;

    final Path path = Path();
    // Center the cone and avoid clipping

        final double centerX = size.width / 2 + size.width * 0.06; // Shift further right for more visible alignment
        final double centerY = size.height * 0.5; // Move center up more for recentering
        final double radius = size.height * 0.95; // Keep the cone long

    path.moveTo(centerX, centerY);
        // Narrower cone: -20 to +20 degrees (total 40 degrees)
        path.arcTo(
          Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
          -math.pi / 9, // -20 degrees
          2 * math.pi / 9, // 40 degrees
          false,
        );
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
