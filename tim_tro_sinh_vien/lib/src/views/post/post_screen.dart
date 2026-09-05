import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum PostType { room, roommate }

class PostTab extends StatefulWidget {
  const PostTab({super.key});

  @override
  State<PostTab> createState() => _PostTabState();
}

class _PostTabState extends State<PostTab> {
  PostType _selectedType = PostType.room;

  // Controllers cho Phòng trọ
  final TextEditingController titleController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();
  String _selectedDistrict = 'Quận 1';

  // Controllers cho Tìm ở ghép
  final TextEditingController schoolController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController budgetController = TextEditingController();
  String _selectedGender = 'Nam';
  final List<String> _selectedTraits = [];

  bool isUploading = false;

  final List<String> districts = [
    'Quận 1', 'Quận 3', 'Quận 4', 'Quận 5', 'Quận 7', 'Quận 8', 'Quận 10', 
    'Bình Thạnh', 'Gò Vấp', 'Tân Bình', 'Thủ Đức'
  ];

  @override
  void dispose() {
    titleController.dispose();
    addressController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    imageUrlController.dispose();
    schoolController.dispose();
    bioController.dispose();
    budgetController.dispose();
    super.dispose();
  }

  Future<void> postRoom() async {
    String title = titleController.text.trim();
    String address = addressController.text.trim();
    String priceText = priceController.text.trim();
    String description = descriptionController.text.trim();
    String imageUrl = imageUrlController.text.trim();

    if (title.isEmpty || address.isEmpty || priceText.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')));
      return;
    }

    double? price = double.tryParse(priceText);
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giá phòng không hợp lệ')));
      return;
    }

    setState(() => isUploading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String ownerName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Người dùng';
      
      await FirebaseFirestore.instance.collection('rooms').add({
        'title': title,
        'address': address,
        'district': _selectedDistrict,
        'price': price,
        'description': description,
        'imageUrl': imageUrl.isEmpty ? 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=500&q=80' : imageUrl,
        'ownerId': user?.uid,
        'ownerName': ownerName,
        'ownerPhotoUrl': user?.photoURL,
        'likes': 0,
        'comments': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng tin phòng trọ thành công!')));
      _clearRoomFields();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> postRoommateRequest() async {
    String school = schoolController.text.trim();
    String bio = bioController.text.trim();
    String budgetText = budgetController.text.trim();

    if (school.isEmpty || bio.isEmpty || budgetText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')));
      return;
    }

    double? budget = double.tryParse(budgetText);
    if (budget == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ngân sách không hợp lệ')));
      return;
    }

    setState(() => isUploading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String name = user?.displayName ?? user?.email?.split('@')[0] ?? 'Người dùng';

      await FirebaseFirestore.instance.collection('roommate_requests').add({
        'name': name,
        'photoUrl': user?.photoURL,
        'gender': _selectedGender,
        'school': school,
        'bio': bio,
        'budget': budget,
        'userId': user?.uid,
        'traits': _selectedTraits,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng tin tìm ở ghép thành công!')));
      _clearRoommateFields();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  void _clearRoomFields() {
    titleController.clear();
    addressController.clear();
    priceController.clear();
    descriptionController.clear();
    imageUrlController.clear();
  }

  void _clearRoommateFields() {
    schoolController.clear();
    bioController.clear();
    budgetController.clear();
    setState(() => _selectedTraits.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Đăng tin mới', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SegmentedButton<PostType>(
                segments: const [
                  ButtonSegment(value: PostType.room, label: Text('Cho thuê phòng'), icon: Icon(Icons.home_work_rounded)),
                  ButtonSegment(value: PostType.roommate, label: Text('Tìm ở ghép'), icon: Icon(Icons.people_alt_rounded)),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<PostType> newSelection) {
                  setState(() => _selectedType = newSelection.first);
                },
              ),
            ),
            const SizedBox(height: 25),
            if (_selectedType == PostType.room) ...[
              const Text('Khu vực', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                isExpanded: true,
                value: _selectedDistrict,
                items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => setState(() => _selectedDistrict = v!),
              ),
              const SizedBox(height: 12),
              _buildTextField(titleController, 'Tiêu đề', Icons.title),
              const SizedBox(height: 12),
              _buildTextField(addressController, 'Địa chỉ cụ thể', Icons.location_on),
              const SizedBox(height: 12),
              _buildTextField(priceController, 'Giá (VNĐ/tháng)', Icons.payments, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _buildTextField(imageUrlController, 'Link ảnh minh họa', Icons.image),
              const SizedBox(height: 12),
              _buildTextField(descriptionController, 'Mô tả', Icons.description, maxLines: 4),
            ] else ...[
              _buildTextField(schoolController, 'Trường đại học', Icons.school),
              const SizedBox(height: 12),
              _buildTextField(budgetController, 'Ngân sách', Icons.payments, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              const Text('Giới tính', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  ChoiceChip(label: const Text('Nam'), selected: _selectedGender == 'Nam', onSelected: (s) => setState(() => _selectedGender = 'Nam')),
                  const SizedBox(width: 10),
                  ChoiceChip(label: const Text('Nữ'), selected: _selectedGender == 'Nữ', onSelected: (s) => setState(() => _selectedGender = 'Nữ')),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(bioController, 'Giới thiệu bản thân', Icons.info, maxLines: 4),
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isUploading ? null : (_selectedType == PostType.room ? postRoom : postRoommateRequest),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text('ĐĂNG TIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true, fillColor: Colors.white,
      ),
    );
  }
}
