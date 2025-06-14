// lib/services/exercise_adjustment_service.dart (COMPLETE FIXED VERSION)
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

      // 🗓️ Schedule adjusted exercise for SAME DAY next week
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

  // 🗓️ FIXED: Schedule adjusted exercise using smart plan-based inference
  Future<void> _scheduleAdjustedExerciseForNextWeek({
    required String userId,
    required String planId,
    required String exerciseId,
    required Map<String, dynamic> feedbackData,
  }) async {
    try {
      print('🗓️ Scheduling adjusted exercise for same day next week...');

      // ✅ IMPROVED: Smart original schedule detection
      DateTime originalScheduleDate;

      try {
        final now = DateTime.now();
        final startOfWeek = _getWeekStart(now);

        // First: Try to find actual scheduled exercise
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
          final originalData = originalScheduled.docs.first.data();
          originalScheduleDate =
              (originalData['scheduledDate'] as Timestamp).toDate();
          print(
              '📅 Found original schedule date: ${_formatDate(originalScheduleDate)} (${_getDayOfWeekName(originalScheduleDate.weekday)})');
        } else {
          print('📅 No scheduled exercise found - this was a pattern exercise');
          // Smart inference: Use exercise's position in plan to determine correct day
          originalScheduleDate = await _inferOriginalScheduleDateFromPlan(
              userId, planId, exerciseId);
        }
      } catch (e) {
        print('❌ Error finding original schedule: $e');
        originalScheduleDate = await _inferOriginalScheduleDateFromPlan(
            userId, planId, exerciseId);
      }

      print(
          '📅 Using smart-inferred schedule day: ${_getDayOfWeekName(originalScheduleDate.weekday)}');

      // Calculate same day next week from INFERRED/ORIGINAL schedule date
      final nextWeekSameDay = originalScheduleDate.add(const Duration(days: 7));

      final scheduledDate = DateTime(nextWeekSameDay.year,
          nextWeekSameDay.month, nextWeekSameDay.day, 9, 0, 0);

      print(
          '📅 Scheduling for: ${_formatDate(scheduledDate)} (${_getDayOfWeekName(scheduledDate.weekday)})');
      print(
          '📅 Scheduling logic: Pattern position → ${_getDayOfWeekName(originalScheduleDate.weekday)} → Next ${_getDayOfWeekName(scheduledDate.weekday)}');

      // Check if exercise already scheduled for this date
      final existingSchedule = await _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .where('scheduledDate', isEqualTo: Timestamp.fromDate(scheduledDate))
          .limit(1)
          .get();

      if (existingSchedule.docs.isNotEmpty) {
        print(
            '⚠️ Date already has an exercise scheduled - replacing with optimized version');

        for (final doc in existingSchedule.docs) {
          await doc.reference.delete();
        }
      }

      // Get the adjusted exercise data
      final adjustedExercise =
          await _getAdjustedExercise(userId, planId, exerciseId);

      if (adjustedExercise != null) {
        await _firestore.collection('exerciseSchedule').add({
          'userId': userId,
          'planId': planId,
          'exerciseId': exerciseId,
          'exerciseName': adjustedExercise['name'],
          'adjustedExercise': adjustedExercise,
          'originalFeedback': feedbackData,
          'scheduledDate': Timestamp.fromDate(scheduledDate),
          'originalScheduledDate': Timestamp.fromDate(originalScheduleDate),
          'actualCompletionDate': FieldValue.serverTimestamp(),
          'dayOfWeek': _getDayOfWeekName(originalScheduleDate.weekday),
          'weekStartDate': Timestamp.fromDate(_getWeekStart(scheduledDate)),
          'status': 'scheduled',
          'adjustmentReason': 'ai_optimization',
          'createdAt': FieldValue.serverTimestamp(),
          'isAdjusted': true,
          'adjustmentVersion': 1,
          'schedulingType': 'smart_plan_based_inference',
        });

        print(
            '✅ Exercise scheduled for ${_formatDate(scheduledDate)} (using smart plan-based inference)');
        print(
            '📅 Schedule logic: Exercise position in plan → ${_getDayOfWeekName(originalScheduleDate.weekday)} → Next: ${_getDayOfWeekName(scheduledDate.weekday)}');

        await _createScheduleNotification(
            userId, adjustedExercise, scheduledDate);
      }
    } catch (e) {
      print('❌ Error scheduling exercise for same day next week: $e');
    }
  }

  // 🔍 IMPROVED: Smart inference based on exercise position in plan
  Future<DateTime> _inferOriginalScheduleDateFromPlan(
      String userId, String planId, String exerciseId) async {
    try {
      print('🔍 Smart inference: Finding exercise position in plan...');

      // Get the rehabilitation plan
      final planDoc = await _getPlanDocument(userId, planId);
      if (planDoc == null || !planDoc.exists) {
        print('❌ Plan not found for inference');
        return _getWeekStart(DateTime.now()); // Fallback to Monday
      }

      final planData = planDoc.data() as Map<String, dynamic>;

      // ✅ Safe access to exercises
      if (!planData.containsKey('exercises') || planData['exercises'] == null) {
        print('❌ No exercises in plan for inference');
        return _getWeekStart(DateTime.now());
      }

      final exercisesData = planData['exercises'];
      if (exercisesData is! List) {
        print('❌ Exercises data is not a list for inference');
        return _getWeekStart(DateTime.now());
      }

      // Find this exercise in the plan
      int exerciseIndex = -1;
      for (int i = 0; i < exercisesData.length; i++) {
        final exercise = exercisesData[i];
        if (exercise is Map<String, dynamic> && exercise['id'] == exerciseId) {
          exerciseIndex = i;
          break;
        }
      }

      if (exerciseIndex == -1) {
        print('❌ Exercise not found in plan for inference');
        return _getWeekStart(DateTime.now());
      }

      // ✅ SMART LOGIC: Use exercise position to determine typical day
      final now = DateTime.now();
      final startOfWeek = _getWeekStart(now);

      // Map exercise index to day of week (0 = Monday, 6 = Sunday)
      final targetDayOfWeek = exerciseIndex % 7;
      final targetDate = startOfWeek.add(Duration(days: targetDayOfWeek));

      print('📅 Smart inference complete:');
      print('   - Exercise position in plan: $exerciseIndex');
      print(
          '   - Mapped to day of week: $targetDayOfWeek (${_getDayOfWeekName(targetDate.weekday)})');
      print('   - Target date: ${_formatDate(targetDate)}');

      return targetDate;
    } catch (e) {
      print('❌ Error in smart inference: $e');
      // Ultimate fallback: Monday of current week
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

      DocumentSnapshot? planDoc = await _getPlanDocument(userId, planId);

      if (planDoc == null || !planDoc.exists) {
        print('❌ Plan not found: $planId');
        return;
      }

      final planData = planDoc.data() as Map<String, dynamic>;

      // ✅ FIXED: Safe access to exercises with proper null checking
      if (!planData.containsKey('exercises') || planData['exercises'] == null) {
        print('❌ No exercises found in plan data');
        return;
      }

      final exercisesData = planData['exercises'];
      List<dynamic> exercises = [];

      if (exercisesData is List) {
        exercises = List.from(exercisesData);
      } else {
        print('❌ Exercises data is not a list: ${exercisesData.runtimeType}');
        return;
      }

      // Find and update the specific exercise
      bool exerciseUpdated = false;
      for (int i = 0; i < exercises.length; i++) {
        final exercise = exercises[i];
        if (exercise is Map<String, dynamic> && exercise['id'] == exerciseId) {
          exerciseUpdated = true;

          final adjustedExercise =
              _applyAdjustmentsToExercise(exercise, aiAdjustments);
          exercises[i] = adjustedExercise;

          print('✅ Updated exercise: ${adjustedExercise['name']}');
          print(
              '📈 New parameters: Sets: ${adjustedExercise['sets']}, Reps: ${adjustedExercise['reps']}');
          break;
        }
      }

      if (exerciseUpdated) {
        await planDoc.reference.update({
          'exercises': exercises,
          'lastAIAdjustment': FieldValue.serverTimestamp(),
          'adjustmentReason': _generateAdjustmentReason(aiAdjustments),
          'adjustmentVersion': FieldValue.increment(1),
        });

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

      final feedbackHistory =
          await _getRecentFeedbackHistory(userId, exerciseId, 5);

      if (feedbackHistory.length < 3) {
        print('📊 Insufficient data for pattern analysis');
        return;
      }

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

    if (currentSets <= 2) {
      return rawNewSets.clamp(1, 4);
    } else if (currentSets <= 4) {
      return rawNewSets.clamp(2, 6);
    } else {
      return rawNewSets.clamp(3, 8);
    }
  }

  int _calculateNewReps(int currentReps, double multiplier) {
    final rawNewReps = (currentReps * multiplier).round();

    if (currentReps <= 5) {
      return rawNewReps.clamp(3, 8);
    } else if (currentReps <= 12) {
      return rawNewReps.clamp(5, 20);
    } else {
      return rawNewReps.clamp(10, 30);
    }
  }

  int _calculateNewDuration(int currentDuration, double multiplier) {
    final rawNewDuration = (currentDuration * multiplier).round();

    if (currentDuration <= 30) {
      return rawNewDuration.clamp(15, 60);
    } else if (currentDuration <= 90) {
      return rawNewDuration.clamp(30, 150);
    } else {
      return rawNewDuration.clamp(60, 300);
    }
  }

  // 📈 Analyze patterns in feedback history
  Map<String, dynamic> _analyzePatterns(
      List<Map<String, dynamic>> feedbackHistory) {
    Map<String, dynamic> adjustments = {};

    final difficultyRatings =
        feedbackHistory.map((f) => f['difficultyRating'] as String).toList();
    final easyCount = difficultyRatings.where((d) => d == 'easy').length;
    final hardCount = difficultyRatings.where((d) => d == 'hard').length;
    final totalCount = difficultyRatings.length;

    if (easyCount >= (totalCount * 0.7)) {
      adjustments['sets_multiplier'] = 1.2;
      adjustments['reps_multiplier'] = 1.15;
      print('📊 Pattern detected: Exercise too easy - increasing difficulty');
    } else if (hardCount >= (totalCount * 0.6)) {
      adjustments['sets_multiplier'] = 0.85;
      adjustments['reps_multiplier'] = 0.9;
      print('📊 Pattern detected: Exercise too hard - decreasing difficulty');
    }

    final painChanges = feedbackHistory.map((f) {
      final painBefore = f['painLevelBefore'] ?? 5;
      final painAfter = f['painLevelAfter'] ?? 5;
      return painAfter - painBefore;
    }).toList();

    final averagePainChange =
        painChanges.reduce((a, b) => a + b) / painChanges.length;

    if (averagePainChange > 1.0) {
      adjustments['intensity_multiplier'] = 0.8;
      adjustments['rest_time_multiplier'] = 1.3;
      print('📊 Pattern detected: Pain increasing - reducing intensity');
    } else if (averagePainChange < -1.0) {
      adjustments['intensity_multiplier'] = 1.1;
      print(
          '📊 Pattern detected: Pain decreasing - safe to increase intensity');
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
        return false;
      }

      final feedbacks = feedbackSnapshot.docs.map((doc) => doc.data()).toList();

      final difficultyRatings =
          feedbacks.map((f) => f['difficultyRating']).toList();
      final hardCount = difficultyRatings.where((d) => d == 'hard').length;
      final easyCount = difficultyRatings.where((d) => d == 'easy').length;

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

  // 📱 FIXED: Get plan document with better error handling
  Future<DocumentSnapshot?> _getPlanDocument(
      String userId, String planId) async {
    try {
      // ✅ FIXED: Try both collections with better error handling

      // Try user's subcollection first
      try {
        final userPlanQuery = await _firestore
            .collection('users')
            .doc(userId)
            .collection('rehabilitation_plans')
            .doc(planId)
            .get();

        if (userPlanQuery.exists) {
          print('📱 Found plan in user subcollection');
          return userPlanQuery;
        }
      } catch (e) {
        print('⚠️ Could not access user subcollection: $e');
      }

      // Try main collection
      try {
        final mainPlanDoc = await _firestore
            .collection('rehabilitation_plans')
            .doc(planId)
            .get();

        if (mainPlanDoc.exists) {
          print('📱 Found plan in main collection');
          return mainPlanDoc;
        }
      } catch (e) {
        print('⚠️ Could not access main collection: $e');
      }

      print('❌ Plan not found in any collection: $planId');
      return null;
    } catch (e) {
      print('❌ Error getting plan document: $e');
      return null;
    }
  }

  // 📅 FIXED: Get adjusted exercise data with better error handling
  Future<Map<String, dynamic>?> _getAdjustedExercise(
      String userId, String planId, String exerciseId) async {
    try {
      DocumentSnapshot? planDoc = await _getPlanDocument(userId, planId);

      if (planDoc == null || !planDoc.exists) {
        print('❌ Plan document not found');
        return null;
      }

      final planData = planDoc.data() as Map<String, dynamic>?;
      if (planData == null) {
        print('❌ Plan data is null');
        return null;
      }

      // ✅ FIXED: Safe access to exercises
      if (!planData.containsKey('exercises') || planData['exercises'] == null) {
        print('❌ No exercises found in plan');
        return null;
      }

      final exercisesData = planData['exercises'];
      if (exercisesData is! List) {
        print('❌ Exercises data is not a list');
        return null;
      }

      // Find the specific exercise
      for (final exerciseData in exercisesData) {
        if (exerciseData is Map<String, dynamic> &&
            exerciseData['id'] == exerciseId) {
          return Map<String, dynamic>.from(exerciseData);
        }
      }

      print('❌ Exercise not found: $exerciseId');
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

  // 🔍 Get adjustment history for an exercise
  Future<List<Map<String, dynamic>>> getAdjustmentHistory(
      String userId, String exerciseId) async {
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
        final timestamp = data['timestamp'];

        return {
          'id': doc.id,
          ...data,
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
    const double threshold = 0.1;

    for (final entry in adjustments.entries) {
      if (entry.key.contains('multiplier')) {
        final value = entry.value as double;
        if ((value - 1.0).abs() > threshold) {
          print('🎯 Significant adjustment detected: ${entry.key} = $value');
          return true;
        }
      }

      if (entry.key == 'difficulty_level') {
        print('🎯 Difficulty level change detected');
        return true;
      }
    }

    print('📊 No significant adjustments needed');
    return false;
  }

  // 🔔 Create notification
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
          'schedulingType': 'smart_plan_based_inference',
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

  // 🗓️ FIXED: Get exercises for specific date with proper plan filtering
  Future<List<Map<String, dynamic>>> getExercisesForDate(
      String userId, DateTime date,
      {String? currentPlanId}) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final now = DateTime.now();
      final isNextWeekOrFuture = date.isAfter(now.add(const Duration(days: 1)));

      print('🔍 Getting exercises for ${_formatDate(date)}:');
      print('   - Is future: $isNextWeekOrFuture');
      print('   - Current plan ID: $currentPlanId');

      // Build query for scheduled exercises
      Query query = _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .where('scheduledDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay));

      // ✅ FIXED: Filter by current plan if provided
      if (currentPlanId != null && currentPlanId.isNotEmpty) {
        query = query.where('planId', isEqualTo: currentPlanId);
        print('   - Filtering by plan ID: $currentPlanId');
      }

      final scheduledSnapshot = await query.get();
      print(
          '   - Found ${scheduledSnapshot.docs.length} scheduled exercises in DB');

      List<Map<String, dynamic>> exercises = [];
      Set<String> addedExerciseIds = {};

      // Process scheduled exercises
      for (final doc in scheduledSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final exerciseId = data['exerciseId'] as String;
        final status = data['status'] as String;

        if (['scheduled', 'completed'].contains(status)) {
          final adjustedExercise =
              data['adjustedExercise'] as Map<String, dynamic>?;

          if (adjustedExercise != null &&
              !addedExerciseIds.contains(exerciseId)) {
            exercises.add({
              'scheduleId': doc.id,
              'isScheduled': true,
              'isAdjusted': true,
              'status': status,
              'scheduledDate': (data['scheduledDate'] as Timestamp).toDate(),
              'dayOfWeek': data['dayOfWeek'] ?? _getDayOfWeekName(date.weekday),
              'adjustmentReason': data['adjustmentReason'],
              'schedulingType':
                  data['schedulingType'] ?? 'smart_plan_based_inference',
              'planId': data['planId'],
              ...adjustedExercise,
            });
            addedExerciseIds.add(exerciseId);
            print(
                '   - ✅ Added scheduled exercise: ${adjustedExercise['name']}');
          }
        }
      }

      // ✅ FIXED: Only add pattern exercises for current/past dates, NOT future dates
      if (exercises.isEmpty && !isNextWeekOrFuture && currentPlanId != null) {
        print(
            '   - No scheduled exercises and is current/past date - adding pattern exercise');
        final patternExercises = await _getExerciseFromPlanForDate(userId, date,
            planId: currentPlanId);
        for (final exercise in patternExercises) {
          final exerciseId = exercise['id'] as String;
          if (!addedExerciseIds.contains(exerciseId)) {
            exercises.add({
              ...exercise,
              'isScheduled': false,
              'isAdjusted': false,
              'status': 'pattern',
              'scheduledDate': date,
              'planId': currentPlanId,
            });
            addedExerciseIds.add(exerciseId);
            print('   - ✅ Added pattern exercise: ${exercise['name']}');
          }
        }
      }

      print(
          '📅 FINAL: Found ${exercises.length} unique exercises for ${_formatDate(date)}');
      return exercises;
    } catch (e) {
      print('❌ Error getting exercises for date: $e');
      return [];
    }
  }

  // 🗓️ FIXED: Get exercise from plan for a specific date with robust error handling
  Future<List<Map<String, dynamic>>> _getExerciseFromPlanForDate(
      String userId, DateTime date,
      {String? planId}) async {
    try {
      print(
          '🔍 Getting exercise from plan for date: ${_formatDate(date)}, planId: $planId');

      // ✅ FIXED: Get plan with proper error handling
      DocumentSnapshot? planDoc;

      if (planId != null && planId.isNotEmpty) {
        planDoc = await _getPlanDocument(userId, planId);
      } else {
        // Get active plan as fallback
        final userPlans = await _firestore
            .collection('rehabilitation_plans')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'active')
            .orderBy('lastUpdated', descending: true)
            .limit(1)
            .get();

        if (userPlans.docs.isNotEmpty) {
          planDoc = userPlans.docs.first;
        }
      }

      if (planDoc == null || !planDoc.exists) {
        print('❌ Plan not found');
        return [];
      }

      final planData = planDoc.data() as Map<String, dynamic>?;
      if (planData == null) {
        print('❌ Plan data is null');
        return [];
      }

      // ✅ FIXED: Safe access to exercises with comprehensive null checking
      if (!planData.containsKey('exercises')) {
        print('❌ No exercises key found in plan data');
        return [];
      }

      final exercisesData = planData['exercises'];
      if (exercisesData == null) {
        print('❌ Exercises data is null');
        return [];
      }

      if (exercisesData is! List) {
        print('❌ Exercises is not a list: ${exercisesData.runtimeType}');
        return [];
      }

      // Convert to proper format
      List<Map<String, dynamic>> exercises = [];

      for (var exerciseData in exercisesData) {
        try {
          if (exerciseData is Map<String, dynamic>) {
            exercises.add(exerciseData);
          } else if (exerciseData is Map) {
            exercises.add(Map<String, dynamic>.from(exerciseData));
          } else {
            print('❌ Unknown exercise format: ${exerciseData.runtimeType}');
          }
        } catch (e) {
          print('❌ Error converting exercise: $e');
        }
      }

      if (exercises.isEmpty) {
        print('❌ No valid exercises found in plan');
        return [];
      }

      // Simple pattern: Different exercise each day of the week
      final dayOfWeek = date.weekday - 1; // Monday = 0
      final exerciseIndex = dayOfWeek % exercises.length;
      final selectedExercise = exercises[exerciseIndex];

      print(
          '📅 Selected exercise: ${selectedExercise['name'] ?? 'Unknown'} (day $dayOfWeek, index $exerciseIndex)');

      // Check if this exercise has been adjusted
      final hasAdjustments =
          await _hasRecentAdjustments(userId, selectedExercise['id'] ?? '');

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
      print('❌ Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // 🧹 Clean up scheduled exercises for old plans
  Future<void> cleanupOldPlanScheduledExercises(
      String userId, String currentPlanId) async {
    try {
      print('🧹 Cleaning up scheduled exercises from old plans...');

      final oldExercises = await _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .get();

      int deletedCount = 0;
      for (final doc in oldExercises.docs) {
        final data = doc.data();
        final exercisePlanId = data['planId'] as String?;

        if (exercisePlanId != null && exercisePlanId != currentPlanId) {
          final exerciseName = data['exerciseName'] ?? 'Unknown';
          print(
              '🗑️ Deleting old exercise: $exerciseName (from plan: $exercisePlanId)');
          await doc.reference.delete();
          deletedCount++;
        }
      }

      print('✅ Cleaned up $deletedCount exercises from old plans');
    } catch (e) {
      print('❌ Error cleaning up old plan exercises: $e');
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

  // 📊 Get weekly schedule summary
  Future<Map<String, dynamic>> getWeeklyScheduleSummary(String userId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = _getWeekStart(now);
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      final nextWeekStart = endOfWeek.add(const Duration(days: 1));
      final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));

      // Get current week data
      final currentWeekExercises =
          await _getExercisesForWeek(userId, startOfWeek, endOfWeek);

      // Get next week data
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

  // 📅 Get next week's scheduled exercises
  Future<List<Map<String, dynamic>>> getNextWeekScheduledExercises(
      String userId) async {
    final now = DateTime.now();
    final daysUntilNextMonday = (8 - now.weekday) % 7;
    final nextWeekStart = now.add(
        Duration(days: daysUntilNextMonday == 0 ? 7 : daysUntilNextMonday));

    return await getScheduledExercisesForWeek(userId, nextWeekStart);
  }

  // 📋 Get scheduled exercises for a specific week
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

      Set<String> addedExercises = {};
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
    final weekEnd = weekStart.add(const Duration(days: 7));
    return await _getScheduledExercisesForWeek(userId, weekStart, weekEnd);
  }

  // 📅 Get exercises for a week range
  Future<List<Map<String, dynamic>>> _getExercisesForWeek(
      String userId, DateTime startDate, DateTime endDate) async {
    try {
      final isNextWeek =
          startDate.isAfter(DateTime.now().add(const Duration(days: 1)));

      if (isNextWeek) {
        return await _getScheduledExercisesForWeek(userId, startDate, endDate);
      } else {
        return await _generateCurrentWeekExercisesFromPattern(
            userId, startDate, endDate);
      }
    } catch (e) {
      print('❌ Error getting exercises for week: $e');
      return [];
    }
  }

  // 📅 Generate current week exercises from pattern
  Future<List<Map<String, dynamic>>> _generateCurrentWeekExercisesFromPattern(
      String userId, DateTime startDate, DateTime endDate) async {
    try {
      final exercises = <Map<String, dynamic>>[];

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

      // ✅ FIXED: Safe access to exercises
      if (!planData.containsKey('exercises') || planData['exercises'] == null) {
        return [];
      }

      final exercisesData = planData['exercises'];
      if (exercisesData is! List) {
        return [];
      }

      List<Map<String, dynamic>> planExercises = [];
      for (var exercise in exercisesData) {
        if (exercise is Map<String, dynamic>) {
          planExercises.add(exercise);
        } else if (exercise is Map) {
          planExercises.add(Map<String, dynamic>.from(exercise));
        }
      }

      if (planExercises.isEmpty) {
        return [];
      }

      // Generate exactly 1 exercise per day
      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final currentDate = startDate.add(Duration(days: dayOffset));
        if (currentDate.isAfter(endDate)) break;

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

  // 🚨 Nuclear option - delete all scheduled exercises
  Future<void> nukeAllScheduledExercises(String userId) async {
    try {
      print('🚨 NUCLEAR OPTION: Deleting ALL scheduled exercises for user...');

      final allScheduled = await _firestore
          .collection('exerciseSchedule')
          .where('userId', isEqualTo: userId)
          .get();

      print(
          '🗑️ Found ${allScheduled.docs.length} total scheduled exercises to delete...');

      int deleteCount = 0;
      for (final doc in allScheduled.docs) {
        final data = doc.data();
        final exerciseName = data['exerciseName'] ?? 'Unknown';
        final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();

        print('🗑️ Deleting: $exerciseName scheduled for $scheduledDate');
        await doc.reference.delete();
        deleteCount++;
      }

      print('✅ NUCLEAR COMPLETE: Deleted $deleteCount scheduled exercises');

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
