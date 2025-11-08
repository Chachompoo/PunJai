import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:punjai_app/screens/profile/profile_screen.dart';

class ChatRoomPage extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserImage;
  final String postId;
  final String ownerId;

  const ChatRoomPage({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
    required this.postId,
    required this.ownerId,
  });

  static const routeName = '/chatRoom';

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _msgController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool get isDonor => _auth.currentUser?.uid == widget.ownerId;

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  // =============================
  // 🩷 ฟังก์ชันส่งข้อความทั่วไป
  // =============================
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': _auth.currentUser!.uid,
      'text': text.trim(),
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('chats').doc(widget.chatId).update({
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _msgController.clear();
  }

  // =============================
  // 🩵 ฟังก์ชันส่งรูปภาพในแชท
  // =============================
  Future<void> _sendImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    final ref = FirebaseStorage.instance
        .ref('chat_media/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(File(picked.path));
    final url = await ref.getDownloadURL();

    await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': _auth.currentUser!.uid,
      'type': 'image',
      'mediaUrl': url,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ===================================================
  // 📦 ผู้บริจาคกดยืนยันการจัดส่ง (กรอกชื่อ / จำนวน / รูป)
  // ===================================================
  Future<void> _confirmDelivery(BuildContext context) async {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController qtyCtrl = TextEditingController();
    File? imageFile;
    final picker = ImagePicker();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> _pickImage() async {
              final picked = await picker.pickImage(source: ImageSource.gallery);
              if (picked != null) {
                imageFile = File(picked.path);
                setState(() {});
              }
            }

            return AlertDialog(
              title: const Text('📦 ยืนยันการจัดส่งสินค้า'),
              backgroundColor: const Color(0xFFFFF7FB),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อสิ่งของ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'จำนวนสิ่งของที่จัดส่ง',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.pinkAccent),
                          image: imageFile != null
                              ? DecorationImage(
                                  image: FileImage(imageFile!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imageFile == null
                            ? const Center(
                                child: Text('เลือกรูปหลักฐานการจัดส่ง 📸'),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("ยกเลิก"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8FB1),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty ||
                        qtyCtrl.text.isEmpty ||
                        imageFile == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบ 💗')),
                      );
                      return;
                    }

                    Navigator.pop(context);

                    // ✅ อัปโหลดรูปหลักฐาน
                    final ref = FirebaseStorage.instance
                        .ref('shipping_images')
                        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
                    await ref.putFile(imageFile!);
                    final imageUrl = await ref.getDownloadURL();

                    final quantity = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                    final userId = _auth.currentUser!.uid;

                    // ✅ อัปเดต Firestore
                    await _firestore.collection('confirmations').add({
                      'chatId': widget.chatId,
                      'postId': widget.postId,
                      'ownerId': widget.ownerId,
                      'requesterId': widget.otherUserId,
                      'status': 'shipping',
                      'shippingItems': [
                        {
                          'name': nameCtrl.text.trim(),
                          'quantity': quantity,
                        }
                      ],
                      'shippingImageUrl': imageUrl,
                      'ownerConfirm': true,
                      'requesterConfirm': false,
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    // ✅ อัปเดต stock
                    final postRef = _firestore.collection('posts').doc(widget.postId);
                    await _firestore.runTransaction((tx) async {
                      final postSnap = await tx.get(postRef);
                      if (postSnap.exists) {
                        final oldQty = postSnap['quantity'] ?? 0;
                        final newQty = (oldQty - quantity).clamp(0, oldQty);
                        tx.update(postRef, {'quantity': newQty});
                      }
                    });

                    // ✅ แจ้งเตือนผู้รับ
                    await _firestore.collection('notifications').add({
                      'toUserId': widget.otherUserId,
                      'fromUserId': userId,
                      'postId': widget.postId,
                      'type': 'shipping_started',
                      'message': 'ผู้บริจาคได้จัดส่งของให้คุณแล้ว 💛',
                      'isRead': false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    // ✅ เพิ่มการ์ดสถานะในแชท
                    await _firestore
                        .collection('chats')
                        .doc(widget.chatId)
                        .collection('messages')
                        .add({
                      'type': 'delivery_card',
                      'senderId': userId,
                      'itemName': nameCtrl.text.trim(),
                      'quantity': quantity,
                      'imageUrl': imageUrl,
                      'status': 'shipping',
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ส่งของเรียบร้อย 💗 รอผู้รับยืนยัน')),
                    );
                  },
                  child: const Text("ยืนยันจัดส่ง"),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // ===================================================
  // 🎁 ผู้รับกดยืนยันว่า "ได้รับสินค้าแล้ว"
  // ===================================================
  Future<void> _confirmReceived(BuildContext context) async {
    final userId = _auth.currentUser!.uid;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🎁 ยืนยันการได้รับสินค้า"),
        content: const Text("คุณได้รับสินค้าครบถ้วนแล้วใช่ไหม?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF91C7F2),
            ),
            child: const Text("ยืนยัน"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // ✅ อัปเดตสถานะ
    final query = await _firestore
        .collection('confirmations')
        .where('chatId', isEqualTo: widget.chatId)
        .where('status', isEqualTo: 'shipping')
        .get();

    if (query.docs.isNotEmpty) {
      final docId = query.docs.first.id;
      final data = query.docs.first.data();
      final quantity = (data['shippingItems']?[0]['quantity'] ?? 1) as int;

      await _firestore.collection('confirmations').doc(docId).update({
        'status': 'completed',
        'requesterConfirm': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // ✅ เพิ่มแต้มให้ผู้บริจาค
      await _updateDonationPointsIfCompleted();

      // ✅ แจ้งเตือนเจ้าของโพสต์
      await _firestore.collection('notifications').add({
        'toUserId': widget.ownerId,
        'fromUserId': userId,
        'postId': widget.postId,
        'type': 'deal_completed',
        'message': 'ผู้รับยืนยันการได้รับของแล้ว 🎉',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ เพิ่มข้อความในห้องแชท
      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'type': 'system',
        'text': '🎁 ผู้รับยืนยันการได้รับสินค้าเรียบร้อยแล้ว',
        'createdAt': FieldValue.serverTimestamp(),
      });


      // ✅ เปิด popup รีวิวผู้บริจาค
      _showReviewDialog(context, widget.ownerId);
    }
  }

  // ===================================================
  // ⭐️ Popup รีวิวให้คะแนนผู้บริจาค
  // ===================================================
  Future<void> _showReviewDialog(BuildContext context, String donorId) async {
  double rating = 5;
  final TextEditingController commentCtrl = TextEditingController();

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("ให้คะแนนผู้บริจาค"),
        backgroundColor: const Color(0xFFFFF7FB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("ช่วยให้คะแนนและเขียนความคิดเห็นของคุณ 💖"),
                const SizedBox(height: 12),

                // ⭐ Rating stars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        Icons.star,
                        color: index < rating ? Colors.amber : Colors.grey[300],
                      ),
                      onPressed: () => setState(() => rating = index + 1.0),
                    );
                  }),
                ),

                // 💬 Comment box
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'เขียนความคิดเห็นของคุณ...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ข้าม"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('reviews').add({
                'donorId': donorId,
                'reviewerId': _auth.currentUser!.uid,
                'rating': rating,
                'comment': commentCtrl.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });

              // ✅ คำนวณค่าเฉลี่ยใหม่
              final reviews = await _firestore
                  .collection('reviews')
                  .where('donorId', isEqualTo: donorId)
                  .get();

              double avg = reviews.docs
                      .map((d) => (d['rating'] ?? 0).toDouble())
                      .fold(0.0, (a, b) => a + b) /
                  reviews.docs.length;

              await _firestore.collection('users').doc(donorId).update({
                'rating': double.parse(avg.toStringAsFixed(1)),
                'ratingCount': reviews.docs.length,
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('💖 ขอบคุณสำหรับการรีวิว!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8FB1),
            ),
            child: const Text("ส่งรีวิว"),
          ),
        ],
      );
    },
  );
}


// ===================================================
// 🏆 ฟังก์ชันอัปเดตแต้มผู้บริจาค (เรียกหลังจากมีการยืนยันครบทั้งคู่)
// ===================================================
Future<void> _updateDonationPointsIfCompleted() async {
  try {
    final query = await _firestore
        .collection('confirmations')
        .where('chatId', isEqualTo: widget.chatId)
        .get();

    if (query.docs.isEmpty) return;
    final doc = query.docs.first;
    final data = doc.data();

    final ownerConfirm = data['ownerConfirm'] ?? false;
    final requesterConfirm = data['requesterConfirm'] ?? false;
    final ownerId = data['ownerId'];
    final postType = data['type'] ?? 'donate';
    final shippingItems = (data['shippingItems'] ?? []) as List<dynamic>;
    final itemCount = (shippingItems.isNotEmpty
        ? shippingItems[0]['quantity'] ?? 1
        : 1) as int;

    // ✅ ถ้าทั้งคู่กดยืนยันแล้ว + เป็นโพสต์บริจาคหรือขอรับ
    if (ownerConfirm && requesterConfirm &&
        (postType == 'donate' || postType == 'request')) {
      final userRef = _firestore.collection('users').doc(ownerId);
      await _firestore.runTransaction((txn) async {
        final snapshot = await txn.get(userRef);
        if (!snapshot.exists) return;
        final currentPoints = 
        ((snapshot.data()?['points'] ?? 0) as num).toInt();
        txn.update(userRef, {'points': currentPoints + itemCount});
      });

      // ✅ เพิ่มข้อความ system ในแชท
      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'type': 'system',
        'text': '🏆 ระบบได้เพิ่มแต้มให้ผู้บริจาค +$itemCount คะแนน',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ แจ้งเตือนผู้บริจาค
      await _firestore.collection('notifications').add({
        'toUserId': ownerId,
        'fromUserId': _auth.currentUser!.uid,
        'postId': widget.postId,
        'type': 'point_awarded',
        'message': 'คุณได้รับ +$itemCount แต้มจากการบริจาคครั้งล่าสุด 🎉',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Added $itemCount points to donor $ownerId');
    }
  } catch (e) {
    print('❌ Error updating donation points: $e');
  }
}


  // ===================================================
  // 📋 แสดงข้อความและการ์ดสถานะในแชท
  // ===================================================
  Widget _buildMessage(Map<String, dynamic> data) {
    final type = data['type'];
    final isMe = data['senderId'] == _auth.currentUser?.uid;

    if (type == 'delivery_card') {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: _buildDeliveryCard(data),
      );
    }

    if (type == 'image') {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(data['mediaUrl'], width: 180),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              isMe ? const Color(0xFFFFE0EE) : const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(data['text'] ?? ''),
      ),
    );
  }

  // ===================================================
  // 🧾 การ์ดสถานะการจัดส่ง
  // ===================================================
  Widget _buildDeliveryCard(Map<String, dynamic> data) {
    final itemName = data['itemName'] ?? 'ไม่ระบุ';
    final qty = data['quantity'] ?? 0;
    final imageUrl = data['imageUrl'] ?? '';
    final status = data['status'] ?? 'shipping';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.local_shipping_outlined,
                  color: Color(0xFFFF8FB1), size: 22),
              SizedBox(width: 6),
              Text("ผู้บริจาคได้จัดส่งของแล้ว",
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 10),
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child:
                  Image.network(imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 10),
          Text('สิ่งของ: $itemName',
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.black87)),
          Text('จำนวน: $qty ชิ้น',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.airport_shuttle_outlined,
                  color: Colors.orange, size: 18),
              const SizedBox(width: 5),
              Text(
                status == 'shipping'
                    ? 'สถานะ: กำลังจัดส่งสินค้า'
                    : 'สถานะ: รอผู้รับยืนยัน',
                style: const TextStyle(color: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================================================
  // 🧩 ส่วน build หลักของหน้าแชท
  // ===================================================
  @override
  Widget build(BuildContext context) {
    final chatRef = _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true);

                return Scaffold(
              backgroundColor: const Color(0xFFFFF7FB),
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 1,
                title: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(uid: widget.otherUserId),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(widget.otherUserImage),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.otherUserName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                iconTheme: const IconThemeData(color: Colors.black),
              ),


      body: Column(
        children: [
          // พื้นที่แสดงข้อความ
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final data = messages[i].data() as Map<String, dynamic>;
                    return _buildMessage(data);
                  },
                );
              },
            ),
          ),

          // แถบพิมพ์ + ปุ่ม action
          // 🔹 แถบพิมพ์ข้อความและปุ่มส่ง
Container(
  color: Colors.white,
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  child: Column(
    children: [
      Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo, color: Colors.pinkAccent),
            onPressed: _sendImage,
          ),
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: const InputDecoration(
                hintText: 'พิมพ์ข้อความ...',
                border: InputBorder.none,
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.pinkAccent),
            onPressed: () => _sendMessage(_msgController.text),
          ),
        ],
      ),
      const SizedBox(height: 8),

      // 🌸 ปุ่มจัดส่ง / รับแล้ว
      Row(
        children: [
          if (isDonor)
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('จัดส่งแล้ว'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8FB1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _confirmDelivery(context),
              ),
            )
          else
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('ได้รับแล้ว'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF91C7F2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _confirmReceived(context),
              ),
            ),
        ],
      ),
    ],
  ),
),
        ],
      ),
    );
  }
} 

