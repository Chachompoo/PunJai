import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ------------------------------------------------------------
/// ProfileScreen
/// - แสดงโปรไฟล์ผู้ใช้ (รูป โปรไฟล์, ชื่อ, username)
/// - แสดง Trust Score แบบ "ดาว" (คำนวณจาก trustAvg และ trustCount ใน users/{uid})
/// - แสดงจำนวนโพสต์ และกริดรูปโพสต์ ของ user คนนั้น
/// - ถ้าเจ้าของโปรไฟล์ = ผู้ใช้ปัจจุบัน → โชว์ปุ่ม Edit Profile
/// - ถ้าไม่ใช่เจ้าของ → โชว์ปุ่ม Report User (เวอร์ชันเบา: ส่งเหตุผลขึ้น Firestore)
/// โทนสี: พื้นชมพูพาสเทลแบบหน้า Welcome (เพราะไม่ใช่หน้าบริจาค/แลกเปลี่ยน)
/// ------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  /// ถ้าเป็นโปรไฟล์ตัวเอง อนุญาตให้ส่ง `uid` เป็น currentUser.uid ได้เลย
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

  static const Color kBg = Color(0xFFFDECF2);
  static const Color kPrimary = Color(0xFFFF6FA5);
  static const Color kText = Color(0xFF39424E);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadUserDoc() {
    return _db.collection('users').doc(widget.uid).get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _postsStream({String? type}) {
    var ref = _db
        .collection('posts')
        .where('ownerUid', isEqualTo: widget.uid)
        .orderBy('createdAt', descending: true);

    if (type != null) {
      ref = ref.where('type', isEqualTo: type);
    }
    return ref.snapshots();
  }

  /// กดติดตาม / เลิกติดตาม
  Future<void> _toggleFollow(String targetUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentRef = _db.collection('users').doc(currentUser.uid);
    final targetRef = _db.collection('users').doc(targetUid);

    final currentSnap = await currentRef.get();
    final targetSnap = await targetRef.get();

    List followersList =
        (targetSnap.data()?['followersList'] ?? []).cast<String>();
    List followingList =
        (currentSnap.data()?['followingList'] ?? []).cast<String>();

    bool isFollowing = followersList.contains(currentUser.uid);

    if (isFollowing) {
      followersList.remove(currentUser.uid);
      followingList.remove(targetUid);
    } else {
      followersList.add(currentUser.uid);
      followingList.add(targetUid);
    }

    await _db.runTransaction((txn) async {
      txn.update(targetRef, {
        'followersList': followersList,
        'followers': followersList.length,
      });
      txn.update(currentRef, {
        'followingList': followingList,
        'following': followingList.length,
      });
    });

    setState(() {});
  }

  /// แสดง Dialog รายชื่อ Followers / Following
  void _showUserList(List<dynamic> userList, String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: userList.isEmpty
            ? const Text('ยังไม่มีข้อมูล')
            : SizedBox(
                height: 300,
                width: 250,
                child: ListView.builder(
                  itemCount: userList.length,
                  itemBuilder: (context, i) =>
                      ListTile(title: Text(userList[i])),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = _auth.currentUser;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kText,
        centerTitle: true,
        title: const Text('Profile'),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
          final followers = data['followers'] ?? 0;
          final following = data['following'] ?? 0;
          final followersList =
              (data['followersList'] ?? []).cast<String>().toList();
          final followingList =
              (data['followingList'] ?? []).cast<String>().toList();
          final trustAvg = (data['trustAvg'] ?? 0.0).toDouble();
          final trustCount = (data['trustCount'] ?? 0) as int;

          final postsCount = (data['postsCount'] ?? 0) as int;

          return Column(
            children: [
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 42,
                backgroundImage: NetworkImage(profileImage),
              ),
              const SizedBox(height: 12),
              Text(name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kText)),
              Text('@$username',
                  style: TextStyle(
                      color: kText.withOpacity(0.65), fontSize: 14)),
              const SizedBox(height: 12),

              // Followers / Following
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => _showUserList(followersList, 'Followers'),
                    child: _StatPill(
                        label: 'followers', value: followers.toString()),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showUserList(followingList, 'Following'),
                    child: _StatPill(
                        label: 'following', value: following.toString()),
                  ),
                  const SizedBox(width: 8),
                  _StatPill(label: 'posts', value: postsCount.toString()),
                ],
              ),
              const SizedBox(height: 12),

              // ปุ่ม Follow / Edit
              isOwner
                  ? _ActionButton(
                      text: 'Edit profile',
                      onTap: () {
                        Navigator.pushNamed(context, '/edit_profile');
                      },
                    )
                  : _ActionButton(
                      text: followersList.contains(me?.uid)
                          ? 'Unfollow'
                          : 'Follow',
                      onTap: () => _toggleFollow(widget.uid),
                    ),


              // คะแนนความน่าเชื่อถือ
              const Text('Trust Score', style: TextStyle(color: kText)),
              StarRating(
                rating: trustAvg,
                size: 26,
                filledColor: kPrimary,
                emptyColor: Colors.white,
                borderColor: kPrimary.withOpacity(0.4),
              ),
              Text('${trustAvg.toStringAsFixed(1)} / 5 ($trustCount รีวิว)',
                  style: TextStyle(color: kText.withOpacity(0.7))),
              const SizedBox(height: 16),

              // Tab: โพสต์
              TabBar(
                controller: _tabController,
                labelColor: kPrimary,
                unselectedLabelColor: kText.withOpacity(0.5),
                indicatorColor: kPrimary,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on), text: 'รวมทุกโพสต์'),
                  Tab(icon: Icon(Icons.favorite), text: 'เฉพาะโพสต์บริจาค'),
                  Tab(icon: Icon(Icons.swap_horiz), text: 'เฉพาะโพสต์แลกเปลี่ยน'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _PostGrid(stream: _postsStream()),
                    _PostGrid(stream: _postsStream(type: 'donation')),
                    _PostGrid(stream: _postsStream(type: 'exchange')),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ------------------------------------------------------------
/// Widgets ย่อย
/// ------------------------------------------------------------
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
          color: _ProfileColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: _ProfileColors.primary.withOpacity(0.35)),
        ),
        child: Text(text,
            style: const TextStyle(
                color: _ProfileColors.text, fontWeight: FontWeight.w600)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _ProfileColors.text)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: _ProfileColors.text.withOpacity(0.65))),
        ],
      ),
    );
  }
}

