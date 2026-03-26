import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'cloud_function_logs_screen.dart';

/// TEMPORARY: Email preview screen for testing email templates
/// This allows quick iteration on email design without triggering actual notifications
class EmailPreviewScreen extends StatefulWidget {
  const EmailPreviewScreen({super.key});

  @override
  State<EmailPreviewScreen> createState() => _EmailPreviewScreenState();
}

class _EmailPreviewScreenState extends State<EmailPreviewScreen> {
  String selectedEmailType = 'project_invitation';

  final Map<String, String> emailTypes = {
    'project_invitation': 'Project Invitation',
    'milestone_started': 'Milestone Started',
    'milestone_completed': 'Milestone Completed',
    'change_order': 'Change Order Submitted',
    'milestone_approved': 'Milestone Approved',
    'change_order_approved': 'Change Order Approved',
    'change_order_declined': 'Change Order Declined',
    'quality_issue': 'Quality Issue Reported',
    'addition_requested': 'Addition Requested',
    'option_b_custom_color': '🎨 Option B - Custom Color Picker',
    'option_c_curated': '🎨 Option C - Curated Palette',
    'option_d_shopify': '⭐ Option D - Shopify Style (RECOMMENDED)',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Preview'),
        backgroundColor: const Color(0xFF8B5CF6),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CloudFunctionLogsScreen(),
                ),
              );
            },
            tooltip: 'View Email Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Email type selector
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: selectedEmailType,
              decoration: const InputDecoration(
                labelText: 'Select Email Type',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              items: emailTypes.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedEmailType = value;
                  });
                }
              },
            ),
          ),
          // Email preview
          Expanded(
            child: InAppWebView(
              key: ValueKey(selectedEmailType), // Force rebuild when email type changes
              initialData: InAppWebViewInitialData(
                data: _getEmailHtml(selectedEmailType),
                encoding: 'utf-8',
                mimeType: 'text/html',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getEmailHtml(String type) {
    switch (type) {
      case 'project_invitation':
        return _getProjectInvitationEmail();
      case 'milestone_started':
        return _getMilestoneStartedEmail();
      case 'milestone_completed':
        return _getMilestoneCompletedEmail();
      case 'change_order':
        return _getChangeOrderEmail();
      case 'milestone_approved':
        return _getMilestoneApprovedEmail();
      case 'change_order_approved':
        return _getChangeOrderResponseEmail(true);
      case 'change_order_declined':
        return _getChangeOrderResponseEmail(false);
      case 'quality_issue':
        return _getClientRequestEmail(true);
      case 'addition_requested':
        return _getClientRequestEmail(false);
      case 'option_b_custom_color':
        return _getOptionBCustomColorEmail();
      case 'option_c_curated':
        return _getOptionCCuratedEmail();
      case 'option_d_shopify':
        return _getOptionDShopifyStyleEmail();
      default:
        return '<h1>Unknown email type</h1>';
    }
  }

  String _getProjectInvitationEmail() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      margin: 0;
      padding: 20px;
      background: #f8f9fa;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background: white;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    }
    .header {
      background: linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%);
      color: white;
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      margin: 0 0 8px 0;
      font-size: 28px;
      font-weight: 700;
    }
    .header p {
      margin: 0;
      opacity: 0.95;
      font-size: 16px;
    }
    .content {
      padding: 30px;
    }
    .project-box {
      background: #f3e8ff;
      border-left: 4px solid #8B5CF6;
      padding: 20px;
      margin: 20px 0;
      border-radius: 8px;
    }
    .project-name {
      color: #6b21a8;
      font-weight: 600;
      font-size: 20px;
      margin: 0 0 8px 0;
    }
    .contractor-name {
      color: #6b7280;
      font-size: 14px;
      margin: 0;
    }
    .button {
      display: inline-block;
      padding: 14px 32px;
      background: linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%);
      color: white;
      text-decoration: none;
      border-radius: 8px;
      font-weight: 600;
      font-size: 16px;
      margin: 20px 0;
    }
    .footer {
      background: #f8f9fa;
      padding: 20px 30px;
      text-align: center;
      color: #6b7280;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🎉 You've Been Invited!</h1>
      <p>Track your project in real-time</p>
    </div>
    <div class="content">
      <p>Hi <strong>Sarah Smith</strong>!</p>
      <p><strong>Smith Contracting</strong> has invited you to track your project on ProjectPulse.</p>
      <div class="project-box">
        <p class="project-name">Kitchen Remodel</p>
        <p class="contractor-name">Smith Contracting</p>
      </div>
      <p>With ProjectPulse, you'll be able to:</p>
      <ul>
        <li>See daily photo updates</li>
        <li>Track milestone progress</li>
        <li>Approve payments securely</li>
        <li>Chat with your contractor</li>
      </ul>
      <p style="text-align: center;">
        <a href="#" class="button">View Your Project →</a>
      </p>
    </div>
    <div class="footer">
      <p><strong>ProjectPulse</strong> · Real-time project communication</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  String _getMilestoneStartedEmail() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #3B82F6 0%, #2563EB 100%); color: white; padding: 40px 30px; text-align: center; }
    .header h1 { margin: 0 0 8px 0; font-size: 28px; font-weight: 700; }
    .header p { margin: 0; opacity: 0.95; font-size: 16px; }
    .content { padding: 30px; }
    .milestone-box { background: #eff6ff; border-left: 4px solid #3B82F6; padding: 20px; margin: 20px 0; border-radius: 8px; }
    .milestone-name { color: #1e40af; font-weight: 600; font-size: 20px; margin: 0 0 8px 0; }
    .project-name { color: #6b7280; font-size: 14px; margin: 0; }
    .button { display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #3B82F6 0%, #2563EB 100%); color: white; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 20px 0; }
    .info-box { background: #f8f9fa; padding: 16px; border-radius: 8px; margin: 20px 0; }
    .info-box p { margin: 0 0 8px 0; font-size: 14px; color: #4b5563; }
    .footer { background: #f8f9fa; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🚀 Work Started</h1>
      <p>New milestone in progress</p>
    </div>
    <div class="content">
      <p>Hi <strong>Sarah</strong>!</p>
      <p><strong>Smith Contracting</strong> has started work on a new milestone.</p>
      <div class="milestone-box">
        <p class="milestone-name">Demolition & Prep</p>
        <p class="project-name">Kitchen Remodel</p>
      </div>
      <div class="info-box">
        <p><strong>What's happening:</strong></p>
        <p>• Work is now in progress on this phase</p>
        <p>• You'll see photo updates as work progresses</p>
        <p>• You'll be notified when it's ready for approval</p>
      </div>
      <p style="text-align: center;">
        <a href="#" class="button">View Project →</a>
      </p>
    </div>
    <div class="footer">
      <p><strong>ProjectPulse</strong> · Real-time project communication</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  String _getMilestoneCompletedEmail() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #10B981 0%, #059669 100%); color: white; padding: 40px 30px; text-align: center; }
    .header h1 { margin: 0 0 8px 0; font-size: 28px; font-weight: 700; }
    .header p { margin: 0; opacity: 0.95; font-size: 16px; }
    .content { padding: 30px; }
    .milestone-box { background: #d1fae5; border-left: 4px solid #10B981; padding: 20px; margin: 20px 0; border-radius: 8px; }
    .milestone-name { color: #065f46; font-weight: 600; font-size: 20px; margin: 0 0 8px 0; }
    .project-name { color: #6b7280; font-size: 14px; margin: 0; }
    .button { display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #10B981 0%, #059669 100%); color: white; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 20px 0; }
    .footer { background: #f8f9fa; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>✓ Milestone Complete</h1>
      <p>Ready for your review</p>
    </div>
    <div class="content">
      <p>Hi <strong>Sarah</strong>!</p>
      <p><strong>Smith Contracting</strong> has completed a milestone.</p>
      <div class="milestone-box">
        <p class="milestone-name">Demolition & Prep</p>
        <p class="project-name">Kitchen Remodel</p>
      </div>
      <p>Please review the photos and approve the milestone to release payment.</p>
      <p style="text-align: center;">
        <a href="#" class="button">Review & Approve →</a>
      </p>
    </div>
    <div class="footer">
      <p><strong>ProjectPulse</strong> · Real-time project communication</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  String _getChangeOrderEmail() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #F59E0B 0%, #D97706 100%); color: white; padding: 40px 30px; text-align: center; }
    .header h1 { margin: 0 0 8px 0; font-size: 28px; font-weight: 700; }
    .header p { margin: 0; opacity: 0.95; font-size: 16px; }
    .content { padding: 30px; }
    .change-order-box { background: #fef3c7; border-left: 4px solid #F59E0B; padding: 20px; margin: 20px 0; border-radius: 8px; }
    .cost-change { color: #92400e; font-weight: 700; font-size: 24px; margin: 0 0 8px 0; }
    .description { color: #6b7280; font-size: 14px; margin: 0; }
    .button { display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #F59E0B 0%, #D97706 100%); color: white; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 10px 5px; }
    .footer { background: #f8f9fa; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>📋 Change Order Submitted</h1>
      <p>Requires your approval</p>
    </div>
    <div class="content">
      <p>Hi <strong>Sarah</strong>!</p>
      <p><strong>Smith Contracting</strong> has submitted a change order.</p>
      <div class="change-order-box">
        <p class="cost-change">+\$850.00</p>
        <p class="description">Additional electrical outlet in pantry + upgraded light fixture</p>
      </div>
      <p>Please review and respond to this change order.</p>
      <p style="text-align: center;">
        <a href="#" class="button">Approve</a>
        <a href="#" class="button" style="background: #6b7280;">Decline</a>
      </p>
    </div>
    <div class="footer">
      <p><strong>ProjectPulse</strong> · Real-time project communication</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  String _getMilestoneApprovedEmail() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #10B981 0%, #059669 100%); color: white; padding: 40px 30px; text-align: center; }
    .header h1 { margin: 0 0 8px 0; font-size: 28px; font-weight: 700; }
    .header p { margin: 0; opacity: 0.95; font-size: 16px; }
    .content { padding: 30px; }
    .payment-box { background: #d1fae5; border-left: 4px solid #10B981; padding: 20px; margin: 20px 0; border-radius: 8px; }
    .amount { color: #065f46; font-weight: 700; font-size: 24px; margin: 0 0 8px 0; }
    .milestone { color: #6b7280; font-size: 14px; margin: 0; }
    .info-box { background: #f8f9fa; padding: 16px; border-radius: 8px; margin: 20px 0; }
    .button { display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #10B981 0%, #059669 100%); color: white; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 20px 0; }
    .footer { background: #f8f9fa; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>✓ Milestone Approved</h1>
      <p>Payment is being processed</p>
    </div>
    <div class="content">
      <p>Hi <strong>John</strong>!</p>
      <p>Good news! Your client has approved a milestone payment.</p>
      <div class="payment-box">
        <p class="amount">\$3,500.00</p>
        <p class="milestone">Demolition & Prep</p>
      </div>
      <div class="info-box">
        <p><strong>Payment Timeline:</strong></p>
        <p>• Funds are being processed by Stripe</p>
        <p>• Expected in your account: 2-3 business days</p>
        <p>• You'll receive a confirmation when deposited</p>
      </div>
      <p style="text-align: center;">
        <a href="#" class="button">View Project →</a>
      </p>
    </div>
    <div class="footer">
      <p><strong>ProjectPulse</strong> · Real-time project communication</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  String _getChangeOrderResponseEmail(bool approved) {
    final color = approved ? '#10B981' : '#EF4444';
    final gradient = approved
        ? 'linear-gradient(135deg, #10B981 0%, #059669 100%)'
        : 'linear-gradient(135deg, #EF4444 0%, #DC2626 100%)';
    final bgColor = approved ? '#d1fae5' : '#fee2e2';
    final textColor = approved ? '#065f46' : '#991b1b';
    final title = approved ? '✓ Change Order Approved' : '✗ Change Order Declined';
    final message = approved
        ? 'Your client has approved the change order.'
        : 'Your client has declined the change order.';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
    .header { background: $gradient; color: white; padding: 40px 30px; text-align: center; }
    .header h1 { margin: 0 0 8px 0; font-size: 28px; font-weight: 700; }
    .header p { margin: 0; opacity: 0.95; font-size: 16px; }
    .content { padding: 30px; }
    .response-box { background: $bgColor; border-left: 4px solid $color; padding: 20px; margin: 20px 0; border-radius: 8px; }
    .amount { color: $textColor; font-weight: 700; font-size: 24px; margin: 0 0 8px 0; }
    .description { color: #6b7280; font-size: 14px; margin: 0; }
    .button { display: inline-block; padding: 14px 32px; background: $gradient; color: white; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 20px 0; }
    .footer { background: #f8f9fa; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>$title</h1>
      <p>Client has responded</p>
    </div>
    <div class="content">
      <p>Hi <strong>John</strong>!</p>
      <p>$message</p>
      <div class="response-box">
        <p class="amount">+\$850.00</p>
        <p class="description">Additional electrical outlet in pantry + upgraded light fixture</p>
      </div>
      <p style="text-align: center;">
        <a href="#" class="button">View Project →</a>
      </p>
    </div>
    <div class="footer">
      <p><strong>ProjectPulse</strong> · Real-time project communication</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  String _getClientRequestEmail(bool isQualityIssue) {
    final color = isQualityIssue ? '#F59E0B' : '#8B5CF6';
    final gradient = isQualityIssue
        ? 'linear-gradient(135deg, #F59E0B 0%, #D97706 100%)'
        : 'linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%)';
    final bgColor = isQualityIssue ? '#fef3c7' : '#f3e8ff';
    final textColor = isQualityIssue ? '#92400e' : '#6b21a8';
    final icon = isQualityIssue ? '⚠️' : '💡';
    final title = isQualityIssue ? 'Quality Issue Reported' : 'Addition Requested';
    final message = isQualityIssue
        ? 'has reported a quality issue on your project.'
        : 'wants to add something to your project.';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
    .header { background: $gradient; color: white; padding: 40px 30px; text-align: center; }
    .header h1 { margin: 0 0 8px 0; font-size: 28px; font-weight: 700; }
    .header p { margin: 0; opacity: 0.95; font-size: 16px; }
    .content { padding: 30px; }
    .request-box { background: $bgColor; border-left: 4px solid $color; padding: 20px; margin: 20px 0; border-radius: 8px; }
    .request-title { color: $textColor; font-weight: 600; font-size: 18px; margin: 0 0 8px 0; }
    .request-text { color: #6b7280; font-size: 14px; margin: 0; }
    .button { display: inline-block; padding: 14px 32px; background: $gradient; color: white; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 20px 0; }
    .footer { background: #f8f9fa; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>$icon $title</h1>
      <p>Requires your attention</p>
    </div>
    <div class="content">
      <p>Hi <strong>John</strong>!</p>
      <p><strong>Sarah Smith</strong> $message</p>
      <div class="request-box">
        <p class="request-title">Kitchen Remodel</p>
        <p class="request-text">The cabinet door alignment looks off on the corner unit. Can this be adjusted?</p>
      </div>
      <p style="text-align: center;">
        <a href="#" class="button">View & Respond →</a>
      </p>
    </div>
    <div class="footer">
      <p><strong>ProjectPulse</strong> · Real-time project communication</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  /// Option B: Custom Color Picker - Contractor chooses any color for email header
  /// Example: Smith Contracting uses their brand color (orange #FF6B35)
  String _getOptionBCustomColorEmail() {
    const contractorBrandColor = '#FF6B35'; // Example: Contractor's custom orange

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
    .header { background: $contractorBrandColor; color: white; padding: 40px 30px; text-align: center; }
    .header h1 { margin: 0 0 8px 0; font-size: 28px; font-weight: 700; }
    .header p { margin: 0; opacity: 0.95; font-size: 16px; }
    .contractor-name { font-size: 18px; font-weight: 600; margin-bottom: 12px; opacity: 0.95; }
    .content { padding: 30px; }
    .milestone-box { background: #fff5f0; border-left: 4px solid $contractorBrandColor; padding: 20px; margin: 20px 0; border-radius: 8px; }
    .milestone-name { color: #9a3412; font-weight: 600; font-size: 20px; margin: 0 0 8px 0; }
    .project-name { color: #6b7280; font-size: 14px; margin: 0; }
    .button { display: inline-block; padding: 14px 32px; background: $contractorBrandColor; color: white; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 20px 0; }
    .info-box { background: #f8f9fa; padding: 16px; border-radius: 8px; margin: 20px 0; }
    .info-box p { margin: 0 0 8px 0; font-size: 14px; color: #4b5563; }
    .footer { background: #f8f9fa; padding: 20px 30px; text-align: center; font-size: 13px; }
    .contractor-contact { color: #374151; margin-bottom: 12px; }
    .contractor-contact strong { display: block; margin-bottom: 4px; }
    .powered-by { color: #9ca3af; font-size: 12px; margin-top: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <p class="contractor-name">Smith Contracting</p>
      <h1>✓ Milestone Complete</h1>
      <p>Ready for your review</p>
    </div>
    <div class="content">
      <p>Hi <strong>Sarah</strong>!</p>
      <p>Great news! We just wrapped up the Demolition & Prep work.</p>
      <div class="milestone-box">
        <p class="milestone-name">Demolition & Prep</p>
        <p class="project-name">Kitchen Remodel</p>
      </div>
      <p>I've posted photos so you can see the progress. Take a look and let me know if it looks good to you. Once you approve, we'll move on to the next phase.</p>
      <p style="text-align: center;">
        <a href="#" class="button">View Photos & Approve →</a>
      </p>
    </div>
    <div class="footer">
      <div class="contractor-contact">
        <strong>Questions about your project?</strong>
        <p style="margin: 4px 0;">John Smith, Smith Contracting</p>
        <p style="margin: 4px 0;">(555) 123-4567 • john@smithcontracting.com</p>
      </div>
      <p class="powered-by">Powered by ProjectPulse</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  /// Option C: Curated Palette - Contractor picks from 8 preset professional colors
  /// Example: Showing "Forest Green" (#047857) option
  String _getOptionCCuratedEmail() {
    const curatedColor = '#047857'; // Forest Green (one of 8 preset options)
    const curatedColorLight = '#d1fae5'; // Light version for boxes
    const curatedColorDark = '#065f46'; // Dark version for text

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, $curatedColor 0%, #065f46 100%); color: white; padding: 40px 30px; text-align: center; }
    .header h1 { margin: 0 0 8px 0; font-size: 28px; font-weight: 700; }
    .header p { margin: 0; opacity: 0.95; font-size: 16px; }
    .contractor-name { font-size: 18px; font-weight: 600; margin-bottom: 12px; opacity: 0.95; }
    .content { padding: 30px; }
    .change-order-box { background: $curatedColorLight; border-left: 4px solid $curatedColor; padding: 20px; margin: 20px 0; border-radius: 8px; }
    .cost-change { color: $curatedColorDark; font-weight: 700; font-size: 24px; margin: 0 0 8px 0; }
    .description { color: #6b7280; font-size: 14px; margin: 0; }
    .button { display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, $curatedColor 0%, #065f46 100%); color: white; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 10px 5px; }
    .palette-note { background: #f0fdf4; border: 1px solid $curatedColor; padding: 12px; border-radius: 8px; margin: 20px 0; font-size: 13px; color: #166534; }
    .footer { background: #f8f9fa; padding: 20px 30px; text-align: center; font-size: 13px; }
    .contractor-contact { color: #374151; margin-bottom: 12px; }
    .contractor-contact strong { display: block; margin-bottom: 4px; }
    .powered-by { color: #9ca3af; font-size: 12px; margin-top: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <p class="contractor-name">Smith Contracting</p>
      <h1>📋 Change Order Submitted</h1>
      <p>Requires your approval</p>
    </div>
    <div class="content">
      <p>Hi <strong>Sarah</strong>!</p>
      <p>I've submitted a change order for your review.</p>
      <div class="change-order-box">
        <p class="cost-change">+\$850.00</p>
        <p class="description">Additional electrical outlet in pantry + upgraded light fixture</p>
      </div>
      <div class="palette-note">
        <strong>📐 Curated Palette Example:</strong> This email uses "Forest Green" - one of 8 professionally-selected color options contractors can choose from. Options include: Navy Blue, Forest Green, Warm Orange, Charcoal, Deep Purple, Teal, Burgundy, and Slate Blue.
      </div>
      <p>Please review and respond to this change order at your convenience.</p>
      <p style="text-align: center;">
        <a href="#" class="button">Approve</a>
        <a href="#" class="button" style="background: #6b7280;">Decline</a>
      </p>
    </div>
    <div class="footer">
      <div class="contractor-contact">
        <strong>Questions about your project?</strong>
        <p style="margin: 4px 0;">John Smith, Smith Contracting</p>
        <p style="margin: 4px 0;">(555) 123-4567 • john@smithcontracting.com</p>
      </div>
      <p class="powered-by">Powered by ProjectPulse</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  /// Option D: Shopify-Style Hybrid (RECOMMENDED FOR MVP)
  /// Contractor logo at top, ProjectPulse branded header, full contact info in footer
  /// This is the most common pattern used by Shopify, Calendly, Square
  String _getOptionDShopifyStyleEmail() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }

    /* Contractor Logo Section */
    .logo-section { background: white; padding: 24px 30px 16px 30px; text-align: center; border-bottom: 1px solid #e5e7eb; }
    .contractor-logo { width: 120px; height: 60px; background: #f3f4f6; border-radius: 8px; display: inline-flex; align-items: center; justify-content: center; color: #6b7280; font-size: 12px; font-weight: 600; }

    /* ProjectPulse Branded Header */
    .header { background: linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%); color: white; padding: 32px 30px; text-align: center; }
    .header-subtitle { font-size: 14px; opacity: 0.9; margin-bottom: 8px; font-weight: 500; }
    .header h1 { margin: 0 0 6px 0; font-size: 28px; font-weight: 700; }
    .header p { margin: 0; opacity: 0.95; font-size: 15px; }

    /* Content */
    .content { padding: 30px; line-height: 1.6; }
    .content p { margin: 0 0 16px 0; color: #374151; }
    .milestone-box { background: #f3e8ff; border-left: 4px solid #8B5CF6; padding: 18px; margin: 20px 0; border-radius: 8px; }
    .milestone-name { color: #6b21a8; font-weight: 600; font-size: 18px; margin: 0 0 6px 0; }
    .project-name { color: #6b7280; font-size: 14px; margin: 0; }

    /* Button */
    .button { display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%); color: white; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 20px 0; }

    /* Footer with Full Contact Info */
    .footer { background: #f8f9fa; padding: 24px 30px; border-top: 1px solid #e5e7eb; }
    .footer-section { margin-bottom: 16px; }
    .footer-title { font-weight: 600; color: #374151; font-size: 14px; margin: 0 0 8px 0; }
    .footer-text { color: #6b7280; font-size: 14px; margin: 4px 0; line-height: 1.5; }
    .footer-text strong { color: #374151; }
    .powered-by { color: #9ca3af; font-size: 12px; text-align: center; margin-top: 16px; padding-top: 16px; border-top: 1px solid #e5e7eb; }

    /* Explainer Note */
    .explainer-note { background: #eff6ff; border: 1px solid #3B82F6; padding: 16px; border-radius: 8px; margin: 24px 0; font-size: 13px; color: #1e40af; line-height: 1.5; }
    .explainer-note strong { display: block; margin-bottom: 8px; color: #1e3a8a; }
  </style>
</head>
<body>
  <div class="container">
    <!-- Contractor Logo at Top (White Background) -->
    <div class="logo-section">
      <div class="contractor-logo">
        SMITH<br>CONTRACTING
      </div>
    </div>

    <!-- ProjectPulse Branded Header -->
    <div class="header">
      <p class="header-subtitle">John Smith via ProjectPulse</p>
      <h1>✓ Milestone Complete</h1>
      <p>Ready for your review</p>
    </div>

    <!-- Email Content -->
    <div class="content">
      <p>Hi <strong>Sarah</strong>!</p>
      <p>Great news! We just finished the demolition and prep work on your kitchen remodel. I've posted photos so you can see the progress.</p>

      <div class="milestone-box">
        <p class="milestone-name">Demolition & Prep</p>
        <p class="project-name">Kitchen Remodel</p>
      </div>

      <div class="explainer-note">
        <strong>📐 Shopify-Style Branding (Option D - RECOMMENDED):</strong>
        This approach balances contractor branding (logo at top, contact in footer) with ProjectPulse brand identity (colored header, "via ProjectPulse" attribution). It's the most common pattern used by successful platforms like Shopify, Calendly, and Square. Benefits: (1) Simple setup - no color picker needed, (2) Professional consistency across all emails, (3) Builds ProjectPulse brand recognition, (4) Contractor gets full contact info in footer.
      </div>

      <p>Please take a look and let me know if everything looks good. Once you approve, we'll move on to the next phase.</p>

      <p style="text-align: center;">
        <a href="#" class="button">View Photos & Approve →</a>
      </p>
    </div>

    <!-- Footer with Full Contractor Contact Info -->
    <div class="footer">
      <div class="footer-section">
        <p class="footer-title">Questions about your project?</p>
        <p class="footer-text"><strong>John Smith</strong>, Smith Contracting</p>
        <p class="footer-text">📞 (555) 123-4567</p>
        <p class="footer-text">✉️ john@smithcontracting.com</p>
        <p class="footer-text">🌐 www.smithcontracting.com</p>
      </div>

      <p class="powered-by">Powered by ProjectPulse</p>
    </div>
  </div>
</body>
</html>
    ''';
  }
}
