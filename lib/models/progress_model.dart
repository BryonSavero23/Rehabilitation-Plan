import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseLog {
  final String exerciseId;
  final String exerciseName;
  final int setsCompleted;
  final int repsCompleted;
  final int durationSeconds;
  final int painLevel; // 0-10 scale
  final String? notes;

  ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.setsCompleted,
    required this.repsCompleted,
    required this.durationSeconds,
    required this.painLevel,
    this.notes,
  });

  factory ExerciseLog.fromMap(Map<String, dynamic> data) {
    return ExerciseLog(
      exerciseId: data['exerciseId'] ?? '',
      exerciseName: data['exerciseName'] ?? '',
      setsCompleted: data['setsCompleted'] ?? 0,
      repsCompleted: data['repsCompleted'] ?? 0,
      durationSeconds: data['durationSeconds'] ?? 0,
      painLevel: data['painLevel'] ?? 0,
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'setsCompleted': setsCompleted,
      'repsCompleted': repsCompleted,
      'durationSeconds': durationSeconds,
      'painLevel': painLevel,
      'notes': notes,
    };
  }
}

class ProgressModel {
  final String id;
  final String userId;
  final String planId;
  final DateTime date;
  final List<ExerciseLog> exerciseLogs;
  final Map<String, dynamic>?
      metrics; // Additional metrics like ROM, strength, etc.
  final String? feedback;
  final int overallRating; // 0-5 scale
  final int adherencePercentage; // 0-100

  ProgressModel({
    required this.id,
    required this.userId,
    required this.planId,
    required this.date,
    required this.exerciseLogs,
    this.metrics,
    this.feedback,
    required this.overallRating,
    required this.adherencePercentage,
  });

  factory ProgressModel.fromMap(Map<String, dynamic> data, String id) {
    List<ExerciseLog> logs = [];
    if (data['exerciseLogs'] != null) {
      for (var log in data['exerciseLogs']) {
        logs.add(ExerciseLog.fromMap(log));
      }
    }

    return ProgressModel(
      id: id,
      userId: data['userId'] ?? '',
      planId: data['planId'] ?? '',
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      exerciseLogs: logs,
      metrics: data['metrics'],
      feedback: data['feedback'],
      overallRating: data['overallRating'] ?? 0,
      adherencePercentage: data['adherencePercentage'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'planId': planId,
      'date': date,
      'exerciseLogs': exerciseLogs.map((log) => log.toMap()).toList(),
      'metrics': metrics,
      'feedback': feedback,
      'overallRating': overallRating,
      'adherencePercentage': adherencePercentage,
    };
  }
}

class ProgressSummary {
  final String planId;
  final DateTime startDate;
  final DateTime endDate;
  final double averagePainLevel;
  final double averageAdherence;
  final int totalSessionsCompleted;
  final Map<String, dynamic> metricsProgress; // Track improvement in metrics

  ProgressSummary({
    required this.planId,
    required this.startDate,
    required this.endDate,
    required this.averagePainLevel,
    required this.averageAdherence,
    required this.totalSessionsCompleted,
    required this.metricsProgress,
  });

  factory ProgressSummary.fromProgressLogs(
      List<ProgressModel> logs, String planId) {
    if (logs.isEmpty) {
      return ProgressSummary(
        planId: planId,
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        averagePainLevel: 0,
        averageAdherence: 0,
        totalSessionsCompleted: 0,
        metricsProgress: {},
      );
    }

    // Sort logs by date
    logs.sort((a, b) => a.date.compareTo(b.date));

    double totalPain = 0;
    double totalAdherence = 0;
    Map<String, List<dynamic>> metricsValues = {};

    // Process logs
    for (var log in logs) {
      // Calculate average pain across all exercises in this log
      double logPain = 0;
      for (var exercise in log.exerciseLogs) {
        logPain += exercise.painLevel;
      }
      logPain =
          log.exerciseLogs.isNotEmpty ? logPain / log.exerciseLogs.length : 0;

      totalPain += logPain;
      totalAdherence += log.adherencePercentage;

      // Track metrics
      if (log.metrics != null) {
        log.metrics!.forEach((key, value) {
          if (value is num) {
            if (!metricsValues.containsKey(key)) {
              metricsValues[key] = [];
            }
            metricsValues[key]!.add(value);
          }
        });
      }
    }

    // Calculate final summary values
    Map<String, dynamic> metricsProgress = {};
    metricsValues.forEach((key, values) {
      if (values.length >= 2) {
        // Calculate improvement (latest - first)
        metricsProgress[key] = {
          'first': values.first,
          'latest': values.last,
          'improvement': values.last - values.first,
          'percentImprovement':
              ((values.last - values.first) / values.first) * 100,
        };
      }
    });

    return ProgressSummary(
      planId: planId,
      startDate: logs.first.date,
      endDate: logs.last.date,
      averagePainLevel: logs.isNotEmpty ? totalPain / logs.length : 0,
      averageAdherence: logs.isNotEmpty ? totalAdherence / logs.length : 0,
      totalSessionsCompleted: logs.length,
      metricsProgress: metricsProgress,
    );
  }
}
