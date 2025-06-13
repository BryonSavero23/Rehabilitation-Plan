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

      // 🗓️ NEW: Schedule adjusted exercise for next week
      if (adjustmentsApplied) {
        await _scheduleAdjustedExerciseForNextWeek(
          userId: userId,
          planId: planId,
          exerciseId: exerciseId,
          feedbackData: feedbackData,
        );
      }

      print('🎯 Post-exercise adjustment processing complete');
    } catch (e) {
      print('❌ Error in post-exercise adjustments: $e');
      // Continue without throwing - adjustments are optional
    }
  }

  // 🗓️ NEW: Schedule adjusted exercise for next week
  Future<void> _scheduleAdjustedExerciseForNextWeek({
    required String userId,
    required String planId,
    required String exerciseId,
    required Map<String, dynamic> feedbackData,
  }) async {
    try {
      print('🗓️ Scheduling adjusted exercise for next week...');

      // Calculate next week's start date (next Monday)
      final now = DateTime.now();
      final daysUntilNextMonday = (8 - now.weekday) % 7;
      final nextWeekStart = now.add(
          Duration(days: daysUntilNextMonday == 0 ? 7 : daysUntilNextMonday));

      // Get the adjusted exercise data
      final adjustedExercise =
          await _getAdjustedExercise(userId, planId, exerciseId);

      if (adjustedExercise != null) {
        // Create schedule entry for next week
        await _firestore.collection('exerciseSchedule').add({
          'userId': userId,
          'planId': planId,
          'exerciseId': exerciseId,
          'exerciseName': adjustedExercise['name'],
          'adjustedExercise': adjustedExercise,
          'originalFeedback': feedbackData,
          'scheduledDate': Timestamp.fromDate(nextWeekStart),
          'weekStartDate': Timestamp.fromDate(nextWeekStart),
          'status': 'scheduled', // scheduled, completed, skipped
          'adjustmentReason': 'ai_optimization',
          'createdAt': FieldValue.serverTimestamp(),
          'isAdjusted': true,
          'adjustmentVersion': 1,
        });

        print('✅ Exercise scheduled for ${_formatDate(nextWeekStart)}');

        // Create user notification about the scheduled adjustment
        await _createScheduleNotification(
            userId, adjustedExercise, nextWeekStart);
      }
    } catch (e) {
      print('❌ Error scheduling exercise for next week: $e');
    }
  }

  // 📅 Get adjusted exercise data
  Future<Map<String, dynamic>?> _getAdjustedExercise(
      String userId, String planId, String exerciseId) async {
    try {
      // Get current plan
      DocumentSnapshot? planDoc = await _getPlanDocument(userId, planId);

      if (planDoc == null || !planDoc.exists) {
        return null;
      }

      final planData = planDoc.data() as Map<String, dynamic>;
      final exercises = List<dynamic>.from(planData['exercises'] ?? []);

      // Find the specific exercise
      for (final exercise in exercises) {
        if (exercise['id'] == exerciseId) {
          return Map<String, dynamic>.from(exercise);
        }
      }

      return null;
    } catch (e) {
      print('❌ Error getting adjusted exercise: $e');
      return null;
    }
  }

  // 🔔 Create notification about scheduled adjustment
  Future<void> _createScheduleNotification(String userId,
      Map<String, dynamic> exercise, DateTime scheduledDate) async {
    try {
      await _firestore.collection('userNotifications').add({
        'userId': userId,
        'type': 'exercise_scheduled',
        'title': 'Exercise Adjusted for Next Week',
        'message':
            '${exercise['name']} has been optimized based on your feedback and scheduled for ${_formatDate(scheduledDate)}',
        'data': {
          'exerciseId': exercise['id'],
          'exerciseName': exercise['name'],
          'scheduledDate': scheduledDate.toIso8601String(),
          'adjustments': {
            'sets': exercise['sets'],
            'reps': exercise['reps'],
            'duration': exercise['durationSeconds'],
            'difficulty': exercise['difficultyLevel'],
          }
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('🔔 Schedule notification created');
    } catch (e) {
      print('❌ Error creating schedule notification: $e');
    }
  }

  // 📋 Get scheduled exercises for a specific week
  Future<List<Map<String, dynamic>>> getScheduledExercisesForWeek(
      String userId, DateTime weekStart) async {
    try {
      // Calculate week end
      final weekEnd = weekStart.add(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .where('weekStartDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('weekStartDate', isLessThan: Timestamp.fromDate(weekEnd))
          .orderBy('weekStartDate')
          .orderBy('scheduledDate')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'scheduledDate': (data['scheduledDate'] as Timestamp).toDate(),
          'weekStartDate': (data['weekStartDate'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting scheduled exercises: $e');
      return [];
    }
  }

  // 📅 Get next week's scheduled exercises (for UI display)
  Future<List<Map<String, dynamic>>> getNextWeekScheduledExercises(
      String userId) async {
    final now = DateTime.now();
    final daysUntilNextMonday = (8 - now.weekday) % 7;
    final nextWeekStart = now.add(
        Duration(days: daysUntilNextMonday == 0 ? 7 : daysUntilNextMonday));

    return await getScheduledExercisesForWeek(userId, nextWeekStart);
  }

  // 🗓️ Mark scheduled exercise as completed
  Future<void> markScheduledExerciseCompleted(String scheduleId) async {
    try {
      await _firestore.collection('exerciseSchedule').doc(scheduleId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Scheduled exercise marked as completed');
    } catch (e) {
      print('❌ Error marking scheduled exercise as completed: $e');
    }
  }

  // 🗓️ Get exercises for specific date (enhanced for scheduled exercises)
  Future<List<Map<String, dynamic>>> getExercisesForDate(
      String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Get scheduled exercises for this date
      final scheduledSnapshot = await _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .where('scheduledDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      List<Map<String, dynamic>> exercises = [];

      for (final doc in scheduledSnapshot.docs) {
        final data = doc.data();
        final adjustedExercise =
            data['adjustedExercise'] as Map<String, dynamic>;

        exercises.add({
          'scheduleId': doc.id,
          'isScheduled': true,
          'isAdjusted': true,
          'status': data['status'],
          'scheduledDate': (data['scheduledDate'] as Timestamp).toDate(),
          'adjustmentReason': data['adjustmentReason'],
          ...adjustedExercise,
        });
      }

      return exercises;
    } catch (e) {
      print('❌ Error getting exercises for date: $e');
      return [];
    }
  }

  // 📊 Get weekly schedule summary
  Future<Map<String, dynamic>> getWeeklyScheduleSummary(String userId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      final nextWeekStart = endOfWeek.add(const Duration(days: 1));
      final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));

      // Get current week data
      final currentWeekExercises =
          await _getExercisesForWeek(userId, startOfWeek, endOfWeek);
      final nextWeekExercises =
          await _getExercisesForWeek(userId, nextWeekStart, nextWeekEnd);

      // Check for AI-adjusted exercises in next week
      final adjustedExercises =
          nextWeekExercises.where((e) => e['isAdjusted'] == true).toList();

      return {
        'currentWeek': {
          'total': currentWeekExercises.length,
          'completed': currentWeekExercises
              .where((e) => e['status'] == 'completed')
              .length,
          'remaining': currentWeekExercises
              .where((e) => e['status'] != 'completed')
              .length,
        },
        'nextWeek': {
          'total': nextWeekExercises.length,
          'scheduled':
              nextWeekExercises.where((e) => e['status'] == 'scheduled').length,
          'hasAdjustedExercises': adjustedExercises.isNotEmpty,
          'adjustedCount': adjustedExercises.length,
        },
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting weekly schedule summary: $e');
      return {
        'currentWeek': {'total': 0, 'completed': 0, 'remaining': 0},
        'nextWeek': {
          'total': 0,
          'scheduled': 0,
          'hasAdjustedExercises': false,
          'adjustedCount': 0
        },
      };
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

  // 📅 HELPER: Get exercises for a week range
  Future<List<Map<String, dynamic>>> _getExercisesForWeek(
      String userId, DateTime startDate, DateTime endDate) async {
    try {
      final exercisesForWeek = <Map<String, dynamic>>[];

      // Get scheduled exercises for the week
      final scheduledExercises = await _firestore
          .collection('scheduledExercises')
          .where('userId', isEqualTo: userId)
          .where('scheduledDate', isGreaterThanOrEqualTo: startDate)
          .where('scheduledDate', isLessThan: endDate)
          .get();

      for (final doc in scheduledExercises.docs) {
        final data = doc.data();
        exercisesForWeek.add({
          'id': doc.id,
          ...data,
          'isScheduled': true,
        });
      }

      // If no scheduled exercises, generate from patterns
      if (exercisesForWeek.isEmpty) {
        exercisesForWeek.addAll(await _generateWeeklyExercisesFromPattern(
            userId, startDate, endDate));
      }

      return exercisesForWeek;
    } catch (e) {
      print('❌ Error getting exercises for week: $e');
      return [];
    }
  }

  // 📅 HELPER: Get exercises from weekly pattern
  Future<List<Map<String, dynamic>>> _getExercisesFromWeeklyPattern(
      String userId, DateTime date) async {
    try {
      // Get user's current rehabilitation plan
      final userPlans = await _firestore
          .collection('rehabilitation_plans')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      if (userPlans.docs.isEmpty) {
        return [];
      }

      final planData = userPlans.docs.first.data();
      final exercises =
          List<Map<String, dynamic>>.from(planData['exercises'] ?? []);

      if (exercises.isEmpty) {
        return [];
      }

      // Simple pattern: Different exercise each day of the week
      final dayOfWeek = date.weekday - 1; // Monday = 0
      final exerciseIndex = dayOfWeek % exercises.length;
      final selectedExercise = exercises[exerciseIndex];

      // Check if this exercise has been adjusted
      final hasAdjustments =
          await _hasRecentAdjustments(userId, selectedExercise['id']);

      return [
        {
          ...selectedExercise,
          'scheduledDate': date.toIso8601String(),
          'status': 'scheduled',
          'isAdjusted': hasAdjustments,
          'isScheduled': true,
        }
      ];
    } catch (e) {
      print('❌ Error getting exercises from weekly pattern: $e');
      return [];
    }
  }

  // 📅 HELPER: Generate weekly exercises from pattern
  Future<List<Map<String, dynamic>>> _generateWeeklyExercisesFromPattern(
      String userId, DateTime startDate, DateTime endDate) async {
    try {
      final exercises = <Map<String, dynamic>>[];

      // Get user's current rehabilitation plan
      final userPlans = await _firestore
          .collection('rehabilitation_plans')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      if (userPlans.docs.isEmpty) {
        return [];
      }

      final planData = userPlans.docs.first.data();
      final planExercises =
          List<Map<String, dynamic>>.from(planData['exercises'] ?? []);

      if (planExercises.isEmpty) {
        return [];
      }

      // Generate exercises for each day of the week
      for (int i = 0; i < 7; i++) {
        final currentDate = startDate.add(Duration(days: i));
        if (currentDate.isAfter(endDate)) break;

        final exerciseIndex = i % planExercises.length;
        final selectedExercise = planExercises[exerciseIndex];

        // Check if this exercise has been adjusted
        final hasAdjustments =
            await _hasRecentAdjustments(userId, selectedExercise['id']);

        exercises.add({
          ...selectedExercise,
          'scheduledDate': currentDate.toIso8601String(),
          'status': 'scheduled',
          'isAdjusted': hasAdjustments,
          'isScheduled': true,
        });
      }

      return exercises;
    } catch (e) {
      print('❌ Error generating weekly exercises from pattern: $e');
      return [];
    }
  }

  // 📅 HELPER: Check if exercise has recent adjustments
  Future<bool> _hasRecentAdjustments(String userId, String exerciseId) async {
    try {
      final recentAdjustments = await _firestore
          .collection('exerciseAdjustments')
          .where('userId', isEqualTo: userId)
          .where('exerciseId', isEqualTo: exerciseId)
          .where('timestamp',
              isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
          .limit(1)
          .get();

      return recentAdjustments.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking recent adjustments: $e');
      return false;
    }
  }

  // 📅 NEW: Schedule exercise for specific date
  Future<void> scheduleExerciseForDate({
    required String userId,
    required String exerciseId,
    required DateTime scheduledDate,
    required Map<String, dynamic> exerciseData,
  }) async {
    try {
      await _firestore.collection('scheduledExercises').add({
        'userId': userId,
        'exerciseId': exerciseId,
        'scheduledDate': scheduledDate,
        'status': 'scheduled',
        'isCompleted': false,
        'isAdjusted': exerciseData['isAdjusted'] ?? false,
        'exerciseData': exerciseData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Exercise scheduled for ${scheduledDate.toIso8601String()}');
    } catch (e) {
      print('❌ Error scheduling exercise: $e');
      throw e;
    }
  }

  // 📅 NEW: Update scheduled exercise status
  Future<void> updateScheduledExerciseStatus({
    required String userId,
    required String exerciseId,
    required DateTime scheduledDate,
    required String status,
  }) async {
    try {
      final startOfDay =
          DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final scheduledExercises = await _firestore
          .collection('scheduledExercises')
          .where('userId', isEqualTo: userId)
          .where('exerciseId', isEqualTo: exerciseId)
          .where('scheduledDate', isGreaterThanOrEqualTo: startOfDay)
          .where('scheduledDate', isLessThan: endOfDay)
          .get();

      for (final doc in scheduledExercises.docs) {
        await doc.reference.update({
          'status': status,
          'isCompleted': status == 'completed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Updated scheduled exercise status to: $status');
    } catch (e) {
      print('❌ Error updating scheduled exercise status: $e');
      throw e;
    }
  }

  // 📅 NEW: Get exercise schedule analytics
  Future<Map<String, dynamic>> getExerciseScheduleAnalytics(
      String userId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final monthlyExercises = await _firestore
          .collection('scheduledExercises')
          .where('userId', isEqualTo: userId)
          .where('scheduledDate', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      final total = monthlyExercises.docs.length;
      final completed = monthlyExercises.docs
          .where((doc) => doc.data()['isCompleted'] == true)
          .length;
      final skipped = monthlyExercises.docs
          .where((doc) => doc.data()['status'] == 'skipped')
          .length;
      final scheduled = monthlyExercises.docs
          .where((doc) => doc.data()['status'] == 'scheduled')
          .length;

      return {
        'total': total,
        'completed': completed,
        'skipped': skipped,
        'scheduled': scheduled,
        'completionRate': total > 0 ? (completed / total * 100).round() : 0,
        'period': 'current_month',
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting exercise schedule analytics: $e');
      return {
        'total': 0,
        'completed': 0,
        'skipped': 0,
        'scheduled': 0,
        'completionRate': 0,
      };
    }
  }

  // Utility method to format dates
  String _formatDate(DateTime date) {
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}
