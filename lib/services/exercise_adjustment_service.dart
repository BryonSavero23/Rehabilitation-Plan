// lib/services/exercise_adjustment_service.dart (COMPLETE UPDATED VERSION)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/services/rehabilitation_service.dart';
import 'package:intl/intl.dart';

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
          adjustmentsApplied = true;
          print('✅ Pattern-based adjustments applied');
        }
      }

      // 🗓️ FIXED: Schedule adjusted exercise for SAME DAY next week
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

  // 🗓️ FIXED: Schedule adjusted exercise for SAME DAY next week (using ORIGINAL schedule date)
  Future<void> _scheduleAdjustedExerciseForNextWeek({
    required String userId,
    required String planId,
    required String exerciseId,
    required Map<String, dynamic> feedbackData,
  }) async {
    try {
      print('🗓️ Scheduling adjusted exercise for same day next week...');

      // ✅ FIXED: Use ORIGINAL exercise schedule date, not completion date
      DateTime originalScheduleDate;

      // Try to get the original scheduled date from the exercise plan
      // This maintains routine consistency even if exercise is completed late
      try {
        // Get the current week's exercise schedule for this exercise
        final now = DateTime.now();
        final startOfWeek = _getWeekStart(now);

        // Check if we can find the original schedule in current week
        final originalScheduled = await _firestore
            .collection('exerciseSchedule')
            .where('userId', isEqualTo: userId)
            .where('exerciseId', isEqualTo: exerciseId)
            .where('scheduledDate',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
            .where('scheduledDate',
                isLessThan: Timestamp.fromDate(
                    startOfWeek.add(const Duration(days: 7))))
            .limit(1)
            .get();

        if (originalScheduled.docs.isNotEmpty) {
          // Found original schedule - use that date
          final originalData = originalScheduled.docs.first.data();
          originalScheduleDate =
              (originalData['scheduledDate'] as Timestamp).toDate();
          print(
              '📅 Found original schedule date: ${_formatDate(originalScheduleDate)} (${_getDayOfWeekName(originalScheduleDate.weekday)})');
        } else {
          // No original schedule found, try to infer from exercise pattern
          originalScheduleDate =
              await _inferOriginalScheduleDate(userId, exerciseId);
        }
      } catch (e) {
        print('❌ Could not find original schedule, using current date pattern');
        originalScheduleDate =
            await _inferOriginalScheduleDate(userId, exerciseId);
      }

      print(
          '📅 Using original schedule day: ${_getDayOfWeekName(originalScheduleDate.weekday)}');

      // Calculate same day next week from ORIGINAL schedule date
      final nextWeekSameDay = originalScheduleDate.add(const Duration(days: 7));

      // Normalize to start of day for consistent scheduling
      final scheduledDate = DateTime(
          nextWeekSameDay.year,
          nextWeekSameDay.month,
          nextWeekSameDay.day,
          9,
          0,
          0 // Schedule for 9 AM by default
          );

      print(
          '📅 Scheduling for: ${_formatDate(scheduledDate)} (${_getDayOfWeekName(scheduledDate.weekday)})');

      // 🚫 PREVENT ANY EXERCISE on this date: Check if ANY exercise is already scheduled
      final existingSchedule = await _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .where('scheduledDate', isEqualTo: Timestamp.fromDate(scheduledDate))
          .limit(1)
          .get();

      if (existingSchedule.docs.isNotEmpty) {
        print(
            '⚠️ Date already has an exercise scheduled - replacing with optimized version');

        // Delete existing exercise for this date
        for (final doc in existingSchedule.docs) {
          await doc.reference.delete();
        }
      }

      // Get the adjusted exercise data
      final adjustedExercise =
          await _getAdjustedExercise(userId, planId, exerciseId);

      if (adjustedExercise != null) {
        // Create schedule entry for same day next week
        await _firestore.collection('exerciseSchedule').add({
          'userId': userId,
          'planId': planId,
          'exerciseId': exerciseId,
          'exerciseName': adjustedExercise['name'],
          'adjustedExercise': adjustedExercise,
          'originalFeedback': feedbackData,
          'scheduledDate': Timestamp.fromDate(scheduledDate),
          'originalScheduledDate': Timestamp.fromDate(
              originalScheduleDate), // Store original schedule
          'actualCompletionDate':
              FieldValue.serverTimestamp(), // When it was actually completed
          'dayOfWeek': _getDayOfWeekName(
              originalScheduleDate.weekday), // Use original day
          'weekStartDate': Timestamp.fromDate(_getWeekStart(scheduledDate)),
          'status': 'scheduled',
          'adjustmentReason': 'ai_optimization',
          'createdAt': FieldValue.serverTimestamp(),
          'isAdjusted': true,
          'adjustmentVersion': 1,
          'schedulingType': 'same_day_next_week_original_schedule',
        });

        print(
            '✅ Exercise scheduled for ${_formatDate(scheduledDate)} (maintaining original routine)');
        print(
            '📅 Original schedule: ${_getDayOfWeekName(originalScheduleDate.weekday)} → Next: ${_getDayOfWeekName(scheduledDate.weekday)}');

        // Create user notification about the scheduled adjustment
        await _createScheduleNotification(
            userId, adjustedExercise, scheduledDate);
      }
    } catch (e) {
      print('❌ Error scheduling exercise for same day next week: $e');
    }
  }

  // 🔍 Helper: Infer original schedule date from exercise pattern
  Future<DateTime> _inferOriginalScheduleDate(
      String userId, String exerciseId) async {
    try {
      // Get user's rehabilitation plan to find exercise pattern
      final userPlans = await _firestore
          .collection('rehabilitation_plans')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      if (userPlans.docs.isNotEmpty) {
        final planData = userPlans.docs.first.data();
        final exercises =
            List<Map<String, dynamic>>.from(planData['exercises'] ?? []);

        // Find the exercise index in the plan
        int exerciseIndex = -1;
        for (int i = 0; i < exercises.length; i++) {
          if (exercises[i]['id'] == exerciseId) {
            exerciseIndex = i;
            break;
          }
        }

        if (exerciseIndex >= 0) {
          // Calculate which day this exercise typically falls on (Monday = 0, Tuesday = 1, etc.)
          final now = DateTime.now();
          final startOfWeek = _getWeekStart(now);
          final targetDayOfWeek = exerciseIndex % 7; // Cycle through days
          final targetDate = startOfWeek.add(Duration(days: targetDayOfWeek));

          print(
              '📅 Inferred original schedule: ${_getDayOfWeekName(targetDate.weekday)} (based on exercise pattern)');
          return targetDate;
        }
      }

      // Fallback: use Monday of current week
      print('📅 Fallback: using Monday of current week');
      return _getWeekStart(DateTime.now());
    } catch (e) {
      print('❌ Error inferring original schedule date: $e');
      return _getWeekStart(DateTime.now());
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

  // 📝 Generate human-readable reason for the adjustment
  String _generateAdjustmentReason(Map<String, dynamic> adjustments) {
    List<String> reasons = [];

    if (adjustments.containsKey('sets_multiplier')) {
      final multiplier = adjustments['sets_multiplier'] as double;
      if (multiplier > 1.0) {
        reasons.add('Increased sets (exercise too easy)');
      } else if (multiplier < 1.0) {
        reasons.add('Reduced sets (exercise too hard)');
      }
    }

    if (adjustments.containsKey('reps_multiplier')) {
      final multiplier = adjustments['reps_multiplier'] as double;
      if (multiplier > 1.0) {
        reasons.add('Increased reps (good progress)');
      } else if (multiplier < 1.0) {
        reasons.add('Reduced reps (needs easier progression)');
      }
    }

    if (adjustments.containsKey('intensity_multiplier')) {
      final multiplier = adjustments['intensity_multiplier'] as double;
      if (multiplier > 1.0) {
        reasons.add('Increased intensity (pain improving)');
      } else if (multiplier < 1.0) {
        reasons.add('Reduced intensity (pain management)');
      }
    }

    if (adjustments.containsKey('difficulty_level')) {
      reasons.add('Difficulty level updated');
    }

    return reasons.isEmpty ? 'AI optimization' : reasons.join(', ');
  }

  // 📋 Log adjustment for analytics
  Future<void> _logAdjustment(String userId, String exerciseId,
      Map<String, dynamic> adjustments, String adjustmentType) async {
    try {
      await _firestore.collection('exerciseAdjustments').add({
        'userId': userId,
        'exerciseId': exerciseId,
        'adjustments': adjustments,
        'adjustmentType': adjustmentType,
        'timestamp': FieldValue.serverTimestamp(),
        'reason': _generateAdjustmentReason(adjustments),
      });

      print('📊 Adjustment logged: $adjustmentType');
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

  // 🔔 UPDATED: Create notification with correct day information
  Future<void> _createScheduleNotification(String userId,
      Map<String, dynamic> exercise, DateTime scheduledDate) async {
    try {
      final dayName = _getDayOfWeekName(scheduledDate.weekday);

      await _firestore.collection('userNotifications').add({
        'userId': userId,
        'type': 'exercise_scheduled',
        'title': 'Exercise Optimized for Next $dayName',
        'message':
            '${exercise['name']} has been adjusted based on your feedback and scheduled for next $dayName (${_formatDate(scheduledDate)})',
        'data': {
          'exerciseId': exercise['id'],
          'exerciseName': exercise['name'],
          'scheduledDate': scheduledDate.toIso8601String(),
          'dayOfWeek': dayName,
          'schedulingType': 'same_day_next_week',
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

      print('🔔 Schedule notification created for $dayName');
    } catch (e) {
      print('❌ Error creating schedule notification: $e');
    }
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

  // 🗓️ Get exercises for specific date (ENHANCED DEBUG: find the source of the problem)
  Future<List<Map<String, dynamic>>> getExercisesForDate(
      String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Check if this date is in the future (next week or beyond)
      final now = DateTime.now();
      final isNextWeekOrFuture = date.isAfter(now.add(const Duration(days: 1)));

      print('🔍 DEBUG for ${_formatDate(date)}:');
      print('   - Is future: $isNextWeekOrFuture');
      print('   - Start of day: $startOfDay');
      print('   - End of day: $endOfDay');

      // Get scheduled exercises for this specific date
      final scheduledSnapshot = await _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .where('scheduledDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get(); // Remove status filter to see ALL exercises

      print(
          '   - Found ${scheduledSnapshot.docs.length} scheduled exercises in DB');

      List<Map<String, dynamic>> exercises = [];
      Set<String> addedExerciseIds = {}; // Track to prevent duplicates

      // Debug: Log all scheduled exercises found
      for (final doc in scheduledSnapshot.docs) {
        final data = doc.data();
        final exerciseId = data['exerciseId'] as String;
        final exerciseName = data['exerciseName'] as String;
        final status = data['status'] as String;
        final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();

        print(
            '   - DB Exercise: $exerciseName (ID: $exerciseId, Status: $status, Date: $scheduledDate)');

        // Only add if status is valid
        if (['scheduled', 'completed'].contains(status)) {
          final adjustedExercise =
              data['adjustedExercise'] as Map<String, dynamic>;

          if (!addedExerciseIds.contains(exerciseId)) {
            exercises.add({
              'scheduleId': doc.id,
              'isScheduled': true,
              'isAdjusted': true,
              'status': status,
              'scheduledDate': scheduledDate,
              'dayOfWeek':
                  data['dayOfWeek'] ?? _getDayOfWeekName(scheduledDate.weekday),
              'adjustmentReason': data['adjustmentReason'],
              'schedulingType': data['schedulingType'] ?? 'same_day_next_week',
              ...adjustedExercise,
            });
            addedExerciseIds.add(exerciseId);
            print('   - ✅ Added scheduled exercise: $exerciseName');
          }
        } else {
          print('   - ❌ Skipped exercise with status: $status');
        }
      }

      print('   - Scheduled exercises added: ${exercises.length}');

      // ✅ FIXED: Only add pattern exercises for current/past dates, NOT future dates
      if (exercises.isEmpty && !isNextWeekOrFuture) {
        print(
            '   - No scheduled exercises and is current/past date - adding pattern exercise');
        final patternExercises =
            await _getExerciseFromPlanForDate(userId, date);
        for (final exercise in patternExercises) {
          final exerciseId = exercise['id'] as String;
          if (!addedExerciseIds.contains(exerciseId)) {
            exercises.add({
              ...exercise,
              'isScheduled': false,
              'isAdjusted': false,
              'status': 'pattern',
              'scheduledDate': date,
            });
            addedExerciseIds.add(exerciseId);
            print('   - ✅ Added pattern exercise: ${exercise['name']}');
          }
        }
      } else if (exercises.isEmpty && isNextWeekOrFuture) {
        print(
            '   - No scheduled exercises and is future date - NOT adding pattern exercises');
      } else if (!exercises.isEmpty) {
        print('   - Found scheduled exercises - NOT adding pattern exercises');
      }

      final dateType = isNextWeekOrFuture ? 'future' : 'current/past';
      print(
          '📅 FINAL: Found ${exercises.length} unique exercises for ${_formatDate(date)} ($dateType)');
      return exercises;
    } catch (e) {
      print('❌ Error getting exercises for date: $e');
      return [];
    }
  }

  // 🚨 NUCLEAR OPTION: Delete ALL scheduled exercises for this user
  Future<void> nukeAllScheduledExercises(String userId) async {
    try {
      print('🚨 NUCLEAR OPTION: Deleting ALL scheduled exercises for user...');

      // Get ALL scheduled exercises for this user (no date filters)
      final allScheduled = await _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .get();

      print(
          '🗑️ Found ${allScheduled.docs.length} total scheduled exercises to delete...');

      int deleteCount = 0;
      // Delete ALL of them
      for (final doc in allScheduled.docs) {
        final data = doc.data();
        final exerciseName = data['exerciseName'] ?? 'Unknown';
        final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();

        print('🗑️ Deleting: $exerciseName scheduled for $scheduledDate');
        await doc.reference.delete();
        deleteCount++;
      }

      print('✅ NUCLEAR COMPLETE: Deleted $deleteCount scheduled exercises');
      print('📊 All scheduled exercises should now be 0');

      // Verify cleanup
      final remaining = await _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .get();

      print(
          '✅ Verification: ${remaining.docs.length} exercises remaining (should be 0)');
    } catch (e) {
      print('❌ Error in nuclear option: $e');
    }
  }

  // 🚨 EMERGENCY FIX: Completely clear and rebuild next week schedule
  Future<void> emergencyFixScheduling(String userId) async {
    try {
      print(
          '🚨 EMERGENCY: Completely clearing and rebuilding next week schedule...');

      // Step 1: Delete ALL scheduled exercises for next week
      final now = DateTime.now();
      final nextWeekStart = _getWeekStart(now).add(const Duration(days: 7));
      final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));

      final allScheduled = await _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .where('scheduledDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(nextWeekStart))
          .where('scheduledDate',
              isLessThan: Timestamp.fromDate(nextWeekEnd
                  .add(const Duration(days: 1)))) // Add extra day buffer
          .get();

      print('🗑️ Deleting ${allScheduled.docs.length} scheduled exercises...');

      // Delete all existing scheduled exercises for next week
      for (final doc in allScheduled.docs) {
        await doc.reference.delete();
      }

      print('✅ All next week exercises cleared!');
      print('📊 Next week should now show 0 exercises for all days');

      // Step 2: Verify cleanup
      final remaining = await _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .where('scheduledDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(nextWeekStart))
          .where('scheduledDate',
              isLessThan:
                  Timestamp.fromDate(nextWeekEnd.add(const Duration(days: 1))))
          .get();

      print(
          '✅ Verification: ${remaining.docs.length} exercises remaining (should be 0)');
    } catch (e) {
      print('❌ Error in emergency fix: $e');
    }
  }

  // 🧹 Clean up duplicate scheduled exercises (AGGRESSIVE: max 1 exercise per day)
  Future<void> cleanupDuplicateScheduledExercises(String userId) async {
    try {
      print('🧹 Cleaning up duplicate scheduled exercises (max 1 per day)...');

      final snapshot = await _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true) // Keep newest
          .get();

      Map<String, List<DocumentSnapshot>> exercisesByDate = {};

      // Group exercises by date only (not by exerciseId)
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();
        final dateKey =
            '${scheduledDate.year}-${scheduledDate.month}-${scheduledDate.day}';

        if (!exercisesByDate.containsKey(dateKey)) {
          exercisesByDate[dateKey] = [];
        }
        exercisesByDate[dateKey]!.add(doc);
      }

      int deletedCount = 0;

      // Keep only 1 exercise per date (the newest one)
      for (final exercises in exercisesByDate.values) {
        if (exercises.length > 1) {
          print(
              '📅 Found ${exercises.length} exercises for same date - keeping newest, deleting ${exercises.length - 1}');

          // Keep the first (most recent due to descending order), delete the rest
          for (int i = 1; i < exercises.length; i++) {
            await exercises[i].reference.delete();
            deletedCount++;
          }
        }
      }

      print('✅ Cleaned up $deletedCount duplicate scheduled exercises');
      print('📊 Now enforcing: MAX 1 exercise per day');
    } catch (e) {
      print('❌ Error cleaning up duplicates: $e');
    }
  }

  // 📊 Get weekly schedule summary (FIXED: accurate counting)
  Future<Map<String, dynamic>> getWeeklyScheduleSummary(String userId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = _getWeekStart(now);
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      final nextWeekStart = endOfWeek.add(const Duration(days: 1));
      final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));

      // Get current week data (from patterns since it's current week)
      final currentWeekExercises =
          await _getExercisesForWeek(userId, startOfWeek, endOfWeek);

      // Get next week data (from scheduled exercises)
      final nextWeekExercises = await _getScheduledExercisesForWeek(
          userId, nextWeekStart, nextWeekEnd);

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

  // 📅 Get next week's scheduled exercises (for UI display)
  Future<List<Map<String, dynamic>>> getNextWeekScheduledExercises(
      String userId) async {
    final now = DateTime.now();
    final daysUntilNextMonday = (8 - now.weekday) % 7;
    final nextWeekStart = now.add(
        Duration(days: daysUntilNextMonday == 0 ? 7 : daysUntilNextMonday));

    return await getScheduledExercisesForWeek(userId, nextWeekStart);
  }

  // 📋 Get scheduled exercises for a specific week (FIXED: only scheduled, no duplicates)
  Future<List<Map<String, dynamic>>> _getScheduledExercisesForWeek(
      String userId, DateTime weekStart, DateTime weekEnd) async {
    try {
      final snapshot = await _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .where('scheduledDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(weekEnd))
          .where('status', whereIn: ['scheduled', 'completed'])
          .orderBy('scheduledDate')
          .get();

      Set<String> addedExercises = {}; // Prevent duplicates
      List<Map<String, dynamic>> exercises = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final exerciseId = data['exerciseId'] as String;
        final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();
        final uniqueKey =
            '${exerciseId}_${scheduledDate.year}_${scheduledDate.month}_${scheduledDate.day}';

        if (!addedExercises.contains(uniqueKey)) {
          exercises.add({
            'id': doc.id,
            ...data,
            'scheduledDate': scheduledDate,
            'weekStartDate': (data['weekStartDate'] as Timestamp).toDate(),
          });
          addedExercises.add(uniqueKey);
        }
      }

      print(
          '📅 Found ${exercises.length} unique scheduled exercises for week starting ${_formatDate(weekStart)}');
      return exercises;
    } catch (e) {
      print('❌ Error getting scheduled exercises for week: $e');
      return [];
    }
  }

  // 📋 Get scheduled exercises for a specific week (public method)
  Future<List<Map<String, dynamic>>> getScheduledExercisesForWeek(
      String userId, DateTime weekStart) async {
    // Calculate week end
    final weekEnd = weekStart.add(const Duration(days: 7));
    return await _getScheduledExercisesForWeek(userId, weekStart, weekEnd);
  }

  // 📅 HELPER: Get exercises for a week range (FIXED: prevents over-generation)
  Future<List<Map<String, dynamic>>> _getExercisesForWeek(
      String userId, DateTime startDate, DateTime endDate) async {
    try {
      // For next week, prioritize scheduled exercises
      final isNextWeek =
          startDate.isAfter(DateTime.now().add(const Duration(days: 1)));

      if (isNextWeek) {
        // Next week: Only return scheduled exercises
        return await _getScheduledExercisesForWeek(userId, startDate, endDate);
      } else {
        // Current week: Return pattern-based exercises (1 per day max)
        return await _generateCurrentWeekExercisesFromPattern(
            userId, startDate, endDate);
      }
    } catch (e) {
      print('❌ Error getting exercises for week: $e');
      return [];
    }
  }

  // 📅 HELPER: Get exercise from plan for a specific date
  Future<List<Map<String, dynamic>>> _getExerciseFromPlanForDate(
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
          'status': 'pattern',
          'isAdjusted': hasAdjustments,
          'isScheduled': false,
        }
      ];
    } catch (e) {
      print('❌ Error getting exercise from plan for date: $e');
      return [];
    }
  }

  // 📅 HELPER: Generate current week exercises from pattern (limited to 1 per day)
  Future<List<Map<String, dynamic>>> _generateCurrentWeekExercisesFromPattern(
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

      // Generate exactly 1 exercise per day (no more!)
      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final currentDate = startDate.add(Duration(days: dayOffset));
        if (currentDate.isAfter(endDate)) break;

        // Pick different exercise for each day
        final exerciseIndex = dayOffset % planExercises.length;
        final selectedExercise = planExercises[exerciseIndex];

        exercises.add({
          ...selectedExercise,
          'scheduledDate': currentDate.toIso8601String(),
          'status': 'pattern',
          'isAdjusted': false,
          'isScheduled': false,
        });
      }

      print(
          '📅 Generated ${exercises.length} pattern exercises for current week');
      return exercises;
    } catch (e) {
      print('❌ Error generating current week exercises from pattern: $e');
      return [];
    }
  }

  // 📅 HELPER: Generate exercises from weekly pattern
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

  // 🚨 IMMEDIATE FIX: Call this method to fix the current duplicate issue
  Future<void> fixDuplicateSchedulingIssue(String userId) async {
    try {
      print('🚨 EMERGENCY FIX: Resolving duplicate scheduling issue...');

      // Step 1: NUCLEAR OPTION - Clear everything for next week
      await emergencyFixScheduling(userId);

      // Step 2: Clean up any remaining duplicates
      await cleanupDuplicateScheduledExercises(userId);

      // Step 3: Verify the fix worked
      final now = DateTime.now();
      final nextWeekStart = _getWeekStart(now).add(const Duration(days: 7));

      // Check each day of next week
      print('📅 Checking each day of next week:');
      for (int day = 0; day < 7; day++) {
        final checkDate = nextWeekStart.add(Duration(days: day));
        final dayExercises = await getExercisesForDate(userId, checkDate);
        final dayName = _getDayOfWeekName(checkDate.weekday);
        print('   $dayName: ${dayExercises.length} exercises');
      }

      print('✅ Emergency fix completed!');
      print('📊 Next week should now show 0 exercises per day');
      print(
          '🎯 Complete exercises this week to schedule optimized versions for next week');
    } catch (e) {
      print('❌ Error fixing duplicate scheduling issue: $e');
    }
  }

  // 🎯 Manually create a clean next week schedule (1 exercise per day)
  Future<void> createCleanNextWeekSchedule(String userId) async {
    try {
      print('🎯 Creating clean next week schedule (1 exercise per day)...');

      // Get user's plan
      final userPlans = await _firestore
          .collection('rehabilitation_plans')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      if (userPlans.docs.isEmpty) {
        print('❌ No active rehabilitation plan found');
        return;
      }

      final planData = userPlans.docs.first.data();
      final planId = userPlans.docs.first.id;
      final exercises =
          List<Map<String, dynamic>>.from(planData['exercises'] ?? []);

      if (exercises.isEmpty) {
        print('❌ No exercises in rehabilitation plan');
        return;
      }

      // Schedule 1 exercise per day for next week
      final now = DateTime.now();
      final nextWeekStart = _getWeekStart(now).add(const Duration(days: 7));

      for (int day = 0; day < 7; day++) {
        final scheduledDate = DateTime(nextWeekStart.year, nextWeekStart.month,
            nextWeekStart.day + day, 9, 0, 0);

        // Pick different exercise for each day
        final exerciseIndex = day % exercises.length;
        final selectedExercise = exercises[exerciseIndex];

        await _firestore.collection('exerciseSchedule').add({
          'userId': userId,
          'planId': planId,
          'exerciseId': selectedExercise['id'],
          'exerciseName': selectedExercise['name'],
          'adjustedExercise': selectedExercise,
          'scheduledDate': Timestamp.fromDate(scheduledDate),
          'dayOfWeek': _getDayOfWeekName(scheduledDate.weekday),
          'weekStartDate': Timestamp.fromDate(nextWeekStart),
          'status': 'scheduled',
          'adjustmentReason': 'manual_clean_schedule',
          'createdAt': FieldValue.serverTimestamp(),
          'isAdjusted': false,
          'schedulingType': 'manual_clean',
        });

        print(
            '✅ Scheduled ${selectedExercise['name']} for ${_getDayOfWeekName(scheduledDate.weekday)}');
      }

      print('🎯 Clean schedule created: 7 exercises, 1 per day');
    } catch (e) {
      print('❌ Error creating clean schedule: $e');
    }
  }

  // 📅 Helper function to get day of week name
  String _getDayOfWeekName(int weekday) {
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return dayNames[weekday - 1];
  }

  // 📅 Helper function to get week start (Monday)
  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  // 📅 Helper function to format date
  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
}
