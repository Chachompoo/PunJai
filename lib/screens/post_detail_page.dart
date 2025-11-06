import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:punjai_app/screens/edit_post_page.dart';

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> postData;
  const PostDetailPage({super.key, required this.postData});

  static const routeName = '/postDetail';

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initVideoIfAvailable();
    });
  }

  Future<void> _initVideoIfAvailable() async {
    try {
      final videos = widget.postData['videos'] ?? [];
      if (videos.isNotEmpty) {
        _videoController =
            VideoPlayerController.networkUrl(Uri.parse(videos.first));
        await _videoController?.initialize();
        _videoController?.setVolume(1.0);
        _videoController?.setLooping(true);
        await _videoController?.play();
        setState(() => _isVideoInitialized = true);
      }
    } catch (e) {
      debugPrint('❌ Video load error: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final data = widget.postData;
    final type = data['type'] ?? 'donate';
    final images = data['images'] ?? [];
    final videos = data['videos'] ?? [];
    final mediaCount = images.length + (videos.isNotEmpty ? 1 : 0);

    // 🎨 ธีมสี
    final themeColor = type == 'donate'
        ? const Color(0xFFFFF7CC)
        : type == 'request'
            ? const Color(0xFFFFE6F0)
            : const Color(0xFFE3F4FF);

    final accentColor = type == 'donate'
        ? const Color(0xFFFFC83C)
        : type == 'request'
            ? const Color(0xFFFF8FB1)
            : const Color(0xFF8CC7FF);

    return Scaffold(
      backgroundColor: themeColor,
      appBar: AppBar(
        title: Text(
          data['title'] ?? 'รายละเอียดโพสต์',
          style: const TextStyle(
            color: Color(0xFF393E46),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          children: [
            // 🖼 Media
            if (mediaCount > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: MediaQuery.of(context).size.width * 0.95,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      for (final img in images)
                        Image.network(img, fit: BoxFit.cover),
                      if (videos.isNotEmpty)
                        _isVideoInitialized
                            ? VideoPlayer(_videoController!)
                            : const Center(
                                child: CircularProgressIndicator(),
                              ),
                    ],
                  ),
                ),
              ),

            if (mediaCount > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    mediaCount,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentPage == index ? 10 : 6,
                      height: _currentPage == index ? 10 : 6,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? accentColor
                            : Colors.black26,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 25),

            // 💬 ข้อมูลโพสต์
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.category, 'ประเภท', _getTypeLabel(type)),
                  const SizedBox(height: 10),
                  _buildInfoRow(Icons.inventory_2, 'ยี่ห้อ',
                      data['brand']?.toString() ?? '-'),
                  _buildInfoRow(Icons.star, 'สภาพ',
                      data['condition']?.toString() ?? '-'),
                  _buildInfoRow(Icons.straighten, 'ขนาด',
                      data['size']?.toString() ?? '-'),
                  _buildInfoRow(Icons.card_giftcard, 'จำนวน',
                      data['quantity']?.toString() ?? '-'),
                  _buildInfoRow(Icons.delivery_dining, 'วิธีรับของ',
                      data['deliveryMethod']?.toString() ?? '-'),
                  const Divider(height: 24, color: Colors.black12),
                  Text(
                    data['description'] ?? '',
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFF393E46), height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 🩷 ปุ่มขอรับ / แก้ไข
            Builder(builder: (context) {
              final currentUser = FirebaseAuth.instance.currentUser;
              final isOwner = currentUser?.uid == data['ownerId'];
              return GestureDetector(
                onTap: isOwner
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EditPostPage(postData: data)),
                        )
                    : () => _sendRequest(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      isOwner
                          ? 'แก้ไขโพสต์ ✏️'
                          : type == 'donate'
                              ? 'ขอรับสิ่งของ 💛'
                              : type == 'request'
                                  ? 'ขอบริจาค 💗'
                                  : 'ขอแลกเปลี่ยน 💙',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
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
}
