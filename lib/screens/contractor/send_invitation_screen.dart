import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

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
      print('Error loading milestones: $e');
    }
  }

  Future<void> _sendInvitation() async {
    setState(() => _isSending = true);

    try {
      // Update project with invitation_ready flag
      // This triggers the Cloud Function to send the email
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({
        'invitation_ready': true,
        'invitation_requested_at': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isSending = false;
        _invitationSent = true;
      });

      // Wait a moment to show success, then return
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _sendContractText() async {
    if (_milestones.isEmpty || _projectData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading project data...')),
      );
      return;
    }

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, yyyy');

    // Build milestone list for SMS
    final milestoneList = _milestones.map((m) {
      return '- ${m['name']}: ${currencyFormat.format(m['amount'])} (paid when work is done)';
    }).join('\n');

    // Get dates
    final startDate = _projectData!['start_date'] as Timestamp?;
    final endDate = _projectData!['estimated_end_date'] as Timestamp?;
    final startDateStr = startDate != null ? dateFormat.format(startDate.toDate()) : 'TBD';
    final endDateStr = endDate != null ? dateFormat.format(endDate.toDate()) : 'TBD';

    // Calculate total cost from project
    final totalCost = _projectData!['current_cost'] as double? ??
                     _projectData!['original_cost'] as double? ?? 0.0;

    // Get client phone (if exists)
    final clientPhone = _projectData!['client_phone'] as String? ?? '';

    final inviteLink = 'https://projectpulse-7d258.web.app/join/${widget.projectId}';

    // Build SMS message
    final smsMessage = '''Hi ${widget.clientName}! Here's the plan for your ${widget.projectName}:

$milestoneList

Total: ${currencyFormat.format(totalCost)}
Timeline: $startDateStr to $endDateStr

You'll see photo updates after each phase. Payment due within 3 days of completion.

Track progress: $inviteLink

Reply YES to accept and I'll order materials!''';

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
    final inviteLink = 'https://projectpulse-7d258.web.app/join/${widget.projectId}';

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
              _invitationSent ? Icons.check_circle : Icons.email_outlined,
              size: 64,
              color: _invitationSent ? Colors.green : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _invitationSent ? 'Invitation Sent!' : 'Ready to Invite Client',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _invitationSent
                  ? '${widget.clientName} will receive an email shortly'
                  : 'An invitation email will be sent to:',
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

            // Send Button
            if (!_invitationSent)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendInvitation,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSending ? 'Sending...' : 'Send Invitation',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            // SMS Contract Template Button
            if (!_invitationSent) const SizedBox(height: 12),
            if (!_invitationSent)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingMilestones ? null : _sendContractText,
                  icon: _isLoadingMilestones
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : const Icon(Icons.text_snippet_outlined),
                  label: Text(
                    _isLoadingMilestones ? 'Loading...' : 'Send Contract Text',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            if (!_invitationSent) const SizedBox(height: 8),
            if (!_invitationSent)
              Text(
                'Opens your SMS app with project details pre-filled',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 8),
            if (!_invitationSent)
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Skip for now'),
              ),
          ],
        ),
      ),
    );
  }
}
