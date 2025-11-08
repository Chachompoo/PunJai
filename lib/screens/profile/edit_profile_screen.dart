import 'dart:io';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'settings_page.dart';

class EditProfileScreen extends StatefulWidget {
  static const routeName = '/edit_profile';
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _loading = false;
  bool _isPressed = false;
  File? _imageFile;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    setState(() {
      _firstNameCtrl.text = data['firstname'] ?? '';
      _lastNameCtrl.text = data['lastname'] ?? '';
      _usernameCtrl.text = data['username'] ?? '';
      _phoneCtrl.text = data['phone'] ?? '';
      _bioCtrl.text = data['bio'] ?? '';
      _profileImageUrl = data['profileImage'] ??
          'https://cdn-icons-png.flaticon.com/512/149/149071.png';
    });
  }

  Future<void> _pickImage() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<String> _uploadImage(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not found');
    final ref = FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _saveProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loading = true);

    try {
      String imageUrl = _profileImageUrl ?? '';
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
      }

      await _db.collection('users').doc(uid).update({
        'firstname': _firstNameCtrl.text.trim(),
        'lastname': _lastNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'profileImage': imageUrl,
      });

      if (!mounted) return;

      _showFloatingHeart(context);

      final snackBar = SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: AwesomeSnackbarContent(
          title: 'สำเร็จแล้ว 💗',
          message: 'โปรไฟล์ของคุณได้รับการอัปเดตเรียบร้อย!',
          contentType: ContentType.success,
          color: const Color(0xFFFFC1D0),
        ),
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (_, __, ___) => const SettingsPage(),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(
              opacity: anim,
              child: child,
            ),
          ),
        );
      }
    } catch (e) {
      final snackBar = SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: AwesomeSnackbarContent(
          title: 'Error!',
          message: 'เกิดข้อผิดพลาด: $e',
          contentType: ContentType.failure,
        ),
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);
    } finally {
      setState(() => _loading = false);
    }
  }

  /// 💕 หัวใจลอยตอนบันทึก
  void _showFloatingHeart(BuildContext context) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.45,
        left: MediaQuery.of(context).size.width * 0.45,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: -100),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: 1 - (value.abs() / 100),
            child: Transform.translate(
              offset: Offset(0, value),
              child: const Icon(Icons.favorite,
                  size: 48, color: Color(0xFFFF8FBF)),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(milliseconds: 950), overlayEntry.remove);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : (_profileImageUrl != null
                                ? NetworkImage(_profileImageUrl!)
                                : const AssetImage('assets/default_avatar.png'))
                                as ImageProvider,
                      ),
                      InkWell(
                        onTap: _pickImage,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF8FBF),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // 🌸 ฟิลด์กรอกมน ๆ พร้อมเงา
                  _buildSmoothField(_firstNameCtrl, "First Name"),
                  const SizedBox(height: 18),
                  _buildSmoothField(_lastNameCtrl, "Last Name"),
                  const SizedBox(height: 18),
                  _buildSmoothField(_usernameCtrl, "Username"),
                  const SizedBox(height: 18),
                  _buildSmoothField(_phoneCtrl, "Phone Number",
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 18),
                  _buildSmoothField(_bioCtrl, "Bio",
                      maxLines: 3),

                  const SizedBox(height: 28),

                  GestureDetector(
                    onTapDown: (_) => setState(() => _isPressed = true),
                    onTapUp: (_) async {
                      await Future.delayed(const Duration(milliseconds: 100));
                      setState(() => _isPressed = false);
                      if (!_loading) _saveProfile();
                    },
                    onTapCancel: () => setState(() => _isPressed = false),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 150),
                      scale: _isPressed ? 0.95 : 1.0,
                      curve: Curves.easeOut,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8FBF),
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
                          child: _loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  "Save Changes",
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

  /// 🌷 ช่องกรอกมน ๆ แบบโฟกัสแล้วขยายเหมือนหน้าเปลี่ยนรหัส + label ด้านบน
Widget _buildSmoothField(TextEditingController controller, String label,
    {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
  return StatefulBuilder(
    builder: (context, setInnerState) {
      bool isFocused = false;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🌸 ข้อความด้านบนช่อง
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF43593E),
              ),
            ),
          ),

          // 🌸 ช่องกรอกมน ๆ
          Focus(
            onFocusChange: (focus) => setInnerState(() => isFocused = focus),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              transform: Matrix4.identity()..scale(isFocused ? 1.02 : 1.0),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF6F9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isFocused
                        ? const Color(0xFFFFC0CB).withOpacity(0.25)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: isFocused ? 10 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                maxLines: maxLines,
                keyboardType: keyboardType,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: '',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
}
