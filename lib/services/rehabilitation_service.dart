import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';

class RehabilitationService {
  // API endpoint - Updated to use Render deployment
  static const String baseUrl =
      'https://rehabilitation-plan-2.onrender.com/api';

  // Generate rehabilitation plan based on user data
  Future<RehabilitationPlan> generatePlan(RehabilitationData data) async {
    try {
      // Convert to JSON and ensure proper data types
      final jsonData = data.toJson();

      // Debug: Log the data being sent
      log("🚀 Sending data to backend:");
      log("Pain Level: ${jsonData['physicalCondition']['painLevel']} (${jsonData['physicalCondition']['painLevel'].runtimeType})");
      log("Body Part: ${jsonData['physicalCondition']['bodyPart']}");

      // Make HTTP request to the backend
      final response = await http
          .post(
            Uri.parse('$baseUrl/generate_plan'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(jsonData),
          )
          .timeout(const Duration(
              seconds: 30)); // Increased timeout for first request

      log("📡 Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Debug: Log the received plan
        if (responseData['exercises'] != null &&
            responseData['exercises'].isNotEmpty) {
          final firstExercise = responseData['exercises'][0];
          log("✅ Generated plan - Sets: ${firstExercise['sets']}, Reps: ${firstExercise['reps']}, Difficulty: ${firstExercise['difficultyLevel']}");

          // Log plan description to verify pain level handling
          log("📋 Plan description: ${responseData['description']}");

          final painPriority = responseData['goals']?['painReduction'];
          log("🎯 Pain reduction priority: $painPriority");
        }

        return RehabilitationPlan.fromJson(responseData);
      } else {
        throw Exception(
            'Failed to generate plan: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      log("❌ Error in generatePlan: $e");
      throw Exception('Failed to generate plan: $e');
    }
  }

  // NEW: Analyze exercise feedback using the modularized backend
  Future<Map<String, dynamic>> analyzeFeedback(
      Map<String, dynamic> feedbackData) async {
    try {
      log("🧠 Sending feedback for AI analysis:");
      log("Exercise: ${feedbackData['exerciseName']}");
      log("Pain change: ${feedbackData['painLevelAfter']} - ${feedbackData['painLevelBefore']}");

      final response = await http
          .post(
            Uri.parse('$baseUrl/analyze_feedback'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'feedback': feedbackData}),
          )
          .timeout(const Duration(seconds: 15));

      log("📊 Feedback analysis response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Log AI recommendations
        if (responseData['analysis']?['recommendations'] != null) {
          final recommendations =
              responseData['analysis']['recommendations'] as List;
          log("🎯 AI Recommendations: $recommendations");
        }

        return responseData;
      } else {
        throw Exception(
            'Failed to analyze feedback: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      log("❌ Error in analyzeFeedback: $e");
      throw Exception('Failed to analyze feedback: $e');
    }
  }

  // NEW: Optimize exercise plan based on feedback history
  Future<Map<String, dynamic>> optimizePlan({
    required String userId,
    required String exerciseId,
    required List<Map<String, dynamic>> feedbackHistory,
  }) async {
    try {
      log("🔧 Optimizing plan for user: $userId, exercise: $exerciseId");

      final response = await http
          .post(
            Uri.parse('$baseUrl/optimize_plan'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'userId': userId,
              'exerciseId': exerciseId,
              'feedbackHistory': feedbackHistory,
            }),
          )
          .timeout(const Duration(seconds: 15));

      log("📈 Plan optimization response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Log optimization results
        if (responseData['optimized_parameters'] != null) {
          final params = responseData['optimized_parameters'];
          log("🎯 Optimized parameters: Sets: ${params['optimized_sets']}, Reps: ${params['optimized_reps']}");
        }

        return responseData;
      } else {
        throw Exception(
            'Failed to optimize plan: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      log("❌ Error in optimizePlan: $e");
      throw Exception('Failed to optimize plan: $e');
    }
  }

  // NEW: Get AI-powered user analytics
  Future<Map<String, dynamic>> getUserAnalytics({
    required String userId,
    int timePeriod = 30,
  }) async {
    try {
      log("📊 Getting AI analytics for user: $userId");

      final response = await http
          .post(
            Uri.parse('$baseUrl/user_analytics'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'userId': userId,
              'timePeriod': timePeriod,
            }),
          )
          .timeout(const Duration(seconds: 15));

      log("📈 User analytics response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['analytics'] ?? {};
      } else {
        log("⚠️ Analytics request failed: ${response.statusCode}");
        return {};
      }
    } catch (e) {
      log("❌ Error in getUserAnalytics: $e");
      return {};
    }
  }

  // NEW: Get feedback trends
  Future<Map<String, dynamic>> getFeedbackTrends({
    required String userId,
    int daysBack = 30,
  }) async {
    try {
      log("📈 Getting feedback trends for user: $userId");

      final response = await http
          .post(
            Uri.parse('$baseUrl/feedback_trends'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'userId': userId,
              'daysBack': daysBack,
            }),
          )
          .timeout(const Duration(seconds: 15));

      log("📊 Feedback trends response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['trends'] ?? {};
      } else {
        log("⚠️ Trends request failed: ${response.statusCode}");
        return {};
      }
    } catch (e) {
      log("❌ Error in getFeedbackTrends: $e");
      return {};
    }
  }

  // NEW: Get exercise-specific insights
  Future<Map<String, dynamic>> getExerciseInsights({
    required String userId,
    required String exerciseId,
  }) async {
    try {
      log("🎯 Getting exercise insights for: $exerciseId");

      final response = await http
          .post(
            Uri.parse('$baseUrl/exercise_insights'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'userId': userId,
              'exerciseId': exerciseId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      log("📈 Exercise insights response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['insights'] ?? {};
      } else {
        log("⚠️ Exercise insights request failed: ${response.statusCode}");
        return {};
      }
    } catch (e) {
      log("❌ Error in getExerciseInsights: $e");
      return {};
    }
  }

  // Health check method
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(
          const Duration(seconds: 30)); // Increased timeout for first request

      return response.statusCode == 200;
    } catch (e) {
      log("Health check failed: $e");
      return false;
    }
  }

  // NEW: Get model metrics (for debugging/monitoring)
  Future<Map<String, dynamic>> getModelMetrics() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/model_metrics'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'Failed to get model metrics'};
      }
    } catch (e) {
      log("Error getting model metrics: $e");
      return {'error': e.toString()};
    }
  }
}
