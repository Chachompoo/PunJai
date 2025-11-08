import 'package:flutter/material.dart';

// 🔹 Auth & User
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import 'welcome/welcome_screen.dart';
import 'auth/forgot_password_screen.dart';
import 'auth/verify_code_screen.dart';
import 'auth/password_reset_success_screen.dart';
import 'auth/update_password_screen.dart';

// 🔹 Home & Profile
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'profile/edit_profile_screen.dart';

// 🔹 Main Features
import 'home/feed_page.dart';
import 'posts/create_post_page.dart';
import 'posts/post_detail_page.dart';
import 'posts/my_requests_page.dart';
import 'confirmations/confirmations_page.dart';
import 'home/top_donors_page.dart';
import 'home/search_page.dart';


// 🔹 Chat
import 'chat/ChatsListPage.dart';
import 'chat/ChatRoomPage.dart';

// 🔹 Notifications
import 'notifications/notifications_page.dart';

// 🔹 settings
import 'package:punjai_app/screens/profile/settings_page.dart';
import 'package:punjai_app/screens/profile/history_page.dart';


class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {

      // 🩷 Authentication
      case WelcomeScreen.routeName:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case LoginScreen.routeName:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case SignupScreen.routeName:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case ForgotPasswordScreen.routeName:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case VerifyCodeScreen.routeName:
        final email = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => VerifyCodeScreen(email: email));
      case PasswordResetSuccessScreen.routeName:
        final email = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => PasswordResetSuccessScreen(email: email));
      case UpdatePasswordScreen.routeName:
        final email = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => UpdatePasswordScreen(email: email));

      // 🏡 Home & Profile
      case HomeScreen.routeName:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case ProfileScreen.routeName:
        final uid = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid));
      case EditProfileScreen.routeName:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());

      // 🩷 Core Features
      case FeedPage.routeName:
        return MaterialPageRoute(builder: (_) => const FeedPage());
      case CreatePostPage.routeName:
        final type = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => CreatePostPage(type: type));

      // 🩷 โพสต์รายละเอียด
      case PostDetailPage.routeName:
        final postData = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => PostDetailPage(postData: postData));

      // 💛 คำขอ / การยืนยัน / อันดับ / ค้นหา
      case MyRequestsPage.routeName:
        return MaterialPageRoute(builder: (_) => const MyRequestsPage());
      case ConfirmationsPage.routeName:
        return MaterialPageRoute(builder: (_) => const ConfirmationsPage());
      case TopDonorsPage.routeName:
        return MaterialPageRoute(builder: (_) => const TopDonorsPage());
      case SearchPage.routeName:
        return MaterialPageRoute(builder: (_) => const SearchPage());

      // 💬 ระบบแชต
      case ChatsListPage.routeName:
        return MaterialPageRoute(builder: (_) => const ChatsListPage());
      case ChatRoomPage.routeName:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            chatId: args['chatId'],
            otherUserId: args['otherUserId'],
            otherUserName: args['otherUserName'],
            otherUserImage: args['otherUserImage'],
            postId: args['postId'],         
            ownerId: args['ownerId'], 
          ),
        );

      // 🔔 การแจ้งเตือน
      case NotificationsPage.routeName:
        return MaterialPageRoute(builder: (_) => const NotificationsPage());

      // ⚙️ การตั้งค่า
      case SettingsPage.routeName:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      case HistoryPage.routeName:
        return MaterialPageRoute(builder: (_) => const HistoryPage());

      // 🚫 หน้าที่ไม่พบ
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found 🚫')),
          ),
        );
    }
  }
}
