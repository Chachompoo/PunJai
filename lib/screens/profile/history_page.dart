import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import 'history_detail_page.dart';
import 'package:punjai_app/widgets/fade_slide_route.dart';



class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  static const routeName = '/history';

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? _filterType; // donate / request / swap / null = all
  String? _filterTime; // week / month / all
  late TabController _tabController;
  

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🩷 เปิด dialog สำหรับฟิลเตอร์
  void _openFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFF7FB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "กรองประวัติ",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF393E46),
                ),
              ),
              const SizedBox(height: 20),
              // 🔸 ประเภทโพสต์
              _buildFilterSection(
                title: "ประเภทโพสต์",
                children: [
                  _filterChip("บริจาค", "donate"),
                  _filterChip("ขอรับบริจาค", "request"),
                  _filterChip("แลกเปลี่ยน", "swap"),
                ],
              ),
              const SizedBox(height: 10),
              // ⏰ เวลา
              _buildFilterSection(
                title: "ช่วงเวลา",
                children: [
                  _filterChip("สัปดาห์นี้", "week", isTime: true),
                  _filterChip("เดือนนี้", "month", isTime: true),
                  _filterChip("ทั้งหมด", "all", isTime: true),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8FB1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text("ยืนยัน", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🔹 Helper: สร้างหัวข้อฟิลเตอร์
  Widget _buildFilterSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: children),
      ],
    );
  }

  // 🔹 Helper: ปุ่ม filter
  Widget _filterChip(String label, String value, {bool isTime = false}) {
    final isSelected =
        isTime ? _filterTime == value : _filterType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFFFC1CC),
      backgroundColor: Colors.grey[200],
      onSelected: (selected) {
        setState(() {
          if (isTime) {
            _filterTime = selected ? value : null;
          } else {
            _filterType = selected ? value : null;
          }
        });
      },
    );
  }
  
  Future<bool> _hasReviewed(String dealId) async {
  final currentUser = _auth.currentUser;
  if (currentUser == null) return false;

  final snap = await _firestore
      .collection('reviews')
      .where('dealId', isEqualTo: dealId)
      .where('reviewerId', isEqualTo: currentUser.uid)
      .limit(1)
      .get();

  return snap.docs.isNotEmpty;
}

  // 🩵 Card ของแต่ละดีล (structure)
  Widget _buildDealCard(Map<String, dynamic> data) {

    
    final type = data['type'] ?? 'donate';
    final status = data['status'] ?? 'pending';
    final otherUser = data['otherUserName'] ?? 'ไม่ระบุ';
    final date = data['timestamp'] ?? 'ไม่ทราบเวลา';
    final points = data['points'] ?? 0;

    print("🧩 post = ${data['postTitle']}, user = ${data['otherUserName']}, status = ${data['status']}");

    IconData icon;
    Color color;
    String typeLabel;


    switch (type) {
      case 'donate':
        icon = Icons.volunteer_activism_rounded;
        color = const Color(0xFFFFC1CC);
        typeLabel = "บริจาค";
        break;
      case 'request':
        icon = Icons.card_giftcard_rounded;
        color = const Color(0xFFFFD97D);
        typeLabel = "ขอรับบริจาค";
        break;
      case 'swap':
        icon = Icons.swap_horiz_rounded;
        color = const Color(0xFFB3E5FC);
        typeLabel = "แลกเปลี่ยน";
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        typeLabel = "ไม่ทราบ";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          // 🔸 Header
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.3),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Text(typeLabel,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              _statusTag(status),
            ],
          ),
          const Divider(height: 20, thickness: 0.8),
          // 🔹 Details
              if (data['postImage'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    data['postImage'],
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                data['postTitle'] ?? 'ไม่ระบุชื่อโพสต์',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Text("คู่ดีล: ${data['otherUserName']}",
                  style: const TextStyle(fontSize: 14, color: Colors.black87)),
              Text("วันที่: ${data['timestamp']}",
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
          if (type == 'donate' && status == 'completed')
            Text("คะแนนที่ได้รับ: +$points แต้ม",
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          // 🔸 Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text("แชท"),
                  onPressed: () async {
                    final currentUserId = _auth.currentUser!.uid;
                    final postId = data['postId']; // 🔸 เปลี่ยนให้ตรงกับตัวแปรของชมพู เช่น confirmation['postId']

                    final confirmSnap = await _firestore
                        .collection('confirmations')
                        .where('postId', isEqualTo: postId)
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

                      final userDoc =
                          await _firestore.collection('users').doc(otherUserId).get();
                      final userData = userDoc.data() ?? {};
                      final otherName =
                          '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.trim();
                      final otherImage = userData['profileImage'] ??
                          'https://cdn-icons-png.flaticon.com/512/149/149071.png';

                      if (!context.mounted) return;
                      Navigator.pushNamed(
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF8FB1),
                    side: const BorderSide(color: Color(0xFFFF8FB1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              // 🌷 ทั้งบล็อกนี้ด้านล่างมนจะไม่แตะเลย
              const SizedBox(width: 10),
              Expanded(
                child: FutureBuilder<bool>(
                  future: _hasReviewed(data['confirmId']),
                  builder: (context, snapshot) {
                    final alreadyReviewed = snapshot.data ?? false;
                    final canReview = status == 'completed' && !alreadyReviewed;

                    return ElevatedButton.icon(
                      icon: Icon(
                        alreadyReviewed ? Icons.star : Icons.star_outline,
                        color: Colors.white,
                      ),
                      label: Text(
                        alreadyReviewed ? "รีวิวแล้ว" : "รีวิว",
                      ),
                      onPressed: canReview
                          ? () => _openReviewDialog(data)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            alreadyReviewed ? Colors.grey : const Color(0xFFFF8FB1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
              ),

            ],
          ),

        ],
      ),
    );
  }

  Future<void> _openReviewDialog(Map<String, dynamic> deal) async {
  final currentUser = _auth.currentUser;
  if (currentUser == null) return;

  double rating = 5;
  final commentCtrl = TextEditingController();

  await showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setSt) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: const Color(0xFFFFF7FB),
          title: const Text("ให้คะแนนดีลนี้ 💖", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  hintText: 'เขียนความคิดเห็นถึงคู่ดีล...',
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
                activeColor: const Color(0xFFFF8FB1),
                onChanged: (v) => setSt(() => rating = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ยกเลิก"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8FB1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await _submitReview(deal, commentCtrl.text.trim(), rating);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("ส่งรีวิว"),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _submitReview(Map<String, dynamic> deal, String comment, double rating) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final firestore = FirebaseFirestore.instance;
    final reviewerId = currentUser.uid;
    final reviewedUserId = deal['otherUserId'];
    final confirmationId = deal['confirmId'];

    // 1️⃣ เพิ่มรีวิวใหม่
    await firestore.collection('reviews').add({
      'reviewId': const Uuid().v4(),
      'reviewerId': reviewerId,
      'reviewedUserId': reviewedUserId,
      'dealId': confirmationId,
      'comment': comment,
      'rating': rating,
      'createdAt': Timestamp.now(),
    });

    // 2️⃣ กันรีวิวซ้ำ
    await firestore.collection('confirmations').doc(confirmationId).update({
      'isReviewed': true,
    });

    // 3️⃣ แจ้งเตือนผู้ถูกรีวิว
    await firestore.collection('notifications').add({
      'type': 'review_received',
      'fromUserId': reviewerId,
      'toUserId': reviewedUserId,
      'confirmationId': confirmationId,
      'message': '⭐ คุณได้รับรีวิวใหม่จาก ${currentUser.displayName ?? "ผู้ใช้ PunJai"}!',
      'isRead': false,
      'createdAt': Timestamp.now(),
    });

    // 4️⃣ คำนวณคะแนนเฉลี่ยใหม่
    final reviewsSnap = await firestore
        .collection('reviews')
        .where('reviewedUserId', isEqualTo: reviewedUserId)
        .get();

    if (reviewsSnap.docs.isNotEmpty) {
      double total = 0;
      for (final d in reviewsSnap.docs) {
        total += (d['rating'] ?? 0).toDouble();
      }
      final avg = total / reviewsSnap.docs.length;
      final count = reviewsSnap.docs.length;
      final trust = (avg * 20).clamp(0, 100);

      await firestore.collection('users').doc(reviewedUserId).update({
        'rating': double.parse(avg.toStringAsFixed(2)),
        'ratingCount': count,
        'trustScore': trust,
      });

      await firestore.collection('notifications').add({
        'type': 'trust_updated',
        'fromUserId': 'system',
        'toUserId': reviewedUserId,
        'message': '⭐ คะแนนความน่าเชื่อถืออัปเดตเป็น ${avg.toStringAsFixed(1)} ดาว!',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ส่งรีวิวเรียบร้อยแล้ว 💖')),
    );
  } catch (e) {
    debugPrint('submitReview error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ส่งรีวิวไม่สำเร็จ: $e')),
    );
  }
}
Widget _statusTag(String status) {
  Color bg;
  String text;

  switch (status) {
    case 'accepted':
    case 'in_progress':
    case 'shipping':
      bg = Colors.orange;
      text = "กำลังดำเนินการ";
      break;

    case 'completed':
      bg = Colors.green;
      text = "เสร็จสิ้น";
      break;

    case 'rejected':
      bg = Colors.redAccent;
      text = "ถูกปฏิเสธ";
      break;

    case 'pending':
    default:
      bg = Colors.grey;
      text = "รอดำเนินการ";
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: bg,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        title: const Text(
          "ประวัติการดำเนินการ",
          style: TextStyle(
            color: Color(0xFF393E46),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: Colors.pinkAccent),
            onPressed: _openFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFFF8FB1),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFFFF8FB1),
            tabs: const [
              Tab(text: "ทั้งหมด"),
              Tab(text: "กำลังดำเนินการ"),
              Tab(text: "เสร็จสิ้น"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryList("all"),
                _buildHistoryList("ongoing"),
                _buildHistoryList("completed"),
              ],
            ),
          ),
        ],
      ),
    );
  }
 

    // ใช้ FutureBuilder แทน StreamBuilder เพื่อหลีกเลี่ยง stream ซ้ำ
    Widget _buildHistoryList(String tabType) {
  final currentUser = _auth.currentUser;
  if (currentUser == null) {
    return const Center(child: Text("กรุณาเข้าสู่ระบบก่อน 💗"));
  }

  // 🌸 Stream ทั้งฝั่ง owner และ requester
  final ownerStream = _firestore
      .collection('confirmations')
      .where('ownerId', isEqualTo: currentUser.uid)
      .snapshots();

  final requesterStream = _firestore
      .collection('confirmations')
      .where('requesterId', isEqualTo: currentUser.uid)
      .snapshots();

  // 🎀 รวม 2 stream เข้าด้วยกัน (ใช้ Rx.combineLatest2 ที่ชมพู import ไว้แล้ว)
  return FutureBuilder<List<QuerySnapshot>>(
  future: Future.wait([
    _firestore
        .collection('confirmations')
        .where('ownerId', isEqualTo: currentUser.uid)
        .get(),
    _firestore
        .collection('confirmations')
        .where('requesterId', isEqualTo: currentUser.uid)
        .get(),
  ]),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF8FB1)),
      );
    }

    if (!snapshot.hasData) {
      return const Center(
        child: Text("ยังไม่มีข้อมูล 💗", style: TextStyle(color: Colors.grey)),
      );
    }

    // รวมข้อมูล 2 ฝั่ง
    final allDocs = [...snapshot.data![0].docs, ...snapshot.data![1].docs];

    // 🔹 ลบข้อมูลซ้ำ
    final uniqueDocs = allDocs.fold<Map<String, DocumentSnapshot>>({}, (map, doc) {
      final data = doc.data() as Map<String, dynamic>;
      final key = data['confirmationId'] ?? data['postId'];
      map[key] = doc;
      return map;
    }).values.toList();

    // 🩷 กรองตามแท็บ
    List<DocumentSnapshot> filteredDocs = uniqueDocs;
    if (tabType == "ongoing") {
      filteredDocs = uniqueDocs.where((d) {
        final s = ((d.data() as Map<String, dynamic>)['status'] ?? '')
            .toString()
            .toLowerCase();
        return ["accepted", "in_progress", "shipping"].contains(s);
      }).toList();
    } else if (tabType == "completed") {
      filteredDocs = uniqueDocs.where((d) {
        final s = ((d.data() as Map<String, dynamic>)['status'] ?? '')
            .toString()
            .toLowerCase();
        return ["completed", "done", "success"].contains(s);
      }).toList();
    }

    if (filteredDocs.isEmpty) {
      return const Center(
        child: Text(
          "ยังไม่มีการดำเนินการในหมวดนี้ 💗",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // 🔄 แสดงรายการดีลแบบเดิม
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredDocs.length,
      itemBuilder: (context, index) {
        final confirmation = filteredDocs[index].data() as Map<String, dynamic>;
        final postId = confirmation['postId'];
        final otherUserId = (confirmation['ownerId'] == currentUser.uid)
            ? confirmation['requesterId']
            : confirmation['ownerId'];

        return FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('posts').doc(postId).get(),
          builder: (context, postSnap) {
            if (!postSnap.hasData || !postSnap.data!.exists) {
              return const SizedBox.shrink();
            }

            final post = postSnap.data!.data() as Map<String, dynamic>;

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(otherUserId).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData || !userSnap.data!.exists) {
                  return const SizedBox();
                }

                final user = userSnap.data!.data() as Map<String, dynamic>?;

                final fullName =
                    '${user?['firstname'] ?? ''} ${user?['lastname'] ?? ''}'.trim();
                final displayName = fullName.isNotEmpty
                    ? fullName
                    : user?['username'] ?? 'ไม่ระบุ';

                final data = {
                  'type': confirmation['type'],
                  'status': confirmation['status'],
                  'otherUserName': displayName,
                  'timestamp': confirmation['createdAt']
                          ?.toDate()
                          .toString()
                          .substring(0, 16) ??
                      '',
                  'points': confirmation['pointsAwarded'] ?? 0,
                  'postTitle': post['title'] ?? 'ไม่ระบุชื่อโพสต์',
                  'postImage': (post['images'] != null &&
                          post['images'].isNotEmpty &&
                          post['images'][0].toString().startsWith('http'))
                      ? post['images'][0]
                      : null,
                  'userImg': user?['profileImage'],
                  'otherUserId': otherUserId,
                  'confirmId':
                      confirmation['confirmationId'] ?? filteredDocs[index].id,
                };

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistoryDetailPage(
                          data: {
                            ...confirmation,
                            'confirmId': filteredDocs[index].id,
                            'isOwner': confirmation['ownerId'] ==
                                FirebaseAuth.instance.currentUser!.uid,
                            'isRequester': confirmation['requesterId'] ==
                                FirebaseAuth.instance.currentUser!.uid,
                            'postTitle': post['title'] ?? 'ไม่ระบุชื่อโพสต์',
                            'postImage': (post['images'] != null &&
                                    post['images'].isNotEmpty &&
                                    post['images'][0]
                                        .toString()
                                        .startsWith('http'))
                                ? post['images'][0]
                                : null,
                            'otherUserName': displayName,
                            'timestamp': confirmation['createdAt']
                                    ?.toDate()
                                    .toString()
                                    .substring(0, 16) ??
                                '-',
                            'type': confirmation['type'] ?? 'donate',
                          },
                        ),
                      ),
                    );
                  },
                  child: _buildDealCard(data),
                );
              },
            );
          },
        );
      },
    );
  },
);
}
}

