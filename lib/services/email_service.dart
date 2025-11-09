import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

class EmailService {
  static const String senderEmail = 'chaploy.house@gmail.com';
  static const String appPassword = 'rqfm hzup fivx ypbv'; // App Password

  static final smtpServer = gmail(senderEmail, appPassword);

  // 🔹 ส่งรหัสรีเซ็ตรหัสผ่าน (ของเดิม)
  static Future<void> sendResetCodeEmail(String email, String code) async {
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

  // 💌 ส่งอีเมลแจ้งผลตรวจสอบบัตรประชาชน (Pastel Theme)
  static Future<void> sendVerificationResultEmail({
    required String email,
    required String name,
    required bool isApproved,
    String? rejectReason,
  }) async {
    final subject = isApproved
        ? '🌸 PunJai: บัญชีของคุณได้รับการยืนยันแล้ว 💗'
        : '🍃 PunJai: บัญชีของคุณไม่ผ่านการตรวจสอบ 😢';

    final bgColor = isApproved ? "#FFF7FB" : "#FFF3F3";
    final headerColor = isApproved ? "#FF8FB1" : "#FF9E9E";
    final emoji = isApproved ? "💖" : "💔";

    final htmlBody = '''
<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="UTF-8" />
  <style>
    body {
      background-color: $bgColor;
      font-family: 'Kanit', sans-serif;
      color: #393E46;
      margin: 0;
      padding: 0;
    }
    .container {
      max-width: 500px;
      background: #fff;
      border-radius: 16px;
      box-shadow: 0 2px 10px rgba(255, 143, 177, 0.15);
      margin: 40px auto;
      overflow: hidden;
      border: 2px solid #FFD7E2;
    }
    .header {
      background-color: $headerColor;
      color: white;
      text-align: center;
      padding: 20px;
      font-size: 22px;
      font-weight: bold;
      letter-spacing: 0.5px;
    }
    .content {
      padding: 25px 25px 35px;
      text-align: center;
      font-size: 15px;
      line-height: 1.6;
    }
    .emoji {
      font-size: 36px;
    }
    .footer {
      background: #FFF7FB;
      padding: 12px;
      font-size: 13px;
      color: #777;
      text-align: center;
      border-top: 1px solid #FFD7E2;
    }
    .button {
      display: inline-block;
      margin-top: 16px;
      padding: 10px 20px;
      background-color: $headerColor;
      color: white;
      border-radius: 25px;
      text-decoration: none;
      font-weight: bold;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">PunJai Verification</div>
    <div class="content">
      <div class="emoji">$emoji</div>
      <p>สวัสดีคุณ <b>$name</b></p>
      ${isApproved
          ? '''
          <p>บัญชีของคุณได้รับการตรวจสอบเรียบร้อยแล้ว 💗</p>
          <p>ตอนนี้คุณสามารถเข้าสู่ระบบ <b>PunJai</b> เพื่อเริ่มแบ่งปันสิ่งดี ๆ ได้เลย!</p>
          <a href="https://punjai-app.web.app" class="button">เข้าสู่ระบบ PunJai</a>
          '''
          : '''
          <p>ขออภัย บัญชีของคุณไม่ผ่านการตรวจสอบ 😢</p>
          <p><b>สาเหตุ:</b> ${rejectReason ?? "ไม่ระบุ"}</p>
          <p>กรุณาตรวจสอบข้อมูลอีกครั้ง และสมัครใหม่อีกครั้งค่ะ 💌</p>
          '''
        }
    </div>
    <div class="footer">
      © 2025 PunJai App — Small act, Big heart 💞
    </div>
  </div>
</body>
</html>
''';

    final message = Message()
      ..from = Address(senderEmail, 'PunJai Support')
      ..recipients.add(email)
      ..subject = subject
      ..html = htmlBody;

    try {
      await send(message, smtpServer);
      print('📧 Verification email sent to $email');
    } on MailerException catch (e) {
      print('❌ Failed to send verification email: $e');
    }
  }
}
