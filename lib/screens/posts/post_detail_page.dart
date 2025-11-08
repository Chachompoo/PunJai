import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:punjai_app/screens/posts/edit_post_page.dart';
import 'package:intl/intl.dart';
import 'package:punjai_app/screens/profile/profile_screen.dart';

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> postData;
  const PostDetailPage({super.key, required this.postData});

  static const routeName = '/postDetail';

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  Map<String, dynamic>? _ownerData;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  int _currentPage = 0;
  late final PageController _pageController;

  // =====================================================
  // 🧩 Utilities
  // =====================================================
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: Colors.black45, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF3A3A3A),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF4E4E4E)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'donate':
        return 'บริจาค 💛';
      case 'request':
        return 'ขอรับ 💗';
      case 'swap':
        return 'แลกเปลี่ยน 💙';
      default:
        return '-';
    }
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    final dt = (ts is Timestamp) ? ts.toDate() : DateTime.now();
    return DateFormat('d MMM yyyy, HH:mm').format(dt);
  }

  // =====================================================
  // ⚙️ Lifecycle
  // =====================================================
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_handlePageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initVideoIfAvailable();
      _fetchOwnerData();

    });
  }

  @override
  void dispose() {
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
    }
    _pageController.removeListener(_handlePageScroll);
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // =====================================================
  // 🧠 Video Control
  // =====================================================
  Future<void> _initVideoIfAvailable() async {
    try {
      final videos = widget.postData['videos'] ?? [];
      if (videos.isNotEmpty) {
        _videoController =
            VideoPlayerController.networkUrl(Uri.parse(videos.first));
        await _videoController?.initialize();
        _videoController?.setVolume(1.0);
        _videoController?.setLooping(true);
        
        setState(() => _isVideoInitialized = true);
      }
    } catch (e) {
      debugPrint('❌ Video load error: $e');
    }
  }

  void _handlePageScroll() {
    if (!_isVideoInitialized || _videoController == null) return;
    final currentIndex = _pageController.page?.round() ?? 0;
    final images = widget.postData['images'] ?? [];
    final videos = widget.postData['videos'] ?? [];
    final videoIndex = images.length;

    if (videos.isNotEmpty) {
      if (currentIndex == videoIndex) {
        _videoController!.play();
      } else {
        _videoController!.pause();
      }
    }
  }

  Future<void> _fetchOwnerData() async {
  try {
    final ownerId = widget.postData['ownerId'];
    if (ownerId == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
    if (doc.exists) {
      setState(() {
        _ownerData = doc.data();
      });
    }
  } catch (e) {
    debugPrint('❌ Error fetching owner data: $e');
  }
}


  // =====================================================
  // 📨 Send Request
  // =====================================================
  Future<void> _sendRequest(BuildContext context) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนทำรายการ 💗')),
        );
        return;
      }

      final postId = widget.postData['postId'];
      final postOwnerId = widget.postData['ownerId'];
      final requesterId = currentUser.uid;
      final type = widget.postData['type'] ?? 'donate';
      final timestamp = Timestamp.now();

      final requestRef =
          await FirebaseFirestore.instance.collection('requests').add({
        'postId': postId,
        'postOwnerId': postOwnerId,
        'requesterId': requesterId,
        'status': 'pending',
        'createdAt': timestamp,
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'fromUserId': requesterId,
        'toUserId': postOwnerId,
        'postId': postId,
        'notificationId': requestRef.id,
        'message': type == 'donate'
            ? 'มีคนขอรับสิ่งของของคุณ 💛'
            : type == 'request'
                ? 'มีคนเสนอของบริจาคให้คุณ 💗'
                : 'มีคนอยากแลกของกับคุณ 💙',
        'type': 'request',
        'isRead': false,
        'createdAt': timestamp,
      });

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('ส่งคำขอเรียบร้อย 💌'),
          content: const Text('คำขอของคุณถูกส่งไปยังเจ้าของโพสต์แล้ว'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ตกลง'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  // =====================================================
  // 🎨 UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final data = widget.postData;
    final type = data['type'] ?? 'donate';
    final images = data['images'] ?? [];
    final videos = data['videos'] ?? [];
    final mediaCount = images.length + (videos.isNotEmpty ? 1 : 0);

    final accentColor = type == 'donate'
        ? const Color(0xFFFFC83C)
        : type == 'request'
            ? const Color(0xFFFF8FB1)
            : const Color(0xFF8CC7FF);

    return Scaffold(
  backgroundColor: const Color(0xFFFFF7FB),
  appBar: AppBar(
    backgroundColor: Colors.white, // ✅ เพิ่มพื้นหลัง AppBar สีขาว
    elevation: 1.5, // ✅ เพิ่มเงาเบา ๆ ให้ดูแยกจากรูป
    foregroundColor: Colors.black87,
    centerTitle: true,
    title: const Text(
      'รายละเอียดโพสต์',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFF393E46),
      ),
    ),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new),
      onPressed: () async {
        if (_videoController != null && _videoController!.value.isPlaying) {
          await _videoController!.pause();
        }
        Navigator.pop(context);
      },
    ),
  ),

  body: SafeArea( // ✅ ป้องกันปุ่มล่างโดนแท็บมือถือกิน
    child: SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🌸 ส่วนรูปภาพ (พร้อม fade gradient)
          // 🌸 ส่วนรูปภาพและวิดีโอ (รองรับแนวตั้ง + indicator)
          if (mediaCount > 0)
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // ✅ รองรับแนวตั้ง-แนวนอน
                Container(
                  height: 280,
                  width: double.infinity,
                  color: Colors.grey[100],
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: mediaCount,
                    itemBuilder: (context, index) {
                      // 🖼️ แสดงรูป
                      if (index < images.length) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.05),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                          child: Center(
                            child: Image.network(
                              images[index],
                              fit: BoxFit.contain, // ✅ รองรับภาพแนวตั้ง
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        );
                      }

                      // 🎥 แสดงวิดีโอ (อยู่ลำดับสุดท้าย)
                      if (videos.isNotEmpty && index == images.length) {
                        return _isVideoInitialized
                            ? GestureDetector(
                                onTap: () {
                                  if (_videoController!.value.isPlaying) {
                                    _videoController!.pause();
                                  } else {
                                    _videoController!.play();
                                  }
                                  setState(() {});
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AspectRatio(
                                      aspectRatio:
                                          _videoController!.value.aspectRatio,
                                      child: VideoPlayer(_videoController!),
                                    ),
                                    if (!_videoController!.value.isPlaying)
                                      Container(
                                        color: Colors.black26,
                                        child: const Icon(
                                          Icons.play_circle_fill_rounded,
                                          size: 90,
                                          color: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : const Center(child: CircularProgressIndicator());
                      }

                      return const SizedBox();
                    },
                  ),
                ),

          

                // 🟣 วงกลมบอกตำแหน่งภาพแบบ Instagram
                if (mediaCount > 1)
                  Positioned(
                    bottom: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        mediaCount,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 10 : 6,
                          height: _currentPage == index ? 10 : 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? accentColor.withOpacity(0.9)
                                : Colors.grey.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),


          // 👤 ข้อมูลเจ้าของโพสต์
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  child: Row(
    children: [
      GestureDetector(
        onTap: () {
          final ownerId = widget.postData['ownerId'];
          if (ownerId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(uid: ownerId),
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: _ownerData != null && _ownerData!['profileImage'] != null
                ? Image.network(
                    _ownerData!['profileImage'],
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.network(
                      'https://cdn-icons-png.flaticon.com/512/847/847969.png', // fallback รูปคนเทาๆ
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.network(
                    'https://cdn-icons-png.flaticon.com/512/847/847969.png', // ใช้ fallback เดียวกัน
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _ownerData != null
                ? '${_ownerData!['firstname'] ?? ''} ${_ownerData!['lastname'] ?? ''}'.trim().isNotEmpty
                    ? '${_ownerData!['firstname']} ${_ownerData!['lastname']}'
                    : 'ผู้ใช้ไม่ระบุชื่อ'
                : 'ผู้ใช้ไม่ระบุชื่อ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          Text(
            _formatDate(widget.postData['createdAt']),
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ],
  ),
),




          // 🌈 Card รายละเอียด
          Container(
            margin: const EdgeInsets.fromLTRB(16, 24, 16, 40),
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 36),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withOpacity(0.12),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['title'] ?? 'ไม่มีชื่อโพสต์',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E2E2E),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 3,
                  width: 60,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),

                // ประเภทโพสต์
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _getTypeLabel(type),
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                _buildInfoRow(Icons.inventory_2_outlined, 'ยี่ห้อ',
                    data['brand']?.toString() ?? '-'),
                _buildInfoRow(Icons.star_border_rounded, 'สภาพ',
                    data['condition']?.toString() ?? '-'),
                _buildInfoRow(Icons.straighten, 'ขนาด',
                    data['size']?.toString() ?? '-'),
                // แสดงจำนวนเฉพาะโพสต์บริจาคเท่านั้น
                if (type == 'donate')
                  _buildInfoRow(Icons.card_giftcard, 'จำนวน',
                      data['quantity']?.toString() ?? '-'),
                _buildInfoRow(Icons.delivery_dining, 'วิธีรับของ',
                    data['deliveryMethod']?.toString() ?? '-'),
                // ✅ แสดงสถานที่นัดรับ ถ้ามีค่า pickupLocation
                if (data['pickupLocation'] != null &&
                    (data['pickupLocation'] as String).trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: Color.fromARGB(255, 131, 130, 130), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['pickupLocation'],
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: Color(0xFF3A3A3A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),
                Divider(color: accentColor.withOpacity(0.3)),
                const SizedBox(height: 12),

                Text(
                  data['description'] ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Color(0xFF393E46),
                  ),
                ),
                const SizedBox(height: 28),

                // ปุ่ม
                Builder(builder: (context) {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final isOwner = currentUser?.uid == data['ownerId'];
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withOpacity(0.9),
                          accentColor.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: isOwner
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditPostPage(postData: data),
                                ),
                              )
                          : () => _sendRequest(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isOwner
                            ? 'แก้ไขโพสต์ ✏️'
                            : type == 'donate'
                                ? 'ขอรับสิ่งของ 💛'
                                : type == 'request'
                                    ? 'ขอบริจาค 💗'
                                    : 'ขอแลกเปลี่ยน 💙',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // ✅ เพิ่มพื้นที่ด้านล่าง
          const SizedBox(height: 100),
        ],
      ),
    ),
  ),
);
  }
  String _formatDate(dynamic timestamp) {
  if (timestamp == null) return '';
  final date = (timestamp as Timestamp).toDate();
  return '${date.day} ${_monthName(date.month)} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _monthName(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return months[month - 1];
}

}


