import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/home_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../admin/admin_verification_page.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  
  get role => null;

  Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final input = _emailController.text.trim();
    final password = _passwordController.text.trim();

    String email = input;

    // 🔍 ถ้าไม่มี @ แสดงว่าเป็น username → ไปค้นใน Firestore
    if (!input.contains('@')) {
      print('🔎 ตรวจสอบ username: $input');
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: input)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _errorMessage = 'ไม่พบบัญชีผู้ใช้นี้');
        setState(() => _isLoading = false);
        return;
      }

      email = query.docs.first['email'];
      print('✅ พบ email จาก username: $email');
    }

    // 🔐 เข้าสู่ระบบด้วย email ที่ได้
    UserCredential userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);


    final user = userCredential.user;
    if (user == null) {
      setState(() => _errorMessage = 'ไม่สามารถเข้าสู่ระบบได้ กรุณาลองใหม่อีกครั้ง');
      return;
    }

    // ✅ ดึงข้อมูลจาก Firestore
    final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get(const GetOptions(source: Source.server));


    print('🔥 UID: ${user.uid}');
    print('📬 Email: ${user.email}');
    print('🗂 Document ID: ${userDoc.id}');
    print('📄 Data: ${userDoc.data()}');

    if (!userDoc.exists || userDoc.data() == null) {
      setState(() => _errorMessage = 'ไม่พบบัญชีผู้ใช้ในระบบ');
      await FirebaseAuth.instance.signOut();
      return;
    }

    // ✅ อ่านข้อมูลให้แน่ใจว่ามี field role
    final userData = userDoc.data()!;
    final role = userData.containsKey('role') ? userData['role'] : 'user';
    final status = userData.containsKey('status')
        ? userData['status']
        : 'pending_verification';
    final rejectReason = userData['rejectReason'] ?? '';

    print('🎭 ROLE: $role | STATUS: $status');

    // 🔥 ถ้าเป็นแอดมิน
    if (role.toString().trim().toLowerCase() == 'admin') {
      print('🧑‍💼 เข้าระบบแอดมินสำเร็จ!');
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminVerificationPage()),
        );
      }
      return;
    }

    // 🔹 ตรวจสถานะผู้ใช้ทั่วไป
    if (status == 'pending_verification') {
      await FirebaseAuth.instance.signOut();
      _showStatusDialog(
        title: '⏳ อยู่ระหว่างตรวจสอบ 💌',
        message:
            'บัญชีของคุณยังอยู่ระหว่างตรวจสอบจากผู้ดูแลระบบ\nโปรดรอการอนุมัติทางอีเมลก่อนเข้าสู่ระบบค่ะ 💗',
        icon: Icons.hourglass_bottom,
        color: Colors.amber,
      );
      return;
    }

    if (status == 'rejected') {
      await FirebaseAuth.instance.signOut();
      _showStatusDialog(
        title: 'ไม่ผ่านการตรวจสอบ 😢',
        message:
            'บัญชีของคุณไม่ผ่านการตรวจสอบ\nสาเหตุ: ${rejectReason.isNotEmpty ? rejectReason : "ไม่ระบุ"}',
        icon: Icons.cancel,
        color: Colors.redAccent,
      );
      return;
    }

    // 🏠 ถ้าอนุมัติแล้ว → เข้า Home
    if (status == 'approved') {
      print('🏠 เข้าระบบผู้ใช้ปกติ');
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') {
      setState(() => _errorMessage = 'ไม่พบบัญชีผู้ใช้หรืออีเมลนี้');
    } else if (e.code == 'wrong-password') {
      setState(() => _errorMessage = 'รหัสผ่านไม่ถูกต้อง');
    } else {
      setState(() => _errorMessage = 'เกิดข้อผิดพลาด: ${e.message}');
    }
  } catch (e) {
    setState(() => _errorMessage = 'เกิดข้อผิดพลาด: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}





  void _showStatusDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  void _navigateToForgotPassword(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
    );
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
              child: Form(
                key: _formKey,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: kPink.withOpacity(0.3),
                        child: const Icon(Icons.favorite,
                            color: Colors.pinkAccent, size: 42),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: kText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'เข้าสู่ระบบเพื่อแบ่งปันและรับสิ่งดีๆ 💖',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 28),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email_outlined),
                          hintText: 'อีเมลหรือชื่อผู้ใช้',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: kPink.withOpacity(0.6)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: kPink, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'กรุณากรอกอีเมล';
                          // สามารถกรอกได้ทั้ง username หรือ email
                          if (!value.contains('@') && value.length < 3)
                            return 'กรุณากรอกอีเมลหรือชื่อผู้ใช้ให้ถูกต้อง';

                        },
                      ),
                      const SizedBox(height: 18),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline),
                          hintText: 'รหัสผ่าน',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: kBlue.withOpacity(0.6)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: kBlue, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'กรุณากรอกรหัสผ่าน';
                          if (value.length < 6)
                            return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                          return null;
                        },
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _navigateToForgotPassword(context),
                          child: Text(
                            'ลืมรหัสผ่าน?',
                            style: TextStyle(
                              color: kPink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'เข้าสู่ระบบ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('ยังไม่มีบัญชีใช่ไหม?'),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const SignupScreen()),
                              );
                            },
                            child: Text(
                              'สมัครสมาชิก',
                              style: TextStyle(
                                color: kText,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      )
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
}
