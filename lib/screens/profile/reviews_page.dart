import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReviewsPage extends StatefulWidget {
  final String userId;
  final String userName;
  const ReviewsPage({super.key, required this.userId, required this.userName});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static const kPrimary = Color(0xFFFF8FB1);
  static const kText = Color(0xFF393E46);

  // 🎯 ฟังก์ชันคำนวณและอัปเดต Trust Score เฉลี่ย
  Future<void> _updateUserRating(String userId) async {
    final reviewsSnap = await _firestore
        .collection('reviews')
        .where('reviewedUserId', isEqualTo: userId)
        .get();

    if (reviewsSnap.docs.isEmpty) return;

    final ratings =
        reviewsSnap.docs.map((e) => (e['rating'] ?? 0).toDouble()).toList();
    final total = ratings.fold(0.0, (a, b) => a + b);
    final avg = total / ratings.length;

    await _firestore.collection('users').doc(userId).update({
      'rating': double.parse(avg.toStringAsFixed(1)),
      'ratingCount': ratings.length,
      // ✅ เพิ่มอัปเดต trustScore ไปด้วย (ให้มีค่ากลางระหว่าง 0–100)
      'trustScore': (avg / 5 * 100).round(),
    });
  }

  @override
  void initState() {
    super.initState();
    _updateUserRating(widget.userId); // อัปเดตค่าเฉลี่ยทุกครั้งที่เข้า
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        title: Text(
          'รีวิวของ ${widget.userName}',
          style: const TextStyle(
            color: kText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        iconTheme: const IconThemeData(color: kText),
      ),

      // ✅ ส่วนหัวบนสุดแสดงคะแนนเฉลี่ย
      body: Column(
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('users').doc(widget.userId).get(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SizedBox(height: 80);
              }
              final user = snap.data!.data() as Map<String, dynamic>? ?? {};
              final rating = (user['rating'] ?? 0).toDouble();
              final count = (user['ratingCount'] ?? 0);
              final trustScore = (user['trustScore'] ?? 0);

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text("คะแนนความน่าเชื่อถือ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kText)),
                    const SizedBox(height: 6),
                    Text(
                      "$trustScore / 100",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating.round() ? Icons.star : Icons.star_border,
                          color: kPrimary,
                        ),
                      ),
                    ),
                    Text(
                      "เฉลี่ย ${rating.toStringAsFixed(1)} ดาว จากทั้งหมด $count รีวิว",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),

          // 🔻 รายการรีวิวทั้งหมด
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('reviews')
                  .where('reviewedUserId', isEqualTo: widget.userId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kPrimary),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("ยังไม่มีรีวิว 💬",
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                final reviews = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reviews.length,
                  itemBuilder: (context, i) {
                    final data = reviews[i].data() as Map<String, dynamic>;
                    final rating = (data['rating'] ?? 0).toDouble();
                    final comment = data['comment'] ?? '';
                    final createdAt =
                        (data['createdAt'] as Timestamp?)?.toDate();
                    final reviewerId = data['reviewerId'] ?? '';

                    return FutureBuilder<DocumentSnapshot>(
                      future:
                          _firestore.collection('users').doc(reviewerId).get(),
                      builder: (context, snap) {
                        final reviewer =
                            snap.data?.data() as Map<String, dynamic>? ?? {};
                        final name =
                            '${reviewer['firstname'] ?? ''} ${reviewer['lastname'] ?? ''}'
                                .trim();
                        final profileImage = reviewer['profileImage'] ??
                            'https://cdn-icons-png.flaticon.com/512/149/149071.png';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🧍‍♀️ ข้อมูลผู้รีวิว
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundImage:
                                        NetworkImage(profileImage),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      name.isNotEmpty ? name : 'ผู้ใช้ Punjai',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: kText,
                                      ),
                                    ),
                                  ),
                                  if (createdAt != null)
                                    Text(
                                      DateFormat('d MMM yyyy')
                                          .format(createdAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // ⭐ แสดงดาว
                              Row(
                                children: List.generate(
                                  5,
                                  (index) => Icon(
                                    index < rating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: kPrimary,
                                    size: 20,
                                  ),
                                ),
                              ),

                              if (comment.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  comment,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: kText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
