// lib/services/exercise_adjustment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/services/rehabilitation_service.dart';

class ExerciseAdjustmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RehabilitationService _rehabilitationService = RehabilitationService();

  /// Apply AI-recommended adjustments to exercises in real-time
  Future<void> applyAIAdjustments({
    required String userId,
    required String planId,
    required String exerciseId,
    required Map<String, dynamic> aiAdjustments,
  }) async {
    try {
      print('🔧 Applying AI adjustments to exercise: $exerciseId');
      print('📊 Adjustments: $aiAdjustments');

      // Get current plan
      final planDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('rehabilitation_plans')
          .doc(planId)
          .get();

      if (!planDoc.exists) {
        print('❌ Plan not found: $planId');
        return;
      }

      final planData = planDoc.data()!;
      List<dynamic> exercises = List.from(planData['exercises'] ?? []);

      // Find and update the specific exercise
      bool exerciseUpdated = false;
      for (int i = 0; i < exercises.length; i++) {
        if (exercises[i]['id'] == exerciseId) {
          exerciseUpdated = true;
          final currentExercise = exercises[i];

          // Apply adjustments based on AI recommendations
          final adjustedExercise =
              _applyAdjustmentsToExercise(currentExercise, aiAdjustments);

          exercises[i] = adjustedExercise;

          print('✅ Updated exercise: ${adjustedExercise['name']}');
          print(
              '📈 New parameters: Sets: ${adjustedExercise['sets']}, Reps: ${adjustedExercise['reps']}');
          break;
        }
      }

      if (exerciseUpdated) {
        // Update the plan in Firestore
        await planDoc.reference.update({
          'exercises': exercises,
          'lastAIAdjustment': FieldValue.serverTimestamp(),
          'adjustmentReason': _generateAdjustmentReason(aiAdjustments),
        });

        // Log the adjustment for analytics
        await _logAdjustment(userId, exerciseId, aiAdjustments);

        print('🎯 AI adjustments applied successfully!');
      }
    } catch (e) {
      print('❌ Error applying AI adjustments: $e');
    }
  }

  /// Apply adjustments to a single exercise based on AI recommendations
  Map<String, dynamic> _applyAdjustmentsToExercise(
    Map<String, dynamic> exercise,
    Map<String, dynamic> adjustments,
  ) {
    final adjustedExercise = Map<String, dynamic>.from(exercise);

    final currentSets = exercise['sets'] ?? 3;
    final currentReps = exercise['reps'] ?? 10;
    final currentDuration = exercise['durationSeconds'] ?? 30;

    // Apply sets multiplier
    if (adjustments.containsKey('sets_multiplier')) {
      final multiplier = adjustments['sets_multiplier'] as double;
      final newSets = (currentSets * multiplier).round().clamp(1, 6);
      adjustedExercise['sets'] = newSets;
      print('🔄 Sets: $currentSets → $newSets (${multiplier}x)');
    }

    // Apply reps multiplier
    if (adjustments.containsKey('reps_multiplier')) {
      final multiplier = adjustments['reps_multiplier'] as double;
      final newReps = (currentReps * multiplier).round().clamp(3, 20);
      adjustedExercise['reps'] = newReps;
      print('🔄 Reps: $currentReps → $newReps (${multiplier}x)');
    }

    // Apply intensity multiplier (affects duration)
    if (adjustments.containsKey('intensity_multiplier')) {
      final multiplier = adjustments['intensity_multiplier'] as double;
      final newDuration = (currentDuration * multiplier).round().clamp(15, 120);
      adjustedExercise['durationSeconds'] = newDuration;
      print(
          '🔄 Duration: ${currentDuration}s → ${newDuration}s (${multiplier}x)');
    }

    // Update difficulty level if suggested
    if (adjustments.containsKey('difficulty_level')) {
      final newDifficulty = adjustments['difficulty_level'] as String;
      adjustedExercise['difficultyLevel'] = newDifficulty;
      print('🔄 Difficulty: ${exercise['difficultyLevel']} → $newDifficulty');
    }

    // Add adjustment metadata
    adjustedExercise['lastAdjusted'] = DateTime.now().toIso8601String();
    adjustedExercise['adjustmentSource'] = 'ai_feedback';

    return adjustedExercise;
  }

  /// Generate human-readable reason for the adjustment
  String _generateAdjustmentReason(Map<String, dynamic> adjustments) {
    List<String> reasons = [];

    if (adjustments.containsKey('sets_multiplier')) {
      final multiplier = adjustments['sets_multiplier'] as double;
      if (multiplier > 1.0) {
        reasons.add('Increased sets due to good performance');
      } else if (multiplier < 1.0) {
        reasons.add('Reduced sets to prevent overexertion');
      }
    }

    if (adjustments.containsKey('reps_multiplier')) {
      final multiplier = adjustments['reps_multiplier'] as double;
      if (multiplier > 1.0) {
        reasons.add('Increased reps - exercise seems too easy');
      } else if (multiplier < 1.0) {
        reasons.add('Reduced reps due to difficulty');
      }
    }

    if (adjustments.containsKey('intensity_multiplier')) {
      final multiplier = adjustments['intensity_multiplier'] as double;
      if (multiplier > 1.0) {
        reasons.add('Increased intensity - pain reduction observed');
      } else if (multiplier < 1.0) {
        reasons.add('Reduced intensity due to pain increase');
      }
    }

    return reasons.join('; ');
  }

  /// Log adjustment for analytics and tracking
  Future<void> _logAdjustment(
    String userId,
    String exerciseId,
    Map<String, dynamic> adjustments,
  ) async {
    try {
      await _firestore.collection('exerciseAdjustments').add({
        'userId': userId,
        'exerciseId': exerciseId,
        'adjustments': adjustments,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'ai_feedback_analysis',
      });
    } catch (e) {
      print('Error logging adjustment: $e');
    }
  }

  /// Get adjustment history for an exercise
  Future<List<Map<String, dynamic>>> getAdjustmentHistory(
    String userId,
    String exerciseId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('exerciseAdjustments')
          .where('userId', isEqualTo: userId)
          .where('exerciseId', isEqualTo: exerciseId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('Error getting adjustment history: $e');
      return [];
    }
  }

  /// Check if an exercise needs adjustment based on recent feedback
  Future<bool> shouldAdjustExercise(
    String userId,
    String exerciseId,
    int feedbackCount,
  ) async {
    try {
      // Get recent feedback for this exercise
      final feedbackSnapshot = await _firestore
          .collection('exerciseFeedbacks')
          .where('userId', isEqualTo: userId)
          .where('exerciseId', isEqualTo: exerciseId)
          .orderBy('timestamp', descending: true)
          .limit(feedbackCount)
          .get();

      if (feedbackSnapshot.docs.length < 2) {
        return false; // Need at least 2 feedback entries
      }

      // Analyze if adjustment is needed based on patterns
      final feedbacks = feedbackSnapshot.docs.map((doc) => doc.data()).toList();

      // Check for consistent difficulty patterns
      final difficultyRatings =
          feedbacks.map((f) => f['difficultyRating']).toList();
      final hardCount = difficultyRatings.where((d) => d == 'hard').length;
      final easyCount = difficultyRatings.where((d) => d == 'easy').length;

      // Adjust if 70% or more sessions are consistently hard or easy
      final threshold = feedbacks.length * 0.7;

      return hardCount >= threshold || easyCount >= threshold;
    } catch (e) {
      print('Error checking if exercise needs adjustment: $e');
      return false;
    }
  }

  /// Apply real-time adjustments after exercise completion
  Future<void> processPostExerciseAdjustments({
    required String userId,
    required String planId,
    required String exerciseId,
    required Map<String, dynamic> feedbackData,
  }) async {
    try {
      print('🤖 Processing post-exercise adjustments...');

      // Send feedback to AI for analysis
      final analysisResult =
          await _rehabilitationService.analyzeFeedback(feedbackData);

      if (analysisResult['analysis']?['adjustments'] != null) {
        final adjustments =
            analysisResult['analysis']['adjustments'] as Map<String, dynamic>;

        // Apply adjustments if they're significant enough
        if (_shouldApplyAdjustments(adjustments)) {
          await applyAIAdjustments(
            userId: userId,
            planId: planId,
            exerciseId: exerciseId,
            aiAdjustments: adjustments,
          );

          return; // Adjustments applied
        }
      }

      // Check if exercise needs adjustment based on pattern analysis
      final needsAdjustment = await shouldAdjustExercise(userId, exerciseId, 3);

      if (needsAdjustment) {
        // Get historical feedback for optimization
        final feedbackHistory =
            await _getRecentFeedbackHistory(userId, exerciseId);

        // Get optimization recommendations
        final optimizationResult = await _rehabilitationService.optimizePlan(
          userId: userId,
          exerciseId: exerciseId,
          feedbackHistory: feedbackHistory,
        );

        if (optimizationResult['optimized_parameters'] != null) {
          final params = optimizationResult['optimized_parameters'];
          await _applyOptimizedParameters(userId, planId, exerciseId, params);
        }
      }

      print('✅ Post-exercise adjustment processing complete');
    } catch (e) {
      print('❌ Error in post-exercise adjustments: $e');
    }
  }

  /// Check if adjustments are significant enough to apply
  bool _shouldApplyAdjustments(Map<String, dynamic> adjustments) {
    // Apply if any multiplier is significantly different from 1.0
    for (final entry in adjustments.entries) {
      if (entry.key.contains('multiplier')) {
        final value = entry.value as double;
        if ((value - 1.0).abs() > 0.1) {
          // 10% threshold
          return true;
        }
      }
    }
    return false;
  }

  /// Get recent feedback history for an exercise
  Future<List<Map<String, dynamic>>> _getRecentFeedbackHistory(
    String userId,
    String exerciseId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('exerciseFeedbacks')
          .where('userId', isEqualTo: userId)
          .where('exerciseId', isEqualTo: exerciseId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting feedback history: $e');
      return [];
    }
  }

  /// Apply optimized parameters from ML recommendations
  Future<void> _applyOptimizedParameters(
    String userId,
    String planId,
    String exerciseId,
    Map<String, dynamic> optimizedParams,
  ) async {
    try {
      print('🎯 Applying ML-optimized parameters...');

      final adjustments = <String, dynamic>{};

      if (optimizedParams.containsKey('optimized_sets')) {
        // Calculate multiplier from current vs optimized values
        // This would require getting current values first
        adjustments['sets_multiplier'] = 1.0; // Placeholder
      }

      if (optimizedParams.containsKey('optimized_reps')) {
        adjustments['reps_multiplier'] = 1.0; // Placeholder
      }

      await applyAIAdjustments(
        userId: userId,
        planId: planId,
        exerciseId: exerciseId,
        aiAdjustments: adjustments,
      );

      print('✅ ML-optimized parameters applied');
    } catch (e) {
      print('❌ Error applying optimized parameters: $e');
    }
  }
}
