// lib/widgets/exercise_difficulty_widget.dart
import 'package:flutter/material.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';

class ExerciseDifficultyWidget extends StatefulWidget {
  final String initialDifficulty;
  final Function(String) onDifficultyChanged;
  final bool showRecommendations;

  const ExerciseDifficultyWidget({
    super.key,
    this.initialDifficulty = 'perfect',
    required this.onDifficultyChanged,
    this.showRecommendations = true,
  });

  @override
  State<ExerciseDifficultyWidget> createState() =>
      _ExerciseDifficultyWidgetState();
}

class _ExerciseDifficultyWidgetState extends State<ExerciseDifficultyWidget>
    with TickerProviderStateMixin {
  late String _selectedDifficulty;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final Map<String, DifficultyOption> _difficultyOptions = {
    'easy': DifficultyOption(
      label: 'Too Easy',
      description: 'I could do more sets/reps',
      icon: Icons.sentiment_satisfied_alt,
      color: Colors.green,
      recommendation: 'We\'ll increase the intensity next time',
    ),
    'perfect': DifficultyOption(
      label: 'Just Right',
      description: 'Perfect challenge level',
      icon: Icons.sentiment_very_satisfied,
      color: Colors.blue,
      recommendation: 'Great! Keep this intensity',
    ),
    'hard': DifficultyOption(
      label: 'Too Hard',
      description: 'Struggled to complete',
      icon: Icons.sentiment_dissatisfied,
      color: Colors.orange,
      recommendation: 'We\'ll reduce the intensity next time',
    ),
  };

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = widget.initialDifficulty;
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _selectDifficulty(String difficulty) {
    setState(() {
      _selectedDifficulty = difficulty;
    });
    widget.onDifficultyChanged(difficulty);
    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fitness_center,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How was the difficulty?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Your feedback helps us adjust future exercises',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Difficulty Selection Cards
          Column(
            children: _difficultyOptions.entries.map((entry) {
              final difficulty = entry.key;
              final option = entry.value;
              final isSelected = _selectedDifficulty == difficulty;

              return AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isSelected ? _pulseAnimation.value : 1.0,
                    child: GestureDetector(
                      onTap: () => _selectDifficulty(difficulty),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? option.color.withOpacity(0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? option.color
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Selection indicator
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? option.color
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? option.color
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),

                            const SizedBox(width: 16),

                            // Difficulty icon
                            Icon(
                              option.icon,
                              color: isSelected ? option.color : Colors.grey,
                              size: 28,
                            ),

                            const SizedBox(width: 16),

                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.label,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? option.color
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    option.description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected
                                          ? option.color.withOpacity(0.8)
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Difficulty level indicator
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: option.color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getDifficultyLevel(difficulty),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),

          // Recommendation based on selection
          if (widget.showRecommendations && _selectedDifficulty.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _difficultyOptions[_selectedDifficulty]!
                    .color
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _difficultyOptions[_selectedDifficulty]!
                      .color
                      .withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: _difficultyOptions[_selectedDifficulty]!.color,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recommendation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                _difficultyOptions[_selectedDifficulty]!.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _difficultyOptions[_selectedDifficulty]!
                              .recommendation,
                          style: TextStyle(
                            fontSize: 13,
                            color: _difficultyOptions[_selectedDifficulty]!
                                .color
                                .withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getDifficultyLevel(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 'LOW';
      case 'perfect':
        return 'IDEAL';
      case 'hard':
        return 'HIGH';
      default:
        return 'UNKNOWN';
    }
  }
}

class DifficultyOption {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final String recommendation;

  DifficultyOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.recommendation,
  });
}
