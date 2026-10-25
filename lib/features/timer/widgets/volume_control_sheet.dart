import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../services/audio_service.dart';

class VolumeControlSheet extends StatefulWidget {
  final AppThemeConfig theme;

  const VolumeControlSheet({
    super.key,
    required this.theme,
  });

  static Future<void> show(BuildContext context, AppThemeConfig theme) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => VolumeControlSheet(theme: theme),
    );
  }

  @override
  State<VolumeControlSheet> createState() => _VolumeControlSheetState();
}

class _VolumeControlSheetState extends State<VolumeControlSheet> {
  final AudioService _audio = AudioService();
  late double _volume;
  late bool _duckMusic;

  @override
  void initState() {
    super.initState();
    _volume = _audio.notificationVolume;
    _duckMusic = _audio.duckMusicOnVoice;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isLight = theme.isLight;
    final bgColor = isLight ? Colors.white : const Color(0xFF0F172A);
    final textPrimary = isLight ? const Color(0xFF0F172A) : Colors.white;
    final textSecondary = isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final cardBg = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: theme.accent.withValues(alpha: isLight ? 0.2 : 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: isLight ? 0.15 : 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.volume_up_rounded,
                  color: theme.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Громкость тренера',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Сигналы таймера и голос поверх музыки',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Volume Slider Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Уровень громкости',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${(_volume * 100).round()}%',
                        style: GoogleFonts.chakraPetch(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      _volume == 0
                          ? Icons.volume_off_rounded
                          : (_volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                      color: textSecondary,
                      size: 22,
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: theme.accent,
                          inactiveTrackColor: theme.accent.withValues(alpha: 0.2),
                          thumbColor: theme.accent,
                          overlayColor: theme.accent.withValues(alpha: 0.15),
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        ),
                        child: Slider(
                          value: _volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          onChanged: (val) {
                            setState(() {
                              _volume = val;
                            });
                            _audio.setNotificationVolume(val);
                          },
                          onChangeEnd: (val) {
                            HapticFeedback.selectionClick();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Ducking switch card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Приглушать музыку во время речи',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Автоматически понижает звук Spotify / Музыки, когда тренер называет упражнение',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: _duckMusic,
                  activeColor: theme.accent,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _duckMusic = val;
                    });
                    _audio.setDuckMusicOnVoice(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Test Voice Button
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.accent,
                side: BorderSide(color: theme.accent, width: 1.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.record_voice_over_rounded, size: 22),
              label: Text(
                'Проверить голос тренера',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                _audio.testCoachVoice();
              },
            ),
          ),
        ],
      ),
    );
  }
}
