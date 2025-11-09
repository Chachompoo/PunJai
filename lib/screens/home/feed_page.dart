import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:punjai_app/screens/posts/post_detail_page.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:punjai_app/screens/profile/profile_screen.dart';

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
      ..setVolume(0)
      ..setLooping(true)
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.play();
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: VideoPlayer(_controller),
      ),
    );
  }
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});
  static const routeName = '/feed';

  @override
  State<FeedPage> createState() => _FeedPageState();
}

// ✅ ใส่ initState ที่นี่แทน
class _FeedPageState extends State<FeedPage> {
  String selectedFilter = 'all';
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkExpiredPosts(); // ✅ ตอนนี้ถูกที่แล้ว
  }

// ✅ เพิ่มตรงนี้
Future<void> _checkExpiredPosts() async {
  final now = DateTime.now();
  try {
    final postsSnapshot = await _firestore
        .collection('posts')
        .where('status', isEqualTo: 'active')
        .get();

    for (final doc in postsSnapshot.docs) {
      final data = doc.data();
      final expireAt = (data['expireAt'] as Timestamp?)?.toDate();
      final postId = doc.id;
      final ownerId = data['ownerId'];
      final title = data['title'] ?? 'โพสต์ของคุณ';

      if (expireAt == null) continue;

      final hoursLeft = expireAt.difference(now).inHours;

      // ✅ 1. ใกล้หมดอายุ (<24 ชม.)
      if (hoursLeft <= 24 && hoursLeft > 0) {
        final existing = await _firestore
            .collection('notifications')
            .where('postId', isEqualTo: postId)
            .where('type', isEqualTo: 'post_expiring')
            .get();

        if (existing.docs.isEmpty) {
          await _firestore.collection('notifications').add({
            'toUserId': ownerId,
            'fromUserId': 'system',
            'postId': postId,
            'type': 'post_expiring',
            'message':
                'โพสต์ของคุณ "$title" ใกล้หมดอายุแล้ว ⏰',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint('⏰ แจ้งเตือนโพสต์ใกล้หมดอายุ: $title');
        }
      }

      // ✅ 2. หมดอายุแล้วจริง
      if (expireAt != null && expireAt.isBefore(now)) {
      final postId = doc.id;
      final ownerId = data['ownerId'];
      final title = data['title'] ?? 'โพสต์ของคุณ';
      final quantity = (data['quantity'] ?? 0) as int;

      // 🚫 ข้ามโพสต์ที่บริจาคครบแล้ว (ของหมด)
      if (quantity <= 0) {
        debugPrint('⏩ ข้ามโพสต์ "$title" เพราะบริจาคครบแล้ว');
        continue;
      }

      // ✅ ถ้าไม่หมดของและถึงวันหมดอายุ → อัปเดตเป็น expired
      await _firestore.collection('posts').doc(postId).update({
        'status': 'expired',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('notifications').add({
        'toUserId': ownerId,
        'fromUserId': 'system',
        'postId': postId,
        'type': 'post_expired',
        'message':
            'โพสต์ของคุณ "$title" หมดอายุแล้วและถูกเก็บไว้ในหน้าเก็บโพสต์ 📦',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('📦 หมดอายุโพสต์: $title');
    }

    }
  } catch (e) {
    debugPrint('❌ Error checking expired posts: $e');
  }
}



  final colorMap = {
    'donate': const Color(0xFFFFF7CC),
    'request': const Color(0xFFFFD6E8),
    'swap': const Color(0xFFD6F0FF),
  };

  Stream<QuerySnapshot> _postStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    final userRef = _firestore.collection('users').doc(currentUser.uid);

    return userRef.snapshots().asyncExpand((userSnap) {
      if (!userSnap.exists) return const Stream.empty();
      final data = userSnap.data() as Map<String, dynamic>;
      final following = List<String>.from(data['followingList'] ?? []);
      final visibleUsers = [...following, currentUser.uid];

      Query query = _firestore.collection('posts');
      if (visibleUsers.isNotEmpty) {
        query = query.where('ownerId', whereIn: visibleUsers);
      } else {
        query = query.where('ownerId', isEqualTo: currentUser.uid);
      }
      if (selectedFilter != 'all') {
        query = query.where('type', isEqualTo: selectedFilter);
      }
      return query.orderBy('createdAt', descending: true).snapshots();
    });
  }

  Future<void> _handleRequestAction(Map<String, dynamic> post) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final postId = post['postId'];
    final ownerId = post['ownerId'];
    final postType = post['type'];

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

    await _firestore.collection('confirmations').doc(confirmationId).set({
      'confirmationId': confirmationId,
      'postId': postId,
      'ownerId': ownerId,
      'requesterId': currentUser.uid,
      'status': 'pending',
      'type': postType,
      'createdAt': FieldValue.serverTimestamp(),
    });

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
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // 🔹 Filter Chips
            SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip('all', 'ทั้งหมด', const Color(0xFFEAEAEA)),
                _buildFilterChip('donate', 'บริจาค 💛', const Color(0xFFFFF7A6)),
                _buildFilterChip('request', 'ขอรับ 💗', const Color(0xFFFFC7DE)),
                _buildFilterChip('swap', 'แลกเปลี่ยน 💙', const Color(0xFFB7E4FF)),
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
                          final fullname = (firstname + ' ' + lastname).trim().isNotEmpty
                              ? '$firstname $lastname'
                              : 'ผู้ใช้ไม่ระบุชื่อ';
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
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(bottom: 18),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        color.withOpacity(0.8),
                                        Colors.white.withOpacity(0.8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(2, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 🔹 Header (ชื่อ + เวลา)
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
                                                  radius: 20,
                                                  backgroundImage:
                                                      NetworkImage(profileImage),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
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
                                            ],
                                          ),
                                        ),

                                        // 🔹 รูป / วิดีโอ
                                        if (images.isNotEmpty || videos.isNotEmpty)
                                        AspectRatio(
                                          aspectRatio: 4 / 5,
                                          child: Builder(
                                            builder: (context) {
                                              if (images.isNotEmpty) {
                                                return Image.network(
                                                  images.first,
                                                  fit: BoxFit.cover,
                                                );
                                              } else if (videos.isNotEmpty) {
                                                return SilentVideoPreview(url: videos.first);
                                              } else {
                                                return const SizedBox.shrink(); // ไม่แสดงอะไรเลย
                                              }
                                            },
                                          ),
                                        ),


                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Builder(
                                            builder: (context) {
                                              // ✅ ต้องประกาศตัวแปรที่นี่ (นอก widget tree)
                                              final type = data['type'] ?? 'donate'; // เพิ่มบรรทัดนี้
                                              final quantity = (data['quantity'] ?? 0) as int;
                                              final isOutOfStock = (type == 'donate') && quantity <= 0;


                                              return Column(
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
                                                  const SizedBox(height: 12),

                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: ownerId == _auth.currentUser?.uid
                                                        ? const SizedBox.shrink()
                                                        : ElevatedButton(
                                                            onPressed: isOutOfStock || alreadyRequested
                                                                ? null
                                                                : () => _handleRequestAction(data),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: isOutOfStock
                                                                  ? Colors.grey.shade400
                                                                  : alreadyRequested
                                                                      ? Colors.grey
                                                                      : type == 'donate'
                                                                          ? const Color(0xFFFFD84D)
                                                                          : type == 'request'
                                                                              ? const Color(0xFFFF8FBF)
                                                                              : const Color(0xFF7EC8E3),
                                                              foregroundColor: Colors.white,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(30),
                                                              ),
                                                              padding: const EdgeInsets.symmetric(
                                                                  horizontal: 22, vertical: 10),
                                                            ),
                                                            child: Text(
                                                              isOutOfStock
                                                                  ? 'บริจาคครบแล้ว 💖'
                                                                  : alreadyRequested
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
                                              );
                                            },
                                          ),
                                         ),
                                      ]
                                  ),
                                ),
                                )
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

  Widget _buildFilterChip(String value, String label, Color baseColor) {
  final bool isSelected = selectedFilter == value;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? baseColor : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? baseColor.withOpacity(0.5)
                : Colors.grey.withOpacity(0.15),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isSelected ? Colors.transparent : Colors.grey.shade300,
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => selectedFilter = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(Icons.check_rounded,
                    size: 16, color: Colors.black.withOpacity(0.7)),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14.5,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
