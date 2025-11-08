import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimations = List.generate(
      3,
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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
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

    // 🌿 สเต็ปไทม์ไลน์
    final List<Map<String, dynamic>> timelineSteps = [
      {
        'label': 'รอเจ้าของตอบรับ',
        'active': status == 'pending' || status == 'accepted' || status == 'completed',
      },
      {
        'label': 'กำลังดำเนินการ',
        'active': status == 'accepted' || status == 'completed',
      },
      {
        'label': 'เสร็จสิ้น',
        'active': status == 'completed',
      },
    ];

    int currentStep = 0;
    if (status == 'accepted') currentStep = 1;
    if (status == 'completed') currentStep = 2;

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

                  // ปุ่มต่าง ๆ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline, size: 20),
                          label: const Text("แชท"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimary,
                            side: const BorderSide(color: kPrimary, width: 1.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("เปิดแชทได้เร็ว ๆ นี้ 💬")),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.star_border_rounded, size: 20),
                          label: const Text("รีวิว"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("เปิดรีวิวได้เร็ว ๆ นี้ ⭐")),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  // 🩷 ข้อความขอบคุณตอนเสร็จสิ้น
                  if (status == 'completed') ...[
                    const SizedBox(height: 28),
                    Center(
                      child: Column(
                        children: const [
                          Icon(Icons.favorite, color: kPrimary, size: 40),
                          SizedBox(height: 8),
                          Text(
                            "ขอบคุณที่ร่วมแบ่งปันสิ่งดี ๆ 💗",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: kText,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "คุณคือหนึ่งในแรงบันดาลใจของชุมชนปันใจ 🌷",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
