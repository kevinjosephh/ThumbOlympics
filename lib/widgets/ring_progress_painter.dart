import 'dart:math' as math;
import 'package:flutter/material.dart';

class RingProgressPainter extends CustomPainter {
  final double progress; // 0..1
  final Color backgroundColor;
  final Color foregroundColor;
  final double strokeWidth;

  RingProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - (strokeWidth / 2);

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Background ring
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final startAngle = -math.pi / 2; // Start from top
      final sweepAngle = 2 * math.pi * progress;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, startAngle, sweepAngle, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RingProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}