// lib/models/exercise_feedback_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseFeedback {
  final String id;
  final String userId;
  final String exerciseId;
  final String exerciseName;
  final int painLevelBefore;
  final int painLevelAfter;
  final String difficultyRating; // 'easy', 'perfect', 'hard'
  final int completedSets;
  final int completedReps;
  final int targetSets;
  final int targetReps;
  final int actualDurationSeconds;
  final int targetDurationSeconds;
  final String? notes;
  final bool completed;
  final DateTime timestamp;
  final Map<String, dynamic>? additionalMetrics;

  ExerciseFeedback({
    required this.id,
    required this.userId,
    required this.exerciseId,
    required this.exerciseName,
    required this.painLevelBefore,
    required this.painLevelAfter,
    required this.difficultyRating,
    required this.completedSets,
    required this.completedReps,
    required this.targetSets,
    required this.targetReps,
    required this.actualDurationSeconds,
    required this.targetDurationSeconds,
    this.notes,
    required this.completed,
    required this.timestamp,
    this.additionalMetrics,
  });

  factory ExerciseFeedback.fromMap(Map<String, dynamic> data, String id) {
    return ExerciseFeedback(
      id: id,
      userId: data['userId'] ?? '',
      exerciseId: data['exerciseId'] ?? '',
      exerciseName: data['exerciseName'] ?? '',
      painLevelBefore: data['painLevelBefore'] ?? 0,
      painLevelAfter: data['painLevelAfter'] ?? 0,
      difficultyRating: data['difficultyRating'] ?? 'perfect',
      completedSets: data['completedSets'] ?? 0,
      completedReps: data['completedReps'] ?? 0,
      targetSets: data['targetSets'] ?? 0,
      targetReps: data['targetReps'] ?? 0,
      actualDurationSeconds: data['actualDurationSeconds'] ?? 0,
      targetDurationSeconds: data['targetDurationSeconds'] ?? 0,
      notes: data['notes'],
      completed: data['completed'] ?? false,
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      additionalMetrics: data['additionalMetrics'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'painLevelBefore': painLevelBefore,
      'painLevelAfter': painLevelAfter,
      'difficultyRating': difficultyRating,
      'completedSets': completedSets,
      'completedReps': completedReps,
      'targetSets': targetSets,
      'targetReps': targetReps,
      'actualDurationSeconds': actualDurationSeconds,
      'targetDurationSeconds': targetDurationSeconds,
      'notes': notes,
      'completed': completed,
      'timestamp': timestamp,
      'additionalMetrics': additionalMetrics,
    };
  }

  // Calculate completion percentage
  double get completionPercentage {
    final setsCompletion = targetSets > 0 ? completedSets / targetSets : 0.0;
    final repsCompletion = targetReps > 0 ? completedReps / targetReps : 0.0;
    return ((setsCompletion + repsCompletion) / 2).clamp(0.0, 1.0);
  }

  // Calculate pain change
  int get painChange => painLevelAfter - painLevelBefore;

  // Check if exercise was beneficial (pain decreased or stayed same)
  bool get wasBeneficial => painChange <= 0;

  // Get difficulty score for analysis
  int get difficultyScore {
    switch (difficultyRating.toLowerCase()) {
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

class ExerciseSession {
  final String id;
  final String userId;
  final String planId;
  final List<ExerciseFeedback> exerciseFeedbacks;
  final DateTime sessionDate;
  final int totalDurationMinutes;
  final double overallSatisfaction; // 1-5 scale
  final String? sessionNotes;
  final Map<String, dynamic>? environmentalFactors; // weather, mood, etc.

  ExerciseSession({
    required this.id,
    required this.userId,
    required this.planId,
    required this.exerciseFeedbacks,
    required this.sessionDate,
    required this.totalDurationMinutes,
    required this.overallSatisfaction,
    this.sessionNotes,
    this.environmentalFactors,
  });

  factory ExerciseSession.fromMap(Map<String, dynamic> data, String id) {
    List<ExerciseFeedback> feedbacks = [];
    if (data['exerciseFeedbacks'] != null) {
      for (var feedback in data['exerciseFeedbacks']) {
        feedbacks.add(ExerciseFeedback.fromMap(
          feedback,
          feedback['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        ));
      }
    }

    return ExerciseSession(
      id: id,
      userId: data['userId'] ?? '',
      planId: data['planId'] ?? '',
      exerciseFeedbacks: feedbacks,
      sessionDate: data['sessionDate'] != null
          ? (data['sessionDate'] as Timestamp).toDate()
          : DateTime.now(),
      totalDurationMinutes: data['totalDurationMinutes'] ?? 0,
      overallSatisfaction: (data['overallSatisfaction'] ?? 3.0).toDouble(),
      sessionNotes: data['sessionNotes'],
      environmentalFactors: data['environmentalFactors'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'planId': planId,
      'exerciseFeedbacks': exerciseFeedbacks.map((f) => f.toMap()).toList(),
      'sessionDate': sessionDate,
      'totalDurationMinutes': totalDurationMinutes,
      'overallSatisfaction': overallSatisfaction,
      'sessionNotes': sessionNotes,
      'environmentalFactors': environmentalFactors,
    };
  }

  // Calculate session metrics
  double get averagePainBefore {
    if (exerciseFeedbacks.isEmpty) return 0.0;
    return exerciseFeedbacks
            .map((f) => f.painLevelBefore)
            .reduce((a, b) => a + b) /
        exerciseFeedbacks.length;
  }

  double get averagePainAfter {
    if (exerciseFeedbacks.isEmpty) return 0.0;
    return exerciseFeedbacks
            .map((f) => f.painLevelAfter)
            .reduce((a, b) => a + b) /
        exerciseFeedbacks.length;
  }

  double get averagePainChange {
    if (exerciseFeedbacks.isEmpty) return 0.0;
    return exerciseFeedbacks.map((f) => f.painChange).reduce((a, b) => a + b) /
        exerciseFeedbacks.length;
  }

  double get sessionCompletionRate {
    if (exerciseFeedbacks.isEmpty) return 0.0;
    return exerciseFeedbacks
            .map((f) => f.completionPercentage)
            .reduce((a, b) => a + b) /
        exerciseFeedbacks.length;
  }

  int get exercisesCompleted {
    return exerciseFeedbacks.where((f) => f.completed).length;
  }

  Map<String, int> get difficultyDistribution {
    Map<String, int> distribution = {'easy': 0, 'perfect': 0, 'hard': 0};
    for (var feedback in exerciseFeedbacks) {
      distribution[feedback.difficultyRating] =
          (distribution[feedback.difficultyRating] ?? 0) + 1;
    }
    return distribution;
  }
}
