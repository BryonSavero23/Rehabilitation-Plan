// lib/services/weekly_progression_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class WeeklyProgressionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================================
  // WEEKLY EXERCISE COMPLETION & FEEDBACK TRACKING
  // ============================================================================

  /// Complete an exercise and provide feedback
  Future<Map<String, dynamic>> completeExerciseWithFeedback({
    required String userId,
    required String planId,
    required String exerciseId,
    required Map<String, dynamic> feedbackData,
    required int weekNumber,
  }) async {
    try {
      final batch = _firestore.batch();
      final timestamp = DateTime.now();

      // 1. Save exercise feedback
      final feedbackRef = _firestore.collection('exerciseFeedbacks').doc();
      batch.set(feedbackRef, {
        'userId': userId,
        'planId': planId,
        'exerciseId': exerciseId,
        'weekNumber': weekNumber,
        'timestamp': timestamp,
        ...feedbackData,
      });

      // 2. Update weekly progress
      final weeklyProgressRef = _firestore
          .collection('weeklyProgress')
          .doc('${userId}_${planId}_week$weekNumber');

      batch.update(weeklyProgressRef, {
        'completedExercises': FieldValue.arrayUnion([exerciseId]),
        'lastCompletedAt': timestamp,
        'lastUpdated': timestamp,
      });

      // 3. Mark exercise as completed in plan
      await _markExerciseCompleted(userId, planId, exerciseId, weekNumber);

      await batch.commit();

      // 4. Check if week is completed and generate feedback for next week
      final weeklyAdjustments =
          await _checkWeekCompletionAndAdjust(userId, planId, weekNumber);

      return {
        'success': true,
        'weeklyAdjustments': weeklyAdjustments,
        'message': 'Exercise completed successfully',
      };
    } catch (e) {
      print('❌ Error completing exercise with feedback: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Check if all exercises for the week are completed and trigger adjustments
  Future<Map<String, dynamic>?> _checkWeekCompletionAndAdjust(
      String userId, String planId, int weekNumber) async {
    try {
      // Get weekly progress
      final weeklyProgressDoc = await _firestore
          .collection('weeklyProgress')
          .doc('${userId}_${planId}_week$weekNumber')
          .get();

      if (!weeklyProgressDoc.exists) return null;

      final weeklyData = weeklyProgressDoc.data()!;
      final completedExercises =
          List<String>.from(weeklyData['completedExercises'] ?? []);

      // Get total exercises for this week
      final planDoc =
          await _firestore.collection('rehabilitation_plans').doc(planId).get();

      if (!planDoc.exists) return null;

      final planData = planDoc.data()!;
      final totalExercises = List.from(planData['exercises'] ?? []).length;

      // Check if week is completed (assuming all exercises should be done once per week)
      if (completedExercises.length >= totalExercises) {
        print('✅ Week $weekNumber completed for plan $planId');

        // Generate adjustments for next week
        final adjustments =
            await _generateWeeklyAdjustments(userId, planId, weekNumber);

        // Mark week as completed
        await weeklyProgressDoc.reference.update({
          'status': 'completed',
          'completedAt': DateTime.now(),
          'adjustmentsGenerated': adjustments != null,
        });

        return adjustments;
      }

      return null;
    } catch (e) {
      print('❌ Error checking week completion: $e');
      return null;
    }
  }

  /// Generate exercise adjustments based on weekly feedback
  Future<Map<String, dynamic>?> _generateWeeklyAdjustments(
      String userId, String planId, int completedWeekNumber) async {
    try {
      // Get all feedback from the completed week
      final feedbackSnapshot = await _firestore
          .collection('exerciseFeedbacks')
          .where('userId', isEqualTo: userId)
          .where('planId', isEqualTo: planId)
          .where('weekNumber', isEqualTo: completedWeekNumber)
          .get();

      if (feedbackSnapshot.docs.isEmpty) return null;

      final feedbacks = feedbackSnapshot.docs.map((doc) => doc.data()).toList();

      // Analyze feedback patterns for each exercise
      final exerciseAdjustments = <String, Map<String, dynamic>>{};

      // Group feedback by exercise
      final feedbackByExercise = <String, List<Map<String, dynamic>>>{};
      for (final feedback in feedbacks) {
        final exerciseId = feedback['exerciseId'] as String;
        feedbackByExercise.putIfAbsent(exerciseId, () => []).add(feedback);
      }

      // Generate adjustments for each exercise
      for (final entry in feedbackByExercise.entries) {
        final exerciseId = entry.key;
        final exerciseFeedbacks = entry.value;

        final adjustment = _analyzeExerciseFeedback(exerciseFeedbacks);
        if (adjustment.isNotEmpty) {
          exerciseAdjustments[exerciseId] = adjustment;
        }
      }

      if (exerciseAdjustments.isNotEmpty) {
        // Save adjustments for next week
        final nextWeekNumber = completedWeekNumber + 1;
        await _firestore
            .collection('weeklyAdjustments')
            .doc('${userId}_${planId}_week$nextWeekNumber')
            .set({
          'userId': userId,
          'planId': planId,
          'weekNumber': nextWeekNumber,
          'basedOnWeek': completedWeekNumber,
          'adjustments': exerciseAdjustments,
          'createdAt': DateTime.now(),
          'applied': false,
        });

        print('✅ Generated adjustments for week $nextWeekNumber');
        return exerciseAdjustments;
      }

      return null;
    } catch (e) {
      print('❌ Error generating weekly adjustments: $e');
      return null;
    }
  }

  /// Analyze feedback for a specific exercise to determine adjustments
  Map<String, dynamic> _analyzeExerciseFeedback(
      List<Map<String, dynamic>> feedbacks) {
    if (feedbacks.isEmpty) return {};

    final adjustments = <String, dynamic>{};
    final recommendations = <String>[];

    // Analyze difficulty ratings
    final difficultyRatings =
        feedbacks.map((f) => f['difficultyRating'] as String).toList();
    final hardCount = difficultyRatings.where((d) => d == 'hard').length;
    final easyCount = difficultyRatings.where((d) => d == 'easy').length;
    final perfectCount = difficultyRatings.where((d) => d == 'perfect').length;

    // Analyze pain levels
    final painChanges = feedbacks.map((f) {
      final painBefore = f['painLevelBefore'] as int? ?? 0;
      final painAfter = f['painLevelAfter'] as int? ?? 0;
      return painAfter - painBefore;
    }).toList();

    final avgPainChange = painChanges.isNotEmpty
        ? painChanges.reduce((a, b) => a + b) / painChanges.length
        : 0.0;

    // Analyze completion rates
    final completionRates = feedbacks.map((f) {
      final completed = f['completedSets'] as int? ?? 0;
      final target = f['targetSets'] as int? ?? 1;
      return target > 0 ? completed / target : 1.0;
    }).toList();

    final avgCompletionRate = completionRates.isNotEmpty
        ? completionRates.reduce((a, b) => a + b) / completionRates.length
        : 1.0;

    // Generate adjustments based on analysis

    // If mostly too hard (>50% of sessions)
    if (hardCount > feedbacks.length * 0.5) {
      adjustments['sets_multiplier'] = 0.8;
      adjustments['reps_multiplier'] = 0.9;
      adjustments['difficulty_adjustment'] = 'decrease';
      recommendations.add('Exercise reduced due to consistent difficulty');
    }

    // If mostly too easy (>60% of sessions)
    else if (easyCount > feedbacks.length * 0.6) {
      adjustments['sets_multiplier'] = 1.2;
      adjustments['reps_multiplier'] = 1.1;
      adjustments['difficulty_adjustment'] = 'increase';
      recommendations.add('Exercise intensity increased due to low difficulty');
    }

    // If pain is consistently increasing
    if (avgPainChange > 1.0) {
      adjustments['intensity_reduction'] = true;
      adjustments['sets_multiplier'] = 0.7;
      recommendations.add('Intensity reduced due to pain increase');
    }

    // If completion rate is low
    if (avgCompletionRate < 0.7) {
      adjustments['sets_multiplier'] = 0.8;
      recommendations.add('Sets reduced to improve completion rate');
    }

    // If everything is going well, slight progression
    else if (perfectCount > feedbacks.length * 0.6 &&
        avgPainChange <= 0 &&
        avgCompletionRate >= 0.9) {
      adjustments['progression_ready'] = true;
      adjustments['sets_multiplier'] = 1.1;
      recommendations.add('Ready for progression - slight increase applied');
    }

    if (adjustments.isNotEmpty) {
      adjustments['recommendations'] = recommendations;
      adjustments['analysis_summary'] = {
        'avg_pain_change': avgPainChange,
        'avg_completion_rate': avgCompletionRate,
        'difficulty_distribution': {
          'easy': easyCount,
          'perfect': perfectCount,
          'hard': hardCount,
        },
      };
    }

    return adjustments;
  }

  // ============================================================================
  // WEEKLY GOAL TRACKING & GRADUATION
  // ============================================================================

  /// Check rehabilitation goals at end of week and handle graduation
  Future<Map<String, dynamic>> checkWeeklyGoalsAndGraduate({
    required String userId,
    required String planId,
    required int weekNumber,
  }) async {
    try {
      // Get plan goals
      final planDoc =
          await _firestore.collection('rehabilitation_plans').doc(planId).get();

      if (!planDoc.exists) {
        return {'success': false, 'error': 'Plan not found'};
      }

      final planData = planDoc.data()!;
      final goals = planData['goals'] as Map<String, dynamic>? ?? {};

      if (goals.isEmpty) {
        return {'success': false, 'error': 'No goals defined for this plan'};
      }

      // Calculate current goal progress
      final goalProgress = await _calculateGoalProgress(userId, planId, goals);

      // Check if goals are achieved (80% threshold for most goals)
      final goalsAchieved = _checkGoalsAchievement(goalProgress, goals);

      if (goalsAchieved['isGraduated'] as bool) {
        // Graduate the patient
        await _graduatePatient(userId, planId, goalProgress, goalsAchieved);

        return {
          'success': true,
          'isGraduated': true,
          'goalProgress': goalProgress,
          'achievementSummary': goalsAchieved,
          'message':
              'Congratulations! You have successfully completed your rehabilitation plan.',
        };
      } else {
        // Continue with next week
        await _setupNextWeek(userId, planId, weekNumber + 1);

        return {
          'success': true,
          'isGraduated': false,
          'goalProgress': goalProgress,
          'achievementSummary': goalsAchieved,
          'message':
              'Continue with next week exercises. Keep up the great work!',
        };
      }
    } catch (e) {
      print('❌ Error checking weekly goals: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Calculate progress towards rehabilitation goals
  Future<Map<String, dynamic>> _calculateGoalProgress(
      String userId, String planId, Map<String, dynamic> goals) async {
    try {
      // Get all feedback for this plan
      final feedbackSnapshot = await _firestore
          .collection('exerciseFeedbacks')
          .where('userId', isEqualTo: userId)
          .where('planId', isEqualTo: planId)
          .orderBy('timestamp')
          .get();

      final feedbacks = feedbackSnapshot.docs.map((doc) => doc.data()).toList();

      if (feedbacks.isEmpty) {
        return {};
      }

      final progress = <String, dynamic>{};

      // Pain Reduction Goal
      if (goals.containsKey('painReduction')) {
        final targetReduction = goals['painReduction']['target'] as num? ?? 50;
        final initialPain = feedbacks.first['painLevelBefore'] as int? ?? 10;
        final recentPain = feedbacks.length >= 5
            ? feedbacks
                    .sublist(feedbacks.length - 5)
                    .map((f) => f['painLevelAfter'] as int? ?? 0)
                    .reduce((a, b) => a + b) /
                5
            : feedbacks.last['painLevelAfter'] as int? ?? 0;

        final actualReduction =
            ((initialPain - recentPain) / initialPain * 100);
        progress['painReduction'] = {
          'current': actualReduction,
          'target': targetReduction,
          'progress': actualReduction / targetReduction,
          'achieved': actualReduction >= targetReduction * 0.8, // 80% threshold
        };
      }

      // Range of Motion Goal
      if (goals.containsKey('rangeOfMotion')) {
        // This would typically come from specific measurements
        // For now, we'll estimate based on completion rates and difficulty trends
        final recentFeedbacks = feedbacks.length >= 10
            ? feedbacks.sublist(feedbacks.length - 10)
            : feedbacks;

        final avgCompletion = recentFeedbacks
                .map((f) =>
                    (f['completedSets'] as int? ?? 0) /
                    (f['targetSets'] as int? ?? 1))
                .reduce((a, b) => a + b) /
            recentFeedbacks.length;

        final easyPercentage = recentFeedbacks
                .where((f) => f['difficultyRating'] == 'easy')
                .length /
            recentFeedbacks.length *
            100;

        // Estimate ROM improvement as combination of completion and ease
        final romImprovement = (avgCompletion * 50) + (easyPercentage * 0.5);
        final targetImprovement =
            goals['rangeOfMotion']['target'] as num? ?? 70;

        progress['rangeOfMotion'] = {
          'current': romImprovement,
          'target': targetImprovement,
          'progress': romImprovement / targetImprovement,
          'achieved': romImprovement >= targetImprovement * 0.8,
        };
      }

      // Strength Goal
      if (goals.containsKey('strength')) {
        // Estimate strength improvement based on progression in sets/reps
        final recentFeedbacks = feedbacks.length >= 10
            ? feedbacks.sublist(feedbacks.length - 10)
            : feedbacks;

        final avgCompletion = recentFeedbacks
                .map((f) =>
                    (f['completedSets'] as int? ?? 0) /
                    (f['targetSets'] as int? ?? 1))
                .reduce((a, b) => a + b) /
            recentFeedbacks.length;

        final strengthImprovement = avgCompletion * 100;
        final targetImprovement = goals['strength']['target'] as num? ?? 80;

        progress['strength'] = {
          'current': strengthImprovement,
          'target': targetImprovement,
          'progress': strengthImprovement / targetImprovement,
          'achieved': strengthImprovement >= targetImprovement * 0.8,
        };
      }

      // Functional Capacity Goal
      if (goals.containsKey('functionalCapacity')) {
        // Estimate based on overall consistency and completion
        final consistencyScore = feedbacks.length >= 14
            ? (feedbacks.length / 14.0) * 100 // Assuming 2 weeks minimum
            : (feedbacks.length / 14.0) * 100;

        final avgCompletion = feedbacks
                .map((f) =>
                    (f['completedSets'] as int? ?? 0) /
                    (f['targetSets'] as int? ?? 1))
                .reduce((a, b) => a + b) /
            feedbacks.length;

        final functionalCapacity =
            (consistencyScore * 0.6) + (avgCompletion * 40);
        final targetCapacity =
            goals['functionalCapacity']['target'] as num? ?? 85;

        progress['functionalCapacity'] = {
          'current': functionalCapacity,
          'target': targetCapacity,
          'progress': functionalCapacity / targetCapacity,
          'achieved': functionalCapacity >= targetCapacity * 0.8,
        };
      }

      return progress;
    } catch (e) {
      print('❌ Error calculating goal progress: $e');
      return {};
    }
  }

  /// Check if rehabilitation goals are achieved
  Map<String, dynamic> _checkGoalsAchievement(
      Map<String, dynamic> goalProgress, Map<String, dynamic> goals) {
    final achievedGoals = <String>[];
    final unachievedGoals = <String>[];

    for (final goalType in goalProgress.keys) {
      final goalData = goalProgress[goalType] as Map<String, dynamic>;
      if (goalData['achieved'] as bool) {
        achievedGoals.add(goalType);
      } else {
        unachievedGoals.add(goalType);
      }
    }

    // Graduate if at least 80% of goals are achieved
    final totalGoals = goalProgress.length;
    final achievedCount = achievedGoals.length;
    final isGraduated = totalGoals > 0 && (achievedCount / totalGoals) >= 0.8;

    return {
      'isGraduated': isGraduated,
      'achievedGoals': achievedGoals,
      'unachievedGoals': unachievedGoals,
      'totalGoals': totalGoals,
      'achievedCount': achievedCount,
      'achievementPercentage':
          totalGoals > 0 ? (achievedCount / totalGoals * 100) : 0,
    };
  }

  /// Graduate patient and archive plan
  Future<void> _graduatePatient(
    String userId,
    String planId,
    Map<String, dynamic> goalProgress,
    Map<String, dynamic> achievementSummary,
  ) async {
    try {
      final batch = _firestore.batch();

      // 1. Update plan status to completed
      final planRef = _firestore.collection('rehabilitation_plans').doc(planId);
      batch.update(planRef, {
        'status': 'completed',
        'completedAt': DateTime.now(),
        'goalProgress': goalProgress,
        'achievementSummary': achievementSummary,
      });

      // 2. Create archived plan record
      final archivedPlanRef = _firestore.collection('archivedPlans').doc();

      // Get complete plan data
      final planDoc = await planRef.get();
      final planData = planDoc.data()!;

      batch.set(archivedPlanRef, {
        ...planData,
        'originalPlanId': planId,
        'archivedAt': DateTime.now(),
        'graduationDate': DateTime.now(),
        'finalGoalProgress': goalProgress,
        'achievementSummary': achievementSummary,
        'archiveReason': 'graduation',
      });

      // 3. Create graduation notification
      final notificationRef = _firestore.collection('notifications').doc();
      batch.set(notificationRef, {
        'userId': userId,
        'type': 'graduation',
        'title': 'Rehabilitation Plan Completed!',
        'message':
            'Congratulations! You have successfully completed your rehabilitation plan and achieved your goals.',
        'data': {
          'planId': planId,
          'archivedPlanId': archivedPlanRef.id,
          'achievementSummary': achievementSummary,
        },
        'isRead': false,
        'timestamp': DateTime.now(),
      });

      await batch.commit();

      print('✅ Patient graduated from plan $planId');
    } catch (e) {
      print('❌ Error graduating patient: $e');
      rethrow;
    }
  }

  /// Setup next week exercises with adjustments
  Future<void> _setupNextWeek(
      String userId, String planId, int nextWeekNumber) async {
    try {
      // Check if there are adjustments for next week
      final adjustmentsDoc = await _firestore
          .collection('weeklyAdjustments')
          .doc('${userId}_${planId}_week$nextWeekNumber')
          .get();

      // Create next week progress tracking
      await _firestore
          .collection('weeklyProgress')
          .doc('${userId}_${planId}_week$nextWeekNumber')
          .set({
        'userId': userId,
        'planId': planId,
        'weekNumber': nextWeekNumber,
        'status': 'active',
        'completedExercises': [],
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
        'hasAdjustments': adjustmentsDoc.exists,
      });

      if (adjustmentsDoc.exists) {
        // Apply adjustments to plan exercises
        await _applyWeeklyAdjustments(planId, adjustmentsDoc.data()!);
      }

      print('✅ Setup next week $nextWeekNumber for plan $planId');
    } catch (e) {
      print('❌ Error setting up next week: $e');
    }
  }

  /// Apply weekly adjustments to plan exercises
  Future<void> _applyWeeklyAdjustments(
      String planId, Map<String, dynamic> adjustmentData) async {
    try {
      final planRef = _firestore.collection('rehabilitation_plans').doc(planId);
      final planDoc = await planRef.get();

      if (!planDoc.exists) return;

      final planData = planDoc.data()!;
      final exercises =
          List<Map<String, dynamic>>.from(planData['exercises'] ?? []);
      final adjustments = adjustmentData['adjustments'] as Map<String, dynamic>;

      // Apply adjustments to each exercise
      for (int i = 0; i < exercises.length; i++) {
        final exerciseId = exercises[i]['id'] as String;

        if (adjustments.containsKey(exerciseId)) {
          final exerciseAdjustment =
              adjustments[exerciseId] as Map<String, dynamic>;

          // Apply multipliers
          if (exerciseAdjustment.containsKey('sets_multiplier')) {
            final multiplier = exerciseAdjustment['sets_multiplier'] as double;
            final currentSets = exercises[i]['sets'] as int? ?? 1;
            exercises[i]['sets'] =
                (currentSets * multiplier).round().clamp(1, 20);
          }

          if (exerciseAdjustment.containsKey('reps_multiplier')) {
            final multiplier = exerciseAdjustment['reps_multiplier'] as double;
            final currentReps = exercises[i]['reps'] as int? ?? 1;
            exercises[i]['reps'] =
                (currentReps * multiplier).round().clamp(1, 50);
          }

          // Add adjustment metadata
          exercises[i]['lastAdjusted'] = DateTime.now().toIso8601String();
          exercises[i]['adjustmentReason'] =
              exerciseAdjustment['recommendations'];
        }
      }

      // Update plan with adjusted exercises
      await planRef.update({
        'exercises': exercises,
        'lastUpdated': DateTime.now(),
        'adjustmentHistory': FieldValue.arrayUnion([adjustmentData]),
      });

      // Mark adjustments as applied
      await _firestore
          .collection('weeklyAdjustments')
          .doc(adjustmentData['userId'] +
              '_' +
              planId +
              '_week' +
              adjustmentData['weekNumber'].toString())
          .update({'applied': true, 'appliedAt': DateTime.now()});

      print('✅ Applied weekly adjustments to plan $planId');
    } catch (e) {
      print('❌ Error applying weekly adjustments: $e');
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Mark exercise as completed in plan
  Future<void> _markExerciseCompleted(
      String userId, String planId, String exerciseId, int weekNumber) async {
    try {
      final planRef = _firestore.collection('rehabilitation_plans').doc(planId);
      final planDoc = await planRef.get();

      if (planDoc.exists) {
        final planData = planDoc.data()!;
        final exercises =
            List<Map<String, dynamic>>.from(planData['exercises'] ?? []);

        for (int i = 0; i < exercises.length; i++) {
          if (exercises[i]['id'] == exerciseId) {
            exercises[i]['lastCompletedAt'] = DateTime.now().toIso8601String();
            exercises[i]['lastCompletedWeek'] = weekNumber;
            break;
          }
        }

        await planRef.update({
          'exercises': exercises,
          'lastUpdated': DateTime.now(),
        });
      }
    } catch (e) {
      print('❌ Error marking exercise completed: $e');
    }
  }

  /// Get current week number for a plan
  Future<int> getCurrentWeekNumber(String userId, String planId) async {
    try {
      final weeklyProgressSnapshot = await _firestore
          .collection('weeklyProgress')
          .where('userId', isEqualTo: userId)
          .where('planId', isEqualTo: planId)
          .orderBy('weekNumber', descending: true)
          .limit(1)
          .get();

      if (weeklyProgressSnapshot.docs.isNotEmpty) {
        final latestWeek = weeklyProgressSnapshot.docs.first.data();
        return latestWeek['weekNumber'] as int? ?? 1;
      }

      // If no weekly progress exists, start with week 1
      await _firestore
          .collection('weeklyProgress')
          .doc('${userId}_${planId}_week1')
          .set({
        'userId': userId,
        'planId': planId,
        'weekNumber': 1,
        'status': 'active',
        'completedExercises': [],
        'createdAt': DateTime.now(),
        'lastUpdated': DateTime.now(),
      });

      return 1;
    } catch (e) {
      print('❌ Error getting current week number: $e');
      return 1;
    }
  }

  /// Get weekly progress summary
  Future<Map<String, dynamic>> getWeeklyProgressSummary(
      String userId, String planId, int weekNumber) async {
    try {
      final weeklyProgressDoc = await _firestore
          .collection('weeklyProgress')
          .doc('${userId}_${planId}_week$weekNumber')
          .get();

      if (!weeklyProgressDoc.exists) {
        return {
          'weekNumber': weekNumber,
          'status': 'not_started',
          'completedExercises': [],
          'totalExercises': 0,
          'completionPercentage': 0.0,
        };
      }

      final weeklyData = weeklyProgressDoc.data()!;
      final completedExercises =
          List<String>.from(weeklyData['completedExercises'] ?? []);

      // Get total exercises from plan
      final planDoc =
          await _firestore.collection('rehabilitation_plans').doc(planId).get();

      final totalExercises = planDoc.exists
          ? (planDoc.data()!['exercises'] as List?)?.length ?? 0
          : 0;

      final completionPercentage = totalExercises > 0
          ? (completedExercises.length / totalExercises * 100)
          : 0.0;

      return {
        'weekNumber': weekNumber,
        'status': weeklyData['status'] ?? 'active',
        'completedExercises': completedExercises,
        'totalExercises': totalExercises,
        'completionPercentage': completionPercentage,
        'lastUpdated': weeklyData['lastUpdated'],
      };
    } catch (e) {
      print('❌ Error getting weekly progress summary: $e');
      return {};
    }
  }

  /// Get rehabilitation goals for a plan
  Future<Map<String, dynamic>> getRehabilitationGoals(String planId) async {
    try {
      final planDoc =
          await _firestore.collection('rehabilitation_plans').doc(planId).get();

      if (!planDoc.exists) {
        return {};
      }

      final planData = planDoc.data()!;
      return planData['goals'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      print('❌ Error getting rehabilitation goals: $e');
      return {};
    }
  }

  /// Get archived plans for a user
  Future<List<Map<String, dynamic>>> getArchivedPlans(String userId) async {
    try {
      final archivedSnapshot = await _firestore
          .collection('archivedPlans')
          .where('userId', isEqualTo: userId)
          .orderBy('archivedAt', descending: true)
          .get();

      return archivedSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('❌ Error getting archived plans: $e');
      return [];
    }
  }
}
