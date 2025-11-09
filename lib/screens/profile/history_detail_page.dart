import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';


class HistoryDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const HistoryDetailPage({super.key, required this.data});

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}



class _HistoryDetailPageState extends State<HistoryDetailPage>
  
    with TickerProviderStateMixin {
  static const kBg = Color(0xFFFFF7FB);
  static const kPrimary = Color(0xFFFF8FB1);
  static const kText = Color(0xFF393E46);
  static const kGreen = Color(0xFF92D56F);
  static const kOrange = Color(0xFFFFB84C);
  static const kGrey = Color(0xFFBDBDBD);

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late List<Animation<double>> _fadeAnimations;

  // 🔐 Firebase
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // ⭐ รีวิว/แต้ม
  bool _canReview = false;     // โชว์ปุ่มรีวิวได้ไหม (เฉพาะผู้รับ + completed + ยังไม่เคยรีวิว)
  bool _hasReviewed = false;   // เคยรีวิวแล้วหรือยัง (จาก confirmations.isReviewed)
  bool _isReceiver = false;    // ฉันคือผู้รับไหม (current.uid == requesterId)
  String? _targetUserId;       // user ที่จะถูกรีวิว (donate/request => ownerId, swap => อีกฝั่ง)
  String? _confirmationId;     // id ของดีลนี้ (จาก widget.data['confirmId'])


  @override
  void initState() {
    super.initState();

    int _countValidItems(dynamic raw) {
      try {
        final list = (raw as List?) ?? const [];
        // นับเฉพาะสตริงที่ไม่ว่าง
        return list.where((e) => (e is String) && e.trim().isNotEmpty).length;
      } catch (_) {
        return 0;
      }
    }

    Future<void> _handleReviewPermissionAndPoints() async {
  try {
    final current = _auth.currentUser;
    if (current == null) return;

    // id ดีลมาจาก data ของหน้าปัจจุบัน
    final confirmId = widget.data['confirmId'];
    if (confirmId == null || (confirmId is String && confirmId.isEmpty)) return;
    _confirmationId = confirmId;

    final snap = await _firestore.collection('confirmations').doc(confirmId).get();
    if (!snap.exists) return;
    final c = snap.data()!;

    // ====== อ่านฟิลด์ตามสกีมของชมพู ======
    final ownerId        = (c['ownerId']        ?? '') as String; // ผู้บริจาค
    final requesterId    = (c['requesterId']    ?? '') as String; // ผู้รับ
    final type           = (c['type']           ?? '') as String; // 'donate' | 'request' | 'swap'
    final status         = (c['status']         ?? '') as String; // 'pending'|'accepted'|'shipping'|'completed'
    final isReviewed     = (c['isReviewed']     ?? false) as bool;
    final pointsAwarded  = (c['pointsAwarded']  ?? 0) as num;     // กันแต้มซ้ำ (number)
    final shippingItems  = c['shippingItems'];                    // array of string

    final isRequester = current.uid == requesterId;
    final isOwner     = current.uid == ownerId;
    _isReceiver = isRequester;

    // ====== 1) ตัดสินใจสิทธิ์รีวิว ======
    bool canReview = false;
    String? target;

    if (status == 'completed') {
      if (type == 'donate' || type == 'request') {
        // ผู้รับรีวิวผู้บริจาคเท่านั้น
        if (isRequester) { canReview = true; target = ownerId; }
      } else if (type == 'swap') {
        // แลกเปลี่ยน: ทั้งสองฝ่ายรีวิวกันได้
        canReview = true;
        target = isRequester ? ownerId : requesterId;
      }
    }

    // ====== 2) ให้แต้มผู้บริจาค (เฉพาะ donate/request + completed + ยังไม่ได้ให้) ======
    // แต้ม = จำนวนชิ้นที่ส่ง = shippingItems.length (นับเฉพาะรายการที่ไม่ว่าง)
    if ((type == 'donate' || type == 'request') &&
        status == 'completed' &&
        pointsAwarded == 0) {
      final award = _countValidItems(shippingItems);
      if (award > 0) {
        // อัปเดตแต้มให้ owner
        await _firestore.collection('users').doc(ownerId).update({
          'points': FieldValue.increment(award),
        });
        // กันซ้ำด้วยการบันทึกยอดแต้มที่ให้แล้ว
        await _firestore.collection('confirmations').doc(confirmId).update({
          'pointsAwarded': award,
        });
        // แจ้งเตือนให้ผู้บริจาคทราบ
        await _firestore.collection('notifications').add({
          'type': 'points_awarded',
          'fromUserId': 'system',
          'toUserId': ownerId,
          'confirmationId': confirmId,
          'message': 'ได้รับ +$award คะแนนจากการบริจาค 💗',
          'isRead': false,
          'createdAt': Timestamp.now(),
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _canReview   = canReview && !isReviewed;
      _hasReviewed = isReviewed;
      _targetUserId = target;
    });
  } catch (e) {
    debugPrint('handleReviewPermissionAndPoints error: $e');
  }
}

  Future<void> _submitReview(String comment, double rating) async {
  try {
    final current = _auth.currentUser;
    if (current == null || _targetUserId == null || _confirmationId == null) return;

    // 1) บันทึกรีวิว
    await _firestore.collection('reviews').add({
      'reviewId': const Uuid().v4(),
      'reviewerId': current.uid,
      'reviewedUserId': _targetUserId,
      'dealId': _confirmationId,
      'comment': comment,
      'rating': rating,
      'createdAt': Timestamp.now(),
    });

    // 2) เซ็ต flag กันรีวิวซ้ำ
    await _firestore.collection('confirmations').doc(_confirmationId!).update({
      'isReviewed': true,
    });

    // 3) แจ้งเตือนผู้ถูกรีวิว
    await _firestore.collection('notifications').add({
      'type': 'review_received',
      'fromUserId': current.uid,
      'toUserId': _targetUserId,
      'confirmationId': _confirmationId,
      'message': '⭐ คุณได้รับรีวิวใหม่จาก ${current.displayName ?? "ผู้ใช้ PunJai"}!',
      'isRead': false,
      'createdAt': Timestamp.now(),
    });

    // 4) คำนวณคะแนนเฉลี่ย + trustScore แล้วอัปเดตที่ users
    final reviewsSnap = await _firestore
        .collection('reviews')
        .where('reviewedUserId', isEqualTo: _targetUserId)
        .get();

    if (reviewsSnap.docs.isNotEmpty) {
      double total = 0;
      for (final d in reviewsSnap.docs) {
        total += (d['rating'] ?? 0).toDouble();
      }
      final avg = total / reviewsSnap.docs.length;
      final count = reviewsSnap.docs.length;
      final trust = (avg * 20).clamp(0, 100); // สูตรที่ตกลงกัน

      await _firestore.collection('users').doc(_targetUserId).update({
        'rating': double.parse(avg.toStringAsFixed(2)),
        'ratingCount': count,
        'trustScore': trust,
      });

      await _firestore.collection('notifications').add({
        'type': 'trust_updated',
        'fromUserId': 'system',
        'toUserId': _targetUserId,
        'message': '⭐ คะแนนความน่าเชื่อถืออัปเดตเป็น ${avg.toStringAsFixed(1)} ดาว!',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
    }

    if (!mounted) return;
    setState(() {
      _canReview = false;
      _hasReviewed = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ส่งรีวิวเรียบร้อยแล้ว 💖')),
    );
  } catch (e) {
    debugPrint('submitReview error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งรีวิวไม่สำเร็จ ลองใหม่อีกครั้งนะคะ')),
      );
    }
  }
}



    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimations = List.generate(
      4,
      (i) => CurvedAnimation(
        parent: _fadeController,
        curve: Interval(i * 0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
      lowerBound: 0.85,
      upperBound: 1.15,
    )..repeat(reverse: true);

    _fadeController.forward();
    // ✅ โหลดสิทธิ์รีวิว + ให้แต้มถ้ายังไม่ให้
  _handleReviewPermissionAndPoints();

  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // =====================================================
// 🌸 ฟังก์ชันส่งรีวิวและอัปเดต Trust Score
// =====================================================
Future<void> _submitReview(String comment, double rating) async {
  try {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || _targetUserId == null || _confirmationId == null) return;

    final firestore = FirebaseFirestore.instance;

    // 1️⃣ บันทึกรีวิวใหม่
    await firestore.collection('reviews').add({
      'reviewId': const Uuid().v4(),
      'reviewerId': current.uid,
      'reviewedUserId': _targetUserId,
      'dealId': _confirmationId,
      'comment': comment,
      'rating': rating,
      'createdAt': Timestamp.now(),
    });

    // 2️⃣ ป้องกันการรีวิวซ้ำ
    await firestore.collection('confirmations').doc(_confirmationId!).update({
      'isReviewed': true,
    });

    // 3️⃣ แจ้งเตือนผู้ถูกรีวิว
    await firestore.collection('notifications').add({
      'type': 'review_received',
      'fromUserId': current.uid,
      'toUserId': _targetUserId,
      'confirmationId': _confirmationId,
      'message': '⭐ คุณได้รับรีวิวใหม่จาก ${current.displayName ?? "ผู้ใช้ PunJai"}!',
      'isRead': false,
      'createdAt': Timestamp.now(),
    });

    // 4️⃣ คำนวณค่าเฉลี่ยใหม่ของคะแนน
    final reviewsSnap = await firestore
        .collection('reviews')
        .where('reviewedUserId', isEqualTo: _targetUserId)
        .get();

    if (reviewsSnap.docs.isNotEmpty) {
      double total = 0;
      for (final d in reviewsSnap.docs) {
        total += (d['rating'] ?? 0).toDouble();
      }
      final avg = total / reviewsSnap.docs.length;
      final count = reviewsSnap.docs.length;
      final trust = (avg * 20).clamp(0, 100); // 5 ดาว = 100 คะแนน

      await firestore.collection('users').doc(_targetUserId).update({
        'rating': double.parse(avg.toStringAsFixed(2)),
        'ratingCount': count,
        'trustScore': trust,
      });

      // แจ้งเตือนการอัปเดต trust score
      await firestore.collection('notifications').add({
        'type': 'trust_updated',
        'fromUserId': 'system',
        'toUserId': _targetUserId,
        'message': '⭐ คะแนนความน่าเชื่อถืออัปเดตเป็น ${avg.toStringAsFixed(1)} ดาว!',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
    }

    if (!mounted) return;
    setState(() {
      _canReview = false;
      _hasReviewed = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ส่งรีวิวเรียบร้อยแล้ว 💖')),
    );
  } catch (e) {
    debugPrint('submitReview error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งรีวิวไม่สำเร็จ ลองใหม่อีกครั้งนะคะ')),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final postTitle = data['postTitle'] ?? 'ไม่ระบุชื่อโพสต์';
    final status = data['status'] ?? 'pending';
    final userName = data['otherUserName'] ?? 'ไม่ระบุ';
    final postImage = data['postImage'];
    final date = data['timestamp'] ?? '-';
    final type = data['type'] ?? 'donate';

    // 🎨 สีและข้อความสถานะ
    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'accepted':
      case 'in_progress':
      case 'shipping': // ✅ เพิ่มบรรทัดนี้
        statusColor = kOrange;
        statusLabel = 'กำลังดำเนินการ';
        break;

      case 'completed':
        statusColor = kGreen;
        statusLabel = 'เสร็จสิ้น';
        break;

      default:
        statusColor = kGrey;
        statusLabel = 'รอดำเนินการ';
    }


    /// 🌿 สเต็ปไทม์ไลน์ (แสดงตามสถานะจริง)
    final List<Map<String, dynamic>> timelineSteps = [
      {
        'label': 'รอเจ้าของตอบรับ',
        'active': ['pending', 'accepted', 'in_progress', 'shipping', 'completed'].contains(status),
      },
      {
        'label': 'กำลังดำเนินการ',
        'active': ['accepted', 'in_progress', 'shipping', 'completed'].contains(status),
      },
      {
        'label': 'จัดส่งพัสดุแล้ว',
        'active': ['shipping', 'completed'].contains(status),
      },
      {
        'label': 'เสร็จสิ้น',
        'active': status == 'completed',
      },
    ];

    // 🎀 หาขั้นตอนปัจจุบัน
    int currentStep = 0;
    if (['accepted', 'in_progress'].contains(status)) currentStep = 1;
    if (status == 'shipping') currentStep = 2;
    if (status == 'completed') currentStep = 3;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text(
          "รายละเอียดการดำเนินการ",
          style: TextStyle(
            color: kText,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: kText),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🌸 การ์ดหลัก
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // รูปภาพ
                  if (postImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.network(
                        postImage,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Center(child: Text("ไม่มีรูปภาพ")),
                    ),
                  const SizedBox(height: 16),

                  // ชื่อโพสต์ + สถานะ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          postTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: kText,
                          ),
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text("คู่ดีล: ",
                          style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      Text(
                        userName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text("ประเภท: ",
                          style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      Text(
                        type == "donate"
                            ? "บริจาค 💗"
                            : type == "request"
                                ? "ขอรับ 💛"
                                : "แลกเปลี่ยน 💙",
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text("วันที่: ",
                          style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      Text(
                        date,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  

                  // 🌿 Timeline Section
                  const Text(
                    "ขั้นตอนการดำเนินการ",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kText),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: List.generate(timelineSteps.length, (index) {
                      final step = timelineSteps[index];
                      final active = step['active'] as bool;
                      final isCurrent = index == currentStep;
                      final isLast = index == timelineSteps.length - 1;

                      return FadeTransition(
                        opacity: _fadeAnimations[index],
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    final pulseScale =
                                        (isCurrent) ? _pulseController.value : 1.0;
                                    final glow = (isLast && status == 'completed')
                                        ? [
                                            BoxShadow(
                                              color: Colors.greenAccent
                                                  .withOpacity(0.6),
                                              blurRadius: 12,
                                              spreadRadius: 3,
                                            )
                                          ]
                                        : null;

                                    return Transform.scale(
                                      scale: pulseScale,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: active
                                              ? (isCurrent
                                                  ? kPrimary
                                                  : kPrimary.withOpacity(0.6))
                                              : Colors.grey[300],
                                          shape: BoxShape.circle,
                                          boxShadow: glow,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2,
                                    height: 40,
                                    color: Colors.grey[300],
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                step['label'],
                                style: TextStyle(
                                  fontSize: 15,
                                  color: active ? kText : Colors.grey,
                                  fontWeight: active
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  
                  // ✅ ปุ่มเปลี่ยนสถานะดีล
            if ((status == 'accepted' || status == 'in_progress') && data['isOwner'] == true) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFFB84C), // ส้ม
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () async {
                    final firestore = FirebaseFirestore.instance;
                    final confirmId = data['confirmId'];
                    final postId = data['postId'];
                    final chatId = data['chatId'];
                    final requesterId = data['requesterId'];
                    final ownerId = data['ownerId'];
                    final postTitle = data['postTitle'] ?? "สิ่งของ";

                    final qtyController = TextEditingController();

                    // 🎁 popup ให้กรอกจำนวนที่ส่ง
                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("จำนวนของที่จัดส่ง"),
                        content: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: "เช่น 100",
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("ยกเลิก"),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final sentQty = int.tryParse(qtyController.text) ?? 0;
                              if (sentQty <= 0) return;

                              // ✅ 1. อัปเดตสถานะใน confirmations
                              await firestore.collection('confirmations').doc(confirmId).update({
                                'status': 'shipping',
                                'itemSent': sentQty,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              // ✅ 2. ลบจำนวนใน posts
                              await firestore.collection('posts').doc(postId).update({
                                'quantity': FieldValue.increment(-sentQty),
                              });

                              // ✅ 3. ส่งข้อความไปในแชท (ให้ผู้รับรู้)
                              await firestore
                                  .collection('chats')
                                  .doc(chatId)
                                  .collection('messages')
                                  .add({
                                'type': 'system',
                                'text': '📦 ผู้บริจาคได้จัดส่ง "$postTitle" จำนวน $sentQty ชิ้นแล้ว!',
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              // ✅ 4. สร้างการแจ้งเตือนให้ผู้รับ
                              await firestore.collection('notifications').add({
                                'toUserId': requesterId,
                                'fromUserId': ownerId,
                                'postId': postId,
                                'type': 'shipping_started',
                                'message': 'ผู้บริจาคได้จัดส่ง "$postTitle" จำนวน $sentQty ชิ้นแล้ว 💛',
                                'isRead': false,
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('📦 บันทึกการจัดส่งเรียบร้อย!')),
                              );
                            },
                            child: const Text("ยืนยัน"),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text("จัดส่งพัสดุแล้ว 📦"),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ],
        ),
      ),
                        // ✅ ปุ่มสำหรับประเภท "แลกเปลี่ยน (swap)"
            if (type == 'swap' && status == 'accepted') ...[
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFFB84C), // ส้ม
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () async {
                    final firestore = FirebaseFirestore.instance;
                    final confirmId = data['confirmId'];
                    final currentUserId = data['currentUserId']; // ผู้ใช้ปัจจุบัน
                    final ownerId = data['ownerId'];
                    final requesterId = data['requesterId'];

                    // ถ้าเราคือ owner → ownerConfirm = true
                    // ถ้าเราคือ requester → requesterConfirm = true
                    final updateField = currentUserId == ownerId
                        ? 'ownerConfirm'
                        : 'requesterConfirm';

                    await firestore.collection('confirmations').doc(confirmId).update({
                      updateField: true,
                      'status': 'shipping',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📦 บันทึกการจัดส่งเรียบร้อย!')),
                    );
                  },
                  child: const Text("จัดส่งพัสดุแล้ว 📦"),
                ),
              ),
              const SizedBox(width: 12),
            ],

            // ✅ ปุ่มสำหรับผู้รับ (Requester) เมื่อสถานะเป็น shipping
            if (status == 'shipping' && data['isRequester'] == true) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF92D56F), // เขียว
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () async {
                  final firestore = FirebaseFirestore.instance;
                  final confirmId = data['confirmId'];
                  final ownerId = data['ownerId'];
                  final requesterId = data['requesterId'];
                  final itemSent = data['itemSent'] ?? 0;

                  // ✅ 1. เปลี่ยนสถานะเป็น completed + บันทึกแต้มที่ได้รับ
                  await firestore.collection('confirmations').doc(confirmId).update({
                    'status': 'completed',
                    'pointsAwarded': itemSent, // 🌟 เพิ่มบรรทัดนี้
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  // ✅ 2. เพิ่มคะแนนให้ผู้บริจาค
                  if (itemSent > 0) {
                    await firestore.collection('users').doc(ownerId).update({
                      'points': FieldValue.increment(itemSent),
                    });

                    // ✅ 3. แจ้งเตือนว่าผู้บริจาคได้รับคะแนนแล้ว
                    await firestore.collection('notifications').add({
                      'toUserId': ownerId,
                      'fromUserId': requesterId,
                      'type': 'points_awarded',
                      'message': 'ได้รับ +$itemSent คะแนนจากการบริจาค 💗',
                      'isRead': false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ ยืนยันรับพัสดุเรียบร้อย!')),
                    );
                  },
                  child: const Text("ยืนยันรับพัสดุ ✅"),
                ),
              ),
              const SizedBox(height: 12),
            ],


            if (type == 'swap' && status == 'shipping') ...[
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF92D56F), // เขียว
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () async {
                    final firestore = FirebaseFirestore.instance;
                    final confirmId = data['confirmId'];
                    final currentUserId = data['currentUserId'];
                    final ownerId = data['ownerId'];
                    final requesterId = data['requesterId'];

                    final snapshot =
                        await firestore.collection('confirmations').doc(confirmId).get();
                    final confirmData = snapshot.data() ?? {};

                    final ownerConfirm = confirmData['ownerConfirm'] ?? false;
                    final requesterConfirm = confirmData['requesterConfirm'] ?? false;

                    final updateField = currentUserId == ownerId
                        ? 'ownerConfirm'
                        : 'requesterConfirm';

                    // กดยืนยันรับพัสดุ
                    await firestore.collection('confirmations').doc(confirmId).update({
                      updateField: true,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    // ถ้าทั้งสองฝั่งยืนยันครบ → เปลี่ยนเป็น completed
                    if ((updateField == 'ownerConfirm' && requesterConfirm == true) ||
                        (updateField == 'requesterConfirm' && ownerConfirm == true)) {
                      await firestore.collection('confirmations').doc(confirmId).update({
                        'status': 'completed',
                      });
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ ยืนยันรับพัสดุเรียบร้อย!')),
                    );
                  },
                  child: const Text("ยืนยันรับพัสดุ ✅"),
                ),
              ),
                            const SizedBox(width: 12),
            ],

            // 🌸 ปุ่มรีวิว (เพิ่มใหม่ — อยู่หลังปุ่มทั้งหมด)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.star_rate_rounded, color: Colors.white),
                label: Text(
                  (status == 'completed')
                      ? (_isReceiver
                          ? (_hasReviewed ? 'รีวิวแล้ว' : 'รีวิวผู้บริจาค 💗')
                          : 'รีวิวไม่ได้')
                      : 'ยังรีวิวไม่ได้ (ดีลยังไม่เสร็จ)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (status == 'completed')
                      ? (_isReceiver
                          ? (_hasReviewed
                              ? const Color(0xFFBDBDBD)
                              : const Color(0xFFFF8FB1))
                          : const Color(0xFFBDBDBD))
                      : const Color(0xFFBDBDBD),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                ),
                onPressed: (status != 'completed' || !_isReceiver || _hasReviewed)
                    ? null
                    : () {
                        double rating = 5;
                        final commentCtrl = TextEditingController();
                        showDialog(
                          context: context,
                          builder: (_) => StatefulBuilder(
                            builder: (context, setSt) {
                              return AlertDialog(
                                title: const Text('ให้คะแนนดีลนี้'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: commentCtrl,
                                      decoration: const InputDecoration(
                                        hintText:
                                            'เขียนความคิดเห็นถึงผู้บริจาค...',
                                      ),
                                      maxLines: 3,
                                    ),
                                    const SizedBox(height: 12),
                                    Slider(
                                      value: rating,
                                      min: 1,
                                      max: 5,
                                      divisions: 4,
                                      label: '${rating.round()} ดาว',
                                      onChanged: (v) => setSt(() => rating = v),
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
                                      await _submitReview(
                                          commentCtrl.text.trim(), rating);
                                      if (context.mounted)
                                        Navigator.pop(context);
                                    },
                                    child: const Text('ส่งรีวิว'),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

    