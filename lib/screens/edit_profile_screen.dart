import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  static const routeName = '/edit_profile';

  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // สีธีม PunJai พาสเทล
  static const Color kBg = Color(0xFFFDECF2);
  static const Color kPrimary = Color(0xFFFF6FA5);
  static const Color kText = Color(0xFF39424E);

  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _loading = false;
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

  /// 📷 เลือกรูปจากเครื่อง
  Future<void> _pickImage() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  /// ☁️ อัปโหลดรูปขึ้น Firebase Storage แล้วคืน URL
  Future<String> _uploadImage(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not found');
    final ref = FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  /// 💾 อัปเดตข้อมูลใน Firestore
  Future<void> _saveProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loading = true);

    try {
      // ถ้ามีเลือกรูปใหม่ → อัปโหลดก่อน
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ บันทึกข้อมูลสำเร็จ')),
      );
      Navigator.pop(context); // กลับไปหน้าโปรไฟล์
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kText,
        title: const Text('Edit Profile'),
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
                            color: kPrimary,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildTextField('ชื่อจริง', _firstNameCtrl),
                  _buildTextField('นามสกุล', _lastNameCtrl),
                  _buildTextField('ชื่อผู้ใช้', _usernameCtrl),
                  _buildTextField('เบอร์โทรศัพท์', _phoneCtrl, keyboardType: TextInputType.phone),
                  _buildTextField('คำแนะนำสั้น ๆ (Bio)', _bioCtrl, maxLines: 3),

                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'บันทึกการเปลี่ยนแปลง',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: kText),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
