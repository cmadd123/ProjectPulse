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
  String? _pendingTeamId;
  String? _pendingMemberId;

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

    // Handle invite links: projectpulse://join/{projectId}
    // or https://projectpulsehub.com/join/{projectId}
    // Team invites use: https://projectpulsehub.com/join/team?t={teamId}&m={memberId}
    if ((firstSegment == 'join' || firstSegment == 'invite') && uri.pathSegments.length > 1) {
      final secondSegment = uri.pathSegments[1];

      // Check if this is a team invite: /join/team?t=xxx&m=xxx
      if (secondSegment == 'team' &&
          uri.queryParameters.containsKey('t') &&
          uri.queryParameters.containsKey('m')) {
        _handleTeamInvite(
            context, uri.queryParameters['t']!, uri.queryParameters['m']!);
      } else {
        final projectId = secondSegment;
        _handleProjectInvite(context, projectId);
      }
    }

    // Handle project links: https://projectpulsehub.com/project/{projectId}
    else if (firstSegment == 'project' && uri.pathSegments.length > 1) {
      final projectId = uri.pathSegments[1];
      _handleProjectInvite(context, projectId);
    }

    // Handle team invite links (legacy): projectpulse://team/{teamId}/invite/{memberId}
    else if (firstSegment == 'team' && uri.pathSegments.length >= 4 && uri.pathSegments[2] == 'invite') {
      final teamId = uri.pathSegments[1];
      final memberId = uri.pathSegments[3];
      _handleTeamInvite(context, teamId, memberId);
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

  /// Handle team invite link
  Future<void> _handleTeamInvite(BuildContext context, String teamId, String memberId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Store pending invite — will be processed after signup/login
      _pendingTeamId = teamId;
      _pendingMemberId = memberId;
      return;
    }

    await _linkTeamMember(context, teamId, memberId, user);
  }

  /// Link a user to a team member doc after auth
  Future<void> _linkTeamMember(BuildContext context, String teamId, String memberId, User user) async {
    try {
      final teamRef = FirebaseFirestore.instance.collection('teams').doc(teamId);
      final memberRef = teamRef.collection('members').doc(memberId);

      // Verify member doc exists and is not already linked
      final memberDoc = await memberRef.get();
      if (!memberDoc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invite not found. Ask your GC to re-send.')),
          );
        }
        return;
      }

      final memberData = memberDoc.data()!;
      if (memberData['user_uid'] != null && memberData['user_uid'] != user.uid) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This invite has already been used by another account.')),
          );
        }
        return;
      }

      // Already linked to this user — just navigate
      if (memberData['user_uid'] == user.uid) {
        return;
      }

      // Link the member: set user_uid and status
      await memberRef.update({
        'user_uid': user.uid,
        'status': 'active',
      });

      // Add uid to team's member_uids array
      await teamRef.update({
        'member_uids': FieldValue.arrayUnion([user.uid]),
      });

      // Create/update user doc with team_member role
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'user_id': user.uid,
        'email': user.email,
        'role': 'team_member',
        'team_id': teamId,
        'team_member_id': memberId,
        'team_member_profile': {
          'name': memberData['name'] ?? user.displayName ?? '',
          'team_role': memberData['role'] ?? 'worker',
        },
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Auto-assign to projects the GC pre-selected
      final assignedProjectIds = (memberData['assigned_project_ids'] as List<dynamic>?) ?? [];
      for (final projectId in assignedProjectIds) {
        try {
          await FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId as String)
              .update({
            'assigned_member_uids': FieldValue.arrayUnion([user.uid]),
          });
        } catch (e) {
          debugPrint('Error assigning to project $projectId: $e');
        }
      }

      // Navigation happens automatically via AuthWrapper -> RoleDetectionScreen
      // which streams the user doc and routes on role: 'team_member'
    } catch (e) {
      debugPrint('Error linking team member: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining team: $e')),
        );
      }
    }
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

      // Update project to link this client user
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await FirebaseFirestore.instance.collection('projects').doc(projectId).update({
        'client_user_ref': userRef,
      });

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

  /// Check if there's a pending invite (project or team) after login
  Future<void> handlePendingInvite(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check deep-link based pending invites
    if (_pendingProjectId != null) {
      final projectId = _pendingProjectId!;
      _pendingProjectId = null;
      await _navigateToProject(context, projectId, user);
    }

    if (_pendingTeamId != null && _pendingMemberId != null) {
      final teamId = _pendingTeamId!;
      final memberId = _pendingMemberId!;
      _pendingTeamId = null;
      _pendingMemberId = null;
      await _linkTeamMember(context, teamId, memberId, user);
      return; // Already linked via deep link, skip email check
    }

    // Email-based auto-linking: check if user's email matches a pending team invite
    await _checkEmailBasedTeamInvite(context, user);
  }

  /// Check if the user's email matches a pending team member invite
  Future<void> _checkEmailBasedTeamInvite(BuildContext context, User user) async {
    try {
      // Skip if user already has a role (existing user, not a new sign-in)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()?['role'] != null) return;

      // Query all teams' members subcollections for matching email
      final memberQuery = await FirebaseFirestore.instance
          .collectionGroup('members')
          .where('email', isEqualTo: user.email)
          .where('status', isEqualTo: 'invited')
          .limit(1)
          .get();

      if (memberQuery.docs.isEmpty) return;

      final memberDoc = memberQuery.docs.first;
      final memberData = memberDoc.data();

      // Get the team ID from the document path: teams/{teamId}/members/{memberId}
      final teamId = memberDoc.reference.parent.parent!.id;
      final memberId = memberDoc.id;

      await _linkTeamMember(context, teamId, memberId, user);
    } catch (e) {
      debugPrint('Error checking email-based team invite: $e');
    }
  }

  /// Generate invite link for a project
  String generateInviteLink(String projectId) {
    // Simple HTTPS link that works with App Links
    return 'https://projectpulsehub.com/join/$projectId';
  }

  /// Generate invite link for a team member
  /// Uses the same /join path as client links (which already works in SMS)
  String generateTeamInviteLink(String teamId, String memberId) {
    return 'https://projectpulsehub.com/join/team?t=$teamId&m=$memberId';
  }

  /// Dispose subscriptions
  void dispose() {
    _linkSubscription?.cancel();
  }
}
