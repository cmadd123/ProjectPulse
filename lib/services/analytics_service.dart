import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized Firebase Analytics + Crashlytics wrapper.
///
/// Pre-tester instrumentation: watches the full conversion funnel from
/// sign-up to first paid invoice. Events are fire-and-forget — analytics
/// failures never break the user flow.
///
/// "first_" events only fire once per installation. Everything else is per-
/// occurrence. All events tolerate being called before Firebase is
/// initialized (they log a warning and return).
class Analytics {
  Analytics._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static bool _initialized = false;

  /// Call once during app startup after Firebase.initializeApp().
  static Future<void> init() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
      // Route uncaught Flutter errors and platform errors to Crashlytics.
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      _initialized = true;
    } catch (e, st) {
      debugPrint('Analytics init failed: $e\n$st');
    }
  }

  /// Tie subsequent events to the signed-in user. Clears on sign-out
  /// (pass `null`).
  static Future<void> setUserId(String? uid) async {
    if (!_initialized) return;
    try {
      await _analytics.setUserId(id: uid);
      if (uid != null) {
        await FirebaseCrashlytics.instance.setUserIdentifier(uid);
      }
    } catch (_) {}
  }

  /// Set the user's role as an analytics user property so funnels can
  /// split by contractor vs client vs crew.
  static Future<void> setUserRole(String role) async {
    if (!_initialized) return;
    try {
      await _analytics.setUserProperty(name: 'user_role', value: role);
    } catch (_) {}
  }

  // ─── Conversion events ─────────────────────────────────────────────

  static Future<void> signedUp({required String role}) async {
    await _log('sign_up', {'method': 'email', 'role': role});
  }

  static Future<void> roleSelected({required String role}) async {
    await _log('role_selected', {'role': role});
  }

  static Future<void> firstProjectCreated({
    required String projectId,
    String? projectName,
  }) async {
    if (await _fireOnce('first_project_created')) {
      await _log('first_project_created', {
        'project_id': projectId,
        if (projectName != null) 'project_name': projectName,
      });
    }
  }

  static Future<void> firstInviteSent({required String projectId}) async {
    if (await _fireOnce('first_invite_sent')) {
      await _log('first_invite_sent', {'project_id': projectId});
    }
  }

  static Future<void> milestoneCompleted({
    required String projectId,
    required String milestoneId,
    String? milestoneName,
  }) async {
    await _log('milestone_completed', {
      'project_id': projectId,
      'milestone_id': milestoneId,
      if (milestoneName != null) 'milestone_name': milestoneName,
    });
  }

  static Future<void> milestoneApproved({
    required String projectId,
    required String milestoneId,
    String? milestoneName,
    double? amount,
  }) async {
    await _log('milestone_approved', {
      'project_id': projectId,
      'milestone_id': milestoneId,
      if (milestoneName != null) 'milestone_name': milestoneName,
      if (amount != null) 'amount': amount,
    });
  }

  static Future<void> invoiceGenerated({
    required String projectId,
    required String invoiceId,
    double? amount,
  }) async {
    await _log('invoice_generated', {
      'project_id': projectId,
      'invoice_id': invoiceId,
      if (amount != null) 'amount': amount,
    });
  }

  static Future<void> paymentMarkedPaid({
    required String projectId,
    required String invoiceId,
    double? amount,
  }) async {
    await _log('payment_marked_paid', {
      'project_id': projectId,
      'invoice_id': invoiceId,
      if (amount != null) 'amount': amount,
    });
  }

  static Future<void> photoUploaded({
    required String projectId,
    String? milestoneId,
  }) async {
    await _log('photo_uploaded', {
      'project_id': projectId,
      if (milestoneId != null) 'milestone_id': milestoneId,
    });
  }

  static Future<void> clientPortalOpened({required String projectId}) async {
    await _log('client_portal_opened', {'project_id': projectId});
  }

  /// Escape hatch — manually record a non-fatal error to Crashlytics.
  static Future<void> recordError(Object error, StackTrace stack, {String? reason}) async {
    try {
      await FirebaseCrashlytics.instance.recordError(error, stack,
          reason: reason, fatal: false);
    } catch (_) {}
  }

  // ─── Internals ─────────────────────────────────────────────────────

  static Future<void> _log(String name, Map<String, Object?> params) async {
    if (!_initialized) {
      debugPrint('Analytics not initialized; dropping $name');
      return;
    }
    try {
      final cleaned = <String, Object>{};
      params.forEach((k, v) {
        if (v != null) cleaned[k] = v;
      });
      await _analytics.logEvent(name: name, parameters: cleaned);
    } catch (_) {}
  }

  /// Returns true the first time it's called with this key on this device.
  static Future<bool> _fireOnce(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = 'analytics_once_$key';
      if (prefs.getBool(storageKey) == true) return false;
      await prefs.setBool(storageKey, true);
      return true;
    } catch (_) {
      return true; // On failure prefer over-logging to under-logging.
    }
  }
}
