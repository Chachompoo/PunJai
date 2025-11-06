import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TopDonorsPage extends StatelessWidget {
  const TopDonorsPage({super.key});
  static const routeName = '/topDonors';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 จัดอันดับผู้บริจาคสูงสุด'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFFDFBFB),
      body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('points', isGreaterThanOrEqualTo: 0) // ✅ บังคับให้มี field points
          .orderBy('points', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'ยังไม่มีข้อมูลผู้บริจาคค่ะ 💛',
              style: TextStyle(color: Colors.brown),
            ),
          );
        }

        final users = snapshot.data!.docs;
        print('✅ Loaded ${users.length} users'); // 🧩 debug เช็กว่ามี data จริงไหม

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>;
            final name = data['firstname'] != null
                ? '${data['firstname']} ${data['lastname'] ?? ''}'
                : (data['name'] ?? 'ไม่ระบุชื่อ');
            final points = (data['points'] ?? 0).toInt(); // ✅ ป้องกัน double
            final imageUrl = data['profileImage'] ??
                'https://cdn-icons-png.flaticon.com/512/149/149071.png';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(2, 3),
                  ),
                ],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(imageUrl),
                  radius: 25,
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text('แต้มสะสมทั้งหมด: $points'),
                trailing: Text(
                  '#${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: index == 0
                        ? Colors.amber[800]
                        : index == 1
                            ? Colors.grey[700]
                            : index == 2
                                ? Colors.brown[400]
                                : Colors.black54,
                    fontSize: 18,
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
}
