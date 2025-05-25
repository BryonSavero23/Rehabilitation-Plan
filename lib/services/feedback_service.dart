// lib/services/feedback_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:personalized_rehabilitation_plans/models/exercise_feedback_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FeedbackService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  // Submit exercise feedback
  Future<void> submitExerciseFeedback(ExerciseFeedback feedback) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('exerciseFeedbacks').add(feedback.toMap());

      // Send to backend for analysis
      await _sendToBackendAnalysis(feedback);
    } catch (e) {
      print('Error submitting exercise feedback: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get user's exercise feedback history
  Future<List<ExerciseFeedback>> getUserFeedbackHistory(
    String userId, {
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      Query query = _firestore
          .collection('exerciseFeedbacks')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true);

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs
          .map((doc) => ExerciseFeedback.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error getting user feedback history: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get feedback for a specific exercise
  Future<List<ExerciseFeedback>> getExerciseFeedback(
    String userId,
    String exerciseId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('exerciseFeedbacks')
          .where('userId', isEqualTo: userId)
          .where('exerciseId', isEqualTo: exerciseId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ExerciseFeedback.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting exercise feedback: $e');
      return [];
    }
  }

  // Analyze user's feedback patterns
  Future<Map<String, dynamic>> analyzeFeedbackPatterns(String userId) async {
    try {
      final feedbacks = await getUserFeedbackHistory(userId, limit: 100);

      if (feedbacks.isEmpty) {
        return {
          'totalSessions': 0,
          'averagePainBefore': 0.0,
          'averagePainAfter': 0.0,
          'averagePainChange': 0.0,
          'difficultyDistribution': {'easy': 0, 'perfect': 0, 'hard': 0},
          'completionRate': 0.0,
          'improvementTrend': 'stable',
          'recommendations': [],
        };
      }

      final totalSessions = feedbacks.length;
      final averagePainBefore =
          feedbacks.map((f) => f.painLevelBefore).reduce((a, b) => a + b) /
              totalSessions;
      final averagePainAfter =
          feedbacks.map((f) => f.painLevelAfter).reduce((a, b) => a + b) /
              totalSessions;
      final averagePainChange =
          feedbacks.map((f) => f.painChange).reduce((a, b) => a + b) /
              totalSessions;

      // Calculate difficulty distribution
      Map<String, int> difficultyDistribution = {
        'easy': 0,
        'perfect': 0,
        'hard': 0
      };
      for (var feedback in feedbacks) {
        difficultyDistribution[feedback.difficultyRating] =
            (difficultyDistribution[feedback.difficultyRating] ?? 0) + 1;
      }

      // Calculate completion rate
      final completionRate =
          feedbacks.map((f) => f.completionPercentage).reduce((a, b) => a + b) /
              totalSessions;

      // Analyze improvement trend
      final improvementTrend = _analyzeImprovementTrend(feedbacks);

      // Generate recommendations
      final recommendations = _generateRecommendations(
        feedbacks,
        averagePainChange,
        difficultyDistribution,
        completionRate,
      );

      return {
        'totalSessions': totalSessions,
        'averagePainBefore': averagePainBefore,
        'averagePainAfter': averagePainAfter,
        'averagePainChange': averagePainChange,
        'difficultyDistribution': difficultyDistribution,
        'completionRate': completionRate,
        'improvementTrend': improvementTrend,
        'recommendations': recommendations,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error analyzing feedback patterns: $e');
      return {};
    }
  }

  // Get exercise-specific insights
  Future<Map<String, dynamic>> getExerciseInsights(
    String userId,
    String exerciseId,
  ) async {
    try {
      final feedbacks = await getExerciseFeedback(userId, exerciseId);

      if (feedbacks.isEmpty) {
        return {
          'totalAttempts': 0,
          'averageCompletion': 0.0,
          'painTrend': 'no_data',
          'difficultyTrend': 'no_data',
          'recommendations': [],
        };
      }

      final totalAttempts = feedbacks.length;
      final averageCompletion =
          feedbacks.map((f) => f.completionPercentage).reduce((a, b) => a + b) /
              totalAttempts;

      // Analyze trends over time
      final painTrend = _analyzePainTrendForExercise(feedbacks);
      final difficultyTrend = _analyzeDifficultyTrendForExercise(feedbacks);

      // Get latest feedback
      final latestFeedback = feedbacks.first;

      return {
        'totalAttempts': totalAttempts,
        'averageCompletion': averageCompletion,
        'painTrend': painTrend,
        'difficultyTrend': difficultyTrend,
        'latestPainLevel': latestFeedback.painLevelAfter,
        'latestDifficulty': latestFeedback.difficultyRating,
        'lastPerformed': latestFeedback.timestamp.toIso8601String(),
        'recommendations': _generateExerciseSpecificRecommendations(feedbacks),
      };
    } catch (e) {
      print('Error getting exercise insights: $e');
      return {};
    }
  }

  // Submit session feedback
  Future<void> submitSessionFeedback(ExerciseSession session) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('exerciseSessions').add(session.toMap());

      // Also submit individual exercise feedbacks
      for (var feedback in session.exerciseFeedbacks) {
        await submitExerciseFeedback(feedback);
      }
    } catch (e) {
      print('Error submitting session feedback: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get real-time feedback stream
  Stream<List<ExerciseFeedback>> getFeedbackStream(String userId) {
    return _firestore
        .collection('exerciseFeedbacks')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExerciseFeedback.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Private helper methods

  String _analyzeImprovementTrend(List<ExerciseFeedback> feedbacks) {
    if (feedbacks.length < 3) return 'insufficient_data';

    // Take last 10 sessions for trend analysis
    final recentFeedbacks = feedbacks.take(10).toList();
    final olderFeedbacks = feedbacks.skip(10).take(10).toList();

    if (olderFeedbacks.isEmpty) return 'insufficient_data';

    final recentAvgPain =
        recentFeedbacks.map((f) => f.painLevelAfter).reduce((a, b) => a + b) /
            recentFeedbacks.length;
    final olderAvgPain =
        olderFeedbacks.map((f) => f.painLevelAfter).reduce((a, b) => a + b) /
            olderFeedbacks.length;

    final painDifference = recentAvgPain - olderAvgPain;

    if (painDifference < -1.0) return 'improving';
    if (painDifference > 1.0) return 'declining';
    return 'stable';
  }

  String _analyzePainTrendForExercise(List<ExerciseFeedback> feedbacks) {
    if (feedbacks.length < 3) return 'insufficient_data';

    final painChanges = feedbacks.map((f) => f.painChange).toList();
    final averageChange =
        painChanges.reduce((a, b) => a + b) / painChanges.length;

    if (averageChange < -0.5) return 'improving';
    if (averageChange > 0.5) return 'worsening';
    return 'stable';
  }

  String _analyzeDifficultyTrendForExercise(List<ExerciseFeedback> feedbacks) {
    if (feedbacks.length < 3) return 'insufficient_data';

    final recentDifficulties =
        feedbacks.take(5).map((f) => f.difficultyScore).toList();
    final averageDifficulty =
        recentDifficulties.reduce((a, b) => a + b) / recentDifficulties.length;

    if (averageDifficulty < 1.5) return 'too_easy';
    if (averageDifficulty > 2.5) return 'too_hard';
    return 'appropriate';
  }

  List<String> _generateRecommendations(
    List<ExerciseFeedback> feedbacks,
    double averagePainChange,
    Map<String, int> difficultyDistribution,
    double completionRate,
  ) {
    List<String> recommendations = [];

    // Pain-based recommendations
    if (averagePainChange > 1.0) {
      recommendations.add(
          'Consider reducing exercise intensity as pain levels are increasing');
    } else if (averagePainChange < -1.0) {
      recommendations
          .add('Great progress! Pain levels are decreasing consistently');
    }

    // Difficulty-based recommendations
    final totalExercises =
        difficultyDistribution.values.reduce((a, b) => a + b);
    final easyPercentage =
        (difficultyDistribution['easy']! / totalExercises) * 100;
    final hardPercentage =
        (difficultyDistribution['hard']! / totalExercises) * 100;

    if (easyPercentage > 60) {
      recommendations
          .add('Consider increasing exercise difficulty for better progress');
    } else if (hardPercentage > 40) {
      recommendations
          .add('Consider reducing exercise difficulty to prevent overexertion');
    }

    // Completion-based recommendations
    if (completionRate < 0.7) {
      recommendations.add(
          'Focus on completing prescribed sets and reps for optimal results');
    } else if (completionRate > 0.95) {
      recommendations.add(
          'Excellent adherence! You might be ready for more challenging exercises');
    }

    return recommendations;
  }

  List<String> _generateExerciseSpecificRecommendations(
      List<ExerciseFeedback> feedbacks) {
    List<String> recommendations = [];

    if (feedbacks.isEmpty) return recommendations;

    final latestFeedback = feedbacks.first;
    final painTrend = _analyzePainTrendForExercise(feedbacks);
    final difficultyTrend = _analyzeDifficultyTrendForExercise(feedbacks);

    // Pain-specific recommendations
    if (latestFeedback.painChange > 2) {
      recommendations.add(
          'This exercise may be causing increased pain. Consider modifying or skipping.');
    } else if (latestFeedback.painChange < -2) {
      recommendations.add(
          'This exercise is helping reduce pain significantly. Continue as prescribed.');
    }

    // Difficulty-specific recommendations
    if (difficultyTrend == 'too_easy') {
      recommendations.add(
          'Consider increasing sets, reps, or resistance for this exercise.');
    } else if (difficultyTrend == 'too_hard') {
      recommendations.add(
          'Consider reducing intensity or breaking this exercise into smaller segments.');
    }

    // Completion-specific recommendations
    if (latestFeedback.completionPercentage < 0.5) {
      recommendations.add(
          'Focus on proper form rather than completing all reps if struggling.');
    }

    return recommendations;
  }

  // Send feedback to backend for ML analysis
  Future<void> _sendToBackendAnalysis(ExerciseFeedback feedback) async {
    try {
      // This integrates with your Flask backend
      const String baseUrl =
          'http://localhost:5000/api'; // Update with your backend URL

      final response = await http
          .post(
            Uri.parse('$baseUrl/analyze_feedback'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'feedback': feedback.toMap(),
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Backend analysis response: $responseData');

        // Handle any recommendations or adjustments from backend
        if (responseData['recommendations'] != null) {
          await _storeBERecommendations(
              feedback.userId, responseData['recommendations']);
        }
      } else {
        print('Backend analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending feedback to backend: $e');
      // Don't throw error here as feedback submission should still succeed
    }
  }

  // Store backend recommendations
  Future<void> _storeBERecommendations(
      String userId, List<dynamic> recommendations) async {
    try {
      await _firestore.collection('userRecommendations').add({
        'userId': userId,
        'recommendations': recommendations,
        'source': 'ml_analysis',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Error storing backend recommendations: $e');
    }
  }

  // Get therapy progress analytics
  Future<Map<String, dynamic>> getTherapyProgressAnalytics(
      String userId) async {
    try {
      final feedbacks = await getUserFeedbackHistory(userId, limit: 200);

      if (feedbacks.isEmpty) {
        return {'hasData': false};
      }

      // Group by week for trend analysis
      Map<String, List<ExerciseFeedback>> weeklyData = {};
      for (var feedback in feedbacks) {
        final weekKey = _getWeekKey(feedback.timestamp);
        weeklyData.putIfAbsent(weekKey, () => []).add(feedback);
      }

      // Calculate weekly metrics
      List<Map<String, dynamic>> weeklyMetrics = [];
      for (var entry in weeklyData.entries) {
        final weekFeedbacks = entry.value;
        final avgPainBefore = weekFeedbacks
                .map((f) => f.painLevelBefore)
                .reduce((a, b) => a + b) /
            weekFeedbacks.length;
        final avgPainAfter =
            weekFeedbacks.map((f) => f.painLevelAfter).reduce((a, b) => a + b) /
                weekFeedbacks.length;
        final avgCompletion = weekFeedbacks
                .map((f) => f.completionPercentage)
                .reduce((a, b) => a + b) /
            weekFeedbacks.length;

        weeklyMetrics.add({
          'week': entry.key,
          'sessions': weekFeedbacks.length,
          'avgPainBefore': avgPainBefore,
          'avgPainAfter': avgPainAfter,
          'avgPainChange': avgPainAfter - avgPainBefore,
          'avgCompletion': avgCompletion,
        });
      }

      // Sort by week
      weeklyMetrics.sort((a, b) => a['week'].compareTo(b['week']));

      return {
        'hasData': true,
        'totalSessions': feedbacks.length,
        'weeklyMetrics': weeklyMetrics,
        'overallTrend': _calculateOverallTrend(weeklyMetrics),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting therapy progress analytics: $e');
      return {'hasData': false, 'error': e.toString()};
    }
  }

  String _getWeekKey(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final daysSinceStartOfYear = date.difference(startOfYear).inDays;
    final weekNumber = (daysSinceStartOfYear / 7).floor() + 1;
    return '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _calculateOverallTrend(
      List<Map<String, dynamic>> weeklyMetrics) {
    if (weeklyMetrics.length < 3) {
      return {'trend': 'insufficient_data'};
    }

    final recentWeeks = weeklyMetrics.skip(weeklyMetrics.length - 4).toList();
    final olderWeeks = weeklyMetrics.take(weeklyMetrics.length - 4).toList();

    if (olderWeeks.isEmpty) {
      return {'trend': 'insufficient_data'};
    }

    final recentAvgPain = recentWeeks
            .map((w) => w['avgPainAfter'] as double)
            .reduce((a, b) => a + b) /
        recentWeeks.length;
    final olderAvgPain = olderWeeks
            .map((w) => w['avgPainAfter'] as double)
            .reduce((a, b) => a + b) /
        olderWeeks.length;

    final painImprovement = olderAvgPain - recentAvgPain;

    final recentCompletion = recentWeeks
            .map((w) => w['avgCompletion'] as double)
            .reduce((a, b) => a + b) /
        recentWeeks.length;
    final olderCompletion = olderWeeks
            .map((w) => w['avgCompletion'] as double)
            .reduce((a, b) => a + b) /
        olderWeeks.length;

    final completionImprovement = recentCompletion - olderCompletion;

    String overallTrend;
    if (painImprovement > 1.0 && completionImprovement > 0.1) {
      overallTrend = 'excellent_progress';
    } else if (painImprovement > 0.5 || completionImprovement > 0.05) {
      overallTrend = 'good_progress';
    } else if (painImprovement < -1.0 || completionImprovement < -0.1) {
      overallTrend = 'needs_attention';
    } else {
      overallTrend = 'stable';
    }

    return {
      'trend': overallTrend,
      'painImprovement': painImprovement,
      'completionImprovement': completionImprovement,
      'recentAvgPain': recentAvgPain,
      'recentCompletion': recentCompletion,
    };
  }
}
