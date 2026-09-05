import 'package:cloud_firestore/cloud_firestore.dart';

class RoommateModel {
  final String id;
  final String name;
  final String? photoUrl;
  final String gender;
  final String school;
  final String bio;
  final double budget;
  final String userId;
  final List<String> traits;
  final DateTime createdAt;

  RoommateModel({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.gender,
    required this.school,
    required this.bio,
    required this.budget,
    required this.userId,
    required this.traits,
    required this.createdAt,
  });

  factory RoommateModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return RoommateModel(
      id: doc.id,
      name: data['name'] ?? 'Người dùng',
      photoUrl: data['photoUrl'],
      gender: data['gender'] ?? 'Nam',
      school: data['school'] ?? '',
      bio: data['bio'] ?? '',
      budget: (data['budget'] ?? 0).toDouble(),
      userId: data['userId'] ?? '',
      traits: List<String>.from(data['traits'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'gender': gender,
      'school': school,
      'bio': bio,
      'budget': budget,
      'userId': userId,
      'traits': traits,
      'createdAt': createdAt,
    };
  }
}
