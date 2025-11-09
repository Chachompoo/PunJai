import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConfirmationsPage extends StatefulWidget {
  const ConfirmationsPage({super.key});
  static const routeName = '/confirmations';

  @override
  State<ConfirmationsPage> createState() => _ConfirmationsPageState();
}

class _ConfirmationsPageState extends State<ConfirmationsPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final colorMap = {
    'donate': const Color(0xFFFFF7CC),
    'request': const Color(0xFFFFD6E8),
    'swap': const Color(0xFFD6F0FF),
  };

  /// ✅ ฟังก์ชันเพิ่มแต้มให้ผู้บริจาค
  Future<void> _addDonationPoint(String giverId) async {
    final userRef = _firestore.collection('users').doc(giverId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) return;
      final currentPoints = (snap['points'] ?? 0) as int;
      final currentCount = (snap['donationsCount'] ?? 0) as int;
      tx.update(userRef, {
        'points': currentPoints + 1,
        'donationsCount': currentCount + 1,
      });
    });
  }

  /// ✅ ฟังก์ชันสร้างห้องแชตอัตโนมัติเมื่อดีลสำเร็จ
Future<void> _createChatIfNotExist(String giverId, String receiverId) async {
  final chatsRef = _firestore.collection('chats');

  // 🔹 เช็คว่ามีแชตเดิมอยู่ไหม
  final existingChat = await chatsRef
      .where('participants', arrayContains: giverId)
      .get();

  for (final doc in existingChat.docs) {
    final participants = List<String>.from(doc['participants']);
    if (participants.contains(receiverId)) {
      print('💬 ห้องแชตมีอยู่แล้ว: ${doc.id}');
      return; // ไม่ต้องสร้างใหม่
    }
  }

  // 🔹 ถ้าไม่เจอ → สร้างห้องใหม่
  final newChat = await chatsRef.add({
    'participants': [giverId, receiverId],
    'lastMessage': '',
    'updatedAt': FieldValue.serverTimestamp(),
  });

  print('🆕 สร้างห้องแชตใหม่: ${newChat.id}');
}


  /// ✅ ฟังก์ชันเพิ่มรีวิวและคำนวณคะแนนเฉลี่ย
  Future<void> _submitReview(String giverId, double rating, String comment, String confirmationId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // เพิ่มรีวิวใหม่
    await _firestore.collection('reviews').add({
      'giverId': giverId,
      'receiverId': currentUser.uid,
      'confirmationId': confirmationId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // อัปเดตคะแนนเฉลี่ย
    final userRef = _firestore.collection('users').doc(giverId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) return;
      final currentRating = (snap['rating'] ?? 0).toDouble();
      final ratingCount = (snap['ratingCount'] ?? 0) as int;
      final newAverage = ((currentRating * ratingCount) + rating) / (ratingCount + 1);

      tx.update(userRef, {
        'rating': double.parse(newAverage.toStringAsFixed(2)),
        'ratingCount': ratingCount + 1,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⭐ ขอบคุณสำหรับการให้คะแนน!')),
    );
  }

  /// ✅ Popup ให้คะแนนผู้บริจาค
  Future<void> _showReviewDialog(String giverId, String confirmationId) async {
    double rating = 3;
    final commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('ให้คะแนนผู้บริจาค', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ช่วยให้คะแนนความพึงพอใจของคุณหน่อยนะ 💗'),
              const SizedBox(height: 12),
              StatefulBuilder(builder: (context, setState) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: () => setState(() => rating = index + 1.0),
                      icon: Icon(
                        Icons.star,
                        color: index < rating ? Colors.amber : Colors.grey[300],
                        size: 32,
                      ),
                    );
                  }),
                );
              }),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'แสดงความคิดเห็น (ไม่บังคับ)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _submitReview(giverId, rating, commentController.text, confirmationId);
              },
              child: const Text('ส่งรีวิว'),
            ),
          ],
        );
      },
    );
  }

  /// ✅ Stream ดีลทั้งหมดที่เกี่ยวข้องกับผู้ใช้
  Stream<QuerySnapshot> _confirmationStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('confirmations')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// ✅ ฟังก์ชันอัปเดตสถานะดีล
  Future<void> _updateStatus({
    required String confirmationId,
    required String status,
    required String otherUserId,
    required String postType,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final confirmationRef = _firestore.collection('confirmations').doc(confirmationId);
    final doc = await confirmationRef.get();

    if (!doc.exists) return;
    final data = doc.data()!;
    final confirmedBy = List<String>.from(data['confirmedBy'] ?? []);

    // 🟢 หากสถานะคือ 'confirm'
    if (status == 'confirm') {
      if (!confirmedBy.contains(currentUser.uid)) {
        confirmedBy.add(currentUser.uid);
        await confirmationRef.update({
          'confirmedBy': confirmedBy,
          'status': 'waitingConfirm',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // ✅ เมื่อครบทั้งสองฝ่าย
      if (confirmedBy.length >= 2) {
        await confirmationRef.update({
          'status': 'completed',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final giverId = data['giverId'];
        final receiverId = data['receiverId'] ?? otherUserId;
        final postType = data['postType'] ?? 'donate';

        // 🩷 เพิ่มแต้มให้ผู้บริจาค (เฉพาะโพสต์บริจาค)
        if (postType == 'donate' && giverId != null && giverId.isNotEmpty) {
          await _addDonationPoint(giverId);
          await _showReviewDialog(giverId, confirmationId);
        }

        // 💬 แจ้งเตือนเมื่อดีลเสร็จสิ้น
        if (postType == 'donate') {
          // ✅ แจ้งทั้งสองฝ่าย
          await _firestore.collection('notifications').add({
            'toUserId': giverId,
            'fromUserId': receiverId,
            'type': 'deal_completed',
            'message': 'ผู้รับบริจาคยืนยันการรับพัสดุแล้ว 🎁\n'
                'การบริจาคเสร็จสิ้น ขอบคุณที่เป็นส่วนหนึ่งของการแบ่งปัน PunJai 💗',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          await _firestore.collection('notifications').add({
            'toUserId': receiverId,
            'fromUserId': giverId,
            'type': 'deal_completed',
            'message': 'คุณได้ยืนยันการรับพัสดุเรียบร้อยแล้ว 💝\n'
                'ขอบคุณที่ร่วมแบ่งปันกับ PunJai 🌷',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else if (postType == 'swap') {
          // 💙 สำหรับการแลกเปลี่ยน (ทั้งสองฝ่ายเท่ากัน)
          for (final uid in [giverId, receiverId]) {
            await _firestore.collection('notifications').add({
              'toUserId': uid,
              'fromUserId': uid == giverId ? receiverId : giverId,
              'type': 'deal_completed',
              'message': '🎉 การแลกเปลี่ยนของคุณสำเร็จแล้ว!\n'
                  'ขอบคุณที่ร่วมแบ่งปันและสร้างรอยยิ้มกับ PunJai 💙',
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 ดีลนี้สำเร็จเรียบร้อยแล้ว')),
        );
        return;
      }

    } else {
      // 🟡 owner ยอมรับ / ปฏิเสธ
      await confirmationRef.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('notifications').add({
        'toUserId': otherUserId,
        'type': 'confirmation_update',
        'message': status == 'accepted'
            ? (postType == 'donate'
                ? 'เจ้าของโพสต์ยอมรับคำขอของคุณแล้ว 💛'
                : postType == 'request'
                    ? 'คำขอบริจาคของคุณได้รับการตอบรับ 💗'
                    : 'คำขอแลกของคุณได้รับการตอบรับ 💙')
            : 'คำขอของคุณถูกปฏิเสธ ❌',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ ถ้าสถานะคือ waitingConfirm (แปลว่าผู้บริจาคเริ่มจัดส่งของ)
if (status == 'waitingConfirm') {
  try {
    // ดึง postId ของโพสต์จากเอกสาร confirmation
    final postId = data['postId'];
    final postTitle = data['postTitle'] ?? 'โพสต์ของคุณ';
    final sentQty = (data['sentQty'] ?? 1) as int; // จำนวนของที่จัดส่ง (แก้ตาม field ของชมพูได้เลย)
    final ownerId = data['ownerId'];

    final postRef = _firestore.collection('posts').doc(postId);

    // 🔹 ลดจำนวนลงใน Firestore
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(postRef);
      if (!snapshot.exists) return;
      final currentQty = (snapshot['quantity'] ?? 0) as int;
      final newQty = currentQty - sentQty;

      tx.update(postRef, {
        'quantity': newQty < 0 ? 0 : newQty,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // 🔹 ตรวจสอบถ้าจำนวนเหลือ 0 ให้สร้างแจ้งเตือนใหม่
    final updatedPost = await postRef.get();
    final updatedQty = (updatedPost['quantity'] ?? 0) as int;

    if (updatedQty <= 0) {
      await _firestore.collection('notifications').add({
        'toUserId': ownerId,
        'fromUserId': 'system',
        'postId': postId,
        'type': 'out_of_stock',
        'message': '🎉 โพสต์ "$postTitle" ของคุณบริจาคครบแล้ว!',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    debugPrint('📦 อัปเดตจำนวนของในโพสต์สำเร็จ');
  } catch (e) {
    debugPrint('❌ Error updating quantity: $e');
  }
}


      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'accepted'
            ? '✅ ยอมรับคำขอเรียบร้อย'
            : '❌ ปฏิเสธคำขอเรียบร้อย'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('คำขอและดีลของฉัน'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFFDFBFB),
      body: StreamBuilder<QuerySnapshot>(
        stream: _confirmationStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('ยังไม่มีคำขอหรือดีลในตอนนี้ 🕊️',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          final confirmations = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: confirmations.length,
            itemBuilder: (context, index) {
              final data = confirmations[index].data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';
              final type = data['postType'] ?? 'donate';
              final color = colorMap[type] ?? Colors.white;
              final confirmationId = confirmations[index].id;

              final currentUserId = _auth.currentUser?.uid ?? '';
              final participants = List<String>.from(data['participants'] ?? []);
              final otherUserId =
                  participants.firstWhere((id) => id != currentUserId, orElse: () => '');

              final confirmedBy = List<String>.from(data['confirmedBy'] ?? const []);
              final hasConfirmed = confirmedBy.contains(currentUserId);

              return Container(
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
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  title: Text(
                    type == 'donate'
                        ? 'คำขอรับสิ่งของ 💛'
                        : type == 'request'
                            ? 'คำขอบริจาค 💗'
                            : 'คำขอแลกเปลี่ยน 💙',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    'สถานะ: $status\nอีกฝ่าย: ${otherUserId.isEmpty ? 'ไม่ทราบ' : otherUserId}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  trailing: _buildActionButtons(
                    status,
                    confirmationId,
                    otherUserId,
                    type,
                    hasConfirmed,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 🔹 ปุ่มที่แสดงตามสถานะ
  Widget _buildActionButtons(String status, String confirmationId,
      String otherUserId, String postType, bool hasConfirmed) {
    switch (status) {
      case 'pending':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _updateStatus(
                confirmationId: confirmationId,
                status: 'accepted',
                otherUserId: otherUserId,
                postType: postType,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _updateStatus(
                confirmationId: confirmationId,
                status: 'rejected',
                otherUserId: otherUserId,
                postType: postType,
              ),
            ),
          ],
        );

      case 'accepted':
        return ElevatedButton.icon(
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('ของกำลังจัดส่ง'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent.shade100,
              foregroundColor: Colors.black),
          onPressed: () => _updateStatus(
            confirmationId: confirmationId,
            status: 'waitingConfirm',
            otherUserId: otherUserId,
            postType: postType,
          ),
        );

      case 'waitingConfirm':
        return hasConfirmed
            ? const Icon(Icons.check, color: Colors.grey)
            : ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('ยืนยันดีลสำเร็จ'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade300,
                    foregroundColor: Colors.white),
                onPressed: () => _updateStatus(
                  confirmationId: confirmationId,
                  status: 'confirm',
                  otherUserId: otherUserId,
                  postType: postType,
                ),
              );

      case 'completed':
        return const Icon(Icons.verified, color: Colors.green, size: 28);

      default:
        return const SizedBox();
    }
  }
}
