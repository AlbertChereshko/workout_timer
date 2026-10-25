import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/models/athlete_profile.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../services/gemini_coach_service.dart';
import '../../services/recovery_analyzer.dart';
import '../workout_generator/ai_workout_generator_dialog.dart';

class CoachChatScreen extends ConsumerStatefulWidget {
  const CoachChatScreen({super.key});

  @override
  ConsumerState<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends ConsumerState<CoachChatScreen> {
  CoachPersona _currentPersona = CoachPersona.fitnessCoach;
  final List<Map<String, String>> _fitnessMessages = [];
  final List<Map<String, String>> _productMessages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isLoading = false;
  bool _showQuickPrompts = true;

  final List<String> _fitnessPrompts = [
    'Чем заменить планку при боли в плече?',
    'Составь прогрессию удержания статики на 3 недели',
    'Как лучше распределить силы в 20-минутном AMRAP?',
    'Какие упражнения сегодня подходят под моё восстановление?',
  ];

  final List<String> _productPrompts = [
    'Как подготовить приложение к релизу в Google Play?',
    'Идеи для десктопной версии на моём ноутбуке',
    'Как улучшить UX таймера и читаемость в зале?',
    'Какие ключевые фичи добавить перед публикацией?',
  ];

  List<Map<String, String>> get _activeMessages =>
      _currentPersona == CoachPersona.fitnessCoach ? _fitnessMessages : _productMessages;

  List<String> get _activeQuickPrompts =>
      _currentPersona == CoachPersona.fitnessCoach ? _fitnessPrompts : _productPrompts;

  @override
  void initState() {
    super.initState();
    // Приветствие от спортивного тренера
    _fitnessMessages.add({
      'role': 'model',
      'text': 'Привет, атлет! Я твой персональный ИИ-тренер и спортивный физиолог. '
          'Я учитываю твоё текущее мышечное восстановление, параметры профиля и историю занятий. '
          'О чём хочешь проконсультироваться по тренировкам?',
    });

    // Приветствие от продуктового архитектора
    _productMessages.add({
      'role': 'model',
      'text': 'Привет, создатель! Я твой продуктовый ИИ-архитектор и UX/UI советник по Workout Timer. '
          'Помогу продумать эргономику экранов, адаптировать интерфейс для ноутбука/веба, подготовить релиз в Google Play Store и настроить удержание пользователей.',
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _inputController.text).trim();
    if (text.isEmpty || _isLoading) return;

    HapticFeedback.lightImpact();
    if (presetText == null) {
      _inputController.clear();
    }

    setState(() {
      _activeMessages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _scrollToBottom();

    final coach = ref.read(geminiCoachServiceProvider);
    final profile = ref.read(athleteProfileProvider);
    final historyRepo = ref.read(historyRepositoryProvider);
    final workoutRepo = ref.read(workoutRepositoryProvider);

    final recentSessions = historyRepo.getSessions();
    final availableWorkouts = workoutRepo.getWorkouts();
    final report = RecoveryAnalyzer.analyze(
      recentSessions: recentSessions,
      availableWorkouts: availableWorkouts,
    );

    try {
      final reply = await coach.sendChatMessage(
        messages: _activeMessages,
        profile: profile,
        recoveryReport: report,
        recentSessions: recentSessions,
        persona: _currentPersona,
      );

      if (mounted) {
        setState(() {
          _activeMessages.add({'role': 'model', 'text': reply});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activeMessages.add({
            'role': 'model',
            'text': 'Извини, возникла ошибка соединения. Попробуй задать вопрос ещё раз.',
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final isLight = theme.isLight;
    final coach = ref.watch(geminiCoachServiceProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 860;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: theme.background,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Panel: AI Studio & Persona Switcher
              Container(
                width: 320,
                decoration: BoxDecoration(
                  color: theme.surface.withValues(alpha: 0.5),
                  border: Border(
                    right: BorderSide(color: theme.cardBorder, width: 1.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: AI Studio / Coach Info
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: (_currentPersona == CoachPersona.fitnessCoach
                                        ? theme.accent
                                        : const Color(0xFF8B5CF6))
                                    .withValues(alpha: 0.15),
                                radius: 20,
                                child: Icon(
                                  _currentPersona == CoachPersona.fitnessCoach
                                      ? Icons.psychology_rounded
                                      : Icons.lightbulb_rounded,
                                  color: _currentPersona == CoachPersona.fitnessCoach
                                      ? theme.accent
                                      : const Color(0xFF8B5CF6),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AI Studio',
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: coach.hasApiKey ? Colors.greenAccent : Colors.amberAccent,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          coach.hasApiKey ? 'Gemini AI Online' : 'Офлайн режим',
                                          style: TextStyle(
                                            color: theme.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'РЕЖИМ НАСТАВНИКА',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Persona Card 1: Fitness Coach
                          _buildPersonaCard(
                            persona: CoachPersona.fitnessCoach,
                            title: 'Спортивный Тренер',
                            subtitle: 'Физиология, прогрессия статики, подбор комплексов',
                            icon: '🏋️',
                            theme: theme,
                            color: theme.accent,
                          ),
                          const SizedBox(height: 8),
                          // Persona Card 2: Product Advisor
                          _buildPersonaCard(
                            persona: CoachPersona.productAdvisor,
                            title: 'Архитектор Приложения',
                            subtitle: 'UX/UI, десктоп/веб, релиз в Google Play Store',
                            icon: '💡',
                            theme: theme,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Prompt Suggestions
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        'БЫСТРЫЕ ВОПРОСЫ',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: _activeQuickPrompts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final prompt = _activeQuickPrompts[idx];
                          return InkWell(
                            onTap: () => _sendMessage(prompt),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.cardBorder),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 14, color: theme.accent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      prompt,
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontSize: 13,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton.icon(
                        onPressed: () => AiWorkoutGeneratorDialog.show(context),
                        icon: Icon(Icons.auto_awesome, color: theme.accent, size: 18),
                        label: const Text('AI-Конструктор комплексов'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.accent,
                          side: BorderSide(color: theme.accent.withValues(alpha: 0.5)),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Center / Right Panel: Chat Stream
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      children: [
                        // Chat Messages List
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            itemCount: _activeMessages.length,
                            itemBuilder: (context, idx) {
                              final msg = _activeMessages[idx];
                              final isUser = msg['role'] == 'user';
                              return _buildMessageBubble(msg, isUser, theme, isLight, isDesktop: true);
                            },
                          ),
                        ),

                        if (_isLoading) _buildLoadingIndicator(theme),

                        // Bottom Input Bar
                        _buildInputBar(theme, isLight, isDesktop: true),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile layout (< 860px)
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: (_currentPersona == CoachPersona.fitnessCoach
                            ? theme.accent
                            : const Color(0xFF8B5CF6))
                        .withValues(alpha: 0.15),
                    child: Icon(
                      _currentPersona == CoachPersona.fitnessCoach
                          ? Icons.psychology_rounded
                          : Icons.lightbulb_rounded,
                      color: _currentPersona == CoachPersona.fitnessCoach
                          ? theme.accent
                          : const Color(0xFF8B5CF6),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentPersona == CoachPersona.fitnessCoach
                              ? 'AI-Тренер Консультант'
                              : 'AI-Разработчик Приложения',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: coach.hasApiKey ? Colors.greenAccent : Colors.amberAccent,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              coach.hasApiKey ? 'Google Gemini AI на связи' : 'Офлайн режим советов',
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Открыть конструктор комплексов',
                    icon: Icon(Icons.auto_awesome, color: theme.accent),
                    onPressed: () => AiWorkoutGeneratorDialog.show(context),
                  ),
                ],
              ),
            ),

            // Segmented Persona Selector (Fitness Coach vs Product Advisor)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isLight ? theme.surface : const Color(0xFF131D31),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_currentPersona != CoachPersona.fitnessCoach) {
                            HapticFeedback.selectionClick();
                            setState(() => _currentPersona = CoachPersona.fitnessCoach);
                            _scrollToBottom();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _currentPersona == CoachPersona.fitnessCoach
                                ? theme.accent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🏋️', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                'Тренер',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _currentPersona == CoachPersona.fitnessCoach
                                      ? (theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                                      : theme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_currentPersona != CoachPersona.productAdvisor) {
                            HapticFeedback.selectionClick();
                            setState(() => _currentPersona = CoachPersona.productAdvisor);
                            _scrollToBottom();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _currentPersona == CoachPersona.productAdvisor
                                ? const Color(0xFF8B5CF6)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                'Разработчик',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _currentPersona == CoachPersona.productAdvisor
                                      ? Colors.white
                                      : theme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Quick Prompt Suggestions (Floating Wrap / Feed Style)
            _buildMobileQuickPrompts(theme, isLight),

            // Chat Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _activeMessages.length,
                itemBuilder: (context, idx) {
                  final msg = _activeMessages[idx];
                  final isUser = msg['role'] == 'user';
                  return _buildMessageBubble(msg, isUser, theme, isLight, isDesktop: false);
                },
              ),
            ),

            if (_isLoading) _buildLoadingIndicator(theme),

            // Bottom Input Bar
            _buildInputBar(theme, isLight, isDesktop: false),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonaCard({
    required CoachPersona persona,
    required String title,
    required String subtitle,
    required String icon,
    required AppThemeConfig theme,
    required Color color,
  }) {
    final isSelected = _currentPersona == persona;
    return InkWell(
      onTap: () {
        if (_currentPersona != persona) {
          HapticFeedback.selectionClick();
          setState(() => _currentPersona = persona);
          _scrollToBottom();
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : theme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : theme.cardBorder,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? color : theme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileQuickPrompts(AppThemeConfig theme, bool isLight) {
    if (_activeQuickPrompts.isEmpty) return const SizedBox.shrink();

    final isDev = _currentPersona == CoachPersona.productAdvisor;
    final emoji = isDev ? '💡' : '⚡';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isLight ? theme.surfaceSubtle.withValues(alpha: 0.5) : const Color(0xFF0F172A).withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: theme.cardBorder.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(
                    'Темы для диалога',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _showQuickPrompts = !_showQuickPrompts),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showQuickPrompts ? 'Свернуть' : 'Развернуть (${_activeQuickPrompts.length})',
                        style: TextStyle(fontSize: 10.5, color: theme.accent, fontWeight: FontWeight.w600),
                      ),
                      Icon(
                        _showQuickPrompts ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 14,
                        color: theme.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showQuickPrompts) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _activeQuickPrompts.map((prompt) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _sendMessage(prompt),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isLight ? theme.surface : const Color(0xFF131D31),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLight ? theme.cardBorder : theme.cardBorder.withValues(alpha: 0.7),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.25),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        prompt,
                        style: TextStyle(
                          color: isLight ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, String> msg,
    bool isUser,
    AppThemeConfig theme,
    bool isLight, {
    required bool isDesktop,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 680 : MediaQuery.of(context).size.width * 0.85,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 18 : 14,
          vertical: isDesktop ? 14 : 10,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.accent
              : (isLight ? theme.surface : const Color(0xFF131D31)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: Border.all(
            color: isUser
                ? theme.accent
                : (isLight ? theme.cardBorder : theme.cardBorder.withValues(alpha: 0.5)),
          ),
          boxShadow: isDesktop
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: isUser
            ? SelectableText(
                msg['text'] ?? '',
                style: TextStyle(
                  color: theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                  fontSize: isDesktop ? 15.5 : 13.5,
                  height: 1.45,
                  letterSpacing: 0.1,
                ),
              )
            : MarkdownBody(
                data: msg['text'] ?? '',
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: theme.textPrimary,
                    fontSize: isDesktop ? 15.5 : 13.5,
                    height: 1.45,
                    letterSpacing: 0.1,
                  ),
                  strong: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: isDesktop ? 15.5 : 13.5,
                    height: 1.45,
                  ),
                  em: TextStyle(
                    color: theme.textPrimary,
                    fontStyle: FontStyle.italic,
                    fontSize: isDesktop ? 15.5 : 13.5,
                  ),
                  code: TextStyle(
                    color: theme.accent,
                    backgroundColor: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                    fontFamily: 'monospace',
                    fontSize: isDesktop ? 14 : 12.5,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.cardBorder),
                  ),
                  codeblockPadding: const EdgeInsets.all(10),
                  listBullet: TextStyle(
                    color: theme.accent,
                    fontSize: isDesktop ? 15.5 : 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                  h1: TextStyle(
                    color: theme.textPrimary,
                    fontSize: isDesktop ? 20 : 17,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: TextStyle(
                    color: theme.textPrimary,
                    fontSize: isDesktop ? 18 : 15.5,
                    fontWeight: FontWeight.bold,
                  ),
                  h3: TextStyle(
                    color: theme.textPrimary,
                    fontSize: isDesktop ? 16.5 : 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                  blockSpacing: 8,
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingIndicator(AppThemeConfig theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: theme.accent),
          ),
          const SizedBox(width: 8),
          Text(
            'Тренер формулирует ответ...',
            style: TextStyle(color: theme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(AppThemeConfig theme, bool isLight, {required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.only(
        left: isDesktop ? 24 : 16,
        right: isDesktop ? 24 : 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + (isDesktop ? 14 : 8),
      ),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.cardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: KeyboardListener(
              focusNode: _inputFocusNode,
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _sendMessage();
                }
              },
              child: TextField(
                controller: _inputController,
                maxLines: isDesktop ? 4 : 3,
                minLines: 1,
                textInputAction: isDesktop ? TextInputAction.none : TextInputAction.send,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: isDesktop ? 15 : 14,
                ),
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: isDesktop
                      ? (_currentPersona == CoachPersona.fitnessCoach
                          ? 'Задайте вопрос тренеру (Enter — отправить, Shift+Enter — перенос)...'
                          : 'Задайте вопрос разработчику (Enter — отправить, Shift+Enter — перенос)...')
                      : (_currentPersona == CoachPersona.fitnessCoach
                          ? 'Задайте вопрос тренеру...'
                          : 'Задайте вопрос разработчику...'),
                  hintStyle: TextStyle(
                    color: theme.textSecondary.withValues(alpha: 0.6),
                    fontSize: isDesktop ? 14 : 13,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isDesktop ? 14 : 10,
                  ),
                  filled: true,
                  fillColor: isLight ? Colors.white : const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: theme.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: theme.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: theme.accent, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: theme.accent,
            radius: isDesktop ? 24 : 22,
            child: IconButton(
              icon: Icon(
                Icons.send_rounded,
                color: theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                size: isDesktop ? 20 : 18,
              ),
              onPressed: () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}
