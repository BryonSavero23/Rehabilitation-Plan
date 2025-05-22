class UserModel {
  final String id;
  final String email;
  String name;
  final String? profileImageUrl;
  final DateTime createdAt;
  bool isTherapist;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.profileImageUrl,
    required this.createdAt,
    this.isTherapist = false,
  });

  // Convert UserModel to Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt,
      'isTherapist': isTherapist,
    };
  }

  // Create UserModel from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      isTherapist: map['isTherapist'] ?? false,
    );
  }

  // Create a copy of UserModel with some changes
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? profileImageUrl,
    DateTime? createdAt,
    bool? isTherapist,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      isTherapist: isTherapist ?? this.isTherapist,
    );
  }
}
