import 'package:mailer/mailer.dart';
import '../utils/currency_formatter.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';

/// Service for sending email notifications to admin
class EmailNotificationService {
  static final EmailNotificationService _instance =
      EmailNotificationService._internal();
  factory EmailNotificationService() => _instance;
  EmailNotificationService._internal();

  // Configure these with your actual SMTP settings
  // For Gmail: Use App Password (not your regular password)
  // Generate at: https://myaccount.google.com/apppasswords
  String? _adminEmail;
  String? _smtpUsername;
  String? _smtpPassword;
  String _smtpHost = 'smtp.gmail.com';
  int _smtpPort = 587;

  /// Configure email settings
  void configure({
    required String adminEmail,
    required String smtpUsername,
    required String smtpPassword,
    String? smtpHost,
    int? smtpPort,
  }) {
    _adminEmail = adminEmail;
    _smtpUsername = smtpUsername;
    _smtpPassword = smtpPassword;
    if (smtpHost != null) _smtpHost = smtpHost;
    if (smtpPort != null) _smtpPort = smtpPort;
  }

  /// Check if email is configured
  bool get isConfigured =>
      _adminEmail != null && _smtpUsername != null && _smtpPassword != null;

  /// Send admin login notification
  Future<bool> sendAdminLoginNotification({
    required String adminEmail,
    required String loginTime,
    required String deviceInfo,
    required String ipAddress,
  }) async {
    if (!isConfigured) {
      debugPrint('⚠️ Email notification not configured');
      return false;
    }

    try {
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _smtpUsername,
        password: _smtpPassword,
        ssl: false,
        allowInsecure: true,
      );

      final message = Message()
        ..from = Address(_smtpUsername!, 'Smart Monitoring System')
        ..recipients.add(_adminEmail!)
        ..subject = '🔐 Admin Login Alert - Smart Monitoring System'
        ..html =
            '''
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                        color: white; padding: 20px; border-radius: 8px 8px 0 0; }
              .content { background: #f9f9f9; padding: 20px; border-radius: 0 0 8px 8px; }
              .info-box { background: white; padding: 15px; margin: 10px 0; 
                          border-left: 4px solid #667eea; border-radius: 4px; }
              .label { font-weight: bold; color: #667eea; }
              .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
              .alert { background: #fff3cd; border-left: 4px solid #ffc107; 
                       padding: 10px; margin: 15px 0; border-radius: 4px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h2>🔐 Admin Login Detected</h2>
              </div>
              <div class="content">
                <p>Hello Administrator,</p>
                <p>An admin account login was detected on your Smart Monitoring System.</p>
                
                <div class="info-box">
                  <p><span class="label">Admin Email:</span> $adminEmail</p>
                  <p><span class="label">Login Time:</span> $loginTime</p>
                  <p><span class="label">Device:</span> $deviceInfo</p>
                  <p><span class="label">IP Address:</span> $ipAddress</p>
                </div>

                <div class="alert">
                  <strong>⚠️ Security Notice:</strong><br>
                  If this wasn't you, please secure your account immediately by:
                  <ul>
                    <li>Changing your password</li>
                    <li>Reviewing recent account activity</li>
                    <li>Enabling additional security measures</li>
                  </ul>
                </div>

                <p style="margin-top: 20px;">
                  This is an automated notification to keep your account secure.
                </p>
              </div>
              <div class="footer">
                <p>Smart Monitoring System</p>
                <p>This email was sent automatically. Please do not reply.</p>
              </div>
            </div>
          </body>
          </html>
        ''';

      await send(message, smtpServer);
      debugPrint('✅ Admin login notification sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send email notification: $e');
      return false;
    }
  }

  /// Send low stock alert
  Future<bool> sendLowStockAlert({
    required String productName,
    required int currentStock,
    required int reorderLevel,
  }) async {
    if (!isConfigured) return false;

    try {
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _smtpUsername,
        password: _smtpPassword,
        ssl: false,
        allowInsecure: true,
      );

      final message = Message()
        ..from = Address(_smtpUsername!, 'Smart Monitoring System')
        ..recipients.add(_adminEmail!)
        ..subject = '⚠️ Low Stock Alert - $productName'
        ..html =
            '''
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); 
                        color: white; padding: 20px; border-radius: 8px 8px 0 0; }
              .content { background: #f9f9f9; padding: 20px; border-radius: 0 0 8px 8px; }
              .warning-box { background: #fff3cd; padding: 15px; margin: 10px 0; 
                            border-left: 4px solid #ffc107; border-radius: 4px; }
              .label { font-weight: bold; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h2>⚠️ Low Stock Alert</h2>
              </div>
              <div class="content">
                <p>Hello Administrator,</p>
                <div class="warning-box">
                  <p><span class="label">Product:</span> $productName</p>
                  <p><span class="label">Current Stock:</span> $currentStock units</p>
                  <p><span class="label">Reorder Level:</span> $reorderLevel units</p>
                </div>
                <p>Please restock this item soon to avoid running out.</p>
              </div>
            </div>
          </body>
          </html>
        ''';

      await send(message, smtpServer);
      debugPrint('✅ Low stock alert sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send low stock alert: $e');
      return false;
    }
  }

  /// Send daily sales report
  Future<bool> sendDailySalesReport({
    required String date,
    required double totalSales,
    required int transactionCount,
    required String topProducts,
  }) async {
    if (!isConfigured) return false;

    try {
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _smtpUsername,
        password: _smtpPassword,
        ssl: false,
        allowInsecure: true,
      );

      final message = Message()
        ..from = Address(_smtpUsername!, 'Smart Monitoring System')
        ..recipients.add(_adminEmail!)
        ..subject = '📊 Daily Sales Report - $date'
        ..html =
            '''
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                        color: white; padding: 20px; border-radius: 8px 8px 0 0; }
              .content { background: #f9f9f9; padding: 20px; border-radius: 0 0 8px 8px; }
              .stat-box { background: white; padding: 15px; margin: 10px 0; 
                         border-radius: 4px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
              .label { font-weight: bold; color: #667eea; }
              .amount { font-size: 24px; font-weight: bold; color: #28a745; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h2>📊 Daily Sales Report</h2>
                <p>$date</p>
              </div>
              <div class="content">
                <div class="stat-box">
                  <p><span class="label">Total Sales:</span></p>
                  <p class="amount">${AppCurrency.peso(totalSales)}</p>
                </div>
                <div class="stat-box">
                  <p><span class="label">Total Transactions:</span> $transactionCount</p>
                </div>
                <div class="stat-box">
                  <p><span class="label">Top Products:</span></p>
                  <p>$topProducts</p>
                </div>
              </div>
            </div>
          </body>
          </html>
        ''';

      await send(message, smtpServer);
      debugPrint('✅ Daily sales report sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send daily sales report: $e');
      return false;
    }
  }
}
