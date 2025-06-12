// lib/services/exercise_adjustment_service.dart (FIXED VERSION)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/services/rehabilitation_service.dart';

class ExerciseAdjustmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RehabilitationService _rehabilitationService = RehabilitationService();

  // 🚀 MAIN ENTRY POINT: Process real-time adjustments after exercise completion
  Future<void> processPostExerciseAdjustments({
    required String userId,
    required String planId,
    required String exerciseId,
    required Map<String, dynamic> feedbackData,
  }) async {
    try {
      print('🤖 Processing post-exercise adjustments...');
      print('📊 Exercise: ${feedbackData['exerciseName']}');
      print(
          '💊 Pain change: ${feedbackData['painLevelAfter']} - ${feedbackData['painLevelBefore']}');
      print('🎯 Difficulty: ${feedbackData['difficultyRating']}');

      // Step 1: Send feedback to AI for immediate analysis
      final analysisResult =
          await _rehabilitationService.analyzeFeedback(feedbackData);

      bool adjustmentsApplied = false;

      // Step 2: Apply immediate AI adjustments if available
      if (analysisResult['analysis']?['adjustments'] != null) {
        final adjustments =
            analysisResult['analysis']['adjustments'] as Map<String, dynamic>;

        if (_shouldApplyAdjustments(adjustments)) {
          await applyAIAdjustments(
            userId: userId,
            planId: planId,
            exerciseId: exerciseId,
            aiAdjustments: adjustments,
          );
          adjustmentsApplied = true;
          print('✅ Immediate AI adjustments applied');
        }
      }

      // Step 3: Check for pattern-based adjustments if no immediate adjustments
      if (!adjustmentsApplied) {
        final needsPatternAdjustment =
            await shouldAdjustExercise(userId, exerciseId, 3);

        if (needsPatternAdjustment) {
          await _processPatternBasedAdjustments(userId, planId, exerciseId);
          print('✅ Pattern-based adjustments applied');
        }
      }

      print('🎯 Post-exercise adjustment processing complete');
    } catch (e) {
      print('❌ Error in post-exercise adjustments: $e');
      // Continue without throwing - adjustments are optional
    }
  }

  // 🔧 Apply AI-recommended adjustments to exercises in real-time
  Future<void> applyAIAdjustments({
    required String userId,
    required String planId,
    required String exerciseId,
    required Map<String, dynamic> aiAdjustments,
  }) async {
    try {
      print('🔧 Applying AI adjustments to exercise: $exerciseId');
      print('📊 Adjustments: $aiAdjustments');

      // Get current plan from user's collection first
      DocumentSnapshot? planDoc = await _getPlanDocument(userId, planId);

      if (planDoc == null || !planDoc.exists) {
        print('❌ Plan not found: $planId');
        return;
      }

      final planData = planDoc.data() as Map<String, dynamic>;
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
          'adjustmentVersion': FieldValue.increment(1),
        });

        // Log the adjustment for analytics
        await _logAdjustment(userId, exerciseId, aiAdjustments, 'ai_immediate');

        print('🎯 AI adjustments applied successfully!');
      }
    } catch (e) {
      print('❌ Error applying AI adjustments: $e');
    }
  }

  // 📊 Process pattern-based adjustments when no immediate AI adjustments available
  Future<void> _processPatternBasedAdjustments(
      String userId, String planId, String exerciseId) async {
    try {
      print('📈 Processing pattern-based adjustments...');

      // Get recent feedback history for this exercise
      final feedbackHistory =
          await _getRecentFeedbackHistory(userId, exerciseId, 5);

      if (feedbackHistory.length < 3) {
        print('📊 Insufficient data for pattern analysis');
        return;
      }

      // Analyze patterns
      final adjustments = _analyzePatterns(feedbackHistory);

      if (adjustments.isNotEmpty) {
        await applyAIAdjustments(
          userId: userId,
          planId: planId,
          exerciseId: exerciseId,
          aiAdjustments: adjustments,
        );

        await _logAdjustment(
            userId, exerciseId, adjustments, 'pattern_analysis');
        print('🎯 Pattern-based adjustments applied');
      }
    } catch (e) {
      print('❌ Error in pattern-based adjustments: $e');
    }
  }

  // 📱 Get plan document from user's collection or main collection
  Future<DocumentSnapshot?> _getPlanDocument(
      String userId, String planId) async {
    try {
      // Try user's collection first
      final userPlanQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('rehabilitation_plans')
          .where(FieldPath.documentId, isEqualTo: planId)
          .get();

      if (userPlanQuery.docs.isNotEmpty) {
        return userPlanQuery.docs.first;
      }

      // Try main collection
      final mainPlanDoc =
          await _firestore.collection('rehabilitation_plans').doc(planId).get();

      return mainPlanDoc;
    } catch (e) {
      print('❌ Error getting plan document: $e');
      return null;
    }
  }

  // 🔄 Apply adjustments to a single exercise based on AI recommendations
  Map<String, dynamic> _applyAdjustmentsToExercise(
    Map<String, dynamic> exercise,
    Map<String, dynamic> adjustments,
  ) {
    final adjustedExercise = Map<String, dynamic>.from(exercise);

    final currentSets = exercise['sets'] ?? 3;
    final currentReps = exercise['reps'] ?? 10;
    final currentDuration = exercise['durationSeconds'] ?? 30;

    // Apply sets multiplier with smart constraints
    if (adjustments.containsKey('sets_multiplier')) {
      final multiplier = adjustments['sets_multiplier'] as double;
      final newSets = _calculateNewSets(currentSets, multiplier);
      adjustedExercise['sets'] = newSets;
      print(
          '🔄 Sets: $currentSets → $newSets (${multiplier.toStringAsFixed(2)}x)');
    }

    // Apply reps multiplier with smart constraints
    if (adjustments.containsKey('reps_multiplier')) {
      final multiplier = adjustments['reps_multiplier'] as double;
      final newReps = _calculateNewReps(currentReps, multiplier);
      adjustedExercise['reps'] = newReps;
      print(
          '🔄 Reps: $currentReps → $newReps (${multiplier.toStringAsFixed(2)}x)');
    }

    // Apply intensity multiplier (affects duration)
    if (adjustments.containsKey('intensity_multiplier')) {
      final multiplier = adjustments['intensity_multiplier'] as double;
      final newDuration = _calculateNewDuration(currentDuration, multiplier);
      adjustedExercise['durationSeconds'] = newDuration;
      print(
          '🔄 Duration: ${currentDuration}s → ${newDuration}s (${multiplier.toStringAsFixed(2)}x)');
    }

    // Apply rest time multiplier
    if (adjustments.containsKey('rest_time_multiplier')) {
      final multiplier = adjustments['rest_time_multiplier'] as double;
      final currentRestTime = exercise['restTimeSeconds'] ?? 30;
      final newRestTime = (currentRestTime * multiplier).round().clamp(15, 120);
      adjustedExercise['restTimeSeconds'] = newRestTime;
      print(
          '🔄 Rest Time: ${currentRestTime}s → ${newRestTime}s (${multiplier.toStringAsFixed(2)}x)');
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
    adjustedExercise['adjustmentCount'] =
        (exercise['adjustmentCount'] ?? 0) + 1;

    return adjustedExercise;
  }

  // 🧮 Smart calculation methods with exercise-specific constraints
  int _calculateNewSets(int currentSets, double multiplier) {
    final rawNewSets = (currentSets * multiplier).round();

    // Smart constraints based on current level
    if (currentSets <= 2) {
      return rawNewSets.clamp(1, 4); // Low volume exercises
    } else if (currentSets <= 4) {
      return rawNewSets.clamp(2, 6); // Medium volume exercises
    } else {
      return rawNewSets.clamp(3, 8); // High volume exercises
    }
  }

  int _calculateNewReps(int currentReps, double multiplier) {
    final rawNewReps = (currentReps * multiplier).round();

    // Smart constraints based on current level
    if (currentReps <= 5) {
      return rawNewReps.clamp(3, 8); // Strength-focused exercises
    } else if (currentReps <= 12) {
      return rawNewReps.clamp(5, 20); // Moderate rep exercises
    } else {
      return rawNewReps.clamp(10, 30); // Endurance exercises
    }
  }

  int _calculateNewDuration(int currentDuration, double multiplier) {
    final rawNewDuration = (currentDuration * multiplier).round();

    // Smart constraints based on exercise type
    if (currentDuration <= 30) {
      return rawNewDuration.clamp(15, 60); // Short exercises
    } else if (currentDuration <= 90) {
      return rawNewDuration.clamp(30, 150); // Medium exercises
    } else {
      return rawNewDuration.clamp(60, 300); // Long exercises
    }
  }

  // 📈 Analyze patterns in feedback history
  Map<String, dynamic> _analyzePatterns(
      List<Map<String, dynamic>> feedbackHistory) {
    Map<String, dynamic> adjustments = {};

    // Analyze difficulty patterns
    final difficultyRatings =
        feedbackHistory.map((f) => f['difficultyRating'] as String).toList();
    final easyCount = difficultyRatings.where((d) => d == 'easy').length;
    final hardCount = difficultyRatings.where((d) => d == 'hard').length;
    final totalCount = difficultyRatings.length;

    // If 70% of recent sessions are "easy", increase difficulty
    if (easyCount >= (totalCount * 0.7)) {
      adjustments['sets_multiplier'] = 1.2;
      adjustments['reps_multiplier'] = 1.15;
      print('📊 Pattern detected: Exercise too easy - increasing difficulty');
    }
    // If 60% of recent sessions are "hard", decrease difficulty
    else if (hardCount >= (totalCount * 0.6)) {
      adjustments['sets_multiplier'] = 0.85;
      adjustments['reps_multiplier'] = 0.9;
      print('📊 Pattern detected: Exercise too hard - decreasing difficulty');
    }

    // Analyze pain patterns
    final painChanges = feedbackHistory.map((f) {
      final painBefore = f['painLevelBefore'] ?? 5;
      final painAfter = f['painLevelAfter'] ?? 5;
      return painAfter - painBefore;
    }).toList();

    final averagePainChange =
        painChanges.reduce((a, b) => a + b) / painChanges.length;

    // If pain is consistently increasing, reduce intensity
    if (averagePainChange > 1.0) {
      adjustments['intensity_multiplier'] = 0.8;
      adjustments['rest_time_multiplier'] = 1.3;
      print('📊 Pattern detected: Pain increasing - reducing intensity');
    }
    // If pain is consistently decreasing, can increase intensity slightly
    else if (averagePainChange < -1.0) {
      adjustments['intensity_multiplier'] = 1.1;
      print(
          '📊 Pattern detected: Pain decreasing - safe to increase intensity');
    }

    // Analyze completion patterns
    final completionRates = feedbackHistory.map((f) {
      final completedSets = f['completedSets'] ?? 0;
      final targetSets = f['targetSets'] ?? 1;
      final completedReps = f['completedReps'] ?? 0;
      final targetReps = f['targetReps'] ?? 1;

      final setsCompletion = completedSets / targetSets;
      final repsCompletion = completedReps / targetReps;
      return (setsCompletion + repsCompletion) / 2;
    }).toList();

    final averageCompletion =
        completionRates.reduce((a, b) => a + b) / completionRates.length;

    // If completion rate is consistently low, reduce volume
    if (averageCompletion < 0.7) {
      adjustments['sets_multiplier'] = 0.9;
      adjustments['reps_multiplier'] = 0.85;
      print('📊 Pattern detected: Low completion rate - reducing volume');
    }
    // If completion rate is consistently high, can increase volume
    else if (averageCompletion > 0.95) {
      adjustments['sets_multiplier'] = 1.1;
      adjustments['reps_multiplier'] = 1.05;
      print('📊 Pattern detected: High completion rate - increasing volume');
    }

    return adjustments;
  }

  // 🔍 Check if exercise needs adjustment based on recent feedback patterns
  Future<bool> shouldAdjustExercise(
      String userId, String exerciseId, int feedbackCount) async {
    try {
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

      final feedbacks = feedbackSnapshot.docs.map((doc) => doc.data()).toList();

      // Check for consistent difficulty patterns
      final difficultyRatings =
          feedbacks.map((f) => f['difficultyRating']).toList();
      final hardCount = difficultyRatings.where((d) => d == 'hard').length;
      final easyCount = difficultyRatings.where((d) => d == 'easy').length;

      // Adjust if 70% or more sessions are consistently hard or easy
      final threshold = feedbacks.length * 0.7;
      final needsAdjustment = hardCount >= threshold || easyCount >= threshold;

      if (needsAdjustment) {
        print(
            '🎯 Exercise needs adjustment: $exerciseId (Hard: $hardCount, Easy: $easyCount)');
      }

      return needsAdjustment;
    } catch (e) {
      print('❌ Error checking if exercise needs adjustment: $e');
      return false;
    }
  }

  // 📚 Get recent feedback history for an exercise
  Future<List<Map<String, dynamic>>> _getRecentFeedbackHistory(
    String userId,
    String exerciseId,
    int limit,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('exerciseFeedbacks')
          .where('userId', isEqualTo: userId)
          .where('exerciseId', isEqualTo: exerciseId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('❌ Error getting feedback history: $e');
      return [];
    }
  }

  // 📝 Generate human-readable reason for the adjustment
  String _generateAdjustmentReason(Map<String, dynamic> adjustments) {
    List<String> reasons = [];

    if (adjustments.containsKey('sets_multiplier')) {
      final multiplier = adjustments['sets_multiplier'] as double;
      if (multiplier > 1.1) {
        reasons.add('Increased sets due to good performance');
      } else if (multiplier < 0.9) {
        reasons.add('Reduced sets to prevent overexertion');
      }
    }

    if (adjustments.containsKey('reps_multiplier')) {
      final multiplier = adjustments['reps_multiplier'] as double;
      if (multiplier > 1.1) {
        reasons.add('Increased reps - exercise seems too easy');
      } else if (multiplier < 0.9) {
        reasons.add('Reduced reps due to difficulty');
      }
    }

    if (adjustments.containsKey('intensity_multiplier')) {
      final multiplier = adjustments['intensity_multiplier'] as double;
      if (multiplier > 1.1) {
        reasons.add('Increased intensity - pain reduction observed');
      } else if (multiplier < 0.9) {
        reasons.add('Reduced intensity due to pain increase');
      }
    }

    if (adjustments.containsKey('rest_time_multiplier')) {
      final multiplier = adjustments['rest_time_multiplier'] as double;
      if (multiplier > 1.1) {
        reasons.add('Extended rest time for better recovery');
      } else if (multiplier < 0.9) {
        reasons.add('Reduced rest time - good progress');
      }
    }

    if (adjustments.containsKey('difficulty_level')) {
      final newDifficulty = adjustments['difficulty_level'] as String;
      reasons.add('Difficulty level changed to $newDifficulty');
    }

    return reasons.isEmpty
        ? 'AI-optimized based on feedback'
        : reasons.join('; ');
  }

  // 📊 Log adjustment for analytics and tracking
  Future<void> _logAdjustment(
    String userId,
    String exerciseId,
    Map<String, dynamic> adjustments,
    String adjustmentType,
  ) async {
    try {
      await _firestore.collection('exerciseAdjustments').add({
        'userId': userId,
        'exerciseId': exerciseId,
        'adjustments': adjustments,
        'adjustmentType': adjustmentType,
        'reason': _generateAdjustmentReason(adjustments),
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'ai_feedback_analysis',
      });

      print('📝 Adjustment logged: $adjustmentType for $exerciseId');
    } catch (e) {
      print('❌ Error logging adjustment: $e');
    }
  }

  // 🔍 Get adjustment history for an exercise - FIXED VERSION
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

      return snapshot.docs.map((doc) {
        final data = doc.data();
        // FIXED: Safe timestamp handling
        final timestamp = data['timestamp'];

        return {
          'id': doc.id,
          ...data,
          // Convert Timestamp to DateTime safely
          'timestamp': timestamp is Timestamp
              ? timestamp.toDate()
              : (timestamp is DateTime ? timestamp : DateTime.now()),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting adjustment history: $e');
      return [];
    }
  }

  // ✅ Check if adjustments are significant enough to apply
  bool _shouldApplyAdjustments(Map<String, dynamic> adjustments) {
    const double threshold = 0.1; // 10% change threshold

    for (final entry in adjustments.entries) {
      if (entry.key.contains('multiplier')) {
        final value = entry.value as double;
        if ((value - 1.0).abs() > threshold) {
          print('🎯 Significant adjustment detected: ${entry.key} = $value');
          return true;
        }
      }

      // Always apply difficulty level changes
      if (entry.key == 'difficulty_level') {
        print('🎯 Difficulty level change detected');
        return true;
      }
    }

    print('📊 No significant adjustments needed');
    return false;
  }

  // 📈 Get comprehensive adjustment analytics for a user
  Future<Map<String, dynamic>> getAdjustmentAnalytics(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('exerciseAdjustments')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final adjustments = snapshot.docs.map((doc) => doc.data()).toList();

      if (adjustments.isEmpty) {
        return {
          'totalAdjustments': 0,
          'adjustmentTypes': {},
          'mostAdjustedExercises': [],
          'averageEffectiveness': 0.0,
        };
      }

      // Analyze adjustment types
      Map<String, int> adjustmentTypes = {};
      Map<String, int> exerciseAdjustmentCounts = {};

      for (final adjustment in adjustments) {
        final type = adjustment['adjustmentType'] as String? ?? 'unknown';
        adjustmentTypes[type] = (adjustmentTypes[type] ?? 0) + 1;

        final exerciseId = adjustment['exerciseId'] as String? ?? 'unknown';
        exerciseAdjustmentCounts[exerciseId] =
            (exerciseAdjustmentCounts[exerciseId] ?? 0) + 1;
      }

      // Get most adjusted exercises
      final sortedExercises = exerciseAdjustmentCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'totalAdjustments': adjustments.length,
        'adjustmentTypes': adjustmentTypes,
        'mostAdjustedExercises': sortedExercises
            .take(5)
            .map((e) => {
                  'exerciseId': e.key,
                  'adjustmentCount': e.value,
                })
            .toList(),
        'recentAdjustments': adjustments.take(10).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting adjustment analytics: $e');
      return {};
    }
  }
}
