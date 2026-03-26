import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

/// Card that shows addition requests for a specific milestone (contractor view)
class ContractorAdditionRequestsCard extends StatelessWidget {
  final String projectId;
  final String milestoneId;

  const ContractorAdditionRequestsCard({
    super.key,
    required this.projectId,
    required this.milestoneId,
  });

  void _showQuoteDialog(
    BuildContext context,
    String changeId,
    String projectName,
    String description,
  ) {
    final quoteController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Provide Quote'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Text(
              'Quote Amount (\$)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: quoteController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '150',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Explanation (Optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Includes materials and labor...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final amount = double.tryParse(quoteController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.orange,
                  ),
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
                  'contractor_response': {
                    'type': 'quote',
                    'quoted_amount': amount,
                    'text': reasonController.text.trim().isNotEmpty
                        ? reasonController.text.trim()
                        : 'Quote for requested addition',
                    'responded_at': FieldValue.serverTimestamp(),
                  },
                  'status': 'quoted',
                  'updated_at': FieldValue.serverTimestamp(),
                });

                // Send notification to client
                await NotificationService.sendAdditionQuotedNotification(
                  projectId: projectId,
                  projectName: projectName,
                  quotedAmount: amount,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Quote sent. Client will review.'),
                      backgroundColor: Colors.blue,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
            ),
            child: const Text('Send Quote'),
          ),
        ],
      ),
    );
  }

  void _showDeclineDialog(
    BuildContext context,
    String changeId,
    String projectName,
    String description,
  ) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline Request'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reason for declining:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Not feasible due to...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason'),
                    backgroundColor: Colors.orange,
                  ),
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
                  'contractor_response': {
                    'type': 'decline',
                    'text': reasonController.text.trim(),
                    'responded_at': FieldValue.serverTimestamp(),
                  },
                  'status': 'declined',
                  'updated_at': FieldValue.serverTimestamp(),
                });

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Request declined. Client notified.'),
                      backgroundColor: Colors.grey,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
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
        final pendingRequests = requests.where((doc) => doc['status'] == 'pending').toList();
        final quotedRequests = requests.where((doc) => doc['status'] == 'quoted').toList();
        final approvedRequests = requests.where((doc) => doc['status'] == 'approved').toList();
        final declinedRequests = requests.where((doc) => doc['status'] == 'declined').toList();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          constraints: const BoxConstraints(maxHeight: 350),
          clipBehavior: Clip.hardEdge,
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (fixed at top)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFF3B82F6),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Addition Requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    if (pendingRequests.isNotEmpty) ...[
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
                          '${pendingRequests.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pending requests (direct rendering)
                      if (pendingRequests.isNotEmpty)
                        ...pendingRequests.asMap().entries.map((entry) {
                          final request = entry.value;
                          final data = request.data() as Map<String, dynamic>;
                          return _AdditionRequestItem(
                            description: data['request_text'] ?? '',
                            photoUrl: data['photo_url'],
                            createdAt: data['created_at'] as Timestamp?,
                            status: 'pending',
                            onQuote: () async {
                              // Get project name
                              final projectDoc = await FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(projectId)
                                  .get();
                              final projectName = projectDoc.data()?['project_name'] ?? 'Project';

                              if (context.mounted) {
                                _showQuoteDialog(
                                  context,
                                  request.id,
                                  projectName,
                                  data['request_text'] ?? '',
                                );
                              }
                            },
                            onDecline: () async {
                              // Get project name
                              final projectDoc = await FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(projectId)
                                  .get();
                              final projectName = projectDoc.data()?['project_name'] ?? 'Project';

                              if (context.mounted) {
                                _showDeclineDialog(
                                  context,
                                  request.id,
                                  projectName,
                                  data['request_text'] ?? '',
                                );
                              }
                            },
                          );
                        }),

                      // Quoted requests (awaiting client approval)
                      if (quotedRequests.isNotEmpty)
                        ExpansionTile(
                          title: Text(
                            'Awaiting Approval (${quotedRequests.length})',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          children: quotedRequests.map((request) {
                            final data = request.data() as Map<String, dynamic>;
                            final response = data['contractor_response'] as Map<String, dynamic>?;
                            return _AdditionRequestItem(
                              description: data['request_text'] ?? '',
                              photoUrl: data['photo_url'],
                              createdAt: data['created_at'] as Timestamp?,
                              status: 'quoted',
                              quotedAmount: response?['quoted_amount']?.toDouble(),
                              quoteText: response?['text'],
                            );
                          }).toList(),
                        ),

                      // Approved/Declined (collapsed)
                      if (approvedRequests.isNotEmpty || declinedRequests.isNotEmpty)
                        ExpansionTile(
                          title: Text(
                            'Completed (${approvedRequests.length + declinedRequests.length})',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          children: [
                            ...approvedRequests.map((request) {
                              final data = request.data() as Map<String, dynamic>;
                              final response = data['contractor_response'] as Map<String, dynamic>?;
                              return _AdditionRequestItem(
                                description: data['request_text'] ?? '',
                                photoUrl: data['photo_url'],
                                createdAt: data['created_at'] as Timestamp?,
                                status: 'approved',
                                quotedAmount: response?['quoted_amount']?.toDouble(),
                              );
                            }).toList(),
                            ...declinedRequests.map((request) {
                              final data = request.data() as Map<String, dynamic>;
                              final response = data['contractor_response'] as Map<String, dynamic>?;
                              return _AdditionRequestItem(
                                description: data['request_text'] ?? '',
                                photoUrl: data['photo_url'],
                                createdAt: data['created_at'] as Timestamp?,
                                status: 'declined',
                                declineReason: response?['text'],
                              );
                            }).toList(),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdditionRequestItem extends StatelessWidget {
  final String description;
  final String? photoUrl;
  final Timestamp? createdAt;
  final String status;
  final double? quotedAmount;
  final String? quoteText;
  final String? declineReason;
  final VoidCallback? onQuote;
  final VoidCallback? onDecline;

  const _AdditionRequestItem({
    required this.description,
    this.photoUrl,
    this.createdAt,
    required this.status,
    this.quotedAmount,
    this.quoteText,
    this.declineReason,
    this.onQuote,
    this.onDecline,
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
            style: TextStyle(
              fontSize: 15,
              color: status == 'declined' ? Colors.grey[600] : Colors.black87,
              decoration: status == 'declined' ? TextDecoration.lineThrough : null,
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

          // Quote details if quoted/approved
          if (quotedAmount != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Quote: \$${quotedAmount!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                  if (quoteText != null && quoteText!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      quoteText!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Decline reason if declined
          if (declineReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Declined: $declineReason',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Timestamp and action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (createdAt != null)
                Text(
                  _formatTimestamp(createdAt!),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              if (status == 'pending' && onQuote != null && onDecline != null)
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onQuote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: const Text('Quote'),
                    ),
                  ],
                )
              else if (status == 'quoted')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Awaiting Approval',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else if (status == 'approved')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Approved',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else if (status == 'declined')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cancel, size: 14, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Declined',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
