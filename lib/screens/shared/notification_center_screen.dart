import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../contractor/project_details_screen.dart';
import '../client/client_project_timeline.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'photo_update':
        return Icons.camera_alt;
      case 'change_order':
        return Icons.request_quote;
      case 'milestone_completed':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'photo_update':
        return Colors.blue;
      case 'change_order':
        return Colors.orange;
      case 'milestone_completed':
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

  Future<void> _navigateToProject(BuildContext context, Map<String, dynamic> data, String userRole) async {
    final projectId = data['project_id'] as String?;
    if (projectId == null) return;

    final projectDoc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .get();
    if (!projectDoc.exists) return;
    final projectData = projectDoc.data()!;

    if (!context.mounted) return;

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
              if (snapshot.connectionState == ConnectionState.waiting) {
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
                      _navigateToProject(context, data, userRole);
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
