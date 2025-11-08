import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:punjai_app/screens/notifications/notifications_page.dart';
import 'package:punjai_app/screens/chat/ChatsListPage.dart';
import 'package:punjai_app/screens/profile/history_page.dart';

class PunjaiAppBar extends StatefulWidget implements PreferredSizeWidget {
  const PunjaiAppBar({super.key});

  @override
  State<PunjaiAppBar> createState() => _PunjaiAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(70);
}

class _PunjaiAppBarState extends State<PunjaiAppBar> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  int _unreadCount = 0;
  StreamSubscription? _notifListener;

  @override
  void initState() {
    super.initState();
    _listenForUnreadNotifications();
  }

  @override
  void dispose() {
    _notifListener?.cancel();
    super.dispose();
  }

  void _listenForUnreadNotifications() {
    final user = _auth.currentUser;
    if (user == null) return;

    _notifListener = _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _unreadCount = snapshot.docs.length);
      }
    });
  }

  @override
Widget build(BuildContext context) {
  return Container(
    decoration: const BoxDecoration(
      color: Colors.white, // ✅ ขาวจริง ๆ ไม่โปร่ง ไม่อมชมพู
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x11000000), // เงาเบา ๆ นุ่มๆ
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent, 
      elevation: 0,
      title: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFFFF8FB1), Color(0xFFFFD84D), Color(0xFF9EDAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: const Text(
          'PunJai',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            fontFamily: 'Poppins',
            color: Colors.white,
            letterSpacing: 0.6,
          ),
        ),
      ),
      actions: [
        _buildIconButton(
          icon: Icons.favorite_border,
          color: const Color(0xFFFF8FB1),
          tooltip: 'การแจ้งเตือน',
          badgeCount: _unreadCount,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );
            if (mounted) setState(() => _unreadCount = 0);
          },
        ),
        _buildIconButton(
          icon: Icons.chat_bubble_outline,
          color: const Color(0xFFFF8FB1),
          tooltip: 'ห้องแชท',
          onTap: () {
            Navigator.pushNamed(context, ChatsListPage.routeName);
          },
        ),
        _buildIconButton(
          icon: Icons.history_rounded,
          color: const Color(0xFFFF8FB1),
          tooltip: 'ประวัติของฉัน',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            );
          },
        ),
        const SizedBox(width: 10),
      ],
    ),
  );
}



  /// 🎀 ปุ่มไอคอนที่มี Badge
  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withOpacity(0.2),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white, // ✅ สีขาวเต็มไม่โปร่ง
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 12, 
                    spreadRadius: 2,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, size: 26, color: color),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.shade400,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
