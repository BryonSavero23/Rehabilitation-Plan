// lib/services/realtime_ai_integration_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personalized_rehabilitation_plans/services/rehabilitation_service.dart';
import 'package:personalized_rehabilitation_plans/services/exercise_adjustment_service.dart';
import 'package:personalized_rehabilitation_plans/services/feedback_service.dart';
import 'package:personalized_rehabilitation_plans/models/exercise_feedback_model.dart';

class RealtimeAIIntegrationService extends ChangeNotifier {
  final RehabilitationService _rehabilitationService = RehabilitationService();
  final ExerciseAdjustmentService _adjustmentService =
      ExerciseAdjustmentService();
  final FeedbackService _feedbackService = FeedbackService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isProcessing = false;
  Map<String, dynamic>? _lastAnalysis;
  Map<String, dynamic>? _lastAdjustments;

  bool get isProcessing => _isProcessing;
  Map<String, dynamic>? get lastAnalysis => _lastAnalysis;
  Map<String, dynamic>? get lastAdjustments => _lastAdjustments;

  // 🚀 MAIN INTEGRATION POINT: Complete exercise feedback processing with real-time AI
  Future<Map<String, dynamic>> processExerciseCompletion({
    required ExerciseFeedback feedback,
    required String? planId,
  }) async {
    try {
      _isProcessing = true;
      notifyListeners();

      print('🚀 Starting complete exercise processing pipeline...');

      final result = <String, dynamic>{
        'feedbackSubmitted': false,
        'aiAnalysisCompleted': false,
        'adjustmentsApplied': false,
        'progressUpdated': false,
        'aiAnalysis': null,
        'adjustments': null,
        'recommendations': [],
        'errors': [],
      };

      // Step 1: Submit feedback to Firestore
      try {
        await _feedbackService.submitExerciseFeedback(feedback);
        result['feedbackSubmitted'] = true;
        print('✅ Step 1: Feedback submitted to Firestore');
      } catch (e) {
        result['errors'].add('Failed to submit feedback: $e');
        print('❌ Step 1 failed: $e');
      }

      // Step 2: Send to AI backend for analysis
      try {
        final aiAnalysis = await _sendToAIAnalysis(feedback);
        if (aiAnalysis != null) {
          _lastAnalysis = aiAnalysis;
          result['aiAnalysis'] = aiAnalysis;
          result['aiAnalysisCompleted'] = true;
          result['recommendations'] = aiAnalysis['recommendations'] ?? [];
          print('✅ Step 2: AI analysis completed');
        }
      } catch (e) {
        result['errors'].add('AI analysis failed: $e');
        print('❌ Step 2 failed: $e');
      }

      // Step 3: Apply real-time adjustments if plan is available
      if (planId != null && result['aiAnalysisCompleted']) {
        try {
          final adjustmentsApplied = await _applyRealtimeAdjustments(
            feedback: feedback,
            planId: planId,
            aiAnalysis: result['aiAnalysis'],
          );

          if (adjustmentsApplied != null) {
            _lastAdjustments = adjustmentsApplied;
            result['adjustments'] = adjustmentsApplied;
            result['adjustmentsApplied'] = true;
            print('✅ Step 3: Real-time adjustments applied');
          }
        } catch (e) {
          result['errors'].add('Adjustment application failed: $e');
          print('❌ Step 3 failed: $e');
        }
      }

      // Step 4: Update progress logs
      try {
        await _updateProgressLogs(feedback, result['aiAnalysis']);
        result['progressUpdated'] = true;
        print('✅ Step 4: Progress logs updated');
      } catch (e) {
        result['errors'].add('Progress update failed: $e');
        print('❌ Step 4 failed: $e');
      }

      // Step 5: Generate contextual insights
      try {
        final insights = await _generateContextualInsights(feedback, result);
        result['insights'] = insights;
        print('✅ Step 5: Contextual insights generated');
      } catch (e) {
        result['errors'].add('Insights generation failed: $e');
        print('❌ Step 5 failed: $e');
      }

      print('🎯 Exercise completion processing pipeline finished');
      return result;
    } catch (e) {
      print('❌ Critical error in exercise completion processing: $e');
      return {
        'feedbackSubmitted': false,
        'aiAnalysisCompleted': false,
        'adjustmentsApplied': false,
        'progressUpdated': false,
        'errors': ['Critical processing error: $e'],
      };
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  // 🧠 Send feedback to AI backend for comprehensive analysis
  Future<Map<String, dynamic>?> _sendToAIAnalysis(
      ExerciseFeedback feedback) async {
    try {
      print('🧠 Sending feedback to AI backend...');

      // Convert feedback to JSON-serializable format
      final feedbackData = {
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
        'notes': feedback.notes,
        'userId': feedback.userId,
      };

      // Send to AI backend
      final response =
          await _rehabilitationService.analyzeFeedback(feedbackData);

      if (response['analysis'] != null) {
        final analysis = response['analysis'];

        // Log key metrics
        final effectivenessScore = analysis['effectiveness_score'] ?? 0.0;
        final painBeneficial =
            analysis['pain_analysis']?['is_beneficial'] ?? false;

        print('🎯 AI Analysis Results:');
        print(
            '   Effectiveness: ${(effectivenessScore * 100).toStringAsFixed(1)}%');
        print('   Pain beneficial: $painBeneficial');
        print(
            '   Recommendations: ${(analysis['recommendations'] as List?)?.length ?? 0}');

        return analysis;
      }

      return null;
    } catch (e) {
      print('❌ Error in AI analysis: $e');
      return null;
    }
  }

  // 🔧 Apply real-time adjustments based on AI analysis
  Future<Map<String, dynamic>?> _applyRealtimeAdjustments({
    required ExerciseFeedback feedback,
    required String planId,
    Map<String, dynamic>? aiAnalysis,
  }) async {
    try {
      print('🔧 Applying real-time adjustments...');

      // Create feedback data for adjustment service
      final feedbackData = {
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

      // Process adjustments through the adjustment service
      await _adjustmentService.processPostExerciseAdjustments(
        userId: feedback.userId,
        planId: planId,
        exerciseId: feedback.exerciseId,
        feedbackData: feedbackData,
      );

      // Check if adjustments were actually applied
      final adjustmentHistory = await _adjustmentService.getAdjustmentHistory(
        feedback.userId,
        feedback.exerciseId,
      );

      if (adjustmentHistory.isNotEmpty) {
        final latestAdjustment = adjustmentHistory.first;
        final adjustmentTime = latestAdjustment['timestamp'] as Timestamp?;

        if (adjustmentTime != null) {
          final timeDiff =
              DateTime.now().difference(adjustmentTime.toDate()).inMinutes;

          // If adjustment was made in the last 2 minutes, it's from this session
          if (timeDiff < 2) {
            print('✅ Real-time adjustments confirmed');
            return {
              'adjustments': latestAdjustment['adjustments'],
              'reason': latestAdjustment['reason'],
              'adjustmentType': latestAdjustment['adjustmentType'],
              'timestamp': adjustmentTime.toDate().toIso8601String(),
            };
          }
        }
      }

      print('📊 No adjustments applied this session');
      return null;
    } catch (e) {
      print('❌ Error applying real-time adjustments: $e');
      return null;
    }
  }

  // 📊 Update progress logs with AI analysis data
  Future<void> _updateProgressLogs(
      ExerciseFeedback feedback, Map<String, dynamic>? aiAnalysis) async {
    try {
      print('📊 Updating progress logs...');

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Check for existing progress log today
      final existingLogs = await _firestore
          .collection('progressLogs')
          .where('userId', isEqualTo: feedback.userId)
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
        'timestamp': feedback.timestamp.toIso8601String(),
        // Add AI analysis data
        'aiEffectivenessScore': aiAnalysis?['effectiveness_score'],
        'aiRecommendationsCount':
            (aiAnalysis?['recommendations'] as List?)?.length ?? 0,
        'aiPainBeneficial': aiAnalysis?['pain_analysis']?['is_beneficial'],
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
          'aiAnalysisCount': FieldValue.increment(1),
        });
      } else {
        // Create new progress log
        await _firestore.collection('progressLogs').add({
          'userId': feedback.userId,
          'date': FieldValue.serverTimestamp(),
          'exerciseLogs': [exerciseLogData],
          'lastUpdated': FieldValue.serverTimestamp(),
          'aiAnalysisCount': 1,
        });
      }

      print('✅ Progress logs updated with AI analysis data');
    } catch (e) {
      print('❌ Error updating progress logs: $e');
      rethrow;
    }
  }

