import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/services/audio_service.dart';

void main() {
  group('AudioService SoundMode & Session Mute Tests', () {
    final audio = AudioService();

    setUp(() {
      audio.setSessionMuted(false);
      audio.soundMode = SoundMode.voiceAndBeeps;
    });

    test('voiceAndBeeps mode enables both voice and beeps when unmuted', () {
      audio.soundMode = SoundMode.voiceAndBeeps;
      expect(audio.isVoiceEnabled, isTrue);
      expect(audio.isBeepsEnabled, isTrue);
    });

    test('beepsOnly mode enables strictly beeps and disables voice', () {
      audio.soundMode = SoundMode.beepsOnly;
      expect(audio.isVoiceEnabled, isFalse);
      expect(audio.isBeepsEnabled, isTrue);
    });

    test('voiceOnly mode enables strictly voice and disables beeps', () {
      audio.soundMode = SoundMode.voiceOnly;
      expect(audio.isVoiceEnabled, isTrue);
      expect(audio.isBeepsEnabled, isFalse);
    });

    test('vibrationOnly mode disables both voice and beeps', () {
      audio.soundMode = SoundMode.vibrationOnly;
      expect(audio.isVoiceEnabled, isFalse);
      expect(audio.isBeepsEnabled, isFalse);
    });

    test('session muting suppresses both voice and beeps without changing soundMode', () {
      audio.soundMode = SoundMode.voiceAndBeeps;
      expect(audio.isSessionMuted, isFalse);

      audio.toggleSessionMute();
      expect(audio.isSessionMuted, isTrue);
      expect(audio.isVoiceEnabled, isFalse);
      expect(audio.isBeepsEnabled, isFalse);
      expect(audio.soundMode, equals(SoundMode.voiceAndBeeps));

      audio.toggleSessionMute();
      expect(audio.isSessionMuted, isFalse);
      expect(audio.isVoiceEnabled, isTrue);
      expect(audio.isBeepsEnabled, isTrue);
    });
  });
}
