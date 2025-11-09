import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ArchivedPostsPage extends StatefulWidget {
  const ArchivedPostsPage({super.key});

  @override
  State<ArchivedPostsPage> createState() => _ArchivedPostsPageState();
}

class _ArchivedPostsPageState extends State<ArchivedPostsPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static const kBg = Color(0xFFFFF7FB);
  static const kPrimary = Color(0xFFFF8FB1);
  static const kText = Color(0xFF393E46);

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kPrimary,
        title: const Text(
          'เก็บโพสต์ของฉัน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 3,
      ),
      body: currentUser == null
          ? const Center(child: Text('กรุณาเข้าสู่ระบบก่อนดูโพสต์ที่หมดอายุ'))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('posts')
                  .where('ownerId', isEqualTo: currentUser.uid)
                  .where('status', isEqualTo: 'expired')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SizedBox.expand( // ✅ ทำให้เต็มจอ
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.inbox_outlined,
                          size: 100,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ยังไม่มีโพสต์ที่หมดอายุ ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }


                final posts = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index].data() as Map<String, dynamic>;
                    final title = post['title'] ?? 'ไม่ระบุชื่อโพสต์';
                    final createdAt =
                        (post['createdAt'] as Timestamp?)?.toDate();

                    return Card(
                      color: Colors.white,
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 📸 รูปไอคอนหรือภาพประกอบ
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: kPrimary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.archive_rounded,
                                size: 35,
                                color: kPrimary,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // 🔤 ข้อความ
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: kText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    createdAt != null
                                        ? 'หมดอายุเมื่อ ${createdAt.day}/${createdAt.month}/${createdAt.year}'
                                        : 'ไม่ทราบวันที่สร้าง',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ปุ่มลบ + คืนค่าโพสต์
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded,
                                      color: Colors.blueAccent),
                                  tooltip: 'คืนค่าโพสต์',
                                  onPressed: () async {
                                    await _firestore
                                        .collection('posts')
                                        .doc(posts[index].id)
                                        .update({'status': 'active'});
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent),
                                  tooltip: 'ลบโพสต์',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('ลบโพสต์นี้?'),
                                        content: const Text(
                                            'คุณต้องการลบโพสต์นี้ออกจากระบบหรือไม่?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('ยกเลิก'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('ลบ',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _firestore
                                          .collection('posts')
                                          .doc(posts[index].id)
                                          .delete();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
