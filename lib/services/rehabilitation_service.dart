import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';

class RehabilitationService {
  // API endpoint
  static const String baseUrl = 'http://10.213.71.196:5000/api';

  // Generate rehabilitation plan based on user data
  Future<RehabilitationPlan> generatePlan(RehabilitationData data) async {
    try {
      // Make HTTP request to the backend
      final response = await http.post(
        Uri.parse('$baseUrl/generate_plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data.toJson()),
      );

      log("Response: ${response.statusCode}");

      if (response.statusCode == 200) {
        return RehabilitationPlan.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to generate plan: ${response.statusCode}');
      }
    } catch (e) {
      log("Error: $e");
      throw Exception('Failed to generate plan: $e');
    }
  }
}
