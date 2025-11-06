import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'settings_page.dart';
import 'post_detail_page.dart';
import 'package:video_player/video_player.dart';

// ===============================
// 🔇 วิดีโอ preview ไม่มีเสียง เล่นวน
// ===============================
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
}

// ===============================
// 👤 หน้าโปรไฟล์
// ===============================
class ProfileScreen extends StatefulWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});
  static const routeName = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  late TabController _tabController;

  static const Color kPrimary = Color(0xFFFF6FA5);
  static const Color kText = Color(0xFF1F2937);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadUserDoc() {
    return _db.collection('users').doc(widget.uid).get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _postsStream({String? type}) {
    var ref = _db
        .collection('posts')
        .where('ownerId', isEqualTo: widget.uid)
        .orderBy('createdAt', descending: true);

    if (type != null) {
      ref = ref.where('type', isEqualTo: type);
    }
    return ref.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final me = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _loadUserDoc(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('ไม่พบผู้ใช้นี้ค่ะ'));
            }

            final data = snapshot.data!.data()!;
            final isOwner = me != null && me.uid == widget.uid;

            final profileImage = (data['profileImage'] as String?) ??
                'https://cdn-icons-png.flaticon.com/512/149/149071.png';
            final name =
                '${data['firstname'] ?? ''} ${data['lastname'] ?? ''}'.trim();
            final username = data['username'] ?? '';
            final followersList =
                (data['followersList'] ?? []).cast<String>().toList();
            final followingList =
                (data['followingList'] ?? []).cast<String>().toList();
            final rating = (data['rating'] ?? 0.0).toDouble();
            final ratingCount = (data['ratingCount'] ?? 0) as int;
            final postsCount = (data['postsCount'] ?? 0) as int;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 🔹 Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 20),
                    const Text(
                      "โปรไฟล์",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: kText,
                      ),
                    ),
                    if (isOwner)
                      IconButton(
                        icon: const Icon(
                          Icons.settings,
                          size: 28,
                          color: kText,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsPage()),
                          );
                        },
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // 🔹 Profile image
                Center(
                  child: CircleAvatar(
                    radius: 45,
                    backgroundImage: NetworkImage(profileImage),
                  ),
                ),
                const SizedBox(height: 10),

                // 🔹 Name + username
                Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kText,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '@$username',
                    style: TextStyle(
                      color: kText.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 🔹 posts / followers / following
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatPill(label: 'posts', value: postsCount.toString()),
                    const SizedBox(width: 8),
                    _StatPill(
                        label: 'followers',
                        value: followersList.length.toString()),
                    const SizedBox(width: 8),
                    _StatPill(
                        label: 'following',
                        value: followingList.length.toString()),
                  ],
                ),

                // 🔹 Follow button (for others)
                const SizedBox(height: 18),
                if (!isOwner)
                  Center(
                    child: _ActionButton(
                      text: followersList.contains(me?.uid)
                          ? 'Unfollow'
                          : 'Follow',
                      onTap: () {
                        // TODO: toggle follow function
                      },
                    ),
                  ),

                // 🔹 Trust Score
                const SizedBox(height: 24),
                const Text(
                  'Trust Score',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: StarRating(
                    rating: rating,
                    size: 26,
                    filledColor: kPrimary,
                    emptyColor: Colors.white,
                    borderColor: kPrimary.withOpacity(0.4),
                  ),
                ),
                Text(
                  '${rating.toStringAsFixed(1)} / 5  ($ratingCount รีวิว)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kText.withOpacity(0.7)),
                ),

                const SizedBox(height: 16),

                // 🔹 Tabs
                TabBar(
                  controller: _tabController,
                  labelColor: kPrimary,
                  unselectedLabelColor: kText.withOpacity(0.5),
                  indicatorColor: kPrimary,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_view), text: 'ทั้งหมด'),
                    Tab(icon: Icon(Icons.favorite), text: 'บริจาค'),
                    Tab(icon: Icon(Icons.handshake), text: 'ขอรับ'),
                    Tab(icon: Icon(Icons.swap_horiz), text: 'แลกเปลี่ยน'),
                  ],
                ),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _PostGrid(stream: _postsStream()),
                      _PostGrid(stream: _postsStream(type: 'donate')),
                      _PostGrid(stream: _postsStream(type: 'request')),
                      _PostGrid(stream: _postsStream(type: 'swap')),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ===============================
// 📦 Grid แสดงโพสต์
// ===============================
class _PostGrid extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  const _PostGrid({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('ยังไม่มีโพสต์ในตอนนี้ 🕊️'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final post = docs[i].data();
            final imgs = post['images'] ?? [];
            final vids = post['videos'] ?? [];

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailPage(postData: post),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: imgs.isNotEmpty
                      ? Image.network(imgs.first, fit: BoxFit.cover)
                      : (vids.isNotEmpty
                          ? SilentVideoPreview(url: vids.first)
                          : const Icon(Icons.image_not_supported)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ===============================
// ⭐ Trust Rating Stars
// ===============================
class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final Color filledColor;
  final Color emptyColor;
  final Color borderColor;
  const StarRating({
    super.key,
    required this.rating,
    this.size = 20,
    required this.filledColor,
    required this.emptyColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final fullStars = rating.floor();
    final hasHalf =
        (rating - fullStars) >= 0.25 && (rating - fullStars) < 0.75;
    final halfStars = hasHalf ? 1 : 0;
    final emptyStars = 5 - fullStars - halfStars;

    List<Widget> stars = [];
    for (var i = 0; i < fullStars; i++) {
      stars.add(Icon(Icons.star, color: filledColor, size: size));
    }
    if (halfStars == 1) {
      stars.add(Icon(Icons.star_half, color: filledColor, size: size));
    }
    for (var i = 0; i < emptyStars; i++) {
      stars.add(Icon(Icons.star_border, color: borderColor, size: size));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: stars
          .map((w) =>
              Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: w))
          .toList(),
    );
  }
}

// ===============================
// 💬 UI Components
// ===============================
class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _ActionButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black12),
        ),
        child: Text(
          text,
          style: const TextStyle(
              color: Color(0xFF39424E), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black12.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF39424E))),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: Colors.black.withOpacity(0.6))),
        ],
      ),
    );
  }
}
