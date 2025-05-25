// lib/models/progress_model.dart (Enhanced Version)
import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseLog {
  final String exerciseId;
  final String exerciseName;
  final int setsCompleted;
  final int repsCompleted;
  final int durationSeconds;
  final int painLevel; // 0-10 scale (post-exercise)
  final int? prePainLevel; // 0-10 scale (pre-exercise) - NEW
  final String? difficultyRating; // 'easy', 'perfect', 'hard' - NEW
  final String? notes;
  final double? completionPercentage; // NEW
  final Map<String, dynamic>? additionalMetrics; // NEW

  ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.setsCompleted,
    required this.repsCompleted,
    required this.durationSeconds,
    required this.painLevel,
    this.prePainLevel,
    this.difficultyRating,
    this.notes,
    this.completionPercentage,
    this.additionalMetrics,
  });

  factory ExerciseLog.fromMap(Map<String, dynamic> data) {
    return ExerciseLog(
      exerciseId: data['exerciseId'] ?? '',
      exerciseName: data['exerciseName'] ?? '',
      setsCompleted: data['setsCompleted'] ?? 0,
      repsCompleted: data['repsCompleted'] ?? 0,
      durationSeconds: data['durationSeconds'] ?? 0,
      painLevel: data['painLevel'] ?? 0,
      prePainLevel: data['prePainLevel'],
      difficultyRating: data['difficultyRating'],
      notes: data['notes'],
      completionPercentage: data['completionPercentage']?.toDouble(),
      additionalMetrics: data['additionalMetrics'],
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
      'prePainLevel': prePainLevel,
      'difficultyRating': difficultyRating,
      'notes': notes,
      'completionPercentage': completionPercentage,
      'additionalMetrics': additionalMetrics,
    };
  }

  // Calculate pain change
  int? get painChange {
    if (prePainLevel != null) {
      return painLevel - prePainLevel!;
    }
    return null;
  }

  // Check if exercise was beneficial (pain decreased or stayed same)
  bool get wasBeneficial {
    if (painChange != null) {
      return painChange! <= 0;
    }
    return true; // Assume beneficial if no pre-pain data
  }

  // Get difficulty score for analysis
  int get difficultyScore {
    switch (difficultyRating?.toLowerCase()) {
      case 'easy':
        return 1;
      case 'perfect':
        return 2;
      case 'hard':
        return 3;
      default:
        return 2;
    }
  }
}

class ProgressModel {
  final String id;
  final String userId;
  final String planId;
  final DateTime date;
  final List<ExerciseLog> exerciseLogs;
  final Map<String, dynamic>? metrics;
  final String? feedback;
  final int overallRating; // 0-5 scale
  final int adherencePercentage; // 0-100
  final double? sessionSatisfaction; // 1-5 scale - NEW
  final int? totalSessionDuration; // in minutes - NEW
  final Map<String, dynamic>? environmentalFactors; // NEW
  final List<String>? recommendations; // AI-generated recommendations - NEW

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
    this.sessionSatisfaction,
    this.totalSessionDuration,
    this.environmentalFactors,
    this.recommendations,
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
      sessionSatisfaction: data['sessionSatisfaction']?.toDouble(),
      totalSessionDuration: data['totalSessionDuration'],
      environmentalFactors: data['environmentalFactors'],
      recommendations: data['recommendations'] != null
          ? List<String>.from(data['recommendations'])
          : null,
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
      'sessionSatisfaction': sessionSatisfaction,
      'totalSessionDuration': totalSessionDuration,
      'environmentalFactors': environmentalFactors,
      'recommendations': recommendations,
    };
  }

  // Calculate session averages
  double get averagePrePainLevel {
    final validLogs = exerciseLogs.where((log) => log.prePainLevel != null);
    if (validLogs.isEmpty) return 0.0;
    return validLogs.map((log) => log.prePainLevel!).reduce((a, b) => a + b) /
        validLogs.length;
  }

  double get averagePostPainLevel {
    if (exerciseLogs.isEmpty) return 0.0;
    return exerciseLogs.map((log) => log.painLevel).reduce((a, b) => a + b) /
        exerciseLogs.length;
  }

  double get averagePainChange {
    final validChanges = exerciseLogs
        .where((log) => log.painChange != null)
        .map((log) => log.painChange!)
        .toList();
    if (validChanges.isEmpty) return 0.0;
    return validChanges.reduce((a, b) => a + b) / validChanges.length;
  }

  Map<String, int> get difficultyDistribution {
    Map<String, int> distribution = {'easy': 0, 'perfect': 0, 'hard': 0};
    for (var log in exerciseLogs) {
      if (log.difficultyRating != null) {
        distribution[log.difficultyRating!] =
            (distribution[log.difficultyRating!] ?? 0) + 1;
      }
    }
    return distribution;
  }

  int get exercisesBeneficial {
    return exerciseLogs.where((log) => log.wasBeneficial).length;
  }

  double get averageCompletionRate {
    final validCompletions = exerciseLogs
        .where((log) => log.completionPercentage != null)
        .map((log) => log.completionPercentage!)
        .toList();
    if (validCompletions.isEmpty) return 0.0;
    return validCompletions.reduce((a, b) => a + b) / validCompletions.length;
  }
}

