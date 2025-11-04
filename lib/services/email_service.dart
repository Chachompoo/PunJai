import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

class EmailService {
  static Future<void> sendResetCodeEmail(String email, String code) async {
    // 👉 กำหนด Gmail ของชมพู
    const String senderEmail = 'chaploy.house@gmail.com';
    const String appPassword = 'rqfm hzup fivx ypbv'; // 16 ตัวจาก App Passwords

    final smtpServer = gmail(senderEmail, appPassword);

    final message = Message()
      ..from = Address(senderEmail, 'PunJai Support')
      ..recipients.add(email)
      ..subject = '🔐 PunJai Reset Code'
      ..html = '''
        <h2>PunJai Password Reset</h2>
        <p>สวัสดีค่ะ 💕</p>
        <p>รหัสยืนยันของคุณคือ:</p>
        <h1 style="letter-spacing: 4px; color:#FF6FA5;">$code</h1>
        <p>รหัสนี้จะหมดอายุใน 5 นาที กรุณาใช้รีเซ็ตรหัสผ่านของคุณค่ะ</p>
        <br>
        <p>— ทีมงาน PunJai ☕</p>
      ''';

    try {
      await send(message, smtpServer);
      print('✅ Email sent to $email');
    } on MailerException catch (e) {
      print('❌ Email not sent. Error: $e');
      rethrow;
    }
  }
}
