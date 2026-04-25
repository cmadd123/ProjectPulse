import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/auth_utils.dart';
import '../../services/connectivity_service.dart';
import '../../services/notification_service.dart';
import '../../backend/schema/milestone_record.dart';
import '../../components/project_timeline_widget.dart';
import '../../components/project_timeline_design3.dart'; // Design 3 version
import '../../components/project_timeline_clean.dart'; // Clean version
import '../../components/contractor_info_card.dart';
import '../../components/documents_tab_widget.dart';
import '../../components/client_changes_activity_widget.dart';
import '../../components/debug_console.dart';
import 'enhanced_photo_timeline.dart';
import 'leave_review_screen.dart';
import '../shared/project_chat_screen.dart';
import '../shared/project_chat_design3.dart'; // Design 3 version
import '../shared/notification_center_screen.dart';
import '../../components/skeleton_loader.dart';
import 'design_preview_menu.dart';
import 'home_tab_design3.dart';
import 'client_onboarding.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  int _currentTabIndex = 0;
  String? _selectedProjectId;
  Map<String, dynamic>? _selectedProjectData;
  int _pendingMilestonesCount = 0;
  int _pendingCOsCount = 0;
  int _unreadChatCount = 0;
  StreamSubscription? _milestoneSub;
  StreamSubscription? _coSub;
  StreamSubscription? _chatSub;
  StreamSubscription? _brandingSub;

  // Onboarding
  bool _showOnboarding = false;
  bool _onboardingChecked = false;

  // Contractor branding
  String? _contractorLogoUrl;
  String? _contractorBusinessName;
  Color _brandColor = const Color(0xFFFF6B35); // Default construction orange

  @override
  void dispose() {
    _milestoneSub?.cancel();
    _coSub?.cancel();
    _chatSub?.cancel();
    _brandingSub?.cancel();
    super.dispose();
  }

  void _selectProject(String projectId, Map<String, dynamic> projectData) {
    if (_selectedProjectId == projectId) return;
    _milestoneSub?.cancel();
    _coSub?.cancel();
    _chatSub?.cancel();
    _brandingSub?.cancel();

    DebugConsole().log('✅ CLIENT DASHBOARD - Selected project: ${projectData['project_name'] ?? projectId}');

    setState(() {
      _selectedProjectId = projectId;
      _selectedProjectData = projectData;
      _pendingMilestonesCount = 0;
      _pendingCOsCount = 0;
      _unreadChatCount = 0;
    });

    _ensureClientLinked(projectId);
    _listenToBadges(projectId);
    _listenToContractorBranding(projectData);
  }

  Future<void> _ensureClientLinked(String projectId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists) return;

      final data = projectDoc.data()!;
      final clientUserRef = data['client_user_ref'];
      final clientEmail = data['client_email'] as String?;

      if (clientUserRef != null) return;

      if (clientEmail != null && clientEmail == user.email) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .update({'client_user_ref': userRef});
      }
    } catch (e, st) {
      // Auto-link is best-effort — will retry on next load. Log so we can
      // see if it fails repeatedly for the same user.
      debugPrint('Client auto-link failed for project $projectId: $e\n$st');
    }
  }

  void _listenToBadges(String projectId) {
    _milestoneSub = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('milestones')
        .where('status', isEqualTo: 'awaiting_approval')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _pendingMilestonesCount = snapshot.docs.length);
      }
    });

    _coSub = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('change_orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _pendingCOsCount = snapshot.docs.length);
      }
    });

    _chatSub = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('messages')
        .where('sender_role', isEqualTo: 'contractor')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _unreadChatCount = snapshot.docs.length);
      }
    });
  }

  void _listenToContractorBranding(Map<String, dynamic> projectData) {
    final contractorRef = projectData['contractor_ref'] as DocumentReference?;
    if (contractorRef == null) return;

    _brandingSub = contractorRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists || !mounted) return;

      final userData = snapshot.data() as Map<String, dynamic>?;
      final profile = userData?['contractor_profile'] as Map<String, dynamic>?;
      if (profile == null) return;

      final logoUrl = profile['logo_url'] as String?;
      final businessName = profile['business_name'] as String?;

      if (!mounted) return;
      setState(() {
        _contractorLogoUrl = logoUrl;
        _contractorBusinessName = businessName;
      });

      // Priority: explicit brand_color > extracted from logo > default
      final colorHex = profile['brand_color'] as String?;
      if (colorHex != null && colorHex.isNotEmpty) {
        try {
          // Handle both "#RRGGBB" and "RRGGBB" formats
          final hex = colorHex.replaceFirst('#', '').padLeft(6, '0');
          final colorValue = int.parse('FF$hex', radix: 16);
          if (mounted) {
            setState(() => _brandColor = Color(colorValue));
          }
        } catch (e) {
          debugPrint('Brand color hex parse failed for "$colorHex": $e');
          if (logoUrl != null) await _extractColorFromLogo(logoUrl);
        }
      } else if (logoUrl != null) {
        await _extractColorFromLogo(logoUrl);
      }
    });
  }

  Future<void> _extractColorFromLogo(String logoUrl) async {
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: NetworkImage(logoUrl),
      );
      if (mounted) {
        setState(() => _brandColor = scheme.primary);
      }
    } catch (e) {
      // Cosmetic — keep default brand color but log so we can spot bad logo URLs.
      debugPrint('Logo color extraction failed for "$logoUrl": $e');
    }
  }

  /// Returns white or black text depending on background brightness
  Color _textOnBrand() {
    return _brandColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  Future<void> _checkOnboarding() async {
    if (_onboardingChecked) return;
    _onboardingChecked = true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final seen = doc.data()?['client_onboarding_seen'] == true;
    if (!seen && mounted) {
      setState(() => _showOnboarding = true);
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _showOnboarding = false);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'client_onboarding_seen': true,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    DebugConsole().log('🔍 CLIENT DASHBOARD BUILD - selectedProject: ${_selectedProjectId ?? "null"}');

    // Check onboarding on first build
    _checkOnboarding();

    if (_showOnboarding) {
      return ClientOnboarding(onComplete: _completeOnboarding);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('client_email', isEqualTo: user.email)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: SafeArea(child: const SkeletonProjectList()),
          );
        }

        final projects = snapshot.data?.docs ?? [];

        if (projects.isEmpty) {
          return _buildEmptyState();
        }

        // Auto-select first project if none selected
        if (_selectedProjectId == null) {
          final firstDoc = projects.first;
          final firstData = firstDoc.data() as Map<String, dynamic>;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _selectProject(firstDoc.id, firstData);
          });
          return Scaffold(
            body: SafeArea(child: const SkeletonProjectList()),
          );
        }

        // Update project data if it changed from stream
        for (final doc in projects) {
          if (doc.id == _selectedProjectId) {
            final freshData = doc.data() as Map<String, dynamic>;
            if (_selectedProjectData != freshData) {
              _selectedProjectData = freshData;
            }
            break;
          }
        }

        final projectName = _selectedProjectData?['project_name'] ?? 'Project';

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                // Contractor logo
                _buildAppBarLogo(),
                const SizedBox(width: 10),
                Expanded(
                  child: projects.length > 1
                      ? _buildProjectDropdown(projects)
                      : Text(projectName),
                ),
              ],
            ),
            backgroundColor: _brandColor,
            foregroundColor: _textOnBrand(),
            actions: [
              // // My Requests button - REMOVED (redundant with "Needs Your Attention" section)
              // IconButton(
              //   icon: const Icon(Icons.list_alt),
              //   tooltip: 'My Requests',
              //   onPressed: () {
              //     DebugConsole().log('🔍 CLIENT DASHBOARD - "My Requests" button TAPPED');
              //     if (_selectedProjectId == null) {
              //       DebugConsole().log('❌ CLIENT DASHBOARD - No project selected');
              //       return;
              //     }
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => Scaffold(
              //           appBar: AppBar(
              //             title: const Text('My Requests'),
              //             backgroundColor: _brandColor,
              //             foregroundColor: _textOnBrand(),
              //           ),
              //           body: ClientChangesActivityWidget(
              //             projectId: _selectedProjectId!,
              //             userRole: 'client',
              //           ),
              //         ),
              //       ),
              //     );
              //   },
              // ),
              // Design preview button (DEBUG)
              IconButton(
                icon: const Icon(Icons.palette_outlined),
                tooltip: 'Preview Designs',
                color: Colors.amber.withOpacity(0.9),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DesignPreviewMenu()),
                  );
                },
              ),
              // // Debug console button - REMOVED for production
              // IconButton(
              //   icon: const Icon(Icons.bug_report),
              //   tooltip: 'Debug Console',
              //   color: Colors.purple.withOpacity(0.8),
              //   onPressed: () {
              //     DebugConsole().log('🔍 CLIENT DASHBOARD - Debug console opened');
              //     showModalBottomSheet(
              //       context: context,
              //       isScrollControlled: true,
              //       backgroundColor: Colors.black87,
              //       builder: (context) => const DebugConsoleScreen(),
              //     );
              //   },
              // ),
              // // Notification bell - REMOVED (redundant with "Needs Your Attention" section in Design 3)
              // StreamBuilder<QuerySnapshot>(
              //   stream: FirebaseFirestore.instance
              //       .collection('notifications')
              //       .where('recipient_uid', isEqualTo: user.uid)
              //       .where('read', isEqualTo: false)
              //       .snapshots(),
              //   builder: (context, notifSnap) {
              //     final count = notifSnap.data?.docs.length ?? 0;
              //     return IconButton(
              //       icon: Badge(
              //         isLabelVisible: count > 0,
              //         label: Text('$count', style: const TextStyle(fontSize: 10)),
              //         child: const Icon(Icons.notifications_outlined),
              //       ),
              //       onPressed: () {
              //         Navigator.push(
              //           context,
              //           MaterialPageRoute(
              //             builder: (_) => const NotificationCenterScreen(),
              //           ),
              //         );
              //       },
              //     );
              //   },
              // ),
            ],
          ),
          body: IndexedStack(
            index: _currentTabIndex,
            children: [
              // Tab 0: Home (Design 3 - Personality Injection)
              HomeTabDesign3(
                projectId: _selectedProjectId!,
                projectData: _selectedProjectData!,
                brandColor: _brandColor,
                onTabSwitch: (index) => setState(() => _currentTabIndex = index),
              ),
              // Tab 1: Photos
              EnhancedPhotoTimeline(
                projectId: _selectedProjectId!,
                projectData: _selectedProjectData!,
                showAppBar: false,
              ),
              // Tab 2: Chat (Design 3 - Personality Injection)
              ProjectChatDesign3(
                projectId: _selectedProjectId!,
                projectName: projectName,
                isContractor: false,
                embedded: true,
              ),
              // Tab 3: Milestones (Clean design)
              ProjectTimelineClean(
                projectId: _selectedProjectId!,
                projectData: _selectedProjectData!,
                userRole: 'client',
              ),
              // Tab 4: More
              _MoreTab(
                projectId: _selectedProjectId!,
                projectData: _selectedProjectData!,
                brandColor: _brandColor,
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentTabIndex,
            indicatorColor: _brandColor.withOpacity(0.15),
            onDestinationSelected: (index) {
              setState(() => _currentTabIndex = index);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.timeline_outlined),
                selectedIcon: Icon(Icons.timeline),
                label: 'Timeline',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: _unreadChatCount > 0,
                  label: Text('$_unreadChatCount', style: const TextStyle(fontSize: 10)),
                  child: const Icon(Icons.chat_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: _unreadChatCount > 0,
                  label: Text('$_unreadChatCount', style: const TextStyle(fontSize: 10)),
                  child: const Icon(Icons.chat),
                ),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: _pendingMilestonesCount > 0,
                  label: Text('$_pendingMilestonesCount', style: const TextStyle(fontSize: 10)),
                  child: const Icon(Icons.flag_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: _pendingMilestonesCount > 0,
                  label: Text('$_pendingMilestonesCount', style: const TextStyle(fontSize: 10)),
                  child: const Icon(Icons.flag),
                ),
                label: 'Milestones',
              ),
              const NavigationDestination(
                icon: Icon(Icons.more_horiz),
                selectedIcon: Icon(Icons.more_horiz),
                label: 'More',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectDropdown(List<QueryDocumentSnapshot> projects) {
    final textColor = _textOnBrand();
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedProjectId,
        dropdownColor: _brandColor,
        icon: Icon(Icons.arrow_drop_down, color: textColor),
        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        items: projects.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return DropdownMenuItem<String>(
            value: doc.id,
            child: Text(data['project_name'] ?? 'Project'),
          );
        }).toList(),
        onChanged: (projectId) {
          if (projectId == null) return;
          final doc = projects.firstWhere((d) => d.id == projectId);
          _selectProject(doc.id, doc.data() as Map<String, dynamic>);
        },
      ),
    );
  }

  Widget _buildAppBarLogo() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: _contractorLogoUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: _contractorLogoUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  Icons.business,
                  size: 18,
                  color: Colors.grey[400],
                ),
              ),
            )
          : Icon(
              Icons.business,
              size: 18,
              color: Colors.grey[400],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ProjectPulse'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => confirmLogout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mail_outline, size: 64, color: Colors.blue[300]),
              ),
              const SizedBox(height: 28),
              Text(
                'Waiting for Your Invite',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your contractor will send you a link to view your project. '
                'Once you tap that link, everything will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Text(
                      'How it works',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildHowItWorksStep('1', 'Contractor sends you a project invite link'),
                    const SizedBox(height: 8),
                    _buildHowItWorksStep('2', 'Tap the link to connect your account'),
                    const SizedBox(height: 8),
                    _buildHowItWorksStep('3', 'View updates, approve milestones, and chat'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowItWorksStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

}

// ─────────────────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  final String projectId;
  final Map<String, dynamic> projectData;
  final Color brandColor;
  final ValueChanged<int> onTabSwitch;

  const _HomeTab({
    required this.projectId,
    required this.projectData,
    required this.brandColor,
    required this.onTabSwitch,
  });

  Future<void> _respondToChangeOrder(
    BuildContext context,
    String changeOrderId,
    bool approve,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('change_orders')
          .doc(changeOrderId)
          .update({
        'status': approve ? 'approved' : 'declined',
        'responded_at': FieldValue.serverTimestamp(),
        'responded_by_ref': userRef,
      });

      if (approve) {
        final changeOrderDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('change_orders')
            .doc(changeOrderId)
            .get();

        final costChange = changeOrderDoc.data()?['cost_change'] as num? ?? 0;

        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .update({
          'current_cost': FieldValue.increment(costChange.toDouble()),
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Change order approved' : 'Change order declined'),
            backgroundColor: approve ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _approveMilestone(BuildContext context, String milestoneId, String milestoneName) async {
    debugPrint('🔍 Dashboard _approveMilestone: Starting approval for $milestoneName');

    try {
      // Update milestone status to approved
      debugPrint('🔍 Dashboard _approveMilestone: Updating Firestore...');
      await MilestoneRecord.updateMilestone(projectId, milestoneId, {
        'status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
      });
      debugPrint('🔍 Dashboard _approveMilestone: Firestore updated successfully');

      // Show success SnackBar IMMEDIATELY after Firestore update
      if (context.mounted) {
        debugPrint('🔍 Dashboard _approveMilestone: Context is mounted, showing SnackBar');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milestone approved! Contractor will be notified.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        debugPrint('❌ Dashboard _approveMilestone: Context NOT mounted, cannot show SnackBar');
      }

      // Send notification to contractor (non-blocking - happens in background)
      debugPrint('🔍 Dashboard _approveMilestone: Sending notification in background...');
      final projectName = projectData['project_name'] as String? ?? 'Project';
      NotificationService.sendMilestoneApprovedNotification(
        projectId: projectId,
        projectName: projectName,
        milestoneName: milestoneName,
      ).catchError((error) {
        debugPrint('❌ Failed to send notification: $error');
      });
    } catch (e) {
      debugPrint('❌ Dashboard _approveMilestone: Error occurred: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _requestChanges(BuildContext context, String milestoneId, String milestoneName) async{
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Changes'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Describe what changes are needed...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    reasonController.dispose();

    if (result == null || result.isEmpty) return;

    try {
      await MilestoneRecord.updateMilestone(projectId, milestoneId, {
        'status': 'in_progress',
        'changes_requested': true,
        'dispute_reason': result,
        'last_change_request_at': FieldValue.serverTimestamp(),
      });

      // Show success SnackBar IMMEDIATELY after Firestore update
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes requested - contractor will be notified'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Send notification to contractor (non-blocking - happens in background)
      final projectName = projectData['project_name'] as String? ?? 'Project';
      NotificationService.sendChangesRequestedNotification(
        projectId: projectId,
        projectName: projectName,
        milestoneName: milestoneName,
      ).catchError((error) {
        debugPrint('Failed to send notification: $error');
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 2A + 2B: Hero photo header with progress ring
          _buildHeroHeader(context),
          // 2C: Action cards
          _buildActionCards(context),
          // 2D: Financial summary
          _buildFinancialSummary(context),
          // 2E: Recent activity
          _buildRecentActivity(context),
          // 2F: Contractor info
          ContractorInfoCard(
            projectData: projectData,
            compact: true,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Powered by ProjectPulse',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── 2A: Hero Header ──────────────────────────────────

  Widget _buildHeroHeader(BuildContext context) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Branded gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF292524), // Warm charcoal
                  const Color(0xFF44403C),
                  brandColor,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
          // Progress ring + day counter
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StreamBuilder<List<MilestoneRecord>>(
                  stream: MilestoneRecord.getMilestones(projectId),
                  builder: (context, milestoneSnap) {
                    final milestones = milestoneSnap.data ?? [];
                    final total = milestones.length;
                    final completed = milestones.where(
                      (m) => m.status == 'approved' || m.status == 'complete',
                    ).length;
                    final progress = total > 0 ? completed / total : 0.0;

                    return _AnimatedProgressRing(
                      progress: progress,
                      completed: completed,
                      total: total,
                      brandColor: brandColor,
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildDayCounter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCounter() {
    final startDate = (projectData['start_date'] as Timestamp?)?.toDate();
    final endDate = (projectData['estimated_end_date'] as Timestamp?)?.toDate();

    if (startDate == null || endDate == null) {
      return const Text(
        'Timeline TBD',
        style: TextStyle(color: Colors.white70, fontSize: 14),
      );
    }

    final totalDays = endDate.difference(startDate).inDays;
    var daysElapsed = DateTime.now().difference(startDate).inDays;
    if (daysElapsed < 0) daysElapsed = 0;
    if (daysElapsed > totalDays) daysElapsed = totalDays;

    return Text(
      'Day $daysElapsed of $totalDays',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  // ── 2C: Action Cards ───────────────────────────────────

  Widget _buildActionCards(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('milestones')
          .where('status', isEqualTo: 'awaiting_approval')
          .snapshots(),
      builder: (context, milestoneSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('change_orders')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, coSnap) {
            final pendingMilestones = milestoneSnap.data?.docs ?? [];
            final pendingCOs = coSnap.data?.docs ?? [];

            if (pendingMilestones.isEmpty && pendingCOs.isEmpty) {
              return _buildAllCaughtUp();
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active, color: Colors.amber[800], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Needs Your Attention',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber[700],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pendingMilestones.length + pendingCOs.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Milestone cards
                  for (final doc in pendingMilestones)
                    _buildMilestoneActionCard(context, doc),
                  // CO cards
                  for (final doc in pendingCOs)
                    _buildCOActionCard(context, doc),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAllCaughtUp() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFE6FFFA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF81E6D9)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF38B2AC).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF38B2AC),
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "You're all caught up!",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF234E52),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No items need your approval right now',
              style: TextStyle(
                fontSize: 14,
                color: Colors.teal[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneActionCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? 'Milestone';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Milestone Complete',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (amount > 0) ...[
              const SizedBox(height: 4),
              Text(
                currencyFormat.format(amount),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _requestChanges(context, doc.id, name),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Request Changes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange[700],
                      side: BorderSide(color: Colors.orange[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveMilestone(context, doc.id, name),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCOActionCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final description = data['description'] as String? ?? '';
    final costChange = (data['cost_change'] as num?)?.toDouble() ?? 0;
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Colors.amber[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.request_quote, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Change Order',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${costChange >= 0 ? '+' : ''}${currencyFormat.format(costChange.abs())}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: costChange >= 0 ? Colors.red[700] : Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _respondToChangeOrder(context, doc.id, false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _respondToChangeOrder(context, doc.id, true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 2D: Financial Summary ──────────────────────────────

  Widget _buildFinancialSummary(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final originalCost = (data['original_cost'] as num?)?.toDouble() ?? 0;
        final currentCost = (data['current_cost'] as num?)?.toDouble() ?? originalCost;
        final changeOrderDiff = currentCost - originalCost;
        final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: brandColor, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Project Finances',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFinanceRow('Original Contract', currencyFormat.format(originalCost)),
                  if (changeOrderDiff != 0) ...[
                    const SizedBox(height: 8),
                    _buildFinanceRow(
                      'Change Orders',
                      '${changeOrderDiff >= 0 ? '+' : ''}${currencyFormat.format(changeOrderDiff.abs())}',
                      valueColor: changeOrderDiff >= 0 ? Colors.red[700] : Colors.green[700],
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  _buildFinanceRow(
                    'Current Total',
                    currencyFormat.format(currentCost),
                    isBold: true,
                    valueColor: brandColor,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinanceRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Colors.grey[900],
          ),
        ),
      ],
    );
  }

  // ── 2E: Recent Activity ────────────────────────────────

  Widget _buildRecentActivity(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('updates')
          .orderBy('created_at', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => onTabSwitch(1), // Switch to Photos tab
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final doc in docs)
                _buildActivityRow(doc),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final photoUrl = data['photo_url'] as String?;
    final caption = data['caption'] as String? ?? 'Photo update';
    final createdAt = (data['created_at'] as Timestamp?)?.toDate();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.image, color: Colors.grey[400]),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.image, color: Colors.grey[400]),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (createdAt != null)
            Text(
              _timeAgo(createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// ANIMATED PROGRESS RING
// ─────────────────────────────────────────────────────────

class _AnimatedProgressRing extends StatefulWidget {
  final double progress;
  final int completed;
  final int total;
  final Color brandColor;

  const _AnimatedProgressRing({
    required this.progress,
    required this.completed,
    required this.total,
    required this.brandColor,
  });

  @override
  State<_AnimatedProgressRing> createState() => _AnimatedProgressRingState();
}

class _AnimatedProgressRingState extends State<_AnimatedProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _ProgressRingPainter(
              progress: _animation.value,
              color: widget.brandColor,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.total > 0
                        ? '${(_animation.value * 100).toInt()}%'
                        : '0%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.completed}/${widget.total}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ProgressRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const strokeWidth = 10.0;

    // Track
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// ─────────────────────────────────────────────────────────
// MORE TAB
// ─────────────────────────────────────────────────────────

class _MoreTab extends StatelessWidget {
  final String projectId;
  final Map<String, dynamic> projectData;
  final Color brandColor;

  const _MoreTab({
    required this.projectId,
    required this.projectData,
    required this.brandColor,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = projectData['status'] == 'completed';

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Contractor info (full card)
        ContractorInfoCard(
          projectData: projectData,
          compact: false,
        ),
        const Divider(),
        _buildMenuItem(
          context,
          icon: Icons.info_outline,
          label: 'Project Details',
          subtitle: 'Address, dates & status',
          onTap: () => _showProjectDetails(context),
        ),
        _buildMenuItem(
          context,
          icon: Icons.folder_outlined,
          label: 'Documents',
          subtitle: 'Project documents & files',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: const Text('Documents'),
                  backgroundColor: brandColor,
                  foregroundColor: brandColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                ),
                body: DocumentsTabWidget(
                  projectId: projectId,
                  canManage: false,
                ),
              ),
            ),
          ),
        ),
        if (isCompleted)
          _buildMenuItem(
            context,
            icon: Icons.star_outline,
            label: 'Leave a Review',
            subtitle: 'Share your experience',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LeaveReviewScreen(
                  projectId: projectId,
                  projectData: projectData,
                ),
              ),
            ),
          ),
        const Divider(),
        _buildMenuItem(
          context,
          icon: Icons.logout,
          label: 'Sign Out',
          subtitle: 'Log out of your account',
          isDestructive: true,
          onTap: () => confirmLogout(context),
        ),
      ],
    );
  }

  void _showProjectDetails(BuildContext context) {
    final address = projectData['address'] as String?;
    final status = projectData['status'] as String? ?? 'active';
    final startDate = (projectData['start_date'] as Timestamp?)?.toDate();
    final endDate = (projectData['estimated_end_date'] as Timestamp?)?.toDate();
    final originalCost = (projectData['original_cost'] as num?)?.toDouble();
    final currentCost = (projectData['current_cost'] as num?)?.toDouble();
    final dateFormat = DateFormat('MMM d, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              projectData['project_name'] ?? 'Project',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (address != null)
              _detailRow(Icons.location_on_outlined, 'Address', address),
            _detailRow(
              Icons.circle,
              'Status',
              status[0].toUpperCase() + status.substring(1),
              valueColor: status == 'completed' ? Colors.green : Colors.blue,
            ),
            if (startDate != null)
              _detailRow(Icons.calendar_today, 'Start Date', dateFormat.format(startDate)),
            if (endDate != null)
              _detailRow(Icons.event, 'Est. Completion', dateFormat.format(endDate)),
            if (originalCost != null)
              _detailRow(Icons.attach_money, 'Contract Value', currencyFormat.format(originalCost)),
            if (currentCost != null && currentCost != originalCost)
              _detailRow(Icons.trending_up, 'Current Total', currencyFormat.format(currentCost)),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isDestructive
            ? Colors.red.withOpacity(0.1)
            : brandColor.withOpacity(0.1),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : brandColor,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isDestructive ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
