import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ChatRoomPage.dart';

class ChatsListPage extends StatefulWidget {
  const ChatsListPage({super.key});
  static const routeName = '/chatsList';

  @override
  State<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends State<ChatsListPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
        title: const Text(
          'ข้อความ 💬',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.pinkAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.pinkAccent,
          tabs: const [
            Tab(text: 'แชทดีล'),
            Tab(text: 'แชททั่วไป'),
          ],
        ),
      ),

      // 🎀 แยก 2 หมวด
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatList('deal'),
          _buildChatList('normal'),
        ],
      ),
    );
  }

  Future<void> _deleteChat(BuildContext context, String chatId) async {
  final firestore = FirebaseFirestore.instance;

  try {
    // 🔹 ลบ messages ทั้งหมดใน subcollection
    final messagesRef = firestore.collection('chats').doc(chatId).collection('messages');
    final messagesSnap = await messagesRef.get();
    for (var msg in messagesSnap.docs) {
      await msg.reference.delete();
    }

    // 🔹 ลบ document ของ chat เอง
    await firestore.collection('chats').doc(chatId).delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ลบแชทเรียบร้อยแล้ว 🧹')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เกิดข้อผิดพลาดในการลบแชท: $e')),
    );
  }
}


  // =========================================================
  // 🩷 สร้าง UI แชทตามประเภท (deal / normal)
  // =========================================================
  Widget _buildChatList(String chatType) {
    final currentUser = _auth.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser?.uid)
          .where('chatType', isEqualTo: chatType)
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              chatType == 'deal'
                  ? 'ยังไม่มีแชทดีล 🤝'
                  : 'ยังไม่มีแชททั่วไป 💌',
              style: const TextStyle(color: Colors.black54),
            ),
          );
        }

        final chats = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index].data() as Map<String, dynamic>;
            final participants =
                List<String>.from(chat['participants'] ?? []);
            final otherUserId =
                participants.firstWhere((id) => id != currentUser?.uid);

            final lastMsg = chat['lastMessage'] ?? '';
            final lastTime = chat['updatedAt'] as Timestamp?;
            final time = lastTime != null
                ? _formatTime(lastTime.toDate())
                : 'ไม่ทราบเวลา';

            // 🧾 ดึงข้อมูลดีล (ถ้ามี)
            final dealType = chat['dealType'] ?? '';
            final dealTitle = chat['dealTitle'] ?? '';
            final dealStatus = chat['dealStatus'] ?? '';
            final confirmId = chat['confirmId'] ?? '';

            // 🩷 แปลงประเภทโพสต์เป็นภาษาไทย
            String displayType = '';
            switch (dealType) {
              case 'donate':
                displayType = 'บริจาค';
                break;
              case 'request':
                displayType = 'ขอรับ';
                break;
              case 'swap':
                displayType = 'แลกเปลี่ยน';
                break;
              default:
                displayType = '';
            }

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(otherUserId).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return const SizedBox();
                final userData =
                    userSnap.data!.data() as Map<String, dynamic>?;
                final name =
                    '${userData?['firstname'] ?? ''} ${userData?['lastname'] ?? ''}';
                final profileImage = userData?['profileImage'] ??
                    'https://cdn-icons-png.flaticon.com/512/149/149071.png';

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatRoomPage(
                          chatId: chats[index].id,
                          otherUserId: otherUserId,
                          otherUserName: name,
                          otherUserImage: profileImage,
                          postId: chat['dealPostId'] ?? '',
                          ownerId: chat['ownerId'] ?? '',
                        ),
                      ),
                    );
                  },
                  onLongPress: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('ลบแชทนี้หรือไม่? 🗑️'),
                        content: const Text('หากลบแล้วจะไม่สามารถกู้คืนได้'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('ยกเลิก'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await _deleteChat(context, chats[index].id);
                    }
                  },

                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(2, 3),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        // 🧍‍♀️ รูปโปรไฟล์
                        CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(profileImage),
                        ),
                        const SizedBox(width: 12),

                        // 📋 เนื้อหาแชท
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 6),

                              // 💬 แสดงข้อมูลตามประเภท
                              if (chatType == 'deal') ...[
  Text(
    "$displayType : $dealTitle",
    style: const TextStyle(
      color: Colors.black87,
      fontSize: 14,
    ),
  ),

  // 🔁 ดึงสถานะแบบเรียลไทม์จาก Firestore (แทน dealStatus เดิม)
  if (confirmId.isNotEmpty)
    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('confirmations').doc(confirmId).snapshots(),
      builder: (context, confirmSnap) {
        if (!confirmSnap.hasData || !(confirmSnap.data?.exists ?? false)) {
          return const Text(
            "สถานะ : ไม่พบข้อมูล",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          );
        }

        final confirmData = confirmSnap.data!.data()!;
        final status = (confirmData['status'] as String? ?? '').trim();

        return Text(
          "สถานะ : ${_statusText(status)}",
          style: TextStyle(
            color: _statusColor(status),
            fontSize: 13,
          ),
        );
      },
    ),
] else ...[
                                Text(
                                  lastMsg.isNotEmpty
                                      ? lastMsg
                                      : "เริ่มแชทกันเลย 💬",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // 🕒 เวลา
                        Text(
                          time,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
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
    );
  }

  // =========================================================
  // 🧭 Utility Functions
  // =========================================================
  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาที';
    if (diff.inHours < 24) return '${diff.inHours} ชม.';
    return '${date.day}/${date.month}/${date.year}';
  }

  static String _statusText(String status) {
  switch (status) {
    case 'pending':
      return 'รอเจ้าของตอบรับ';
    case 'accepted':
    case 'in_progress':
      return 'กำลังดำเนินการ';
    case 'shipping':
      return 'กำลังจัดส่ง';
    case 'completed':
      return 'เสร็จสิ้น';
    case 'cancelled':
      return 'ยกเลิกแล้ว';
    default:
      return 'ไม่ทราบสถานะ';
  }
}

static Color _statusColor(String status) {
  switch (status) {
    case 'pending':
      return Colors.grey;
    case 'accepted':
    case 'in_progress':
      return Colors.orange;
    case 'shipping':
      return Colors.blueGrey;
    case 'completed':
      return Colors.green;
    case 'cancelled':
      return Colors.redAccent;
    default:
      return Colors.grey;
  }
}
}
