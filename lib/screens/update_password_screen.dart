import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class UpdatePasswordScreen extends StatefulWidget {
  final String email;
  const UpdatePasswordScreen({super.key, required this.email});

  static const routeName = '/update-password';

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _updatePassword() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
  });

  try {
    final email = widget.email.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // ✅ ตรวจสอบว่ารหัสผ่านตรงกันไหม
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorMessage = 'กรุณากรอกรหัสผ่านให้ครบถ้วน');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'รหัสผ่านทั้งสองไม่ตรงกัน');
      return;
    }

    // ✅ ค้นหา user จาก Firestore
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() => _errorMessage = 'ไม่พบบัญชีนี้ในระบบค่ะ');
      return;
    }

    // ✅ ดึง document แรก (user นั้น) มา update password ใน Firestore ด้วย
    final userDoc = snapshot.docs.first.reference;
    await userDoc.update({'password': newPassword});

    // ✅ อัปเดตใน Firebase Auth ด้วย
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    if (user != null) {
      // ถ้ามี user login อยู่ (เช่นรีเซ็ตรหัสตอนอยู่ในระบบ)
      await user.updatePassword(newPassword);
    } else {
      // ถ้าไม่มี user login (กรณี reset ผ่าน OTP)
      // ลอง reauthenticate ด้วย credential ใหม่ก่อน
      final creds = EmailAuthProvider.credential(
        email: email,
        password: confirmPassword,
      );
      final newUser = await auth.signInWithCredential(creds);
      await newUser.user?.updatePassword(newPassword);
    }

    setState(() {
      _successMessage = 'อัปเดตรหัสผ่านสำเร็จแล้ว 🎉';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('เปลี่ยนรหัสผ่านเรียบร้อยแล้ว 💖'),
        backgroundColor: Color(0xFFFF6FA5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    setState(() => _errorMessage = 'เกิดข้อผิดพลาด: $e');
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
            const Text("Set a new password",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              "Create a new password. Ensure it differs from previous ones for security",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            if (_successMessage != null)
              Text(_successMessage!,
                  style: const TextStyle(color: Colors.green)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6FA5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Update Password",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
