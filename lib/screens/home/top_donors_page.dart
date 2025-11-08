import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:punjai_app/screens/profile/profile_screen.dart'; // ✅ เพิ่ม import หน้าดูโปรไฟล์

class TopDonorsPage extends StatelessWidget {
  const TopDonorsPage({super.key});
  static const routeName = '/topDonors';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        title: const Text(
          '🏆 ผู้ใจดีแห่ง PunJai',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.8,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('points', isGreaterThanOrEqualTo: 0)
            .orderBy('points', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีข้อมูลผู้บริจาคค่ะ 💛',
                style: TextStyle(color: Colors.brown, fontSize: 16),
              ),
            );
          }

          final users = snapshot.data!.docs;
          final top3 = users.take(3).toList();
          final others = users.skip(3).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // 🌸 Banner
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 25, horizontal: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFCFEA), Color(0xFFFFF8E7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.volunteer_activism,
                          size: 42, color: Color(0xFFFF8FB1)),
                      SizedBox(height: 8),
                      Text(
                        "ขอบคุณผู้ใจดีทุกคน 💗",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF393E46)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "3 อันดับผู้บริจาคสูงสุดประจำเดือน 🌟",
                        style:
                            TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 🏅 Top 3 Podium
                if (top3.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (top3.length > 2)
                        _buildPodium(context,
                            rank: 3,
                            data: top3[2],
                            height: 110,
                            color: const Color(0xFFFFD6A5),
                            crownColor: const Color(0xFFFFA726)),
                      const SizedBox(width: 12),
                      if (top3.isNotEmpty)
                        _buildPodium(context,
                            rank: 1,
                            data: top3[0],
                            height: 150,
                            color: const Color(0xFFFFF3C2),
                            crownColor: const Color(0xFFFFC107)),
                      const SizedBox(width: 12),
                      if (top3.length > 1)
                        _buildPodium(context,
                            rank: 2,
                            data: top3[1],
                            height: 120,
                            color: const Color(0xFFE0E0E0),
                            crownColor: const Color(0xFFBDBDBD)),
                    ],
                  ),

                const SizedBox(height: 35),

                // รายชื่ออันดับ 4–20
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: others.length,
                  itemBuilder: (context, index) {
                    final data = others[index].data() as Map<String, dynamic>;
                    final name = data['firstname'] != null
                        ? '${data['firstname']} ${data['lastname'] ?? ''}'
                        : (data['name'] ?? 'ไม่ระบุชื่อ');
                    final points = (data['points'] ?? 0).toInt();
                    final imageUrl = data['profileImage'] ??
                        'https://cdn-icons-png.flaticon.com/512/847/847969.png';
                    final uid = data['uid'] ?? '';

                    return InkWell(
                      onTap: () {
                        if (uid.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(uid: uid),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12.withOpacity(0.06),
                              blurRadius: 6,
                              offset: const Offset(2, 3),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(imageUrl),
                            radius: 24,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                          ),
                          subtitle: Text(
                            'แต้มสะสมทั้งหมด: $points',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          trailing: Text(
                            '#${index + 4}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8C8C8C),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🎖️ Podium พร้อมกดเข้าโปรไฟล์ได้
  Widget _buildPodium(
    BuildContext context, {
    required int rank,
    required QueryDocumentSnapshot data,
    required double height,
    required Color color,
    required Color crownColor,
  }) {
    final user = data.data() as Map<String, dynamic>;
    final name = user['firstname'] != null
        ? '${user['firstname']} ${user['lastname'] ?? ''}'
        : (user['name'] ?? 'ไม่ระบุชื่อ');
    final points = (user['points'] ?? 0).toInt();
    final imageUrl = user['profileImage'] ??
        'https://cdn-icons-png.flaticon.com/512/847/847969.png';
    final uid = user['uid'] ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              height: height,
              width: 90,
              margin: const EdgeInsets.only(top: 25),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.9), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: crownColor.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (uid.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(uid: uid),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(imageUrl),
                      radius: rank == 1 ? 34 : 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF393E46),
                      ),
                    ),
                  ),
                  Text(
                    '$points pts',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: Icon(
                Icons.emoji_events_rounded,
                size: rank == 1 ? 36 : 30,
                color: crownColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '#$rank',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: rank == 1 ? 18 : 16,
            color: crownColor,
          ),
        ),
      ],
    );
  }
}
