import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:punjai_app/screens/posts/post_detail_page.dart';
import 'package:punjai_app/screens/profile/profile_screen.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  static const routeName = '/search';

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String selectedType = 'all';

  // 🔍 Stream โพสต์ทั้งหมด
  Stream<QuerySnapshot> _postStream() {
    Query query = FirebaseFirestore.instance.collection('posts');
    final keyword = _searchCtrl.text.trim();

    if (keyword.isNotEmpty) {
      query = query
          .where('title', isGreaterThanOrEqualTo: keyword)
          .where('title', isLessThanOrEqualTo: '$keyword\uf8ff');
    }

    if (selectedType != 'all') {
      query = query.where('type', isEqualTo: selectedType);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  // 🔍 Stream ผู้ใช้ (ค้นได้ทั้ง firstname, lastname, username)
Stream<List<QueryDocumentSnapshot>> _userStream() async* {
  final queryText = _searchCtrl.text.trim().toLowerCase();

  // ดึงผู้ใช้ทั้งหมด (จำกัด 100 คนแรกพอ)
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .orderBy('username')
      .limit(100)
      .get();

  if (queryText.isEmpty) {
    yield snapshot.docs;
  } else {
    final filtered = snapshot.docs.where((doc) {
      final data = doc.data();
      final first = (data['firstname'] ?? '').toString().toLowerCase();
      final last = (data['lastname'] ?? '').toString().toLowerCase();
      final username = (data['username'] ?? '').toString().toLowerCase();

      // ✅ ตรวจว่ามีอักษรที่พิมพ์ค้นอยู่ในชื่อจริง/นามสกุล/ชื่อผู้ใช้
      return first.contains(queryText) ||
          last.contains(queryText) ||
          username.contains(queryText);
    }).toList();

    yield filtered;
  }
}


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF7FB),
        appBar: PreferredSize(
  preferredSize: const Size.fromHeight(120),
  child: Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(22),
        bottomRight: Radius.circular(22),
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x1A000000), // เงาอ่อนมาก
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: SafeArea(
      child: Column(
        children: [
          // 🔍 แถบค้นหาด้านบน
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7FB),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'ค้นหาสิ่งของหรือผู้ใช้...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFFF8FBF)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() {}),
              ),
            ),
          ),

          // 🌈 แถบ TabBar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7FB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const TabBar(
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(width: 3, color: Color(0xFFFF8FBF)),
                insets: EdgeInsets.symmetric(horizontal: 40),
              ),
              labelColor: Color(0xFF222222),
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
              tabs: [
                Tab(text: 'โพสต์ทั้งหมด 🛍️'),
                Tab(text: 'ผู้ใช้ 👥'),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
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

  // ======================================================
  // 🌈 หน้าโพสต์ทั้งหมด (แบบ Modern Radiant)
  // ======================================================
  Widget _buildPostTab() {
    return Column(
      children: [
        _buildFilterRow(),
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
                    'ยังไม่มีโพสต์ในตอนนี้ 🕊️',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                );
              }

              final posts = snapshot.data!.docs;

              return GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.85,
                ),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final data = posts[index].data() as Map<String, dynamic>;
                  final images = (data['images'] ?? []) as List;
                  final type = data['type'] ?? 'donate';

                  final hasImage = images.isNotEmpty &&
                      (images.first as String).startsWith('http');

                  // 🌸 สีพื้นหลังตามประเภทโพสต์
                  final gradient = _getTypeGradient(type);
                  final label = _getTypeLabel(type);
                  final icon = _getTypeIcon(type);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(postData: data),
                        ),
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(2, 4),
                          ),
                        ],
                        gradient: hasImage ? null : gradient,
                        color: hasImage ? Colors.transparent : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          children: [
                            // ถ้ามีรูป
                            if (hasImage)
                              Image.network(
                                images.first,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: gradient,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            // ถ้าไม่มีรูป
                            if (!hasImage)
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(icon,
                                        size: 50,
                                        color: Colors.white.withOpacity(0.95)),
                                    const SizedBox(height: 10),
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // แถบล่างชื่อโพสต์
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withOpacity(0.5),
                                      Colors.transparent
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                                child: Text(
                                  data['title'] ?? 'ไม่มีชื่อโพสต์',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    shadows: [
                                      Shadow(
                                          color: Colors.black54, blurRadius: 4)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  // ======================================================
  // 👥 แท็บผู้ใช้
  // ======================================================
Widget _buildUserTab() {
  return StreamBuilder<List<QueryDocumentSnapshot>>(
    stream: _userStream(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return const Center(
          child: Text(
            'ไม่พบผู้ใช้ที่ตรงกับคำค้นหา 💬',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        );
      }

      final users = snapshot.data!;

      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final data = users[index].data() as Map<String, dynamic>;
          final profileImage = data['profileImage'] ??
              'https://cdn-icons-png.flaticon.com/512/149/149071.png';
          final name =
              '${data['firstname'] ?? ''} ${data['lastname'] ?? ''}'.trim();
          final username = data['username'] ?? 'ไม่ระบุ';

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7FB), Color(0xFFEAF7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(profileImage),
                radius: 26,
              ),
              title: Text(
                name.isEmpty ? 'ผู้ใช้ไม่ระบุชื่อ' : name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                '@$username',
                style: const TextStyle(color: Colors.black54),
              ),
              trailing:
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(uid: data['uid']),
                  ),
                );
              },
            ),
          );
        },
      );
    },
  );
}

  // ======================================================
  // 🧁 ส่วนประกอบย่อย
  // ======================================================

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          _buildTypeChip('all', 'ทั้งหมด', Colors.grey.shade300),
          _buildTypeChip('donate', 'บริจาค ', const Color(0xFFFFF7CC)),
          _buildTypeChip('request', 'ขอรับ ', const Color(0xFFFFD6E8)),
          _buildTypeChip('swap', 'แลกเปลี่ยน ', const Color(0xFFD6F0FF)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7FB),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'ค้นหาสิ่งของหรือผู้ใช้...',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFFF8FBF)),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
        ),
        onChanged: (val) => setState(() {}),
      ),
    );
  }

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
        onSelected: (selected) => setState(() => selectedType = value),
        backgroundColor: color.withOpacity(0.3),
        selectedColor: color,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ======================================================
  // 🎨 Helper สำหรับสีและไอคอนแต่ละประเภท
  // ======================================================

  LinearGradient _getTypeGradient(String type) {
    switch (type) {
      case 'donate':
        return const LinearGradient(
          colors: [Color(0xFFFFEFA9), Color(0xFFFFD84D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'request':
        return const LinearGradient(
          colors: [Color(0xFFFFC1D8), Color(0xFFFF8FBF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'swap':
        return const LinearGradient(
          colors: [Color(0xFFB5E2FF), Color(0xFF7EC8E3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Colors.grey, Colors.white70],
        );
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'donate':
        return 'บริจาค';
      case 'request':
        return 'ขอรับ';
      case 'swap':
        return 'แลกเปลี่ยน';
      default:
        return 'โพสต์';
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'donate':
        return Icons.volunteer_activism;
      case 'request':
        return Icons.card_giftcard;
      case 'swap':
        return Icons.autorenew;
      default:
        return Icons.image_not_supported;
    }
  }
}
