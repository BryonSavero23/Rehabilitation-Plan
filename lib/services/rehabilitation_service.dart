import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';

class RehabilitationService {
  // API endpoint - Use localhost for development
  static const String baseUrl = 'http://localhost:5000/api';

  // For Android emulator, use: 'http://10.0.2.2:5000/api'
  // For physical device, use your computer's IP: 'http://YOUR_IP:5000/api'

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
          .timeout(const Duration(seconds: 10));

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

  // Health check method
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      log("Health check failed: $e");
      return false;
    }
  }
}
