// lib/screens/exercise_completion_screen.dart (Fixed Version)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/models/exercise_feedback_model.dart';
import 'package:personalized_rehabilitation_plans/widgets/pain_feedback_widget.dart';
import 'package:personalized_rehabilitation_plans/widgets/exercise_difficulty_widget.dart';
import 'package:personalized_rehabilitation_plans/widgets/custom_button.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
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
  int _postPainLevel = 5;
  String _difficultyRating = 'perfect';
  String _additionalNotes = '';
  bool _isSubmitting = false;

  late AnimationController _celebrationController;
  late Animation<double> _celebrationAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _postPainLevel = widget.prePainLevel; // Start with same as pre-exercise

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _celebrationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.elasticOut,
    ));

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    // Start animations
    _celebrationController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _slideController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create exercise feedback
      final feedback = ExerciseFeedback(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        exerciseId: widget.exercise.id,
        exerciseName: widget.exercise.name,
        painLevelBefore: widget.prePainLevel,
        painLevelAfter: _postPainLevel,
        difficultyRating: _difficultyRating,
        completedSets: widget.completedSets,
        completedReps: widget.completedReps,
        targetSets: widget.exercise.sets,
        targetReps: widget.exercise.reps,
        actualDurationSeconds: widget.actualDurationSeconds,
        targetDurationSeconds: widget.exercise.durationSeconds,
        notes: _additionalNotes.isNotEmpty ? _additionalNotes : null,
        completed: true,
        timestamp: DateTime.now(),
        additionalMetrics: {
          'bodyPart': widget.exercise.bodyPart,
          'difficultyLevel': widget.exercise.difficultyLevel,
          'planId': widget.planId,
        },
      );

      // Save feedback to Firestore
      await FirebaseFirestore.instance
          .collection('exerciseFeedbacks')
          .add(feedback.toMap());

      // Update progress log
      await _updateProgressLog(feedback);

      // CRITICAL: Mark exercise as completed in the plan
      if (widget.planId != null) {
        await _markExerciseAsCompleted(
            userId, widget.planId!, widget.exercise.id);
      }

      // Send feedback to backend for analysis
      await _sendFeedbackToBackend(feedback);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exercise feedback submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Return with completion status and exercise ID
        Navigator.of(context).pop({
          'completed': true,
          'exerciseId': widget.exercise.id,
          'feedback': feedback.toMap(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _markExerciseAsCompleted(
      String userId, String planId, String exerciseId) async {
    try {
      // Find the plan document
      final planQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('rehabilitation_plans')
          .where(FieldPath.documentId, isEqualTo: planId)
          .get();

      if (planQuery.docs.isNotEmpty) {
        final planDoc = planQuery.docs.first;
        final planData = planDoc.data();

        // Update the exercise completion status
        List<dynamic> exercises = List.from(planData['exercises'] ?? []);

        for (int i = 0; i < exercises.length; i++) {
          if (exercises[i]['id'] == exerciseId) {
            exercises[i]['isCompleted'] = true;
            // FIX: Use DateTime.now() instead of FieldValue.serverTimestamp() inside arrays
            exercises[i]['completedAt'] = DateTime.now().toIso8601String();
            break;
          }
        }

        // Update the plan document
        await planDoc.reference.update({
          'exercises': exercises,
          'lastUpdated':
              FieldValue.serverTimestamp(), // This is OK outside arrays
        });

        print('✅ Exercise marked as completed in plan: $exerciseId');
      } else {
        // Try alternative collection structure
        final alternativePlanDoc = await FirebaseFirestore.instance
            .collection('rehabilitation_plans')
            .doc(planId)
            .get();

        if (alternativePlanDoc.exists) {
          final planData = alternativePlanDoc.data()!;
          List<dynamic> exercises = List.from(planData['exercises'] ?? []);

          for (int i = 0; i < exercises.length; i++) {
            if (exercises[i]['id'] == exerciseId) {
              exercises[i]['isCompleted'] = true;
              // FIX: Use DateTime.now() instead of FieldValue.serverTimestamp()
              exercises[i]['completedAt'] = DateTime.now().toIso8601String();
              break;
            }
          }

          await alternativePlanDoc.reference.update({
            'exercises': exercises,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          print(
              '✅ Exercise marked as completed in alternative plan structure: $exerciseId');
        }
      }
    } catch (e) {
      print('❌ Error marking exercise as completed: $e');
      // Don't throw error - feedback should still be saved
    }
  }

  Future<void> _updateProgressLog(ExerciseFeedback feedback) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      if (userId == null) return;

      // Check if there's a progress log for today
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final existingLogs = await FirebaseFirestore.instance
          .collection('progressLogs')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThan: endOfDay)
          .get();

      if (existingLogs.docs.isNotEmpty) {
        // Update existing log
        final logDoc = existingLogs.docs.first;
        final logData = logDoc.data();
        final exerciseLogs =
            List<Map<String, dynamic>>.from(logData['exerciseLogs'] ?? []);

        exerciseLogs.add({
          'exerciseId': feedback.exerciseId,
          'exerciseName': feedback.exerciseName,
          'setsCompleted': feedback.completedSets,
          'repsCompleted': feedback.completedReps,
          'durationSeconds': feedback.actualDurationSeconds,
          'painLevel': feedback.painLevelAfter,
          'prePainLevel': feedback.painLevelBefore,
          'difficultyRating': feedback.difficultyRating,
          'completionPercentage': feedback.completionPercentage,
          'notes': feedback.notes,
          'completed': true,
          // FIX: Use DateTime.now() instead of FieldValue.serverTimestamp()
          'timestamp': DateTime.now().toIso8601String(),
        });

        await logDoc.reference.update({
          'exerciseLogs': exerciseLogs,
          'lastUpdated':
              FieldValue.serverTimestamp(), // This is OK outside arrays
          'overallRating': _calculateOverallRating(),
          'adherencePercentage': _calculateAdherence(),
        });
      } else {
        // Create new progress log
        await FirebaseFirestore.instance.collection('progressLogs').add({
          'userId': userId,
          'planId': widget.planId,
          'date': FieldValue.serverTimestamp(),
          'exerciseLogs': [
            {
              'exerciseId': feedback.exerciseId,
              'exerciseName': feedback.exerciseName,
              'setsCompleted': feedback.completedSets,
              'repsCompleted': feedback.completedReps,
              'durationSeconds': feedback.actualDurationSeconds,
              'painLevel': feedback.painLevelAfter,
              'prePainLevel': feedback.painLevelBefore,
              'difficultyRating': feedback.difficultyRating,
              'completionPercentage': feedback.completionPercentage,
              'notes': feedback.notes,
              'completed': true,
              // FIX: Use DateTime.now() instead of FieldValue.serverTimestamp()
              'timestamp': DateTime.now().toIso8601String(),
            }
          ],
          'overallRating': _calculateOverallRating(),
          'adherencePercentage': _calculateAdherence(),
          'feedback': _additionalNotes,
          'sessionSatisfaction': _calculateSessionSatisfaction(),
        });
      }
    } catch (e) {
      print('Error updating progress log: $e');
    }
  }

  Future<void> _sendFeedbackToBackend(ExerciseFeedback feedback) async {
    try {
      // This would integrate with your Flask backend
      // For now, we'll just print the data that would be sent
      print('Feedback data for backend analysis:');
      print('Exercise: ${feedback.exerciseName}');
      print('Difficulty: ${feedback.difficultyRating}');
      print('Pain change: ${feedback.painChange}');
      print('Completion rate: ${feedback.completionPercentage}');

      // TODO: Implement actual HTTP call to Flask backend
      // final response = await http.post(
      //   Uri.parse('${RehabilitationService.baseUrl}/analyze_feedback'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({'feedback': feedback.toMap()}),
      // );
    } catch (e) {
      print('Error sending feedback to backend: $e');
    }
  }

  int _calculateOverallRating() {
    // Simple rating based on pain change and difficulty
    int rating = 3; // Default neutral

    if (_postPainLevel < widget.prePainLevel) {
      rating += 1; // Pain decreased
    } else if (_postPainLevel > widget.prePainLevel) {
      rating -= 1; // Pain increased
    }

    if (_difficultyRating == 'perfect') {
      rating += 1;
    } else if (_difficultyRating == 'hard') {
      rating -= 1;
    }

    return rating.clamp(1, 5);
  }

  int _calculateAdherence() {
    final setsCompletion = (widget.completedSets / widget.exercise.sets) * 100;
    final repsCompletion = (widget.completedReps / widget.exercise.reps) * 100;
    return ((setsCompletion + repsCompletion) / 2).round().clamp(0, 100);
  }

  double _calculateSessionSatisfaction() {
    double satisfaction = 3.0; // Base satisfaction

    // Adjust based on pain change
    final painChange = _postPainLevel - widget.prePainLevel;
    if (painChange < 0) {
      satisfaction += 1.0; // Pain improved
    } else if (painChange > 0) {
      satisfaction -= 0.5; // Pain worsened
    }

    // Adjust based on difficulty
    if (_difficultyRating == 'perfect') {
      satisfaction += 0.5;
    } else if (_difficultyRating == 'hard') {
      satisfaction -= 0.5;
    }

    return satisfaction.clamp(1.0, 5.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      appBar: AppBar(
        title: const Text('Exercise Complete'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.primaryBlue,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Prevent going back without submitting feedback
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Submit Feedback'),
                content: const Text(
                    'Please submit your feedback before leaving this screen.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Continue Feedback'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context, {'completed': false}); // Go back
                    },
                    child: const Text('Skip Feedback'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Celebration header
              AnimatedBuilder(
                animation: _celebrationAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _celebrationAnimation.value,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.celebration,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Great Job!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You completed: ${widget.exercise.name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Exercise summary
              _buildExerciseSummary(),

              const SizedBox(height: 24),

              // Pain level feedback
              PainFeedbackWidget(
                initialPainLevel: _postPainLevel,
                title: 'How do you feel now?',
                subtitle: 'Rate your pain level after the exercise',
                onPainLevelChanged: (level) {
                  setState(() {
                    _postPainLevel = level;
                  });
                },
                showComparison: true,
                previousPainLevel: widget.prePainLevel,
              ),

              const SizedBox(height: 24),

              // Difficulty feedback
              ExerciseDifficultyWidget(
                initialDifficulty: _difficultyRating,
                onDifficultyChanged: (difficulty) {
                  setState(() {
                    _difficultyRating = difficulty;
                  });
                },
                showRecommendations: true,
              ),

              const SizedBox(height: 24),

              // Additional notes
              _buildNotesSection(),

              const SizedBox(height: 32),

              // Submit button
              CustomButton(
                text: _isSubmitting ? 'Submitting...' : 'Submit Feedback',
                onPressed: _isSubmitting ? null : _submitFeedback,
                width: double.infinity,
                isLoading: _isSubmitting,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseSummary() {
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
                Icons.summarize,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Exercise Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Sets Completed',
                  '${widget.completedSets}/${widget.exercise.sets}',
                  Icons.repeat,
                  _getSetsCompletionColor(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  'Reps Completed',
                  '${widget.completedReps}/${widget.exercise.reps}',
                  Icons.fitness_center,
                  _getRepsCompletionColor(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryItem(
            'Duration',
            '${(widget.actualDurationSeconds / 60).ceil()} min (target: ${(widget.exercise.durationSeconds / 60).ceil()} min)',
            Icons.timer,
            _getDurationCompletionColor(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
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
                Icons.note_add,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Additional Notes (Optional)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'How did you feel during the exercise? Any specific observations?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (value) {
              setState(() {
                _additionalNotes = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Color _getSetsCompletionColor() {
    final completion = widget.completedSets / widget.exercise.sets;
    if (completion >= 1.0) return Colors.green;
    if (completion >= 0.8) return Colors.orange;
    return Colors.red;
  }

  Color _getRepsCompletionColor() {
    final completion = widget.completedReps / widget.exercise.reps;
    if (completion >= 1.0) return Colors.green;
    if (completion >= 0.8) return Colors.orange;
    return Colors.red;
  }

  Color _getDurationCompletionColor() {
    final completion =
        widget.actualDurationSeconds / widget.exercise.durationSeconds;
    if (completion >= 0.8 && completion <= 1.2) return Colors.green;
    if (completion >= 0.6) return Colors.orange;
    return Colors.red;
  }
}
