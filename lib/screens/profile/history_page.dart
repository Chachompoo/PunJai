import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
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
                  onPressed: () {}, // TODO: ไปหน้าแชท
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF8FB1),
                    side: const BorderSide(color: Color(0xFFFF8FB1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.star_outline),
                  label: const Text("รีวิว"),
                  onPressed: () {}, // TODO: เปิด Review Dialog
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8FB1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🧩 สร้างแท็กสถานะ
  Widget _statusTag(String status) {
    Color bg;
    String text;
    switch (status) {
      case 'completed':
        bg = Colors.green;
        text = "เสร็จสิ้น";
        break;
      case 'accepted':
      case 'shipping':
        bg = Colors.orange;
        text = "กำลังดำเนินการ";
        break;
      case 'rejected':
        bg = Colors.redAccent;
        text = "ถูกปฏิเสธ";
        break;
      default:
        bg = Colors.grey;
        text = "รอดำเนินการ";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        style: TextStyle(color: bg, fontWeight: FontWeight.w600, fontSize: 12),
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

  

    
    // 🔹 รายการประวัติ (ใช้ Firestore จริง)
  Widget _buildHistoryList(String tabType) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text("กรุณาเข้าสู่ระบบก่อน 💗"));
    }

    print("🔍 currentUser.uid = ${currentUser.uid}");

    // ใช้ FutureBuilder แทน StreamBuilder เพื่อหลีกเลี่ยง stream ซ้ำ
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

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text("ยังไม่มีข้อมูล 💗", style: TextStyle(color: Colors.grey)),
          );
        }

        // รวมผลลัพธ์จากทั้งสอง query
        final allDocs = [
          ...snapshot.data![0].docs,
          ...snapshot.data![1].docs,
        ];

        // 🔹 ลบข้อมูลซ้ำ
        final uniqueDocs = allDocs.fold<Map<String, DocumentSnapshot>>({}, (map, doc) {
          final data = doc.data() as Map<String, dynamic>;
          final key = data['confirmationId'] ?? data['postId'];
          map[key] = doc;
          return map;
        }).values.toList();

        print("✅ [DEBUG] Firestore หลังลบซ้ำเหลือ ${uniqueDocs.length} รายการ");

        // 🩷 กรองตามแท็บ
        List<DocumentSnapshot> filteredDocs = uniqueDocs;
        if (tabType == "ongoing") {
          filteredDocs = uniqueDocs
              .where((d) {
                final s = (d.data() as Map<String, dynamic>)['status'];
                return ["pending", "accepted", "shipping"].contains(s);
              })
              .toList();
        } else if (tabType == "completed") {
          filteredDocs = uniqueDocs.where((d) {
            final s = ((d.data() as Map<String, dynamic>)['status'] ?? '').toString().toLowerCase();
            return s == "completed" || s == "done" || s == "success";
          }).toList();
        }
        // 🩷 กรองตามฟิลเตอร์
        if (filteredDocs.isEmpty) {
          return const Center(
            child: Text(
              "ยังไม่มีการดำเนินการในหมวดนี้ 💗",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        print("✅ [DEBUG] Firestore ได้ข้อมูลรวม ${filteredDocs.length} รายการ");
        for (var d in filteredDocs) {
          print("🩷 status found = ${(d.data() as Map<String, dynamic>)['status']}");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final confirmation =
                filteredDocs[index].data() as Map<String, dynamic>;
            final postId = confirmation['postId'];
            final otherUserId = (confirmation['ownerId'] == currentUser.uid)
                ? confirmation['requesterId']
                : confirmation['ownerId'];

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('posts').doc(postId).get(),
              builder: (context, postSnap) {
                if (postSnap.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }

                if (!postSnap.hasData || !postSnap.data!.exists) {
                  return const Text("ไม่พบโพสต์นี้ 😢");
                }

                final post = postSnap.data!.data() as Map<String, dynamic>;

                return FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('users').doc(otherUserId).get(),
                  builder: (context, userSnap) {
                    if (userSnap.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    if (!userSnap.hasData || !userSnap.data!.exists) {
                      return const SizedBox();
                    }

                    final user = userSnap.data!.data() as Map<String, dynamic>?;

                    final data = {
                      'type': confirmation['type'],
                      'status': confirmation['status'],
                      'otherUserName': user?['username'],
                      'timestamp': confirmation['createdAt']?.toDate().toString().substring(0, 16) ?? '',
                      'points': confirmation['pointsAwarded'] ?? 0,
                      'postTitle': post['title'] ?? 'ไม่ระบุชื่อโพสต์',
                      'postImage': (post['images'] != null &&
                              post['images'].isNotEmpty &&
                              post['images'][0].toString().startsWith('http'))
                          ? post['images'][0]
                          : null,
                      'userImg': user?['profileImage'],
                    };

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          FadeSlideRoute(
                            page: HistoryDetailPage(data: data),
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
