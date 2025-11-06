import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:punjai_app/screens/post_detail_page.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});
  static const routeName = '/myRequests';

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final colorMap = {
    'donate': const Color(0xFFFFF7CC),
    'request': const Color(0xFFFFD6E8),
    'swap': const Color(0xFFD6F0FF),
  };

  Stream<QuerySnapshot> _myRequestsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('confirmations')
        .where('requesterId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '🕓 รอการตอบรับ';
      case 'accepted':
        return '💚 ได้รับการตอบรับแล้ว';
      case 'rejected':
        return '❌ ถูกปฏิเสธ';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('คำขอของฉัน'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFFDFBFB),
      body: StreamBuilder<QuerySnapshot>(
        stream: _myRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีคำขอที่คุณส่ง 🕊️',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final requestData = requests[index].data() as Map<String, dynamic>;
              final status = requestData['status'] ?? 'pending';
              final postId = requestData['postId'];
              final type = requestData['type'] ?? 'donate';
              final color = colorMap[type] ?? Colors.white;

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('posts').doc(postId).get(),
                builder: (context, postSnap) {
                  if (!postSnap.hasData || !postSnap.data!.exists) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('โพสต์นี้ถูกลบไปแล้ว ❌'),
                    );
                  }

                  final post = postSnap.data!.data() as Map<String, dynamic>;
                  final imageUrl = (post['images'] != null &&
                          (post['images'] as List).isNotEmpty &&
                          (post['images'][0] as String).startsWith('http'))
                      ? post['images'][0]
                      : 'https://cdn-icons-png.flaticon.com/512/1160/1160358.png';

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(postData: post),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // รูปภาพโพสต์
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                            ),
                            child: Image.network(
                              imageUrl,
                              width: 120,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post['title'] ?? 'ไม่มีชื่อโพสต์',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    type == 'donate'
                                        ? 'ประเภท: บริจาค 💛'
                                        : type == 'request'
                                            ? 'ประเภท: ขอรับ 💗'
                                            : 'ประเภท: แลกเปลี่ยน 💙',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.black54),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getStatusText(status),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(status),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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
