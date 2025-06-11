// lib/services/ai_service.dart
import 'package:flutter/foundation.dart';
import 'package:personalized_rehabilitation_plans/services/rehabilitation_service.dart';
import 'package:personalized_rehabilitation_plans/models/exercise_feedback_model.dart';

class AIService extends ChangeNotifier {
  final RehabilitationService _rehabilitationService = RehabilitationService();
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  // Get AI-powered exercise recommendations
  Future<List<String>> getExerciseRecommendations(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final analytics =
          await _rehabilitationService.getUserAnalytics(userId: userId);

      if (analytics['recommendations'] != null) {
        return List<String>.from(analytics['recommendations']);
      }

      return [];
    } catch (e) {
      print('Error getting AI recommendations: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get comprehensive progress insights powered by AI
  Future<Map<String, dynamic>> getProgressInsights(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final analytics =
          await _rehabilitationService.getUserAnalytics(userId: userId);

      return {
        'summary': analytics['summary'] ?? {},
        'pain_analytics': analytics['pain_analytics'] ?? {},
        'difficulty_analytics': analytics['difficulty_analytics'] ?? {},
        'completion_analytics': analytics['completion_analytics'] ?? {},
        'goals_progress': analytics['goals_progress'] ?? {},
        'recommendations': analytics['recommendations'] ?? [],
      };
    } catch (e) {
      print('Error getting progress insights: $e');
      return {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Determine if user should progress to higher difficulty
  Future<bool> shouldProgressDifficulty(
      String userId, String exerciseId) async {
    try {
      final insights = await _rehabilitationService.getExerciseInsights(
        userId: userId,
        exerciseId: exerciseId,
      );

      // AI logic to determine progression readiness
      final averageCompletion = insights['average_completion'] ?? 0.0;
      final difficultyTrend = insights['difficulty_trend'] ?? 'stable';
      final painImprovement = insights['pain_improvement'] ?? 0.0;

      // User is ready to progress if:
      // 1. High completion rate (>90%)
      // 2. Exercise is becoming too easy
      // 3. Pain is improving (negative value)
      return averageCompletion > 0.9 &&
          difficultyTrend == 'stable' &&
          painImprovement < -1.0;
    } catch (e) {
      print('Error determining progression readiness: $e');
      return false;
    }
  }

  // Get personalized feedback trends
  Future<Map<String, dynamic>> getFeedbackTrends(String userId,
      {int daysBack = 30}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final trends = await _rehabilitationService.getFeedbackTrends(
        userId: userId,
        daysBack: daysBack,
      );

      return trends;
    } catch (e) {
      print('Error getting feedback trends: $e');
      return {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Analyze single exercise feedback and get instant recommendations
  Future<Map<String, dynamic>> analyzeExerciseFeedback(
      ExerciseFeedback feedback) async {
    try {
      final analysis =
          await _rehabilitationService.analyzeFeedback(feedback.toMap());

      return analysis['analysis'] ?? {};
    } catch (e) {
      print('Error analyzing exercise feedback: $e');
      return {};
    }
  }

  // Get optimal exercise parameters based on user history
  Future<Map<String, dynamic>> getOptimalExerciseParameters({
    required String userId,
    required String exerciseId,
    required List<ExerciseFeedback> feedbackHistory,
  }) async {
    try {
      // Convert feedback history to maps
      final feedbackMaps = feedbackHistory.map((f) => f.toMap()).toList();

      final optimization = await _rehabilitationService.optimizePlan(
        userId: userId,
        exerciseId: exerciseId,
        feedbackHistory: feedbackMaps,
      );

      return optimization['optimized_parameters'] ?? {};
    } catch (e) {
      print('Error getting optimal parameters: $e');
      return {};
    }
  }

  // Get AI-powered exercise insights
  Future<Map<String, dynamic>> getExerciseInsights(
      String userId, String exerciseId) async {
    try {
      return await _rehabilitationService.getExerciseInsights(
        userId: userId,
        exerciseId: exerciseId,
      );
    } catch (e) {
      print('Error getting exercise insights: $e');
      return {};
    }
  }

  // Check if AI backend is healthy
  Future<bool> checkAIHealth() async {
    try {
      return await _rehabilitationService.checkHealth();
    } catch (e) {
      print('AI health check failed: $e');
      return false;
    }
  }

  // Get model performance metrics (for debugging)
  Future<Map<String, dynamic>> getModelMetrics() async {
    try {
      return await _rehabilitationService.getModelMetrics();
    } catch (e) {
      print('Error getting model metrics: $e');
      return {};
    }
  }

  // Generate contextual recommendations based on current state
  List<String> generateContextualRecommendations({
    required double painLevel,
    required String difficultyRating,
    required double completionRate,
    required int sessionsThisWeek,
  }) {
    List<String> recommendations = [];

    // Pain-based recommendations
    if (painLevel > 7) {
      recommendations.add('Consider taking a rest day due to high pain levels');
    } else if (painLevel < 3) {
      recommendations.add(
          'Great progress with pain management! Consider gentle progression');
    }

    // Difficulty-based recommendations
    if (difficultyRating == 'easy' && completionRate > 0.9) {
      recommendations.add('You\'re ready for more challenging exercises');
    } else if (difficultyRating == 'hard' && completionRate < 0.7) {
      recommendations.add('Focus on form rather than completing all reps');
    }

    // Frequency-based recommendations
    if (sessionsThisWeek < 3) {
      recommendations
          .add('Try to increase your exercise frequency for better results');
    } else if (sessionsThisWeek > 6) {
      recommendations.add('Great consistency! Make sure to include rest days');
    }

    return recommendations;
  }
}
