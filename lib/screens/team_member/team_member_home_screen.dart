import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/auth_utils.dart';
import 'team_member_project_screen.dart';
import '../contractor/schedule_screen.dart';
import '../shared/notification_center_screen.dart';

class TeamMemberHomeScreen extends StatelessWidget {
  const TeamMemberHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final teamId = userData['team_id'] as String?;
        final teamMemberId = userData['team_member_id'] as String?;
        final memberProfile =
            userData['team_member_profile'] as Map<String, dynamic>?;
        final memberName = memberProfile?['name'] ?? 'Team Member';
        final userDocRole = memberProfile?['team_role'] ?? 'worker';

        if (teamId == null) {
          return Scaffold(
            backgroundColor: Colors.grey[50],
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.group_off, size: 40, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No team linked yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ask your GC for an invite link to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 15),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      onPressed: () => confirmLogout(context),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Read role from the member doc (source of truth managed by GC)
        if (teamMemberId != null) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('teams')
                .doc(teamId)
                .collection('members')
                .doc(teamMemberId)
                .snapshots(),
            builder: (context, memberSnapshot) {
              final memberData = memberSnapshot.data?.data()
                  as Map<String, dynamic>?;
              final liveRole =
                  memberData?['role'] as String? ?? userDocRole;

              // Self-heal: sync user doc if roles drifted
              if (memberSnapshot.hasData &&
                  memberData != null &&
                  liveRole != userDocRole) {
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({
                  'team_member_profile': {
                    'name': memberName,
                    'team_role': liveRole,
                  },
                });
              }

              return _TeamMemberDashboard(
                teamId: teamId,
                memberName: memberName,
                teamRole: liveRole,
                userUid: user.uid,
              );
            },
          );
        }

        return _TeamMemberDashboard(
          teamId: teamId,
          memberName: memberName,
          teamRole: userDocRole,
          userUid: user.uid,
        );
      },
    );
  }
}

// =============================================================================
// DESIGN 3 DASHBOARD
// =============================================================================

class _TeamMemberDashboard extends StatefulWidget {
  final String teamId;
  final String memberName;
  final String teamRole;
  final String userUid;

  const _TeamMemberDashboard({
    required this.teamId,
    required this.memberName,
    required this.teamRole,
    required this.userUid,
  });

  @override
  State<_TeamMemberDashboard> createState() => _TeamMemberDashboardState();
}

