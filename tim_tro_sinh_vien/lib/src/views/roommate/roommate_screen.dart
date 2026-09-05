import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../inbox/chat_detail_screen.dart';

class RoommateRequest {
  final String id;
  final String name;
  final String? photoUrl;
  final String gender;
  final String school;
  final String bio;
  final double budget;
  final String userId;
  final List<String> traits;

  RoommateRequest({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.gender,
    required this.school,
    required this.bio,
    required this.budget,
    required this.userId,
    required this.traits,
  });
}

class ShopTab extends StatelessWidget {
  const ShopTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Tìm bạn ở ghép', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('roommate_requests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Đã xảy ra lỗi'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Chưa có tin tìm bạn.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final roommate = RoommateRequest(
                id: docs[index].id,
                name: data['name'] ?? 'Người dùng',
                photoUrl: data['photoUrl'],
                gender: data['gender'] ?? 'Nam',
                school: data['school'] ?? '',
                bio: data['bio'] ?? '',
                budget: (data['budget'] ?? 0).toDouble(),
                userId: data['userId'] ?? '',
                traits: List<String>.from(data['traits'] ?? []),
              );
              return _buildRoommateCard(context, roommate);
            },
          );
        },
      ),
    );
  }

  Widget _buildRoommateCard(BuildContext context, RoommateRequest roommate) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: roommate.photoUrl != null ? NetworkImage(roommate.photoUrl!) : null,
                  child: roommate.photoUrl == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(roommate.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(roommate.school, style: const TextStyle(color: Colors.blue, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _startChat(context, roommate),
                  child: const Text('Nhắn tin'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(roommate.bio),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.payments, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${(roommate.budget / 1000000).toStringAsFixed(1)} Tr/tháng', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(roommate.gender),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _startChat(BuildContext context, RoommateRequest roommate) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == roommate.userId) return;

    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    String? chatId;
    for (var doc in chatQuery.docs) {
      List participants = doc['participants'];
      if (participants.contains(roommate.userId)) {
        chatId = doc.id;
        break;
      }
    }

    if (chatId == null) {
      final newChat = await FirebaseFirestore.instance.collection('chats').add({
        'participants': [currentUser.uid, roommate.userId],
        'participantNames': {
          currentUser.uid: currentUser.displayName ?? 'Người dùng',
          roommate.userId: roommate.name,
        },
        'participantPhotos': {
          currentUser.uid: currentUser.photoURL,
          roommate.userId: roommate.photoUrl,
        },
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
      chatId = newChat.id;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(chatId: chatId!, otherUserName: roommate.name),
        ),
      );
    }
  }
}
