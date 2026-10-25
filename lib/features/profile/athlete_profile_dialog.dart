import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/models/athlete_profile.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../services/gemini_coach_service.dart';
import '../../services/recovery_analyzer.dart';
import '../../core/pluralization.dart';

class AthleteProfileDialog extends ConsumerStatefulWidget {
  const AthleteProfileDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AthleteProfileDialog(),
    );
  }

  @override
  ConsumerState<AthleteProfileDialog> createState() => _AthleteProfileDialogState();
}

class _AthleteProfileDialogState extends ConsumerState<AthleteProfileDialog> {
  late double _weight;
  late double _height;
  late int _age;
  late String _gender;
  late FitnessLevel _level;
  late TextEditingController _apiKeyController;
  bool _obscureKey = true;
  bool? _isKeyValid;
  bool _isValidatingKey = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(athleteProfileProvider);
    _weight = profile.weightKg;
    _height = profile.heightCm;
    _age = profile.age;
    _gender = profile.gender;
    _level = profile.fitnessLevel;
    _apiKeyController = TextEditingController(text: profile.geminiApiKey ?? '');
    if (profile.geminiApiKey != null && profile.geminiApiKey!.trim().isNotEmpty) {
      _testApiKey();
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;

    setState(() {
      _isValidatingKey = true;
      _isKeyValid = null;
    });

    final valid = await GeminiCoachService.validateKey(key);
    if (!mounted) return;

    setState(() {
      _isValidatingKey = false;
      _isKeyValid = valid;
    });
  }

