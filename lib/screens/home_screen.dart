import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:punjai_app/screens/login_screen.dart';
import 'package:punjai_app/screens/profile_screen.dart';
import 'package:punjai_app/screens/create_post_page.dart';
import 'package:punjai_app/screens/feed_page.dart';
import 'package:punjai_app/screens/notifications_page.dart';
import 'package:punjai_app/screens/search_page.dart';
import 'package:punjai_app/screens/ChatsListPage.dart';
import 'package:punjai_app/widgets/punjai_appbar.dart';
import 'package:punjai_app/screens/top_donors_page.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (_auth.currentUser == null) {
      Future.microtask(() {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
    }
  }

  Widget _buildCurrentPage() {
  switch (_selectedIndex) {
    case 0:
      return const FeedPage();
    case 1:
      return const SearchPage();
    case 2:
      return _buildPostTypeSelector(context);
    case 3:
      return const TopDonorsPage();
    case 4:
      // ✅ ปุ่มโปรไฟล์อยู่ตรงนี้
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;
          if (user == null) {
            Future.microtask(() {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            });
            return const Center(child: Text('กำลังออกจากระบบ... 💗'));
          }
          return ProfileScreen(uid: user.uid);
        },
      );
    default:
      return const Center(child: Text('หน้าที่ไม่พบค่ะ 🚫'));
  }
}


  Widget _buildTopDonors() {
    return Container(
      color: const Color(0xFFFFF7E5),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('points', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('ยังไม่มีข้อมูลผู้บริจาคค่ะ 💛'),
            );
          }

          final users = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final data = users[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'ไม่ระบุชื่อ';
              final username = data['username'] ?? '';
              final profileImage = data['profileImage'] ??
                  'https://cdn-icons-png.flaticon.com/512/149/149071.png';
              final points = data['points'] ?? 0;


              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(profileImage),
                    radius: 26,
                  ),
                  title: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black87)),
                  subtitle: Text('@$username',
                      style: const TextStyle(color: Colors.grey)),
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPostTypeSelector(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('เลือกประเภทโพสต์ 💗',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          _buildTypeButton(context,
              title: 'บริจาคสิ่งของ',
              color: const Color(0xFFFFF7CC),
              accent: const Color(0xFFFFD84D),
              icon: Icons.volunteer_activism,
              type: 'donate'),
          const SizedBox(height: 20),
          _buildTypeButton(context,
              title: 'ขอรับบริจาค',
              color: const Color(0xFFFFD6E8),
              accent: const Color(0xFFFF8FBF),
              icon: Icons.card_giftcard,
              type: 'request'),
          const SizedBox(height: 20),
          _buildTypeButton(context,
              title: 'แลกเปลี่ยนสิ่งของ',
              color: const Color(0xFFD6F0FF),
              accent: const Color(0xFF7EC8E3),
              icon: Icons.swap_horiz,
              type: 'swap'),
        ],
      ),
    );
  }

  Widget _buildTypeButton(
    BuildContext context, {
    required String title,
    required Color color,
    required Color accent,
    required IconData icon,
    required String type,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CreatePostPage(type: type)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: const Offset(2, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _selectedIndex == 0 ? const PunjaiAppBar() : null,
      body: _buildCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF43593E),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Add'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), label: 'Top Donors'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
