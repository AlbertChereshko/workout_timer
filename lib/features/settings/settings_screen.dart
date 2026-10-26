import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/locale_provider.dart';
import '../../data/repositories/exercise_repository.dart';
import '../workout_list/workout_list_screen.dart';
import '../history/history_screen.dart';
import '../../core/theme.dart';
import '../../services/audio_service.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../l10n/app_localizations.dart';
import '../profile/athlete_profile_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late SoundMode _soundMode;

  @override
  void initState() {
    super.initState();
    final audio = AudioService();
    _soundMode = audio.soundMode;
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      case 'hr':
        return 'Hrvatski';
      case 'ru':
      default:
        return 'Русский';
    }
  }

  String _getSoundModeTitle(SoundMode mode, [AppLocalizations? l10n]) {
    switch (mode) {
      case SoundMode.voiceAndBeeps:
        return l10n?.soundModeVoiceAndBeep ?? 'Голос + Звуковые сигналы';
      case SoundMode.voiceOnly:
        return l10n?.soundModeVoice ?? 'Только голос тренера (TTS)';
      case SoundMode.beepsOnly:
        return l10n?.soundModeBeep ?? 'Только спортивные сигналы';
      case SoundMode.vibrationOnly:
        return l10n?.soundModeMute ?? 'Только тактильный отклик (Без звука)';
    }
  }

  String _getSoundModeSubtitle(SoundMode mode, [AppLocalizations? l10n]) {
    switch (mode) {
      case SoundMode.voiceAndBeeps:
        return l10n?.soundModeVoiceAndBeep ?? 'Озвучка названий, обратный отсчёт, свисток и гонг';
      case SoundMode.voiceOnly:
        return l10n?.soundModeVoice ?? 'Озвучивание упражнений и команд без звуковых эффектов';
      case SoundMode.beepsOnly:
        return l10n?.soundModeBeep ?? 'Системные бипы 3-2-1, свисток старта и гонг отдыха';
      case SoundMode.vibrationOnly:
        return l10n?.vibrationSubtitle ?? 'Бесшумный режим: фирменный виброотклик O-Haptics';
    }
  }

  void _showEventSoundPicker({
    required BuildContext context,
    required String title,
    required String eventKey,
    required List<SoundOption> options,
    required String currentSelectedId,
    required AppThemeConfig currentTheme,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: currentTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: currentTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...options.map((option) {
                    final isSelected = currentSelectedId == option.id;
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      tileColor: isSelected
                          ? currentTheme.accent.withValues(alpha: 0.15)
                          : Colors.transparent,
                      title: Text(
                        option.name,
                        style: TextStyle(
                          color: currentTheme.textPrimary,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.play_circle_fill, color: currentTheme.accent),
                            tooltip: 'Прослушать',
                            onPressed: () {
                              AudioService().testSound(option.asset);
                            },
                          ),
                          if (isSelected)
                            Icon(Icons.check, color: currentTheme.accent)
                          else
                            const SizedBox(width: 24),
                        ],
                      ),
                      onTap: () {
                        AudioService().setEventSound(eventKey, option.id);
                        AudioService().testSound(option.asset);
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                  const Divider(height: 24),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: currentTheme.accent.withValues(alpha: 0.08),
                    leading: Icon(Icons.audio_file_rounded, color: currentTheme.accent, size: 28),
                    title: Text(
                      'Выбрать свой звук с устройства...',
                      style: TextStyle(
                        color: currentTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      'mp3, wav, ogg, aac из памяти телефона',
                      style: TextStyle(color: currentTheme.textSecondary, fontSize: 12),
                    ),
                    trailing: Icon(Icons.folder_open_rounded, color: currentTheme.accent),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['wav', 'mp3', 'ogg', 'aac', 'm4a'],
                      );
                      if (result != null && result.files.single.path != null) {
                        final path = result.files.single.path!;
                        final customId = 'custom:$path';
                        AudioService().setEventSound(eventKey, customId);
                        AudioService().testSound(customId);
                        setState(() {});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: currentTheme.surface,
                              content: Text(
                                'Выбран звук: ${result.files.single.name}',
                                style: TextStyle(color: currentTheme.textPrimary),
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context, Locale currentLocale) {
    final languages = [
      {'code': 'ru', 'name': 'Русский', 'flag': '🇷🇺'},
      {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
      {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
      {'code': 'hr', 'name': 'Hrvatski', 'flag': '🇭🇷'},
    ];

    final currentTheme = ref.read(appThemeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: currentTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Выберите язык / Select language',
                    style: TextStyle(
                      color: currentTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...languages.map((item) {
                  final isSelected = currentLocale.languageCode == item['code'];
                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: isSelected
                        ? currentTheme.accent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    leading: Text(item['flag']!, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      item['name']!,
                      style: TextStyle(
                        color: currentTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: currentTheme.accent)
                        : null,
                    onTap: () {
                      final selectedCode = item['code']!;
                      ref.read(localeProvider.notifier).setLocale(Locale(selectedCode));
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showThemeSelectionDialog(BuildContext context) {
    final currentTheme = ref.read(appThemeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: currentTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Выберите цветовую тему',
                    style: TextStyle(
                      color: currentTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: AppThemes.all.length,
                    itemBuilder: (context, index) {
                      final theme = AppThemes.all[index];
                      final isSelected = theme.id == currentTheme.id;
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tileColor: isSelected
                            ? currentTheme.accent.withValues(alpha: 0.15)
                            : Colors.transparent,
                        leading: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: theme.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.isLight ? Colors.black26 : Colors.white24,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildColorCircle(theme.accent, isAccent: true),
                              const SizedBox(width: 4),
                              _buildColorCircle(theme.workPhase),
                              const SizedBox(width: 4),
                              _buildColorCircle(theme.restPhase),
                            ],
                          ),
                        ),
                        title: Text(
                          theme.name,
                          style: TextStyle(
                            color: currentTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          theme.subtitle,
                          style: TextStyle(
                            color: isSelected ? theme.accent : currentTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: theme.accent)
                            : null,
                        onTap: () {
                          ref.read(appThemeProvider.notifier).setTheme(theme);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSoundModeDialog(BuildContext context) {
    final currentTheme = ref.read(appThemeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: currentTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Режим звукового сопровождения',
                    style: TextStyle(
                      color: currentTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...SoundMode.values.map((mode) {
                  final isSelected = _soundMode == mode;
                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: isSelected
                        ? currentTheme.accent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    title: Text(
                      _getSoundModeTitle(mode),
                      style: TextStyle(
                        color: currentTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      _getSoundModeSubtitle(mode),
                      style: TextStyle(color: currentTheme.textSecondary, fontSize: 12),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: currentTheme.accent)
                        : null,
                    onTap: () {
                      setState(() {
                        _soundMode = mode;
                      });
                      AudioService().setSoundMode(mode);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(appThemeProvider);
    final currentLocale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);
    final audio = AudioService();

    final countdownOption = AudioService.countdownOptions.firstWhere(
      (o) => o.id == audio.countdownSound,
      orElse: () => AudioService.countdownOptions.first,
    );
    final startOption = AudioService.startOptions.firstWhere(
      (o) => o.id == audio.startSound,
      orElse: () => AudioService.startOptions.first,
    );
    final restOption = AudioService.restOptions.firstWhere(
      (o) => o.id == audio.restSound,
      orElse: () => AudioService.restOptions.first,
    );
    final finishOption = AudioService.finishOptions.firstWhere(
      (o) => o.id == audio.finishSound,
      orElse: () => AudioService.finishOptions.first,
    );

    final auth = ref.watch(authServiceProvider);
    final syncService = ref.watch(cloudSyncServiceProvider);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: currentTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n?.settings ?? 'Настройки',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: currentTheme.textPrimary,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 680;
              final availableWidth = constraints.maxWidth - 40; // horizontal padding 20 * 2
              final double cardWidth = isWide ? (availableWidth - 16) / 2 : availableWidth;

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      // 1. Account & Cloud Card
                      SizedBox(
                        width: cardWidth,
                        child: _buildAccountCard(context, currentTheme, auth, syncService, user, l10n),
                      ),

                      // Athlete profile
                      SizedBox(
                        width: cardWidth,
                        child: Material(
                          color: currentTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => AthleteProfileDialog.show(context),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: currentTheme.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.psychology_outlined, color: currentTheme.accent, size: 26),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Профиль атлета & AI Тренер',
                                            style: TextStyle(color: currentTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text('Параметры, цели и ключ Gemini',
                                            style: TextStyle(color: currentTheme.textSecondary, fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: currentTheme.textSecondary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 2. Offline JSON Backup & Transfer Card
                      SizedBox(
                        width: cardWidth,
                        child: _buildBackupTransferCard(context, currentTheme, l10n),
                      ),

                      // 3. Theme Selection Card
                      SizedBox(
                        width: cardWidth,
                        child: _buildThemeCard(context, currentTheme, l10n),
                      ),

                      // 4. Language Card
                      SizedBox(
                        width: cardWidth,
                        child: _buildLanguageCard(context, currentTheme, currentLocale, l10n),
                      ),

                      // 5. Sound Mode & Vibration Card
                      SizedBox(
                        width: cardWidth,
                        child: _buildSoundModeCard(context, currentTheme, l10n),
                      ),

                      // 6. Individual Event Sounds Card
                      SizedBox(
                        width: cardWidth,
                        child: _buildEventSoundsCard(
                          context,
                          currentTheme,
                          audio,
                          countdownOption,
                          startOption,
                          restOption,
                          finishOption,
                          l10n,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(String title, Color accent, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    AppThemeConfig currentTheme,
    AuthService auth,
    CloudSyncService syncService,
    UserProfile? user,
    AppLocalizations? l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: currentTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: user != null
              ? currentTheme.accent.withValues(alpha: 0.3)
              : currentTheme.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            l10n?.accountAndCloud ?? 'Аккаунт и облачный бэкап',
            currentTheme.accent,
            icon: Icons.cloud_done_rounded,
          ),
          if (user == null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: currentTheme.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_off_rounded, color: currentTheme.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.offlineMode ?? 'Офлайн-режим',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: currentTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n?.signInToSync ?? 'Войдите для синхронизации тренировок',
                        style: TextStyle(
                          fontSize: 12,
                          color: currentTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) {
                          _showDesktopGoogleSignInDialog(context, auth, currentTheme);
                          return;
                        }
                        final success = await auth.signInWithGoogle();
                        if (!context.mounted) return;
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: currentTheme.surface,
                              content: Text(
                                'Вы успешно вошли через Google!',
                                style: TextStyle(color: currentTheme.textPrimary),
                              ),
                            ),
                          );
                        } else if (auth.lastError != null) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: currentTheme.surface,
                              title: Text('Ошибка авторизации', style: TextStyle(color: currentTheme.textPrimary)),
                              content: Text(
                                '${auth.lastError}\n\nУбедитесь, что в Firebase Console добавлен SHA-1 отпечаток приложения для Google Sign-In.',
                                style: TextStyle(color: currentTheme.textSecondary, fontSize: 13),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text('Понятно', style: TextStyle(color: currentTheme.accent)),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: currentTheme.accent,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: auth.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.login_rounded, size: 20),
                label: Text(
                  auth.isLoading ? (l10n?.signingIn ?? 'Вход...') : (l10n?.signInWithGoogle ?? 'Войти через Google'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => _showEditProfileDialog(context, auth, null, currentTheme),
                icon: Icon(Icons.edit_note_rounded, size: 18, color: currentTheme.accent),
                label: Text(
                  'Указать имя и Google Email для синхронизации',
                  style: TextStyle(color: currentTheme.accent, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                InkWell(
                  onTap: () => _showEditProfileDialog(context, auth, user, currentTheme),
                  borderRadius: BorderRadius.circular(26),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: currentTheme.accent.withValues(alpha: 0.15),
                        child: ClipOval(
                          child: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                              ? Image.network(
                                  user.photoUrl!,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.person,
                                    color: currentTheme.accent,
                                    size: 28,
                                  ),
                                )
                              : Icon(Icons.person, color: currentTheme.accent, size: 28),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: currentTheme.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 10, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: currentTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          user.email,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            color: currentTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            syncService.isSyncing
                                ? Icons.sync_rounded
                                : Icons.check_circle_rounded,
                            color: syncService.isSyncing ? currentTheme.accent : Colors.greenAccent.shade700,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              syncService.syncStatus,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: syncService.isSyncing ? currentTheme.accent : Colors.greenAccent.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: currentTheme.accent),
                  tooltip: 'Изменить имя, почту и аватар',
                  onPressed: () => _showEditProfileDialog(context, auth, user, currentTheme),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  tooltip: l10n?.signOut ?? 'Выйти',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: currentTheme.surface,
                        title: Text(l10n?.signOutConfirmTitle ?? 'Выйти из аккаунта?', style: TextStyle(color: currentTheme.textPrimary)),
                        content: Text(
                          l10n?.signOutConfirmMessage ?? 'Локальные тренировки сохранятся на этом устройстве.',
                          style: TextStyle(color: currentTheme.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n?.cancel ?? 'Отмена', style: TextStyle(color: currentTheme.textSecondary)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n?.signOut ?? 'Выйти', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await auth.signOut();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: syncService.isSyncing
                    ? null
                    : () async {
                        await syncService.syncAll(user.uid);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: currentTheme.surface,
                            content: Text(
                              syncService.lastError == null
                                  ? 'Тренировки, история и настройки успешно синхронизированы!'
                                  : 'Ошибка: ${syncService.lastError}',
                              style: TextStyle(color: currentTheme.textPrimary),
                            ),
                          ),
                        );
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: currentTheme.accent,
                  side: BorderSide(color: currentTheme.accent.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: syncService.isSyncing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: currentTheme.accent),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: Text(
                  syncService.isSyncing ? 'Синхронизация...' : 'Синхронизировать сейчас',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBackupTransferCard(
    BuildContext context,
    AppThemeConfig currentTheme,
    AppLocalizations? l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: currentTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: currentTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            'Кроссплатформенный бэкап',
            currentTheme.accent,
            icon: Icons.import_export_rounded,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.tealAccent.shade400,
                    side: BorderSide(color: Colors.tealAccent.shade400.withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('Экспорт JSON', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final json = ref.read(cloudSyncServiceProvider).exportBackupJson();
                    Clipboard.setData(ClipboardData(text: json));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: currentTheme.surface,
                        content: Text('Бэкап скопирован в буфер обмена! Перешлите его на другое устройство.', style: TextStyle(color: currentTheme.textPrimary)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Импорт данных', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    _showImportBackupDialog(context, currentTheme);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    AppThemeConfig currentTheme,
    AppLocalizations? l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: currentTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: currentTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            l10n?.colorScheme ?? 'Цветовая схема',
            currentTheme.accent,
            icon: Icons.palette_rounded,
          ),
          InkWell(
            onTap: () => _showThemeSelectionDialog(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: currentTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: currentTheme.accent.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: currentTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: currentTheme.isLight ? Colors.black12 : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildColorCircle(currentTheme.accent, isAccent: true),
                        const SizedBox(width: 4),
                        _buildColorCircle(currentTheme.workPhase),
                        const SizedBox(width: 4),
                        _buildColorCircle(currentTheme.restPhase),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentTheme.name,
                          style: TextStyle(
                            color: currentTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          currentTheme.subtitle,
                          style: TextStyle(
                            color: currentTheme.accent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: currentTheme.accent, size: 26),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(
    BuildContext context,
    AppThemeConfig currentTheme,
    Locale currentLocale,
    AppLocalizations? l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: currentTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: currentTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            l10n?.appLanguageTitle ?? 'Язык приложения',
            currentTheme.accent,
            icon: Icons.language_rounded,
          ),
          InkWell(
            onTap: () => _showLanguageDialog(context, currentLocale),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: currentTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: currentTheme.cardBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: currentTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.language, color: currentTheme.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.appLanguageSubtitle ?? 'Язык интерфейса и тренера',
                          style: TextStyle(
                            color: currentTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_getLanguageName(currentLocale.languageCode)} (${currentLocale.languageCode.toUpperCase()})',
                          style: TextStyle(
                            color: currentTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: currentTheme.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundModeCard(
    BuildContext context,
    AppThemeConfig currentTheme,
    AppLocalizations? l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: currentTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: currentTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            l10n?.soundAccompaniment ?? 'Звук и тактильный отклик',
            currentTheme.accent,
            icon: Icons.volume_up_rounded,
          ),
          InkWell(
            onTap: () => _showSoundModeDialog(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: currentTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: currentTheme.cardBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: currentTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.volume_up, color: currentTheme.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.soundMode ?? 'Режим звука',
                          style: TextStyle(
                            color: currentTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getSoundModeTitle(_soundMode, l10n),
                          style: TextStyle(
                            color: currentTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: currentTheme.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: currentTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: currentTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Профиль тактильного отклика (Haptics):',
                  style: TextStyle(color: currentTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    {'id': 'light', 'name': 'Мягкий'},
                    {'id': 'crisp', 'name': 'Чёткий'},
                    {'id': 'strong', 'name': 'Сильный'},
                    {'id': 'heavy', 'name': 'Мощный'},
                  ].map((p) {
                    final isSelected = AudioService().hapticProfile == p['id'];
                    return ChoiceChip(
                      label: Text(p['name']!, style: const TextStyle(fontSize: 12.5)),
                      selected: isSelected,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            AudioService().setHapticProfile(p['id']!);
                          });
                          AudioService().vibrate();
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSoundsCard(
    BuildContext context,
    AppThemeConfig currentTheme,
    AudioService audio,
    SoundOption countdownOption,
    SoundOption startOption,
    SoundOption restOption,
    SoundOption finishOption,
    AppLocalizations? l10n,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: currentTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: currentTheme.cardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: currentTheme.accent,
          collapsedIconColor: currentTheme.textSecondary,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: currentTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.music_note_rounded, color: currentTheme.accent, size: 22),
          ),
          title: Text(
            l10n?.individualSignals ?? 'Сигналы для отдельных событий',
            style: TextStyle(
              color: currentTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            l10n?.individualSignalsSub ?? 'Нажмите, чтобы настроить звуки или выбрать свой файл',
            style: TextStyle(color: currentTheme.textSecondary, fontSize: 11),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: currentTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: currentTheme.accent.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Готовые звуковые схемы',
                          style: TextStyle(
                            color: currentTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSoundSchemeButton(
                                title: '🎮 АРКАДА',
                                subtitle: 'Пинбол, Панч',
                                isSelected: audio.countdownSound == 'arcade_tick' && audio.startSound == 'arcade_start',
                                theme: currentTheme,
                                onTap: () {
                                  audio.applySoundScheme('arcade');
                                  audio.testSound('sounds/arcade_start.wav');
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSoundSchemeButton(
                                title: '🥊 Спорт',
                                subtitle: 'Бип, Свист',
                                isSelected: audio.countdownSound == 'beep' && (audio.startSound == 'arrow_start' || audio.startSound == 'whistle'),
                                theme: currentTheme,
                                onTap: () {
                                  audio.applySoundScheme('classic_sport');
                                  audio.testSound('sounds/arrow_start.wav');
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSoundSchemeButton(
                                title: '🕰 Часы',
                                subtitle: 'Тиканье, Бой',
                                isSelected: audio.countdownSound == 'clock_tick' && audio.restSound == 'clock_gong',
                                theme: currentTheme,
                                onTap: () {
                                  audio.applySoundScheme('vintage_clock');
                                  audio.testSound('sounds/clock_gong.wav');
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSoundSchemeButton(
                                title: '🌿 Природа',
                                subtitle: 'Дзен, Чаша',
                                isSelected: audio.countdownSound == 'nature_wood' && audio.startSound == 'nature_bowl',
                                theme: currentTheme,
                                onTap: () {
                                  audio.applySoundScheme('nature');
                                  audio.testSound('sounds/nature_singing_bowl.wav');
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildEventSoundTile(
                    title: l10n?.signalCountdown ?? 'Обратный отсчёт (3, 2, 1)',
                    selectedName: audio.countdownSound.startsWith('custom:')
                        ? '📁 ${audio.countdownSound.split('/').last}'
                        : countdownOption.name,
                    icon: Icons.timer,
                    theme: currentTheme,
                    onTap: () => _showEventSoundPicker(
                      context: context,
                      title: l10n?.signalCountdown ?? 'Сигнал обратного отсчёта',
                      eventKey: 'countdown',
                      options: AudioService.countdownOptions,
                      currentSelectedId: audio.countdownSound,
                      currentTheme: currentTheme,
                    ),
                  ),
                  _buildEventSoundTile(
                    title: l10n?.signalRoundStart ?? 'Старт раунда (РАБОТА)',
                    selectedName: audio.startSound.startsWith('custom:')
                        ? '📁 ${audio.startSound.split('/').last}'
                        : startOption.name,
                    icon: Icons.play_arrow_rounded,
                    theme: currentTheme,
                    onTap: () => _showEventSoundPicker(
                      context: context,
                      title: l10n?.signalRoundStart ?? 'Сигнал старта раунда',
                      eventKey: 'start',
                      options: AudioService.startOptions,
                      currentSelectedId: audio.startSound,
                      currentTheme: currentTheme,
                    ),
                  ),
                  _buildEventSoundTile(
                    title: l10n?.signalRoundRest ?? 'Окончание раунда (ОТДЫХ)',
                    selectedName: audio.restSound.startsWith('custom:')
                        ? '📁 ${audio.restSound.split('/').last}'
                        : restOption.name,
                    icon: Icons.pause_rounded,
                    theme: currentTheme,
                    onTap: () => _showEventSoundPicker(
                      context: context,
                      title: l10n?.signalRoundRest ?? 'Сигнал отдыха',
                      eventKey: 'rest',
                      options: AudioService.restOptions,
                      currentSelectedId: audio.restSound,
                      currentTheme: currentTheme,
                    ),
                  ),
                  _buildEventSoundTile(
                    title: 'Завершение раунда / интервала',
                    selectedName: audio.roundSound.startsWith('custom:')
                        ? '📁 ${audio.roundSound.split('/').last}'
                        : AudioService.roundOptions.firstWhere((o) => o.id == audio.roundSound, orElse: () => AudioService.roundOptions.first).name,
                    icon: Icons.notifications_active_rounded,
                    theme: currentTheme,
                    onTap: () => _showEventSoundPicker(
                      context: context,
                      title: 'Сигнал смены раунда',
                      eventKey: 'round',
                      options: AudioService.roundOptions,
                      currentSelectedId: audio.roundSound,
                      currentTheme: currentTheme,
                    ),
                  ),
                  _buildEventSoundTile(
                    title: l10n?.signalFinish ?? 'Завершение комплекса (ФИНИШ)',
                    selectedName: audio.finishSound.startsWith('custom:')
                        ? '📁 ${audio.finishSound.split('/').last}'
                        : finishOption.name,
                    icon: Icons.emoji_events_rounded,
                    theme: currentTheme,
                    onTap: () => _showEventSoundPicker(
                      context: context,
                      title: l10n?.signalFinish ?? 'Сигнал финиша',
                      eventKey: 'finish',
                      options: AudioService.finishOptions,
                      currentSelectedId: audio.finishSound,
                      currentTheme: currentTheme,
                    ),
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    value: audio.isMetronomeEnabled,
                    activeColor: currentTheme.accent,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Метроном / тиканье каждую секунду',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: currentTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Воспроизводит лёгкий такт во время работы (не прерывает музыку)',
                      style: TextStyle(
                        fontSize: 12,
                        color: currentTheme.textSecondary,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        audio.setMetronomeEnabled(val);
                      });
                      if (val) {
                        audio.playMetronomeTick();
                      }
                    },
                  ),
                  if (audio.isMetronomeEnabled)
                    _buildEventSoundTile(
                      title: 'Звук тиканья метронома',
                      selectedName: AudioService.metronomeOptions.firstWhere(
                        (o) => o.id == audio.metronomeSound,
                        orElse: () => AudioService.metronomeOptions.first,
                      ).name,
                      icon: Icons.timer_outlined,
                      theme: currentTheme,
                      onTap: () => _showEventSoundPicker(
                        context: context,
                        title: 'Звук метронома',
                        eventKey: 'metronome',
                        options: AudioService.metronomeOptions,
                        currentSelectedId: audio.metronomeSound,
                        currentTheme: currentTheme,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarChip({
    required String label,
    required String url,
    required TextEditingController photoController,
    required StateSetter setDialogState,
    required AppThemeConfig theme,
  }) {
    final isSelected = photoController.text == url;
    return InkWell(
      onTap: () {
        photoController.text = url;
        setDialogState(() {});
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent.withValues(alpha: 0.2) : theme.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? theme.accent : theme.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.accent : theme.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _showDesktopGoogleSignInDialog(
    BuildContext context,
    AuthService auth,
    AppThemeConfig currentTheme,
  ) async {
    final emailController = TextEditingController(text: auth.currentUser?.email ?? '');
    final nameController = TextEditingController(text: auth.currentUser?.displayName ?? '');
    final photoController = TextEditingController(text: auth.currentUser?.photoUrl ?? '');

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final photoUrl = photoController.text.trim();

            return AlertDialog(
              backgroundColor: currentTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: currentTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.account_circle_rounded, color: currentTheme.accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Вход через Google (Десктоп)',
                      style: TextStyle(
                        color: currentTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Введите ваш Google аккаунт для облачной синхронизации тренировок, базы упражнений и аналитики:',
                      style: TextStyle(color: currentTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Avatar Preview with live update
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: currentTheme.accent.withValues(alpha: 0.2),
                          child: ClipOval(
                            child: photoUrl.isNotEmpty
                                ? Image.network(
                                    photoUrl,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Icon(
                                      Icons.person,
                                      size: 40,
                                      color: currentTheme.accent,
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 40,
                                    color: currentTheme.accent,
                                  ),
                          ),
                        ),
                        if (photoUrl.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.shade700,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 14, color: Colors.black),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: currentTheme.textPrimary, fontSize: 14),
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Google Email',
                        labelStyle: TextStyle(color: currentTheme.accent),
                        hintText: 'user@gmail.com',
                        hintStyle: TextStyle(color: currentTheme.textSecondary.withValues(alpha: 0.5)),
                        prefixIcon: Icon(Icons.email_outlined, color: currentTheme.accent, size: 20),
                        filled: true,
                        fillColor: currentTheme.surfaceSubtle,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(color: currentTheme.textPrimary, fontSize: 14),
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Имя атлета',
                        labelStyle: TextStyle(color: currentTheme.accent),
                        hintText: 'Ваше имя',
                        hintStyle: TextStyle(color: currentTheme.textSecondary.withValues(alpha: 0.5)),
                        prefixIcon: Icon(Icons.badge_outlined, color: currentTheme.accent, size: 20),
                        filled: true,
                        fillColor: currentTheme.surfaceSubtle,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: photoController,
                      keyboardType: TextInputType.url,
                      style: TextStyle(color: currentTheme.textPrimary, fontSize: 14),
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'URL фотографии (Аватар)',
                        labelStyle: TextStyle(color: currentTheme.accent),
                        hintText: 'https://...',
                        hintStyle: TextStyle(color: currentTheme.textSecondary.withValues(alpha: 0.5)),
                        prefixIcon: Icon(Icons.image_outlined, color: currentTheme.accent, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.auto_awesome, color: currentTheme.accent, size: 18),
                          tooltip: 'Подтянуть аватар по имени',
                          onPressed: () {
                            final name = nameController.text.trim().isNotEmpty
                                ? nameController.text.trim()
                                : (emailController.text.trim().isNotEmpty
                                    ? emailController.text.trim().split('@').first
                                    : 'Athlete');
                            final generated = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=00E5FF&color=000&size=200&bold=true';
                            photoController.text = generated;
                            setDialogState(() {});
                          },
                        ),
                        filled: true,
                        fillColor: currentTheme.surfaceSubtle,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quick presets chips
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Быстрые аватары:',
                        style: TextStyle(color: currentTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildAvatarChip(
                            label: '⚡ Атлет',
                            url: 'https://api.dicebear.com/7.x/bottts/png?seed=athlete',
                            photoController: photoController,
                            setDialogState: setDialogState,
                            theme: currentTheme,
                          ),
                          const SizedBox(width: 6),
                          _buildAvatarChip(
                            label: '🥊 Бокс',
                            url: 'https://api.dicebear.com/7.x/bottts/png?seed=boxing',
                            photoController: photoController,
                            setDialogState: setDialogState,
                            theme: currentTheme,
                          ),
                          const SizedBox(width: 6),
                          _buildAvatarChip(
                            label: '🧘 Баланс',
                            url: 'https://api.dicebear.com/7.x/bottts/png?seed=zen',
                            photoController: photoController,
                            setDialogState: setDialogState,
                            theme: currentTheme,
                          ),
                          const SizedBox(width: 6),
                          _buildAvatarChip(
                            label: '🔥 Чемпион',
                            url: 'https://api.dicebear.com/7.x/bottts/png?seed=champion',
                            photoController: photoController,
                            setDialogState: setDialogState,
                            theme: currentTheme,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Отмена', style: TextStyle(color: currentTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final email = emailController.text.trim();
                    final name = nameController.text.trim();
                    final photo = photoController.text.trim();

                    if (email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Пожалуйста, введите ваш Google Email')),
                      );
                      return;
                    }

                    final finalName = name.isNotEmpty
                        ? (name[0].toUpperCase() + name.substring(1))
                        : email.split('@').first;

                    Navigator.pop(ctx);

                    await auth.signInWithCustomProfile(
                      email: email,
                      displayName: finalName,
                      photoUrl: photo.isNotEmpty ? photo : null,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: currentTheme.surface,
                          content: Text(
                            'Вы успешно вошли под аккаунтом $email!',
                            style: TextStyle(color: currentTheme.textPrimary),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentTheme.accent,
                    foregroundColor: currentTheme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Войти и синхронизировать'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    AuthService auth,
    UserProfile? user,
    AppThemeConfig currentTheme,
  ) async {
    final nameController = TextEditingController(text: user?.displayName ?? 'Атлет');
    final emailController = TextEditingController(text: user?.email ?? '');
    final photoController = TextEditingController(text: user?.photoUrl ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final photoUrl = photoController.text.trim();

          return AlertDialog(
            backgroundColor: currentTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.manage_accounts_rounded, color: currentTheme.accent, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Профиль синхронизации',
                  style: TextStyle(color: currentTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Укажите ваши данные для облачной синхронизации комплексов и аналитики:',
                    style: TextStyle(color: currentTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Avatar Preview
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: currentTheme.accent.withValues(alpha: 0.2),
                    child: ClipOval(
                      child: photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Icon(
                                Icons.person,
                                size: 40,
                                color: currentTheme.accent,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 40,
                              color: currentTheme.accent,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(color: currentTheme.textPrimary, fontSize: 15),
                    onChanged: (val) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Имя атлета',
                      labelStyle: TextStyle(color: currentTheme.accent),
                      filled: true,
                      fillColor: currentTheme.surfaceSubtle,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: currentTheme.textPrimary, fontSize: 15),
                    onChanged: (val) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Google Email',
                      labelStyle: TextStyle(color: currentTheme.accent),
                      hintText: 'name@gmail.com',
                      hintStyle: TextStyle(color: currentTheme.textSecondary.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: currentTheme.surfaceSubtle,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: photoController,
                    keyboardType: TextInputType.url,
                    style: TextStyle(color: currentTheme.textPrimary, fontSize: 15),
                    onChanged: (val) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'URL фотографии (Аватар)',
                      labelStyle: TextStyle(color: currentTheme.accent),
                      hintText: 'https://...',
                      hintStyle: TextStyle(color: currentTheme.textSecondary.withValues(alpha: 0.5)),
                      prefixIcon: Icon(Icons.image_outlined, color: currentTheme.accent, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.auto_awesome, color: currentTheme.accent, size: 18),
                        tooltip: 'Подтянуть аватар по имени',
                        onPressed: () {
                          final name = nameController.text.trim().isNotEmpty
                              ? nameController.text.trim()
                              : 'Athlete';
                          final generated = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=00E5FF&color=000&size=200&bold=true';
                          photoController.text = generated;
                          setDialogState(() {});
                        },
                      ),
                      filled: true,
                      fillColor: currentTheme.surfaceSubtle,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Quick presets
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Быстрые аватары:',
                      style: TextStyle(color: currentTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildAvatarChip(
                          label: '⚡ Атлет',
                          url: 'https://api.dicebear.com/7.x/bottts/png?seed=athlete',
                          photoController: photoController,
                          setDialogState: setDialogState,
                          theme: currentTheme,
                        ),
                        const SizedBox(width: 6),
                        _buildAvatarChip(
                          label: '🥊 Бокс',
                          url: 'https://api.dicebear.com/7.x/bottts/png?seed=boxing',
                          photoController: photoController,
                          setDialogState: setDialogState,
                          theme: currentTheme,
                        ),
                        const SizedBox(width: 6),
                        _buildAvatarChip(
                          label: '🧘 Баланс',
                          url: 'https://api.dicebear.com/7.x/bottts/png?seed=zen',
                          photoController: photoController,
                          setDialogState: setDialogState,
                          theme: currentTheme,
                        ),
                        const SizedBox(width: 6),
                        _buildAvatarChip(
                          label: '🔥 Чемпион',
                          url: 'https://api.dicebear.com/7.x/bottts/png?seed=champion',
                          photoController: photoController,
                          setDialogState: setDialogState,
                          theme: currentTheme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Отмена', style: TextStyle(color: currentTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  final newEmail = emailController.text.trim();
                  final newPhoto = photoController.text.trim();

                  if (newName.isNotEmpty && newEmail.isNotEmpty) {
                    final capitalizedName = newName[0].toUpperCase() + newName.substring(1);
                    await auth.updateProfile(
                      displayName: capitalizedName,
                      email: newEmail,
                      photoUrl: newPhoto.isNotEmpty ? newPhoto : null,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: currentTheme.accent,
                  foregroundColor: currentTheme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSoundSchemeButton({
    required String title,
    required String subtitle,
    required bool isSelected,
    required AppThemeConfig theme,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.accent.withValues(alpha: 0.18)
                : theme.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? theme.accent
                  : theme.textSecondary.withValues(alpha: 0.2),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? theme.accent : theme.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventSoundTile({
    required String title,
    required String selectedName,
    required IconData icon,
    required AppThemeConfig theme,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: theme.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedName,
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorCircle(Color color, {bool isAccent = false}) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: isAccent ? Border.all(color: Colors.white, width: 1.5) : null,
      ),
    );
  }



  Future<void> _showImportBackupDialog(BuildContext context, AppThemeConfig currentTheme) async {
    final textController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: currentTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.download_rounded, color: currentTheme.accent, size: 24),
            const SizedBox(width: 8),
            Text('Импорт данных', style: TextStyle(color: currentTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вставьте ранее экспортированный JSON бэкап тренировок и истории:',
              style: TextStyle(color: currentTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 5,
              style: TextStyle(color: currentTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '{\n  "version": "1.0",\n  "workouts": [...]\n}',
                hintStyle: TextStyle(color: currentTheme.textSecondary.withValues(alpha: 0.5)),
                filled: true,
                fillColor: currentTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: currentTheme.cardBorder),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.paste_rounded, size: 16),
                label: const Text('Вставить из буфера', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: currentTheme.accent),
                onPressed: () async {
                  final clipData = await Clipboard.getData(Clipboard.kTextPlain);
                  if (clipData?.text != null) {
                    textController.text = clipData!.text!;
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: currentTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: currentTheme.accent,
              foregroundColor: currentTheme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final raw = textController.text.trim();
              if (raw.isEmpty) return;
              final count = ref.read(cloudSyncServiceProvider).importBackupJson(raw);
              ref.invalidate(workoutsProvider);
              ref.invalidate(historyProvider);
              ref.invalidate(exerciseRepositoryProvider);
              ref.invalidate(allExercisesProvider);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: currentTheme.surface,
                  content: Text(
                    count > 0
                        ? 'Успешно импортировано $count элементов!'
                        : 'Не удалось импортировать данные или элементы уже существуют.',
                    style: TextStyle(color: currentTheme.textPrimary),
                  ),
                ),
              );
            },
            child: const Text('Импортировать', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

}

