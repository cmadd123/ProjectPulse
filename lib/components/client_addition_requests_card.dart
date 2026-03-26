import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

/// Card that shows addition requests for client (approval flow)
class ClientAdditionRequestsCard extends StatelessWidget {
  final String projectId;
  final String milestoneId;

  const ClientAdditionRequestsCard({
    super.key,
    required this.projectId,
    required this.milestoneId,
  });

  Future<void> _approveQuote(
    BuildContext context,
    String changeId,
    String projectName,
    String description,
    double quotedAmount,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve Quote'),
        content: Text(
          'Approve addition for \$${quotedAmount.toStringAsFixed(2)}?\n\n'
          'This will be added to your project total.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Create a change order from the approved addition
      final changeOrderRef = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('change_orders')
          .add({
        'description': description,
        'cost_change': quotedAmount,
        'status': 'approved',
        'milestone_ref': FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('milestones')
            .doc(milestoneId),
        'requested_at': FieldValue.serverTimestamp(),
        'responded_at': FieldValue.serverTimestamp(),
        'source': 'client_addition', // Track that this came from client request
      });

      // Update the addition request status and link to change order
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('client_changes')
          .doc(changeId)
          .update({
        'status': 'approved',
        'change_order_ref': changeOrderRef,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update project current cost
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();
      final currentCost = (projectDoc.data()?['current_cost'] as num?)?.toDouble() ?? 0.0;
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({
        'current_cost': currentCost + quotedAmount,
      });

      // Send notification to contractor
      await NotificationService.sendAdditionApprovedNotification(
        projectId: projectId,
        projectName: projectName,
        quotedAmount: quotedAmount,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Addition approved. Contractor notified.'),
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

  Future<void> _declineQuote(
    BuildContext context,
    String changeId,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline Quote'),
        content: const Text(
          'Decline this addition request?\n\n'
          'The contractor will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('client_changes')
          .doc(changeId)
          .update({
        'status': 'declined',
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Quote declined.'),
            backgroundColor: Colors.grey,
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

  @override
  Widget build(BuildContext context) {
    final milestoneRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('milestones')
        .doc(milestoneId);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('client_changes')
          .where('type', isEqualTo: 'addition_request')
          .where('milestone_ref', isEqualTo: milestoneRef)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data!.docs;
        final quotedRequests = requests.where((doc) => doc['status'] == 'quoted').toList();

        // Only show if there are quoted requests awaiting approval
        if (quotedRequests.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pending_actions,
                      color: Color(0xFF3B82F6),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Quotes Awaiting Approval',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${quotedRequests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Quoted requests
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: quotedRequests.length,
                itemBuilder: (context, index) {
                  final request = quotedRequests[index];
                  final data = request.data() as Map<String, dynamic>;
                  final response = data['contractor_response'] as Map<String, dynamic>?;

                  return _QuoteItem(
                    description: data['request_text'] ?? '',
                    photoUrl: data['photo_url'],
                    quotedAmount: response?['quoted_amount']?.toDouble() ?? 0.0,
                    quoteText: response?['text'],
                    onApprove: () async {
                      // Get project name
                      final projectDoc = await FirebaseFirestore.instance
                          .collection('projects')
                          .doc(projectId)
                          .get();
                      final projectName = projectDoc.data()?['project_name'] ?? 'Project';

                      if (context.mounted) {
                        _approveQuote(
                          context,
                          request.id,
                          projectName,
                          data['request_text'] ?? '',
                          response?['quoted_amount']?.toDouble() ?? 0.0,
                        );
                      }
                    },
                    onDecline: () {
                      _declineQuote(context, request.id);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuoteItem extends StatelessWidget {
  final String description;
  final String? photoUrl;
  final double quotedAmount;
  final String? quoteText;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  const _QuoteItem({
    required this.description,
    this.photoUrl,
    required this.quotedAmount,
    this.quoteText,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          Text(
            description,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Photo if available
          if (photoUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                photoUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.error_outline, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Quote details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.attach_money,
                      color: Color(0xFF3B82F6),
                      size: 24,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '\$${quotedAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
                if (quoteText != null && quoteText!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    quoteText!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey[400]!),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text(
                    'Approve & Add to Project',
                    style: TextStyle(fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
