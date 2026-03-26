import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import 'debug_console.dart';

/// Activity feed widget showing all quality issues and addition requests for a project
class ClientChangesActivityWidget extends StatelessWidget {
  final String projectId;
  final String userRole; // "contractor" or "client"

  const ClientChangesActivityWidget({
    super.key,
    required this.projectId,
    required this.userRole,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'fixed':
        return Colors.green;
      case 'quoted':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'declined':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String type, String status) {
    if (type == 'quality_issue') {
      return status == 'pending' ? 'Needs Fix' : 'Fixed';
    } else {
      // addition_request
      switch (status) {
        case 'pending':
          return 'Awaiting Quote';
        case 'quoted':
          return 'Quoted';
        case 'approved':
          return 'Approved';
        case 'declined':
          return 'Declined';
        default:
          return status;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('client_changes')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userRole == 'contractor'
                        ? 'No client requests yet'
                        : 'No requests submitted yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userRole == 'contractor'
                        ? 'Client change requests will appear here'
                        : 'Your quality issues and addition requests will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final changes = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: changes.length,
          itemBuilder: (context, index) {
            final change = changes[index];
            final data = change.data() as Map<String, dynamic>;
            final type = data['type'] as String;
            final status = data['status'] as String;
            final requestText = data['request_text'] as String;
            final photoUrl = data['photo_url'] as String?;
            final milestoneName = data['milestone_name'] as String?;
            final createdAt = data['created_at'] as Timestamp?;
            final contractorResponse = data['contractor_response'] as Map<String, dynamic>?;

            final isQualityIssue = type == 'quality_issue';
            final iconColor = isQualityIssue ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
            final statusColor = _getStatusColor(status);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isQualityIssue ? Icons.report_problem_outlined : Icons.add_circle_outline,
                            color: iconColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isQualityIssue ? 'Quality Issue' : 'Addition Request',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (milestoneName != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        milestoneName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _getStatusLabel(type, status),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Request text
                    Text(
                      requestText,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),

                    // Photo if available
                    if (photoUrl != null) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          photoUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 180,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 40),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // Contractor response (if exists)
                    if (contractorResponse != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.reply, size: 12, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Contractor Response',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[800],
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (contractorResponse['type'] == 'quote') ...[
                              Text(
                                '\$${(contractorResponse['quoted_amount'] as num).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF3B82F6),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (contractorResponse['text'] != null && contractorResponse['text'].toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  contractorResponse['text'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ] else if (contractorResponse['type'] == 'decline') ...[
                              Text(
                                contractorResponse['text'] ?? 'Request declined',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Footer: Timestamp and Actions
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          createdAt != null ? _formatTimestamp(createdAt) : 'Just now',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),

                        // Action buttons for contractor
                        if (userRole == 'contractor') ...[
                          if (isQualityIssue && status == 'pending')
                            ElevatedButton.icon(
                              onPressed: () => _markAsFixed(context, change.id, data),
                              icon: const Icon(Icons.check_circle, size: 17),
                              label: const Text('Mark Fixed'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          if (!isQualityIssue && status == 'pending')
                            ElevatedButton.icon(
                              onPressed: () => _provideQuote(context, change.id, data),
                              icon: const Icon(Icons.monetization_on_outlined, size: 17),
                              label: const Text('Quote'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                        ],

                        // Action buttons for client
                        if (userRole == 'client') ...[
                          if (!isQualityIssue && status == 'quoted')
                            ElevatedButton.icon(
                              onPressed: () => _approveQuote(context, change.id, data),
                              icon: const Icon(Icons.check_circle, size: 17),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _markAsFixed(BuildContext context, String changeId, Map<String, dynamic> data) async {
    DebugConsole().log('🔍 CLIENT CHANGES ACTIVITY - "Mark as Fixed" tapped for $changeId');
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('client_changes')
          .doc(changeId)
          .update({
        'status': 'fixed',
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Get project name for notification
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();
      final projectName = projectDoc.data()?['project_name'] ?? 'Project';

      // Send notification to client
      await NotificationService.sendQualityIssueFixedNotification(
        projectId: projectId,
        projectName: projectName,
        description: data['request_text'] ?? '',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Marked as fixed. Client notified.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      DebugConsole().log('✅ CLIENT CHANGES ACTIVITY - Successfully marked as fixed');
    } catch (e) {
      DebugConsole().log('❌ CLIENT CHANGES ACTIVITY - Error marking as fixed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _provideQuote(BuildContext context, String changeId, Map<String, dynamic> data) async {
    // Show dialog for quote amount and optional note
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Provide Quote'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Quote Amount',
                  prefixText: '\$',
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Additional details...',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (amountController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a quote amount')),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Submit Quote'),
          ),
        ],
      ),
    );

    if (result != true || !context.mounted) return;

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('client_changes')
          .doc(changeId)
          .update({
        'status': 'quoted',
        'contractor_response': {
          'type': 'quote',
          'quoted_amount': amount,
          'text': noteController.text.trim(),
        },
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Get project name for notification
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();
      final projectName = projectDoc.data()?['project_name'] ?? 'Project';

      // Send notification to client
      await NotificationService.sendAdditionQuotedNotification(
        projectId: projectId,
        projectName: projectName,
        quotedAmount: amount,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Quote submitted. Client notified.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveQuote(BuildContext context, String changeId, Map<String, dynamic> data) async {
    DebugConsole().log('🔍 CLIENT CHANGES ACTIVITY - "Approve Quote" tapped for $changeId');

    final contractorResponse = data['contractor_response'] as Map<String, dynamic>?;
    final quotedAmount = contractorResponse?['quoted_amount'] as num?;

    if (quotedAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quote amount not found')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve Quote'),
        content: Text(
          'Approve quote of \$${quotedAmount.toStringAsFixed(2)}?\n\nThis will add the cost to your project total.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('client_changes')
          .doc(changeId)
          .update({
        'status': 'approved',
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Get project name for notification
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();
      final projectName = projectDoc.data()?['project_name'] ?? 'Project';

      // Send notification to contractor
      await NotificationService.sendAdditionApprovedNotification(
        projectId: projectId,
        projectName: projectName,
        quotedAmount: quotedAmount.toDouble(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Quote approved. Contractor notified.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      DebugConsole().log('✅ CLIENT CHANGES ACTIVITY - Successfully approved quote');
    } catch (e) {
      DebugConsole().log('❌ CLIENT CHANGES ACTIVITY - Error approving quote: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago • ${DateFormat('MMM d, h:mm a').format(dateTime)}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
