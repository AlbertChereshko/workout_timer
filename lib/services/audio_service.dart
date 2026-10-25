import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vibration/vibration.dart';
import 'package:workout_timer/data/models/workout.dart';

enum SoundMode {
  voiceAndBeeps, // Голос тренера + Спортивные сигналы
  voiceOnly,     // Только голос (TTS)
  beepsOnly,     // Только сигналы (Бипы, Свисток, Гонг)
  vibrationOnly, // Без звука (Только тактильный отклик)
}

class SoundOption {
  final String id;
  final String name;
  final String asset;

  const SoundOption({
    required this.id,
    required this.name,
    required this.asset,
  });
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  FlutterTts? _tts;
  AudioPlayer? _player;
  
  FlutterTts get tts => _tts ??= FlutterTts();
  
  static final AudioContext nonInterruptingAudioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      audioMode: AndroidAudioMode.normal,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {
        AVAudioSessionOptions.mixWithOthers,
        AVAudioSessionOptions.duckOthers,
      },
    ),
  );

  AudioPlayer get player {
    if (_player == null) {
      _player = AudioPlayer();
      _player!.setAudioContext(nonInterruptingAudioContext).catchError((_) {});
      _player!.setVolume(1.0).catchError((_) {});
      _player!.setReleaseMode(ReleaseMode.stop).catchError((_) {});
    }
    return _player!;
  }
  
  bool _initialized = false;
  SoundMode soundMode = SoundMode.voiceAndBeeps;
  bool isVibrationEnabled = true;

  // Customizable Sound selections for individual workout events
  String countdownSound = 'clock_tick';
  String startSound = 'clock_gong';
  String restSound = 'clock_gong';
  String roundSound = 'bell';
  String finishSound = 'clock_chime';

  // Dedicated notification volume (0.0 to 1.0)
  double notificationVolume = 1.0;

  // Duck background music during coach TTS speech
  bool duckMusicOnVoice = true;

  // O-Haptics profile for OnePlus 15: 'light', 'crisp', 'strong', 'heavy'
  String hapticProfile = 'crisp';

  static const List<SoundOption> countdownOptions = [
    SoundOption(id: 'guitar_tick', name: '🎸 Гитарный щипок / флажолет (EMOM)', asset: 'sounds/guitar_pluck_tick.wav'),
    SoundOption(id: 'clock_tick', name: '🕰 Тиканье механических часов (AMRAP)', asset: 'sounds/clock_tick.wav'),
    SoundOption(id: 'beep', name: '⏱ Цифровой бип 950Hz (Табата)', asset: 'sounds/beep_countdown.wav'),
    SoundOption(id: 'nature_wood', name: '🌿 Бамбуковый стук (Природа)', asset: 'sounds/nature_wood_tick.wav'),
    SoundOption(id: 'clock_pendulum', name: '⏳ Маятниковый ход (Тик-Так)', asset: 'sounds/clock_pendulum.wav'),
    SoundOption(id: 'click', name: '🪵 Деревянный клик (Тик)', asset: 'sounds/click_tick.wav'),
    SoundOption(id: 'bell', name: '🔔 Звон колокольчика', asset: 'sounds/bell_boxing.wav'),
  ];

  static const List<SoundOption> startOptions = [
    SoundOption(id: 'guitar_strum', name: '🎸 Сочный гитарный бой (EMOM)', asset: 'sounds/guitar_strum_start.wav'),
    SoundOption(id: 'whistle', name: '📣 Судейский свисток Fox-40 (Табата)', asset: 'sounds/whistle_start.wav'),
    SoundOption(id: 'clock_gong', name: '🕰 Бой старинных часов (AMRAP)', asset: 'sounds/clock_gong.wav'),
    SoundOption(id: 'gong', name: '🥊 Тяжёлый гонг (Табата)', asset: 'sounds/gong_rest.wav'),
    SoundOption(id: 'nature_bowl', name: '🧘 Тибетская поющая чаша (Природа)', asset: 'sounds/nature_singing_bowl.wav'),
    SoundOption(id: 'clock_chime', name: '🔔 Куранты старых часов (Мелодия)', asset: 'sounds/clock_chime.wav'),
    SoundOption(id: 'airhorn', name: '🎺 Стадионный горн (Horn)', asset: 'sounds/horn_stadium.wav'),
    SoundOption(id: 'bell', name: '🔔 Боксёрский колокол', asset: 'sounds/bell_boxing.wav'),
  ];

  static const List<SoundOption> restOptions = [
    SoundOption(id: 'gong', name: '🥊 Тяжёлый бронзовый гонг (Табата)', asset: 'sounds/gong_rest.wav'),
    SoundOption(id: 'guitar_strum', name: '🎸 Гитарный аккорд (EMOM)', asset: 'sounds/guitar_strum_start.wav'),
    SoundOption(id: 'clock_gong', name: '🕰 Бой старинных часов (AMRAP)', asset: 'sounds/clock_gong.wav'),
    SoundOption(id: 'nature_drop', name: '💧 Лесной ручей / Капля дзэн (Природа)', asset: 'sounds/nature_zen_drop.wav'),
    SoundOption(id: 'clock_chime', name: '🔔 Куранты старых часов (Мелодия)', asset: 'sounds/clock_chime.wav'),
    SoundOption(id: 'bell', name: '🔔 Боксёрский колокол', asset: 'sounds/bell_boxing.wav'),
    SoundOption(id: 'whistle', name: '📣 Судейский свисток', asset: 'sounds/whistle_start.wav'),
    SoundOption(id: 'airhorn', name: '🎺 Стадионный горн', asset: 'sounds/horn_stadium.wav'),
  ];

  static const List<SoundOption> roundOptions = [
    SoundOption(id: 'bell', name: '🔔 Боксёрский гонг / Колокол (Табата)', asset: 'sounds/bell_boxing.wav'),
    SoundOption(id: 'guitar_strum', name: '🎸 Гитарный аккорд (EMOM)', asset: 'sounds/guitar_strum_start.wav'),
    SoundOption(id: 'clock_gong', name: '🕰 Бой старинных часов (AMRAP)', asset: 'sounds/clock_gong.wav'),
    SoundOption(id: 'nature_bowl', name: '🧘 Поющая чаша (Природа)', asset: 'sounds/nature_singing_bowl.wav'),
    SoundOption(id: 'clock_chime', name: '🔔 Куранты старых часов', asset: 'sounds/clock_chime.wav'),
    SoundOption(id: 'whistle', name: '📣 Судейский свисток Fox-40', asset: 'sounds/whistle_start.wav'),
    SoundOption(id: 'gong', name: '🥊 Бронзовый гонг', asset: 'sounds/gong_rest.wav'),
  ];

  static const List<SoundOption> finishOptions = [
    SoundOption(id: 'guitar_finish', name: '🎸 Финальный аккорд гитары (EMOM)', asset: 'sounds/guitar_finish.wav'),
    SoundOption(id: 'clock_chime', name: '🔔 Торжественные куранты старых часов (AMRAP)', asset: 'sounds/clock_chime.wav'),
    SoundOption(id: 'gong', name: '🥊 Финальный тройной гонг (Табата)', asset: 'sounds/gong_rest.wav'),
    SoundOption(id: 'nature_harmony', name: '🍃 Дзэн-гармония леса (Природа)', asset: 'sounds/nature_forest_harmony.wav'),
    SoundOption(id: 'clock_gong', name: '🕰 Финальный бой старинных часов', asset: 'sounds/clock_gong.wav'),
    SoundOption(id: 'fanfare', name: '🏆 Победные фанфары (Трезвучие)', asset: 'sounds/fanfare_finish.wav'),
    SoundOption(id: 'airhorn', name: '🎺 Стадионный горн', asset: 'sounds/horn_stadium.wav'),
  ];

  /// Автоматическое назначение звукового профиля в зависимости от типа тренировки
  void applyWorkoutTypeSoundProfile(WorkoutType type) {
    switch (type) {
      case WorkoutType.tabata:
        setEventSound('countdown', 'beep');
        setEventSound('start', 'whistle');
        setEventSound('rest', 'gong');
        setEventSound('round', 'bell');
        setEventSound('finish', 'gong');
        break;
      case WorkoutType.emom:
        setEventSound('countdown', 'guitar_tick');
        setEventSound('start', 'guitar_strum');
        setEventSound('rest', 'guitar_strum');
        setEventSound('round', 'guitar_strum');
        setEventSound('finish', 'guitar_finish');
        break;
      case WorkoutType.amrap:
        setEventSound('countdown', 'clock_tick');
        setEventSound('start', 'clock_gong');
        setEventSound('rest', 'clock_gong');
        setEventSound('round', 'clock_gong');
        setEventSound('finish', 'clock_chime');
        break;
    }
  }

  void applySoundScheme(String schemeId) {
    if (schemeId == 'vintage_clock') {
      setEventSound('countdown', 'clock_tick');
      setEventSound('start', 'clock_gong');
      setEventSound('rest', 'clock_gong');
      setEventSound('round', 'clock_gong');
      setEventSound('finish', 'clock_chime');
    } else if (schemeId == 'classic_sport') {
      setEventSound('countdown', 'beep');
      setEventSound('start', 'whistle');
      setEventSound('rest', 'gong');
      setEventSound('round', 'bell');
      setEventSound('finish', 'fanfare');
    } else if (schemeId == 'nature') {
      setEventSound('countdown', 'nature_wood');
      setEventSound('start', 'nature_bowl');
      setEventSound('rest', 'nature_drop');
      setEventSound('round', 'nature_bowl');
      setEventSound('finish', 'nature_harmony');
    } else if (schemeId == 'guitar') {
      setEventSound('countdown', 'guitar_tick');
      setEventSound('start', 'guitar_strum');
      setEventSound('rest', 'guitar_strum');
      setEventSound('round', 'guitar_strum');
      setEventSound('finish', 'guitar_finish');
    }
  }

  bool _isSessionMuted = false;
  bool get isSessionMuted => _isSessionMuted;

  void toggleSessionMute() {
    _isSessionMuted = !_isSessionMuted;
  }

  void setSessionMuted(bool muted) {
    _isSessionMuted = muted;
  }

  bool get isVoiceEnabled =>
      !_isSessionMuted &&
      (soundMode == SoundMode.voiceOnly || soundMode == SoundMode.voiceAndBeeps);

  set isVoiceEnabled(bool enabled) {
    if (enabled) {
      setSoundMode(isBeepsEnabled ? SoundMode.voiceAndBeeps : SoundMode.voiceOnly);
    } else {
      setSoundMode(isBeepsEnabled ? SoundMode.beepsOnly : SoundMode.vibrationOnly);
    }
  }

  bool get isBeepsEnabled =>
      !_isSessionMuted &&
      (soundMode == SoundMode.beepsOnly || soundMode == SoundMode.voiceAndBeeps);

  Future<void> init() async {
    if (_initialized) return;
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final savedMode = box.get('sound_mode', defaultValue: 'voiceAndBeeps') as String;
        soundMode = SoundMode.values.firstWhere(
          (m) => m.name == savedMode,
          orElse: () => SoundMode.voiceAndBeeps,
        );
        isVibrationEnabled = box.get('vibration_enabled', defaultValue: true) as bool;
        notificationVolume = (box.get('notification_volume', defaultValue: 1.0) as num).toDouble();
        duckMusicOnVoice = box.get('duck_music_on_voice', defaultValue: true) as bool;
        hapticProfile = box.get('haptic_profile', defaultValue: 'crisp') as String;

        if (!box.containsKey('sound_scheme_migrated_v2')) {
          box.put('sound_scheme_migrated_v2', true);
          box.put('sound_countdown', 'clock_tick');
          box.put('sound_start', 'clock_gong');
          box.put('sound_rest', 'clock_gong');
          box.put('sound_round', 'bell');
          box.put('sound_finish', 'clock_chime');
        }
        countdownSound = box.get('sound_countdown', defaultValue: 'clock_tick') as String;
        startSound = box.get('sound_start', defaultValue: 'clock_gong') as String;
        restSound = box.get('sound_rest', defaultValue: 'clock_gong') as String;
        roundSound = box.get('sound_round', defaultValue: 'bell') as String;
        finishSound = box.get('sound_finish', defaultValue: 'clock_chime') as String;
      }
      try {
        await AudioPlayer.global.setAudioContext(nonInterruptingAudioContext);
      } catch (_) {}
      if (!kIsWeb && Platform.isIOS) {
        await tts.setSharedInstance(true).catchError((_) {});
        await tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.ambient,
          [IosTextToSpeechAudioCategoryOptions.mixWithOthers, IosTextToSpeechAudioCategoryOptions.duckOthers],
        ).catchError((_) {});
      }
      await tts.setLanguage("ru-RU").catchError((_) {});
      await tts.setSpeechRate(0.5).catchError((_) {});
      await tts.setVolume(notificationVolume).catchError((_) {});
      _initialized = true;
    } catch (e) {
      debugPrint("AudioService init error: $e");
    }
  }

  void setNotificationVolume(double volume) {
    notificationVolume = volume.clamp(0.0, 1.0);
    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('notification_volume', notificationVolume);
      }
      player.setVolume(notificationVolume).catchError((_) {});
      tts.setVolume(notificationVolume).catchError((_) {});
    } catch (_) {}
  }

  void setDuckMusicOnVoice(bool value) {
    duckMusicOnVoice = value;
    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('duck_music_on_voice', value);
      }
    } catch (_) {}
  }

  Future<void> testCoachVoice() async {
    await speak('Голос тренера: ${(notificationVolume * 100).round()}%');
  }

  void setHapticProfile(String profile) {
    hapticProfile = profile;
    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('haptic_profile', profile);
      }
    } catch (_) {}
  }

  Future<String?> pickCustomAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'],
      );
      if (result != null && result.files.single.path != null) {
        return 'custom:${result.files.single.path!}';
      }
    } catch (e) {
      debugPrint("pickCustomAudioFile error: $e");
    }
    return null;
  }

  String getSoundDisplayName(String event, String soundId) {
    if (soundId.startsWith('custom:')) {
      final path = soundId.replaceFirst('custom:', '');
      final name = path.split(Platform.pathSeparator).last;
      return '📁 Файл: $name';
    }
    List<SoundOption> options;
    switch (event) {
      case 'countdown':
        options = countdownOptions;
        break;
      case 'start':
        options = startOptions;
        break;
      case 'rest':
        options = restOptions;
        break;
      case 'round':
        options = roundOptions;
        break;
      case 'finish':
        options = finishOptions;
        break;
      default:
        options = [];
    }
    final match = options.firstWhere(
      (o) => o.id == soundId,
      orElse: () => SoundOption(id: soundId, name: soundId, asset: ''),
    );
    return match.name;
  }

  void setSoundMode(SoundMode mode) {
    soundMode = mode;
    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('sound_mode', mode.name);
      }
    } catch (_) {}
  }

  void setEventSound(String event, String soundId) {
    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('sound_$event', soundId);
      }
    } catch (_) {}

    switch (event) {
      case 'countdown':
        countdownSound = soundId;
        break;
      case 'start':
        startSound = soundId;
        break;
      case 'rest':
        restSound = soundId;
        break;
      case 'round':
        roundSound = soundId;
        break;
      case 'finish':
        finishSound = soundId;
        break;
    }
  }

  String _getAssetFor(String event, String id) {
    if (id.startsWith('custom:')) {
      return id; // Прямой путь к кастомному звуковому файлу с устройства
    }
    List<SoundOption> options;
    switch (event) {
      case 'countdown':
        options = countdownOptions;
        break;
      case 'start':
        options = startOptions;
        break;
      case 'rest':
        options = restOptions;
        break;
      case 'round':
        options = roundOptions;
        break;
      case 'finish':
        options = finishOptions;
        break;
      default:
        options = [];
    }
    final match = options.firstWhere(
      (o) => o.id == id,
      orElse: () => options.isNotEmpty ? options.first : const SoundOption(id: '', name: '', asset: 'sounds/beep_countdown.wav'),
    );
    return match.asset;
  }

  void setVibrationEnabled(bool enabled) {
    isVibrationEnabled = enabled;
    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('vibration_enabled', enabled);
      }
    } catch (_) {}
  }

  Future<void> updateLanguage(String langCode) async {
    try {
      final ttsLang = langCode == 'en' ? 'en-US' :
                      langCode == 'de' ? 'de-DE' :
                      langCode == 'hr' ? 'hr-HR' : 'ru-RU';
      await tts.setLanguage(ttsLang).catchError((_) {});
    } catch (e) {
      debugPrint("TTS updateLanguage error: $e");
    }
  }

  Future<void> _playSound(String path) async {
    if (!isBeepsEnabled) return;
    try {
      final source = path.startsWith('custom:')
          ? DeviceFileSource(path.replaceFirst('custom:', ''))
          : AssetSource(path);
      await player.setVolume(notificationVolume).catchError((_) {});
      await player.play(source, volume: notificationVolume);
    } catch (e) {
      debugPrint("AudioPlayer play error: $e");
      // Recovery fallback in case native player was disposed or entered faulted state
      try {
        _player = AudioPlayer();
        await _player!.setAudioContext(nonInterruptingAudioContext).catchError((_) {});
        await _player!.setVolume(notificationVolume).catchError((_) {});
        final source = path.startsWith('custom:')
            ? DeviceFileSource(path.replaceFirst('custom:', ''))
            : AssetSource(path);
        await _player!.play(source, volume: notificationVolume);
      } catch (e2) {
        debugPrint("AudioPlayer recovery error: $e2");
      }
    }
  }

  Future<void> speak(String text) async {
    if (!isVoiceEnabled) return;
    try {
      await tts.stop().catchError((_) {});
      await tts.setVolume(notificationVolume).catchError((_) {});
      await tts.speak(text, focus: duckMusicOnVoice).catchError((_) {});
    } catch (e) {
      debugPrint("AudioService speak error: $e");
    }
  }

  Future<void> vibrate([List<int> pattern = const [0, 150], int duration = 200]) async {
    if (!isVibrationEnabled) return;
    try {
      final hasVib = await Vibration.hasVibrator().catchError((_) => false);
      if (hasVib == true) {
        double factor = 1.0;
        if (hapticProfile == 'light') factor = 0.6;
        if (hapticProfile == 'strong') factor = 1.5;
        if (hapticProfile == 'heavy') factor = 2.0;

        if (pattern.length > 1) {
          final scaledPattern = pattern.asMap().entries.map((entry) {
            // entry.key % 2 == 1 is the vibration time, 0 is the delay time
            if (entry.key % 2 == 1) {
              return (entry.value * factor).round().clamp(10, 2000);
            }
            return entry.value;
          }).toList();
          Vibration.vibrate(pattern: scaledPattern).catchError((_) {});
        } else {
          final scaledDuration = (duration * factor).round().clamp(10, 2000);
          Vibration.vibrate(duration: scaledDuration).catchError((_) {});
        }
      }
    } catch (e) {
      debugPrint("AudioService vibration error: $e");
    }
  }

  Future<void> announceCountdown(int number) async {
    if (isBeepsEnabled) {
      _playSound(_getAssetFor('countdown', countdownSound));
    }
    if (isVoiceEnabled) {
      speak(number.toString());
    }
    vibrate([0, 100]);
  }

  Future<void> announceStart([String? exerciseName]) async {
    if (isBeepsEnabled) {
      _playSound(_getAssetFor('start', startSound));
    }
    if (isVoiceEnabled) {
      if (exerciseName != null && exerciseName.isNotEmpty) {
        speak("$exerciseName. Вперёд!");
      } else {
        speak("Вперёд!");
      }
    }
    // Энергичный импульс (O-Haptics)
    vibrate([0, 250, 80, 350]);
  }

  Future<void> announceRest() async {
    if (isBeepsEnabled) {
      _playSound(_getAssetFor('rest', restSound));
    }
    if (isVoiceEnabled) {
      speak("Отдых!");
    }
    // Спокойный импульс
    vibrate([0, 350]);
  }

  Future<void> announceRoundComplete([int? roundNumber]) async {
    if (isBeepsEnabled) {
      _playSound(_getAssetFor('round', roundSound));
    }
    if (isVoiceEnabled) {
      if (roundNumber != null) {
        speak("Раунд $roundNumber завершён!");
      } else {
        speak("Раунд завершён!");
      }
    }
    vibrate([0, 180, 80, 220]);
  }
  
  Future<void> announceFinish() async {
    if (isBeepsEnabled) {
      _playSound(_getAssetFor('finish', finishSound));
    }
    if (isVoiceEnabled) {
      speak("Тренировка завершена! Отличная работа!");
    }
    // Победная серия вибрации
    vibrate([0, 250, 80, 250, 80, 500]);
  }

  Future<void> testSound(String path) async {
    try {
      final source = path.startsWith('custom:')
          ? DeviceFileSource(path.replaceFirst('custom:', ''))
          : AssetSource(path);
      await player.setVolume(notificationVolume).catchError((_) {});
      await player.play(source, volume: notificationVolume);
      vibrate([0, 150]);
    } catch (e) {
      debugPrint("AudioPlayer testSound error: $e");
    }
  }
}
