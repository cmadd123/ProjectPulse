import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Service for handling push notifications via Firebase Cloud Messaging
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize FCM and request permissions
  static Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    _navigatorKey = navigatorKey;
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('User granted provisional notification permission');
      } else {
        debugPrint('User declined notification permission');
      }

      await _saveFcmToken();
      FirebaseMessaging.instance.onTokenRefresh.listen(_updateFcmToken);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Set navigator key after app is built (called from main.dart)
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static Future<void> _saveFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcm_tokens': FieldValue.arrayUnion([token]),
        'last_fcm_token_update': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('FCM Token saved: $token');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  static Future<void> _updateFcmToken(String newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcm_tokens': FieldValue.arrayUnion([newToken]),
      'last_fcm_token_update': FieldValue.serverTimestamp(),
    });

    debugPrint('FCM Token updated: $newToken');
  }

  /// Handle messages when app is in foreground — show toast
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received foreground message: ${message.notification?.title}');

    final context = _navigatorKey?.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message.notification?.body ?? 'New notification',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Helper: get recipient UID from a DocumentReference
  static String _uidFromRef(DocumentReference ref) {
    return ref.path.split('/').last;
  }

  /// Send notification to client when contractor posts photo update
  static Future<void> sendPhotoUpdateNotification({
    required String projectId,
    required String projectName,
    required String caption,
  }) async {
    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) return;

      final projectData = projectDoc.data()!;
      final clientRef = projectData['client_user_ref'] as DocumentReference?;
      if (clientRef == null) return;

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) return;

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      if (fcmTokens == null || fcmTokens.isEmpty) return;

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'photo_update',
        'recipient_ref': clientRef,
        'recipient_uid': _uidFromRef(clientRef),
        'fcm_tokens': fcmTokens,
        'title': 'New Photo Update',
        'body': '$projectName: ${caption.isNotEmpty ? caption : 'New photo posted'}',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'photo_update',
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Photo update notification queued for client');
    } catch (e) {
      debugPrint('Error sending photo update notification: $e');
    }
  }

  /// Send notification when change order is created
  static Future<void> sendChangeOrderNotification({
    required String projectId,
    required String projectName,
    required String description,
    required double costChange,
  }) async {
    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) return;

      final projectData = projectDoc.data()!;
      final clientRef = projectData['client_user_ref'] as DocumentReference?;
      if (clientRef == null) return;

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) return;

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      if (fcmTokens == null || fcmTokens.isEmpty) return;

      final costChangeText = costChange >= 0
          ? '+\$${costChange.toStringAsFixed(0)}'
          : '-\$${costChange.abs().toStringAsFixed(0)}';

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'change_order',
        'recipient_ref': clientRef,
        'recipient_uid': _uidFromRef(clientRef),
        'fcm_tokens': fcmTokens,
        'title': 'Change Order Requires Approval',
        'body': '$projectName: $description ($costChangeText)',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'change_order',
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Change order notification queued for client');
    } catch (e) {
      debugPrint('Error sending change order notification: $e');
    }
  }

  /// Send notification when milestone is marked complete
  static Future<void> sendMilestoneNotification({
    required String projectId,
    required String projectName,
    required String milestoneName,
  }) async {
    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) return;

      final projectData = projectDoc.data()!;
      final clientRef = projectData['client_user_ref'] as DocumentReference?;
      if (clientRef == null) return;

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) return;

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      if (fcmTokens == null || fcmTokens.isEmpty) return;

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'milestone_completed',
        'recipient_ref': clientRef,
        'recipient_uid': _uidFromRef(clientRef),
        'fcm_tokens': fcmTokens,
        'title': 'Milestone Completed!',
        'body': '$projectName: $milestoneName',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'milestone_completed',
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Milestone notification queued for client');
    } catch (e) {
      debugPrint('Error sending milestone notification: $e');
    }
  }
  // ==================== REVERSE NOTIFICATIONS (Client → GC) ====================

  /// Helper: look up GC's FCM tokens from a project
  static Future<Map<String, dynamic>?> _getContractorFcmData(String projectId) async {
    final projectDoc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .get();

    if (!projectDoc.exists) return null;

    final contractorUid = projectDoc.data()?['contractor_uid'] as String?;
    if (contractorUid == null) return null;

    final contractorDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(contractorUid)
        .get();

    if (!contractorDoc.exists) return null;

    final fcmTokens = contractorDoc.data()?['fcm_tokens'] as List<dynamic>?;
    if (fcmTokens == null || fcmTokens.isEmpty) return null;

    return {
      'contractor_uid': contractorUid,
      'contractor_ref': FirebaseFirestore.instance.collection('users').doc(contractorUid),
      'fcm_tokens': fcmTokens,
    };
  }

  /// Notify GC when client approves a milestone
  static Future<void> sendMilestoneApprovedNotification({
    required String projectId,
    required String projectName,
    required String milestoneName,
  }) async {
    try {
      final gcData = await _getContractorFcmData(projectId);
      if (gcData == null) return;

      final user = FirebaseAuth.instance.currentUser;
      final clientName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Client';

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'milestone_approved',
        'recipient_ref': gcData['contractor_ref'],
        'recipient_uid': gcData['contractor_uid'],
        'fcm_tokens': gcData['fcm_tokens'],
        'title': 'Milestone Approved',
        'body': '$projectName: $clientName approved "$milestoneName"',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'milestone_approved',
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Milestone approved notification queued for GC');
    } catch (e) {
      debugPrint('Error sending milestone approved notification: $e');
    }
  }

  /// Notify GC when client requests changes on a milestone
  static Future<void> sendChangesRequestedNotification({
    required String projectId,
    required String projectName,
    required String milestoneName,
  }) async {
    try {
      final gcData = await _getContractorFcmData(projectId);
      if (gcData == null) return;

      final user = FirebaseAuth.instance.currentUser;
      final clientName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Client';

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'changes_requested',
        'recipient_ref': gcData['contractor_ref'],
        'recipient_uid': gcData['contractor_uid'],
        'fcm_tokens': gcData['fcm_tokens'],
        'title': 'Changes Requested',
        'body': '$projectName: $clientName requested changes on "$milestoneName"',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'changes_requested',
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Changes requested notification queued for GC');
    } catch (e) {
      debugPrint('Error sending changes requested notification: $e');
    }
  }

  /// Notify GC when client sends a chat message
  static Future<void> sendChatMessageNotification({
    required String projectId,
    required String projectName,
    required String messagePreview,
  }) async {
    try {
      final gcData = await _getContractorFcmData(projectId);
      if (gcData == null) return;

      final user = FirebaseAuth.instance.currentUser;
      final clientName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Client';

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'chat_message',
        'recipient_ref': gcData['contractor_ref'],
        'recipient_uid': gcData['contractor_uid'],
        'fcm_tokens': gcData['fcm_tokens'],
        'title': 'New Message',
        'body': '$projectName: $clientName — ${messagePreview.length > 80 ? '${messagePreview.substring(0, 80)}...' : messagePreview}',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'chat_message',
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Chat message notification queued for GC');
    } catch (e) {
      debugPrint('Error sending chat message notification: $e');
    }
  }
  // ==================== TEAM MEMBER NOTIFICATIONS (GC → Team Member) ====================

  /// Helper: look up a team member's FCM tokens by their user_uid
  static Future<Map<String, dynamic>?> _getTeamMemberFcmData(String userUid) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userUid)
        .get();

    if (!userDoc.exists) return null;

    final fcmTokens = userDoc.data()?['fcm_tokens'] as List<dynamic>?;
    if (fcmTokens == null || fcmTokens.isEmpty) return null;

    return {
      'user_uid': userUid,
      'user_ref': FirebaseFirestore.instance.collection('users').doc(userUid),
      'fcm_tokens': fcmTokens,
    };
  }

  /// Notify team member when assigned to a project
  static Future<void> sendCrewAssignmentNotification({
    required String userUid,
    required String projectId,
    required String projectName,
  }) async {
    try {
      final memberData = await _getTeamMemberFcmData(userUid);
      if (memberData == null) return;

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'crew_assignment',
        'recipient_ref': memberData['user_ref'],
        'recipient_uid': userUid,
        'fcm_tokens': memberData['fcm_tokens'],
        'title': 'New Project Assignment',
        'body': 'You\'ve been assigned to $projectName',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'crew_assignment',
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Crew assignment notification queued for $userUid');
    } catch (e) {
      debugPrint('Error sending crew assignment notification: $e');
    }
  }

  /// Notify team member when scheduled to work on a project
  static Future<void> sendScheduleNotification({
    required String userUid,
    required String projectName,
    required String dateLabel,
  }) async {
    try {
      final memberData = await _getTeamMemberFcmData(userUid);
      if (memberData == null) return;

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'schedule_update',
        'recipient_ref': memberData['user_ref'],
        'recipient_uid': userUid,
        'fcm_tokens': memberData['fcm_tokens'],
        'title': 'Schedule Update',
        'body': 'You\'re scheduled for $projectName on $dateLabel',
        'data': {
          'type': 'schedule_update',
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Schedule notification queued for $userUid');
    } catch (e) {
      debugPrint('Error sending schedule notification: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.notification?.title}');
}
