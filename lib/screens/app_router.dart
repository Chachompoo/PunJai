import 'package:flutter/material.dart';
import 'package:punjai_app/screens/login_screen.dart';
import 'package:punjai_app/screens/signup_screen.dart';
import 'package:punjai_app/screens/home_screen.dart';
import 'package:punjai_app/screens/welcome_screen.dart';
import 'package:punjai_app/screens/forgot_password_screen.dart';
import 'package:punjai_app/screens/verify_code_screen.dart';
import 'package:punjai_app/screens/password_reset_success_screen.dart';
import 'package:punjai_app/screens/update_password_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case WelcomeScreen.routeName:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case LoginScreen.routeName:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case SignupScreen.routeName:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case HomeScreen.routeName:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
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

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
