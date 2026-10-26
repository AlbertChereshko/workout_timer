import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';

class MusicService {
  static const MethodChannel _appLauncherChannel =
      MethodChannel('com.workoutapp.workout_timer/app_launcher');

  static const String spotifyPackage = 'com.spotify.music';
  static const String spotifyUri = 'spotify:';
  static const String spotifyWebUrl = 'https://open.spotify.com';
  
  static const String ytMusicPackage = 'com.google.android.apps.youtube.music';
  static const String ytMusicUri = 'youtubemusic:';
  static const String ytMusicWebUrl = 'https://music.youtube.com';

  static const String libreTubePackage = 'com.github.libretube';

  /// Запуск Spotify напрямую в установленное нативное приложение (без посредников)
  static Future<bool> openSpotify() async {
    HapticFeedback.mediumImpact();

    // 1. Прямой запуск через нативный Android Intent по имени пакета (гарантирует отсутствие браузера)
    try {
      final bool? launched = await _appLauncherChannel.invokeMethod<bool>(
        'launchApp',
        {'package': spotifyPackage},
      );
      if (launched == true) return true;
    } catch (_) {}

    // 2. Попытка через нативный URI схемы без участия браузера
    final Uri nativeUri = Uri.parse(spotifyUri);
    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (_) {}

    // 3. Крайний случай, если приложение не установлено вовсе — переход на веб
    final Uri webUri = Uri.parse(spotifyWebUrl);
    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Запуск YouTube Music напрямую в установленное нативное приложение (без посредников)
  static Future<bool> openYouTubeMusic() async {
    HapticFeedback.mediumImpact();

    // 1. Прямой запуск через нативный Android Intent по имени пакета (гарантирует открытие нативного приложения)
    try {
      final bool? launched = await _appLauncherChannel.invokeMethod<bool>(
        'launchApp',
        {'package': ytMusicPackage},
      );
      if (launched == true) return true;
    } catch (_) {}

    // 2. Попытка через нативную схему без браузера
    final Uri nativeUri = Uri.parse(ytMusicUri);
    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (_) {}

    // 3. Попытка через App Link нативного приложения без браузера
    final Uri webUri = Uri.parse(ytMusicWebUrl);
    try {
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (_) {}

    // 4. Крайний случай, если приложение не установлено — открытие веб-версии
    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Выбор и открытие любого локального аудиофайла на устройстве через проводник
  static Future<bool> pickAndOpenAudioFile(BuildContext context) async {
    HapticFeedback.mediumImpact();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'opus'],
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final openRes = await OpenFilex.open(path, type: 'audio/*');
        return openRes.type == ResultType.done;
      }
    } catch (e) {
      debugPrint('Error picking or opening audio file: $e');
    }
    return false;
  }

  /// Запуск стандартного музыкального плеера телефона
  static Future<bool> openPhoneMusicPlayer() async {
    HapticFeedback.mediumImpact();
    try {
      final bool? launched = await _appLauncherChannel.invokeMethod<bool>('launchMusicPlayer');
      if (launched == true) return true;
    } catch (_) {}
    return false;
  }

  /// Запуск приложения LibreTube
  static Future<bool> openLibreTube() async {
    HapticFeedback.mediumImpact();
    try {
      final bool? launched = await _appLauncherChannel.invokeMethod<bool>(
        'launchApp',
        {'package': libreTubePackage},
      );
      if (launched == true) return true;
    } catch (_) {}
    return false;
  }

  /// Показ всплывающей панели выбора музыки (в стиле Waze)
  static void showMusicPickerSheet(BuildContext context, AppThemeConfig theme) {
    HapticFeedback.lightImpact();
    final isLight = theme.isLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF0F1524),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isLight ? Colors.black.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.5),
              blurRadius: 32,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Полоска-индикатор шторки
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Заголовок в стиле навигатора
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: isLight ? 0.15 : 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: theme.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'МУЗЫКА ДЛЯ ТРЕНИРОВКИ',
                        style: GoogleFonts.chakraPetch(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isLight ? const Color(0xFF0A0F1D) : Colors.white,
                        ),
                      ),
                      Text(
                        'Звуки таймера не прерывают воспроизведение',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isLight ? const Color(0xFF64748B) : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Кнопка: Аудиофайл на телефоне (поиск и выбор через проводник)
            _buildMusicAppButton(
              context: ctx,
              title: 'Аудиофайл на телефоне',
              subtitle: 'Поиск и открытие трека (MP3, M4A, FLAC...)',
              iconColor: const Color(0xFF3B82F6),
              icon: Icons.audio_file_rounded,
              isLight: isLight,
              onTap: () {
                Navigator.pop(ctx);
                pickAndOpenAudioFile(context);
              },
            ),
            const SizedBox(height: 12),

            // Кнопка: LibreTube
            _buildMusicAppButton(
              context: ctx,
              title: 'LibreTube',
              subtitle: 'Фоновое воспроизведение и плейлисты',
              iconColor: const Color(0xFFE11D48),
              icon: Icons.play_circle_fill_rounded,
              isLight: isLight,
              onTap: () {
                Navigator.pop(ctx);
                openLibreTube();
              },
            ),
            const SizedBox(height: 12),

            // Кнопка Spotify
            _buildMusicAppButton(
              context: ctx,
              title: 'Spotify',
              subtitle: 'Плейлисты для спорта и бега',
              iconColor: const Color(0xFF1DB954),
              icon: Icons.graphic_eq_rounded,
              isLight: isLight,
              onTap: () {
                Navigator.pop(ctx);
                openSpotify();
              },
            ),
            const SizedBox(height: 12),

            // Кнопка YouTube Music
            _buildMusicAppButton(
              context: ctx,
              title: 'YouTube Music',
              subtitle: 'Треки, миксы и тренировочное радио',
              iconColor: const Color(0xFFFF0000),
              icon: Icons.play_circle_fill_rounded,
              isLight: isLight,
              onTap: () {
                Navigator.pop(ctx);
                openYouTubeMusic();
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildMusicAppButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Color iconColor,
    required IconData icon,
    required bool isLight,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF161F33),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isLight ? const Color(0xFF0A0F1D) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isLight ? const Color(0xFF64748B) : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 20,
                color: isLight ? const Color(0xFF94A3B8) : Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
