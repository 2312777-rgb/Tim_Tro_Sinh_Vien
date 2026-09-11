import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Ảnh mặc định nếu người dùng chưa có Avatar
const String defaultAvatarUrl = 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAuth.instance.setLanguageCode('vi');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tìm Trọ Sinh Viên',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const MainPage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}

// ==========================================
// TRANG ĐĂNG NHẬP
// ==========================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng nhập: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(Icons.home_rounded, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text('Tìm Trọ Sinh Viên', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 35),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Đăng nhập', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 25),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'Email hoặc số điện thoại',
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true, fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: passwordController,
                        obscureText: hidePassword,
                        decoration: InputDecoration(
                          hintText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => hidePassword = !hidePassword),
                          ),
                          filled: true, fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordPage())),
                          child: const Text('Quên mật khẩu?'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton(
                          onPressed: login,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                          child: const Text('ĐĂNG NHẬP'),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Chưa có tài khoản? '),
                          TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())),
                            child: const Text('Đăng ký', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// TRANG ĐĂNG KÝ
// ==========================================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool isRegistering = false;

  Future<void> register() async {
    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')));
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu xác nhận không khớp')));
      return;
    }
    setState(() => isRegistering = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      await userCredential.user?.updateDisplayName(name);

      // Tạo một document mặc định cho user trong Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
        'phone': '',
        'major': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainPage()), (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMsg = 'Đã xảy ra lỗi khi đăng ký';
      if (e.code == 'weak-password') errorMsg = 'Mật khẩu quá yếu. Vui lòng nhập tối thiểu 6 ký tự.';
      else if (e.code == 'email-already-in-use') errorMsg = 'Email này đã được sử dụng cho một tài khoản khác.';
      else if (e.code == 'invalid-email') errorMsg = 'Định dạng email không hợp lệ.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text('Đăng ký', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tạo tài khoản mới', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Đăng ký để tìm kiếm và chia sẻ phòng trọ nhanh chóng.', style: TextStyle(fontSize: 15, color: Colors.grey[700])),
              const SizedBox(height: 30),
              TextField(controller: nameController, decoration: InputDecoration(hintText: 'Họ và tên', prefixIcon: const Icon(Icons.badge_outlined), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
              const SizedBox(height: 16),
              TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(hintText: 'Email', prefixIcon: const Icon(Icons.email_outlined), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
              const SizedBox(height: 16),
              TextField(controller: passwordController, obscureText: hidePassword, decoration: InputDecoration(hintText: 'Mật khẩu', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => hidePassword = !hidePassword)), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
              const SizedBox(height: 16),
              TextField(controller: confirmPasswordController, obscureText: hideConfirmPassword, decoration: InputDecoration(hintText: 'Xác nhận mật khẩu', prefixIcon: const Icon(Icons.lock_reset_outlined), suffixIcon: IconButton(icon: Icon(hideConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => hideConfirmPassword = !hideConfirmPassword)), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
              const SizedBox(height: 35),
              SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: isRegistering ? null : register, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: isRegistering ? const CircularProgressIndicator(color: Colors.white) : const Text('ĐĂNG KÝ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)))),
              const SizedBox(height: 25),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Đã có tài khoản? '), TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold)))])
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// TRANG QUÊN MẬT KHẨU
// ==========================================
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  bool isResetting = false;

  Future<void> resetPassword() async {
    String email = emailController.text.trim();
    if (email.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập email'))); return; }
    setState(() => isResetting = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email khôi phục đã được gửi.'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = 'Đã xảy ra lỗi';
      if (e.code == 'user-not-found') errorMessage = 'Không tìm thấy tài khoản.';
      else if (e.code == 'invalid-email') errorMessage = 'Email không hợp lệ.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text('Quên mật khẩu', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Khôi phục mật khẩu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Nhập email đã đăng ký. Chúng tôi sẽ gửi liên kết đặt lại mật khẩu.', style: TextStyle(fontSize: 15, color: Colors.grey[700])),
              const SizedBox(height: 30),
              TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(hintText: 'Nhập địa chỉ email', prefixIcon: const Icon(Icons.email_outlined), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
              const SizedBox(height: 25),
              SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: isResetting ? null : resetPassword, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: isResetting ? const CircularProgressIndicator(color: Colors.white) : const Text('GỬI YÊU CẦU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// MODEL DỮ LIỆU
// ==========================================
class Room {
  final String id;
  final String title;
  final String address;
  final double price;
  final String imageUrl;
  final String description;
  final String ownerName;
  final String ownerAvatar; // Đã thêm Avatar chủ bài đăng
  final String roomType;

  Room({
    required this.id,
    required this.title,
    required this.address,
    required this.price,
    required this.imageUrl,
    required this.description,
    required this.ownerName,
    required this.ownerAvatar,
    this.roomType = 'Phòng đơn',
  });
}

// ==========================================
// TRANG CHỦ LƯỚI (DẠNG PINTEREST)
// ==========================================
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Khám phá phòng trọ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.black, size: 26),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng tìm kiếm đang phát triển')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rooms')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Đã xảy ra lỗi', style: TextStyle(color: Colors.black)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blue));
          }

          final roomDocs = snapshot.data!.docs;

          if (roomDocs.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có tin đăng nào.\nHãy là người đầu tiên!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: roomDocs.length,
            itemBuilder: (context, index) {
              final data = roomDocs[index].data() as Map<String, dynamic>;
              final room = Room(
                id: roomDocs[index].id,
                title: data['title'] ?? '',
                address: data['address'] ?? '',
                price: (data['price'] ?? 0).toDouble(),
                imageUrl: data['imageUrl'] ?? 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=500&q=80',
                description: data['description'] ?? '',
                ownerName: data['ownerName'] ?? 'Người dùng',
                ownerAvatar: data['ownerAvatar'] ?? defaultAvatarUrl, // Lấy Avatar từ Database
                roomType: data['roomType'] ?? 'Phòng đơn',
              );
              return RoomGridItem(room: room);
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// ITEM ẢNH TRÊN TRANG CHỦ
// ==========================================
class RoomGridItem extends StatefulWidget {
  final Room room;
  const RoomGridItem({super.key, required this.room});

  @override
  State<RoomGridItem> createState() => _RoomGridItemState();
}

class _RoomGridItemState extends State<RoomGridItem> {
  bool isLiked = false;

  void toggleLike() {
    setState(() {
      isLiked = !isLiked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RoomDetailScreen(
              room: widget.room,
              initialLikeState: isLiked,
            ),
          ),
        ).then((_) {
          setState(() {});
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              widget.room.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.3), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: toggleLike,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isLiked ? Colors.red : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TRANG CHI TIẾT THEO PHONG CÁCH PIXIV
// ==========================================
class RoomDetailScreen extends StatefulWidget {
  final Room room;
  final bool initialLikeState;

  const RoomDetailScreen({
    super.key,
    required this.room,
    this.initialLikeState = false,
  });

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late bool isLiked;

  @override
  void initState() {
    super.initState();
    isLiked = widget.initialLikeState;
  }

  void toggleLike() {
    setState(() {
      isLiked = !isLiked;
    });
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(price % 1000000 == 0 ? 0 : 1)} Tr';
    } else {
      return '${price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} đ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HÌNH ẢNH HERO BÊN TRÊN
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 300,
                    maxHeight: 450,
                  ),
                  child: Image.network(
                    widget.room.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned(
                  top: 0, left: 0, right: 0,
                  height: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNavButton(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
                        _buildNavButton(Icons.more_vert_rounded, () {}),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 2. KHU VỰC NỘI DUNG CHÍNH
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.room.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.3),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: NetworkImage(widget.room.ownerAvatar), // Hiển thị Avatar thật của chủ bài đăng
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.room.ownerName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                            ),
                            Row(
                              children: [
                                Icon(Icons.verified_rounded, color: Colors.blue[600], size: 12),
                                const SizedBox(width: 4),
                                Text('Đã xác thực', style: TextStyle(color: Colors.blue[600], fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                          minimumSize: const Size(0, 36),
                        ),
                        child: const Text('Liên hệ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTag(widget.room.roomType, Colors.blue),
                      _buildTag('${_formatPrice(widget.room.price)}/tháng', Colors.red),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_rounded, color: Colors.grey[500], size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.room.address,
                          style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    widget.room.description,
                    style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
                  ),
                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionIcon(
                        icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        label: 'Thích',
                        iconColor: isLiked ? Colors.red : Colors.grey[700]!,
                        onTap: toggleLike,
                      ),
                      _buildActionIcon(
                        icon: Icons.share_rounded,
                        label: 'Chia sẻ',
                        iconColor: Colors.grey[700]!,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildActionIcon({required IconData icon, required String label, required Color iconColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ==========================================
// TRANG ĐĂNG TIN
// ==========================================
class PostTab extends StatefulWidget {
  const PostTab({super.key});
  @override
  State<PostTab> createState() => _PostTabState();
}

class _PostTabState extends State<PostTab> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  File? _imageFile;
  bool isUploading = false;
  String _selectedRoomType = 'Phòng đơn';
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  Future<String?> uploadImageToImgBB(File imageFile) async {
    const String imgbbApiKey = "6a3c8ce6b7aff39f890a29a6ef322afc";
    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$imgbbApiKey'));
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResult = jsonDecode(responseData);
        return jsonResult['data']['url'];
      }
    } catch (e) {
      debugPrint("Lỗi upload ảnh: $e");
    }
    return null;
  }

  Future<void> postRoom() async {
    String title = titleController.text.trim();
    String address = addressController.text.trim();
    String priceText = priceController.text.trim();
    String description = descriptionController.text.trim();

    if (title.isEmpty || address.isEmpty || priceText.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin chữ')));
      return;
    }
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn 1 ảnh minh họa')));
      return;
    }
    double? price = double.tryParse(priceText);
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giá phòng không hợp lệ')));
      return;
    }

    setState(() => isUploading = true);
    try {
      String? downloadUrl = await uploadImageToImgBB(_imageFile!);
      if (downloadUrl == null) throw Exception("Không thể tải ảnh lên máy chủ ImgBB");
      User? user = FirebaseAuth.instance.currentUser;

      // Lưu Avatar của người dùng lúc đăng tin vào bài viết
      await FirebaseFirestore.instance.collection('rooms').add({
        'title': title, 'address': address, 'price': price, 'description': description,
        'imageUrl': downloadUrl, 'roomType': _selectedRoomType, 'ownerId': user?.uid,
        'ownerName': user?.displayName ?? 'Người dùng',
        'ownerAvatar': user?.photoURL ?? defaultAvatarUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng tin thành công!'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi đăng tin: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black, size: 28), onPressed: () => Navigator.pop(context)),
        title: const Text('Đăng tin mới', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity, height: 180,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid)),
                child: _imageFile != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.blue[400]), const SizedBox(height: 8), Text('Nhấn để tải ảnh lên', style: TextStyle(color: Colors.grey[600]))]),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRoomType = 'Phòng đơn'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: _selectedRoomType == 'Phòng đơn' ? Colors.blue : Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: _selectedRoomType == 'Phòng đơn' ? Colors.blue : Colors.transparent)),
                      child: Center(child: Text('Phòng đơn', style: TextStyle(color: _selectedRoomType == 'Phòng đơn' ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 15))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRoomType = 'Phòng ghép'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: _selectedRoomType == 'Phòng ghép' ? Colors.orange : Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: _selectedRoomType == 'Phòng ghép' ? Colors.orange : Colors.transparent)),
                      child: Center(child: Text('Phòng ghép', style: TextStyle(color: _selectedRoomType == 'Phòng ghép' ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 15))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField(titleController, 'Tiêu đề tin đăng', Icons.title),
            const SizedBox(height: 15),
            _buildTextField(addressController, 'Địa chỉ chi tiết', Icons.location_on),
            const SizedBox(height: 15),
            _buildTextField(priceController, 'Giá cho thuê (VNĐ/tháng)', Icons.money, keyboardType: TextInputType.number),
            const SizedBox(height: 15),
            _buildTextField(descriptionController, 'Mô tả chi tiết', Icons.description, maxLines: 4),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: isUploading ? null : postRoom,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 2),
                child: isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text('ĐĂNG TIN NGAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: controller, keyboardType: keyboardType, maxLines: maxLines,
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: Colors.grey), filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
    );
  }
}

// ==========================================
// TRANG HỒ SƠ & CÀI ĐẶT
// ==========================================
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  User? user = FirebaseAuth.instance.currentUser;
  bool isUploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();

  // Hàm tải ảnh lên ImgBB
  Future<String?> _uploadImageToImgBB(File imageFile) async {
    const String imgbbApiKey = "6a3c8ce6b7aff39f890a29a6ef322afc";
    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$imgbbApiKey'));
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResult = jsonDecode(responseData);
        return jsonResult['data']['url'];
      }
    } catch (e) {
      debugPrint("Lỗi upload ảnh: $e");
    }
    return null;
  }

  // Cập nhật Avatar (Tự động đồng bộ với bài đăng cũ)
  Future<void> _updateAvatar() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile == null) return;

    setState(() => isUploadingAvatar = true);
    try {
      String? downloadUrl = await _uploadImageToImgBB(File(pickedFile.path));
      if (downloadUrl != null) {
        // 1. Cập nhật Avatar trong tài khoản Firebase Auth
        await user?.updatePhotoURL(downloadUrl);
        await user?.reload();

        // 2. Cập nhật Avatar cho toàn bộ bài đăng của User này trong Firestore
        var roomQuery = await FirebaseFirestore.instance
            .collection('rooms')
            .where('ownerId', isEqualTo: user?.uid)
            .get();

        var batch = FirebaseFirestore.instance.batch();
        for (var doc in roomQuery.docs) {
          batch.update(doc.reference, {'ownerAvatar': downloadUrl});
        }
        await batch.commit(); // Thực thi đồng loạt

        setState(() {
          user = FirebaseAuth.instance.currentUser; // Refresh UI
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật ảnh đại diện')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      setState(() => isUploadingAvatar = false);
    }
  }

  // Cập nhật thông tin (Tên, SĐT, Trường)
  Future<void> _showEditProfileDialog(String currentPhone, String currentMajor) async {
    TextEditingController nameController = TextEditingController(text: user?.displayName);
    TextEditingController phoneController = TextEditingController(text: currentPhone);
    TextEditingController majorController = TextEditingController(text: currentMajor);
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Chỉnh sửa thông tin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: InputDecoration(hintText: 'Họ và tên', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
                    const SizedBox(height: 10),
                    TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(hintText: 'Số điện thoại', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
                    const SizedBox(height: 10),
                    TextField(controller: majorController, decoration: InputDecoration(hintText: 'Trường / Ngành học', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setStateDialog(() => isSaving = true);
                    try {
                      if (nameController.text.trim() != user?.displayName) {
                        await user?.updateDisplayName(nameController.text.trim());
                        await user?.reload();
                      }

                      await FirebaseFirestore.instance.collection('users').doc(user?.uid).set({
                        'phone': phoneController.text.trim(),
                        'major': majorController.text.trim(),
                      }, SetOptions(merge: true));

                      if (!mounted) return;
                      this.setState(() { user = FirebaseAuth.instance.currentUser; });
                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                    } finally {
                      if (mounted) setStateDialog(() => isSaving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
          title: const Text('Hồ sơ cá nhân', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          backgroundColor: Colors.white, elevation: 0, centerTitle: true
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
          builder: (context, snapshot) {
            String phone = '';
            String major = '';

            if (snapshot.hasData && snapshot.data!.exists) {
              Map<String, dynamic> userData = snapshot.data!.data() as Map<String, dynamic>;
              phone = userData['phone'] ?? '';
              major = userData['major'] ?? '';
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity, padding: const EdgeInsets.only(bottom: 25, top: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))]),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _updateAvatar,
                          child: Stack(
                            children: [
                              Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blue.withOpacity(0.2), width: 3)),
                                  child: isUploadingAvatar
                                      ? const SizedBox(width: 110, height: 110, child: CircularProgressIndicator())
                                      : CircleAvatar(
                                    radius: 55,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: NetworkImage(user?.photoURL ?? defaultAvatarUrl),
                                  )
                              ),
                              Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                                  )
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(user?.displayName ?? 'Người dùng', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                              const SizedBox(width: 8),
                              GestureDetector(
                                  onTap: () => _showEditProfileDialog(phone, major),
                                  child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.edit_rounded, size: 16, color: Colors.blue))
                              )
                            ]
                        ),
                        const SizedBox(height: 6),
                        Text(user?.email ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.phone_rounded, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(phone.isNotEmpty ? phone : 'Chưa cập nhật số điện thoại', style: TextStyle(color: phone.isNotEmpty ? Colors.black87 : Colors.grey, fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.school_rounded, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(major.isNotEmpty ? major : 'Chưa cập nhật trường/ngành', style: TextStyle(color: major.isNotEmpty ? Colors.black87 : Colors.grey, fontSize: 14)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]),
                      child: Column(
                        children: [
                          _buildProfileOption(icon: Icons.post_add_rounded, title: 'Tin đăng của tôi', iconColor: Colors.blue, onTap: () {}), _buildDivider(),
                          _buildProfileOption(icon: Icons.favorite_rounded, title: 'Phòng đã lưu', iconColor: Colors.redAccent, onTap: () {}), _buildDivider(),
                          _buildProfileOption(icon: Icons.settings_rounded, title: 'Cài đặt', iconColor: Colors.grey[700]!, onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())); }), _buildDivider(),
                          _buildProfileOption(icon: Icons.help_outline_rounded, title: 'Hỗ trợ & Khiếu nại', iconColor: Colors.orange, onTap: () {}),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          }
      ),
    );
  }

  Widget _buildDivider() => Divider(height: 1, thickness: 1, color: Colors.grey[100], indent: 65, endIndent: 20);
  Widget _buildProfileOption({required IconData icon, required String title, required Color iconColor, required VoidCallback onTap}) {
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 22)), const SizedBox(width: 16), Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)))), Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[300], size: 16)]))));
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, appBar: AppBar(title: const Text('Cài đặt', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          _buildSettingItem(Icons.notifications_none_rounded, 'Thông báo hệ thống', () {}),
          const Divider(height: 32, thickness: 8, color: Color(0xFFF8F9FA)),
          _buildSettingItem(Icons.info_outline_rounded, 'Về ứng dụng', () {}),
          _buildSettingItem(Icons.delete_outline_rounded, 'Xóa tài khoản', () {}, isDestructive: true),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: () async { await FirebaseAuth.instance.signOut(); if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false); },
              icon: const Icon(Icons.logout_rounded), label: const Text('ĐĂNG XUẤT', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFF1F0), foregroundColor: Colors.red, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSettingItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDestructive ? Colors.red.withOpacity(0.05) : Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: isDestructive ? Colors.red : Colors.blue, size: 22)), title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDestructive ? Colors.red : Colors.black87)), trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey), onTap: onTap);
  }
}

