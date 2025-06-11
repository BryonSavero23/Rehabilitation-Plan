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
import 'package:personalized_rehabilitation_plans/services/rehabilitation_service.dart';
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
  Map<String, dynamic>? _aiAnalysis;
  bool _showAIInsights = false;

  late AnimationController _celebrationController;
  late Animation<double> _celebrationAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _aiInsightsController;
  late Animation<double> _aiInsightsAnimation;

  final TextEditingController _notesController = TextEditingController();
  final RehabilitationService _rehabilitationService = RehabilitationService();

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

    _aiInsightsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _aiInsightsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _aiInsightsController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _celebrationController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _slideController.dispose();
    _aiInsightsController.dispose();
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

      // Send feedback to AI backend for analysis
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
          'aiAnalysis': _aiAnalysis,
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

  // FIXED: Send feedback to AI backend for analysis with proper JSON serialization
  Future<void> _sendFeedbackToBackend(ExerciseFeedback feedback) async {
    try {
      print('🧠 Sending feedback to AI for analysis...');

      // FIX: Create a JSON-serializable version of the feedback
      final Map<String, dynamic> jsonSerializableFeedback = {
        'id': feedback.id,
        'userId': feedback.userId,
        'exerciseId': feedback.exerciseId,
        'exerciseName': feedback.exerciseName,
        'painLevelBefore': feedback.painLevelBefore,
        'painLevelAfter': feedback.painLevelAfter,
        'difficultyRating': feedback.difficultyRating,
        'completedSets': feedback.completedSets,
        'completedReps': feedback.completedReps,
        'targetSets': feedback.targetSets,
        'targetReps': feedback.targetReps,
        'actualDurationSeconds': feedback.actualDurationSeconds,
        'targetDurationSeconds': feedback.targetDurationSeconds,
        'notes': feedback.notes,
        'completed': feedback.completed,
        'timestamp':
            feedback.timestamp.toIso8601String(), // Convert DateTime to string
        'additionalMetrics': feedback.additionalMetrics,
      };

      print('📊 Sending feedback to deployed backend...');
      final response = await _rehabilitationService
          .analyzeFeedback(jsonSerializableFeedback);

      print('🧠 AI Analysis Results: $response');

      // Store AI analysis for display
      if (response['analysis'] != null) {
        setState(() {
          _aiAnalysis = response['analysis'];
          _showAIInsights = true;
        });

        // Animate AI insights appearance
        _aiInsightsController.forward();

        final analysis = response['analysis'];
        final recommendations = analysis['recommendations'] as List<dynamic>?;

        if (recommendations != null && recommendations.isNotEmpty && mounted) {
          // Show the most important recommendation to the user
          final topRecommendation = recommendations.first.toString();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      const Text('AI Recommendation',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(topRecommendation),
                ],
              ),
              backgroundColor: Colors.blue.shade600,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'View All',
                textColor: Colors.white,
                onPressed: () => _showAllRecommendations(recommendations),
              ),
            ),
          );
        }

        // Log effectiveness score for debugging
        final effectivenessScore = analysis['effectiveness_score'];
        if (effectivenessScore != null) {
          print(
              '📊 Exercise effectiveness: ${(effectivenessScore * 100).toStringAsFixed(1)}%');
        }

        // Handle pain analysis
        final painAnalysis = analysis['pain_analysis'];
        if (painAnalysis != null && painAnalysis['is_beneficial'] == true) {
          print('✅ Exercise was beneficial for pain management');
        }
      } else {
        print('⚠️ No analysis data received from backend');
      }
    } catch (e) {
      print('❌ Error analyzing feedback with AI: $e');
      // Show user-friendly message for common errors
      if (mounted) {
        String userMessage = 'AI analysis temporarily unavailable';

        if (e.toString().contains('timeout') ||
            e.toString().contains('connection')) {
          userMessage =
              'Backend connection issue - your feedback was saved locally';
        } else if (e.toString().contains('500')) {
          userMessage =
              'AI service temporarily down - feedback saved successfully';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(userMessage)),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      // Don't throw error - feedback submission should still succeed
    }
  }

  // Show all AI recommendations in a dialog
  void _showAllRecommendations(List<dynamic> recommendations) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue),
            SizedBox(width: 8),
            Text('AI Recommendations'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: recommendations
              .map((rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(rec.toString())),
                      ],
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
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

              // AI Insights Section (appears after feedback analysis)
              if (_showAIInsights && _aiAnalysis != null) ...[
                AnimatedBuilder(
                  animation: _aiInsightsAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _aiInsightsAnimation.value,
                      child: Opacity(
                        opacity: _aiInsightsAnimation.value,
                        child: _buildAIInsights(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Additional notes
              _buildNotesSection(),

              const SizedBox(height: 32),

              // Submit button
              CustomButton(
                text:
                    _isSubmitting ? 'Analyzing with AI...' : 'Submit Feedback',
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

  Widget _buildAIInsights() {
    if (_aiAnalysis == null) return const SizedBox.shrink();

    final effectivenessScore = _aiAnalysis!['effectiveness_score'] ?? 0.0;
    final recommendations = _aiAnalysis!['recommendations'] as List? ?? [];
    final painAnalysis = _aiAnalysis!['pain_analysis'] ?? {};
    final adjustments = _aiAnalysis!['adjustments'] ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Analysis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      'Personalized insights powered by machine learning',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Effectiveness Score
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Effectiveness Score:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  '${(effectivenessScore * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: effectivenessScore > 0.7
                        ? Colors.green
                        : effectivenessScore > 0.4
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          if (painAnalysis.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.healing,
                    color: painAnalysis['is_beneficial'] == true
                        ? Colors.green
                        : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    painAnalysis['is_beneficial'] == true
                        ? 'Exercise was beneficial for pain'
                        : 'Monitor pain levels closely',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],

          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'AI Recommendations:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ...recommendations.take(3).map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rec.toString(),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
            if (recommendations.length > 3) ...[
              TextButton(
                onPressed: () => _showAllRecommendations(recommendations),
                child:
                    Text('View all ${recommendations.length} recommendations'),
              ),
            ],
          ],

          if (adjustments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune, color: Colors.purple, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Suggested Adjustments:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...adjustments.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• ${entry.key}: ${entry.value}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      )),
                ],
              ),
            ),
          ],
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
