import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:expandable_page_view/expandable_page_view.dart';
import 'firebase_options.dart';

// 3 dòng thư viện bản đồ
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// Đảm bảo geocoding dùng "as geocoding" để Dart không bị nhầm lẫn class Location
import 'package:geocoding/geocoding.dart' as geocoding;
// ==========================================
// TRANG BẢN ĐỒ MIỄN PHÍ (OPENSTREETMAP)
// ==========================================
class FreeMapScreen extends StatefulWidget {
  const FreeMapScreen({super.key});

  @override
  State<FreeMapScreen> createState() => _FreeMapScreenState();
}

class _FreeMapScreenState extends State<FreeMapScreen> {
  List<Marker> _markers = [];
  bool _isLoading = true;

  // Tọa độ trung tâm mặc định (Đà Lạt)
  final LatLng _center = const LatLng(11.940419, 108.458313);

  @override
  void initState() {
    super.initState();
    _loadRoomsToMap();
  }
  Future<void> _loadRoomsToMap() async {
    List<Marker> markers = [];

    try {
      var snapshot = await FirebaseFirestore.instance.collection('rooms').get();

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String address = data['address'] ?? '';

        if (address.isNotEmpty) {
          try {
            // Sử dụng OpenStreetMap Nominatim API để tìm tọa độ từ địa chỉ miễn phí
            final encodedAddress = Uri.encodeComponent(address);
            final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedAddress&format=json&limit=1');

            final response = await http.get(url, headers: {'User-Agent': 'com.example.timtro'});

            if (response.statusCode == 200) {
              final List results = jsonDecode(response.body);
              if (results.isNotEmpty) {
                final lat = double.parse(results[0]['lat']);
                final lon = double.parse(results[0]['lon']);
                LatLng position = LatLng(lat, lon);

                DateTime postTime = data['createdAt'] != null
                    ? (data['createdAt'] as Timestamp).toDate()
                    : DateTime.now();

                Room room = Room(
                  id: doc.id,
                  ownerId: data['ownerId'] ?? '',
                  title: data['title'] ?? '',
                  address: address,
                  price: (data['price'] ?? 0).toDouble(),
                  imageUrl: data['imageUrl'] ?? '',
                  imageUrls: List<String>.from(data['imageUrls'] ?? []),
                  description: data['description'] ?? '',
                  ownerName: data['ownerName'] ?? 'Người dùng',
                  ownerAvatar: data['ownerAvatar'] ?? defaultAvatarUrl,
                  roomType: data['roomType'] ?? 'Phòng đơn',
                  area: data['area'] ?? '',
                  amenities: List<String>.from(data['amenities'] ?? []),
                  requirements: List<String>.from(data['requirements'] ?? []),
                  createdAt: postTime,
                  likedBy: List<String>.from(data['likedBy'] ?? []),
                );

                markers.add(
                  Marker(
                    point: position,
                    width: 45,
                    height: 45,
                    child: GestureDetector(
                      onTap: () => _showRoomPreview(room),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Colors.red,
                        size: 45,
                      ),
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint("Không tìm thấy vị trí cho địa chỉ: $address");
          }
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải bản đồ: $e");
    }

    if (mounted) {
      setState(() {
        _markers = markers;
        _isLoading = false;
      });
    }
  }

  // Bảng xem nhanh thông tin khi bấm vào ghim
  void _showRoomPreview(Room room) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 180,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  room.imageUrl,
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(width: 110, height: 110, color: Colors.grey[200]),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      room.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${room.price >= 1000000 ? (room.price / 1000000).toStringAsFixed(1) : room.price.toInt()} Tr/tháng',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => RoomDetailScreen(room: room)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Xem chi tiết'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ phòng trọ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text("Đang tải dữ liệu bản đồ..."),
          ],
        ),
      )
          : FlutterMap(
        options: MapOptions(
          initialCenter: _center,
          initialZoom: 13.0,
        ),
        children: [
          // Lớp gạch bản đồ miễn phí OpenStreetMap
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.timtro',
          ),
          // Lớp chứa các ghim vị trí phòng
          MarkerLayer(
            markers: _markers,
          ),
        ],
      ),
    );
  }
}
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin')));
      return;
    }
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainPage()));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi đăng nhập: ${e.message}')));
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
                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(25)),
                  child: const Icon(Icons.home_rounded, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text('Tìm Trọ Sinh Viên', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 35),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
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

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
        'phone': '',
        'gender': 'Chưa xác định',
        'tags': [],
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
  final String ownerId;
  final String title;
  final String address;
  final double price;
  final String imageUrl;
  final List<String> imageUrls;
  final String description;
  final String ownerName;
  final String ownerAvatar;
  final String roomType;
  final DateTime createdAt;
  final List<String> likedBy;
  final String area;
  final List<String> amenities;
  final List<String> requirements;

  Room({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.address,
    required this.price,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.description,
    required this.ownerName,
    required this.ownerAvatar,
    required this.createdAt,
    required this.likedBy,
    this.roomType = 'Phòng đơn',
    this.area = '',
    this.amenities = const [],
    this.requirements = const [],
  });
}
// ==========================================
// TRANG CHỦ LƯỚI
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
          // NÚT MỞ BẢN ĐỒ ĐÃ ĐƯỢC TÍCH HỢP Ở ĐÂY
          IconButton(
              icon: const Icon(Icons.map_rounded, color: Colors.black, size: 26),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FreeMapScreen()),
                );
              }
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.blue));
          if (snapshot.hasError) return const Center(child: Text('Đã xảy ra lỗi'));

          final roomDocs = snapshot.data?.docs ?? [];
          if (roomDocs.isEmpty) return const Center(child: Text('Chưa có tin đăng nào.'));

          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75,
            ),
            itemCount: roomDocs.length,
            itemBuilder: (context, index) {
              final data = roomDocs[index].data() as Map<String, dynamic>;

              DateTime postTime = DateTime.now();
              if (data['createdAt'] != null) postTime = (data['createdAt'] as Timestamp).toDate();

              final room = Room(
                id: roomDocs[index].id,
                ownerId: data['ownerId'] ?? '',
                title: data['title'] ?? '', address: data['address'] ?? '',
                price: (data['price'] ?? 0).toDouble(), imageUrl: data['imageUrl'] ?? '',
                imageUrls: List<String>.from(data['imageUrls'] ?? []),
                description: data['description'] ?? '', ownerName: data['ownerName'] ?? 'Người dùng',
                ownerAvatar: data['ownerAvatar'] ?? defaultAvatarUrl, roomType: data['roomType'] ?? 'Phòng đơn',
                area: data['area'] ?? '',
                amenities: List<String>.from(data['amenities'] ?? []),
                requirements: List<String>.from(data['requirements'] ?? []),
                createdAt: postTime,
                likedBy: List<String>.from(data['likedBy'] ?? []),
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
  void toggleLike() async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    DocumentReference roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.room.id);
    bool isLiked = widget.room.likedBy.contains(uid);

    if (isLiked) {
      await roomRef.update({'likedBy': FieldValue.arrayRemove([uid])});
    } else {
      await roomRef.update({'likedBy': FieldValue.arrayUnion([uid])});
    }
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    bool isLiked = widget.room.likedBy.contains(uid);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => RoomDetailScreen(room: widget.room)));
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(widget.room.imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[200])),
          ),
          Positioned(bottom: 0, left: 0, right: 0, height: 50, child: Container(decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)), gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.3), Colors.transparent])))),
          Positioned(
            bottom: 8, right: 8,
            child: GestureDetector(
              onTap: toggleLike,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isLiked ? Colors.red : Colors.white, size: 22,
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
// TRANG CHI TIẾT
// ==========================================
class RoomDetailScreen extends StatefulWidget {
  final Room room;
  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late bool isLiked;
  final TextEditingController _commentController = TextEditingController();
  bool isPostingComment = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    isLiked = widget.room.likedBy.contains(uid);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void toggleLike() async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    setState(() { isLiked = !isLiked; });
    DocumentReference roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.room.id);
    if (isLiked) {
      await roomRef.update({'likedBy': FieldValue.arrayUnion([uid])});
    } else {
      await roomRef.update({'likedBy': FieldValue.arrayRemove([uid])});
    }
  }

  Future<void> _postComment() async {
    String text = _commentController.text.trim();
    if (text.isEmpty) return;
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn cần đăng nhập để bình luận')));
      return;
    }
    setState(() => isPostingComment = true);
    try {
      await FirebaseFirestore.instance.collection('rooms').doc(widget.room.id).collection('comments').add({
        'text': text, 'userId': user.uid, 'userName': user.displayName ?? 'Người dùng',
        'userAvatar': user.photoURL ?? defaultAvatarUrl, 'createdAt': FieldValue.serverTimestamp(),
      });
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      setState(() => isPostingComment = false);
    }
  }

  String _formatPrice(double price) {
    if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(price % 1000000 == 0 ? 0 : 1)} Tr';
    return '${price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} đ';
  }

  @override
  Widget build(BuildContext context) {
    List<String> displayImages = widget.room.imageUrls.isNotEmpty ? widget.room.imageUrls : [widget.room.imageUrl];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // TOÀN BỘ NỘI DUNG CUỘN ĐƯỢC (ẢNH + CHỮ)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      // SỬ DỤNG EXPANDABLE PAGE VIEW TẠI ĐÂY
                      Container(
                        color: Colors.black.withOpacity(0.03),
                        child: ExpandablePageView.builder(
                          onPageChanged: (index) {
                            setState(() { _currentImageIndex = index; });
                          },
                          itemCount: displayImages.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              displayImages[index],
                              fit: BoxFit.contain, // Hiển thị trọn vẹn toàn bộ ảnh
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 300,
                                  color: Colors.grey[100],
                                  child: const Center(child: CircularProgressIndicator(color: Colors.blue)),
                                );
                              },
                              errorBuilder: (c, e, s) => Container(height: 300, color: Colors.grey[250]),
                            );
                          },
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                          ),
                        ),
                      ),
                      if (displayImages.length > 1 && _currentImageIndex < displayImages.length - 1)
                        Positioned(
                          right: 16, top: 0, bottom: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 20),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 16, right: 16,
                        child: GestureDetector(
                          onTap: toggleLike,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                            child: Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isLiked ? Colors.red : Colors.white, size: 26),
                          ),
                        ),
                      ),
                      if (displayImages.length > 1)
                        Positioned(
                          bottom: 16, left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                            child: Text('${_currentImageIndex + 1}/${displayImages.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                    ],
                  ),

                  // PHẦN THÔNG TIN BÊN DƯỚI KHUNG ẢNH
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.room.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.3)),
                        const SizedBox(height: 20),

                        // NHẤN VÀO KHU VỰC CHỦ PHÒNG ĐỂ ĐẾN TRANG CÁ NHÂN
                        GestureDetector(
                          onTap: () {
                            if (widget.room.ownerId.isNotEmpty) {
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (context) => PublicProfileScreen(userId: widget.room.ownerId)
                              ));
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              CircleAvatar(radius: 20, backgroundImage: NetworkImage(widget.room.ownerAvatar)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.room.ownerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Row(children: [Icon(Icons.verified_rounded, color: Colors.blue[600], size: 12), const SizedBox(width: 4), Text('Đã xác thực', style: TextStyle(color: Colors.blue[600], fontSize: 12))]),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text('${_formatPrice(widget.room.price)}/tháng', style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            if (widget.room.area.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                child: Text('${widget.room.area} m²', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.location_on_rounded, color: Colors.grey[500], size: 18), const SizedBox(width: 6), Expanded(child: Text(widget.room.address, style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w500)))]),
                        const SizedBox(height: 16),

                        // Tiện nghi & Yêu cầu nếu có
                        if (widget.room.amenities.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Tiện nghi:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: widget.room.amenities.map((e) => Chip(label: Text(e, style: const TextStyle(fontSize: 12)), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact)).toList(),
                          )
                        ],
                        if (widget.room.requirements.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Yêu cầu:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(widget.room.requirements.join(', '), style: const TextStyle(fontSize: 14)),
                        ],

                        const SizedBox(height: 16),
                        Text(widget.room.description, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6)),

                        const Divider(height: 40, thickness: 1, color: Color(0xFFEEEEEE)),

                        const Text('Bình luận', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('rooms').doc(widget.room.id).collection('comments').orderBy('createdAt', descending: false).snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                            final comments = snapshot.data?.docs ?? [];
                            if (comments.isEmpty) return const Padding(padding: EdgeInsets.only(bottom: 20), child: Text('Chưa có bình luận nào.', style: TextStyle(color: Colors.grey)));

                            return ListView.builder(
                              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 20),
                              itemCount: comments.length,
                              itemBuilder: (context, index) {
                                var commentData = comments[index].data() as Map<String, dynamic>;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(radius: 18, backgroundImage: NetworkImage(commentData['userAvatar'] ?? defaultAvatarUrl)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(commentData['userName'] ?? 'Người dùng', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              const SizedBox(height: 4),
                                              Text(commentData['text'] ?? '', style: const TextStyle(fontSize: 14)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // THANH NHẬP BÌNH LUẬN NẰM CỐ ĐỊNH DƯỚI ĐÁY MÀN HÌNH
          Container(
            padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 12),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10)]),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _commentController, decoration: InputDecoration(hintText: 'Viết bình luận...', filled: true, fillColor: Colors.grey[100], contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
                const SizedBox(width: 8),
                isPostingComment ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) : IconButton(icon: const Icon(Icons.send_rounded, color: Colors.blue), onPressed: _postComment),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TRANG ĐĂNG TIN MỚI (WIZARD 5 BƯỚC)
// ==========================================
class PostTab extends StatelessWidget {
  const PostTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Đăng tin', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150, height: 150,
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.maps_home_work_rounded, size: 80, color: Colors.blue),
              ),
              const SizedBox(height: 32),
              const Text('Đăng tin cho thuê phòng', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              const Text(
                'Chia sẻ phòng trọ của bạn đến hàng nghìn sinh viên, tìm được người thuê phù hợp nhanh chóng!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostWizard()));
                  },
                  icon: const Icon(Icons.edit_document),
                  label: const Text('Đăng tin ngay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 55,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPostsScreen()));
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, side: const BorderSide(color: Colors.blue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: const Text('Xem tin đã đăng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreatePostWizard extends StatefulWidget {
  const CreatePostWizard({super.key});
  @override
  State<CreatePostWizard> createState() => _CreatePostWizardState();
}

class _CreatePostWizardState extends State<CreatePostWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool isUploading = false;

  String _title = '';
  String _roomType = 'Phòng trọ';
  String _price = '';
  String _area = '';
  String _address = '';
  List<File> _imageFiles = [];
  String _description = '';
  final List<String> _selectedAmenities = [];
  final List<String> _selectedRequirements = [];
  String _detailedAddress = '';

  final List<String> roomTypes = ['Phòng trọ', 'Ký túc xá', 'Căn hộ mini', 'Nhà nguyên căn'];
  final List<Map<String, dynamic>> amenitiesList = [
    {'name': 'WiFi', 'icon': Icons.wifi}, {'name': 'Máy lạnh', 'icon': Icons.ac_unit},
    {'name': 'Nội thất', 'icon': Icons.chair}, {'name': 'Máy giặt', 'icon': Icons.local_laundry_service},
    {'name': 'Bếp riêng', 'icon': Icons.countertops}, {'name': 'Ban công', 'icon': Icons.balcony},
    {'name': 'Thang máy', 'icon': Icons.elevator}, {'name': 'Bãi xe', 'icon': Icons.local_parking},
    {'name': 'Camera', 'icon': Icons.videocam}, {'name': 'Bảo vệ', 'icon': Icons.security},
    {'name': 'Giờ giấc tự do', 'icon': Icons.access_time},
  ];
  final List<String> requirementsList = ['Nữ', 'Nam', 'Sinh viên', 'Đi làm', 'Có thú cưng'];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_title.isEmpty || _price.isEmpty || _area.isEmpty || _address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đủ thông tin cơ bản')));
        return;
      }
    } else if (_currentStep == 1) {
      if (_imageFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ít nhất 1 hình ảnh')));
        return;
      }
      if (_description.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập mô tả')));
        return;
      }
    }

    if (_currentStep < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _submitPost();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

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

  Future<void> _submitPost() async {
    setState(() => isUploading = true);
    try {
      List<String> uploadedUrls = [];
      for (var file in _imageFiles) {
        String? downloadUrl = await _uploadImageToImgBB(file);
        if (downloadUrl != null) uploadedUrls.add(downloadUrl);
      }

      if (uploadedUrls.isEmpty) throw Exception("Không thể tải ảnh lên máy chủ");
      User? user = FirebaseAuth.instance.currentUser;

      double? parsedPrice = double.tryParse(_price.replaceAll(RegExp(r'[^0-9]'), ''));

      await FirebaseFirestore.instance.collection('rooms').add({
        'title': _title,
        'address': '$_detailedAddress, $_address',
        'price': parsedPrice ?? 0,
        'area': _area,
        'description': _description,
        'imageUrl': uploadedUrls.first,
        'imageUrls': uploadedUrls,
        'roomType': _roomType,
        'amenities': _selectedAmenities,
        'requirements': _selectedRequirements,
        'ownerId': user?.uid,
        'ownerName': user?.displayName ?? 'Người dùng',
        'ownerAvatar': user?.photoURL ?? defaultAvatarUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'likedBy': [],
      });

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PostSuccessScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  String getStepTitle() {
    switch (_currentStep) {
      case 0: return 'Thông tin cơ bản';
      case 1: return 'Hình ảnh & Mô tả';
      case 2: return 'Tiện nghi & Đặc điểm';
      case 3: return 'Vị trí & Bản đồ';
      case 4: return 'Xem lại thông tin';
      default: return 'Đăng tin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20), onPressed: _prevStep),
        title: Text(getStepTitle(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1BasicInfo(),
                _buildStep2ImagesDesc(),
                _buildStep3Amenities(),
                _buildStep4Location(),
                _buildStep5Review(),
              ],
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (index) {
          bool isActive = index == _currentStep;
          bool isCompleted = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: isActive || isCompleted ? Colors.blue : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: isActive || isCompleted ? Colors.blue : Colors.grey[300]!, width: 2),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text('${index + 1}', style: TextStyle(color: isActive ? Colors.white : Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                if (index != 4)
                  Expanded(
                    child: Container(
                      height: 2, margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: isCompleted ? Colors.blue : Colors.grey[200],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 20),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton(
          onPressed: isUploading ? null : _nextStep,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: isUploading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(_currentStep == 4 ? 'ĐĂNG TIN' : 'Tiếp theo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildStep1BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Tiêu đề tin *'),
          TextField(onChanged: (val) => _title = val, decoration: _inputDeco('VD: Phòng trọ 20m2, gần ĐH Đà Lạt, giá 2.5tr')),
          const SizedBox(height: 20),

          _buildLabel('Loại phòng *'),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: roomTypes.map((type) => GestureDetector(
              onTap: () => setState(() => _roomType = type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: _roomType == type ? Colors.blue.withOpacity(0.1) : Colors.white,
                    border: Border.all(color: _roomType == type ? Colors.blue : Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12)
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home_outlined, size: 18, color: _roomType == type ? Colors.blue : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(type, style: TextStyle(color: _roomType == type ? Colors.blue : Colors.black87, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Giá thuê *'),
                    TextField(onChanged: (val) => _price = val, keyboardType: TextInputType.number, decoration: _inputDeco('Nhập giá thuê', suffix: 'đ/tháng')),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Diện tích *'),
                    TextField(onChanged: (val) => _area = val, keyboardType: TextInputType.number, decoration: _inputDeco('Nhập diện tích', suffix: 'm²')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildLabel('Địa chỉ khu vực *'),
          TextField(onChanged: (val) => _address = val, decoration: _inputDeco('VD: Phường 3, Đà Lạt')),
        ],
      ),
    );
  }

  Widget _buildStep2ImagesDesc() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Hình ảnh phòng *'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: _imageFiles.length + 1,
            itemBuilder: (context, index) {
              if (index == _imageFiles.length) {
                return GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickMultiImage(imageQuality: 70);
                    if (picked.isNotEmpty) setState(() => _imageFiles.addAll(picked.map((e) => File(e.path))));
                  },
                  child: Container(
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), border: Border.all(color: Colors.blue.withOpacity(0.3), style: BorderStyle.solid), borderRadius: BorderRadius.circular(12)),
                    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_outlined, color: Colors.blue, size: 30), SizedBox(height: 4), Text('Thêm ảnh', style: TextStyle(color: Colors.blue, fontSize: 12))]),
                  ),
                );
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_imageFiles[index], fit: BoxFit.cover)),
                  Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => setState(() => _imageFiles.removeAt(index)), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14)))),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _buildLabel('Mô tả chi tiết *'),
          TextField(
            onChanged: (val) => _description = val,
            maxLines: 5,
            decoration: _inputDeco('Mô tả về phòng, tiện nghi, nội thất, khu vực xung quanh...'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [const Icon(Icons.info_outline, color: Colors.blue, size: 20), const SizedBox(width: 10), Expanded(child: Text('Mẹo nhỏ: Tin có ảnh và mô tả chi tiết sẽ thu hút nhiều người quan tâm hơn!', style: TextStyle(color: Colors.blue[800], fontSize: 13)))]),
          )
        ],
      ),
    );
  }

  Widget _buildStep3Amenities() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Tiện nghi có sẵn'),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9),
            itemCount: amenitiesList.length,
            itemBuilder: (context, index) {
              final item = amenitiesList[index];
              bool isSelected = _selectedAmenities.contains(item['name']);
              return GestureDetector(
                onTap: () {
                  setState(() { isSelected ? _selectedAmenities.remove(item['name']) : _selectedAmenities.add(item['name']); });
                },
                child: Container(
                  decoration: BoxDecoration(color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white, border: Border.all(color: isSelected ? Colors.blue : Colors.grey[200]!), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item['icon'], color: isSelected ? Colors.blue : Colors.grey[600], size: 24),
                      const SizedBox(height: 6),
                      Text(item['name'], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: isSelected ? Colors.blue : Colors.grey[800], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 30),
          _buildLabel('Yêu cầu người thuê'),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: requirementsList.map((req) {
              bool isSelected = _selectedRequirements.contains(req);
              return GestureDetector(
                onTap: () => setState(() { isSelected ? _selectedRequirements.remove(req) : _selectedRequirements.add(req); }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white, border: Border.all(color: isSelected ? Colors.blue : Colors.grey[300]!), borderRadius: BorderRadius.circular(100)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline, size: 16, color: isSelected ? Colors.blue : Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(req, style: TextStyle(color: isSelected ? Colors.blue : Colors.grey[800])),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Location() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Chọn vị trí trên bản đồ'),
          Container(
            height: 200, width: double.infinity,
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 50, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Khu vực hiển thị Bản đồ Google Maps', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildLabel('Địa chỉ chi tiết (Số nhà, hẻm, đường) *'),
          TextField(onChanged: (val) => _detailedAddress = val, decoration: _inputDeco('Số 10, đường Trần Phú')),
        ],
      ),
    );
  }

  Widget _buildStep5Review() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: _imageFiles.isNotEmpty ? Image.file(_imageFiles.first, width: 100, height: 100, fit: BoxFit.cover) : Container(width: 100, height: 100, color: Colors.grey[200])),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title.isNotEmpty ? _title : 'Chưa có tiêu đề', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.3)),
                    const SizedBox(height: 8),
                    Text('$_price đ/tháng', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('$_roomType - $_area m²', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              )
            ],
          ),
          const Divider(height: 40),
          _buildReviewItem('Địa chỉ', '$_detailedAddress, $_address'),
          _buildReviewItem('Tiện nghi', _selectedAmenities.isEmpty ? 'Không có' : _selectedAmenities.join(' • ')),
          _buildReviewItem('Yêu cầu', _selectedRequirements.isEmpty ? 'Không có' : _selectedRequirements.join(', ')),
          _buildLabel('Mô tả:'),
          const SizedBox(height: 8),
          Text(_description, style: TextStyle(color: Colors.grey[800], height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)));
  Widget _buildReviewItem(String title, String content) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 90, child: Text(title, style: TextStyle(color: Colors.grey[600]))), Expanded(child: Text(content, style: const TextStyle(fontWeight: FontWeight.w500)))]));
  InputDecoration _inputDeco(String hint, {String? suffix}) {
    return InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: Colors.grey[400]),
        suffixText: suffix,
        filled: true, fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
    );
  }
}

