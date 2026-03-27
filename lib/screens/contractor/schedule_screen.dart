import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String? _teamId;
  bool _isLoading = true;
  late DateTime _weekStart;
  List<Map<String, dynamic>> _teamMembers = [];
  List<Map<String, dynamic>> _subcontractors = [];
  List<Map<String, dynamic>> _projects = [];

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
    _loadData();
  }

  Color _projectColor(String projectId) {
    return _projectColors[projectId.hashCode.abs() % _projectColors.length];
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final teamId = userDoc.data()?['team_id'] as String?;
      if (teamId == null || !mounted) return;

      _teamId = teamId;

      final membersSnap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('members')
          .where('status', whereIn: ['active', 'invited'])
          .get();

      final subsSnap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('subcontractors')
          .where('status', isEqualTo: 'active')
          .get();

      final projectsSnap = await FirebaseFirestore.instance
          .collection('projects')
          .where('contractor_uid', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();

      if (mounted) {
        setState(() {
          _teamMembers = membersSnap.docs
              .map((d) => {
                    'uid': d.data()['user_uid'] as String? ?? d.id,
                    'name': d.data()['name'] as String? ?? 'Unknown',
                    'role': d.data()['role'] as String? ?? 'worker',
                  })
              .toList();
          _subcontractors = subsSnap.docs
              .map((d) => {
                    'sub_id': d.id,
                    'company_name':
                        d.data()['company_name'] as String? ?? 'Unknown',
                    'trade': d.data()['trade'] as String? ?? 'other',
                  })
              .toList();
          _projects = projectsSnap.docs
              .map((d) => {
                    'id': d.id,
                    'name': d.data()['project_name'] as String? ?? 'Untitled',
                  })
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Crew scheduling ---

  Future<void> _assignProject(String memberUid, String memberName,
      String projectId, String projectName, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    await FirebaseFirestore.instance
        .collection('teams')
        .doc(_teamId!)
        .collection('schedule_entries')
        .add({
      'user_uid': memberUid,
      'user_name': memberName,
      'project_id': projectId,
      'project_name': projectName,
      'date': Timestamp.fromDate(normalizedDate),
      'created_by_uid': FirebaseAuth.instance.currentUser!.uid,
      'created_at': Timestamp.now(),
    });

    final dateLabel = '${normalizedDate.month}/${normalizedDate.day}';

    // Show local confirmation snackbar (context-aware message)
    final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
    final isSchedulingSelf = (memberUid == currentUserUid);

    // Only send push notification if scheduling someone else (not yourself)
    if (!isSchedulingSelf) {
      NotificationService.sendScheduleNotification(
        userUid: memberUid,
        projectName: projectName,
        dateLabel: dateLabel,
      );
    }
    final message = isSchedulingSelf
        ? 'You\'re scheduled for $projectName on $dateLabel'
        : '$memberName scheduled for $projectName on $dateLabel';

    debugPrint('Schedule: memberUid=$memberUid, currentUid=$currentUserUid, isSelf=$isSchedulingSelf');


    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _clearAssignments(
      String memberUid, DateTime date, List<QueryDocumentSnapshot> allEntries) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // Also query Firestore directly to catch any entries the snapshot missed
    final directQuery = await FirebaseFirestore.instance
        .collection('teams')
        .doc(_teamId!)
        .collection('schedule_entries')
        .where('user_uid', isEqualTo: memberUid)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedDate))
        .where('date',
            isLessThan: Timestamp.fromDate(
                normalizedDate.add(const Duration(days: 1))))
        .get();

    for (final doc in directQuery.docs) {
      await doc.reference.delete();
    }

    if (mounted) Navigator.pop(context);
  }

  void _showAssignSheet(String memberUid, String memberName, DateTime date,
      List<QueryDocumentSnapshot> allEntries) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final existingEntries = allEntries.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final entryDate = (data['date'] as Timestamp).toDate();
      final entryNormalized =
          DateTime(entryDate.year, entryDate.month, entryDate.day);
      return data['user_uid'] == memberUid &&
          entryNormalized == normalizedDate;
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(memberName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(DateFormat('EEEE, MMM d').format(date),
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_projects.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('No active projects',
                              style: TextStyle(color: Colors.grey[500])),
                        ),
                      )
                    else
                      ..._projects.map((project) {
                        final color = _projectColor(project['id'] as String);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.15),
                            child: Icon(Icons.work, color: color, size: 20),
                          ),
                          title: Text(project['name'] as String),
                          onTap: () => _assignProject(
                            memberUid,
                            memberName,
                            project['id'] as String,
                            project['name'] as String,
                            date,
                          ),
                        );
                      }),
                    if (existingEntries.isNotEmpty) ...[
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          child: const Icon(Icons.clear, color: Colors.red, size: 20),
                        ),
                        title: const Text('Clear assignments',
                            style: TextStyle(color: Colors.red)),
                        onTap: () =>
                            _clearAssignments(memberUid, date, allEntries),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // --- Subcontractor scheduling ---

  Future<void> _assignSubProject(String subId, String subName,
      String projectId, String projectName, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    await FirebaseFirestore.instance
        .collection('teams')
        .doc(_teamId!)
        .collection('schedule_entries')
        .add({
      'type': 'sub',
      'sub_id': subId,
      'sub_name': subName,
      'user_uid': null,
      'user_name': null,
      'project_id': projectId,
      'project_name': projectName,
      'date': Timestamp.fromDate(normalizedDate),
      'created_by_uid': FirebaseAuth.instance.currentUser!.uid,
      'created_at': Timestamp.now(),
    });

    // Show local confirmation snackbar
    final dateLabel = DateFormat('EEEE, MMM d').format(date);
    final message = '$subName scheduled for $projectName on $dateLabel';

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _clearSubAssignments(
      String subId, DateTime date, List<QueryDocumentSnapshot> allEntries) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // Query Firestore directly for reliable deletion
    final directQuery = await FirebaseFirestore.instance
        .collection('teams')
        .doc(_teamId!)
        .collection('schedule_entries')
        .where('type', isEqualTo: 'sub')
        .where('sub_id', isEqualTo: subId)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedDate))
        .where('date',
            isLessThan: Timestamp.fromDate(
                normalizedDate.add(const Duration(days: 1))))
        .get();

    for (final doc in directQuery.docs) {
      await doc.reference.delete();
    }

    if (mounted) Navigator.pop(context);
  }

  void _showSubAssignSheet(String subId, String subName, DateTime date,
      List<QueryDocumentSnapshot> allEntries) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final existingEntries = allEntries.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final entryDate = (data['date'] as Timestamp).toDate();
      final entryNormalized =
          DateTime(entryDate.year, entryDate.month, entryDate.day);
      return data['type'] == 'sub' &&
          data['sub_id'] == subId &&
          entryNormalized == normalizedDate;
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(DateFormat('EEEE, MMM d').format(date),
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_projects.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('No active projects',
                              style: TextStyle(color: Colors.grey[500])),
                        ),
                      )
                    else
                      ..._projects.map((project) {
                        final color = _projectColor(project['id'] as String);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.15),
                            child: Icon(Icons.work, color: color, size: 20),
                          ),
                          title: Text(project['name'] as String),
                          onTap: () => _assignSubProject(
                            subId,
                            subName,
                            project['id'] as String,
                            project['name'] as String,
                            date,
                          ),
                        );
                      }),
                    if (existingEntries.isNotEmpty) ...[
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          child: const Icon(Icons.clear, color: Colors.red, size: 20),
                        ),
                        title: const Text('Clear assignments',
                            style: TextStyle(color: Colors.red)),
                        onTap: () => _clearSubAssignments(subId, date, allEntries),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // --- Grid row builders ---

  Widget _buildSectionHeader(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.grey[100],
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> member,
      List<QueryDocumentSnapshot> allEntries) {
    final memberUid = member['uid'] as String;
    final memberName = member['name'] as String;
    final memberRole = member['role'] as String;

    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memberName,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  memberRole == 'owner'
                      ? 'Owner'
                      : memberRole == 'foreman'
                          ? 'Foreman'
                          : 'Worker',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
        ..._weekDays.map((day) {
          final dayEntries = allEntries.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final entryDate = (data['date'] as Timestamp).toDate();
            return data['user_uid'] == memberUid &&
                data['type'] != 'sub' &&
                _isSameDay(entryDate, day);
          }).toList();

          return Expanded(
            child: ClipRect(
              child: InkWell(
                onTap: () => _showAssignSheet(
                    memberUid, memberName, day, allEntries),
                child: _buildDayCell(dayEntries),
              ),
            ),
          );
        }),
      ],
    );
  }

  static const _tradeLabels = {
    'plumbing': 'Plumbing',
    'electrical': 'Electrical',
    'hvac': 'HVAC',
    'roofing': 'Roofing',
    'painting': 'Painting',
    'concrete': 'Concrete',
    'drywall': 'Drywall',
    'framing': 'Framing',
    'other': 'Other',
  };

  Widget _buildSubRow(Map<String, dynamic> sub,
      List<QueryDocumentSnapshot> allEntries) {
    final subId = sub['sub_id'] as String;
    final companyName = sub['company_name'] as String;
    final trade = sub['trade'] as String;

    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _tradeLabels[trade] ?? trade,
                  style: TextStyle(fontSize: 10, color: Colors.orange[700]),
                ),
              ],
            ),
          ),
        ),
        ..._weekDays.map((day) {
          final dayEntries = allEntries.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final entryDate = (data['date'] as Timestamp).toDate();
            return data['type'] == 'sub' &&
                data['sub_id'] == subId &&
                _isSameDay(entryDate, day);
          }).toList();

          return Expanded(
            child: ClipRect(
              child: InkWell(
                onTap: () => _showSubAssignSheet(
                    subId, companyName, day, allEntries),
                child: _buildDayCell(dayEntries),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDayCell(List<QueryDocumentSnapshot> dayEntries) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: dayEntries.isEmpty
          ? Center(
              child: Icon(Icons.add, size: 16, color: Colors.grey[300]))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: dayEntries.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final projectName =
                    data['project_name'] as String? ?? '?';
                final projectId =
                    data['project_id'] as String? ?? '';
                final color = _projectColor(projectId);

                // Create abbreviation: first letter of each word, max 3 letters
                final words = projectName.split(' ');
                String abbreviation;
                if (words.length >= 2) {
                  // Multi-word: take first letter of each word (max 3)
                  abbreviation = words
                      .take(3)
                      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
                      .join('');
                } else if (projectName.length <= 6) {
                  // Short name: show full name
                  abbreviation = projectName;
                } else {
                  // Long single word: first 4-5 chars
                  abbreviation = projectName.substring(0, projectName.length >= 5 ? 5 : 4).toUpperCase();
                }

                return Tooltip(
                  message: projectName,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      abbreviation,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Schedule')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_teamMembers.isEmpty && _subcontractors.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Schedule')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_month, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No team members yet',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 12),
                Text(
                    'Add crew or subcontractors to your team first, then schedule them here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey[500], height: 1.5)),
              ],
            ),
          ),
        ),
      );
    }

    final weekEnd = _weekStart.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Week navigation
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() =>
                      _weekStart =
                          _weekStart.subtract(const Duration(days: 7))),
                ),
                GestureDetector(
                  onTap: () {
                    final now = DateTime.now();
                    setState(() {
                      _weekStart = DateTime(now.year, now.month, now.day)
                          .subtract(Duration(days: now.weekday - 1));
                    });
                  },
                  child: Text(
                    'Week of ${DateFormat('MMM d').format(_weekStart)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() =>
                      _weekStart =
                          _weekStart.add(const Duration(days: 7))),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Day headers
          Container(
            color: Colors.grey[50],
            child: Row(
              children: [
                const SizedBox(width: 90),
                ..._weekDays.map((day) {
                  final isToday = _isSameDay(day, DateTime.now());
                  return Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('E').format(day),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isToday
                                      ? Colors.white
                                      : Colors.grey[800],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),

          // Grid with crew + subs
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('teams')
                  .doc(_teamId!)
                  .collection('schedule_entries')
                  .where('date',
                      isGreaterThanOrEqualTo:
                          Timestamp.fromDate(_weekStart))
                  .where('date',
                      isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
                  .snapshots(),
              builder: (context, snapshot) {
                final allEntries = snapshot.data?.docs ?? [];
                final hasCrew = _teamMembers.isNotEmpty;
                final hasSubs = _subcontractors.isNotEmpty;

                // Separate owner from crew
                final owner = _teamMembers.where((m) => m['role'] == 'owner').toList();
                final crew = _teamMembers.where((m) => m['role'] != 'owner').toList();

                final items = <Widget>[];

                // Owner row at the very top (no section header needed)
                for (final o in owner) {
                  items.add(_buildMemberRow(o, allEntries));
                  items.add(const Divider(height: 1));
                }

                if (crew.isNotEmpty) {
                  items.add(_buildSectionHeader(
                      Icons.construction, 'CREW'));
                  for (final member in crew) {
                    items.add(_buildMemberRow(member, allEntries));
                    items.add(const Divider(height: 1));
                  }
                }

                if (hasSubs) {
                  items.add(_buildSectionHeader(
                      Icons.engineering, 'SUBCONTRACTORS'));
                  for (final sub in _subcontractors) {
                    items.add(_buildSubRow(sub, allEntries));
                    items.add(const Divider(height: 1));
                  }
                }

                return ListView(children: items);
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
