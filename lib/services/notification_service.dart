import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'debug_logger.dart';
import '../components/client_changes_activity_widget.dart';
import '../screens/shared/project_chat_screen.dart';
import '../screens/contractor/project_details_screen.dart';
import '../screens/client/client_project_timeline.dart';

/// Service for handling push notifications via Firebase Cloud Messaging
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize FCM and request permissions
  static Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    _navigatorKey = navigatorKey;
    try {
      // Create notification channel for Android
      if (!kIsWeb && Platform.isAndroid) {
        await _createAndroidNotificationChannel();
      }

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

      // Handle notification taps (when app opens from notification)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was launched from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Create Android notification channel (required for Android 8.0+)
  static Future<void> _createAndroidNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'projectpulse_notifications', // Must match AndroidManifest.xml
        'ProjectPulse Notifications',
        description: 'Notifications for project updates, milestones, and change orders',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('Android notification channel created: ${channel.id}');
    } catch (e) {
      debugPrint('Error creating notification channel: $e');
    }
  }

  /// Set navigator key after app is built (called from main.dart)
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static Future<void> _saveFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('FCM Token save failed: No authenticated user');
        return;
      }

      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('FCM Token save failed: getToken() returned null (permissions likely denied)');
        return;
      }

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

    // Check if the notification is for the currently signed-in user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('Notification ignored: No user signed in');
      return;
    }

    // Get recipient_uid from notification data
    final recipientUid = message.data['recipient_uid'] as String?;
    if (recipientUid != null && recipientUid != currentUser.uid) {
      debugPrint('Notification ignored: For different user (recipient: $recipientUid, current: ${currentUser.uid})');
      return;
    }

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

  /// Handle notification tap (when user taps notification to open app)
  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('📱 Notification tapped: ${message.notification?.title}');
    debugPrint('   Data: ${message.data}');

    // Wait for navigator to be available, then navigate
    Future.delayed(const Duration(milliseconds: 500), () async {
      final context = _navigatorKey?.currentContext;
      if (context == null) {
        debugPrint('❌ Cannot navigate: Navigator context not available');
        return;
      }

      final type = message.data['type'] as String?;
      final projectId = message.data['project_id'] as String?;

      if (projectId == null) {
        debugPrint('❌ Cannot navigate: project_id missing from notification data');
        return;
      }

      // Get user role to determine which screen to navigate to
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userRole = (userDoc.data()?['role'] as String?) ?? 'client';

      // Get project data for navigation
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();
      if (!projectDoc.exists) {
        debugPrint('❌ Project $projectId does not exist');
        return;
      }
      final projectData = projectDoc.data()!;

      if (!context.mounted) return;

      // Navigate based on notification type
      switch (type) {
        case 'quality_issue_reported':
        case 'quality_issue_fixed':
        case 'addition_requested':
        case 'addition_quoted':
        case 'addition_approved':
          // Navigate to My Requests screen
          debugPrint('✅ Navigating to My Requests screen');
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
          debugPrint('✅ Navigating to Project Chat');
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

        case 'milestone_completed':
        case 'milestone_approved':
        case 'milestone_started':
        case 'changes_requested':
          // Navigate to project timeline (milestones are shown there)
          // For client: shows milestones with approval buttons
          // For contractor: shows milestone status
          debugPrint('✅ Navigating to Project Timeline (Milestones)');
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
          break;

        default:
          // Default: Navigate to project timeline
          debugPrint('✅ Navigating to Project Timeline');
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
    });
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

      if (!projectDoc.exists) {
        debugPrint('Notification failed: Project $projectId does not exist');
        return;
      }

      final projectData = projectDoc.data()!;
      final clientRef = projectData['client_user_ref'] as DocumentReference?;
      if (clientRef == null) {
        debugPrint('Notification skipped: client_user_ref is null (client hasn\'t joined yet)');
        return;
      }

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) {
        debugPrint('Notification failed: Client user document does not exist');
        return;
      }

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      if (fcmTokens == null || fcmTokens.isEmpty) {
        debugPrint('Notification skipped: Client has no FCM tokens (app not opened or permissions denied)');
        return;
      }

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
    DebugLogger.log('🔔 sendChangeOrderNotification called');
    DebugLogger.log('   projectId: $projectId');
    DebugLogger.log('   projectName: $projectName');

    // Check auth state first
    final currentUser = FirebaseAuth.instance.currentUser;
    DebugLogger.log('🔐 Auth check:');
    DebugLogger.log('   User ID: ${currentUser?.uid ?? "NOT LOGGED IN"}');
    DebugLogger.log('   Email: ${currentUser?.email ?? "null"}');

    try {
      DebugLogger.log('📥 Fetching project document...');
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) {
        DebugLogger.log('❌ Project does not exist');
        return;
      }
      DebugLogger.log('✅ Project document exists');

      final projectData = projectDoc.data()!;
      final clientRef = projectData['client_user_ref'] as DocumentReference?;
      DebugLogger.log('📋 client_user_ref: ${clientRef?.path ?? "null"}');

      if (clientRef == null) {
        DebugLogger.log('❌ client_user_ref is null');
        return;
      }

      DebugLogger.log('📥 Fetching client document...');
      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) {
        DebugLogger.log('❌ Client document does not exist');
        return;
      }
      DebugLogger.log('✅ Client document exists');

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      DebugLogger.log('📋 Client FCM tokens: ${fcmTokens?.length ?? 0}');

      if (fcmTokens == null || fcmTokens.isEmpty) {
        DebugLogger.log('❌ Client has NO FCM tokens');
        return;
      }

      final costChangeText = costChange >= 0
          ? '+\$${costChange.toStringAsFixed(0)}'
          : '-\$${costChange.abs().toStringAsFixed(0)}';

      DebugLogger.log('💾 Creating notification document...');
      final recipientUid = _uidFromRef(clientRef);
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'change_order',
        'recipient_ref': clientRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Change Order Requires Approval',
        'body': '$projectName: $description ($costChangeText)',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'change_order',
          'recipient_uid': recipientUid, // Include in FCM message data
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      DebugLogger.log('✅ Notification created successfully');
    } catch (e, stackTrace) {
      DebugLogger.log('❌ OUTER ERROR: $e');
      final stackStr = stackTrace.toString();
      final stackPreview = stackStr.length > 300 ? stackStr.substring(0, 300) : stackStr;
      DebugLogger.log('Stack: $stackPreview');
    }
  }

  /// Send notification when milestone is marked complete
  static Future<void> sendMilestoneNotification({
    required String projectId,
    required String projectName,
    required String milestoneName,
  }) async {
    try {
      DebugLogger.log('🎉 Milestone Completed - Starting notification...');
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) {
        DebugLogger.log('❌ Project document not found');
        debugPrint('Notification failed: Project $projectId does not exist');
        return;
      }
      DebugLogger.log('✅ Project document exists');

      final projectData = projectDoc.data()!;
      final clientRef = projectData['client_user_ref'] as DocumentReference?;
      if (clientRef == null) {
        DebugLogger.log('❌ No client reference (client hasn\'t joined yet)');
        debugPrint('Notification skipped: client_user_ref is null (client hasn\'t joined yet)');
        return;
      }
      DebugLogger.log('✅ Client reference found');

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) {
        DebugLogger.log('❌ Client document does not exist');
        debugPrint('Notification failed: Client user document does not exist');
        return;
      }
      DebugLogger.log('✅ Client document exists');

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      DebugLogger.log('📋 Client FCM tokens: ${fcmTokens?.length ?? 0}');

      if (fcmTokens == null || fcmTokens.isEmpty) {
        DebugLogger.log('❌ Client has NO FCM tokens');
        debugPrint('Notification skipped: Client has no FCM tokens (app not opened or permissions denied)');
        return;
      }

      DebugLogger.log('💾 Creating notification document...');
      final recipientUid = _uidFromRef(clientRef);
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'milestone_completed',
        'recipient_ref': clientRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Milestone Completed!',
        'body': '$projectName: $milestoneName',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'milestone_completed',
          'recipient_uid': recipientUid, // Include in FCM message data
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      DebugLogger.log('✅ Milestone completed notification created successfully');
      debugPrint('Milestone notification queued for client');
    } catch (e) {
      DebugLogger.log('❌ ERROR: $e');
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

    if (!projectDoc.exists) {
      debugPrint('_getContractorFcmData: Project $projectId does not exist');
      return null;
    }

    // Try to get contractor_uid (string) first
    String? contractorUid = projectDoc.data()?['contractor_uid'] as String?;

    // Fallback: If no contractor_uid, try to get it from contractor_ref (DocumentReference)
    if (contractorUid == null) {
      final contractorRef = projectDoc.data()?['contractor_ref'] as DocumentReference?;
      if (contractorRef != null) {
        contractorUid = contractorRef.id;
        debugPrint('_getContractorFcmData: Using contractor_ref.id: $contractorUid');
      }
    }

    if (contractorUid == null) {
      debugPrint('_getContractorFcmData: No contractor_uid or contractor_ref found');
      return null;
    }

    final contractorDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(contractorUid)
        .get();

    if (!contractorDoc.exists) {
      debugPrint('_getContractorFcmData: Contractor user $contractorUid does not exist');
      return null;
    }

    final fcmTokens = contractorDoc.data()?['fcm_tokens'] as List<dynamic>?;
    if (fcmTokens == null || fcmTokens.isEmpty) {
      debugPrint('_getContractorFcmData: Contractor $contractorUid has no FCM tokens');
      return null;
    }

    debugPrint('_getContractorFcmData: SUCCESS - Found ${fcmTokens.length} FCM tokens for contractor $contractorUid');

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

  // ==================== NEW NOTIFICATIONS (Phase 1A) ====================

  /// 1. Notify GC when client approves/declines change order
  static Future<void> sendChangeOrderResponseNotification({
    required String projectId,
    required String projectName,
    required String changeOrderDescription,
    required bool approved,
    required double costChange,
  }) async {
    try {
      final gcData = await _getContractorFcmData(projectId);
      if (gcData == null) return;

      final user = FirebaseAuth.instance.currentUser;
      final clientName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Client';
      final costText = costChange >= 0 ? '+\$${costChange.toStringAsFixed(0)}' : '-\$${costChange.abs().toStringAsFixed(0)}';
      final status = approved ? 'approved' : 'declined';

      final recipientUid = gcData['contractor_uid'] as String;
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'change_order_$status',
        'recipient_ref': gcData['contractor_ref'],
        'recipient_uid': recipientUid,
        'fcm_tokens': gcData['fcm_tokens'],
        'title': approved ? 'Change Order Approved' : 'Change Order Declined',
        'body': '$projectName: $clientName $status "$changeOrderDescription" ($costText)',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'change_order_$status',
          'recipient_uid': recipientUid,
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Change order $status notification queued for GC');
    } catch (e) {
      debugPrint('Error sending change order response notification: $e');
    }
  }

  /// 2. Notify client when GC addresses change request
  static Future<void> sendChangeRequestAddressedNotification({
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

      final clientRef = projectDoc.data()?['client_user_ref'] as DocumentReference?;
      if (clientRef == null) return;

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) return;

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      if (fcmTokens == null || fcmTokens.isEmpty) return;

      final recipientUid = _uidFromRef(clientRef);
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'change_request_addressed',
        'recipient_ref': clientRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Changes Addressed',
        'body': '$projectName: Contractor addressed your changes to "$milestoneName"',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'change_request_addressed',
          'recipient_uid': recipientUid,
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Change request addressed notification queued for client');
    } catch (e) {
      debugPrint('Error sending change request addressed notification: $e');
    }
  }

  /// 3. Notify client when payment is processed
  static Future<void> sendPaymentProcessedNotification({
    required String projectId,
    required String projectName,
    required String milestoneName,
    required double amount,
  }) async {
    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) return;

      final clientRef = projectDoc.data()?['client_user_ref'] as DocumentReference?;
      if (clientRef == null) return;

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) return;

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      if (fcmTokens == null || fcmTokens.isEmpty) return;

      final recipientUid = _uidFromRef(clientRef);
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'payment_processed',
        'recipient_ref': clientRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Payment Processed',
        'body': '$projectName: Payment of \$${amount.toStringAsFixed(0)} processed for "$milestoneName"',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'payment_processed',
          'recipient_uid': recipientUid,
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Payment processed notification queued for client');
    } catch (e) {
      debugPrint('Error sending payment processed notification: $e');
    }
  }

  /// 4. Notify client when milestone schedule is created
  static Future<void> sendMilestoneScheduleCreatedNotification({
    required String projectId,
    required String projectName,
    required int milestoneCount,
  }) async {
    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) return;

      final clientRef = projectDoc.data()?['client_user_ref'] as DocumentReference?;
      if (clientRef == null) return;

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) return;

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      if (fcmTokens == null || fcmTokens.isEmpty) return;

      final recipientUid = _uidFromRef(clientRef);
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'milestone_schedule_created',
        'recipient_ref': clientRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Project Timeline Created',
        'body': '$projectName: Contractor created $milestoneCount milestone${milestoneCount != 1 ? 's' : ''} for your project',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'milestone_schedule_created',
          'recipient_uid': recipientUid,
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Milestone schedule created notification queued for client');
    } catch (e) {
      debugPrint('Error sending milestone schedule notification: $e');
    }
  }

  /// 5. Notify client when project is marked complete
  static Future<void> sendProjectCompletedNotification({
    required String projectId,
    required String projectName,
  }) async {
    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) return;

      final clientRef = projectDoc.data()?['client_user_ref'] as DocumentReference?;
      if (clientRef == null) return;

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) return;

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      if (fcmTokens == null || fcmTokens.isEmpty) return;

      final recipientUid = _uidFromRef(clientRef);
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'project_completed',
        'recipient_ref': clientRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Project Completed!',
        'body': '$projectName: Your project is complete! Please leave a review.',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'project_completed',
          'recipient_uid': recipientUid,
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Project completed notification queued for client');
    } catch (e) {
      debugPrint('Error sending project completed notification: $e');
    }
  }

  /// 6. Notify client when milestone is started
  static Future<void> sendMilestoneStartedNotification({
    required String projectId,
    required String projectName,
    required String milestoneName,
  }) async {
    try {
      DebugLogger.log('🚀 Milestone Started - Starting notification...');
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) {
        DebugLogger.log('❌ Project document not found');
        return;
      }
      DebugLogger.log('✅ Project document exists');

      final clientRef = projectDoc.data()?['client_user_ref'] as DocumentReference?;
      if (clientRef == null) {
        DebugLogger.log('❌ No client reference in project');
        return;
      }
      DebugLogger.log('✅ Client reference found');

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) {
        DebugLogger.log('❌ Client document does not exist');
        return;
      }
      DebugLogger.log('✅ Client document exists');

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      DebugLogger.log('📋 Client FCM tokens: ${fcmTokens?.length ?? 0}');

      if (fcmTokens == null || fcmTokens.isEmpty) {
        DebugLogger.log('❌ Client has NO FCM tokens');
        return;
      }

      DebugLogger.log('💾 Creating notification document...');
      final recipientUid = _uidFromRef(clientRef);
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'milestone_started',
        'recipient_ref': clientRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Work Started',
        'body': '$projectName: Started working on "$milestoneName"',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'milestone_started',
          'recipient_uid': recipientUid,
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      DebugLogger.log('✅ Milestone started notification created successfully');
      debugPrint('Milestone started notification queued for client');
    } catch (e) {
      DebugLogger.log('❌ ERROR: $e');
      debugPrint('Error sending milestone started notification: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────
  // UNIFIED CHANGE SYSTEM NOTIFICATIONS
  // ────────────────────────────────────────────────────────────────

  /// Client reports a quality issue
  static Future<void> sendQualityIssueReportedNotification({
    required String projectId,
    required String projectName,
    required String description,
  }) async {
    try {
      DebugLogger.log('🚨 Quality Issue Reported - Starting notification...');
      final contractorData = await _getContractorFcmData(projectId);
      if (contractorData == null) {
        DebugLogger.log('❌ Contractor data not found');
        return;
      }
      DebugLogger.log('✅ Contractor data retrieved');

      final fcmTokens = contractorData['fcm_tokens'] as List<dynamic>;
      final contractorRef = contractorData['contractor_ref'] as DocumentReference;
      final recipientUid = _uidFromRef(contractorRef);
      DebugLogger.log('📋 Contractor FCM tokens: ${fcmTokens.length}');

      DebugLogger.log('💾 Creating notification document...');
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'quality_issue_reported',
        'recipient_ref': contractorRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Quality Issue Reported',
        'body': '$projectName: Client reported: ${description.substring(0, description.length > 50 ? 50 : description.length)}...',
        'data': {
          'project_id': projectId,
          'action': 'view_client_requests',
          'recipient_uid': recipientUid,
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      DebugLogger.log('✅ Quality issue notification created successfully');
      debugPrint('Quality issue notification queued for contractor');
    } catch (e) {
      DebugLogger.log('❌ ERROR: $e');
      debugPrint('Error sending quality issue notification: $e');
    }
  }

  /// Contractor marks quality issue as fixed
  static Future<void> sendQualityIssueFixedNotification({
    required String projectId,
    required String projectName,
    required String description,
  }) async {
    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) return;

      final clientRef = projectDoc.data()?['client_user_ref'] as DocumentReference?;
      if (clientRef == null) return;

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) return;

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      if (fcmTokens == null || fcmTokens.isEmpty) return;

      final recipientUid = _uidFromRef(clientRef);

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'quality_issue_fixed',
        'recipient_ref': clientRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Issue Fixed',
        'body': '$projectName: Contractor fixed: ${description.substring(0, description.length > 50 ? 50 : description.length)}...',
        'data': {
          'project_id': projectId,
          'action': 'view_project',
          'recipient_uid': recipientUid,
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Quality issue fixed notification queued for client');
    } catch (e) {
      debugPrint('Error sending quality issue fixed notification: $e');
    }
  }

  /// Client requests an addition
  static Future<void> sendAdditionRequestedNotification({
    required String projectId,
    required String projectName,
    required String description,
  }) async {
    try {
      DebugLogger.log('➕ Addition Requested - Starting notification...');
      final contractorData = await _getContractorFcmData(projectId);
      if (contractorData == null) {
        DebugLogger.log('❌ Contractor data not found');
        return;
      }
      DebugLogger.log('✅ Contractor data retrieved');

      final fcmTokens = contractorData['fcm_tokens'] as List<dynamic>;
      final contractorRef = contractorData['contractor_ref'] as DocumentReference;
      final recipientUid = _uidFromRef(contractorRef);
      DebugLogger.log('📋 Contractor FCM tokens: ${fcmTokens.length}');

      DebugLogger.log('💾 Creating notification document...');
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'addition_requested',
        'recipient_ref': contractorRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Addition Requested',
        'body': '$projectName: Client wants: ${description.substring(0, description.length > 50 ? 50 : description.length)}...',
        'data': {
          'project_id': projectId,
          'action': 'view_client_requests',
          'recipient_uid': recipientUid,
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      DebugLogger.log('✅ Addition request notification created successfully');
      debugPrint('Addition request notification queued for contractor');
    } catch (e) {
      DebugLogger.log('❌ ERROR: $e');
      debugPrint('Error sending addition request notification: $e');
    }
  }

  /// Contractor provides a quote for addition
  static Future<void> sendAdditionQuotedNotification({
    required String projectId,
    required String projectName,
    required double quotedAmount,
  }) async {
    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) return;

      final clientRef = projectDoc.data()?['client_user_ref'] as DocumentReference?;
      if (clientRef == null) return;

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) return;

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      if (fcmTokens == null || fcmTokens.isEmpty) return;

      final recipientUid = _uidFromRef(clientRef);

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'addition_quoted',
        'recipient_ref': clientRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Quote Received',
        'body': '$projectName: Contractor quoted \$${quotedAmount.toStringAsFixed(0)} for your request',
        'data': {
          'project_id': projectId,
          'action': 'view_project',
          'recipient_uid': recipientUid,
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Addition quoted notification queued for client');
    } catch (e) {
      debugPrint('Error sending addition quoted notification: $e');
    }
  }

  /// Client approves contractor's quote for addition
  static Future<void> sendAdditionApprovedNotification({
    required String projectId,
    required String projectName,
    required double quotedAmount,
  }) async {
    try {
      final contractorData = await _getContractorFcmData(projectId);
      if (contractorData == null) return;

      final fcmTokens = contractorData['fcm_tokens'] as List<dynamic>;
      final contractorRef = contractorData['contractor_ref'] as DocumentReference;
      final recipientUid = _uidFromRef(contractorRef);

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'addition_approved',
        'recipient_ref': contractorRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Addition Approved',
        'body': '$projectName: Client approved your \$${quotedAmount.toStringAsFixed(0)} quote',
        'data': {
          'project_id': projectId,
          'action': 'view_change_orders',
          'recipient_uid': recipientUid,
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Addition approved notification queued for contractor');
    } catch (e) {
      debugPrint('Error sending addition approved notification: $e');
    }
  }

  /// Notify client when contractor posts a milestone update
  static Future<void> sendMilestoneUpdateNotification({
    required String projectId,
    required String projectName,
    required String milestoneName,
    required String updateText,
  }) async {
    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) return;

      final clientRef = projectDoc.data()?['client_user_ref'] as DocumentReference?;
      if (clientRef == null) return;

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) return;

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      if (fcmTokens == null || fcmTokens.isEmpty) return;

      final recipientUid = _uidFromRef(clientRef);
      // Truncate update text for notification body
      final preview = updateText.length > 80
          ? '${updateText.substring(0, 80)}...'
          : updateText;

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'milestone_update',
        'recipient_ref': clientRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Update on $milestoneName',
        'body': '$projectName: $preview',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'milestone_update',
          'recipient_uid': recipientUid,
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Milestone update notification queued for client');
    } catch (e) {
      debugPrint('Error sending milestone update notification: $e');
    }
  }

  /// Notify client when contractor edits milestone structure
  static Future<void> sendMilestonesEditedNotification({
    required String projectId,
    required String projectName,
    required int milestoneCount,
  }) async {
    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) return;

      final clientRef = projectDoc.data()?['client_user_ref'] as DocumentReference?;
      if (clientRef == null) return;

      final clientDoc = await clientRef.get();
      if (!clientDoc.exists) return;

      final clientData = clientDoc.data() as Map<String, dynamic>?;
      final fcmTokens = clientData?['fcm_tokens'] as List<dynamic>?;
      if (fcmTokens == null || fcmTokens.isEmpty) return;

      final recipientUid = _uidFromRef(clientRef);
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'milestones_edited',
        'recipient_ref': clientRef,
        'recipient_uid': recipientUid,
        'fcm_tokens': fcmTokens,
        'title': 'Milestones Updated',
        'body': '$projectName: Contractor updated the milestone schedule ($milestoneCount milestones)',
        'data': {
          'project_id': projectId,
          'project_name': projectName,
          'type': 'milestones_edited',
          'recipient_uid': recipientUid,
        },
        'created_at': FieldValue.serverTimestamp(),
        'processed': false,
        'read': false,
      });

      debugPrint('Milestones edited notification queued for client');
    } catch (e) {
      debugPrint('Error sending milestones edited notification: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.notification?.title}');
}
