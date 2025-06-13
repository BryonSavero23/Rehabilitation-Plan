// lib/screens/exercise_completion_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/models/exercise_feedback_model.dart';
import 'package:personalized_rehabilitation_plans/widgets/pain_feedback_widget.dart';
import 'package:personalized_rehabilitation_plans/widgets/exercise_difficulty_widget.dart';
import 'package:personalized_rehabilitation_plans/widgets/custom_button.dart';
import 'package:personalized_rehabilitation_plans/widgets/weekly_feedback_dialog.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/services/weekly_progression_service.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';

class ExerciseCompletionScreen extends StatefulWidget {
  final Exercise exercise;
  final int completedSets;
  final int completedReps;
  final int actualDurationSeconds;
  final int prePainLevel;
  final String? planId;

  const ExerciseCompletionScreen({
    super.key,
    required this.exercise,
    required this.completedSets,
    required this.completedReps,
    required this.actualDurationSeconds,
    required this.prePainLevel,
    this.planId,
  });

  @override
  State<ExerciseCompletionScreen> createState() =>
      _ExerciseCompletionScreenState();
}

class _ExerciseCompletionScreenState extends State<ExerciseCompletionScreen>
    with TickerProviderStateMixin {
  // 🆕 Weekly progression service
  final WeeklyProgressionService _progressionService =
      WeeklyProgressionService();

  // Feedback state
  int _postPainLevel = 5;
  String _difficultyRating = 'perfect';
  String _additionalNotes = '';
  bool _isSubmitting = false;
  bool _isAnalyzing = false;
  bool _feedbackSubmitted = false;

  // 🆕 Weekly tracking state
  bool _weekCompleted = false;
  Map<String, dynamic>? _weeklyResults;

  // AI Analysis state
  Map<String, dynamic>? _aiAnalysis;
  Map<String, dynamic>? _adjustmentRecommendations;

  // Animation controllers
  late AnimationController _successAnimationController;
  late Animation<double> _successAnimation;

  // Controllers
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _successAnimationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _isAnalyzing = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      if (widget.planId == null) {
        throw Exception('Plan ID is required');
      }

      // 🆕 Get current week number
      final currentWeek = await _progressionService.getCurrentWeekNumber(
          userId, widget.planId!);

      // Prepare feedback data
      final feedbackData = {
        'painLevelBefore': widget.prePainLevel,
        'painLevelAfter': _postPainLevel,
        'difficultyRating': _difficultyRating,
        'completedSets': widget.completedSets,
        'completedReps': widget.completedReps,
        'targetSets': widget.exercise.sets,
        'targetReps': widget.exercise.reps,
        'actualDurationSeconds': widget.actualDurationSeconds,
        'targetDurationSeconds': widget.exercise.durationSeconds,
        'notes': _additionalNotes.isNotEmpty ? _additionalNotes : null,
        'completed': true,
        'exerciseName': widget.exercise.name,
        'bodyPart': widget.exercise.bodyPart,
        'difficultyLevel': widget.exercise.difficultyLevel,
      };

      // 🆕 Submit with weekly progression tracking
      final result = await _progressionService.completeExerciseWithFeedback(
        userId: userId,
        planId: widget.planId!,
        exerciseId: widget.exercise.id,
        feedbackData: feedbackData,
        weekNumber: currentWeek,
      );

      if (result['success'] == true) {
        setState(() {
          _feedbackSubmitted = true;
          _isAnalyzing = false;
          _weeklyResults = result['weeklyAdjustments'];
          _weekCompleted = _weeklyResults != null;
        });

        // Start success animation
        _successAnimationController.forward();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Exercise completed successfully!'),
                        if (_weekCompleted)
                          const Text(
                            'Week completed! Adjustments generated.',
                            style: TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // 🆕 Check if week is completed and show weekly feedback
        if (_weekCompleted) {
          _showWeeklyFeedback(currentWeek);
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to submit feedback');
      }
    } catch (e) {
      print('❌ Error submitting feedback: $e');

      setState(() {
        _isAnalyzing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // 🆕 Show weekly feedback dialog
  Future<void> _showWeeklyFeedback(int weekNumber) async {
    try {
      // Get rehabilitation goals
      final goals =
          await _progressionService.getRehabilitationGoals(widget.planId!);

      if (goals.isEmpty) {
        print('⚠️ No goals found for plan ${widget.planId}');
        return;
      }

      // Show weekly feedback dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WeeklyFeedbackDialog(
            userId: Provider.of<AuthService>(context, listen: false)
                .currentUser!
                .uid,
            planId: widget.planId!,
            weekNumber: weekNumber,
            goals: goals,
            onComplete: (result) {
              // Handle graduation or continuation
              final isGraduated = result['isGraduated'] as bool? ?? false;

              if (isGraduated) {
                // Navigate to graduation screen or home
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/patient_home',
                  (route) => false,
                );
              }
            },
          ),
        );
      }
    } catch (e) {
      print('❌ Error showing weekly feedback: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Exercise Complete'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _feedbackSubmitted
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Exercise Summary Card
            _buildExerciseSummaryCard(),
            const SizedBox(height: 20),

            if (!_feedbackSubmitted) ...[
              // Pain Level Feedback
              _buildPainFeedbackSection(),
              const SizedBox(height: 20),

              // Difficulty Rating
              _buildDifficultySection(),
              const SizedBox(height: 20),

              // Additional Notes
              _buildNotesSection(),
              const SizedBox(height: 30),

              // Submit Button
              _buildSubmitButton(),
            ] else ...[
              // Success Feedback Display
              _buildSuccessFeedback(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseSummaryCard() {
    final completionPercentage = widget.exercise.sets > 0
        ? (widget.completedSets / widget.exercise.sets * 100).clamp(0, 100)
        : 100.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Theme.of(context).primaryColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.fitness_center,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.exercise.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.exercise.bodyPart,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                if (_feedbackSubmitted)
                  ScaleTransition(
                    scale: _successAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Performance Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Sets',
                    '${widget.completedSets}/${widget.exercise.sets}',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Reps',
                    '${widget.completedReps}/${widget.exercise.reps}',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Duration',
                    '${(widget.actualDurationSeconds / 60).toStringAsFixed(1)}m',
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Completion Progress
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Completion Rate',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '${completionPercentage.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: completionPercentage >= 80
                                ? Colors.green
                                : Colors.orange,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: completionPercentage / 100,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completionPercentage >= 80 ? Colors.green : Colors.orange,
                  ),
                  minHeight: 8,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildPainFeedbackSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.healing,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Pain Level After Exercise',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'How do you feel now compared to before the exercise?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 20),

            // Pain comparison
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Before',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.prePainLevel.toString(),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: Colors.grey[400],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'After',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _postPainLevel.toString(),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _postPainLevel <= widget.prePainLevel
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            PainFeedbackWidget(
              initialPainLevel: _postPainLevel,
              onPainLevelChanged: (level) {
                setState(() {
                  _postPainLevel = level;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Exercise Difficulty',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'How challenging was this exercise for you?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 20),
            ExerciseDifficultyWidget(
              initialDifficulty: _difficultyRating,
              onDifficultyChanged: (difficulty) {
                setState(() {
                  _difficultyRating = difficulty;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notes,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Additional Notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Any observations or comments about this exercise? (Optional)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              onChanged: (value) {
                setState(() {
                  _additionalNotes = value;
                });
              },
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'e.g., Felt easier than last time, some stiffness in the morning...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return CustomButton(
      text: _isSubmitting ? 'Submitting...' : 'Complete Exercise',
      onPressed: _isSubmitting ? null : _submitFeedback,
      isLoading: _isSubmitting,
      icon: _isSubmitting ? null : Icons.check_circle_outline,
    );
  }

  Widget _buildSuccessFeedback() {
    return Column(
      children: [
        // Success Animation and Message
        ScaleTransition(
          scale: _successAnimation,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Exercise Completed!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your feedback has been recorded and will help improve your future exercises.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green.shade600,
                      ),
                ),
                if (_weekCompleted) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.celebration,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Week completed! Check your progress and next week\'s adjustments.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // AI Analysis Section (if available)
        if (_isAnalyzing) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Analyzing Your Performance...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'re processing your feedback to optimize future exercises.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.blue.shade600,
                      ),
                ),
              ],
            ),
          ),
        ] else if (_aiAnalysis != null) ...[
          // Show AI recommendations if available
          _buildAIRecommendations(),
        ],

        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.home),
                label: const Text('Back to Dashboard'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_weekCompleted) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to progress screen
                    Navigator.of(context).pushReplacementNamed('/progress');
                  },
                  icon: const Icon(Icons.insights),
                  label: const Text('View Progress'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAIRecommendations() {
    final recommendations =
        _aiAnalysis?['recommendations'] as List<dynamic>? ?? [];

    if (recommendations.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: Colors.purple.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'AI Recommendations',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recommendations.map((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.purple.shade400,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rec.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.purple.shade700,
                            ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
