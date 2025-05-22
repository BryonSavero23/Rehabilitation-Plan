// User Rehabilitation Data Model
class RehabilitationData {
  final Map<String, dynamic> medicalHistory;
  final Map<String, dynamic> physicalCondition;
  final List<String> rehabilitationGoals;

  RehabilitationData({
    required this.medicalHistory,
    required this.physicalCondition,
    required this.rehabilitationGoals,
  });

  Map<String, dynamic> toJson() {
    return {
      'medicalHistory': medicalHistory,
      'physicalCondition': physicalCondition,
      'rehabilitationGoals': rehabilitationGoals,
    };
  }

  factory RehabilitationData.fromJson(Map<String, dynamic> json) {
    return RehabilitationData(
      medicalHistory: json['medicalHistory'],
      physicalCondition: json['physicalCondition'],
      rehabilitationGoals: List<String>.from(json['rehabilitationGoals']),
    );
  }
}

// Exercise Model
class Exercise {
  final String id;
  final String name;
  final String description;
  final String bodyPart;
  final int sets;
  final int reps;
  final int durationSeconds;
  final String difficultyLevel;
  final String? imageUrl;
  final String? videoUrl;
  bool isCompleted;

  Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.bodyPart,
    required this.sets,
    required this.reps,
    required this.durationSeconds,
    required this.difficultyLevel,
    this.imageUrl,
    this.videoUrl,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'bodyPart': bodyPart,
      'sets': sets,
      'reps': reps,
      'durationSeconds': durationSeconds,
      'difficultyLevel': difficultyLevel,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'isCompleted': isCompleted,
    };
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      bodyPart: json['bodyPart'],
      sets: json['sets'],
      reps: json['reps'],
      durationSeconds: json['durationSeconds'],
      difficultyLevel: json['difficultyLevel'],
      imageUrl: json['imageUrl'],
      videoUrl: json['videoUrl'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

// Rehabilitation Plan Model
class RehabilitationPlan {
  final String title;
  final String description;
  final List<Exercise> exercises;
  final Map<String, dynamic> goals;

  RehabilitationPlan({
    required this.title,
    required this.description,
    required this.exercises,
    required this.goals,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'goals': goals,
    };
  }

  factory RehabilitationPlan.fromJson(Map<String, dynamic> json) {
    return RehabilitationPlan(
      title: json['title'],
      description: json['description'],
      exercises:
          (json['exercises'] as List).map((e) => Exercise.fromJson(e)).toList(),
      goals: json['goals'],
    );
  }

  get therapistId => null;
}