class PostSuccessScreen extends StatelessWidget {
  const PostSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, size: 70, color: Colors.green),
              ),
              const SizedBox(height: 32),
              const Text('Đăng tin thành công!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'Tin của bạn đã được đăng lên hệ thống.\nChúng tôi sẽ hiển thị trong thời gian sớm nhất.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPostsScreen()));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Xem tin của tôi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, side: const BorderSide(color: Colors.blue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Về trang chủ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
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

  // URL ảnh bìa mặc định
  final String coverPhotoUrl = 'https://images.unsplash.com/photo-1542224566-6e85f2e6772f?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80';

  final Map<String, List<String>> tagCategories = {
    'Sinh hoạt & Lối sống': ['🌙 Thức khuya', '🌅 Dậy sớm', '😴 Ngủ nhiều', '📚 Thích yên tĩnh', '🎮 Chơi game', '🎬 Xem phim', '🎵 Nghe nhạc', '📖 Đọc sách', '💻 Học tập nhiều', '🏸 Chơi thể thao', '🏋️ Tập gym', '🍳 Thích nấu ăn', '☕ Thích uống cà phê', '🧹 Thích sạch sẽ', '🌿 Thích cây xanh', '🤫 Ít nói', '🗣️ Thích giao tiếp', '😊 Hòa đồng', '🙋 Thích giao lưu', '🧘 Thích riêng tư', '🧼 Gọn gàng', '🕐 Sống theo lịch', '🏠 Thường xuyên ở phòng', '🚶 Thường xuyên ra ngoài'],
    'Yêu cầu tìm trọ': ['💰 Dưới 1 triệu', '💰 1–1,5 triệu', '💰 1,5–2 triệu', '💰 2–3 triệu', '💰 Trên 3 triệu', '🏫 Gần trường', '🚶 Đi bộ đến trường', '🛵 Dưới 5 phút', '🛵 Dưới 10 phút', '🛵 Dưới 15 phút', '🏙️ Gần trung tâm', '🛒 Gần chợ', '🏪 Gần cửa hàng tiện lợi', '🚌 Gần trạm xe buýt', '📶 Wi-Fi', '❄️ Máy lạnh', '🚿 WC riêng', '🧺 Máy giặt', '🛏️ Có sẵn giường', '🪑 Có sẵn nội thất', '🍳 Được nấu ăn', '🅿️ Chỗ để xe', '🔥 Có máy nước nóng', '🧊 Có tủ lạnh', '🪟 Có cửa sổ', '🌞 Phòng thoáng', '🌿 Có ban công', '🕐 Không giới hạn giờ về', '👥 Cho phép ở ghép', '👫 Cho phép bạn bè đến chơi', '🐱 Cho nuôi mèo', '🐶 Cho nuôi chó', '🚭 Không hút thuốc', '🔊 Không giới hạn tiếng ồn', '👨‍👩‍👧 Cho phép người thân ở lại', '📹 Camera', '🔐 Khóa vân tay', '🔑 Khóa cổng riêng', '🚪 Cổng 24/7', '👮 Khu vực an ninh', '💡 Khu vực có đèn đường', '🅿️ Bãi xe có camera'],
    'Ghép người ở chung': ['💰 Tiết kiệm chi phí', '🧹 Sạch sẽ', '🤫 Yên tĩnh', '🎮 Chơi game', '📚 Học tập', '🍳 Nấu ăn', '🚭 Không hút thuốc', '🍺 Không uống rượu', '🐱 Nuôi thú cưng', '👥 Thích giao lưu', '🔒 Tôn trọng riêng tư', '🛌 Ngủ sớm', '🎵 Thích nghe nhạc', '🏋️ Tập thể thao', '📅 Gọn gọn, ngăn nắp']
  };

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

  Future<void> _updateAvatar() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile == null) return;

    setState(() => isUploadingAvatar = true);
    try {
      String? downloadUrl = await _uploadImageToImgBB(File(pickedFile.path));
      if (downloadUrl != null) {
        await user?.updatePhotoURL(downloadUrl);
        await user?.reload();

        var batch = FirebaseFirestore.instance.batch();

        var myRoomsQuery = await FirebaseFirestore.instance.collection('rooms').where('ownerId', isEqualTo: user?.uid).get();
        for (var doc in myRoomsQuery.docs) {
          batch.update(doc.reference, {'ownerAvatar': downloadUrl});
        }

        var allRoomsQuery = await FirebaseFirestore.instance.collection('rooms').get();
        for (var roomDoc in allRoomsQuery.docs) {
          var commentsQuery = await roomDoc.reference
              .collection('comments')
              .where('userId', isEqualTo: user?.uid)
              .get();

          for (var commentDoc in commentsQuery.docs) {
            batch.update(commentDoc.reference, {'userAvatar': downloadUrl});
          }
        }

        await batch.commit();

        setState(() { user = FirebaseAuth.instance.currentUser; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật ảnh đại diện!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      setState(() => isUploadingAvatar = false);
    }
  }

  Future<void> _showEditTagsSheet(List<String> currentTags) async {
    List<String> selectedTags = List.from(currentTags);
    bool isSaving = false;

    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setStateSheet) {
                return DraggableScrollableSheet(
                  initialChildSize: 0.85,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  expand: false,
                  builder: (context, scrollController) {
                    return Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 5),
                          width: 40, height: 5,
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Sở thích & Yêu cầu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            children: tagCategories.entries.map((entry) {
                              return ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                childrenPadding: const EdgeInsets.only(bottom: 16),
                                children: [
                                  Wrap(
                                    spacing: 6, runSpacing: 8,
                                    children: entry.value.map((tag) {
                                      bool isSelected = selectedTags.contains(tag);
                                      return FilterChip(
                                        label: Text(tag, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? Colors.blue : Colors.grey[600])),
                                        selected: isSelected, showCheckmark: false,
                                        selectedColor: Colors.blue.withOpacity(0.1),
                                        backgroundColor: Colors.white, elevation: 0,
                                        padding: EdgeInsets.zero, labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: -2),
                                        side: BorderSide(color: isSelected ? Colors.blue : Colors.grey[300]!, width: 1.0),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                        onSelected: (bool selected) {
                                          setStateSheet(() {
                                            if (selected) selectedTags.add(tag);
                                            else selectedTags.remove(tag);
                                          });
                                        },
                                      );
                                    }).toList(),
                                  )
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 20),
                          decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
                          child: SizedBox(
                            width: double.infinity, height: 50,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : () async {
                                setStateSheet(() => isSaving = true);
                                try {
                                  await FirebaseFirestore.instance.collection('users').doc(user?.uid).set({'tags': selectedTags}, SetOptions(merge: true));
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                                } finally {
                                  if (mounted) setStateSheet(() => isSaving = false);
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu Tags', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                        )
                      ],
                    );
                  },
                );
              }
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
          builder: (context, snapshot) {
            String phone = '';
            List<String> tags = [];
            String bio = "Chưa có lời giới thiệu bản thân";
            String major = 'Chưa cập nhật';
            String school = 'Chưa cập nhật';
            String dob = 'Chưa cập nhật';

            if (snapshot.hasData && snapshot.data!.exists) {
              Map<String, dynamic> userData = snapshot.data!.data() as Map<String, dynamic>;
              if (userData['phone'] != null && userData['phone'].toString().isNotEmpty) phone = userData['phone'];
              if (userData['tags'] != null && (userData['tags'] as List).isNotEmpty) {
                tags = List<String>.from(userData['tags']);
              }
              if (userData['bio'] != null && userData['bio'].toString().isNotEmpty) bio = userData['bio'];
              if (userData['major'] != null && userData['major'].toString().isNotEmpty) major = userData['major'];
              if (userData['school'] != null && userData['school'].toString().isNotEmpty) school = userData['school'];
              if (userData['dob'] != null && userData['dob'].toString().isNotEmpty) dob = userData['dob'];
            }

            return SingleChildScrollView(
              child: Stack(
                children: [
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(image: NetworkImage(coverPhotoUrl), fit: BoxFit.cover),
                    ),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 28),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                        },
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 170),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 70),
                          Row(
                            children: [
                              Text(user?.displayName ?? 'Người dùng', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Colors.blue, size: 20),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Sinh viên • $school', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.security, color: Colors.green, size: 14),
                                SizedBox(width: 4),
                                Text('Đã xác thực', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(bio, style: TextStyle(fontSize: 14, color: Colors.grey[700], fontStyle: FontStyle.italic, height: 1.5)),
                          const SizedBox(height: 24),

                          // --- KHU VỰC THỐNG KÊ (ĐẾM SỐ LƯỢNG THỰC TẾ) ---
                          StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('rooms').where('ownerId', isEqualTo: user?.uid).snapshots(),
                              builder: (context, postSnapshot) {
                                int postCount = 0;
                                int totalLikesReceived = 0;

                                // Tính tổng lượt thích người khác thả cho phòng của mình
                                if (postSnapshot.hasData) {
                                  postCount = postSnapshot.data!.docs.length;
                                  for (var doc in postSnapshot.data!.docs) {
                                    var roomData = doc.data() as Map<String, dynamic>;
                                    if (roomData['likedBy'] != null) {
                                      totalLikesReceived += (roomData['likedBy'] as List).length;
                                    }
                                  }
                                }

                                // Lấy danh sách Follow Firebase
                                int followingCount = 0;
                                int followersCount = 0;
                                if (snapshot.hasData && snapshot.data!.exists) {
                                  Map<String, dynamic> userData = snapshot.data!.data() as Map<String, dynamic>;
                                  if (userData['following'] != null) followingCount = (userData['following'] as List).length;
                                  if (userData['followers'] != null) followersCount = (userData['followers'] as List).length;
                                }

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatColumn(postCount.toString(), 'Bài đăng', onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPostsScreen()));
                                    }),
                                    _buildVerticalDivider(),
                                    _buildStatColumn(totalLikesReceived.toString(), 'Lượt thích'),
                                    _buildVerticalDivider(),
                                    _buildStatColumn(followingCount.toString(), 'Đang theo dõi'),
                                    _buildVerticalDivider(),
                                    _buildStatColumn(followersCount.toString(), 'Người theo dõi'),
                                  ],
                                );
                              }
                          ),
                          // ------------------------------------------------

                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) => EditProfileScreen(
                                    phone: phone, major: major, school: school, dob: dob, bio: bio,
                                  ),
                                )).then((_) => setState(() { user = FirebaseAuth.instance.currentUser; }));
                              },
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Chỉnh sửa hồ sơ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue[700],
                                side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                                backgroundColor: Colors.blue.withOpacity(0.05),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildInfoCard(
                            title: 'Thông tin cá nhân',
                            icon: Icons.person_outline,
                            children: [
                              _buildInfoRow(Icons.phone_outlined, 'Số điện thoại', phone.isEmpty ? 'Chưa cập nhật' : phone),
                              _buildInfoRow(Icons.email_outlined, 'Email', user?.email ?? 'Chưa cập nhật'),
                              _buildInfoRow(Icons.school_outlined, 'Ngành học', major),
                              _buildInfoRow(Icons.account_balance_outlined, 'Trường', school),
                              _buildInfoRow(Icons.calendar_today_outlined, 'Ngày sinh', dob, isLast: true),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _buildInfoCard(
                            title: 'Sở thích & yêu cầu',
                            icon: Icons.dashboard_customize_outlined,
                            onEdit: () => _showEditTagsSheet(tags),
                            children: [
                              tags.isEmpty
                                  ? const Text('Chưa có thông tin', style: TextStyle(color: Colors.grey, fontSize: 14))
                                  : Wrap(
                                spacing: 8, runSpacing: 10,
                                children: tags.map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                                  child: Text(tag, style: TextStyle(color: Colors.blue[800], fontSize: 13, fontWeight: FontWeight.w500)),
                                )).toList(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                  child: const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Tài khoản đã xác thực', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                      const SizedBox(height: 4),
                                      Text('Đã xác minh danh tính và thẻ sinh viên', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 120,
                    left: 20,
                    child: GestureDetector(
                      onTap: _updateAvatar,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Color(0xFFF7F9FC), shape: BoxShape.circle),
                            child: isUploadingAvatar
                                ? const SizedBox(width: 90, height: 90, child: CircularProgressIndicator())
                                : CircleAvatar(radius: 45, backgroundColor: Colors.grey[200], backgroundImage: NetworkImage(user?.photoURL ?? defaultAvatarUrl)),
                          ),
                          Positioned(
                            bottom: 4, right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[300]);
  }

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> children, VoidCallback? onEdit}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withOpacity(0.15)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                    child: const Icon(Icons.edit_outlined, color: Colors.grey, size: 18),
                  ),
                )
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[500], size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 14)),
        ],
      ),
    );
  }
}
// ==========================================
// TRANG CHỈNH SỬA HỒ SƠ CƠ BẢN (CÓ CHỌN NGÀY THÁNG)
// ==========================================
class EditProfileScreen extends StatefulWidget {
  final String phone, major, school, dob, bio;

