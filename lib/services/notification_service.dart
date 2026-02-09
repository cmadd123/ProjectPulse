import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for handling push notifications via Firebase Cloud Messaging
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM and request permissions
  static Future<void> initialize() async {
    // Request permission for iOS
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

    // Get and save FCM token
    await _saveFcmToken();

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen(_updateFcmToken);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages (handled in main.dart)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Save FCM token to user document
  static Future<void> _saveFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcm_tokens': FieldValue.arrayUnion([token]),
      'last_fcm_token_update': FieldValue.serverTimestamp(),
    });

    debugPrint('FCM Token saved: $token');
  }

  /// Update FCM token when it refreshes
  static Future<void> _updateFcmToken(String newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcm_tokens': FieldValue.arrayUnion([newToken]),
      'last_fcm_token_update': FieldValue.serverTimestamp(),
    });

    debugPrint('FCM Token updated: $newToken');
  }

  /// Handle messages when app is in foreground
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received foreground message: ${message.notification?.title}');
    // In a real app, you'd show a local notification here
    // For now, just log it
  }

  /// Send notification to client when contractor posts photo update
  static Future<void> sendPhotoUpdateNotification({
    required String projectId,
    required String projectName,
    required String caption,
  }) async {
    try {
      // Get project data to find client
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) return;

      final projectData = projectDoc.data()!;
      final clientRef = projectData['client_user_ref'] as DocumentReference?;

      if (clientRef == null) return; // Client hasn't joined yet

      // Get client's FCM tokens
      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) return;

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;

      if (fcmTokens == null || fcmTokens.isEmpty) return;

      // Create notification document for Cloud Function to process
      // (Cloud Function will actually send the notification)
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'photo_update',
        'recipient_ref': clientRef,
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
      });

      debugPrint('Change order notification queued for client');
    } catch (e) {
      debugPrint('Error sending change order notification: $e');
    }
  }

  /// Send notification when milestone is completed
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
        'fcm_tokens': fcmTokens,
        'title': 'Milestone Completed! 🎉',
        'body': '$projectName: $milestoneName',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'milestone_completed',
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
      });

      debugPrint('Milestone notification queued for client');
    } catch (e) {
      debugPrint('Error sending milestone notification: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.notification?.title}');
}