class ProgressSummary {
  final String planId;
  final DateTime startDate;
  final DateTime endDate;
  final double averagePainLevel;
  final double averageAdherence;
  final int totalSessionsCompleted;
  final Map<String, dynamic> metricsProgress;
  final double averagePainImprovement; // NEW
  final Map<String, int> difficultyTrends; // NEW
  final double overallEffectiveness; // NEW
  final List<String> keyInsights; // NEW

  ProgressSummary({
    required this.planId,
    required this.startDate,
    required this.endDate,
    required this.averagePainLevel,
    required this.averageAdherence,
    required this.totalSessionsCompleted,
    required this.metricsProgress,
    required this.averagePainImprovement,
    required this.difficultyTrends,
    required this.overallEffectiveness,
    required this.keyInsights,
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
        averagePainImprovement: 0,
        difficultyTrends: {'easy': 0, 'perfect': 0, 'hard': 0},
        overallEffectiveness: 0,
        keyInsights: [],
      );
    }

    // Sort logs by date
    logs.sort((a, b) => a.date.compareTo(b.date));

    double totalPain = 0;
    double totalAdherence = 0;
    double totalPainImprovement = 0;
    int painImprovementCount = 0;
    Map<String, List<dynamic>> metricsValues = {};
    Map<String, int> difficultyTrends = {'easy': 0, 'perfect': 0, 'hard': 0};

