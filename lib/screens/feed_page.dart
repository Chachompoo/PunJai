import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:punjai_app/screens/post_detail_page.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:punjai_app/screens/profile_screen.dart';

class SilentVideoPreview extends StatefulWidget {
  final String url;
  const SilentVideoPreview({super.key, required this.url});

  @override
  State<SilentVideoPreview> createState() => _SilentVideoPreviewState();
}

class _SilentVideoPreviewState extends State<SilentVideoPreview> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setVolume(0) // 🔇 ปิดเสียงเสมอ
      ..setLooping(true)
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.play(); // ▶️ เล่นอัตโนมัติ
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});
  static const routeName = '/feed';
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  String selectedFilter = 'all';
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final colorMap = {
    'donate': const Color(0xFFFFF7CC),
    'request': const Color(0xFFFFD6E8),
    'swap': const Color(0xFFD6F0FF),
  };

  /// ดึงโพสต์ของเฉพาะคนที่เราติดตาม
  Stream<QuerySnapshot> _postStream() {
  final currentUser = _auth.currentUser;
  if (currentUser == null) return const Stream.empty();

  final userRef = _firestore.collection('users').doc(currentUser.uid);

  return userRef.snapshots().asyncExpand((userSnap) {
    if (!userSnap.exists) return const Stream.empty();
    final data = userSnap.data() as Map<String, dynamic>;

    // ✅ ใช้ชื่อ field ให้ตรงกับ Firestore
    final following = List<String>.from(data['followingList'] ?? []);
    // ✅ รวมโพสต์ของตัวเองด้วย
    final visibleUsers = [...following, currentUser.uid];

    Query query = _firestore.collection('posts');

    if (visibleUsers.isNotEmpty) {
      query = query.where('ownerId', whereIn: visibleUsers);
    } else {
      // ถ้ายังไม่ follow ใคร ให้เห็นแค่ของตัวเอง
      query = query.where('ownerId', isEqualTo: currentUser.uid);
    }

    if (selectedFilter != 'all') {
      query = query.where('type', isEqualTo: selectedFilter);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  });
}



  /// ✅ ฟังก์ชันเมื่อกดปุ่ม “ขอรับ / ขอแลก / ขอบริจาค”
  Future<void> _handleRequestAction(Map<String, dynamic> post) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final postId = post['postId'];
    final ownerId = post['ownerId'];
    final postType = post['type'];

    // 🔹 ตรวจสอบว่ามีคำขอซ้ำไหม
    final existing = await _firestore
        .collection('confirmations')
        .where('postId', isEqualTo: postId)
        .where('requesterId', isEqualTo: currentUser.uid)
        .get();

    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณได้ส่งคำขอสำหรับโพสต์นี้แล้ว')),
      );
      return;
    }

    final confirmationId = const Uuid().v4();

    // 1️⃣ บันทึกคำขอใน collection confirmations
    await _firestore.collection('confirmations').doc(confirmationId).set({
      'confirmationId': confirmationId,
      'postId': postId,
      'ownerId': ownerId,
      'requesterId': currentUser.uid,
      'status': 'pending',
      'type': postType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2️⃣ ส่งการแจ้งเตือนให้เจ้าของโพสต์
    await _firestore.collection('notifications').add({
      'toUserId': ownerId,
      'fromUserId': currentUser.uid,
      'postId': postId,
      'type': 'request_$postType',
      'message': postType == 'donate'
          ? 'มีคนขอรับสิ่งของของคุณ 💛'
          : postType == 'request'
              ? 'มีคนเสนอของบริจาคให้คุณ 💗'
              : 'มีคนขอแลกสิ่งของกับคุณ 💙',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3️⃣ แจ้งเตือน popup
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          postType == 'donate'
              ? 'ส่งคำขอรับบริจาคเรียบร้อย 💛'
              : postType == 'request'
                  ? 'ส่งคำขอบริจาคสำเร็จ 💗'
                  : 'ส่งคำขอแลกสิ่งของสำเร็จ 💙',
        ),
        backgroundColor: Colors.black87,
      ),
    );
  }

  /// 🔍 ตรวจสอบว่าผู้ใช้เคยกดขอแล้วไหม
  Future<bool> _isRequested(String postId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final result = await _firestore
        .collection('confirmations')
        .where('postId', isEqualTo: postId)
        .where('requesterId', isEqualTo: currentUser.uid)
        .limit(1)
        .get();

    return result.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBFB),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // 🔹 แถบ Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  _buildFilterChip('all', 'ทั้งหมด', Colors.grey[300]!),
                  _buildFilterChip('donate', 'บริจาค', const Color(0xFFFFF7CC)),
                  _buildFilterChip('request', 'ขอรับ', const Color(0xFFFFD6E8)),
                  _buildFilterChip('swap', 'แลกเปลี่ยน', const Color(0xFFD6F0FF)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 🔸 รายการโพสต์
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                key: ValueKey(selectedFilter),
                stream: _postStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'ยังไม่มีโพสต์ในตอนนี้ 🕊️',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  final posts = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
  final data = posts[index].data() as Map<String, dynamic>;
  final type = data['type'] ?? 'donate';
  final color = colorMap[type] ?? Colors.white;
  final postId = data['postId'];
  final ownerId = data['ownerId'];
  final images = data['images'] ?? [];
  final videos = data['videos'] ?? [];

  // 🕓 แปลงเวลาโพสต์
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
    return '${date.day}/${date.month}/${date.year}';
  }

  return FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance.collection('users').doc(ownerId).get(),
    builder: (context, userSnap) {
      final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
      final firstname = userData['firstname'] ?? '';
      final lastname = userData['lastname'] ?? '';
      final fullname =
          (firstname + ' ' + lastname).trim().isNotEmpty ? '$firstname $lastname' : 'ผู้ใช้ไม่ระบุชื่อ';
      final profileImage = userData['profileImage'] ??
          'https://cdn-icons-png.flaticon.com/512/149/149071.png';
      final timeText = _formatTime(data['createdAt']);

      return FutureBuilder<bool>(
        future: _isRequested(postId),
        builder: (context, requestSnapshot) {
          final alreadyRequested = requestSnapshot.data ?? false;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetailPage(postData: data),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: color.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔹 แสดงชื่อ + เวลาโพสต์ (กดได้)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProfileScreen(uid: ownerId),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              radius: 18,
                              backgroundImage: NetworkImage(profileImage),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProfileScreen(uid: ownerId),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullname,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    timeText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 🔹 แสดงรูปก่อน ถ้าไม่มีค่อยใช้วิดีโอ
                    AspectRatio(
                      aspectRatio: 4 / 5,
                      child: Builder(
                        builder: (context) {
                          if (images.isNotEmpty) {
                            return Image.network(
                              images.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image,
                                size: 50,
                              ),
                            );
                          } else if (videos.isNotEmpty) {
                            return SilentVideoPreview(url: videos.first);
                          } else {
                            return const Icon(Icons.image_not_supported,
                                size: 50);
                          }
                        },
                      ),
                    ),

                    // 🔹 เนื้อหาโพสต์
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'] ?? 'ไม่มีชื่อโพสต์',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['description'] ?? 'ไม่มีรายละเอียด',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ownerId == _auth.currentUser?.uid
                                ? const SizedBox.shrink() // ✅ ถ้าเป็นเจ้าของโพสต์ — ซ่อนปุ่มไปเลย
                                : ElevatedButton(
                                    onPressed: alreadyRequested
                                        ? null
                                        : () => _handleRequestAction(data),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: alreadyRequested
                                          ? Colors.grey
                                          : Colors.black87,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: Text(
                                      alreadyRequested
                                          ? 'รอการตอบรับ ⏳'
                                          : type == 'donate'
                                              ? 'ขอรับสิ่งนี้'
                                              : type == 'request'
                                                  ? 'ขอบริจาค'
                                                  : 'ขอแลก',
                                    ),
                                  ),
                          ),

                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
      ),
    );
  }

  /// 🔘 Filter chips
  Widget _buildFilterChip(String value, String label, Color color) {
    final bool isSelected = selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.black87 : Colors.black54,
          fontWeight: FontWeight.bold,
        ),
        selected: isSelected,
        onSelected: (selected) => setState(() => selectedFilter = value),
        backgroundColor: color.withOpacity(0.4),
        selectedColor: color,
        elevation: 2,
      ),
    );
  }
}