/// กริดโพสต์
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
          return const Center(child: Text('ยังไม่มีโพสต์'));
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
            final img = (post['imageUrl'] as String?) ??
                'https://picsum.photos/seed/${docs[i].id}/400/400';
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(img, fit: BoxFit.cover),
            );
          },
        );
      },
    );
  }
}

/// ดาวความน่าเชื่อถือ
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
    final hasHalf = (rating - fullStars) >= 0.25 && (rating - fullStars) < 0.75;
    final halfStars = hasHalf ? 1 : 0;
    final emptyStars = 5 - fullStars - halfStars;

    List<Widget> stars = [];
    for (var i = 0; i < fullStars; i++) {
      stars.add(_buildStar(icon: Icons.star, color: filledColor));
    }
    if (halfStars == 1) {
      stars.add(_buildStar(icon: Icons.star_half, color: filledColor));
    }
    for (var i = 0; i < emptyStars; i++) {
      stars.add(_buildStar(icon: Icons.star_border, color: borderColor));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: stars
          .map((w) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: w))
          .toList(),
    );
  }

  Widget _buildStar({required IconData icon, required Color color}) {
    return Icon(icon, size: size, color: color);
  }
}

class _ProfileColors {
  static const Color primary = Color(0xFFFF6FA5);
  static const Color text = Color(0xFF39424E);
}