  // 💡 Generate contextual insights based on feedback and AI analysis
  Future<Map<String, dynamic>> _generateContextualInsights(
    ExerciseFeedback feedback,
    Map<String, dynamic> processResult,
  ) async {
    try {
      print('💡 Generating contextual insights...');

      final insights = <String, dynamic>{
        'sessionSummary': {},
        'progressInsights': [],
        'nextSessionRecommendations': [],
        'warningFlags': [],
        'achievements': [],
      };

      // Generate session summary
      insights['sessionSummary'] = {
        'painChange': feedback.painLevelAfter - feedback.painLevelBefore,
        'completionRate': feedback.completionPercentage,
        'difficultyAppropriate': feedback.difficultyRating == 'perfect',
        'overallPerformance': _calculateOverallPerformance(feedback),
        'effectivenessScore':
            processResult['aiAnalysis']?['effectiveness_score'] ?? 0.0,
      };

      // Generate progress insights
      final progressInsights = await _generateProgressInsights(feedback);
      insights['progressInsights'] = progressInsights;

      // Generate next session recommendations
      final nextSessionRecs =
          _generateNextSessionRecommendations(feedback, processResult);
      insights['nextSessionRecommendations'] = nextSessionRecs;

      // Check for warning flags
      final warnings = _checkWarningFlags(feedback, processResult);
      insights['warningFlags'] = warnings;

      // Identify achievements
      final achievements = _identifyAchievements(feedback, processResult);
      insights['achievements'] = achievements;

      return insights;
    } catch (e) {
      print('❌ Error generating contextual insights: $e');
      return {};
    }
  }

