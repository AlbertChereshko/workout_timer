import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme/app_typography.dart';

/// Large circular countdown widget with an arc that drains as time passes and a subtle pulsing glow.
class CircularTimerWidget extends StatefulWidget {
  const CircularTimerWidget({
    super.key,
    required this.remaining,
    required this.total,
    required this.phaseColor,
    this.size = 240,
    this.textColor,
    this.trackColor,
    this.arcColor,
  });

  final Duration remaining;
  final Duration total;
  final Color phaseColor;
  final double size;
  final Color? textColor;
  final Color? trackColor;
  final Color? arcColor;

  @override
  State<CircularTimerWidget> createState() => _CircularTimerWidgetState();
}

class _CircularTimerWidgetState extends State<CircularTimerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.total.inMilliseconds > 0
        ? widget.remaining.inMilliseconds / widget.total.inMilliseconds
        : 0.0;

    final mins = widget.remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = widget.remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final label = '$mins:$secs';

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.phaseColor.withValues(alpha: 0.25 * _pulseController.value),
                  blurRadius: 28 * _pulseController.value,
                  spreadRadius: 4 * _pulseController.value,
                ),
              ],
            ),
            child: CustomPaint(
              painter: _ArcPainter(
                progress: progress.clamp(0.0, 1.0),
                color: widget.phaseColor,
                trackColor: widget.trackColor ?? AppColors.cardBorder,
                arcColor: widget.arcColor ?? widget.textColor ?? (widget.phaseColor),
              ),
              child: Center(
                child: Text(
                  label,
                  style: AppTypography.timerDisplay(
                    color: widget.textColor ?? AppColors.textPrimary,
                    fontSize: widget.size * 0.28,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.arcColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final Color arcColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 12;
    const strokeWidth = 10.0;
    const startAngle = -math.pi / 2;

    // Background track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress > 0) {
      // Remaining arc.
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = arcColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // Phase-colored small dot at tip.
    if (progress > 0) {
      final angle = startAngle + 2 * math.pi * progress;
      final dotX = center.dx + radius * math.cos(angle);
      final dotY = center.dy + radius * math.sin(angle);
      canvas.drawCircle(
        Offset(dotX, dotY),
        strokeWidth / 2 + 2,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.arcColor != arcColor;
}
