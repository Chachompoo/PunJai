import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class SignupScreen extends StatefulWidget {
  static const routeName = '/signup';
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();


  bool isLoading = false;

  // รูปบัตรประชาชน
  File? _frontImage;
  File? _backImage;
  File? _selfieImage;

  Future<void> _pickImage(ImageSource source, String type) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked == null) return;

    setState(() {
      if (type == 'front') _frontImage = File(picked.path);
      if (type == 'back') _backImage = File(picked.path);
      if (type == 'selfie') _selfieImage = File(picked.path);
    });
  }

  // อัปโหลดรูปไป Storage
  Future<String> _uploadToStorage(File file, String path) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('id_cards')
        .child('${DateTime.now().millisecondsSinceEpoch}_$path.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (passwordController.text.trim() != confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("รหัสผ่านและยืนยันรหัสผ่านไม่ตรงกัน 💗"),
      ));
      return;
    }

    if (_frontImage == null || _backImage == null || _selfieImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("กรุณาอัปโหลดรูปบัตรประชาชนให้ครบทั้ง 3 รูปค่ะ 💗"),
      ));
      return;
    }

    setState(() => isLoading = true);

    try {
      // 🔹 สมัครสมาชิก
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user == null) return;

      // 🔹 อัปโหลดรูป 3 ใบ
      final frontUrl = await _uploadToStorage(_frontImage!, 'front');
      final backUrl = await _uploadToStorage(_backImage!, 'back');
      final selfieUrl = await _uploadToStorage(_selfieImage!, 'selfie');

      // 🔹 บันทึกข้อมูลใน Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': emailController.text.trim(),
        'username': usernameController.text.trim(),
        'firstname': firstnameController.text.trim(),
        'lastname': lastnameController.text.trim(),
        'phone': phoneController.text.trim(),
        'profileImage': 'https://cdn-icons-png.flaticon.com/512/149/149071.png',
        'idCardFront': frontUrl,
        'idCardBack': backUrl,
        'selfieWithId': selfieUrl,
        'status': 'pending_verification', // 🔸 ยังไม่ยืนยัน
        'rejectReason': '',
        'role': 'user',
        'createdAt': Timestamp.now(),
        'points': 0.0,
      });

      // ✅ แจ้งเตือน
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final snackBar = SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: AwesomeSnackbarContent(
          title: 'สมัครสมาชิกสำเร็จ 🎉',
          message:
              'ข้อมูลของคุณถูกส่งให้ผู้ดูแลตรวจสอบแล้ว\nโปรดรอการยืนยันทางอีเมลก่อนเข้าสู่ระบบค่ะ 💌',
          contentType: ContentType.success,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);

      Future.delayed(const Duration(seconds: 3), () {
        Navigator.pushReplacementNamed(context, '/login');
      });
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final errorSnack = SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: AwesomeSnackbarContent(
          title: 'เกิดข้อผิดพลาด 😢',
          message: e.message ?? 'ไม่สามารถสมัครสมาชิกได้ กรุณาลองใหม่อีกครั้ง',
          contentType: ContentType.failure,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(errorSnack);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kPink = const Color(0xFFFF8FB1);
    final kBlue = const Color(0xFFB3E5FC);
    final kYellow = const Color(0xFFFFF59D);
    final kText = const Color(0xFF393E46);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kPink.withOpacity(0.2),
              kBlue.withOpacity(0.2),
              kYellow.withOpacity(0.2)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: kPink.withOpacity(0.3),
                        child: const Icon(Icons.favorite,
                            color: Colors.pinkAccent, size: 42),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Create Your Account 💖',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: kText,
                        ),
                      ),
                      const SizedBox(height: 28),

                      _buildField('อีเมล', emailController,
                          icon: Icons.email_outlined,
                          validator: (v) =>
                              v!.isEmpty ? 'กรุณากรอกอีเมล' : null),
                      _buildField('รหัสผ่าน', passwordController,
                          icon: Icons.lock_outline,
                          obscure: true,
                          validator: (v) =>
                              v!.length < 6 ? 'รหัสผ่านต้องอย่างน้อย 6 ตัว' : null),
                      _buildField(
                      'ยืนยันรหัสผ่าน',
                      confirmPasswordController,
                      icon: Icons.lock_outline,
                      obscure: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'กรุณากรอกยืนยันรหัสผ่าน';
                        if (v != passwordController.text) return 'รหัสผ่านไม่ตรงกัน';
                        return null;
                      },
                    ),

                      _buildField('ชื่อผู้ใช้ (Username)', usernameController,
                          icon: Icons.person_outline,
                          validator: (v) =>
                              v!.isEmpty ? 'กรุณากรอกชื่อผู้ใช้' : null),
                      _buildField('ชื่อจริง', firstnameController,
                          icon: Icons.badge_outlined,
                          validator: (v) =>
                              v!.isEmpty ? 'กรุณากรอกชื่อจริง' : null),
                      _buildField('นามสกุล', lastnameController,
                          icon: Icons.badge_outlined,
                          validator: (v) =>
                              v!.isEmpty ? 'กรุณากรอกนามสกุล' : null),
                      _buildField('เบอร์โทรศัพท์', phoneController,
                          icon: Icons.phone_outlined,
                          type: TextInputType.phone,
                          validator: (v) =>
                              v!.isEmpty ? 'กรุณากรอกเบอร์โทรศัพท์' : null),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),

                      const Text(
                        'อัปโหลดรูปบัตรประชาชน 📄',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),

                      _buildImagePicker('บัตรด้านหน้า', _frontImage, 'front'),
                      _buildImagePicker('บัตรด้านหลัง', _backImage, 'back'),
                      _buildImagePicker('รูปคู่บัตร', _selfieImage, 'selfie'),

                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : registerUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'ส่งข้อมูลให้ผู้ดูแลตรวจสอบ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          icon: const Icon(Icons.arrow_back, color: Colors.pinkAccent),
                          label: const Text(
                            'กลับไปหน้าเข้าสู่ระบบ',
                            style: TextStyle(
                              color: Colors.pinkAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.pinkAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: Text(
                          'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ',
                          style: TextStyle(
                            color: kText,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {IconData? icon,
      bool obscure = false,
      TextInputType type = TextInputType.text,
      String? Function(String?)? validator}) {
    final kPink = const Color(0xFFFF8FB1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: type,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: kPink),
          hintText: label,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: kPink.withOpacity(0.6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: kPink, width: 2),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildImagePicker(String label, File? image, String type) {
    final kPink = const Color(0xFFFF8FB1);
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.gallery, type),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: kPink.withOpacity(0.6)),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.image_outlined, color: kPink),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                image == null
                    ? 'แตะเพื่อเลือกรูป $label'
                    : 'เลือกรูปแล้ว: $label',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            if (image != null)
              const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }
}
