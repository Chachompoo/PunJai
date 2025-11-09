import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_detail_page.dart';
import '../profile/reviews_page.dart';  
import '../profile/profile_screen.dart'; 
import 'package:flutter/scheduler.dart';
import '../profile/history_detail_page.dart';
import '../posts/post_detail_page.dart';


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
  static const kText = Color(0xFF393E46);

  late Stream<QuerySnapshot> _notifStream;

  @override
  void initState() {
    super.initState();

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
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

  // ✅ format เวลาสวย ๆ
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

  // ✅ mapping icon / color ตาม type
  Map<String, dynamic> _getTypeStyle(String type) {
    switch (type) {
      case 'request':
        return {
          'icon': Icons.volunteer_activism,
          'color': const Color(0xFFFFC1C1),
        };
      case 'deal_accepted': // ✅ แจ้งเตือนเมื่อเจ้าของโพสต์ยอมรับดีล
        return {
          'icon': Icons.handshake_rounded,
          'color': const Color(0xFFA5D6A7), // เขียวมิ้นต์พาสเทล
        };
      case 'accept':
        return {
          'icon': Icons.check_circle_outline,
          'color': const Color(0xFF91C7F2),
        };
      case 'shipping':
        return {
          'icon': Icons.local_shipping_outlined,
          'color': const Color(0xFFFFD580),
        };
      case 'completed':
        return {
          'icon': Icons.favorite_outline,
          'color': const Color(0xFFA1E3A1),
        };
      case 'review':
        return {
          'icon': Icons.star_rounded,
          'color': const Color(0xFFFFC947),
        };
      case 'swap_request':
        return {
          'icon': Icons.swap_horiz,
          'color': const Color(0xFF9EDAFF),
        };
      case 'swap_accept':
        return {
          'icon': Icons.handshake_outlined,
          'color': const Color(0xFF84B6F4),
        };
      case 'chat':
        return {
          'icon': Icons.chat_bubble_outline,
          'color': Colors.grey.shade500,
        };
      case 'points_awarded': // ✅ แก้เพิ่ม
        return {
          'icon': Icons.favorite_rounded,
          'color': const Color(0xFFFF8FB1),
        };
      case 'review_received': // ✅ แก้เพิ่ม
        return {
          'icon': Icons.star_rounded,
          'color': const Color(0xFFFFC947),
        };
      case 'trust_updated': // ✅ แก้เพิ่ม
        return {
          'icon': Icons.verified_rounded,
          'color': const Color(0xFF9EDAFF),
        };
      case 'system':
        return {
          'icon': Icons.card_giftcard,
          'color': const Color(0xFFFF8FB1),
        };
      case 'post_expiring':
        return {
          'icon': Icons.timer_outlined,
          'color': const Color(0xFFB39DDB), // ม่วงพาสเทล ⏰
        };
      case 'out_of_stock':
        return {
          'icon': Icons.inventory_2_outlined,
          'color': const Color(0xFFBDBDBD),
        };


      // 🔥 ส่วนยกเลิกดีล
      case 'cancel_request':
      case 'cancel_donate':
      case 'cancel_swap':
      case 'cancel_received':
        return {
          'icon': Icons.cancel_outlined,
          'color': Colors.redAccent,
        };
      default:
        return {
          'icon': Icons.notifications_none_outlined,
          'color': Colors.grey,
        };
    }
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

          if (snapshot.connectionState == ConnectionState.waiting ||
              (snapshot.hasData && snapshot.data!.metadata.hasPendingWrites)) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          // 🩷 เพิ่ม debug log เพื่อตรวจว่ามีแจ้งเตือนเข้ามากี่รายการ
          print('📬 จำนวนแจ้งเตือนทั้งหมด: ${docs.length}');

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

          // 🩷 เพิ่ม shrinkWrap และ physics เพื่อแก้ Infinite Size error
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            shrinkWrap: true, // 🩷 แก้ตรงนี้
            physics: const BouncingScrollPhysics(), // 🩷 แก้ตรงนี้
            itemBuilder: (context, index) {
              final data = notifications[index];
              final docId = data['id'];
              final message = data['message'] ?? 'ไม่มีข้อความ';
              final type = data['type'] ?? 'general';
              final isRead = data['isRead'] ?? false;
              final createdAt = data['createdAt'];
              final time = _formatTimestamp(createdAt);

              final style = _getTypeStyle(type);
              final icon = style['icon'] as IconData;
              final color = style['color'] as Color;
              
              return GestureDetector(
                onTap: () async {
                  if (!mounted) return;

                  final currentType = (data['type'] ?? '').toString().toLowerCase();
                  final targetData = Map<String, dynamic>.from(data);
                  final targetDocId = docId;

                  // ✅ markAsRead แต่ไม่รอผล (ไม่ block context)
                  _firestore.collection('notifications').doc(docId).update({'isRead': true});

                  await Future.microtask(() {});

                  if (!mounted) return;

                  final currentUser = _auth.currentUser;
                  final firestore = FirebaseFirestore.instance;

                  // 🌟 6. แจ้งเตือนดีล: ขอรับ / เสนอ / แลก (ไปหน้า NotificationDetailPage)
                  if (currentType.contains('deal_request') ||
                      currentType.contains('deal_offer') ||
                      currentType.contains('deal_swap')) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => NotificationDetailPage(
                        notificationData: targetData,
                        notificationId: targetDocId,
                      ),
                    ));
                    return;
                  }

                  // 🌟 7. แจ้งเตือนโพสต์ใกล้หมดอายุ หรือหมดอายุแล้ว (ไปหน้า PostDetailPage)
                  if (currentType.contains('post_expiring') ||
                      currentType.contains('post_expired')) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PostDetailPage(
                        postData: {'postId': targetData['postId'] ?? ''},
                      ),
                    ));
                    return;
                  }

                  // 🩷 8. Default fallback
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => NotificationDetailPage(
                      notificationData: targetData,
                      notificationId: targetDocId,
                    ),
                  ));

                }, // 🩷 ✅ ปิด onTap ให้ครบ

                // ✅ child อยู่ถัดจาก onTap (ใน GestureDetector)
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
                            fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
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
              ); // 🩷 ✅ ปิด GestureDetector ที่นี่
            },
          ); // 🩷 ✅ ปิด ListView.builder
        },
      ),
    );
  }
}
