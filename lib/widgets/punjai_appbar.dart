import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:punjai_app/screens/notifications_page.dart';
import 'dart:async';
import 'package:punjai_app/screens/ChatsListPage.dart';


class PunjaiAppBar extends StatefulWidget implements PreferredSizeWidget {
  const PunjaiAppBar({super.key});

  @override
  State<PunjaiAppBar> createState() => _PunjaiAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _PunjaiAppBarState extends State<PunjaiAppBar> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  int _unreadCount = 0;
  StreamSubscription? _notifListener;

  @override
  void initState() {
    super.initState();
    _listenForUnreadNotifications(); // ✅ ฟังเฉพาะ unread count
  }

  @override
  void dispose() {
    _notifListener?.cancel();
    super.dispose();
  }

  /// 🔔 ฟังการเปลี่ยนแปลงของการแจ้งเตือนแบบ real-time เฉพาะ unread count
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
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text(
        'PunJai',
        style: TextStyle(
          color: Colors.black,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
        ),
      ),
      actions: [
        // ❤️ ปุ่มแจ้งเตือน
        IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.favorite_border,
                  color: Colors.pinkAccent, size: 28),
              if (_unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
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
          onPressed: () async {
            // 👉 เปิดหน้า Notifications
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );

            // ✅ หลังกลับมา เคลียร์ badge เฉย ๆ (ไม่ยุ่ง Firestore)
            if (mounted) setState(() => _unreadCount = 0);
          },
        ),

        // 💬 ปุ่มแชท
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline,
              color: Colors.black87, size: 28),
          onPressed: () {
            Navigator.pushNamed(context, ChatsListPage.routeName);
          },
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}
