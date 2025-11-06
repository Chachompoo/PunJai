import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:punjai_app/screens/post_detail_page.dart';
import 'package:punjai_app/screens/profile_screen.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  static const routeName = '/search';

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String selectedType = 'all'; // all / donate / request / swap

  // 🔍 สร้าง Stream ดึงโพสต์ตามคำค้น
  Stream<QuerySnapshot> _postStream() {
    Query query = FirebaseFirestore.instance.collection('posts');

    final keyword = _searchCtrl.text.trim();
    if (keyword.isNotEmpty) {
      // ใช้การค้นหาด้วย title โดยตรง
      query = query
          .where('title', isGreaterThanOrEqualTo: keyword)
          .where('title', isLessThanOrEqualTo: '$keyword\uf8ff');
    }

    if (selectedType != 'all') {
      query = query.where('type', isEqualTo: selectedType);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  // 🔍 Stream ผู้ใช้ (ค้นหาชื่อ)
  Stream<QuerySnapshot> _userStream() {
    final queryText = _searchCtrl.text.trim().toLowerCase();

    if (queryText.isEmpty) {
      return FirebaseFirestore.instance
          .collection('users')
          .orderBy('username')
          .limit(20)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('users')
          .where('keywords', arrayContains: queryText)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFDFBFB),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 0.8,
          title: _buildSearchBar(),
          bottom: const TabBar(
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFFF8FB1),
            tabs: [
              Tab(text: 'โพสต์ทั้งหมด 🛍️'),
              Tab(text: 'ผู้ใช้ 👥'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPostTab(),
            _buildUserTab(),
          ],
        ),
      ),
    );
  }

  // ===============================
  // 🩷 TAB โพสต์ทั้งหมด
  // ===============================
  Widget _buildPostTab() {
    return Column(
      children: [
        // 🔹 ปุ่มกรองประเภทโพสต์
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              _buildTypeChip('all', 'ทั้งหมด', Colors.grey[300]!),
              _buildTypeChip('donate', 'บริจาค', const Color(0xFFFFF7CC)),
              _buildTypeChip('request', 'ขอรับ', const Color(0xFFFFD6E8)),
              _buildTypeChip('swap', 'แลกเปลี่ยน', const Color(0xFFD6F0FF)),
            ],
          ),
        ),

        // 🔸 แสดงโพสต์
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _postStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'ยังไม่มีโพสต์ที่ตรงกับคำค้นหา 🕊️',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                );
              }

              final posts = snapshot.data!.docs;

              return GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final data = posts[index].data() as Map<String, dynamic>;
                  final imageUrl = (data['images'] != null &&
                          (data['images'] as List).isNotEmpty &&
                          (data['images'][0] as String).startsWith('http'))
                      ? data['images'][0]
                      : 'https://cdn-icons-png.flaticon.com/512/1160/1160358.png';

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(postData: data),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ===============================
  // 👥 TAB ผู้ใช้
  // ===============================
  Widget _buildUserTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _userStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'ไม่พบผู้ใช้ที่ตรงกับคำค้นหา 💬',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>;
            final profileImage = data['profileImage'] ??
                'https://cdn-icons-png.flaticon.com/512/149/149071.png';
            final name =
                '${data['firstname'] ?? ''} ${data['lastname'] ?? ''}'.trim();
            final username = data['username'] ?? 'ไม่ระบุ';

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(profileImage),
                radius: 26,
              ),
              title: Text(
                name.isEmpty ? 'ผู้ใช้ไม่ระบุชื่อ' : name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('@$username',
                  style: const TextStyle(color: Colors.black54)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(uid: data['uid']),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ===============================
  // 🔎 ช่องค้นหา
  // ===============================
  Widget _buildSearchBar() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: const InputDecoration(
          hintText: 'ค้นหาสิ่งของหรือผู้ใช้...',
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
        ),
        onChanged: (val) => setState(() {}),
      ),
    );
  }

  // ===============================
  // 🏷️ ปุ่มกรองประเภทโพสต์
  // ===============================
  Widget _buildTypeChip(String value, String label, Color color) {
    final bool isSelected = selectedType == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.black87 : Colors.black54,
          fontWeight: FontWeight.bold,
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => selectedType = value);
        },
        backgroundColor: color.withOpacity(0.4),
        selectedColor: color,
      ),
    );
  }
}
