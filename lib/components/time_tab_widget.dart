import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'add_time_entry_bottom_sheet.dart';

class TimeTabWidget extends StatefulWidget {
  final String projectId;
  final bool canLogTime;
  final String? currentUserUid;
  final String? currentUserName;
  final String? currentUserRole;
  final String? teamId;

  const TimeTabWidget({
    super.key,
    required this.projectId,
    required this.canLogTime,
    this.currentUserUid,
    this.currentUserName,
    this.currentUserRole,
    this.teamId,
  });

  @override
  State<TimeTabWidget> createState() => _TimeTabWidgetState();
}

class _TimeTabWidgetState extends State<TimeTabWidget> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _openLogTime(BuildContext context) async {
    if (widget.currentUserUid == null ||
        widget.currentUserName == null ||
        widget.currentUserRole == null) return;

    List<Map<String, dynamic>>? assignableMembers;

    // GC and foreman can log time for others
    if (widget.currentUserRole == 'contractor' ||
        widget.currentUserRole == 'foreman') {
      try {
        final projectDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .get();
        final assignedUids =
            (projectDoc.data()?['assigned_member_uids'] as List?)
                    ?.cast<String>() ??
                [];
        final teamId = widget.teamId ??
            projectDoc.data()?['team_id'] as String?;

        if (teamId != null && assignedUids.isNotEmpty) {
          final membersSnap = await FirebaseFirestore.instance
              .collection('teams')
              .doc(teamId)
              .collection('members')
              .where('status', isEqualTo: 'active')
              .get();

          assignableMembers = membersSnap.docs
              .where((d) {
                final uid = d.data()['user_uid'] as String? ?? d.id;
                return assignedUids.contains(uid) &&
                    uid != widget.currentUserUid;
              })
              .map((d) => {
                    'uid': d.data()['user_uid'] as String? ?? d.id,
                    'name': d.data()['name'] as String? ?? 'Unknown',
                  })
              .toList();
        }
      } catch (_) {
        // Member list stays empty — time entry still works with manual input
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AddTimeEntryBottomSheet(
          projectId: widget.projectId,
          enteredByUid: widget.currentUserUid!,
          enteredByName: widget.currentUserName!,
          enteredByRole: widget.currentUserRole!,
          assignableMembers: assignableMembers,
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time entry saved!')),
        );
      }
    });
  }

  Future<void> _exportCsv(List<QueryDocumentSnapshot> entries) async {
    final rows = <List<String>>[
      ['Date', 'Employee', 'Hours', 'Description'],
    ];

    for (final doc in entries) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['date'] as Timestamp).toDate();
      rows.add([
        DateFormat('MM/dd/yyyy').format(date),
        data['logged_by_name'] as String? ?? '',
        (data['hours'] as num?)?.toStringAsFixed(1) ?? '0',
        data['description'] as String? ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final weekLabel = DateFormat('MMM_d').format(_weekStart);
    final file = File('${dir.path}/time_$weekLabel.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject:
          'Time Report - Week of ${DateFormat('MMM d').format(_weekStart)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('time_entries')
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
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.red[600])),
                ],
              ),
            ),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        // Sort by date descending
        allDocs.sort((a, b) {
          final aTime = ((a.data() as Map<String, dynamic>)['date']
                      as Timestamp?)
                  ?.millisecondsSinceEpoch ??
              0;
          final bTime = ((b.data() as Map<String, dynamic>)['date']
                      as Timestamp?)
                  ?.millisecondsSinceEpoch ??
              0;
          return bTime.compareTo(aTime);
        });

        // Filter to selected week
        final weekEntries = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final date = (data['date'] as Timestamp?)?.toDate();
          if (date == null) return false;
          final normalized = DateTime(date.year, date.month, date.day);
          return !normalized.isBefore(_weekStart) &&
              !normalized.isAfter(_weekEnd);
        }).toList();

        if (allDocs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No time logged yet',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700])),
                  const SizedBox(height: 12),
                  Text(
                    widget.canLogTime
                        ? 'Track hours worked on this project'
                        : 'Time entries will appear here once added',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey[500], height: 1.5),
                  ),
                  if (widget.canLogTime) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _openLogTime(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Log Time'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        // Calculate totals for the week
        double totalHours = 0;
        final memberHours = <String, double>{};
        for (final doc in weekEntries) {
          final data = doc.data() as Map<String, dynamic>;
          final hours = (data['hours'] as num?)?.toDouble() ?? 0;
          final name = data['logged_by_name'] as String? ?? 'Unknown';
          totalHours += hours;
          memberHours[name] = (memberHours[name] ?? 0) + hours;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Week navigation
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _weekStart =
                            _weekStart.subtract(const Duration(days: 7));
                      });
                    },
                  ),
                  Text(
                    'Week of ${DateFormat('MMM d').format(_weekStart)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _weekStart = _weekStart.add(const Duration(days: 7));
                      });
                    },
                  ),
                ],
              ),
            ),

            // Log Time button
            if (widget.canLogTime)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openLogTime(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Log Time',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

            // Summary card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('Hours This Week',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text(
                          '${weekEntries.length} entr${weekEntries.length == 1 ? 'y' : 'ies'}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${totalHours.toStringAsFixed(1)} hrs',
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    if (memberHours.length > 1) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      ...memberHours.entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.person, size: 16,
                                    color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(entry.key,
                                    style: const TextStyle(fontSize: 13)),
                                const Spacer(),
                                Text('${entry.value.toStringAsFixed(1)} hrs',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Export CSV button (GC only)
            if (widget.currentUserRole == 'contractor' &&
                weekEntries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: () => _exportCsv(weekEntries),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export CSV'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Entry list
            ...weekEntries.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final hours = (data['hours'] as num?)?.toDouble() ?? 0;
              final description = data['description'] as String? ?? '';
              final loggedByName =
                  data['logged_by_name'] as String? ?? 'Unknown';
              final date = (data['date'] as Timestamp?)?.toDate();
              final createdAt = data['created_at'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clock icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.schedule,
                            color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    date != null
                                        ? DateFormat('EEE, MMM d')
                                            .format(date)
                                        : 'Unknown date',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15),
                                  ),
                                ),
                                Text(
                                  '${hours.toStringAsFixed(1)} hrs',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(description,
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[600]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(loggedByName,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w600)),
                                ),
                                const Spacer(),
                                if (createdAt != null)
                                  Text(
                                    _formatTimeAgo(createdAt.toDate()),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500]),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Show message if no entries this week but there are entries overall
            if (weekEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('No entries this week',
                      style: TextStyle(
                          fontSize: 15, color: Colors.grey[500])),
                ),
              ),
          ],
        );
      },
    );
  }
}
