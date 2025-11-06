import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryPage extends StatelessWidget {
  static const routeName = '/history';
  const HistoryPage({super.key});

  Stream<QuerySnapshot> _userPosts(String uid) {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<DocumentSnapshot> _userData(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('กรุณาเข้าสู่ระบบก่อนค่ะ 💛')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        title: const Text('ประวัติของฉัน 📜'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _userData(uid),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          final points = userData['points'] ?? 0;

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('แต้มสะสมทั้งหมด 💖',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      '$points แต้ม',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF8FB1),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _userPosts(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData ||
                        snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text('ยังไม่มีประวัติการบริจาคหรือแลกเปลี่ยนค่ะ 💗'));
                    }

                    final posts = snapshot.data!.docs;
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final data = posts[index].data()
                            as Map<String, dynamic>;
                        final type = data['type'] ?? 'unknown';
                        final title =
                            data['title'] ?? 'ไม่ระบุชื่อสิ่งของ';
                        final imageUrl = data['imageUrl'] ??
                            'https://cdn-icons-png.flaticon.com/512/833/833524.png';
                        final color = type == 'donate'
                            ? const Color(0xFFFFF7CC)
                            : type == 'request'
                                ? const Color(0xFFFFD6E8)
                                : const Color(0xFFD6F0FF);

                        return Card(
                          color: color,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          margin:
                              const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                                backgroundImage: NetworkImage(imageUrl)),
                            title: Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              type == 'donate'
                                  ? '💛 บริจาคสิ่งของ'
                                  : type == 'request'
                                      ? '💗 ขอรับบริจาค'
                                      : '💙 แลกเปลี่ยนสิ่งของ',
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
        },
      ),
    );
  }
}