class _TeamMemberDashboardState extends State<_TeamMemberDashboard> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';

  // Action item counts
  int _milestonesInProgress = 0;
  int _milestonesAwaitingApproval = 0;
  int _todayScheduleCount = 0;
  List<Map<String, dynamic>> _todaySchedule = [];
  bool _actionItemsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadActionItems();
    _loadTodaySchedule();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get teamId => widget.teamId;
  String get memberName => widget.memberName;
  String get teamRole => widget.teamRole;
  String get userUid => widget.userUid;
  bool get isForeman => teamRole == 'foreman' || teamRole == 'owner';

  Future<void> _loadActionItems() async {
    try {
      // Get projects assigned to this member (or all team projects for foreman)
      Query query;
      if (isForeman) {
        query = FirebaseFirestore.instance
            .collection('projects')
            .where('team_id', isEqualTo: teamId)
            .where('status', isEqualTo: 'active');
      } else {
        query = FirebaseFirestore.instance
            .collection('projects')
            .where('assigned_member_uids', arrayContains: userUid)
            .where('status', isEqualTo: 'active');
      }

      final projects = await query.get();
      int inProgress = 0;
      int awaitingApproval = 0;

      for (final project in projects.docs) {
        final milestones = await FirebaseFirestore.instance
            .collection('projects')
            .doc(project.id)
            .collection('milestones')
            .get();

        for (final m in milestones.docs) {
          final status = (m.data())['status'] as String? ?? 'pending';
          if (status == 'in_progress') inProgress++;
          if (status == 'awaiting_approval') awaitingApproval++;
        }
      }

      if (mounted) {
        setState(() {
          _milestonesInProgress = inProgress;
          _milestonesAwaitingApproval = awaitingApproval;
          _actionItemsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _actionItemsLoaded = true);
    }
  }

  Future<void> _loadTodaySchedule() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('schedule_entries')
          .where('user_uid', isEqualTo: userUid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      if (mounted) {
        setState(() {
          _todaySchedule = snap.docs.map((d) => d.data()).toList();
          _todayScheduleCount = _todaySchedule.length;
        });
      }
    } catch (_) {}
  }

  List<QueryDocumentSnapshot> _filterProjects(
      List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final project = doc.data() as Map<String, dynamic>;
      if (_statusFilter != 'all') {
        final status = project['status'] ?? 'active';
        if (status != _statusFilter) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name =
            (project['project_name'] ?? '').toString().toLowerCase();
        final client =
            (project['client_name'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !client.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  Color _roleColor() {
    switch (teamRole) {
      case 'foreman':
        return const Color(0xFF3B82F6);
      case 'owner':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF10B981);
    }
  }

  String _roleLabel() {
    switch (teamRole) {
      case 'foreman':
        return 'Foreman';
      case 'owner':
        return 'Owner';
      default:
        return 'Worker';
    }
  }

  String _roleEmoji() {
    switch (teamRole) {
      case 'foreman':
        return '\u{1F477}'; // construction worker
      case 'owner':
        return '\u{1F451}'; // crown
      default:
        return '\u{1F528}'; // hammer
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('teams')
              .doc(teamId)
              .snapshots(),
          builder: (context, teamSnapshot) {
            final teamName = (teamSnapshot.data?.data()
                    as Map<String, dynamic>?)?['name'] ??
                'My Team';
            return Text(teamName);
          },
        ),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isForeman)
            IconButton(
              icon: const Icon(Icons.calendar_month),
              tooltip: 'Crew Schedule',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ScheduleScreen()),
              ),
            ),
          // Notification bell with badge
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('recipient_uid', isEqualTo: userUid)
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              final count = snap.hasData ? snap.data!.docs.length : 0;
              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (count > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B35),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationCenterScreen()),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => confirmLogout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Profile header card
          _buildProfileHeader(context),

          // Projects list with action items
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: isForeman
                  ? FirebaseFirestore.instance
                      .collection('projects')
                      .where('team_id', isEqualTo: teamId)
                      .orderBy('created_at', descending: true)
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('projects')
                      .where('assigned_member_uids',
                          arrayContains: userUid)
                      .orderBy('created_at', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 64, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text('Error loading projects',
                              style: TextStyle(
                                  color: Colors.red[600], fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('${snapshot.error}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildActionItemsSection(),
                      _buildTodayScheduleSection(),
                      const SizedBox(height: 40),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.construction,
                                  size: 40, color: Colors.grey[400]),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No projects yet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isForeman
                                  ? 'Projects assigned to your team will show up here'
                                  : 'Your GC will assign you to projects',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                final allDocs = snapshot.data!.docs;
                final filtered = _filterProjects(allDocs);

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildActionItemsSection(),
                          _buildTodayScheduleSection(),
                          const SizedBox(height: 12),

                          // Search bar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search projects...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                prefixIcon: Icon(Icons.search,
                                    size: 20, color: Colors.grey[400]),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear,
                                            size: 18, color: Colors.grey[400]),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 0),
                              ),
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Filter chips
                          Row(
                            children: [
                              for (final filter in [
                                {'key': 'all', 'label': 'All'},
                                {'key': 'active', 'label': 'Active'},
                                {'key': 'completed', 'label': 'Completed'},
                              ]) ...[
                                ChoiceChip(
                                  label: Text(filter['label']!),
                                  selected: _statusFilter == filter['key'],
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() =>
                                          _statusFilter = filter['key']!);
                                    }
                                  },
                                  selectedColor: const Color(0xFF2D3748)
                                      .withOpacity(0.12),
                                  labelStyle: TextStyle(
                                    fontSize: 13,
                                    color: _statusFilter == filter['key']
                                        ? const Color(0xFF2D3748)
                                        : Colors.grey[600],
                                    fontWeight: _statusFilter == filter['key']
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  showCheckmark: false,
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                          if (_searchQuery.isNotEmpty ||
                              _statusFilter != 'all')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${filtered.length} of ${allDocs.length} projects',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                            ),
                          if (filtered.isEmpty) ...[
                            const SizedBox(height: 40),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.search_off,
                                      size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No projects match your search',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 15),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _statusFilter = 'all';
                                      });
                                    },
                                    child: const Text('Clear filters'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],
                      );
                    }

                    final doc = filtered[index - 1];
                    final project = doc.data() as Map<String, dynamic>;
                    return _buildProjectCard(context, doc.id, project);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile header — Design 3 white card with shadow
  // ---------------------------------------------------------------------------
  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _roleColor().withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _roleEmoji(),
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memberName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _roleColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _roleLabel(),
                    style: TextStyle(
                      color: _roleColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action items section — Design 3 style
  // ---------------------------------------------------------------------------
  Widget _buildActionItemsSection() {
    if (!_actionItemsLoaded) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: SizedBox(height: 48),
      );
    }

    final hasItems = _milestonesInProgress > 0 || _milestonesAwaitingApproval > 0;

    if (!hasItems) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green[600], size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'All caught up! No action items right now.',
              style: TextStyle(
                color: Colors.green[800],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Needs Your Attention',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 12),
          if (_milestonesInProgress > 0)
            _buildActionItem(
              emoji: '\u{1F528}',
              color: const Color(0xFF3B82F6),
              text:
                  '$_milestonesInProgress milestone${_milestonesInProgress == 1 ? '' : 's'} in progress',
              subtitle: isForeman
                  ? 'Mark complete when work is done'
                  : 'Post photo updates to keep the client informed',
            ),
          if (_milestonesAwaitingApproval > 0) ...[
            if (_milestonesInProgress > 0) const SizedBox(height: 10),
            _buildActionItem(
              emoji: '\u{23F3}',
              color: const Color(0xFFF59E0B),
              text:
                  '$_milestonesAwaitingApproval milestone${_milestonesAwaitingApproval == 1 ? '' : 's'} awaiting client approval',
              subtitle: 'Waiting on the client to review and approve',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required String emoji,
    required Color color,
    required String text,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: color.withOpacity(1),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Today's schedule section
  // ---------------------------------------------------------------------------
  Widget _buildTodayScheduleSection() {
    if (_todaySchedule.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u{1F4C5}', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                "Today's Schedule",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('EEE, MMM d').format(DateTime.now()),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._todaySchedule.map((entry) {
            final projectName =
                entry['project_name'] as String? ?? 'Unknown Project';
            final projHash = projectName.hashCode.abs();
            final colors = [
              const Color(0xFF3B82F6),
              const Color(0xFF10B981),
              const Color(0xFFF59E0B),
              const Color(0xFF8B5CF6),
              const Color(0xFF14B8A6),
            ];
            final color = colors[projHash % colors.length];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      projectName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: color.withOpacity(0.5)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Project card — GC-style with role-appropriate details
  //
  // GC sees: dollar amounts, pending COs from client, photo count
  // Foreman sees: milestone status (no $), crew on project today, what needs doing
  // Worker sees: milestone status (no $), what's active, post updates prompt
  // ---------------------------------------------------------------------------
  Widget _buildProjectCard(
      BuildContext context, String projectId, Map<String, dynamic> project) {
    final status = project['status'] ?? 'active';
    final crewCount =
        ((project['assigned_member_uids'] as List?)?.length ?? 0);
    final subCount = ((project['assigned_sub_ids'] as List?)?.length ?? 0);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('milestones')
          .orderBy('order')
          .snapshots(),
      builder: (context, milestonesSnapshot) {
        final milestones =
            milestonesSnapshot.hasData ? milestonesSnapshot.data!.docs : [];
        final completedCount = milestones
            .where((m) => (m.data() as Map)['status'] == 'approved')
            .length;
        final totalCount = milestones.length;
        final progress =
            totalCount > 0 ? completedCount / totalCount : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamMemberProjectScreen(
                      projectId: projectId,
                      projectData: project,
                      teamRole: teamRole,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header — Design 3: white card, no gradient
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                project['project_name'] ?? 'Untitled Project',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                            ),
                            if (totalCount > 0)
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: progress >= 1.0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF2D3748),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Foreman: crew + subs. Worker: client name.
                        Row(
                          children: [
                            if (isForeman) ...[
                              Icon(Icons.groups,
                                  size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                '$crewCount crew',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (subCount > 0) ...[
                                const SizedBox(width: 12),
                                Icon(Icons.engineering,
                                    size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  '$subCount sub${subCount == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ] else ...[
                              Icon(Icons.person_outline,
                                  size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                project['client_name'] ?? 'No client',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (totalCount > 0) ...[
                          const SizedBox(height: 14),
                          // Segmented progress bar — each milestone colored by status
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 6,
                              child: Row(
                                children: milestones.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final mData = entry.value.data() as Map<String, dynamic>;
                                  final mStatus = mData['status'] as String? ?? 'pending';
                                  Color color;
                                  switch (mStatus) {
                                    case 'approved':
                                      color = const Color(0xFF10B981);
                                      break;
                                    case 'in_progress':
                                      color = const Color(0xFF3B82F6);
                                      break;
                                    case 'awaiting_approval':
                                      color = const Color(0xFFF59E0B);
                                      break;
                                    default:
                                      color = Colors.grey[300]!;
                                  }
                                  return Expanded(
                                    child: Container(
                                      margin: EdgeInsets.only(
                                          right: i < totalCount - 1 ? 2 : 0),
                                      color: color,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$completedCount of $totalCount milestones complete',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Divider(height: 1, color: Colors.grey[200]),
                      ],
                    ),
                  ),

                  // Milestone preview list — NO dollar amounts
                  if (milestones.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...milestones.take(3).map((milestoneDoc) {
                            final milestone =
                                milestoneDoc.data() as Map<String, dynamic>;
                            final mStatus = milestone['status'] as String? ?? 'pending';
                            final isCompleted = mStatus == 'approved';
                            final isActive = mStatus == 'in_progress' ||
                                mStatus == 'awaiting_approval';

                            Color statusColor = Colors.grey;
                            if (isCompleted) {
                              statusColor = const Color(0xFF10B981);
                            } else if (mStatus == 'awaiting_approval') {
                              statusColor = const Color(0xFFF59E0B);
                            } else if (mStatus == 'in_progress') {
                              statusColor = const Color(0xFF3B82F6);
                            }

                            // Foreman sees actionable hints; worker sees status
                            String? trailingText;
                            if (isForeman) {
                              if (mStatus == 'in_progress') {
                                trailingText = 'Mark done';
                              } else if (mStatus == 'pending' || mStatus == 'not_started') {
                                trailingText = 'Start';
                              } else if (mStatus == 'awaiting_approval') {
                                trailingText = 'With client';
                              }
                            } else {
                              // Worker
                              if (mStatus == 'in_progress') {
                                trailingText = 'Post update';
                              } else if (mStatus == 'awaiting_approval') {
                                trailingText = 'With client';
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  // Status dot — same as GC card
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? statusColor
                                          : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: statusColor, width: 2),
                                    ),
                                    child: isCompleted
                                        ? const Icon(Icons.check,
                                            size: 14, color: Colors.white)
                                        : (isActive
                                            ? Center(
                                                child: Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: statusColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              )
                                            : null),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      milestone['name'] ?? 'Untitled',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isActive
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isCompleted
                                            ? Colors.grey[500]
                                            : const Color(0xFF2D3748),
                                        decoration: isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (trailingText != null)
                                    Text(
                                      trailingText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                          if (milestones.length > 3) ...[
                            const SizedBox(height: 4),
                            Text(
                              '+${milestones.length - 3} more milestones',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          // Bottom activity row
                          Row(
                            children: [
                              // Foreman: show crew count for today
                              if (isForeman) ...[
                                Icon(Icons.groups_outlined,
                                    size: 18, color: Colors.grey[600]),
                                const SizedBox(width: 6),
                                Text(
                                  '$crewCount assigned',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ] else ...[
                                // Worker: show update time
                                Icon(Icons.access_time,
                                    size: 16, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  project['updated_at'] != null
                                      ? _formatTimeAgo(
                                          (project['updated_at'] as Timestamp)
                                              .toDate())
                                      : 'No activity',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Icon(
                                Icons.arrow_forward,
                                size: 20,
                                color: const Color(0xFFFF6B35),
                              ),
                            ],
                          ),
                        ],
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
