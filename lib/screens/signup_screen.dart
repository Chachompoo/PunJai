import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupScreen extends StatefulWidget {
  static const routeName = '/signup';
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController idCardController = TextEditingController();

  bool isLoading = false;

  // ✅ ตรวจสอบเลขบัตรประชาชน 13 หลัก (Thai ID)
  bool isValidThaiID(String id) {
    if (id.length != 13) return false;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += int.parse(id[i]) * (13 - i);
    }
    return (11 - (sum % 11)) % 10 == int.parse(id[12]);
  }

  // ✅ ฟังก์ชันสมัครสมาชิก
  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // สร้าง user ใน Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user != null) {
        // บันทึกข้อมูลใน Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': emailController.text.trim(),
          'username': usernameController.text.trim(),
          'firstname': firstnameController.text.trim(),
          'lastname': lastnameController.text.trim(),
          'phone': phoneController.text.trim(),
          'idCard': idCardController.text.trim(),
          'profileImage': 'https://cdn-icons-png.flaticon.com/512/149/149071.png',
          'createdAt': Timestamp.now(),
          'points': 0.0,
          'role': 'user',
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สมัครสมาชิกสำเร็จ! 🎉')),
      );
      Navigator.pop(context); // กลับไปหน้า Login

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.message}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("สมัครสมาชิก PunJai"),
        backgroundColor: Colors.green.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'อีเมล'),
                validator: (v) =>
                    v!.isEmpty ? 'กรุณากรอกอีเมล' : null,
              ),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
                obscureText: true,
                validator: (v) =>
                    v!.length < 6 ? 'รหัสผ่านต้องอย่างน้อย 6 ตัว' : null,
              ),
              TextFormField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้ (Username)'),
                validator: (v) =>
                    v!.isEmpty ? 'กรุณากรอกชื่อผู้ใช้' : null,
              ),
              TextFormField(
                controller: firstnameController,
                decoration: const InputDecoration(labelText: 'ชื่อจริง'),
                validator: (v) =>
                    v!.isEmpty ? 'กรุณากรอกชื่อจริง' : null,
              ),
              TextFormField(
                controller: lastnameController,
                decoration: const InputDecoration(labelText: 'นามสกุล'),
                validator: (v) =>
                    v!.isEmpty ? 'กรุณากรอกนามสกุล' : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v!.isEmpty ? 'กรุณากรอกเบอร์โทรศัพท์' : null,
              ),
              TextFormField(
                controller: idCardController,
                decoration: const InputDecoration(labelText: 'เลขบัตรประชาชน'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'กรุณากรอกเลขบัตรประชาชน';
                  if (!isValidThaiID(v)) return 'เลขบัตรประชาชนไม่ถูกต้อง';
                  return null;
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: isLoading ? null : registerUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('สมัครสมาชิก',
                        style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
