import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'verify_code_screen.dart';
import '../services/email_service.dart';
import '../widgets/fade_slide_route.dart'; // ✅ route animation ที่เราสร้าง

class ForgotPasswordScreen extends StatefulWidget {
  static const routeName = '/forgot-password';
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  final AudioPlayer _player = AudioPlayer();

  Future<void> _sendResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกอีเมลให้ถูกต้อง')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ สร้าง PIN 5 หลัก
      final code = (10000 + Random().nextInt(90000)).toString();

      // ✅ บันทึกลง Firestore
      await FirebaseFirestore.instance
          .collection('password_resets')
          .doc(email)
          .set({
        'email': email,
        'code': code,
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ ตั้ง timer ลบ PIN หลังหมดอายุ (client side)
      Future.delayed(const Duration(minutes: 5), () async {
        final doc = FirebaseFirestore.instance.collection('password_resets').doc(email);
        final snapshot = await doc.get();
        if (snapshot.exists) {
          await doc.delete();
          debugPrint('🧹 PIN for $email deleted (expired)');
        }
      });

      // ✅ ส่งอีเมล
      await EmailService.sendResetCodeEmail(email, code);

      // 🔊 เล่นเสียงติ๊งตอนสำเร็จ
      await _player.play(AssetSource('sounds/success.mp3'));

      // ✅ เปลี่ยนหน้าแบบ fade-slide
      if (mounted) {
        Navigator.push(
          context,
          FadeSlidePageRoute(page: VerifyCodeScreen(email: email)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Forgot password",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Please enter your email to reset the password",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 28),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Your Email',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendResetCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6FA5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Reset Password",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
