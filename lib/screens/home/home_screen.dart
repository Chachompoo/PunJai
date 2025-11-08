import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:punjai_app/screens/auth/login_screen.dart';
import 'package:punjai_app/screens/profile/profile_screen.dart';
import 'package:punjai_app/screens/posts/create_post_page.dart';
import 'package:punjai_app/screens/home/feed_page.dart';
import 'package:punjai_app/screens/home/search_page.dart';
import 'package:punjai_app/screens/home/top_donors_page.dart';
import 'package:punjai_app/widgets/punjai_appbar.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (_auth.currentUser == null) {
      Future.microtask(() {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
    }
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return const FeedPage();
      case 1:
        return const SearchPage();
      case 2:
        return _buildPostTypeSelector(context);
      case 3:
        return const TopDonorsPage();
      case 4:
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = snapshot.data;
            if (user == null) {
              Future.microtask(() {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              });
              return const Center(child: Text('กำลังออกจากระบบ... 💗'));
            }
            return ProfileScreen(uid: user.uid);
          },
        );
      default:
        return const Center(child: Text('หน้าที่ไม่พบค่ะ 🚫'));
    }
  }

  // 🌸 หน้าเลือกประเภทโพสต์ (Animated Float Style)
  Widget _buildPostTypeSelector(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFFF7FB),
            Color(0xFFFFFAE3),
            Color(0xFFEAF7FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    Text(
                      'เลือกประเภทโพสต์ 💌',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF393E46),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'มาแบ่งปันสิ่งดี ๆ ให้กันเถอะ 🌷',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              // 💛 บริจาคสิ่งของ
              _AnimatedFloatButton(
                title: "บริจาคสิ่งของ",
                subtitle: "แบ่งปันของที่คุณไม่ใช้ ให้คนที่ต้องการ",
                gradient: [Color(0xFFFFE97A), Color(0xFFFFC83C)],
                icon: Icons.volunteer_activism_rounded,
                type: "donate",
              ),
              const SizedBox(height: 22),

              // 💗 ขอรับบริจาค
              _AnimatedFloatButton(
                title: "ขอรับบริจาค",
                subtitle: "ขอรับสิ่งของที่คุณกำลังต้องการอยู่",
                gradient: [Color(0xFFFFB6C1), Color(0xFFFF8FBF)],
                icon: Icons.card_giftcard_rounded,
                type: "request",
              ),
              const SizedBox(height: 22),

              // 💙 แลกเปลี่ยนสิ่งของ
              _AnimatedFloatButton(
                title: "แลกเปลี่ยนสิ่งของ",
                subtitle: "แลกของกันด้วยรอยยิ้ม 😊",
                gradient: [Color(0xFF9EDAFF), Color(0xFF7EC8E3)],
                icon: Icons.swap_horiz_rounded,
                type: "swap",
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🌈 Bottom Navigation + FAB
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: _selectedIndex == 0 ? const PunjaiAppBar() : null,

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.15, 0),
            end: Offset.zero,
          ).animate(animation);
          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Container(
          key: ValueKey<int>(_selectedIndex),
          color: Colors.white,
          child: _buildCurrentPage(),
        ),
      ),

      floatingActionButton: _AnimatedBubbleButton(
        onPressed: () {
          setState(() => _selectedIndex = 2);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 9,
                offset: const Offset(0, -3),
              ),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: SizedBox(
                  height: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNavItem(Icons.home_rounded, 0, 'Home', const Color(0xFFFF8FBF)),
                            _buildNavItem(Icons.search_rounded, 1, 'Search', const Color(0xFF7EC8E3)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 50),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNavItem(Icons.emoji_events_rounded, 3, 'Top Donors', const Color(0xFFFFB703)),
                            _buildNavItem(Icons.person_rounded, 4, 'Profile', const Color(0xFFFF8FBF)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ปุ่มล่างแต่ละอัน
  Widget _buildNavItem(IconData icon, int index, String label, Color activeColor) {
    final bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.grey, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? activeColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🫧 ปุ่มฟองสบู่ตรงกลาง (สร้างโพสต์)
class _AnimatedBubbleButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AnimatedBubbleButton({required this.onPressed});

  @override
  State<_AnimatedBubbleButton> createState() => _AnimatedBubbleButtonState();
}

class _AnimatedBubbleButtonState extends State<_AnimatedBubbleButton>
    with TickerProviderStateMixin {
  late AnimationController _colorController;
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
  }

  @override
  void dispose() {
    _colorController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_colorController, _pressController]),
      builder: (context, _) {
        final colors = [
          Color.lerp(const Color(0xFFFFE97A), const Color(0xFFFFB6C1), _colorController.value)!,
          Color.lerp(const Color(0xFFFFB6C1), const Color(0xFF9EDAFF), _colorController.value)!,
          Color.lerp(const Color(0xFF9EDAFF), const Color(0xFFFFE97A), _colorController.value)!,
        ];

        double scale = 1 - _pressController.value;

        return GestureDetector(
          onTapDown: (_) => _pressController.forward(),
          onTapUp: (_) {
            _pressController.reverse();
            widget.onPressed();
          },
          onTapCancel: () => _pressController.reverse(),
          child: Transform.scale(
            scale: scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.first.withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 34),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 🎀 ปุ่มลอยเด้ง (Animated Float)
class _AnimatedFloatButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  final String type;

  const _AnimatedFloatButton({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.type,
  });

  @override
  State<_AnimatedFloatButton> createState() => _AnimatedFloatButtonState();
}

class _AnimatedFloatButtonState extends State<_AnimatedFloatButton> {
  double _scale = 1.0;
  double _shadow = 0.3;

  void _onTapDown(_) {
    setState(() {
      _scale = 1.05;
      _shadow = 0.45;
    });
  }

  void _onTapUp(_) async {
    setState(() {
      _scale = 1.0;
      _shadow = 0.3;
    });
    await Future.delayed(const Duration(milliseconds: 100));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreatePostPage(type: widget.type)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: () {
          setState(() {
            _scale = 1.0;
            _shadow = 0.3;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: MediaQuery.of(context).size.width * 0.88,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.last.withOpacity(_shadow),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedScale(
                scale: _scale,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.25),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 255, 228, 228).withOpacity(0.5),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(blurRadius: 3, color: Colors.black26),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
