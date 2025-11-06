import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'screens/app_router.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';

// ✅ สร้าง instance ของ plugin สำหรับแสดง notification
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// ------------------------------------------------------------
/// 🔔 ฟังก์ชัน setup ระบบแจ้งเตือน (FCM + Local Notification)
/// ------------------------------------------------------------
Future<void> _setupNotification() async {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  // ✅ ขออนุญาตแจ้งเตือนจากผู้ใช้
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // ✅ ดึง FCM Token ปัจจุบัน
  final token = await messaging.getToken();
  print('📱 Current FCM Token: $token');

  // ✅ บันทึก token ลง Firestore (เพื่อใช้ส่ง push จริงภายหลัง)
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && token != null) {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcmToken': token,
    });
  }

  // ✅ ตั้งค่า Channel สำหรับ Android
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // ✅ กำหนด Channel สำหรับ Android Notification
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'punjai_channel', // id
    'Punjai Notifications', // ชื่อ channel
    description: 'ช่องสำหรับการแจ้งเตือนของ Punjai',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // ✅ ตั้งค่า handler เมื่อมีข้อความเข้าระหว่างเปิดแอป
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

  // ✅ เมื่อผู้ใช้กด notification ตอนแอปปิดอยู่ → เปิดแอปกลับมา
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('🔔 Notification Clicked: ${message.notification?.title}');
    // สามารถนำทางไปยังหน้าที่เกี่ยวข้องได้ เช่น:
    // Navigator.pushNamed(context, '/notifications');
  });
}

/// ------------------------------------------------------------
/// 🎯 main()
/// ------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ เริ่มต้น Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Setup ระบบแจ้งเตือน
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
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: LoginScreen.routeName,
    );
  }
}
