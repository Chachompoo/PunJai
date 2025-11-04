import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import '../widgets/fade_slide_route.dart';
import 'password_reset_success_screen.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String email;
  const VerifyCodeScreen({super.key, required this.email});

  static const routeName = '/verify-code';

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final List<TextEditingController> _controllers =
      List.generate(5, (_) => TextEditingController());
  final AudioPlayer _player = AudioPlayer();
  bool _isVerifying = false;
  String? _errorMessage;

  Future<void> _verifyCode() async {
    final enteredCode = _controllers.map((c) => c.text).join();
    if (enteredCode.length != 5) {
      setState(() => _errorMessage = 'กรุณากรอกโค้ดให้ครบ 5 หลัก');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('password_resets')
          .doc(widget.email)
          .get();

      if (!doc.exists) {
        setState(() => _errorMessage = '⛔ ไม่พบโค้ดในระบบ หรือหมดอายุแล้ว');
        return;
      }

      final data = doc.data()!;
      final savedCode = data['code'];
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiresAt)) {
        setState(() => _errorMessage = '⏰ โค้ดนี้หมดอายุแล้ว');
        await FirebaseFirestore.instance
            .collection('password_resets')
            .doc(widget.email)
            .delete();
        return;
      }

      if (enteredCode != savedCode) {
        setState(() => _errorMessage = '❌ โค้ดไม่ถูกต้อง');
        return;
      }

      // 🔊 เล่นเสียงติ๊งเมื่อ verify สำเร็จ
      await _player.play(AssetSource('sounds/success.mp3'));

      // ✅ ลบโค้ดออกหลัง verify สำเร็จ
      await FirebaseFirestore.instance
          .collection('password_resets')
          .doc(widget.email)
          .delete();

      // ✅ เปลี่ยนหน้าไป success screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          FadeSlidePageRoute(
            page: PasswordResetSuccessScreen(email: widget.email),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() => _isVerifying = false);
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
            const Text("Check your email",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              "We sent a reset code to ${widget.email}\nPlease enter the 5-digit code below.",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 28),

            // 🔢 ช่องกรอก PIN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                return SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _controllers[index],
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (val) {
                      if (val.isNotEmpty && index < 4) {
                        FocusScope.of(context).nextFocus();
                      }
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
              ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6FA5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isVerifying
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Verify Code",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            Center(
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("ยังไม่เปิดให้ส่งอีเมลซ้ำในเวอร์ชันนี้ค่ะ 💌"),
                  ));
                },
                child: const Text(
                  "Didn’t get the email? Resend",
                  style: TextStyle(color: Color(0xFFFF6FA5)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
