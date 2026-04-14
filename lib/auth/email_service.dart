import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  static Future<bool> sendOtpEmail(String recipientEmail, String otp) async {
    final smtpServer = SmtpServer(
      'smtp-relay.brevo.com',
      port: 587,
      username: '92698a002@smtp-brevo.com',
      password: 'Ahtxyvf8DPTFM1Cn',
    );

    final message = Message()
      ..from = const Address('kidet621@gmail.com', 'College App')
      ..recipients.add(recipientEmail)
      ..subject = 'Your Verification OTP'
      ..html = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #1A237E;">College App Verification</h2>
          <p>Your OTP code for email verification is:</p>
          <div style="background: #1A237E; color: white; padding: 15px; text-align: center; font-size: 24px; font-weight: bold; margin: 20px 0; border-radius: 5px;">
            $otp
          </div>
          <p>This OTP is valid for 10 minutes. Please do not share it with anyone.</p>
          <p>If you didn't request this, please ignore this email.</p>
        </div>
      ''';

    try {
      final sendReport = await send(message, smtpServer);
      print('Message sent: $sendReport');
      return true;
    } catch (e) {
      print('Message not sent. $e');
      return false;
    }
  }
}