import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

/// Contextual bottom sheet that explains the value of push notifications
/// before triggering the system permission dialog.
class NotificationPermissionSheet extends StatelessWidget {
  final String contractorName;

  const NotificationPermissionSheet({
    super.key,
    required this.contractorName,
  });

  /// Show the permission prompt if the user hasn't been asked yet.
  static Future<void> showIfNeeded(
      BuildContext context, String contractorName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.data()?['notificationPromptShown'] == true) return;

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          NotificationPermissionSheet(contractorName: contractorName),
    );

    // Mark as shown regardless of choice
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'notificationPromptShown': true}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Bell icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              size: 40,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Stay updated on your project?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          Text(
            'Get notified when $contractorName posts photos, '
            'completes milestones, or sends you a message.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // Enable button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Trigger FCM initialization which requests system permission
                NotificationService.initialize();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Enable notifications',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Not now
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Not now',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
