import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool isLoading = false;

  bool isValidThaiID(String id) {
    if (id.length != 13) return false;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += int.parse(id[i]) * (13 - i);
    }
    return (11 - (sum % 11)) % 10 == int.parse(id[12]);
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
  // 🔹 สมัครสมาชิกสำเร็จ
  final userCredential = await _auth.createUserWithEmailAndPassword(
    email: emailController.text.trim(),
    password: passwordController.text.trim(),
  );

  final user = userCredential.user;
  if (user != null) {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': emailController.text.trim(),
      'username': usernameController.text.trim(),
      'firstname': firstnameController.text.trim(),
      'lastname': lastnameController.text.trim(),
      'phone': phoneController.text.trim(),
      'profileImage': 'https://cdn-icons-png.flaticon.com/512/149/149071.png',
      'createdAt': Timestamp.now(),
      'points': 0.0,
      'role': 'user',
    });
  }

  // 💗 แจ้งเตือนเมื่อสมัครสำเร็จ
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  final snackBar = SnackBar(
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    content: AwesomeSnackbarContent(
      title: 'สำเร็จแล้ว 💖',
      message: 'ยินดีต้อนรับสู่ PunJai!\nเข้าสู่ระบบเพื่อเริ่มแบ่งปันสิ่งดี ๆ กันเลย 💫',
      contentType: ContentType.success,
    ),
  );
  ScaffoldMessenger.of(context).showSnackBar(snackBar);

  // ✅ รอ 2 วิ แล้วเด้งไปหน้า Login
  Future.delayed(const Duration(seconds: 2), () {
    Navigator.pushReplacementNamed(context, '/login');
  });

} on FirebaseAuthException catch (e) {
  // 🔹 แจ้งเตือนเมื่อเกิดข้อผิดพลาด
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
    final kYellow = const Color(0xFFFFF59D);
    final kBlue = const Color(0xFFB3E5FC);
    final kText = const Color(0xFF393E46);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kPink.withOpacity(0.2), kBlue.withOpacity(0.2), kYellow.withOpacity(0.2)],
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
                        child: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 42),
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
                          validator: (v) => v!.isEmpty ? 'กรุณากรอกอีเมล' : null),
                      _buildField('รหัสผ่าน', passwordController,
                          icon: Icons.lock_outline,
                          obscure: true,
                          validator: (v) =>
                              v!.length < 6 ? 'รหัสผ่านต้องอย่างน้อย 6 ตัว' : null),
                      _buildField('ชื่อผู้ใช้ (Username)', usernameController,
                          icon: Icons.person_outline,
                          validator: (v) => v!.isEmpty ? 'กรุณากรอกชื่อผู้ใช้' : null),
                      _buildField('ชื่อจริง', firstnameController,
                          icon: Icons.badge_outlined,
                          validator: (v) => v!.isEmpty ? 'กรุณากรอกชื่อจริง' : null),
                      _buildField('นามสกุล', lastnameController,
                          icon: Icons.badge_outlined,
                          validator: (v) => v!.isEmpty ? 'กรุณากรอกนามสกุล' : null),
                      _buildField('เบอร์โทรศัพท์', phoneController,
                          icon: Icons.phone_outlined,
                          type: TextInputType.phone,
                          validator: (v) => v!.isEmpty ? 'กรุณากรอกเบอร์โทรศัพท์' : null),

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
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'สมัครสมาชิก',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
}
