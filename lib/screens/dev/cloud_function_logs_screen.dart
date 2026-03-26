import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// TEMPORARY: Cloud Function Logs Viewer
/// Shows notification documents and their email_sent status
/// This helps debug why emails aren't being sent
class CloudFunctionLogsScreen extends StatefulWidget {
  const CloudFunctionLogsScreen({super.key});

  @override
  State<CloudFunctionLogsScreen> createState() => _CloudFunctionLogsScreenState();
}

class _CloudFunctionLogsScreenState extends State<CloudFunctionLogsScreen> {
  String selectedFilter = 'all';

  final Map<String, String> filterTypes = {
    'all': 'All Notifications',
    'milestone_started': 'Milestone Started',
    'milestone_completed': 'Milestone Completed',
    'change_order': 'Change Order',
    'milestone_approved': 'Milestone Approved',
    'change_order_approved': 'Change Order Approved',
    'change_order_declined': 'Change Order Declined',
    'quality_issue_reported': 'Quality Issue',
    'addition_requested': 'Addition Request',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Notification Logs'),
        backgroundColor: const Color(0xFF8B5CF6),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter selector
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter by notification type:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedFilter,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: filterTypes.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedFilter = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Shows last 50 notifications. Green = email sent, Red = email failed/skipped.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          // Notification list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getNotificationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading logs: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No notifications found'),
                  );
                }

                final notifications = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final doc = notifications[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildNotificationCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getNotificationsStream() {
    Query query = FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('created_at', descending: true)
        .limit(50);

    if (selectedFilter != 'all') {
      query = query.where('type', isEqualTo: selectedFilter);
    }

    return query.snapshots();
  }

  Widget _buildNotificationCard(String docId, Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'unknown';
    final title = data['title'] as String? ?? 'No title';
    final body = data['body'] as String? ?? 'No body';
    final emailSent = data['email_sent'] as bool?;
    final emailSkipped = data['email_skipped'] as String?;
    final emailError = data['email_error'] as String?;
    final createdAt = data['created_at'] as Timestamp?;
    final emailSentAt = data['email_sent_at'] as Timestamp?;
    final recipientUid = data['recipient_uid'] as String? ?? 'unknown';

    // Determine email status
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (emailSent == true) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Email Sent';
    } else if (emailSent == false && emailError != null) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Email Failed';
    } else if (emailSkipped != null) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Email Skipped';
    } else if (emailSent == null) {
      statusColor = Colors.grey;
      statusIcon = Icons.pending;
      statusText = 'Pending';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help;
      statusText = 'Unknown';
    }

    // Format timestamp
    String timeText = 'Unknown time';
    if (createdAt != null) {
      final date = createdAt.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        timeText = 'Just now';
      } else if (diff.inHours < 1) {
        timeText = '${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        timeText = '${diff.inHours}h ago';
      } else {
        timeText = DateFormat('MMM d, h:mm a').format(date);
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ExpansionTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getTypeColor(type).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 11,
                      color: _getTypeColor(type),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeText,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Notification ID', docId),
                _buildDetailRow('Type', type),
                _buildDetailRow('Recipient UID', recipientUid),
                _buildDetailRow('Body', body),
                if (emailSentAt != null)
                  _buildDetailRow(
                    'Email Sent At',
                    DateFormat('MMM d, yyyy h:mm:ss a').format(emailSentAt.toDate()),
                  ),
                if (emailError != null)
                  _buildDetailRow('Email Error', emailError, isError: true),
                if (emailSkipped != null)
                  _buildDetailRow('Skip Reason', emailSkipped, isWarning: true),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Raw Data:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    data.toString(),
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isError = false, bool isWarning = false}) {
    Color valueColor = Colors.black87;
    if (isError) valueColor = Colors.red;
    if (isWarning) valueColor = Colors.orange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontSize: 12, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'milestone_started':
        return const Color(0xFF3B82F6); // Blue
      case 'milestone_completed':
      case 'milestone_approved':
        return const Color(0xFF10B981); // Green
      case 'change_order':
        return const Color(0xFFF59E0B); // Orange
      case 'change_order_approved':
        return const Color(0xFF10B981); // Green
      case 'change_order_declined':
        return const Color(0xFFEF4444); // Red
      case 'quality_issue_reported':
        return const Color(0xFFF59E0B); // Orange
      case 'addition_requested':
        return const Color(0xFF8B5CF6); // Purple
      default:
        return Colors.grey;
    }
  }
}
