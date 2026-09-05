import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  bool _isValidEmail(String email) {
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) return false;

    final blacklistedDomains = [
      'yopmail.com', 'mailinator.com', 'tempmail.com', 'guerrillamail.com',
      '10minutemail.com', 'trashmail.com', 'getnada.com', 'temp-mail.org',
      'sharklasers.com', 'dispostable.com', 'burnemail.com', 'chacuo.net'
    ];

    final domain = email.split('@').last.toLowerCase();
    return !blacklistedDomains.contains(domain);
  }

  Future<void> register() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    
    if (email.isEmpty || password.isEmpty || nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')));
      return;
    }

    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email không hợp lệ hoặc thuộc danh sách email rác. Vui lòng dùng email thật.')),
      );
      return;
    }

    if (password != confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu không khớp')));
      return;
    }
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await userCredential.user?.updateDisplayName(nameController.text.trim());
      await userCredential.user?.sendEmailVerification();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thành công! Vui lòng kiểm tra email để xác thực tài khoản.')),
      );
      
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.message}')));
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
                const SizedBox(height: 20),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.person_add_rounded, size: 45, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text('Tạo tài khoản mới', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Đăng ký', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 25),
                      _buildRegisterField(nameController, 'Họ tên', Icons.person_outline),
                      const SizedBox(height: 16),
                      _buildRegisterField(emailController, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 16),
                      _buildRegisterField(passwordController, 'Mật khẩu', Icons.lock_outline, obscureText: true),
                      const SizedBox(height: 16),
                      _buildRegisterField(confirmPasswordController, 'Xác nhận mật khẩu', Icons.lock_reset_outlined, obscureText: true),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton(
                          onPressed: register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('ĐĂNG KÝ', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Đã có tài khoản? '),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterField(TextEditingController controller, String hint, IconData icon, {bool obscureText = false, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true, fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
