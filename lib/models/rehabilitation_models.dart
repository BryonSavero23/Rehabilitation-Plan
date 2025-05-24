// Updated RehabilitationData Model with proper data type handling
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
    // Ensure pain level is integer
    Map<String, dynamic> processedPhysicalCondition =
        Map.from(physicalCondition);

    if (processedPhysicalCondition.containsKey('painLevel')) {
      final painLevel = processedPhysicalCondition['painLevel'];
      if (painLevel is String) {
        try {
          processedPhysicalCondition['painLevel'] = int.parse(painLevel);
        } catch (e) {
          processedPhysicalCondition['painLevel'] = 5; // Default fallback
          print(
              'Warning: Could not parse pain level "$painLevel", using default value 5');
        }
      } else if (painLevel is double) {
        processedPhysicalCondition['painLevel'] = painLevel.round();
      }
      // Ensure pain level is within valid range
      processedPhysicalCondition['painLevel'] =
          (processedPhysicalCondition['painLevel'] as int).clamp(0, 10);
    }

    return {
      'medicalHistory': medicalHistory,
      'physicalCondition': processedPhysicalCondition,
      'rehabilitationGoals': rehabilitationGoals,
    };
  }

  factory RehabilitationData.fromJson(Map<String, dynamic> json) {
    return RehabilitationData(
      medicalHistory: Map<String, dynamic>.from(json['medicalHistory'] ?? {}),
      physicalCondition:
          Map<String, dynamic>.from(json['physicalCondition'] ?? {}),
      rehabilitationGoals: List<String>.from(json['rehabilitationGoals'] ?? []),
    );
  }
}

// Exercise Model - Enhanced with better validation
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
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Exercise',
      description:
          json['description']?.toString() ?? 'No description available',
      bodyPart: json['bodyPart']?.toString() ?? 'General',
      sets: _parseInt(json['sets'], 3),
      reps: _parseInt(json['reps'], 10),
      durationSeconds: _parseInt(json['durationSeconds'], 30),
      difficultyLevel: json['difficultyLevel']?.toString() ?? 'beginner',
      imageUrl: json['imageUrl']?.toString(),
      videoUrl: json['videoUrl']?.toString(),
      isCompleted: json['isCompleted'] == true,
    );
  }

  // Helper method to safely parse integers
  static int _parseInt(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        print(
            'Warning: Could not parse "$value" as int, using default $defaultValue');
        return defaultValue;
      }
    }
    return defaultValue;
  }
}

// Rehabilitation Plan Model - Enhanced with better validation
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
    List<Exercise> exerciseList = [];

    if (json['exercises'] is List) {
      exerciseList = (json['exercises'] as List)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return RehabilitationPlan(
      title: json['title']?.toString() ?? 'Rehabilitation Plan',
      description:
          json['description']?.toString() ?? 'No description available',
      exercises: exerciseList,
      goals: Map<String, dynamic>.from(json['goals'] ?? {}),
    );
  }

  get therapistId => null;
}