    // Process logs
    for (var log in logs) {
      // Calculate average pain across all exercises in this log
      double logPain = log.averagePostPainLevel;
      totalPain += logPain;
      totalAdherence += log.adherencePercentage;

      // Track pain improvement
      if (log.averagePainChange != 0) {
        totalPainImprovement += log.averagePainChange;
        painImprovementCount++;
      }

      // Track difficulty trends
      final sessionDifficulty = log.difficultyDistribution;
      sessionDifficulty.forEach((key, value) {
        difficultyTrends[key] = (difficultyTrends[key] ?? 0) + value;
      });

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
        metricsProgress[key] = {
          'first': values.first,
          'latest': values.last,
          'improvement': values.last - values.first,
          'percentImprovement':
              ((values.last - values.first) / values.first) * 100,
        };
      }
    });

    final averagePainImprovement = painImprovementCount > 0
        ? totalPainImprovement / painImprovementCount
        : 0.0;

    // Calculate overall effectiveness
    final effectiveness = _calculateOverallEffectiveness(
      logs,
      averagePainImprovement,
      totalAdherence / logs.length,
    );

    // Generate key insights
    final insights = _generateKeyInsights(
      logs,
      averagePainImprovement,
      difficultyTrends,
      effectiveness,
    );

    return ProgressSummary(
      planId: planId,
      startDate: logs.first.date,
      endDate: logs.last.date,
      averagePainLevel: logs.isNotEmpty ? totalPain / logs.length : 0,
      averageAdherence: logs.isNotEmpty ? totalAdherence / logs.length : 0,
      totalSessionsCompleted: logs.length,
      metricsProgress: metricsProgress,
      averagePainImprovement: averagePainImprovement,
      difficultyTrends: difficultyTrends,
      overallEffectiveness: effectiveness,
      keyInsights: insights,
    );
  }

  static double _calculateOverallEffectiveness(
    List<ProgressModel> logs,
    double avgPainImprovement,
    double avgAdherence,
  ) {
    if (logs.isEmpty) return 0.0;

    double effectiveness = 0.5; // Base score

    // Pain improvement contribution (40%)
    if (avgPainImprovement < -1.0) {
      effectiveness += 0.4; // Significant improvement
    } else if (avgPainImprovement < 0) {
      effectiveness += 0.2; // Some improvement
    } else if (avgPainImprovement > 1.0) {
      effectiveness -= 0.3; // Pain worsening
    }

    // Adherence contribution (30%)
    if (avgAdherence >= 90) {
      effectiveness += 0.3;
    } else if (avgAdherence >= 70) {
      effectiveness += 0.2;
    } else if (avgAdherence >= 50) {
      effectiveness += 0.1;
    }

    // Consistency contribution (30%)
    final recentLogs = logs.length >= 7 ? logs.sublist(logs.length - 7) : logs;
    final consistency = recentLogs.length / 7.0; // Sessions per week
    if (consistency >= 0.8) {
      effectiveness += 0.3;
    } else if (consistency >= 0.6) {
      effectiveness += 0.2;
    } else if (consistency >= 0.4) {
      effectiveness += 0.1;
    }

    return effectiveness.clamp(0.0, 1.0);
  }

  static List<String> _generateKeyInsights(
    List<ProgressModel> logs,
    double avgPainImprovement,
    Map<String, int> difficultyTrends,
    double effectiveness,
  ) {
    List<String> insights = [];

    // Pain insights
    if (avgPainImprovement < -1.0) {
      insights.add(
          'Excellent pain reduction! Average improvement of ${avgPainImprovement.abs().toStringAsFixed(1)} points.');
    } else if (avgPainImprovement > 1.0) {
      insights.add(
          'Pain levels are increasing. Consider adjusting exercise intensity.');
    } else {
      insights.add('Pain levels are stable with slight improvement trend.');
    }

    // Difficulty insights
    final totalDifficulty = difficultyTrends.values.reduce((a, b) => a + b);
    if (totalDifficulty > 0) {
      final easyPercent = (difficultyTrends['easy']! / totalDifficulty) * 100;
      final hardPercent = (difficultyTrends['hard']! / totalDifficulty) * 100;

      if (easyPercent > 60) {
        insights.add(
            'Exercises seem too easy. Consider progression to maintain challenge.');
      } else if (hardPercent > 40) {
        insights.add(
            'Many exercises are challenging. Focus on form and gradual progression.');
      } else {
        insights.add('Exercise difficulty levels are well-balanced.');
      }
    }

    // Effectiveness insights
    if (effectiveness > 0.8) {
      insights.add('Rehabilitation program is highly effective!');
    } else if (effectiveness > 0.6) {
      insights.add('Good progress overall with room for improvement.');
    } else {
      insights
          .add('Consider discussing program adjustments with your therapist.');
    }

    // Session frequency insights
    if (logs.length >= 14) {
      final recentWeek = logs.where((log) =>
          log.date.isAfter(DateTime.now().subtract(const Duration(days: 7))));
      if (recentWeek.length >= 5) {
        insights.add(
            'Excellent consistency with ${recentWeek.length} sessions this week!');
      } else if (recentWeek.length >= 3) {
        insights
            .add('Good session frequency. Try to maintain regular schedule.');
      } else {
        insights
            .add('Consider increasing session frequency for better results.');
      }
    }

    return insights;
  }
}
