import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'screens/app_router.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/welcome/welcome_screen.dart'; // 💗 เพิ่มตรงนี้
import 'screens/home/home_screen.dart'; // เผื่อใช้ตอนเช็ก login

// ✅ สร้าง instance ของ plugin สำหรับแสดง notification
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// ------------------------------------------------------------
/// 🔔 ฟังก์ชัน setup ระบบแจ้งเตือน (FCM + Local Notification)
/// ------------------------------------------------------------
Future<void> _setupNotification() async {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(alert: true, badge: true, sound: true);

  final token = await messaging.getToken();
  print('📱 Current FCM Token: $token');

  final user = FirebaseAuth.instance.currentUser;
  if (user != null && token != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'fcmToken': token}, SetOptions(merge: true)); // ✅ แก้ตรงนี้
  }

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'punjai_channel',
    'Punjai Notifications',
    description: 'ช่องสำหรับการแจ้งเตือนของ Punjai',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    final android = notification?.android;
    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title ?? 'Punjai',
        notification.body ?? 'คุณมีข้อความใหม่ 💌',
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('🔔 Notification Clicked: ${message.notification?.title}');
  });
}


/// ------------------------------------------------------------
/// 🎯 main()
/// ------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _setupNotification();

  runApp(const PunjaiApp());
}

/// ------------------------------------------------------------
/// 🩷 แอปหลัก Punjai
/// ------------------------------------------------------------
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

      // ✅ เริ่มที่หน้า Welcome ก่อน
      initialRoute: '/welcome',

      // ✅ routes หลักของแอป
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },

      // ✅ รองรับระบบ Route อื่น ๆ ของแอปชมพู (ถ้ามี)
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
