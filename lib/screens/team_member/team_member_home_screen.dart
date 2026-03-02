import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/auth_utils.dart';
import 'team_member_project_screen.dart';
import '../contractor/schedule_screen.dart';

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
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No team linked',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask your GC for an invite link',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () => confirmLogout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
                ],
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
              // Use member doc role, fall back to user doc role
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

              return _TeamMemberProjectsScreen(
                teamId: teamId,
                memberName: memberName,
                teamRole: liveRole,
                userUid: user.uid,
              );
            },
          );
        }

        return _TeamMemberProjectsScreen(
          teamId: teamId,
          memberName: memberName,
          teamRole: userDocRole,
          userUid: user.uid,
        );
      },
    );
  }
}

class _TeamMemberProjectsScreen extends StatefulWidget {
  final String teamId;
  final String memberName;
  final String teamRole;
  final String userUid;

  const _TeamMemberProjectsScreen({
    required this.teamId,
    required this.memberName,
    required this.teamRole,
    required this.userUid,
  });

  @override
  State<_TeamMemberProjectsScreen> createState() =>
      _TeamMemberProjectsScreenState();
}

class _TeamMemberProjectsScreenState
    extends State<_TeamMemberProjectsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';
  bool _scheduleExpanded = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get teamId => widget.teamId;
  String get memberName => widget.memberName;
  String get teamRole => widget.teamRole;
  String get userUid => widget.userUid;

  List<QueryDocumentSnapshot> _filterProjects(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final project = doc.data() as Map<String, dynamic>;
      if (_statusFilter != 'all') {
        final status = project['status'] ?? 'active';
        if (status != _statusFilter) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = (project['project_name'] ?? '').toString().toLowerCase();
        final client = (project['client_name'] ?? '').toString().toLowerCase();
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
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${diff.inDays}d ago';
  }

  Color _roleColor() {
    switch (teamRole) {
      case 'foreman':
        return Colors.blue;
      case 'owner':
        return Colors.amber[700]!;
      default:
        return Colors.green;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (teamRole == 'foreman')
            IconButton(
              icon: const Icon(Icons.calendar_month),
              tooltip: 'Crew Schedule',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ScheduleScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => confirmLogout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Member info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _roleColor().withOpacity(0.15),
                  child: Icon(
                    teamRole == 'foreman'
                        ? Icons.engineering
                        : Icons.construction,
                    color: _roleColor(),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
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
          ),

          // Projects list (with schedule, search, chips as scrollable header)
          // Foremen see ALL team projects; workers only see assigned ones
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: teamRole == 'foreman'
                  ? FirebaseFirestore.instance
                      .collection('projects')
                      .where('team_id', isEqualTo: teamId)
                      .orderBy('created_at', descending: true)
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('projects')
                      .where('assigned_member_uids', arrayContains: userUid)
                      .orderBy('created_at', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 80, color: Colors.red[400]),
                        const SizedBox(height: 16),
                        Text('Error loading projects',
                            style: TextStyle(color: Colors.red[600])),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('${snapshot.error}',
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      // Collapsible schedule
                      _buildScheduleSection(),
                      const SizedBox(height: 32),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.work_outline,
                                size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No projects yet',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Your GC will assign you to projects',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[500],
                                height: 1.5,
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

                // +1 for the header (schedule + search + chips)
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    // First item: schedule + search bar + filter chips
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildScheduleSection(),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search projects...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                            onChanged: (value) => setState(() => _searchQuery = value),
                          ),
                          const SizedBox(height: 8),
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
                                      setState(() => _statusFilter = filter['key']!);
                                    }
                                  },
                                  selectedColor:
                                      Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  labelStyle: TextStyle(
                                    fontSize: 13,
                                    color: _statusFilter == filter['key']
                                        ? Theme.of(context).colorScheme.primary
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
                          if (_searchQuery.isNotEmpty || _statusFilter != 'all')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${filtered.length} of ${allDocs.length} projects',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                            ),
                          if (filtered.isEmpty) ...[
                            const SizedBox(height: 40),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No projects match your search',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
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
                          const SizedBox(height: 8),
                        ],
                      );
                    }

                    final doc = filtered[index - 1];
                    final project = doc.data() as Map<String, dynamic>;
                    final status = project['status'] ?? 'active';
                    final crewCount = ((project['assigned_member_uids'] as List?)?.length ?? 0);
                    final subCount = ((project['assigned_sub_ids'] as List?)?.length ?? 0);

                    // Get milestone progress via stream
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('projects')
                          .doc(doc.id)
                          .collection('milestones')
                          .orderBy('order')
                          .snapshots(),
                      builder: (context, milestonesSnapshot) {
                        final milestones = milestonesSnapshot.hasData
                            ? milestonesSnapshot.data!.docs
                            : [];
                        final completedCount = milestones
                            .where((m) =>
                                (m.data() as Map)['status'] == 'approved')
                            .length;
                        final totalCount = milestones.length;
                        final progress = totalCount > 0
                            ? completedCount / totalCount
                            : 0.0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TeamMemberProjectScreen(
                                    projectId: doc.id,
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
                                // Gradient header
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              project['project_name'] ??
                                                  'Untitled Project',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          if (totalCount > 0)
                                            Text(
                                              '${(progress * 100).toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.person_outline, size: 14,
                                              color: Colors.white.withOpacity(0.9)),
                                          const SizedBox(width: 4),
                                          Text(
                                            project['client_name'] ?? 'No client',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white.withOpacity(0.9),
                                            ),
                                          ),
                                          if (crewCount > 0) ...[
                                            const SizedBox(width: 12),
                                            Icon(Icons.groups, size: 14,
                                                color: Colors.white.withOpacity(0.9)),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$crewCount crew',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.white.withOpacity(0.9),
                                              ),
                                            ),
                                          ],
                                          if (subCount > 0) ...[
                                            const SizedBox(width: 12),
                                            Icon(Icons.engineering, size: 14,
                                                color: Colors.white.withOpacity(0.9)),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$subCount sub${subCount == 1 ? '' : 's'}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.white.withOpacity(0.9),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (totalCount > 0) ...[
                                        const SizedBox(height: 12),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            minHeight: 6,
                                            backgroundColor:
                                                Colors.white.withOpacity(0.3),
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                    Color>(Colors.white),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '$completedCount of $totalCount milestones',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white
                                                .withOpacity(0.9),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Bottom section with status + current milestone
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: status == 'active'
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.grey.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          status == 'active'
                                              ? 'Active'
                                              : 'Completed',
                                          style: TextStyle(
                                            color: status == 'active'
                                                ? Colors.green[700]
                                                : Colors.grey[600],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (project['updated_at'] != null) ...[
                                        Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatTimeAgo((project['updated_at'] as Timestamp).toDate()),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _scheduleExpanded = !_scheduleExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'My Schedule',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _scheduleExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _scheduleExpanded
              ? _WeekScheduleStrip(teamId: teamId, userUid: userUid)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Personal week schedule strip — shows this worker's assignments Mon-Fri
class _WeekScheduleStrip extends StatefulWidget {
  final String teamId;
  final String userUid;

  const _WeekScheduleStrip({required this.teamId, required this.userUid});

  @override
  State<_WeekScheduleStrip> createState() => _WeekScheduleStripState();
}

class _WeekScheduleStripState extends State<_WeekScheduleStrip> {
  late DateTime _weekStart;

  static const _projectColors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF009688),
    Color(0xFFE91E63),
    Color(0xFF3F51B5),
    Color(0xFFFF5722),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
  }

  Color _projectColor(String projectId) {
    return _projectColors[projectId.hashCode.abs() % _projectColors.length];
  }

  List<DateTime> get _weekDays =>
      List.generate(5, (i) => _weekStart.add(Duration(days: i)));

  void _shiftWeek(int direction) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * direction));
    });
  }

  bool get _isCurrentWeek {
    final now = DateTime.now();
    final currentWeekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return _weekStart.isAtSameMomentAs(currentWeekStart);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = _weekStart.add(const Duration(days: 4));
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('schedule_entries')
          .where('user_uid', isEqualTo: widget.userUid)
          .snapshots(),
      builder: (context, snap) {
        final Map<int, List<Map<String, dynamic>>> entriesByDay = {};
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp?)?.toDate();
            if (date == null) continue;
            final normalized = DateTime(date.year, date.month, date.day);
            for (int i = 0; i < 5; i++) {
              if (normalized.isAtSameMomentAs(_weekDays[i])) {
                entriesByDay.putIfAbsent(i, () => []);
                entriesByDay[i]!.add(data);
                break;
              }
            }
          }
        }

        final weekLabel =
            '${DateFormat('MMM d').format(_weekStart)} – ${DateFormat('MMM d').format(weekEnd)}';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Week header with navigation
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _shiftWeek(-1),
                      child: Icon(Icons.chevron_left,
                          size: 22, color: Colors.grey[600]),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isCurrentWeek
                            ? null
                            : () {
                                final n = DateTime.now();
                                setState(() {
                                  _weekStart = DateTime(n.year, n.month, n.day)
                                      .subtract(
                                          Duration(days: n.weekday - 1));
                                });
                              },
                        child: Text(
                          _isCurrentWeek ? 'This Week' : weekLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _shiftWeek(1),
                      child: Icon(Icons.chevron_right,
                          size: 22, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // Day columns
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Row(
                  children: List.generate(5, (i) {
                    final day = _weekDays[i];
                    final isToday = day.isAtSameMomentAs(today);
                    final entries = entriesByDay[i] ?? [];

                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          children: [
                            Text(
                              dayNames[i],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isToday
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isToday
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      isToday ? FontWeight.bold : FontWeight.w500,
                                  color: isToday ? Colors.white : Colors.grey[700],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 40,
                              alignment: Alignment.topCenter,
                              child: entries.isEmpty
                                  ? Text('—',
                                      style: TextStyle(
                                          color: Colors.grey[300], fontSize: 16))
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: entries.take(2).map((entry) {
                                        final projectId =
                                            entry['project_id'] as String? ?? '';
                                        final projectName =
                                            entry['project_name'] as String? ??
                                                '?';
                                        final color = _projectColor(projectId);
                                        return Container(
                                          width: double.infinity,
                                          margin:
                                              const EdgeInsets.only(bottom: 2),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 2, horizontal: 2),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            projectName.length > 6
                                                ? '${projectName.substring(0, 6)}…'
                                                : projectName,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: color,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.clip,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
