import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/app_router.dart';
import 'firebase_options.dart'; // สำหรับการเชื่อม Firebase ที่สร้างด้วย CLI
import 'screens/login_screen.dart'; // ✅ ใช้เป็นหน้าแรกของแอป

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ เริ่มต้น Firebase ให้พร้อมก่อน runApp
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PunjaiApp());
}

class PunjaiApp extends StatelessWidget {
  const PunjaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PunJai App',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Poppins',
      ),
      // ✅ ใช้ Router กลางที่ชมพูทำไว้
      onGenerateRoute: AppRouter.generateRoute,

      // ✅ หน้าแรกของแอป (แก้จาก ForgotPasswordScreen เป็น Login)
      initialRoute: LoginScreen.routeName,
    );
  }
}