class InboxTab extends StatelessWidget { const InboxTab({super.key}); @override Widget build(BuildContext context) { return Scaffold(backgroundColor: Colors.white, appBar: AppBar(title: const Text('Hộp thư', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0), body: const Center(child: Text('Tính năng đang phát triển'))); } }
class ShopTab extends StatelessWidget { const ShopTab({super.key}); @override Widget build(BuildContext context) { return Scaffold(backgroundColor: Colors.white, appBar: AppBar(title: const Text('Tìm phòng ở ghép', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0), body: const Center(child: Text('Đang phát triển'))); } }

// ==========================================
// ĐIỀU HƯỚNG BOTTOM NAVIGATION BAR
// ==========================================
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeTab(),
    const ShopTab(),
    const SizedBox(),
    const InboxTab(),
    const ProfileTab(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PostTab()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 55,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildNavItem(0, CupertinoIcons.house_fill, CupertinoIcons.house),
                _buildNavItem(1, Icons.public, Icons.public_outlined),
                _buildNavItem(2, Icons.add, Icons.add),
                _buildNavItem(3, Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded),
                _buildNavItem(4, Icons.person_rounded, Icons.person_outline_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData selectedIcon, IconData unselectedIcon) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 55,
        child: Center(
          child: Icon(
            isSelected ? selectedIcon : unselectedIcon,
            color: isSelected ? Colors.black : Colors.grey[500],
            size: 30,
          ),
        ),
      ),
    );
  }
}