  const EditProfileScreen({
    super.key, required this.phone, required this.major,
    required this.school, required this.dob, required this.bio
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  late TextEditingController majorController;
  late TextEditingController schoolController;
  late TextEditingController dobController;
  late TextEditingController bioController;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: user?.displayName ?? '');
    phoneController = TextEditingController(text: widget.phone == 'Chưa cập nhật' ? '' : widget.phone);
    emailController = TextEditingController(text: user?.email ?? '');
    majorController = TextEditingController(text: widget.major == 'Chưa cập nhật' ? '' : widget.major);
    schoolController = TextEditingController(text: widget.school == 'Chưa cập nhật' ? '' : widget.school);
    dobController = TextEditingController(text: widget.dob == 'Chưa cập nhật' ? '' : widget.dob);
    bioController = TextEditingController(text: widget.bio == 'Chưa có lời giới thiệu bản thân' ? '' : widget.bio);
  }

  @override
  void dispose() {
    nameController.dispose(); phoneController.dispose(); emailController.dispose();
    majorController.dispose(); schoolController.dispose(); dobController.dispose(); bioController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    setState(() => isSaving = true);
    try {
      if (nameController.text.trim() != user?.displayName) {
        await user?.updateDisplayName(nameController.text.trim());
        await user?.reload();
      }

      await FirebaseFirestore.instance.collection('users').doc(user?.uid).set({
        'phone': phoneController.text.trim(),
        'major': majorController.text.trim(),
        'school': schoolController.text.trim(),
        'dob': dobController.text.trim(),
        'bio': bioController.text.trim(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // --- Hàm xử lý mở bảng chọn ngày ---
  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();

    // Nếu đã có ngày sinh trước đó, gán ngày đó làm mặc định khi mở lịch
    if (dobController.text.isNotEmpty && dobController.text != 'Chưa cập nhật') {
      try {
        List<String> parts = dobController.text.split('/');
        if (parts.length == 3) {
          initialDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (e) {
        initialDate = DateTime.now();
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900), // Cho phép chọn từ năm 1900
      lastDate: DateTime.now(),  // Không cho chọn ngày trong tương lai
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue, // Màu sắc đồng bộ với app
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        // Format ngày theo định dạng dd/MM/yyyy
        String formattedDate = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
        dobController.text = formattedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Chỉnh sửa hồ sơ', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: NetworkImage(user?.photoURL ?? defaultAvatarUrl),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.displayName ?? 'Người dùng', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Sinh viên • ${schoolController.text.isNotEmpty ? schoolController.text : "Đại học..."}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 32),

                  const Text('Thông báo cơ bản', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 16),

                  _buildLabelTextField(Icons.person_outline, 'Họ và tên', nameController),
                  _buildLabelTextField(Icons.phone_outlined, 'Số điện thoại', phoneController),
                  _buildLabelTextField(Icons.email_outlined, 'Email', emailController, readOnly: true),
                  _buildLabelTextField(Icons.school_outlined, 'Ngành học', majorController),
                  _buildLabelTextField(Icons.account_balance_outlined, 'Trường', schoolController),

                  // Gọi Date Picker khi ấn vào ô Ngày sinh
                  _buildLabelTextField(
                      Icons.calendar_today_outlined,
                      'Ngày sinh',
                      dobController,
                      isDate: true,
                      onTap: () => _selectDate(context)
                  ),

                  const SizedBox(height: 24),

                  const Text('Giới thiệu bản thân', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bioController,
                    maxLines: 4,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: 'Nhập vài dòng giới thiệu về bản thân bạn...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 20),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[100]!, width: 1.5))),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: isSaving ? null : saveProfile,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Bổ sung thêm biến onTap ---
  Widget _buildLabelTextField(IconData icon, String label, TextEditingController controller, {bool isDate = false, bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 46,
              child: TextField(
                controller: controller,
                // Nếu là trường Ngày tháng (isDate = true) thì tự động khóa bàn phím
                readOnly: readOnly || isDate,
                onTap: onTap, // Lắng nghe sự kiện click
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: readOnly ? Colors.grey[600] : Colors.black87),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  suffixIcon: isDate ? const Icon(Icons.calendar_today, size: 18, color: Colors.grey) : null,
                  fillColor: (readOnly && !isDate) ? Colors.grey[50] : Colors.white,
                  filled: (readOnly && !isDate),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blue)),
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
// TRANG TIN ĐĂNG CỦA TÔI
// ==========================================
class MyPostsScreen extends StatelessWidget {
  const MyPostsScreen({super.key});

  Future<void> _deletePost(BuildContext context, String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa tin đăng này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('rooms').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa bài viết')));
      }
    }
  }

  String _formatDate(DateTime date) {
    String d = date.day.toString().padLeft(2, '0');
    String m = date.month.toString().padLeft(2, '0');
    String y = date.year.toString();
    String h = date.hour.toString().padLeft(2, '0');
    String min = date.minute.toString().padLeft(2, '0');
    return '$h:$min $d/$m/$y';
  }

  String _formatPrice(double price) {
    if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(price % 1000000 == 0 ? 0 : 1)} Tr';
    return '${price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} đ';
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text('Tin đăng của tôi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), backgroundColor: Colors.white, elevation: 0, centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').where('ownerId', isEqualTo: user?.uid).orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.blue));
          if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('Bạn chưa có tin đăng nào.', style: TextStyle(color: Colors.grey, fontSize: 16)));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;
              DateTime postTime = DateTime.now();
              if (data['createdAt'] != null) postTime = (data['createdAt'] as Timestamp).toDate();

              Room room = Room(
                id: docId,
                ownerId: data['ownerId'] ?? '',
                title: data['title'] ?? '', address: data['address'] ?? '',
                price: (data['price'] ?? 0).toDouble(), imageUrl: data['imageUrl'] ?? '',
                imageUrls: List<String>.from(data['imageUrls'] ?? []),
                description: data['description'] ?? '', ownerName: data['ownerName'] ?? '',
                ownerAvatar: data['ownerAvatar'] ?? defaultAvatarUrl, roomType: data['roomType'] ?? 'Phòng đơn',
                area: data['area'] ?? '',
                amenities: List<String>.from(data['amenities'] ?? []),
                requirements: List<String>.from(data['requirements'] ?? []),
                createdAt: postTime, likedBy: List<String>.from(data['likedBy'] ?? []),
              );

              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RoomDetailScreen(room: room))),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(room.imageUrl, width: 90, height: 90, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 90, height: 90, color: Colors.grey[200], child: const Icon(Icons.image_not_supported, color: Colors.grey))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(room.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87, height: 1.3)),
                              const SizedBox(height: 6),
                              Text('${_formatPrice(room.price)}/tháng', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 6),
                              Row(children: [Icon(Icons.meeting_room_rounded, size: 14, color: Colors.grey[600]), const SizedBox(width: 4), Text(room.roomType, style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500))]),
                              const SizedBox(height: 4),
                              Row(children: [Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]), const SizedBox(width: 4), Text(_formatDate(room.createdAt), style: TextStyle(color: Colors.grey[500], fontSize: 12))]),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                            onSelected: (value) {
                              if (value == 'edit') Navigator.push(context, MaterialPageRoute(builder: (context) => EditPostScreen(room: room)));
                              else if (value == 'delete') _deletePost(context, docId);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, color: Colors.blue, size: 20), SizedBox(width: 8), Text('Sửa')])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, color: Colors.red, size: 20), SizedBox(width: 8), Text('Xóa')])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// TRANG CHỈNH SỬA TIN ĐĂNG (Cơ bản)
