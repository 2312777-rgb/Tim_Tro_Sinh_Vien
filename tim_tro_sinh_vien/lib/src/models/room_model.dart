import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String id;
  final String title;
  final String description;
  final double price;
  final String address;
  final String district;
  final List<String> imageUrls;
  final String ownerId;
  final DateTime createdAt;
  final String type; // 'room' hoặc 'roommate'

  RoomModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.address,
    required this.district,
    required this.imageUrls,
    required this.ownerId,
    required this.createdAt,
    required this.type,
  });

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return RoomModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      address: data['address'] ?? '',
      district: data['district'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      ownerId: data['ownerId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      type: data['type'] ?? 'room',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'address': address,
      'district': district,
      'imageUrls': imageUrls,
      'ownerId': ownerId,
      'createdAt': createdAt,
      'type': type,
    };
  }
}
