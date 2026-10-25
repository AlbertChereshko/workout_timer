import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../domain/timer_state.dart';

class NeonAmbientBackground extends StatefulWidget {
  final TimerPhase phase;
  final double progress;
  final AppThemeConfig? theme;
  final bool isRunning;

  const NeonAmbientBackground({
    super.key,
    required this.phase,
    required this.progress,
    this.theme,
    this.isRunning = true,
  });

  @override
  State<NeonAmbientBackground> createState() => _NeonAmbientBackgroundState();
}

class _NeonAmbientBackgroundState extends State<NeonAmbientBackground>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final AnimationController _heartbeatController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.phase == TimerPhase.countdown) {
      _shimmerController.repeat();
    }

    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    if (widget.isRunning && widget.phase != TimerPhase.finished) {
      _heartbeatController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant NeonAmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 1. Шиммер обратного отсчета
    if (widget.phase == TimerPhase.countdown) {
      if (!_shimmerController.isAnimating) {
        _shimmerController.repeat();
      }
    } else {
      if (_shimmerController.isAnimating) {
        _shimmerController.stop();
        _shimmerController.reset();
      }
    }

    // 2. Круговая пульсация в ритме сердца
    if (widget.isRunning && widget.phase != TimerPhase.finished) {
      if (!_heartbeatController.isAnimating) {
        _heartbeatController.repeat();
      }
    } else {
      if (_heartbeatController.isAnimating) {
        _heartbeatController.stop();
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _heartbeatController.dispose();
    super.dispose();
  }

  Color _getPrimaryNeonColor() {
    if (widget.phase == TimerPhase.rest) {
      return const Color(0xFF00E676); // Сочный зеленый неон во время отдыха
    }
    if (widget.theme != null) {
      switch (widget.phase) {
        case TimerPhase.work:
          return widget.theme!.workPhase;
        case TimerPhase.rest:
          return const Color(0xFF00E676);
        case TimerPhase.countdown:
          return widget.theme!.countdownPhase;
        case TimerPhase.finished:
          return widget.theme!.accent;
      }
    }
    switch (widget.phase) {
      case TimerPhase.work:
        return const Color(0xFF00E676);
      case TimerPhase.rest:
        return const Color(0xFF00E676);
      case TimerPhase.countdown:
        return const Color(0xFFF59E0B);
      case TimerPhase.finished:
        return const Color(0xFF10B981);
    }
  }

  Color _getSecondaryNeonColor() {
    if (widget.phase == TimerPhase.rest) {
      return const Color(0xFF10B981); // Изумрудно-зеленый оттенок
    }
    if (widget.theme != null) {
      return widget.theme!.accent;
    }
    switch (widget.phase) {
      case TimerPhase.work:
        return const Color(0xFF76FF03);
      case TimerPhase.rest:
        return const Color(0xFF10B981);
      case TimerPhase.countdown:
        return const Color(0xFFFF9100);
      case TimerPhase.finished:
        return const Color(0xFF059669);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = widget.theme?.isLight ?? false;
    final bgColor = widget.theme?.background ?? const Color(0xFF060911);
    final primary = _getPrimaryNeonColor();
    final secondary = _getSecondaryNeonColor();

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      tween: ColorTween(end: primary),
      builder: (context, animatedPrimary, _) {
        final p = animatedPrimary ?? primary;
        final auraAlpha1 = isLight ? 0.12 : 0.38;
        final auraAlpha2 = isLight ? 0.05 : 0.15;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Фон (адаптивный к выбранной теме)
            ColoredBox(color: bgColor),

            // Левое боковое неоновое свечение (vignette aura)
            Positioned(
              left: -120,
              top: 100,
              bottom: 100,
              width: 240,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(200),
                    gradient: RadialGradient(
                      center: Alignment.centerLeft,
                      radius: 1.0,
                      colors: [
                        p.withValues(alpha: auraAlpha1),
                        p.withValues(alpha: auraAlpha2),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Правое боковое неоновое свечение (vignette aura)
            Positioned(
              right: -120,
              top: 100,
              bottom: 100,
              width: 240,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(200),
                    gradient: RadialGradient(
                      center: Alignment.centerRight,
                      radius: 1.0,
                      colors: [
                        p.withValues(alpha: auraAlpha1),
                        p.withValues(alpha: auraAlpha2),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Нижнее фоновое рассеянное свечение
            Positioned(
              left: 0,
              right: 0,
              bottom: -60,
              height: 260,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.bottomCenter,
                      radius: 0.9,
                      colors: [
                        secondary.withValues(alpha: isLight ? 0.12 : 0.28),
                        p.withValues(alpha: isLight ? 0.05 : 0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // КРУГОВАЯ НЕОНОВАЯ АНИМАЦИЯ В РИТМЕ СЕРДЦА, ИСХОДЯЩАЯ ИЗ ЦЕНТРА
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _heartbeatController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _NeonHeartbeatPainter(
                        progress: _heartbeatController.value,
                        primaryColor: p,
                        secondaryColor: secondary,
                        isLight: isLight,
                        isRunning: widget.isRunning,
                      ),
                    );
                  },
                ),
              ),
            ),

            // АКТИВНЫЙ АНИМИРОВАННЫЙ ШИММЕР-ПЕРЕЛИВ (SHIMMER) ПРИ ОБРАТНОМ ОТСЧЕТЕ (3..2..1)
            if (widget.phase == TimerPhase.countdown)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, _) {
                      final t = _shimmerController.value;
                      final shimmerAlpha1 = isLight ? 0.18 : 0.35;
                      final shimmerAlpha2 = isLight ? 0.08 : 0.18;

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Диагональная скользящая волна неонового сияния
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-2.5 + 4.0 * t, -1.0),
                                end: Alignment(-0.5 + 4.0 * t, 1.0),
                                colors: [
                                  Colors.transparent,
                                  p.withValues(alpha: shimmerAlpha2),
                                  const Color(0xFF00E676).withValues(alpha: shimmerAlpha1),
                                  secondary.withValues(alpha: shimmerAlpha2),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.35, 0.50, 0.65, 1.0],
                              ),
                            ),
                          ),
                          // 2. Пульсирующее центральное неоновое кольцо
                          Center(
                            child: Container(
                              width: 340 + 40 * math.sin(t * 2 * math.pi),
                              height: 340 + 40 * math.sin(t * 2 * math.pi),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    p.withValues(alpha: isLight ? 0.15 : 0.22),
                                    secondary.withValues(alpha: isLight ? 0.06 : 0.10),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

            // Верхнее легкое затемнение для контраста статус-бара
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        isLight
                            ? bgColor.withValues(alpha: 0.6)
                            : const Color(0xFF060911).withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Художник круговой неоновой анимации, исходящей из центра и плавно расплывающейся
/// Художник круговой неоновой анимации с эффектом плавности и широких волн,
/// плавно расплывающихся от центра экрана к краям.
class _NeonHeartbeatPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isLight;
  final bool isRunning;

  _NeonHeartbeatPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isLight,
    required this.isRunning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Центр анимации совпадает с областью основного таймера / центра экрана
    final center = Offset(size.width / 2, size.height * 0.45);
    final double maxRadius = math.sqrt(size.width * size.width + size.height * size.height) * 0.72;

    // Плавное дыхание центрального неонового ядра (синусоидальное покачивание)
    final double breathScale = 0.5 + 0.5 * math.sin(progress * 2 * math.pi);
    final double coreRadius = 45.0 + 15.0 * breathScale;
    final double coreAlpha = isLight
        ? (0.08 + 0.06 * breathScale)
        : (0.18 + 0.12 * breathScale);

    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: coreAlpha),
          secondaryColor.withValues(alpha: coreAlpha * 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius * 2.2));
    canvas.drawCircle(center, coreRadius * 2.2, corePaint);

    // 3 широких волновых фронта со сдвигом фазы (0.0, 0.33, 0.67) для непрерывного плавного течения
    _drawBroadNeonWave(
      canvas: canvas,
      center: center,
      waveProgress: progress,
      maxRadius: maxRadius,
      color: primaryColor,
      isSecondary: false,
    );

    final double wave2 = (progress + 0.33) % 1.0;
    _drawBroadNeonWave(
      canvas: canvas,
      center: center,
      waveProgress: wave2,
      maxRadius: maxRadius,
      color: secondaryColor,
      isSecondary: true,
    );

    final double wave3 = (progress + 0.67) % 1.0;
    _drawBroadNeonWave(
      canvas: canvas,
      center: center,
      waveProgress: wave3,
      maxRadius: maxRadius,
      color: Color.lerp(primaryColor, secondaryColor, 0.5)!,
      isSecondary: false,
    );
  }

  void _drawBroadNeonWave({
    required Canvas canvas,
    required Offset center,
    required double waveProgress,
    required double maxRadius,
    required Color color,
    required bool isSecondary,
  }) {
    // Плавное мягкое расширение (easeOutQuad)
    final double curved = Curves.easeOutQuad.transform(waveProgress);
    final double currentRadius = 30.0 + (maxRadius - 30.0) * curved;

    // Плавная куполообразная огибающая прозрачности: мягкое нарастание и мягкое затухание
    final double envelope = math.sin(waveProgress * math.pi);
    final double maxAlpha = isLight
        ? (isSecondary ? 0.12 : 0.16)
        : (isSecondary ? 0.24 : 0.32);
    final double waveAlpha = maxAlpha * envelope;

    if (waveAlpha <= 0.005) return;

    // 1. Широкая рассеянная аура волны (широкий радиальный градиент)
    final double bandWidth = 70.0 + 80.0 * waveProgress;
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          color.withValues(alpha: waveAlpha * 0.15),
          color.withValues(alpha: waveAlpha * 0.35),
          color.withValues(alpha: waveAlpha * 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.70, 0.90, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: currentRadius + bandWidth / 2));
    canvas.drawCircle(center, currentRadius + bandWidth / 2, auraPaint);

    // 2. Широкий размытый гребень волны (soft blurred neon wave crest)
    final blurPaint = Paint()
      ..color = color.withValues(alpha: waveAlpha * 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isSecondary ? 14.0 : 20.0) * (1.0 - waveProgress * 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18.0 * (1.0 + waveProgress * 0.4));
    canvas.drawCircle(center, currentRadius, blurPaint);

    // 3. Мягкая концентрическая неоновая линия внутри волны
    final strokePaint = Paint()
      ..color = (isLight ? color : Colors.white).withValues(alpha: waveAlpha * 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isSecondary ? 2.0 : 2.8) * (1.0 - waveProgress * 0.3);
    canvas.drawCircle(center, currentRadius, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _NeonHeartbeatPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.isLight != isLight ||
        oldDelegate.isRunning != isRunning;
  }
}
