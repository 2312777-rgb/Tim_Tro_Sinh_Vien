import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../inbox/chat_detail_screen.dart';

class Room {
  final String id;
  final String title;
  final String address;
  final double price;
  final String imageUrl;
  final String description;
  final String ownerName;
  final String? ownerId;
  final String? ownerPhotoUrl;
  final int likes;
  final int comments;

  Room({
    required this.id,
    required this.title,
    required this.address,
    required this.price,
    required this.imageUrl,
    required this.description,
    required this.ownerName,
    this.ownerId,
    this.ownerPhotoUrl,
    this.likes = 0,
    this.comments = 0,
  });
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String selectedDistrict = 'Tất cả';
  RangeValues priceRange = const RangeValues(0, 20000000);
  
  final List<String> districts = [
    'Tất cả', 'Quận 1', 'Quận 3', 'Quận 4', 'Quận 5', 'Quận 7', 'Quận 8', 'Quận 10', 
    'Bình Thạnh', 'Gò Vấp', 'Tân Bình', 'Thủ Đức'
  ];

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bộ lọc tìm kiếm', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('Khu vực', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: districts.map((d) => ChoiceChip(
                  label: Text(d),
                  selected: selectedDistrict == d,
                  onSelected: (s) {
                    setModalState(() => selectedDistrict = d);
                    setState(() {});
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),
              const Text('Giá (VNĐ)', style: TextStyle(fontWeight: FontWeight.bold)),
              RangeSlider(
                values: priceRange,
                min: 0, max: 20000000,
                divisions: 20,
                labels: RangeLabels(
                  '${(priceRange.start / 1000000).toStringAsFixed(1)}Tr',
                  '${(priceRange.end / 1000000).toStringAsFixed(1)}Tr',
                ),
                onChanged: (v) {
                  setModalState(() => priceRange = v);
                  setState(() {});
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: const Text('ÁP DỤNG'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('rooms').orderBy('createdAt', descending: true);
    
    // Áp dụng lọc nếu không phải "Tất cả"
    // Lưu ý: Firebase Firestore yêu cầu index cho việc kết hợp orderBy và where trên các trường khác nhau
    // Tạm thời chỉ dùng stream cơ bản, sau này sẽ nâng cấp query
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Đã xảy ra lỗi'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              var roomDocs = snapshot.data!.docs;
              
              // Lọc thủ công (Client-side) cho đơn giản bước đầu
              var filteredDocs = roomDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final price = (data['price'] ?? 0).toDouble();
                final district = data['district'] ?? '';
                
                bool matchesDistrict = selectedDistrict == 'Tất cả' || district.contains(selectedDistrict);
                bool matchesPrice = price >= priceRange.start && price <= priceRange.end;
                
                return matchesDistrict && matchesPrice;
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(child: Text('Không tìm thấy phòng phù hợp.'));
              }

              return PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = filteredDocs[index].data() as Map<String, dynamic>;
                  final room = Room(
                    id: filteredDocs[index].id,
                    title: data['title'] ?? '',
                    address: data['address'] ?? '',
                    price: (data['price'] ?? 0).toDouble(),
                    imageUrl: data['imageUrl'] ?? 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=500&q=80',
                    description: data['description'] ?? '',
                    ownerName: data['ownerName'] ?? 'Người dùng',
                    ownerPhotoUrl: data['ownerPhotoUrl'],
                    ownerId: data['ownerId'],
                    likes: data['likes'] ?? 0,
                    comments: data['comments'] ?? 0,
                  );
                  return RoomVideoCard(room: room);
                },
              );
            },
          ),
          Positioned(
            top: 50, left: 20, right: 20,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: 'Tìm theo khu vực, trường học...',
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: Colors.blue),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _showFilterSheet,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: const Icon(Icons.tune_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoomVideoCard extends StatefulWidget {
  final Room room;
  const RoomVideoCard({super.key, required this.room});

  @override
  State<RoomVideoCard> createState() => _RoomVideoCardState();
}

class _RoomVideoCardState extends State<RoomVideoCard> {
  bool isLiked = false;

  void _startChat() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == widget.room.ownerId) return;

    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    String? chatId;
    for (var doc in chatQuery.docs) {
      List participants = doc['participants'];
      if (participants.contains(widget.room.ownerId)) {
        chatId = doc.id;
        break;
      }
    }

    if (chatId == null) {
      final newChat = await FirebaseFirestore.instance.collection('chats').add({
        'participants': [currentUser.uid, widget.room.ownerId],
        'participantNames': {
          currentUser.uid: currentUser.displayName ?? 'Người dùng',
          widget.room.ownerId!: widget.room.ownerName,
        },
        'participantPhotos': {
          currentUser.uid: currentUser.photoURL,
          widget.room.ownerId!: widget.room.ownerPhotoUrl,
        },
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
      chatId = newChat.id;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(chatId: chatId!, otherUserName: widget.room.ownerName),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Stack(
        children: [
          Positioned.fill(
            bottom: 220,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(32),
                image: DecorationImage(
                  image: NetworkImage(widget.room.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          Positioned(
            right: 25, bottom: 240,
            child: Column(
              children: [
                _buildSideAction(isLiked ? Icons.favorite : Icons.favorite_border, isLiked ? Colors.red : Colors.white, () => setState(() => isLiked = !isLiked)),
                const SizedBox(height: 20),
                _buildSideAction(Icons.comment_rounded, Colors.white, () {}),
                const SizedBox(height: 20),
                _buildSideAction(Icons.share_rounded, Colors.white, () {}),
              ],
            ),
          ),

          Positioned(
            left: 12, right: 12, bottom: 20,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
                        child: Text('CÒN PHÒNG', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                      Text(
                        '${(widget.room.price / 1000000).toStringAsFixed(1)} Tr/tháng',
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.room.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(widget.room.address, style: const TextStyle(color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: widget.room.ownerPhotoUrl != null ? NetworkImage(widget.room.ownerPhotoUrl!) : null,
                        child: widget.room.ownerPhotoUrl == null ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(widget.room.ownerName, style: const TextStyle(fontWeight: FontWeight.bold))),
                      ElevatedButton(
                        onPressed: _startChat,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        child: const Text('Liên hệ'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
