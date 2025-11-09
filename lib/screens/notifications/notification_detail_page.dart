import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationDetailPage extends StatefulWidget {
  final Map<String, dynamic> notificationData;
  final String notificationId;

  const NotificationDetailPage({
    super.key,
    required this.notificationData,
    required this.notificationId,
  });

  static const routeName = '/notificationDetail';

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

// 🎀 ยอมรับดีล
Future<void> _acceptDeal(Map<String, dynamic> notif, String notifId) async {
  final currentUser = _auth.currentUser;
  if (currentUser == null) return;

  try {
    setState(() => _isLoading = true);

    final requesterId = notif['fromUserId'];
    final postId = notif['postId'];

    if (postId.isEmpty) {
      print("⚠️ ไม่มี postId ใน notification!");
      return;
    }

    // 🟡 ดึงข้อมูลโพสต์
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    final postData = postDoc.data();
    final postTitle = postData?['title'] ?? 'ไม่ระบุชื่อโพสต์';
    final postType = postData?['type'] ?? 'unknown';

    // ✅ อัปเดตสถานะ notification เดิม
    await _firestore.collection('notifications').doc(notifId).update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 🩷 ✅ สร้างแจ้งเตือนใหม่ให้ผู้ขอ (Requester)
    await _firestore.collection('notifications').add({
      'toUserId': requesterId,
      'fromUserId': currentUser.uid,
      'postId': postId,
      'type': 'deal_accepted',
      'message': 'คำขอของคุณสำหรับ "$postTitle" ได้รับการยอมรับแล้ว 🎉',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 🩵 เช็กหรือสร้าง confirmation ก่อน
    final confirmRef = _firestore.collection('confirmations');
    final existingConfirm = await confirmRef
        .where('postId', isEqualTo: postId)
        .where('requesterId', isEqualTo: requesterId)
        .limit(1)
        .get();

    String confirmId;

    if (existingConfirm.docs.isNotEmpty) {
      confirmId = existingConfirm.docs.first.id;
      await confirmRef.doc(confirmId).update({
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('🔄 ใช้ confirmId เดิม: $confirmId');
    } else {
      final newConfirm = await confirmRef.add({
        'ownerId': currentUser.uid,
        'requesterId': requesterId,
        'postId': postId,
        'status': 'in_progress',
        'ownerConfirm': false,
        'requesterConfirm': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      confirmId = newConfirm.id;
      print('🆕 สร้าง confirmId ใหม่: $confirmId');
    }

    // 💬 จากนั้นค่อยสร้างแชท พร้อมแนบ confirmId
    final chatRef = await _firestore.collection('chats').add({
      'participants': [currentUser.uid, requesterId],
      'ownerId': currentUser.uid,
      'dealPostId': postId,
      'dealTitle': postTitle,
      'dealType': postType,
      'dealStatus': 'in_progress',
      'confirmId': confirmId,
      'chatType': 'deal',
      'lastMessage': '',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 🔁 อัปเดต confirm ให้รู้ว่า chat ไหนเชื่อมอยู่
    await confirmRef.doc(confirmId).update({
      'chatId': chatRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 🩷 เพิ่มข้อความระบบในแชท
    await chatRef.collection('messages').add({
      'type': 'system',
      'text': '🎯 ดีลใหม่สำหรับโพสต์: $postTitle',
      'createdAt': FieldValue.serverTimestamp(),
    });

    print("✅ สร้างแชทสำเร็จ confirmId=$confirmId, chatId=${chatRef.id}");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 ยอมรับดีลและสร้างห้องแชทเรียบร้อยแล้ว!'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() => _isLoading = false);
  } catch (e) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เกิดข้อผิดพลาด: $e'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}


  // 💔 ปฏิเสธดีล
  Future<void> _rejectDeal(Map<String, dynamic> notif, String notifId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final reason = _reasonController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (reason.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('กรุณากรอกเหตุผลก่อนปฏิเสธ')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('notifications').doc(notifId).update({
        'status': 'rejected',
      });

      await _firestore.collection('notifications').add({
        'toUserId': notif['fromUserId'],
        'fromUserId': currentUser.uid,
        'postId': notif['postId'],
        'type': 'deal_rejected',
        'status': 'rejected',
        'message': 'เจ้าของโพสต์ปฏิเสธคำขอ 😢 เหตุผล: $reason',
        
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('❌ ปฏิเสธดีลเรียบร้อย')),
      );
      Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
Widget build(BuildContext context) {
  final notif = widget.notificationData;
  final currentUser = _auth.currentUser;

  return Scaffold(
    backgroundColor: const Color(0xFFFFF7FB),
    appBar: AppBar(
      title: const Text(
        'รายละเอียดแจ้งเตือน',
        style: TextStyle(color: Color(0xFF393E46)),
      ),
      backgroundColor: Colors.white,
      centerTitle: true,
      elevation: 1,
      foregroundColor: Colors.black,
    ),
    body: StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('notifications')
          .doc(widget.notificationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifData =
            snapshot.data!.data() as Map<String, dynamic>? ?? notif;
        final status = notifData['status'] ?? 'pending';
        final fromUser = notifData['fromUserId'];
        final toUser = notifData['toUserId'];
        final postId = notifData['postId'];
        final notifType = notifData['type'] ?? '';

        final isOwner = currentUser?.uid == toUser && notifType != 'deal_rejected';
        final isRequester = currentUser?.uid == fromUser || notifType == 'deal_rejected';


        return FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('posts').doc(postId).get(),
          builder: (context, postSnap) {
            if (postSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final postData = postSnap.data?.data() as Map<String, dynamic>? ?? {};
            final postTitle = postData['title'] ?? '(ไม่พบชื่อโพสต์)';
            final postTypeRaw = postData['type'] ?? 'donate';

            // 🩷 แปลงชื่อ type ให้อ่านง่าย + ใส่ไอคอน
            String postType;
            IconData postIcon;
            Color postColor;

            if (postTypeRaw == 'donate') {
              postType = 'บริจาคสิ่งของ';
              postIcon = Icons.volunteer_activism_rounded;
              postColor = const Color(0xFFFFC1CC);
            } else if (postTypeRaw == 'request') {
              postType = 'ขอรับบริจาค';
              postIcon = Icons.card_giftcard_rounded;
              postColor = const Color(0xFFFFB6C1);
            } else if (postTypeRaw == 'swap') {
              postType = 'แลกเปลี่ยนสิ่งของ';
              postIcon = Icons.swap_horiz_rounded;
              postColor = const Color(0xFFB3E5FC);
            } else {
              postType = postTypeRaw;
              postIcon = Icons.help_outline;
              postColor = Colors.grey;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 🌸 การ์ดรายละเอียด
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notifData['message'] ?? 'ไม่มีข้อความ',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF393E46),
                          ),
                        ),
                        const Divider(height: 25),

                        // ประเภทโพสต์ + ไอคอน
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ประเภทโพสต์:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54),
                            ),
                            Row(
                              children: [
                                Icon(postIcon, color: postColor, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  postType,
                                  style: TextStyle(
                                    color: postColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // ชื่อโพสต์
                        _detailRow('โพสต์', postTitle),

                        // สถานะดีล
                        _detailRow('สถานะดีล', status),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 💖 ฝั่งเจ้าของโพสต์
                  if (isOwner) ...[
                    if (status == 'pending') ...[
                      _reasonBox(),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _acceptDeal(
                                  widget.notificationData,
                                  widget.notificationId),
                              icon: const Icon(Icons.check_circle),
                              label: const Text("ยอมรับดีล"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF8FB1),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _rejectDeal(
                                  widget.notificationData,
                                  widget.notificationId),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text("ปฏิเสธ"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF91C7F2),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (status == 'accepted') ...[
                      _goToChatButton(notifData)
                    ] else if (status == 'rejected') ...[
                      const Text(
                        '❌ คุณได้ปฏิเสธคำขอนี้แล้ว',
                        style: TextStyle(color: Colors.redAccent, fontSize: 16),
                      ),
                    ],
                  ],

                  // 💙 ฝั่งผู้ขอ
                  if (isRequester) ...[
                    if (status == 'accepted')
                      _goToChatButton(notifData)
                    else if (status == 'rejected') ...[
                      const SizedBox(height: 20),
                      Text(
                        '❌ คุณถูกปฏิเสธคำขอนี้แล้ว',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ]
                    else
                      const Text(
                        '⌛ เจ้าของโพสต์ยังไม่ตอบรับคำขอของคุณ',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

// 🩷 ฟังก์ชันสร้างแถวข้อมูลทั่วไป
Widget _detailRow(String title, String value) {
  Color statusColor = Colors.black87;
  IconData? statusIcon;

  if (value.toLowerCase().contains('accepted')) {
    statusColor = Colors.green;
    statusIcon = Icons.check_circle_outline;
  } else if (value.toLowerCase().contains('rejected')) {
    statusColor = Colors.redAccent;
    statusIcon = Icons.cancel_outlined;
  } else if (value.toLowerCase().contains('pending')) {
    statusColor = Colors.orangeAccent;
    statusIcon = Icons.hourglass_empty;
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$title:',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (statusIcon != null)
                Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


/// ฟังก์ชันไปหน้าแชท
Future<void> _goToChat(Map<String, dynamic> notifData) async {
  final confirmSnap = await _firestore
      .collection('confirmations')
      .where('postId', isEqualTo: notifData['postId'])
      .where('status', isEqualTo: 'accepted')
      .where('requesterId', isEqualTo: notifData['fromUserId'])
      .limit(1)
      .get();

  if (confirmSnap.docs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ไม่พบห้องแชทของดีลนี้ 😅')),
    );
    return;
  }

  final confirmData = confirmSnap.docs.first.data();
  final chatId = confirmData['chatId'];
  final otherUserId = confirmData['requesterId'];
  final userDoc =
      await _firestore.collection('users').doc(otherUserId).get();
  final userData = userDoc.data() ?? {};

  Navigator.pushReplacementNamed(
    context,
    '/chatRoom',
    arguments: {
      'chatId': chatId,
      'otherUserId': otherUserId,
      'otherUserName':
          '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}',
      'otherUserImage': userData['profileImage'] ??
          'https://cdn-icons-png.flaticon.com/512/149/149071.png',
      'postId': notifData['postId'],
      'ownerId': notifData['toUserId'],
    },
  );
}

// 📦 กล่องเหตุผลในการปฏิเสธ
Widget _reasonBox() {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0F5),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'เหตุผลในการปฏิเสธ (ถ้ามี)',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'พิมพ์เหตุผลของคุณ...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Colors.pinkAccent, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Colors.pinkAccent, width: 2),
            ),
          ),
        ),
      ],
    ),
  );
}

// 💬 ปุ่มไปหน้าแชท
Widget _goToChatButton(Map<String, dynamic> notifData) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () async {
        final currentUserId = _auth.currentUser!.uid;

        // 🔍 ค้นหาดีลที่ตรงกับโพสต์นี้ + มีสถานะ accepted หรือ in_progress
        final confirmSnap = await _firestore
            .collection('confirmations')
            .where('postId', isEqualTo: notifData['postId'])
            .where(
              Filter.or(
                Filter('status', isEqualTo: 'accepted'),
                Filter('status', isEqualTo: 'in_progress'),
              ),
            )
            .where(
              Filter.or(
                Filter('ownerId', isEqualTo: currentUserId),
                Filter('requesterId', isEqualTo: currentUserId),
              ),
            )
            .limit(1)
            .get();

        if (confirmSnap.docs.isNotEmpty) {
          final confirmData = confirmSnap.docs.first.data();
          final chatId = confirmData['chatId'];
          final ownerId = confirmData['ownerId'];
          final requesterId = confirmData['requesterId'];

          final isOwner = currentUserId == ownerId;
          final otherUserId = isOwner ? requesterId : ownerId;

          // 📚 ดึงข้อมูลผู้ใช้ฝั่งตรงข้าม
          final userDoc =
              await _firestore.collection('users').doc(otherUserId).get();
          final userData = userDoc.data() ?? {};
          final otherName =
              '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.trim();
          final otherImage = userData['profileImage'] ??
              'https://cdn-icons-png.flaticon.com/512/149/149071.png';

          // 🪄 ไปหน้าแชท
          if (!context.mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/chatRoom',
            arguments: {
              'chatId': chatId,
              'otherUserId': otherUserId,
              'otherUserName':
                  otherName.isNotEmpty ? otherName : 'ผู้ใช้ Punjai',
              'otherUserImage': otherImage,
              'postId': confirmData['postId'],
              'ownerId': ownerId,
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบห้องแชทของดีลนี้ 😅')),
          );
        }
      },
      icon: const Icon(Icons.chat_bubble_outline),
      label: const Text("ไปที่แชท 💬"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  );
}


// ❌ กล่องแสดงเหตุผลตอนถูกปฏิเสธ
Widget _rejectMessageBox(Map<String, dynamic> notifData) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE6E6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      notifData['message'] ?? 'คำขอของคุณถูกปฏิเสธแล้ว 😢',
      style: const TextStyle(
          color: Colors.redAccent, fontWeight: FontWeight.bold),
    ),
  );
}
}
