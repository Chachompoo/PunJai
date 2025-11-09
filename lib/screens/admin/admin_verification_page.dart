import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_user_detail_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:punjai_app/screens/auth/login_screen.dart';

class AdminVerificationPage extends StatelessWidget {
  const AdminVerificationPage({super.key});

  static const kPrimary = Color(0xFFFF8FB1);
  static const kBg = Color(0xFFFFF7FB);
  static const kText = Color(0xFF393E46);

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kPrimary,
        title: const Text(
          'ตรวจสอบสมาชิกใหม่',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('ออกจากระบบ'),
                  content: const Text('คุณต้องการออกจากระบบหรือไม่?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('ยกเลิก'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'ออกจากระบบ',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await FirebaseAuth.instance.signOut();

                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),

      // 🌷 ส่วนแสดงรายการผู้สมัครที่รอตรวจสอบ
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('users')
            .where('status', isEqualTo: 'pending_verification')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimary),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีผู้สมัครที่รอตรวจสอบ 💗',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user =
                  users[index].data() as Map<String, dynamic>? ?? {};

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(
                      user['profileImage'] ??
                          'https://cdn-icons-png.flaticon.com/512/847/847969.png',
                    ),
                  ),
                  title: Text(
                    '${user['firstname'] ?? ''} ${user['lastname'] ?? ''}'.trim().isEmpty
                        ? 'ไม่ระบุชื่อ'
                        : '${user['firstname']} ${user['lastname']}',
                  ),
                  subtitle: Text(user['email'] ?? '-'),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: kPrimary, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminUserDetailPage(
                          userId: users[index].id,
                          userData: user,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
