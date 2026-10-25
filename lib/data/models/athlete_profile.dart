import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum FitnessLevel {
  beginner,
  intermediate,
  advanced,
}

class AthleteProfile {
  final double weightKg;
  final double heightCm;
  final int age;
  final String gender; // 'male' or 'female'
  final FitnessLevel fitnessLevel;
  final String? geminiApiKey;

  const AthleteProfile({
    this.weightKg = 75.0,
    this.heightCm = 178.0,
    this.age = 30,
    this.gender = 'male',
    this.fitnessLevel = FitnessLevel.intermediate,
    this.geminiApiKey,
  });

  AthleteProfile copyWith({
    double? weightKg,
    double? heightCm,
    int? age,
    String? gender,
    FitnessLevel? fitnessLevel,
    String? geminiApiKey,
    bool clearApiKey = false,
  }) {
    return AthleteProfile(
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      geminiApiKey: clearApiKey ? null : (geminiApiKey ?? this.geminiApiKey),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weightKg': weightKg,
      'heightCm': heightCm,
      'age': age,
      'gender': gender,
      'fitnessLevel': fitnessLevel.name,
      'geminiApiKey': geminiApiKey,
    };
  }

  factory AthleteProfile.fromMap(Map<dynamic, dynamic> map) {
    FitnessLevel level = FitnessLevel.intermediate;
    final levelStr = map['fitnessLevel'] as String?;
    if (levelStr != null) {
      level = FitnessLevel.values.firstWhere(
        (e) => e.name == levelStr,
        orElse: () => FitnessLevel.intermediate,
      );
    }

    return AthleteProfile(
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 75.0,
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 178.0,
      age: (map['age'] as num?)?.toInt() ?? 30,
      gender: (map['gender'] as String?) ?? 'male',
      fitnessLevel: level,
      geminiApiKey: map['geminiApiKey'] as String?,
    );
  }
}

class AthleteProfileNotifier extends StateNotifier<AthleteProfile> {
  static const _kProfileKey = 'athlete_profile';

  AthleteProfileNotifier() : super(const AthleteProfile()) {
    _loadProfile();
  }

  void _loadProfile() {
    if (Hive.isBoxOpen('settings')) {
      final box = Hive.box('settings');
      final data = box.get(_kProfileKey);
      if (data is Map) {
        state = AthleteProfile.fromMap(data);
      }
    }
  }

  Future<void> updateProfile(AthleteProfile profile) async {
    state = profile;
    if (Hive.isBoxOpen('settings')) {
      final box = Hive.box('settings');
      await box.put(_kProfileKey, profile.toMap());
    }
  }

  Future<void> setWeight(double weight) async {
    await updateProfile(state.copyWith(weightKg: weight));
  }

  Future<void> setHeight(double height) async {
    await updateProfile(state.copyWith(heightCm: height));
  }

  Future<void> setAge(int age) async {
    await updateProfile(state.copyWith(age: age));
  }

  Future<void> setGender(String gender) async {
    await updateProfile(state.copyWith(gender: gender));
  }

  Future<void> setFitnessLevel(FitnessLevel level) async {
    await updateProfile(state.copyWith(fitnessLevel: level));
  }

  Future<void> setGeminiApiKey(String? apiKey) async {
    await updateProfile(state.copyWith(
      geminiApiKey: apiKey,
      clearApiKey: apiKey == null || apiKey.trim().isEmpty,
    ));
  }
}

final athleteProfileProvider =
    StateNotifierProvider<AthleteProfileNotifier, AthleteProfile>((ref) {
  return AthleteProfileNotifier();
});
