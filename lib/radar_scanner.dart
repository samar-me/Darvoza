import 'dart:math' as math;
import 'package:flutter/material.dart';

class CyberRadarWidget extends StatefulWidget {
  final double size;
  final Color primaryColor;
  final String statusText;
  final double progress; // 0.0 dan 1.0 gacha

  const CyberRadarWidget({
    super.key,
    this.size = 220,
    this.primaryColor = const Color(0xFF00FF88),
    this.statusText = "SKANERLANMOQDA...",
    this.progress = 0.5,
  });

  @override
  State<CyberRadarWidget> createState() => _CyberRadarWidgetState();
}

class _CyberRadarWidgetState extends State<CyberRadarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return CustomPaint(
                painter: _CyberRadarPainter(
                  angle: _rotationController.value * 2 * math.pi,
                  color: widget.primaryColor,
                  progress: widget.progress,
                ),
                child: Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0A0F1D),
                      border: Border.all(
                        color: widget.primaryColor.withValues(alpha: 0.8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "${(widget.progress * 100).toInt()}%",
                        style: TextStyle(
                          color: widget.primaryColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.statusText,
                style: TextStyle(
                  color: widget.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CyberRadarPainter extends CustomPainter {
  final double angle;
  final Color color;
  final double progress;

  _CyberRadarPainter({
    required this.angle,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Tashqi doira panjarasi
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius, gridPaint);
    canvas.drawCircle(center, radius * 0.72, gridPaint);
    canvas.drawCircle(center, radius * 0.44, gridPaint);

    // Kiber radial burchaklar
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;

    for (int i = 0; i < 12; i++) {
      final a = (i * 30) * math.pi / 180;
      final start = Offset(
        center.dx + (radius - 8) * math.cos(a),
        center.dy + (radius - 8) * math.sin(a),
      );
      final end = Offset(
        center.dx + radius * math.cos(a),
        center.dy + radius * math.sin(a),
      );
      canvas.drawLine(start, end, tickPaint);
    }

    // Aylanuvchi radar konusi (Sweep gradient)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.45),
        ],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, sweepPaint);

    // Old yetakchi skaner chizig'i
    final leadLinePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 2.0;

    final leadEnd = Offset(
      center.dx + radius * math.cos(angle + math.pi / 2),
      center.dy + radius * math.sin(angle + math.pi / 2),
    );
    canvas.drawLine(center, leadEnd, leadLinePaint);
  }

  @override
  bool shouldRepaint(covariant _CyberRadarPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.progress != progress;
  }
}
