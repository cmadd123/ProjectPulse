import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/notification_service.dart';

class ProjectTeamScreen extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> projectData;

  const ProjectTeamScreen({
    super.key,
    required this.projectId,
    required this.projectData,
  });

  @override
  State<ProjectTeamScreen> createState() => _ProjectTeamScreenState();
}

class _ProjectTeamScreenState extends State<ProjectTeamScreen> {
  String? _teamId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamId();
  }

  Future<void> _loadTeamId() async {
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (mounted) {
      setState(() {
        _teamId = userDoc.data()?['team_id'] as String?;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMember(String uid, bool add) async {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .update({
      'assigned_member_uids': add
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    });

    if (add) {
      final projectName = widget.projectData['project_name'] as String? ?? 'Project';
      NotificationService.sendCrewAssignmentNotification(
        userUid: uid,
        projectId: widget.projectId,
        projectName: projectName,
      );
    }
  }

  Future<void> _toggleSub(String subId, bool add) async {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .update({
      'assigned_sub_ids': add
          ? FieldValue.arrayUnion([subId])
          : FieldValue.arrayRemove([subId]),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Team')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_teamId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Team')),
        body: const Center(
            child: Text('No team found. Set up your team first.')),
      );
    }

    final projectName = widget.projectData['project_name'] ?? 'Project';

    return Scaffold(
      appBar: AppBar(
        title: Text('Team — $projectName'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .snapshots(),
        builder: (context, projectSnap) {
          if (!projectSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final projectData =
              projectSnap.data!.data() as Map<String, dynamic>? ?? {};
          final assignedUids =
              List<String>.from(projectData['assigned_member_uids'] ?? []);
          final assignedSubIds =
              List<String>.from(projectData['assigned_sub_ids'] ?? []);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCrewSection(assignedUids),
              const SizedBox(height: 24),
              _buildSubsSection(assignedSubIds),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCrewSection(List<String> assignedUids) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.groups, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 8),
            const Text('Crew',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${assignedUids.length} assigned',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('teams')
              .doc(_teamId)
              .collection('members')
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, membersSnap) {
            if (!membersSnap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final allMembers = membersSnap.data!.docs
                .where((d) => (d.data() as Map)['role'] != 'owner')
                .where((d) => (d.data() as Map)['user_uid'] != null)
                .toList();

            final assigned = allMembers.where((d) {
              final uid = (d.data() as Map)['user_uid'] as String;
              return assignedUids.contains(uid);
            }).toList();

            final unassigned = allMembers.where((d) {
              final uid = (d.data() as Map)['user_uid'] as String;
              return !assignedUids.contains(uid);
            }).toList();

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  if (assigned.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('No crew assigned yet',
                          style: TextStyle(color: Colors.grey[500])),
                    ),
                  ...assigned.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unknown';
                    final role = data['role'] ?? 'worker';
                    final email = data['email'] ?? '';
                    final uid = data['user_uid'] as String;
                    final isForeman = role == 'foreman';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isForeman
                            ? Colors.blue.withOpacity(0.15)
                            : Colors.green.withOpacity(0.15),
                        child: Icon(
                          isForeman ? Icons.engineering : Icons.construction,
                          color: isForeman ? Colors.blue : Colors.green,
                          size: 20,
                        ),
                      ),
                      title: Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isForeman
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isForeman ? 'Foreman' : 'Worker',
                              style: TextStyle(
                                fontSize: 11,
                                color: isForeman ? Colors.blue : Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(email,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500]),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            color: Colors.red[400], size: 20),
                        onPressed: () => _toggleMember(uid, false),
                      ),
                    );
                  }),
                  if (unassigned.isNotEmpty) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Crew',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: unassigned.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name = data['name'] ?? 'Unknown';
                              final role = data['role'] ?? 'worker';
                              final uid = data['user_uid'] as String;
                              final isForeman = role == 'foreman';

                              return ActionChip(
                                avatar: Icon(
                                  Icons.add_circle_outline,
                                  size: 16,
                                  color: isForeman
                                      ? Colors.blue
                                      : Colors.green,
                                ),
                                label: Text(name,
                                    style: const TextStyle(fontSize: 13)),
                                onPressed: () => _toggleMember(uid, true),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubsSection(List<String> assignedSubIds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.engineering, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 8),
            const Text('Subcontractors',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${assignedSubIds.length} assigned',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('teams')
              .doc(_teamId)
              .collection('subcontractors')
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, subsSnap) {
            if (!subsSnap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final allSubs = subsSnap.data!.docs;
            final assigned =
                allSubs.where((d) => assignedSubIds.contains(d.id)).toList();
            final unassigned =
                allSubs.where((d) => !assignedSubIds.contains(d.id)).toList();

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  if (assigned.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('No subcontractors assigned yet',
                          style: TextStyle(color: Colors.grey[500])),
                    ),
                  ...assigned.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final companyName = data['company_name'] ?? 'Unknown';
                    final trade = data['trade'] ?? 'other';
                    final contactName = data['contact_name'] ?? '';
                    final tradeName =
                        trade[0].toUpperCase() + trade.substring(1);

                    // COI status
                    final coiExpiry = data['coi_expiry'] as Timestamp?;
                    Color coiColor = Colors.grey;
                    String coiLabel = 'No COI';
                    if (coiExpiry != null) {
                      final expDate = coiExpiry.toDate();
                      final daysLeft =
                          expDate.difference(DateTime.now()).inDays;
                      if (daysLeft < 0) {
                        coiColor = Colors.red;
                        coiLabel = 'Expired';
                      } else if (daysLeft <= 30) {
                        coiColor = Colors.orange;
                        coiLabel = 'Expiring';
                      } else {
                        coiColor = Colors.green;
                        coiLabel = 'Valid';
                      }
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.withOpacity(0.15),
                        child: const Icon(Icons.engineering,
                            color: Colors.orange, size: 20),
                      ),
                      title: Text(companyName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(tradeName,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: coiColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(coiLabel,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600])),
                          if (contactName.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(contactName,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500]),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            color: Colors.red[400], size: 20),
                        onPressed: () => _toggleSub(doc.id, false),
                      ),
                    );
                  }),
                  if (unassigned.isNotEmpty) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Subcontractor',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: unassigned.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name = data['company_name'] ?? 'Unknown';

                              return ActionChip(
                                avatar: const Icon(Icons.add_circle_outline,
                                    size: 16, color: Colors.orange),
                                label: Text(name,
                                    style: const TextStyle(fontSize: 13)),
                                onPressed: () => _toggleSub(doc.id, true),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