  Future<void> _saveProfile() async {
    final notifier = ref.read(athleteProfileProvider.notifier);
    await notifier.updateProfile(AthleteProfile(
      weightKg: _weight,
      heightCm: _height,
      age: _age,
      gender: _gender,
      fitnessLevel: _level,
      geminiApiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
    ));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Параметры атлета сохранены'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(appThemeProvider);
    final historyRepo = ref.watch(historyRepositoryProvider);
    final workoutRepo = ref.watch(workoutRepositoryProvider);

    final recentSessions = historyRepo.getSessions();
    final availableWorkouts = workoutRepo.getWorkouts();
    final recoveryReport = RecoveryAnalyzer.analyze(
      recentSessions: recentSessions,
      availableWorkouts: availableWorkouts,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: currentTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: currentTheme.cardBorder),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: currentTheme.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: currentTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.psychology_outlined, color: currentTheme.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Профиль атлета & AI',
                        style: TextStyle(
                          color: currentTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Расчет калорий и персональный коучинг',
                        style: TextStyle(
                          color: currentTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: currentTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Section 1: Biometrics
                _buildSectionTitle('Биометрические параметры', Icons.fitness_center_outlined, currentTheme),
                const SizedBox(height: 12),

                // Gender Selection
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceChip(
                        label: 'Мужской',
                        isSelected: _gender == 'male',
                        icon: Icons.male,
                        onTap: () => setState(() => _gender = 'male'),
                        currentTheme: currentTheme,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildChoiceChip(
                        label: 'Женский',
                        isSelected: _gender == 'female',
                        icon: Icons.female,
                        onTap: () => setState(() => _gender = 'female'),
                        currentTheme: currentTheme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Weight Slider
                _buildSliderRow(
                  label: 'Вес',
                  value: _weight,
                  min: 40,
                  max: 140,
                  unit: 'кг',
                  currentTheme: currentTheme,
                  onChanged: (v) => setState(() => _weight = (v * 2).round() / 2),
                ),
                const SizedBox(height: 12),

                // Height Slider
                _buildSliderRow(
                  label: 'Рост',
                  value: _height,
                  min: 140,
                  max: 215,
                  unit: 'см',
                  currentTheme: currentTheme,
                  onChanged: (v) => setState(() => _height = v.roundToDouble()),
                ),
                const SizedBox(height: 12),

                // Age Slider
                _buildSliderRow(
                  label: 'Возраст',
                  value: _age.toDouble(),
                  min: 14,
                  max: 80,
                  displayValue: RussianPlural.years(_age),
                  currentTheme: currentTheme,
                  onChanged: (v) => setState(() => _age = v.toInt()),
                ),
                const SizedBox(height: 16),

                // Fitness level
                Text(
                  'Уровень подготовки:',
                  style: TextStyle(color: currentTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildLevelChip(
                        level: FitnessLevel.beginner,
                        label: 'Новичок',
                        currentTheme: currentTheme,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLevelChip(
                        level: FitnessLevel.intermediate,
                        label: 'Средний',
                        currentTheme: currentTheme,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLevelChip(
                        level: FitnessLevel.advanced,
                        label: 'Опытный',
                        currentTheme: currentTheme,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Section 2: Muscle Recovery Status
                _buildSectionTitle('Баланс восстановления мышц', Icons.battery_charging_full_rounded, currentTheme),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: currentTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: currentTheme.cardBorder),
                  ),
                  child: Column(
                    children: recoveryReport.statuses.map((status) {
                      return _buildRecoveryBar(status, currentTheme);
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 28),

                // Section 3: Gemini API Setup
                _buildSectionTitle('Интеграция Gemini AI', Icons.auto_awesome, currentTheme),
                const SizedBox(height: 8),
                Text(
                  'Персональный разбор тренировок, расчет темпа и умные рекомендации комплексов на основе искусственного интеллекта.',
                  style: TextStyle(color: currentTheme.textSecondary, fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: currentTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isKeyValid == true
                          ? Colors.greenAccent
                          : (_isKeyValid == false ? Colors.redAccent : currentTheme.cardBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _apiKeyController,
                          obscureText: _obscureKey,
                          style: TextStyle(color: currentTheme.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Вставьте ключ Gemini API (AIzaSy... или AQ...)',
                            hintStyle: TextStyle(
                              color: currentTheme.textSecondary.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: currentTheme.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                      if (_isValidatingKey)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_isKeyValid == true)
                        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 22)
                      else
                        TextButton(
                          onPressed: _testApiKey,
                          child: Text(
                            'Проверить',
                            style: TextStyle(color: currentTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Model status & connection details
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isKeyValid == true
                        ? Colors.greenAccent.withValues(alpha: 0.12)
                        : currentTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isKeyValid == true
                          ? Colors.greenAccent.withValues(alpha: 0.4)
                          : currentTheme.cardBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isKeyValid == true ? Icons.verified_outlined : Icons.info_outline,
                        size: 16,
                        color: _isKeyValid == true ? Colors.greenAccent : currentTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isKeyValid == true
                              ? 'Подключено: Google Gemini AI (активно)'
                              : (_isKeyValid == false
                                  ? 'Ключ не подошел или нет соединения'
                                  : (_apiKeyController.text.trim().isNotEmpty
                                      ? 'Нажмите «Проверить» для тестирования Gemini'
                                      : 'Gemini не настроен. Работает локальный офлайн-алгоритм')),
                          style: TextStyle(
                            color: _isKeyValid == true
                                ? Colors.greenAccent
                                : (_isKeyValid == false ? Colors.redAccent : currentTheme.textSecondary),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '💡 Бесплатный ключ можно получить на aistudio.google.com. При активном ключе задействуется Google Gemini AI.',
                  style: TextStyle(
                    color: currentTheme.textSecondary.withValues(alpha: 0.7),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // Bottom save action
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 10,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: currentTheme.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saveProfile,
                child: Text(
                  'Сохранить параметры',
                  style: TextStyle(
                    color: currentTheme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, AppThemeConfig theme) {
    return Row(
      children: [
        Icon(icon, color: theme.accent, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    required AppThemeConfig currentTheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? currentTheme.accent.withValues(alpha: 0.15) : currentTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? currentTheme.accent : currentTheme.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? currentTheme.accent : currentTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? currentTheme.accent : currentTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelChip({
    required FitnessLevel level,
    required String label,
    required AppThemeConfig currentTheme,
  }) {
    final isSelected = _level == level;
    return InkWell(
      onTap: () => setState(() => _level = level),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? currentTheme.accent : currentTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? currentTheme.accent : currentTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (currentTheme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                : currentTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    String? unit,
    String? displayValue,
    required AppThemeConfig currentTheme,
    required ValueChanged<double> onChanged,
  }) {
    final textToShow = displayValue ?? '${value.toInt()} ${unit ?? ""}';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: currentTheme.textSecondary, fontSize: 13)),
            Text(
              textToShow,
              style: TextStyle(color: currentTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: currentTheme.accent,
          inactiveColor: currentTheme.cardBorder,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildRecoveryBar(MuscleRecoveryStatus status, AppThemeConfig theme) {
    Color barColor;
    if (status.isReady) {
      barColor = Colors.greenAccent;
    } else if (status.isRecovering) {
      barColor = Colors.amberAccent;
    } else {
      barColor = Colors.redAccent;
    }

    final percent = (status.recoveryPercent * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                status.group.displayName,
                style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                '$percent% • ${status.statusText}',
                style: TextStyle(color: barColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: status.recoveryPercent,
              minHeight: 6,
              backgroundColor: theme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}
