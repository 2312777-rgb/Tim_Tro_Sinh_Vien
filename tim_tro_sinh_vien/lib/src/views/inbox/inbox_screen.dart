import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chat_detail_screen.dart';

class InboxTab extends StatelessWidget {
  const InboxTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Hộp thư', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser?.uid)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Đã xảy ra lỗi'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final chatDocs = snapshot.data!.docs;
          if (chatDocs.isEmpty) {
            return const Center(child: Text('Chưa có tin nhắn nào', style: TextStyle(color: Colors.grey)));
          }

          return ListView.separated(
            itemCount: chatDocs.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
            itemBuilder: (context, index) {
              final chatData = chatDocs[index].data() as Map<String, dynamic>;
              final participantIds = List<String>.from(chatData['participants']);
              final otherUserId = participantIds.firstWhere((id) => id != currentUser?.uid);
              final otherUserName = chatData['participantNames'][otherUserId] ?? 'Người dùng';
              final otherUserPhoto = chatData['participantPhotos'][otherUserId];
              final lastMessage = chatData['lastMessage'] ?? '';
              final lastTime = chatData['lastMessageTime'] as Timestamp?;

              return ListTile(
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  backgroundImage: otherUserPhoto != null ? NetworkImage(otherUserPhoto) : null,
                  child: otherUserPhoto == null ? const Icon(Icons.person, color: Colors.blue) : null,
                ),
                title: Text(otherUserName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(
                  lastTime != null ? DateFormat('HH:mm').format(lastTime.toDate()) : '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailPage(
                        chatId: chatDocs[index].id,
                        otherUserName: otherUserName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