// ==========================================
class EditPostScreen extends StatefulWidget {
  final Room room;
  const EditPostScreen({super.key, required this.room});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController titleController;
  late TextEditingController addressController;
  late TextEditingController priceController;
  late TextEditingController descriptionController;
  late String _selectedRoomType;

  File? _newImageFile;
  bool isUpdating = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.room.title);
    addressController = TextEditingController(text: widget.room.address);
    priceController = TextEditingController(text: widget.room.price.toStringAsFixed(0));
    descriptionController = TextEditingController(text: widget.room.description);
    _selectedRoomType = widget.room.roomType;
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) setState(() => _newImageFile = File(pickedFile.path));
  }

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

  Future<void> updatePost() async {
    String title = titleController.text.trim();
    String address = addressController.text.trim();
    String priceText = priceController.text.trim();
    String description = descriptionController.text.trim();

    if (title.isEmpty || address.isEmpty || priceText.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')));
      return;
    }
    double? price = double.tryParse(priceText);

    setState(() => isUpdating = true);
    try {
      String finalImageUrl = widget.room.imageUrl;
      List<String> finalImageUrls = List.from(widget.room.imageUrls);

      if (_newImageFile != null) {
        String? downloadUrl = await _uploadImageToImgBB(_newImageFile!);
        if (downloadUrl != null) {
          finalImageUrl = downloadUrl;
          if (finalImageUrls.isEmpty) finalImageUrls.add(downloadUrl);
          else finalImageUrls[0] = downloadUrl;
        }
      }

      await FirebaseFirestore.instance.collection('rooms').doc(widget.room.id).update({
        'title': title, 'address': address, 'price': price, 'description': description,
        'imageUrl': finalImageUrl, 'imageUrls': finalImageUrls, 'roomType': _selectedRoomType,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Chỉnh sửa tin đăng', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)), backgroundColor: Colors.white, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity, height: 180,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[300]!)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _newImageFile != null
                      ? Image.file(_newImageFile!, fit: BoxFit.cover, width: double.infinity)
                      : Image.network(widget.room.imageUrl, fit: BoxFit.cover, width: double.infinity, errorBuilder: (c, e, s) => Container(color: Colors.grey[200])),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Nhấn vào ảnh để đổi ảnh bìa', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRoomType = 'Phòng đơn'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: _selectedRoomType == 'Phòng đơn' ? Colors.blue : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text('Phòng đơn', style: TextStyle(color: _selectedRoomType == 'Phòng đơn' ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRoomType = 'Phòng ghép'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: _selectedRoomType == 'Phòng ghép' ? Colors.orange : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text('Phòng ghép', style: TextStyle(color: _selectedRoomType == 'Phòng ghép' ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(controller: titleController, decoration: InputDecoration(hintText: 'Tiêu đề', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 15),
            TextField(controller: addressController, decoration: InputDecoration(hintText: 'Địa chỉ', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 15),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'Giá', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 15),
            TextField(controller: descriptionController, maxLines: 4, decoration: InputDecoration(hintText: 'Mô tả', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: isUpdating ? null : updatePost,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: isUpdating ? const CircularProgressIndicator(color: Colors.white) : const Text('LƯU THAY ĐỔI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// CÁC MÀN HÌNH KHÁC & ĐIỀU HƯỚNG
// ==========================================
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
      Navigator.push(context, MaterialPageRoute(builder: (context) => const PostTab()));
    } else {
      setState(() { _selectedIndex = index; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1))),
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
        width: 60, height: 55,
        child: Center(
          child: Icon(isSelected ? selectedIcon : unselectedIcon, color: isSelected ? Colors.black : Colors.grey[500], size: 30),
        ),
      ),
    );
  }
}

// ==========================================
// TRANG PHÒNG ĐÃ LƯU
// ==========================================
class SavedRoomsScreen extends StatelessWidget {
  const SavedRoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Phòng đã lưu', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)), backgroundColor: Colors.white, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: Colors.black)),
      body: user == null
          ? const Center(child: Text('Vui lòng đăng nhập để xem phòng đã lưu.'))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').where('likedBy', arrayContains: user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.blue));
          if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));

          final roomDocs = snapshot.data?.docs ?? [];
          if (roomDocs.isEmpty) return const Center(child: Text('Bạn chưa lưu phòng trọ nào.', style: TextStyle(color: Colors.grey, fontSize: 16)));

          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
            itemCount: roomDocs.length,
            itemBuilder: (context, index) {
              final data = roomDocs[index].data() as Map<String, dynamic>;
              DateTime postTime = DateTime.now();
              if (data['createdAt'] != null) postTime = (data['createdAt'] as Timestamp).toDate();

              final room = Room(
                id: roomDocs[index].id,
                ownerId: data['ownerId'] ?? '',
                title: data['title'] ?? '', address: data['address'] ?? '',
                price: (data['price'] ?? 0).toDouble(), imageUrl: data['imageUrl'] ?? '',
                imageUrls: List<String>.from(data['imageUrls'] ?? []),
                description: data['description'] ?? '', ownerName: data['ownerName'] ?? 'Người dùng',
                ownerAvatar: data['ownerAvatar'] ?? defaultAvatarUrl, roomType: data['roomType'] ?? 'Phòng đơn',
                area: data['area'] ?? '',
                amenities: List<String>.from(data['amenities'] ?? []),
                requirements: List<String>.from(data['requirements'] ?? []),
                createdAt: postTime, likedBy: List<String>.from(data['likedBy'] ?? []),
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
// TRANG CÁ NHÂN NGƯỜI KHÁC (PUBLIC PROFILE)
// ==========================================
class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final String coverPhotoUrl = 'https://images.unsplash.com/photo-1542224566-6e85f2e6772f?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80';

  @override
  Widget build(BuildContext context) {
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    bool isMe = currentUserId == widget.userId; // Kiểm tra xem có phải trang của chính mình không

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18)
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
          builder: (context, snapshot) {
            String name = 'Người dùng';
            String avatar = defaultAvatarUrl;
            String bio = "Chưa có lời giới thiệu bản thân";
            String school = 'Chưa cập nhật';

            if (snapshot.hasData && snapshot.data!.exists) {
              Map<String, dynamic> userData = snapshot.data!.data() as Map<String, dynamic>;
              if (userData['bio'] != null && userData['bio'].toString().isNotEmpty) bio = userData['bio'];
              if (userData['school'] != null && userData['school'].toString().isNotEmpty) school = userData['school'];
            }

            return SingleChildScrollView(
              child: Stack(
                children: [
                  // 1. Ảnh bìa
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(coverPhotoUrl), fit: BoxFit.cover)),
                  ),

                  // 2. Nội dung chính
                  Container(
                    margin: const EdgeInsets.only(top: 170),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 60),

                          // Lấy tên và avatar từ bài đăng đầu tiên của họ để dự phòng
                          StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('rooms').where('ownerId', isEqualTo: widget.userId).limit(1).snapshots(),
                              builder: (context, roomSnap) {
                                if (roomSnap.hasData && roomSnap.data!.docs.isNotEmpty) {
                                  var data = roomSnap.data!.docs.first.data() as Map<String, dynamic>;
                                  name = data['ownerName'] ?? name;
                                  avatar = data['ownerAvatar'] ?? avatar;
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.verified, color: Colors.blue, size: 20),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Sinh viên • $school', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                                  ],
                                );
                              }
                          ),

                          const SizedBox(height: 16),
                          Text(bio, style: TextStyle(fontSize: 14, color: Colors.grey[700], fontStyle: FontStyle.italic, height: 1.5)),
                          const SizedBox(height: 24),

                          // Stats & Nút theo dõi (LẤY DỮ LIỆU THỰC TẾ)
                          StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('rooms').where('ownerId', isEqualTo: widget.userId).snapshots(),
                              builder: (context, postSnapshot) {
                                int postCount = 0;
                                int totalLikes = 0;

                                // 1. Cộng dồn tất cả lượt thích từ các bài đăng
                                if (postSnapshot.hasData) {
                                  postCount = postSnapshot.data!.docs.length;
                                  for (var doc in postSnapshot.data!.docs) {
                                    var data = doc.data() as Map<String, dynamic>;
                                    if (data['likedBy'] != null) {
                                      totalLikes += (data['likedBy'] as List).length;
                                    }
                                  }
                                }

                                // 2. Lấy số lượng người theo dõi từ Firebase
                                int followersCount = 0;
                                bool currentIsFollowing = false;

                                if (snapshot.hasData && snapshot.data!.exists) {
                                  Map<String, dynamic> userData = snapshot.data!.data() as Map<String, dynamic>;
                                  List<dynamic> followers = userData['followers'] ?? [];
                                  followersCount = followers.length;
                                  currentIsFollowing = followers.contains(currentUserId);
                                }

                                return Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildStatColumn(postCount.toString(), 'Bài đăng'),
                                        _buildVerticalDivider(),
                                        _buildStatColumn(totalLikes.toString(), 'Lượt thích'),
                                        _buildVerticalDivider(),
                                        _buildStatColumn(followersCount.toString(), 'Người theo dõi'),
                                      ],
                                    ),
                                    const SizedBox(height: 24),

                                    // 3. NÚT THEO DÕI (Đẩy dữ liệu thực tế lên Firebase)
                                    if (!isMe)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: SizedBox(
                                              height: 48,
                                              child: ElevatedButton(
                                                onPressed: () async {
                                                  if (currentUserId.isEmpty) {
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập')));
                                                    return;
                                                  }

                                                  DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
                                                  DocumentReference myRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);

                                                  if (currentIsFollowing) {
                                                    // Hủy theo dõi
                                                    await userRef.update({'followers': FieldValue.arrayRemove([currentUserId])}).catchError((_) {});
                                                    await myRef.update({'following': FieldValue.arrayRemove([widget.userId])}).catchError((_) {});
                                                  } else {
                                                    // Theo dõi
                                                    await userRef.update({'followers': FieldValue.arrayUnion([currentUserId])}).catchError((_) {});
                                                    await myRef.update({'following': FieldValue.arrayUnion([widget.userId])}).catchError((_) {});
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: currentIsFollowing ? Colors.grey[200] : Colors.blue,
                                                  foregroundColor: currentIsFollowing ? Colors.black87 : Colors.white,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                child: Text(
                                                    currentIsFollowing ? 'Đang theo dõi' : 'Theo dõi',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            height: 48, width: 48,
                                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                            child: IconButton(
                                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.blue),
                                              onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng nhắn tin đang phát triển')));
                                              },
                                            ),
                                          )
                                        ],
                                      ),
                                  ],
                                );
                              }
                          ),

                          if (!isMe) const SizedBox(height: 30),

                          const Text('Bài đăng gần đây', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),

                          // Danh sách phòng của người dùng này
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('rooms').where('ownerId', isEqualTo: widget.userId).orderBy('createdAt', descending: true).snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('Người dùng này chưa có bài đăng nào.')));

                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75,
                                ),
                                itemCount: snapshot.data!.docs.length,
                                itemBuilder: (context, index) {
                                  final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                                  DateTime postTime = DateTime.now();
                                  if (data['createdAt'] != null) postTime = (data['createdAt'] as Timestamp).toDate();

                                  final room = Room(
                                    id: snapshot.data!.docs[index].id,
                                    ownerId: widget.userId,
                                    title: data['title'] ?? '', address: data['address'] ?? '',
                                    price: (data['price'] ?? 0).toDouble(), imageUrl: data['imageUrl'] ?? '',
                                    imageUrls: List<String>.from(data['imageUrls'] ?? []),
                                    description: data['description'] ?? '', ownerName: data['ownerName'] ?? '',
                                    ownerAvatar: data['ownerAvatar'] ?? defaultAvatarUrl, roomType: data['roomType'] ?? 'Phòng đơn',
                                    area: data['area'] ?? '',
                                    createdAt: postTime,
                                    likedBy: List<String>.from(data['likedBy'] ?? []),
                                  );
                                  return RoomGridItem(room: room);
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),

                  // 3. Avatar đè lên bìa
                  Positioned(
                    top: 120,
                    left: 20,
                    child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('rooms').where('ownerId', isEqualTo: widget.userId).limit(1).snapshots(),
                        builder: (context, snap) {
                          String userAvatar = defaultAvatarUrl;
                          if (snap.hasData && snap.data!.docs.isNotEmpty) {
                            userAvatar = (snap.data!.docs.first.data() as Map<String, dynamic>)['ownerAvatar'] ?? defaultAvatarUrl;
                          }
                          return Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Color(0xFFF7F9FC), shape: BoxShape.circle),
                            child: CircleAvatar(radius: 45, backgroundColor: Colors.grey[200], backgroundImage: NetworkImage(userAvatar)),
                          );
                        }
                    ),
                  ),
                ],
              ),
            );
          }
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[300]);
  }
}