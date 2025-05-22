import 'package:cloud_firestore/cloud_firestore.dart';

class Exercise {
  final String id;
  final String name;
  final String description;
  final String bodyPart;
  final String? imageUrl;
  final String? videoUrl;
  final int sets;
  final int reps;
  final int durationSeconds;
  final String difficultyLevel; // 'beginner', 'intermediate', 'advanced'

  Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.bodyPart,
    this.imageUrl,
    this.videoUrl,
    required this.sets,
    required this.reps,
    required this.durationSeconds,
    required this.difficultyLevel,
  });

  factory Exercise.fromMap(Map<String, dynamic> data, String id) {
    return Exercise(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      bodyPart: data['bodyPart'] ?? '',
      imageUrl: data['imageUrl'],
      videoUrl: data['videoUrl'],
      sets: data['sets'] ?? 0,
      reps: data['reps'] ?? 0,
      durationSeconds: data['durationSeconds'] ?? 0,
      difficultyLevel: data['difficultyLevel'] ?? 'beginner',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'bodyPart': bodyPart,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'sets': sets,
      'reps': reps,
      'durationSeconds': durationSeconds,
      'difficultyLevel': difficultyLevel,
    };
  }
}

class RehabilitationPlanModel {
  final String id;
  final String userId;
  final String? therapistId;
  final String title;
  final String description;
  final List<Exercise> exercises;
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // 'active', 'completed', 'paused'
  final Map<String, dynamic>? goals;
  final DateTime lastUpdated;
  final bool isDynamicallyAdjusted;

  RehabilitationPlanModel({
    required this.id,
    required this.userId,
    this.therapistId,
    required this.title,
    required this.description,
    required this.exercises,
    required this.startDate,
    this.endDate,
    required this.status,
    this.goals,
    required this.lastUpdated,
    this.isDynamicallyAdjusted = true,
  });

  factory RehabilitationPlanModel.fromMap(
      Map<String, dynamic> data, String id) {
    List<Exercise> exerciseList = [];
    if (data['exercises'] != null) {
      for (var exercise in data['exercises']) {
        exerciseList.add(Exercise.fromMap(
          exercise,
          exercise['id'] ?? '',
        ));
      }
    }

    return RehabilitationPlanModel(
      id: id,
      userId: data['userId'] ?? '',
      therapistId: data['therapistId'],
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      exercises: exerciseList,
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      status: data['status'] ?? 'active',
      goals: data['goals'],
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
      isDynamicallyAdjusted: data['isDynamicallyAdjusted'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'therapistId': therapistId,
      'title': title,
      'description': description,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'startDate': startDate,
      'endDate': endDate,
      'status': status,
      'goals': goals,
      'lastUpdated': lastUpdated,
      'isDynamicallyAdjusted': isDynamicallyAdjusted,
    };
  }

  RehabilitationPlanModel copyWith({
    String? title,
    String? description,
    List<Exercise>? exercises,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    Map<String, dynamic>? goals,
    bool? isDynamicallyAdjusted,
    required DateTime lastUpdated,
  }) {
    return RehabilitationPlanModel(
      id: id,
      userId: userId,
      therapistId: therapistId,
      title: title ?? this.title,
      description: description ?? this.description,
      exercises: exercises ?? this.exercises,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      goals: goals ?? this.goals,
      lastUpdated: DateTime.now(),
      isDynamicallyAdjusted:
          isDynamicallyAdjusted ?? this.isDynamicallyAdjusted,
    );
  }
}
