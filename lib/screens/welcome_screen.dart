import 'package:flutter/material.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  static const routeName = '/welcome';
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _controller = PageController();
  int currentIndex = 0;

  final pages = [
    {
      'bg': const Color(0xFFFFF5F7),
      'image': 'assets/images/punjai.png',
      'width': 470,
      'height': 470,
      'title': 'PUNJAI',
      'caption': 'Happy to share',
      'titleColor': const Color(0xFFFF80A0),
    },
    {
      'bg': const Color(0xFFFFFBEA),
      'image': 'assets/images/Punjai_donation.png',
      'title': 'DONATION',
      'caption': 'Small act, big heart',
      'titleColor': const Color(0xFFF6C23E),
    },
    {
      'bg': const Color(0xFFEBF6FF),
      'image': 'assets/images/Punjai_exchange.png',
      'title': 'EXCHANGE',
      'caption': 'Swap to smile',
      'titleColor': const Color(0xFF58C2E8),
    },
  ];

  void nextPage() {
    if (currentIndex < pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = pages[currentIndex];

    return Scaffold(
      backgroundColor: page['bg'] as Color,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() => currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final page = pages[index];
                  return AnimatedContainer(
                    key: ValueKey(index),
                    duration: const Duration(milliseconds: 400),
                    color: page['bg'] as Color,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            page['image'] as String,
                            width: 450,
                            height: 450,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 40),
                          if (index == 0)
                            const Text(
                              'Welcome To',
                              style: TextStyle(
                                fontSize: 26,
                                color: Colors.black87,
                              ),
                            ),
                          Text(
                            page['title'] as String,
                            style: TextStyle(
                              fontSize: 65,
                              fontWeight: FontWeight.bold,
                              color: page['titleColor'] as Color,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            page['caption'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildBottomSection(page),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(Map<String, dynamic> page) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ElevatedButton(
            onPressed: nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: page['titleColor'] as Color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text(
              currentIndex == pages.length - 1 ? 'Get Start' : 'Next',
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Existing user? "),
            GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text(
                "Sign in",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pages.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: currentIndex == index ? 14 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: currentIndex == index ? Colors.black : Colors.black26,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
