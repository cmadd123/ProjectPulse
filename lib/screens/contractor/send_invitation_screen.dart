import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/analytics_service.dart';

class SendInvitationScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final String clientName;
  final String clientEmail;
  final String contractorName;

  const SendInvitationScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.clientName,
    required this.clientEmail,
    required this.contractorName,
  });

  @override
  State<SendInvitationScreen> createState() => _SendInvitationScreenState();
}

class _SendInvitationScreenState extends State<SendInvitationScreen> {
  bool _isSending = false;
  bool _invitationSent = false;
  bool _isLoadingMilestones = false;
  List<Map<String, dynamic>> _milestones = [];
  Map<String, dynamic>? _projectData;

  @override
  void initState() {
    super.initState();
    _loadProjectAndMilestones();
  }

  Future<void> _loadProjectAndMilestones() async {
    setState(() => _isLoadingMilestones = true);

    try {
      // Load project data
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();

      if (projectDoc.exists) {
        _projectData = projectDoc.data();
      }

      // Load milestones
      final milestonesSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .orderBy('order')
          .get();

      setState(() {
        _milestones = milestonesSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'name': data['name'] as String? ?? '',
            'amount': data['amount'] as double? ?? 0.0,
          };
        }).toList();
        _isLoadingMilestones = false;
      });
    } catch (e) {
      setState(() => _isLoadingMilestones = false);
    }
  }

  Future<void> _sendInvitation() async {
    setState(() => _isSending = true);

    try {
      // The Cloud Function triggers on invitation_ready false→true. If the
      // flag is already true from a prior (failed) attempt, setting it to
      // true again won't re-trigger. Reset to false first, then back to true.
      final ref = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId);

      await ref.update({'invitation_ready': false});
      await Future.delayed(const Duration(milliseconds: 400));
      await ref.update({
        'invitation_ready': true,
        'invitation_requested_at': FieldValue.serverTimestamp(),
      });

      Analytics.firstInviteSent(projectId: widget.projectId);

      // Wait briefly to allow Cloud Function to process and write back invitation_sent
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _isSending = false;
        _invitationSent = true;
      });
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send email: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Open the native share sheet so the GC can fire off the invite through
  /// WhatsApp / Slack / any messaging app on their phone.
  Future<void> _shareInvite() async {
    final inviteLink = 'https://projectpulsehub.com/join/${widget.projectId}';
    final msg = 'Hi ${widget.clientName}! I just set up your project in '
        'ProjectPulse so you can track progress, photos, and payments '
        'in one place.\n\nOpen: $inviteLink';
    try {
      await Share.share(msg, subject: widget.projectName);
      Analytics.firstInviteSent(projectId: widget.projectId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open share sheet: $e')),
        );
      }
    }
  }

  Future<void> _sendContractText() async {
    // Wait for project data to load if it hasn't yet
    if (_projectData == null) {
      if (_isLoadingMilestones) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading project data...')),
        );
        return;
      }
      // If not loading but still null, something went wrong - try anyway
    }

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, yyyy');

    // Get project details (with fallbacks)
    final startDate = _projectData?['start_date'] as Timestamp?;
    final endDate = _projectData?['estimated_end_date'] as Timestamp?;
    final startDateStr = startDate != null ? dateFormat.format(startDate.toDate()) : 'TBD';
    final endDateStr = endDate != null ? dateFormat.format(endDate.toDate()) : 'TBD';

    final totalCost = _projectData?['current_cost'] as double? ??
                     _projectData?['original_cost'] as double? ?? 0.0;

    final clientPhone = _projectData?['client_phone'] as String? ?? '';
    final inviteLink = 'https://projectpulsehub.com/join/${widget.projectId}';

    // Build SMS message (with or without milestones)
    String smsMessage;

    if (_milestones.isNotEmpty) {
      // Include milestone details if available
      final milestoneList = _milestones.map((m) {
        return '- ${m['name']}: ${currencyFormat.format(m['amount'])} (paid when work is done)';
      }).join('\n');

      smsMessage = '''Hi ${widget.clientName}! Here's the plan for your ${widget.projectName}:

$milestoneList

Total: ${currencyFormat.format(totalCost)}
Timeline: $startDateStr to $endDateStr

You'll see photo updates after each phase. Payment due within 3 days of completion.

Track progress: $inviteLink

Reply YES to accept and I'll order materials!''';
    } else {
      // Simpler message without milestones
      smsMessage = '''Hi ${widget.clientName}! I've set up your project: ${widget.projectName}

${totalCost > 0 ? 'Total: ${currencyFormat.format(totalCost)}\n' : ''}Timeline: $startDateStr to $endDateStr

Track real-time progress with photos and updates:
$inviteLink

Looking forward to working with you!''';
    }

    try {
      // Construct SMS URI
      final uri = Uri(
        scheme: 'sms',
        path: clientPhone.isNotEmpty ? clientPhone : '',
        queryParameters: {'body': smsMessage},
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback: Copy to clipboard
        await Clipboard.setData(ClipboardData(text: smsMessage));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contract text copied to clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Fallback: Copy to clipboard
      await Clipboard.setData(ClipboardData(text: smsMessage));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contract text copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inviteLink = 'https://projectpulsehub.com/join/${widget.projectId}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Invitation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Icon(
              _invitationSent ? Icons.check_circle : Icons.send_outlined,
              size: 64,
              color: _invitationSent ? Colors.green : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _invitationSent ? 'Invitation Sent!' : 'Invite Your Client',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _invitationSent
                  ? '${widget.clientName} will get your message shortly'
                  : 'Send ${widget.clientName} a link to track their project:',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),

            // Client Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Icon(
                            Icons.person,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.clientName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.clientEmail,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Email Preview Section
            Text(
              'Email Preview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email Header (charcoal to orange gradient matching app)
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2D3748), // Charcoal
                          Color(0xFFFF6B35), // Orange
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(11),
                        topRight: Radius.circular(11),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            '🏗️ ProjectPulse',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "You've been invited to view your project",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Contractor Section with Logo (full-width background)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          // Logo placeholder
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFe9ecef),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFdee2e6),
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                '🏗️',
                                style: TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Contractor info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Contractor',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.contractorName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Email Body
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi ${widget.clientName}!',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${widget.contractorName} has invited you to track your project in real-time:',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            border: const Border(
                              left: BorderSide(
                                color: Color(0xFFFF6B35),
                                width: 4,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '"${widget.projectName}"',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'View daily photo updates, track milestones, and stay connected throughout your project.',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF2D3748), // Charcoal
                                  Color(0xFFFF6B35), // Orange
                                ],
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x4D2D3748), // Charcoal shadow
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              'View Your Project →',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Or copy this link:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                inviteLink,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Primary: Send via Text. Most contractors text their clients
            // — meets them in their existing workflow. Opens the native
            // SMS composer with a prefilled message including the invite link.
            if (!_invitationSent)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingMilestones ? null : _sendContractText,
                  icon: const Icon(Icons.textsms_outlined),
                  label: const Text(
                    'Send via Text',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            // Secondary options: share, copy, or email.
            const SizedBox(height: 16),
            if (!_invitationSent)
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Or share another way',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),

            if (!_invitationSent) const SizedBox(height: 12),
            if (!_invitationSent)
              Row(
                children: [
                  // Share via any app (WhatsApp, Slack, etc.)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingMilestones ? null : _shareInvite,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share…'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Copy link
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: inviteLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Link'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            if (!_invitationSent) const SizedBox(height: 8),
            if (!_invitationSent)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSending ? null : _sendInvitation,
                  icon: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.email_outlined, size: 18),
                  label: Text(_isSending ? 'Sending email…' : 'Send Email Instead'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

            // Post-send state: show share options with real-time status
            if (_invitationSent) ...[
              const SizedBox(height: 16),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('projects')
                    .doc(widget.projectId)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Default state while waiting
                  String statusText = 'Sending invitation email...';
                  Color cardColor = Colors.blue[50]!;
                  Color iconColor = Colors.blue[700]!;
                  Color textColor = Colors.blue[900]!;
                  IconData statusIcon = Icons.email;

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    final invitationSent = data?['invitation_sent'] as Map<String, dynamic>?;

                    if (invitationSent != null) {
                      final emailResult = invitationSent['email'] as Map<String, dynamic>?;

                      if (emailResult != null) {
                        if (emailResult['success'] == true) {
                          statusText = 'Invitation email sent to ${widget.clientEmail}!';
                          cardColor = Colors.green[50]!;
                          iconColor = Colors.green[700]!;
                          textColor = Colors.green[800]!;
                          statusIcon = Icons.check_circle;
                        } else {
                          final error = emailResult['error'] as String? ?? 'Unknown error';
                          statusText = 'Failed to send email: $error';
                          cardColor = Colors.red[50]!;
                          iconColor = Colors.red[700]!;
                          textColor = Colors.red[800]!;
                          statusIcon = Icons.error;
                        }
                      }
                    }
                  }

                  return Card(
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: iconColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      const SizedBox(height: 12),
                      Text(
                        'You can also share the link directly:',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: inviteLink));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Link copied!')),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy Link'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _sendContractText,
                              icon: const Icon(Icons.textsms_outlined, size: 16),
                              label: const Text('Send Text'),
                            ),
                          ),
                        ],
                      ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],

            if (!_invitationSent) const SizedBox(height: 12),
            if (!_invitationSent)
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Skip for now'),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
