import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main_page.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool isEmailVerified = false;
  bool canResendEmail = true;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      timer = Timer.periodic(const Duration(seconds: 3), (_) => checkEmailVerified());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        if (mounted) {
          setState(() {
            isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint('Check email verification error: $e');
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      setState(() => canResendEmail = false);
      await Future.delayed(const Duration(seconds: 30));
      if (mounted) setState(() => canResendEmail = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => isEmailVerified
      ? const MainPage()
      : Scaffold(
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
                        color: Colors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mark_email_unread_rounded, size: 50, color: Colors.blue),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Xác thực Email',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 35),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Một email xác thực đã được gửi tới địa chỉ của bạn. Vui lòng kiểm tra hộp thư (bao gồm cả thư rác).',
                            style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity, height: 55,
                            child: ElevatedButton.icon(
                              onPressed: canResendEmail ? resendVerificationEmail : null,
                              icon: const Icon(Icons.send_rounded),
                              label: Text(canResendEmail ? 'GỬI LẠI EMAIL' : 'VUI LÒNG ĐỢI...'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextButton(
                            onPressed: () => FirebaseAuth.instance.signOut(),
                            child: const Text(
                              'Hủy bỏ & Quay lại đăng nhập',
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
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
