import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';


class UpdatePasswordScreen extends StatefulWidget {
  final String? email; // ✅ ใช้ได้ทั้งจาก reset และ settings
  const UpdatePasswordScreen({super.key, this.email});

  static const routeName = '/update-password';

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isPressed = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _updatePassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final email = widget.email ?? FirebaseAuth.instance.currentUser?.email;
      if (email == null) {
        setState(() => _errorMessage = 'ไม่พบอีเมลของผู้ใช้');
        return;
      }

      final newPassword = _newPasswordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();
      final currentPassword = _currentPasswordController.text.trim();

      if (newPassword.isEmpty || confirmPassword.isEmpty) {
        setState(() => _errorMessage = 'กรุณากรอกรหัสผ่านให้ครบถ้วน');
        return;
      }
      if (newPassword != confirmPassword) {
        setState(() => _errorMessage = 'รหัสผ่านทั้งสองไม่ตรงกัน');
        return;
      }

      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      if (user != null) {
        final cred = EmailAuthProvider.credential(
          email: email,
          password: currentPassword.isNotEmpty ? currentPassword : confirmPassword,
        );
        await user.reauthenticateWithCredential(cred);
        await user.updatePassword(newPassword);

        await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .get()
            .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            snapshot.docs.first.reference.update({'password': newPassword});
          }
        });
      } else {
        final creds = EmailAuthProvider.credential(
          email: email,
          password: confirmPassword,
        );
        final newUser = await auth.signInWithCredential(creds);
        await newUser.user?.updatePassword(newPassword);
      }


      // ✅ แสดง Popup แบบพาสเทลมนๆ
      final snackBar = SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: AwesomeSnackbarContent(
          title: 'สำเร็จแล้ว 💗',
          message: 'รหัสผ่านของคุณได้รับการอัปเดตเรียบร้อย!',
          contentType: ContentType.success,
          color: const Color(0xFFFFC1D0), // พาสเทลชมพู
          inMaterialBanner: false,
        ),
      );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);

      Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = 'เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFromSettings = widget.email == null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFromSettings ? "Change Password" : "Set a new password",
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isFromSettings
                  ? "กรอกรหัสผ่านเดิมเพื่อยืนยัน และตั้งรหัสใหม่สำหรับบัญชีของคุณ"
                  : "Create a new password. Ensure it differs from previous ones for security.",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // ✅ current password (เฉพาะ Settings)
            if (isFromSettings)
              _buildSmoothField(
                controller: _currentPasswordController,
                hint: "Current Password",
              ),
            if (isFromSettings) const SizedBox(height: 18),

            _buildSmoothField(
              controller: _newPasswordController,
              hint: "New Password",
            ),
            const SizedBox(height: 18),
            _buildSmoothField(
              controller: _confirmPasswordController,
              hint: "Confirm Password",
            ),

            const SizedBox(height: 28),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            if (_successMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_successMessage!,
                    style: const TextStyle(color: Colors.green)),
              ),

            GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) async {
                await Future.delayed(const Duration(milliseconds: 100));
                setState(() => _isPressed = false);
                if (!_isLoading) _updatePassword();
              },
              onTapCancel: () => setState(() => _isPressed = false),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 150),
                scale: _isPressed ? 0.95 : 1.0, // 💖 เด้งลงเบาๆ
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _isLoading
                        ? Colors.pink.shade200
                        : const Color(0xFFFF8FBF),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Confirm Change",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🌸 ช่องกรอกมน ๆ มีเงาเบา ๆ
  Widget _buildSmoothField({
  required TextEditingController controller,
  required String hint,
}) {
  return StatefulBuilder(
    builder: (context, setInnerState) {
      bool isFocused = false;

      return Focus(
        onFocusChange: (focus) {
          setInnerState(() => isFocused = focus);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.identity()
            // ignore: dead_code, deprecated_member_use
            ..scale(isFocused ? 1.02 : 1.0), // 🌸 ขยายขึ้นเล็กน้อย
          decoration: BoxDecoration(
            color: const Color(0xFFFDF6F9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isFocused
                    // ignore: dead_code, deprecated_member_use
                    ? Color(0xFFFFC0CB).withOpacity(0.25)
                    // ignore: deprecated_member_use
                    : Colors.black.withOpacity(0.05),
                // ignore: dead_code
                blurRadius: isFocused ? 10 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: true,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      );
    },
  );
}
}
