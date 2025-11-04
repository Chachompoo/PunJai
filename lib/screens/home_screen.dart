import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:punjai_app/screens/login_screen.dart';
import 'package:punjai_app/screens/profile_screen.dart';

/// ------------------------------------------------------------
/// 🏠 HomeScreen (PunJai)
/// - หน้าหลักหลัง Login สำเร็จ
/// - เพิ่มระบบ "จัดอันดับผู้บริจาคสูงสุด" (Top Donors)
/// - ปุ่ม Navigation ด้านล่าง: Feed / ค้นหา / เพิ่มโพสต์ / Top Donors / โปรไฟล์
/// ------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;

  int _selectedIndex = 0; // สำหรับ BottomNavigationBar

  // ฟังก์ชันออกจากระบบ
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  /// ---------------------------------------------
  /// 🔸 หน้ารายชื่อผู้บริจาคสูงสุด (Top Donors)
  /// ---------------------------------------------
  Widget _buildTopDonors() {
    return Container(
      color: const Color(0xFFFFF7E5), // 💛 โทนเหลืองอ่อน (Donation)
      child: StreamBuilder<QuerySnapshot>(
        // ดึงข้อมูลจาก Firestore collection 'users' แล้ว sort ตาม donationPoints
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('donationPoints', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีข้อมูลผู้บริจาคค่ะ 💛',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final data = users[index].data() as Map<String, dynamic>;

              // อ่านฟิลด์ข้อมูลจาก Firestore
              final name = data['name'] ?? 'ไม่ระบุชื่อ';
              final username = data['username'] ?? '';
              final profileImage = data['profileImage'] ??
                  'https://cdn-icons-png.flaticon.com/512/149/149071.png';
              final points = data['donationPoints'] ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(profileImage),
                    radius: 26,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  subtitle: Text('@$username',
                      style: const TextStyle(color: Colors.black54)),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD479),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$points pts',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF624D00),
                      ),
                    ),
                  ),
                  onTap: () {
                    // กดดูโปรไฟล์ของ user นั้น
                    Navigator.pushNamed(
                      context,
                      ProfileScreen.routeName,
                      arguments: data['uid'],
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

  /// ---------------------------------------------
  /// 🔸 สลับหน้าจอจาก BottomNavigationBar
  /// ---------------------------------------------
  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return const Center(child: Text('📜 หน้าฟีด (Feed ยังไม่สร้าง)'));
      case 1:
        return const Center(child: Text('🔍 หน้าค้นหา (ยังไม่สร้าง)'));
      case 2:
        return const Center(child: Text('➕ เพิ่มโพสต์ (ยังไม่สร้าง)'));
      case 3:
        return _buildTopDonors(); // ✅ หน้าจัดอันดับผู้บริจาคสูงสุด
      case 4:
        final user = _auth.currentUser;
        if (user == null) {
          return const Center(child: Text('ไม่พบข้อมูลผู้ใช้'));
        }
        // ✅ หน้าโปรไฟล์ของตัวเอง
        return ProfileScreen(uid: user.uid);
      default:
        return const Center(child: Text('ไม่พบหน้า'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildCurrentPage(),

      /// ---------------------------------------------
      /// 🔹 Bottom Navigation Bar (สไตล์ IG)
      /// ---------------------------------------------
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF43593E),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_box_outlined), label: 'Add'),
          BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              label: 'Top Donors'), // 🏆 แทน Chat เดิม
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
