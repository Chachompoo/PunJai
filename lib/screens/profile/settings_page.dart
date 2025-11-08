import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:punjai_app/screens/auth/update_password_screen.dart';
import 'package:punjai_app/screens/profile/history_page.dart';
import 'package:punjai_app/screens/auth/login_screen.dart';
import 'package:punjai_app/screens/profile/edit_profile_screen.dart';

class SettingsPage extends StatelessWidget {
  static const routeName = '/settings';
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    // กลับไปหน้า Login
    Navigator.pushNamedAndRemoveUntil(
        context, LoginScreen.routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Settings and Activity ',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 10),
          // =======================
          // 👤 บัญชีของฉัน
          // =======================
          const Text(
            "Your Account",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),

          _buildSettingItem(
            context,
            icon: Icons.person_outline,
            title: "Edit Profile",
            subtitle: "Update your profile information",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
          ),

          _buildSettingItem(
            context,
            icon: Icons.lock_outline,
            title: "Change Password",
            subtitle: "Update your account password",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UpdatePasswordScreen(),
                ),
              );
            },
          ),

          _buildSettingItem(
            context,
            icon: Icons.history_edu_outlined,
            title: "My History",
            subtitle: "View all your donation & swap history",
            onTap: () {
              Navigator.pushNamed(context, HistoryPage.routeName);
            },
          ),

          const Divider(height: 32),

          // =======================
          // 🚪 ออกจากระบบ
          // =======================
          const Text(
            "Account Actions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),

          _buildSettingItem(
            context,
            icon: Icons.logout,
            title: "Log Out",
            subtitle: "Sign out from your current session",
            iconColor: Colors.redAccent,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: iconColor ?? Colors.pinkAccent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13, height: 1.3)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(26),
              margin: const EdgeInsets.symmetric(horizontal: 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 💗 ไอคอนมน ๆ
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE6EF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: const Icon(Icons.logout_rounded,
                        size: 44, color: Color(0xFFFF8FBF)),
                  ),
                  const SizedBox(height: 18),

                  // 🌸 หัวข้อ
                  const Text(
                    'Log Out?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF43593E),
                      decoration: TextDecoration.none, // ❌ ไม่มีขีด
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 🌿 คำอธิบาย
                  const Text(
                    'คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                      height: 1.4,
                      decoration: TextDecoration.none, // ❌ ไม่มีขีด
                    ),
                  ),
                  const SizedBox(height: 26),

                  // 🔘 ปุ่ม
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            // ✨ ใส่หัวใจลอยก่อนออก
                            _showFloatingHeart(context);

                            // ปิด popup หลังดีเลย์นิดหน่อย
                            await Future.delayed(
                                const Duration(milliseconds: 300));
                            Navigator.pop(context);

                            // รอหัวใจจบ animation แล้วค่อย logout
                            await Future.delayed(
                                const Duration(milliseconds: 700));

                            await FirebaseAuth.instance.signOut();

                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                LoginScreen.routeName,
                                (route) => false,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: const Color(0xFFFF8FBF),
                            shadowColor: Colors.pinkAccent.withOpacity(0.2),
                            elevation: 3,
                          ),
                          child: const Text(
                            'Log Out',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// 💗 หัวใจลอยขึ้นตอน logout
void _showFloatingHeart(BuildContext context) {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).size.height * 0.5,
      left: MediaQuery.of(context).size.width * 0.45,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: -100),
        duration: const Duration(milliseconds: 800),
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
  Future.delayed(const Duration(milliseconds: 850), overlayEntry.remove);
}
}

