import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_detail_page.dart';


class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  static const routeName = '/notifications';

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  static const kBg = Color(0xFFFFF7FB);
  static const kPrimary = Color(0xFFFF8FB1);
  static const kText = Color(0xFF393E46);

  late Stream<QuerySnapshot> _notifStream;

  @override
  void initState() {
    super.initState();

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      // ✅ ใช้ includeMetadataChanges เพื่อรอ timestamp จาก server
      _notifStream = _firestore
          .collection('notifications')
          .where('toUserId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(includeMetadataChanges: true);
    } else {
      _notifStream = const Stream.empty();
    }
  }

  Future<void> _markAsRead(String docId) async {
    await _firestore.collection('notifications').doc(docId).update({
      'isRead': true,
    });
  }

  Future<void> _clearAll() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final batch = _firestore.batch();
    final query = await _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: currentUser.uid)
        .get();

    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🧹 ล้างการแจ้งเตือนทั้งหมดแล้ว')),
    );
  }

  Future<void> _acceptDeal(Map<String, dynamic> notif, String notifId) async {
  final currentUser = _auth.currentUser;
  if (currentUser == null) return;

  final requesterId = notif['fromUserId'];
  final ownerId = notif['toUserId'];
  final postId = notif['postId'];
  final type = notif['type'] ?? 'donate';
  final messenger = ScaffoldMessenger.of(context);

  try {
    // ✅ อัปเดตสถานะ notification
    await _firestore.collection('notifications').doc(notifId).update({
      'status': 'accepted',
    });

    // ✅ ตรวจสอบก่อนว่ามีห้องแชทนี้อยู่แล้วหรือยัง
    final existingChat = await _firestore
        .collection('chats')
        .where('participants', arrayContains: ownerId)
        .get();

    final alreadyExists = existingChat.docs.any((doc) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      return participants.contains(requesterId) &&
          data['postId'] == postId;
    });

    // ✅ ถ้ายังไม่มีห้อง → สร้างใหม่
    String chatId;
    if (!alreadyExists) {
      final chatDoc = await _firestore.collection('chats').add({
        'participants': [ownerId, requesterId],
        'postId': postId,
        'type': type,
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      chatId = chatDoc.id;
    } else {
      // ดึง chat ที่มีอยู่แล้ว
      chatId = existingChat.docs.first.id;
    }

    // ✅ สร้างเอกสารใน confirmations (ไว้สำหรับยืนยันการส่งของ)
    await _firestore.collection('confirmations').add({
      'chatId': chatId,
      'postId': postId,
      'ownerId': ownerId,
      'requesterId': requesterId,
      'status': 'accepted',
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'isReviewed': false,
      'ownerConfirm': false,
      'requesterConfirm': false,
    });

    // ✅ แจ้งเตือนไปยังผู้ขอ
    await _firestore.collection('notifications').add({
      'toUserId': requesterId,
      'fromUserId': ownerId,
      'postId': postId,
      'type': 'deal_accepted',
      'message': 'เจ้าของโพสต์ยอมรับดีลของคุณแล้ว 💬',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    messenger.showSnackBar(
      const SnackBar(content: Text('✅ ยอมรับดีลและสร้างห้องแชทเรียบร้อย!')),
    );

  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
    );
  }
}


  // ❌ ปฏิเสธดีล
  Future<void> _rejectDeal(Map<String, dynamic> notif, String notifId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await _firestore.collection('notifications').doc(notifId).update({
        'status': 'rejected',
      });

      await _firestore.collection('notifications').add({
        'toUserId': notif['fromUserId'],
        'fromUserId': currentUser.uid,
        'postId': notif['postId'],
        'type': 'deal_rejected',
        'message': 'เจ้าของโพสต์ปฏิเสธคำขอ 😢',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('❌ ปฏิเสธดีลเรียบร้อย')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  // ✅ ฟังก์ชัน format เวลาแบบกัน null
  String _formatTimestamp(dynamic createdAt) {
    if (createdAt == null) return 'เมื่อสักครู่';
    if (createdAt is Timestamp) {
      final date = createdAt.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'เมื่อสักครู่';
      if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
      if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว';
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'ไม่ทราบเวลา';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text(
          'การแจ้งเตือนของฉัน',
          style: TextStyle(color: kText, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        foregroundColor: kText,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: kText),
            onPressed: _clearAll,
            tooltip: 'ล้างทั้งหมด',
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notifStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
  print('🔥 Firestore Error: ${snapshot.error}');
  return Center(
    child: Text(
      'เกิดข้อผิดพลาด: ${snapshot.error}',
      style: const TextStyle(color: Colors.redAccent),
      textAlign: TextAlign.center,
    ),
  );
}


          // ✅ รอ Firestore sync ครั้งแรกเพื่อกันกระพริบ
          if (snapshot.connectionState == ConnectionState.waiting ||
              (snapshot.hasData && snapshot.data!.metadata.hasPendingWrites)) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีการแจ้งเตือนในตอนนี้ 💌',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final notifications = docs
              .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index];
              final docId = data['id'];
              final message = data['message'] ?? 'ไม่มีข้อความ';
              final type = data['type'] ?? 'general';
              final isRead = data['isRead'] ?? false;
              final createdAt = data['createdAt'];
              final time = _formatTimestamp(createdAt);

              IconData icon;
              Color color;

              switch (type) {
                case 'deal_accepted':
                  icon = Icons.chat_bubble_outline;
                  color = const Color(0xFF91C7F2);
                  break;
                case 'deal_rejected':
                  icon = Icons.block;
                  color = Colors.redAccent;
                  break;
                case 'donate_request':
                  icon = Icons.volunteer_activism;
                  color = Colors.pinkAccent;
                  break;
                case 'swap_request':
                  icon = Icons.swap_horiz;
                  color = Colors.orangeAccent;
                  break;
                default:
                  icon = Icons.notifications_active_outlined;
                  color = Colors.grey;
              }

              return GestureDetector(
                onTap: () {
                  _markAsRead(docId);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationDetailPage(
                        notificationData: data,
                        notificationId: docId,
                      ),
                    ),
                  );

                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white.withOpacity(0.7) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withOpacity(0.2),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: kText,
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
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
