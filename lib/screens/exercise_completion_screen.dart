// lib/screens/exercise_completion_screen.dart (FIXED - AI Analysis stays visible)
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
import 'package:personalized_rehabilitation_plans/services/exercise_adjustment_service.dart';
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
  bool _isAnalyzing = false; // NEW: Separate state for AI analysis
  bool _feedbackSubmitted = false; // NEW: Track if feedback is submitted
  Map<String, dynamic>? _aiAnalysis;
  Map<String, dynamic>? _exerciseAdjustments;
  bool _showAIInsights = false;
  bool _adjustmentsApplied = false;

  late AnimationController _celebrationController;
  late Animation<double> _celebrationAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _aiInsightsController;
  late Animation<double> _aiInsightsAnimation;
  late AnimationController _adjustmentController;
  late Animation<double> _adjustmentAnimation;

  final TextEditingController _notesController = TextEditingController();
  final RehabilitationService _rehabilitationService = RehabilitationService();
  final ExerciseAdjustmentService _adjustmentService =
      ExerciseAdjustmentService();

  @override
  void initState() {
    super.initState();
    _postPainLevel = widget.prePainLevel;

    _initializeAnimations();

    // Start animations
    _celebrationController.forward();
    _slideController.forward();
  }

  void _initializeAnimations() {
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

    _adjustmentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _adjustmentAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _adjustmentController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _slideController.dispose();
    _aiInsightsController.dispose();
    _adjustmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _isAnalyzing = true; // Start AI analysis indicator
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

      // Mark exercise as completed in the plan
      if (widget.planId != null) {
        await _markExerciseAsCompleted(
            userId, widget.planId!, widget.exercise.id);
      }

      // 🚀 REAL-TIME AI ANALYSIS & ADJUSTMENTS
      await _processRealTimeAdjustments(feedback);

      // FIXED: Mark feedback as submitted but don't navigate yet
      setState(() {
        _feedbackSubmitted = true;
        _isSubmitting = false;
        _isAnalyzing = false; // Stop analysis indicator
      });

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
                      const Text('Exercise completed successfully!',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      if (_adjustmentsApplied)
                        const Text('AI adjustments applied for next session',
                            style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // FIXED: Don't auto-navigate - let user read AI analysis first
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
          _isAnalyzing = false;
        });
      }
    }
  }

  // NEW: Separate method to finish and navigate
  void _finishAndNavigate() {
    if (mounted) {
      Navigator.of(context).pop({
        'completed': true,
        'exerciseId': widget.exercise.id,
        'feedback': {
          'painLevelBefore': widget.prePainLevel,
          'painLevelAfter': _postPainLevel,
          'difficultyRating': _difficultyRating,
          'completed': true,
        },
        'aiAnalysis': _aiAnalysis,
        'adjustmentsApplied': _adjustmentsApplied,
        'exerciseAdjustments': _exerciseAdjustments,
      });
    }
  }

  // 🤖 REAL-TIME AI ANALYSIS & EXERCISE ADJUSTMENTS
  Future<void> _processRealTimeAdjustments(ExerciseFeedback feedback) async {
    try {
      print('🤖 Starting real-time AI analysis and adjustments...');

      // Step 1: Send feedback to AI for analysis
      final analysisResult = await _sendFeedbackToBackend(feedback);

      if (analysisResult != null && widget.planId != null) {
        final userId = feedback.userId;

        // Step 2: Process real-time adjustments
        await _adjustmentService.processPostExerciseAdjustments(
          userId: userId,
          planId: widget.planId!,
          exerciseId: widget.exercise.id,
          feedbackData: _createFeedbackDataMap(feedback),
        );

        // Step 3: Check if adjustments were applied
        await _checkAndDisplayAdjustments(userId, widget.exercise.id);

        print('✅ Real-time adjustments processing complete');
      }
    } catch (e) {
      print('❌ Error in real-time adjustments: $e');
      // Continue without throwing - feedback should still be saved
    }
  }

  Map<String, dynamic> _createFeedbackDataMap(ExerciseFeedback feedback) {
    return {
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
      'completed': feedback.completed,
      'timestamp': feedback.timestamp.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>?> _sendFeedbackToBackend(
      ExerciseFeedback feedback) async {
    try {
      print('🧠 Sending feedback to AI for analysis...');

      final jsonSerializableFeedback = _createFeedbackDataMap(feedback);

      final response = await _rehabilitationService
          .analyzeFeedback(jsonSerializableFeedback);

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
          _showAIRecommendationSnackBar(recommendations);
        }

        print(
            '🎯 AI Analysis complete - Effectiveness: ${analysis['effectiveness_score']}');
        return response;
      }
    } catch (e) {
      print('❌ Error analyzing feedback with AI: $e');
      _showAIErrorMessage();
    }
    return null;
  }

  Future<void> _checkAndDisplayAdjustments(
      String userId, String exerciseId) async {
    try {
      print('🔍 Checking adjustments for user: $userId, exercise: $exerciseId');

      final adjustmentHistory =
          await _adjustmentService.getAdjustmentHistory(userId, exerciseId);

      print('📊 Found ${adjustmentHistory.length} adjustments in history');

      if (adjustmentHistory.isNotEmpty) {
        final latestAdjustment = adjustmentHistory.first;

        // Check if adjustment has valid data
        if (latestAdjustment['adjustments'] != null) {
          final adjustments =
              latestAdjustment['adjustments'] as Map<String, dynamic>;

          // Always show the most recent adjustment (remove time restriction)
          if (mounted) {
            setState(() {
              _exerciseAdjustments = adjustments;
              _adjustmentsApplied = true;
            });

            // Animate after a short delay
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _adjustmentController.forward();
              }
            });

            print('🎯 Most recent adjustments displayed');
            print('📊 Adjustment data: $adjustments');
          }
        } else {
          print('❌ No valid adjustment data found');
        }
      } else {
        print('📊 No adjustment history found for exercise: $exerciseId');
      }
    } catch (e) {
      print('❌ Error checking adjustments: $e');
    }
  }

  void _showAIRecommendationSnackBar(List<dynamic> recommendations) {
    final topRecommendation = recommendations.first.toString();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.white, size: 16),
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

  void _showAIErrorMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'AI analysis temporarily unavailable - feedback saved successfully')),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _markExerciseAsCompleted(
      String userId, String planId, String exerciseId) async {
    try {
      // Find and update the plan document
      final planQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('rehabilitation_plans')
          .where(FieldPath.documentId, isEqualTo: planId)
          .get();

      if (planQuery.docs.isNotEmpty) {
        final planDoc = planQuery.docs.first;
        final planData = planDoc.data();
        List<dynamic> exercises = List.from(planData['exercises'] ?? []);

        for (int i = 0; i < exercises.length; i++) {
          if (exercises[i]['id'] == exerciseId) {
            exercises[i]['isCompleted'] = true;
            exercises[i]['completedAt'] = DateTime.now().toIso8601String();
            break;
          }
        }

        await planDoc.reference.update({
          'exercises': exercises,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        print('✅ Exercise marked as completed: $exerciseId');
      } else {
        // Try alternative collection structure
        await _markExerciseInAlternativeCollection(planId, exerciseId);
      }
    } catch (e) {
      print('❌ Error marking exercise as completed: $e');
    }
  }

  Future<void> _markExerciseInAlternativeCollection(
      String planId, String exerciseId) async {
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
          exercises[i]['completedAt'] = DateTime.now().toIso8601String();
          break;
        }
      }

      await alternativePlanDoc.reference.update({
        'exercises': exercises,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print(
          '✅ Exercise marked as completed in alternative collection: $exerciseId');
    }
  }

  Future<void> _updateProgressLog(ExerciseFeedback feedback) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      if (userId == null) return;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final existingLogs = await FirebaseFirestore.instance
          .collection('progressLogs')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThan: endOfDay)
          .get();

      final exerciseLogData = {
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
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (existingLogs.docs.isNotEmpty) {
        // Update existing log
        final logDoc = existingLogs.docs.first;
        final logData = logDoc.data();
        final exerciseLogs =
            List<Map<String, dynamic>>.from(logData['exerciseLogs'] ?? []);

        exerciseLogs.add(exerciseLogData);

        await logDoc.reference.update({
          'exerciseLogs': exerciseLogs,
          'lastUpdated': FieldValue.serverTimestamp(),
          'overallRating': _calculateOverallRating(),
          'adherencePercentage': _calculateAdherence(),
        });
      } else {
        // Create new progress log
        await FirebaseFirestore.instance.collection('progressLogs').add({
          'userId': userId,
          'planId': widget.planId,
          'date': FieldValue.serverTimestamp(),
          'exerciseLogs': [exerciseLogData],
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
    int rating = 3;
    if (_postPainLevel < widget.prePainLevel)
      rating += 1;
    else if (_postPainLevel > widget.prePainLevel) rating -= 1;

    if (_difficultyRating == 'perfect')
      rating += 1;
    else if (_difficultyRating == 'hard') rating -= 1;

    return rating.clamp(1, 5);
  }

  int _calculateAdherence() {
    final setsCompletion = (widget.completedSets / widget.exercise.sets) * 100;
    final repsCompletion = (widget.completedReps / widget.exercise.reps) * 100;
    return ((setsCompletion + repsCompletion) / 2).round().clamp(0, 100);
  }

  double _calculateSessionSatisfaction() {
    double satisfaction = 3.0;
    final painChange = _postPainLevel - widget.prePainLevel;

    if (painChange < 0)
      satisfaction += 1.0;
    else if (painChange > 0) satisfaction -= 0.5;

    if (_difficultyRating == 'perfect')
      satisfaction += 0.5;
    else if (_difficultyRating == 'hard') satisfaction -= 0.5;

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
          onPressed: () => _showExitConfirmation(),
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
              _buildCelebrationHeader(),
              const SizedBox(height: 24),

              // Exercise summary
              _buildExerciseSummary(),
              const SizedBox(height: 24),

              // Pain level feedback
              PainFeedbackWidget(
                initialPainLevel: _postPainLevel,
                title: 'How do you feel now?',
                subtitle: 'Rate your pain level after the exercise',
                onPainLevelChanged: (level) =>
                    setState(() => _postPainLevel = level),
                showComparison: true,
                previousPainLevel: widget.prePainLevel,
              ),
              const SizedBox(height: 24),

              // Difficulty feedback
              ExerciseDifficultyWidget(
                initialDifficulty: _difficultyRating,
                onDifficultyChanged: (difficulty) =>
                    setState(() => _difficultyRating = difficulty),
                showRecommendations: true,
              ),
              const SizedBox(height: 24),

              // AI Analysis loading indicator
              if (_isAnalyzing && !_showAIInsights) ...[
                _buildAnalysisLoadingIndicator(),
                const SizedBox(height: 24),
              ],

              // AI Insights Section
              if (_showAIInsights && _aiAnalysis != null) ...[
                AnimatedBuilder(
                  animation: _aiInsightsAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _aiInsightsAnimation.value,
                    child: Opacity(
                      opacity: _aiInsightsAnimation.value,
                      child: _buildAIInsights(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 🎯 REAL-TIME ADJUSTMENTS DISPLAY
              if (_adjustmentsApplied && _exerciseAdjustments != null) ...[
                AnimatedBuilder(
                  animation: _adjustmentAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _adjustmentAnimation.value,
                    child: Opacity(
                      opacity: _adjustmentAnimation.value,
                      child: _buildAdjustmentsDisplay(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Additional notes (only show if feedback not submitted)
              if (!_feedbackSubmitted) ...[
                _buildNotesSection(),
                const SizedBox(height: 32),
              ],

              // FIXED: Dynamic button based on state
              _buildActionButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Loading indicator for AI analysis
  Widget _buildAnalysisLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.cyan.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Analysis in Progress...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      'Analyzing your feedback and generating insights',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // FIXED: Dynamic action button
  Widget _buildActionButton() {
    if (!_feedbackSubmitted) {
      // Show submit feedback button
      return CustomButton(
        text: _isSubmitting ? 'Processing AI Analysis...' : 'Submit Feedback',
        onPressed: _isSubmitting ? null : _submitFeedback,
        width: double.infinity,
        isLoading: _isSubmitting,
      );
    } else {
      // Show finish button after feedback is submitted
      return Column(
        children: [
          // Success message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Feedback Submitted Successfully!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Review your AI insights above and finish when ready',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Finish & Return to Progress',
            onPressed: _finishAndNavigate,
            width: double.infinity,
            backgroundColor: AppTheme.primaryBlue,
          ),
        ],
      );
    }
  }

  Widget _buildCelebrationHeader() {
    return AnimatedBuilder(
      animation: _celebrationAnimation,
      builder: (context, child) => Transform.scale(
        scale: _celebrationAnimation.value,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
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
              const Icon(Icons.celebration, color: Colors.white, size: 48),
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
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
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
              Icon(Icons.summarize, color: AppTheme.primaryBlue, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Exercise Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  // 🎯 REAL-TIME ADJUSTMENTS DISPLAY
  Widget _buildAdjustmentsDisplay() {
    if (_exerciseAdjustments == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.indigo.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_fix_high,
                    color: Colors.purple, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Adjustments Applied',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    Text(
                      'Your next session has been automatically optimized',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'APPLIED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Adjustment Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What\'s Changed for Next Session:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildAdjustmentItems(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'These adjustments are based on your feedback and pain response patterns',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAdjustmentItems() {
    List<Widget> items = [];

    if (_exerciseAdjustments!.containsKey('sets_multiplier')) {
      final multiplier = _exerciseAdjustments!['sets_multiplier'] as double;
      final currentSets = widget.exercise.sets;
      final newSets = (currentSets * multiplier).round().clamp(1, 6);

      items.add(_buildAdjustmentItem(
        'Sets',
        '$currentSets → $newSets',
        multiplier > 1.0 ? Icons.trending_up : Icons.trending_down,
        multiplier > 1.0 ? Colors.green : Colors.orange,
        _getAdjustmentReason('sets', multiplier),
      ));
    }

    if (_exerciseAdjustments!.containsKey('reps_multiplier')) {
      final multiplier = _exerciseAdjustments!['reps_multiplier'] as double;
      final currentReps = widget.exercise.reps;
      final newReps = (currentReps * multiplier).round().clamp(3, 20);

      items.add(_buildAdjustmentItem(
        'Reps',
        '$currentReps → $newReps',
        multiplier > 1.0 ? Icons.trending_up : Icons.trending_down,
        multiplier > 1.0 ? Colors.green : Colors.orange,
        _getAdjustmentReason('reps', multiplier),
      ));
    }

    if (_exerciseAdjustments!.containsKey('intensity_multiplier')) {
      final multiplier =
          _exerciseAdjustments!['intensity_multiplier'] as double;
      final currentDuration = widget.exercise.durationSeconds;
      final newDuration = (currentDuration * multiplier).round().clamp(15, 120);

      items.add(_buildAdjustmentItem(
        'Duration',
        '${currentDuration}s → ${newDuration}s',
        multiplier > 1.0 ? Icons.trending_up : Icons.trending_down,
        multiplier > 1.0 ? Colors.green : Colors.orange,
        _getAdjustmentReason('intensity', multiplier),
      ));
    }

    if (_exerciseAdjustments!.containsKey('difficulty_level')) {
      final newDifficulty = _exerciseAdjustments!['difficulty_level'] as String;
      items.add(_buildAdjustmentItem(
        'Difficulty',
        '${widget.exercise.difficultyLevel} → $newDifficulty',
        Icons.star,
        Colors.blue,
        'Adjusted based on your performance',
      ));
    }

    return items;
  }

  Widget _buildAdjustmentItem(
      String label, String change, IconData icon, Color color, String reason) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$label: ',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      change,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getAdjustmentReason(String type, double multiplier) {
    if (multiplier > 1.1) {
      switch (type) {
        case 'sets':
          return 'Exercise seems too easy - increasing challenge';
        case 'reps':
          return 'Good performance - adding more repetitions';
        case 'intensity':
          return 'Pain decreasing - safe to increase intensity';
        default:
          return 'Progressing to next level';
      }
    } else if (multiplier < 0.9) {
      switch (type) {
        case 'sets':
          return 'Reducing to prevent overexertion';
        case 'reps':
          return 'Too challenging - making more manageable';
        case 'intensity':
          return 'Pain management - reducing intensity';
        default:
          return 'Adjusting for comfort';
      }
    }
    return 'Fine-tuning based on feedback';
  }

  Widget _buildAIInsights() {
    if (_aiAnalysis == null) return const SizedBox.shrink();

    final effectivenessScore = _aiAnalysis!['effectiveness_score'] ?? 0.0;
    final recommendations = _aiAnalysis!['recommendations'] as List? ?? [];
    final painAnalysis = _aiAnalysis!['pain_analysis'] ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.cyan.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
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
                child:
                    const Icon(Icons.psychology, color: Colors.blue, size: 24),
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
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                        child: Text(rec.toString(),
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                )),
            if (recommendations.length > 3)
              TextButton(
                onPressed: () => _showAllRecommendations(recommendations),
                child:
                    Text('View all ${recommendations.length} recommendations'),
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
              Icon(Icons.note_add, color: AppTheme.primaryBlue, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Additional Notes (Optional)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (value) => setState(() => _additionalNotes = value),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    if (_feedbackSubmitted) {
      // If feedback is already submitted, just ask for confirmation
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Return to Progress'),
          content: const Text(
              'Are you sure you want to return? Your feedback has been saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Stay Here'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _finishAndNavigate();
              },
              child: const Text('Return'),
            ),
          ],
        ),
      );
    } else {
      // If feedback not submitted, warn about losing data
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
                Navigator.pop(context);
                Navigator.pop(context, {'completed': false});
              },
              child: const Text('Skip Feedback'),
            ),
          ],
        ),
      );
    }
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
