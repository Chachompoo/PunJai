import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:punjai_app/screens/profile/profile_screen.dart';

class FollowersFollowingPage extends StatelessWidget {
  final String uid;
  final bool showFollowers;
  const FollowersFollowingPage({
    super.key,
    required this.uid,
    required this.showFollowers,
  });

  @override
  Widget build(BuildContext context) {
    final title = showFollowers ? "ผู้ติดตาม" : "กำลังติดตาม";
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.8,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> ids = showFollowers
              ? (data['followersList'] ?? [])
              : (data['followingList'] ?? []);

          if (ids.isEmpty) {
            return Center(
              child: Text(
                showFollowers
                    ? "ยังไม่มีผู้ติดตาม 🕊️"
                    : "ยังไม่ได้ติดตามใครเลย 🌷",
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .where('uid', whereIn: ids)
                .get(),
            builder: (context, userSnap) {
              if (!userSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = userSnap.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: users.length,
                itemBuilder: (context, i) {
                  final u = users[i].data() as Map<String, dynamic>;
                  final profileImage = u['profileImage'] ??
                      'https://cdn-icons-png.flaticon.com/512/149/149071.png';
                  final name =
                      '${u['firstname'] ?? ''} ${u['lastname'] ?? ''}'.trim();
                  final username = u['username'] ?? '';

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
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
                      subtitle: Text('@$username',
                          style: const TextStyle(color: Colors.black54)),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(uid: u['uid']),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
