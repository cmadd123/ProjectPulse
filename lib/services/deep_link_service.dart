import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/client/client_project_timeline.dart';
import '../screens/public/contractor_public_profile.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription? _linkSubscription;
  String? _pendingProjectId;

  /// Initialize deep link listening
  void initialize(BuildContext context) {
    // Handle initial link when app is opened from terminated state
    _handleInitialLink(context);

    // Listen for links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(context, uri.toString());
      }
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });
  }

  /// Handle the initial link when app opens
  Future<void> _handleInitialLink(BuildContext context) async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(context, uri.toString());
      }
    } catch (e) {
      debugPrint('Error handling initial link: $e');
    }
  }

  /// Parse and handle deep link
  void _handleDeepLink(BuildContext context, String link) {
    final uri = Uri.parse(link);

    if (uri.pathSegments.isEmpty) return;

    final firstSegment = uri.pathSegments.first;

    // Handle invite links: projectpulse://invite/{projectId}
    // or https://projectpulse.app/invite/{projectId}
    if (firstSegment == 'invite' && uri.pathSegments.length > 1) {
      final projectId = uri.pathSegments[1];
      _handleProjectInvite(context, projectId);
    }

    // Handle contractor profile links: projectpulse://contractor/{contractorId}
    // or https://projectpulse.app/contractor/{contractorId}
    else if (firstSegment == 'contractor' && uri.pathSegments.length > 1) {
      final contractorId = uri.pathSegments[1];
      _handleContractorProfile(context, contractorId);
    }
  }

  /// Handle project invite link
  Future<void> _handleProjectInvite(BuildContext context, String projectId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // User not logged in - store projectId and navigate to auth
      _pendingProjectId = projectId;
      // The auth flow will check for _pendingProjectId after login
      return;
    }

    // User is logged in - navigate to project
    await _navigateToProject(context, projectId, user);
  }

  /// Navigate to project after auth
  Future<void> _navigateToProject(BuildContext context, String projectId, User user) async {
    try {
      // Get project data
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project not found')),
          );
        }
        return;
      }

      final projectData = projectDoc.data() as Map<String, dynamic>;
      final clientEmail = projectData['client_email'] as String?;

      // Check if user's email matches client email
      if (clientEmail != user.email) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This project invitation is for a different email address'),
            ),
          );
        }
        return;
      }

      // Check if user has set their role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists || userDoc.data()?['role'] == null) {
        // Auto-set role to client
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'user_id': user.uid,
          'email': user.email,
          'role': 'client',
          'created_at': FieldValue.serverTimestamp(),
          'client_profile': {
            'name': user.displayName ?? user.email?.split('@')[0] ?? 'Client',
            'accessible_projects': [projectId],
          },
        }, SetOptions(merge: true));
      } else {
        // Add project to accessible projects if not already there
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'client_profile.accessible_projects': FieldValue.arrayUnion([projectId]),
        });
      }

      // Navigate to project timeline
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ClientProjectTimeline(
              projectId: projectId,
              projectData: projectData,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to project: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Handle contractor profile link
  void _handleContractorProfile(BuildContext context, String contractorId) {
    // Navigate to public contractor profile (no auth required)
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ContractorPublicProfile(
            contractorId: contractorId,
          ),
        ),
      );
    }
  }

  /// Check if there's a pending project invite after login
  Future<void> handlePendingInvite(BuildContext context) async {
    if (_pendingProjectId != null) {
      final projectId = _pendingProjectId!;
      _pendingProjectId = null; // Clear it

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _navigateToProject(context, projectId, user);
      }
    }
  }

  /// Dispose subscriptions
  void dispose() {
    _linkSubscription?.cancel();
  }
}
