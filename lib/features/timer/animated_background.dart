import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../domain/timer_state.dart';

class AnimatedBackground extends StatefulWidget {
  final TimerPhase phase;
  final double progress;
  final AppThemeConfig? theme;

  const AnimatedBackground({
    super.key,
    required this.phase,
    required this.progress,
    this.theme,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Color _getPhaseColor() {
    final t = widget.theme ?? AppTheme.currentConfig;
    switch (widget.phase) {
      case TimerPhase.countdown:
        return t.countdownPhase;
      case TimerPhase.work:
        // Vibrant energetic red / orange for Work
        return const Color(0xFFFF3B30);
      case TimerPhase.rest:
        // Calming cool blue / cyan for Rest
        return const Color(0xFF00C7BE);
      case TimerPhase.finished:
        return t.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = widget.theme ?? AppTheme.currentConfig;
    final isLight = currentTheme.isLight;
    final targetColor = _getPhaseColor();
    final fillAmount = 1.0 - widget.progress; 

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 300),
      tween: ColorTween(end: targetColor),
      builder: (context, color, child) {
        final c = color ?? targetColor;
        
        return Stack(
          children: [
            Container(color: currentTheme.background), // Base background
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, _) {
                  // Create a shifting gradient effect
                  final shift = _shimmerController.value;
                  
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 1000), 
                    curve: Curves.linear,
                    height: MediaQuery.of(context).size.height * fillAmount,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + shift, -1.0),
                        end: Alignment(1.0 - shift, 1.0),
                        colors: isLight
                            ? [
                                c.withValues(alpha: 0.08),
                                c.withValues(alpha: 0.16),
                                c.withValues(alpha: 0.06),
                              ]
                            : [
                                c.withValues(alpha: 0.2),
                                c.withValues(alpha: 0.4),
                                c.withValues(alpha: 0.15),
                              ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
