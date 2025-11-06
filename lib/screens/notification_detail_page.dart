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

  final requesterId = notif['fromUserId'];
  final ownerId = notif['toUserId'];
  final postId = notif['postId'];
  final type = notif['type'] ?? 'donate';
  final messenger = ScaffoldMessenger.of(context);

  try {
    await _firestore.collection('notifications').doc(notifId).update({
      'status': 'accepted',
    });

    // 🔍 ตรวจว่ามีห้องแชทนี้อยู่แล้วไหม
    final existingChat = await _firestore
        .collection('chats')
        .where('participants', arrayContains: ownerId)
        .get();

    String? chatId;
    for (final doc in existingChat.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      if (participants.contains(requesterId) && data['postId'] == postId) {
        chatId = doc.id;
        break;
      }
    }

    // 🩵 ถ้ายังไม่มีแชทนี้ → สร้างใหม่
    if (chatId == null) {
      final chatDoc = await _firestore.collection('chats').add({
        'participants': [ownerId, requesterId],
        'postId': postId,
        'type': type,
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      chatId = chatDoc.id;
    }

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

    await _firestore.collection('notifications').add({
      'toUserId': requesterId,
      'fromUserId': ownerId,
      'postId': postId,
      'type': 'deal_accepted',
      'message': 'เจ้าของโพสต์ยอมรับดีลของคุณแล้ว 💬',
      'isRead': false,
      'status': 'accepted',
      'createdAt': FieldValue.serverTimestamp(),
    });

    messenger.showSnackBar(
      const SnackBar(content: Text('✅ ยอมรับดีลและสร้างห้องแชทเรียบร้อย!')),
    );

    // 📦 ดึงข้อมูลผู้ใช้ฝั่งตรงข้าม
    final userDoc = await _firestore.collection('users').doc(requesterId).get();
    final userData = userDoc.data() ?? {};
    final requesterName =
        '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.trim();
    final requesterImage = userData['profileImage'] ??
        'https://cdn-icons-png.flaticon.com/512/149/149071.png';

    // ✅ ไปหน้าแชททันที (เลือกฝั่งให้ถูก)
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));

    final currentUserId = _auth.currentUser!.uid;
    final isOwner = currentUserId == ownerId;

    Navigator.pushReplacementNamed(
      context,
      '/chatRoom',
      arguments: {
        'chatId': chatId ?? '',
        'otherUserId': isOwner ? requesterId : ownerId,
        'otherUserName': isOwner
            ? (requesterName.isNotEmpty ? requesterName : 'ผู้ใช้ Punjai')
            : (userData['firstname'] ?? '') + ' ' + (userData['lastname'] ?? ''),
        'otherUserImage': isOwner
            ? requesterImage
            : userData['profileImage'] ??
                'https://cdn-icons-png.flaticon.com/512/149/149071.png',
        'postId': postId ?? '',
        'ownerId': ownerId ?? '',
      },
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
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
        final isOwner = currentUser?.uid == toUser;
        final isRequester = currentUser?.uid == fromUser;

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
                    else if (status == 'rejected')
                      _rejectMessageBox(notifData)
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
        final confirmSnap = await _firestore
            .collection('confirmations')
            .where('postId', isEqualTo: notifData['postId'])
            .where('status', isEqualTo: 'accepted')
            .limit(1)
            .get();

        if (confirmSnap.docs.isNotEmpty) {
          final confirmData = confirmSnap.docs.first.data();
          final chatId = confirmData['chatId'];
          final ownerId = confirmData['ownerId'];
          final requesterId = confirmData['requesterId'];
          final currentUserId = _auth.currentUser!.uid;
          final isOwner = currentUserId == ownerId;
          final otherUserId = isOwner ? requesterId : ownerId;

          final userDoc =
              await _firestore.collection('users').doc(otherUserId).get();
          final userData = userDoc.data() ?? {};
          final otherName =
              '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.trim();
          final otherImage = userData['profileImage'] ??
              'https://cdn-icons-png.flaticon.com/512/149/149071.png';

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
              'postId': notifData['postId'],
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
