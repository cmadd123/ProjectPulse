import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../contractor/project_details_screen.dart';
import '../client/client_project_timeline.dart';
import '../../components/client_changes_activity_widget.dart';
import '../shared/project_chat_screen.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'photo_update':
        return Icons.camera_alt;
      case 'change_order':
      case 'change_order_approved':
      case 'change_order_declined':
        return Icons.request_quote;
      case 'milestone_completed':
      case 'milestone_approved':
      case 'milestone_started':
        return Icons.check_circle;
      case 'changes_requested':
        return Icons.edit_note;
      case 'chat_message':
        return Icons.chat_bubble;
      case 'quality_issue_reported':
      case 'quality_issue_fixed':
        return Icons.report_problem;
      case 'addition_requested':
      case 'addition_quoted':
      case 'addition_approved':
        return Icons.add_circle;
      case 'payment_processed':
        return Icons.payment;
      case 'project_completed':
        return Icons.celebration;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'photo_update':
        return Colors.blue;
      case 'change_order':
      case 'change_order_approved':
      case 'change_order_declined':
        return Colors.orange;
      case 'milestone_completed':
      case 'milestone_approved':
      case 'milestone_started':
        return Colors.green;
      case 'changes_requested':
        return Colors.amber;
      case 'chat_message':
        return Colors.purple;
      case 'quality_issue_reported':
      case 'quality_issue_fixed':
        return const Color(0xFFEF4444); // Red
      case 'addition_requested':
      case 'addition_quoted':
      case 'addition_approved':
        return const Color(0xFF3B82F6); // Blue
      case 'payment_processed':
        return Colors.teal;
      case 'project_completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Future<void> _markAllRead(String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    final unread = await FirebaseFirestore.instance
        .collection('notifications')
        .where('recipient_uid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();

    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> _markRead(DocumentReference ref) async {
    await ref.update({'read': true});
  }

  Future<void> _navigateToNotification(
    BuildContext context,
    String type,
    Map<String, dynamic> data,
    String userRole,
  ) async {
    final projectId = data['project_id'] as String?;
    if (projectId == null) return;

    final projectDoc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .get();
    if (!projectDoc.exists) return;
    final projectData = projectDoc.data()!;

    if (!context.mounted) return;

    // Handle specific notification types with deep linking
    switch (type) {
      case 'quality_issue_reported':
      case 'quality_issue_fixed':
      case 'addition_requested':
      case 'addition_quoted':
      case 'addition_approved':
        // Navigate to My Requests screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('My Requests'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              body: ClientChangesActivityWidget(
                projectId: projectId,
                userRole: userRole,
              ),
            ),
          ),
        );
        break;

      case 'chat_message':
        // Navigate to project chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectChatScreen(
              projectId: projectId,
              projectName: projectData['project_name'] ?? 'Project',
              isContractor: userRole == 'contractor',
            ),
          ),
        );
        break;

      default:
        // Default: Navigate to project timeline
        if (userRole == 'contractor') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectDetailsScreen(
                projectId: projectId,
                projectData: projectData,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientProjectTimeline(
                projectId: projectId,
                projectData: projectData,
              ),
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(user.uid),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, userSnap) {
          final userRole = (userSnap.data?.data() as Map<String, dynamic>?)?['role'] ?? 'client';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('recipient_uid', isEqualTo: user.uid)
                .orderBy('created_at', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              // Only show loading on first load, not on subsequent updates
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final notif = doc.data() as Map<String, dynamic>;
                  final type = notif['type'] as String? ?? '';
                  final title = notif['title'] as String? ?? '';
                  final body = notif['body'] as String? ?? '';
                  final isRead = notif['read'] as bool? ?? false;
                  final createdAt = notif['created_at'] as Timestamp?;
                  final data = notif['data'] as Map<String, dynamic>? ?? {};

                  final color = _colorForType(type);

                  return ListTile(
                    tileColor: isRead ? null : color.withOpacity(0.04),
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.15),
                      child: Icon(_iconForType(type), color: color, size: 20),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          createdAt != null ? _timeAgo(createdAt.toDate()) : '',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        if (!isRead)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      if (!isRead) _markRead(doc.reference);
                      _navigateToNotification(context, type, data, userRole);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