  // 📈 Generate progress insights by comparing with historical data
  Future<List<String>> _generateProgressInsights(
      ExerciseFeedback feedback) async {
    try {
      List<String> insights = [];

      // Get recent feedback for this exercise
      final recentFeedback = await _firestore
          .collection('exerciseFeedbacks')
          .where('userId', isEqualTo: feedback.userId)
          .where('exerciseId', isEqualTo: feedback.exerciseId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      if (recentFeedback.docs.length > 1) {
        final feedbacks = recentFeedback.docs.map((doc) => doc.data()).toList();

        // Analyze pain trend
        final painLevels =
            feedbacks.map((f) => f['painLevelAfter'] as int).toList();
        if (painLevels.length >= 3) {
          final recentAvg = painLevels.take(2).reduce((a, b) => a + b) / 2;
          final olderAvg = painLevels.skip(2).reduce((a, b) => a + b) /
              (painLevels.length - 2);

          if (recentAvg < olderAvg - 1) {
            insights.add('Pain levels are decreasing - excellent progress!');
          } else if (recentAvg > olderAvg + 1) {
            insights
                .add('Pain levels have increased - consider taking it easier');
          }
        }

        // Analyze completion trend
        final completionRates = feedbacks.map((f) {
          final completed = f['completedSets'] * f['completedReps'];
          final target = f['targetSets'] * f['targetReps'];
          return completed / target;
        }).toList();

        if (completionRates.length >= 3) {
          final recentAvg = completionRates.take(2).reduce((a, b) => a + b) / 2;
          final olderAvg = completionRates.skip(2).reduce((a, b) => a + b) /
              (completionRates.length - 2);

          if (recentAvg > olderAvg + 0.1) {
            insights.add('Completion rates are improving consistently');
          } else if (recentAvg < olderAvg - 0.1) {
            insights.add('Consider reducing exercise intensity');
          }
        }

        // Analyze difficulty consistency
        final difficultyRatings =
            feedbacks.map((f) => f['difficultyRating'] as String).toList();
        final perfectCount =
            difficultyRatings.where((d) => d == 'perfect').length;
        final easyCount = difficultyRatings.where((d) => d == 'easy').length;
        final hardCount = difficultyRatings.where((d) => d == 'hard').length;

        if (easyCount >= difficultyRatings.length * 0.6) {
          insights.add('Exercise is becoming too easy - ready for progression');
        } else if (hardCount >= difficultyRatings.length * 0.6) {
          insights.add(
              'Exercise remains challenging - focus on form and consistency');
        } else if (perfectCount >= difficultyRatings.length * 0.6) {
          insights.add(
              'Difficulty level is well-balanced for your current ability');
        }
      }

      return insights;
    } catch (e) {
      print('❌ Error generating progress insights: $e');
      return [];
    }
  }

  // 🎯 Generate recommendations for next session
  List<String> _generateNextSessionRecommendations(
    ExerciseFeedback feedback,
    Map<String, dynamic> processResult,
  ) {
    List<String> recommendations = [];

    // AI recommendations
    final aiRecs = processResult['aiAnalysis']?['recommendations'] as List?;
    if (aiRecs != null && aiRecs.isNotEmpty) {
      recommendations.addAll(aiRecs.cast<String>().take(2));
    }

    // Pain-based recommendations
    final painChange = feedback.painLevelAfter - feedback.painLevelBefore;
    if (painChange > 2) {
      recommendations
          .add('Consider warming up longer and starting more gently next time');
    } else if (painChange < -2) {
      recommendations
          .add('Great pain reduction! You can maintain this intensity');
    }

    // Completion-based recommendations
    if (feedback.completionPercentage < 0.7) {
      recommendations.add('Focus on completing fewer reps with better form');
    } else if (feedback.completionPercentage > 0.95) {
      recommendations
          .add('Consider adding an extra set or increasing resistance');
    }

    // Difficulty-based recommendations
    switch (feedback.difficultyRating) {
      case 'easy':
        recommendations
            .add('Try increasing the intensity or duration next session');
        break;
      case 'hard':
        recommendations
            .add('Take extra rest between sets and focus on proper form');
        break;
      case 'perfect':
        recommendations
            .add('Maintain this difficulty level - it\'s working well for you');
        break;
    }

    // Adjustment-based recommendations
    if (processResult['adjustmentsApplied'] == true) {
      recommendations.add(
          'Your next session has been automatically adjusted based on today\'s performance');
    }

    return recommendations.take(4).toList(); // Limit to top 4 recommendations
  }

  // ⚠️ Check for warning flags that need attention
  List<String> _checkWarningFlags(
      ExerciseFeedback feedback, Map<String, dynamic> processResult) {
    List<String> warnings = [];

    // High pain level warning
    if (feedback.painLevelAfter >= 8) {
      warnings
          .add('High pain level detected - consider consulting your therapist');
    }

    // Significant pain increase warning
    final painIncrease = feedback.painLevelAfter - feedback.painLevelBefore;
    if (painIncrease >= 3) {
      warnings.add(
          'Significant pain increase during exercise - may need modification');
    }

    // Low completion rate warning
    if (feedback.completionPercentage < 0.5) {
      warnings.add('Low completion rate - exercise may be too challenging');
    }

    // Consistently hard difficulty warning
    if (feedback.difficultyRating == 'hard' &&
        feedback.completionPercentage < 0.7) {
      warnings.add('Exercise difficulty is too high for current ability level');
    }

    // AI effectiveness warning
    final effectivenessScore =
        processResult['aiAnalysis']?['effectiveness_score'] ?? 1.0;
    if (effectivenessScore < 0.3) {
      warnings.add('Exercise effectiveness is low - review with therapist');
    }

    return warnings;
  }

  // 🏆 Identify achievements and positive milestones
  List<String> _identifyAchievements(
      ExerciseFeedback feedback, Map<String, dynamic> processResult) {
    List<String> achievements = [];

    // Perfect completion achievement
    if (feedback.completionPercentage >= 1.0) {
      achievements.add('Perfect completion! You finished all sets and reps');
    }

    // Pain reduction achievement
    final painReduction = feedback.painLevelBefore - feedback.painLevelAfter;
    if (painReduction >= 2) {
      achievements.add('Significant pain reduction achieved during exercise');
    }

    // Perfect difficulty achievement
    if (feedback.difficultyRating == 'perfect' &&
        feedback.completionPercentage >= 0.9) {
      achievements.add('Optimal difficulty level with excellent completion');
    }

    // Duration achievement
    if (feedback.actualDurationSeconds >= feedback.targetDurationSeconds) {
      achievements.add('Full duration completed - great endurance!');
    }

    // AI effectiveness achievement
    final effectivenessScore =
        processResult['aiAnalysis']?['effectiveness_score'] ?? 0.0;
    if (effectivenessScore >= 0.8) {
      achievements.add('High exercise effectiveness score from AI analysis');
    }

    // Consistency achievement (would need more complex tracking)
    // This could be enhanced with streak tracking

    return achievements;
  }

  // 📊 Calculate overall performance score
  double _calculateOverallPerformance(ExerciseFeedback feedback) {
    double score = 0.5; // Base score

    // Completion contribution (30%)
    score += (feedback.completionPercentage * 0.3);

    // Pain management contribution (25%)
    final painChange = feedback.painLevelAfter - feedback.painLevelBefore;
    if (painChange <= 0) {
      score += 0.25; // No pain increase
    } else if (painChange <= 1) {
      score += 0.15; // Slight pain increase
    } else {
      score -= 0.1; // Significant pain increase
    }

    // Difficulty appropriateness contribution (25%)
    switch (feedback.difficultyRating) {
      case 'perfect':
        score += 0.25;
        break;
      case 'easy':
        score += 0.15;
        break;
      case 'hard':
        score += 0.1;
        break;
    }

    // Duration completion contribution (20%)
    final durationCompletion =
        feedback.actualDurationSeconds / feedback.targetDurationSeconds;
    if (durationCompletion >= 0.8 && durationCompletion <= 1.2) {
      score += 0.2;
    } else if (durationCompletion >= 0.6) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  // 📱 Get real-time insights for display in UI
  Future<Map<String, dynamic>> getRealtimeInsights(
      String userId, String exerciseId) async {
    try {
      // Get recent feedback for this exercise
      final recentFeedback = await _firestore
          .collection('exerciseFeedbacks')
          .where('userId', isEqualTo: userId)
          .where('exerciseId', isEqualTo: exerciseId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (recentFeedback.docs.isEmpty) {
        return {'hasData': false};
      }

      final latestFeedback = recentFeedback.docs.first.data();

      // Get recent adjustments
      final recentAdjustments =
          await _adjustmentService.getAdjustmentHistory(userId, exerciseId);

      // Get AI analytics
      final aiAnalytics = await _rehabilitationService.getExerciseInsights(
        userId: userId,
        exerciseId: exerciseId,
      );

      return {
        'hasData': true,
        'lastFeedback': latestFeedback,
        'recentAdjustments': recentAdjustments.take(3).toList(),
        'aiInsights': aiAnalytics,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting realtime insights: $e');
      return {'hasData': false, 'error': e.toString()};
    }
  }

  // 🔔 Create notification data for user alerts
  Map<String, dynamic> createNotificationData(
      Map<String, dynamic> processResult) {
    final notifications = <Map<String, dynamic>>[];

    // AI analysis completion notification
    if (processResult['aiAnalysisCompleted'] == true) {
      final effectivenessScore =
          processResult['aiAnalysis']?['effectiveness_score'] ?? 0.0;
      notifications.add({
        'type': 'ai_analysis_complete',
        'title': 'AI Analysis Complete',
        'message':
            'Exercise effectiveness: ${(effectivenessScore * 100).toStringAsFixed(0)}%',
        'priority': 'normal',
      });
    }

    // Adjustments applied notification
    if (processResult['adjustmentsApplied'] == true) {
      notifications.add({
        'type': 'adjustments_applied',
        'title': 'Exercise Adjusted',
        'message': 'Your next session has been automatically optimized',
        'priority': 'high',
      });
    }

    // Warning notifications
    final warnings = processResult['insights']?['warningFlags'] as List? ?? [];
    for (final warning in warnings) {
      notifications.add({
        'type': 'warning',
        'title': 'Attention Needed',
        'message': warning.toString(),
        'priority': 'urgent',
      });
    }

    // Achievement notifications
    final achievements =
        processResult['insights']?['achievements'] as List? ?? [];
    if (achievements.isNotEmpty) {
      notifications.add({
        'type': 'achievement',
        'title': 'Great Job!',
        'message': achievements.first.toString(),
        'priority': 'positive',
      });
    }

    return {
      'notifications': notifications,
      'hasUrgent': notifications.any((n) => n['priority'] == 'urgent'),
      'hasPositive': notifications.any((n) => n['priority'] == 'positive'),
    };
  }

  // 🧹 Clean up old data and maintain performance
  Future<void> performMaintenance(String userId) async {
    try {
      print('🧹 Performing maintenance for user: $userId');

      // Clean up old feedback data (keep last 100 entries per exercise)
      final exerciseGroups = await _firestore
          .collection('exerciseFeedbacks')
          .where('userId', isEqualTo: userId)
          .get();

      final exerciseIds = <String>{};
      for (final doc in exerciseGroups.docs) {
        exerciseIds.add(doc.data()['exerciseId'] as String);
      }

      for (final exerciseId in exerciseIds) {
        final oldFeedback = await _firestore
            .collection('exerciseFeedbacks')
            .where('userId', isEqualTo: userId)
            .where('exerciseId', isEqualTo: exerciseId)
            .orderBy('timestamp', descending: true)
            .get();

        if (oldFeedback.docs.length > 100) {
          final toDelete = oldFeedback.docs.skip(100);
          final batch = _firestore.batch();

          for (final doc in toDelete) {
            batch.delete(doc.reference);
          }

          await batch.commit();
          print(
              '🗑️ Cleaned up ${toDelete.length} old feedback entries for exercise: $exerciseId');
        }
      }

      // Clean up old adjustment logs (keep last 50 per exercise)
      for (final exerciseId in exerciseIds) {
        final oldAdjustments = await _firestore
            .collection('exerciseAdjustments')
            .where('userId', isEqualTo: userId)
            .where('exerciseId', isEqualTo: exerciseId)
            .orderBy('timestamp', descending: true)
            .get();

        if (oldAdjustments.docs.length > 50) {
          final toDelete = oldAdjustments.docs.skip(50);
          final batch = _firestore.batch();

          for (final doc in toDelete) {
            batch.delete(doc.reference);
          }

          await batch.commit();
          print(
              '🗑️ Cleaned up ${toDelete.length} old adjustment entries for exercise: $exerciseId');
        }
      }

      print('✅ Maintenance completed for user: $userId');
    } catch (e) {
      print('❌ Error during maintenance: $e');
    }
  }
}
