import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/deep_link_service.dart';
import 'subcontractor_management_screen.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  String? _teamId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamId();
  }

  Future<void> _loadTeamId() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      var teamId = userData?['team_id'] as String?;

      // Auto-create team for existing contractors who signed up before teams existed
      if (teamId == null && userData?['role'] == 'contractor') {
        final profile =
            userData?['contractor_profile'] as Map<String, dynamic>?;
        final businessName = profile?['business_name'] ?? 'My Business';
        final ownerName =
            profile?['owner_name'] ?? user.displayName ?? '';

        // Create team
        final teamRef =
            await FirebaseFirestore.instance.collection('teams').add({
          'owner_uid': user.uid,
          'name': businessName,
          'member_uids': [user.uid],
          'created_at': FieldValue.serverTimestamp(),
        });

        // Add owner as first member
        await teamRef.collection('members').doc(user.uid).set({
          'name': ownerName,
          'email': user.email,
          'role': 'owner',
          'added_at': FieldValue.serverTimestamp(),
          'status': 'active',
          'user_uid': user.uid,
        });

        // Link team to user doc
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'team_id': teamRef.id});

        teamId = teamRef.id;
      }

      if (mounted) {
        setState(() {
          _teamId = teamId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading team: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddMemberDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String selectedRole = 'worker';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Team Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'e.g. Mike Johnson',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'mike@example.com',
                    border: OutlineInputBorder(),
                    helperText:
                        'They\'ll sign in with this email to join',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Role',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'foreman',
                      label: Text('Foreman'),
                      icon: Icon(Icons.engineering),
                    ),
                    ButtonSegment(
                      value: 'worker',
                      label: Text('Worker'),
                      icon: Icon(Icons.construction),
                    ),
                  ],
                  selected: {selectedRole},
                  onSelectionChanged: (Set<String> newSelection) {
                    setDialogState(() {
                      selectedRole = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedRole == 'foreman'
                              ? 'Foremen can post updates, manage milestones, and oversee workers.'
                              : 'Workers can post photo updates and progress notes.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                  return;
                }
                final email = emailController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Please enter a valid email')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Add Member'),
            ),
          ],
        ),
      ),
    );

    if (result == true && _teamId != null) {
      await _addMember(
        nameController.text.trim(),
        emailController.text.trim(),
        selectedRole,
      );
    }

    // Dispose controllers after a brief delay to avoid "dependents.isEmpty" error
    Future.delayed(const Duration(milliseconds: 100), () {
      nameController.dispose();
      emailController.dispose();
    });
  }

  Future<void> _addMember(String name, String email, String role) async {
    try {
      final teamRef =
          FirebaseFirestore.instance.collection('teams').doc(_teamId);

      // Create a unique ID for this member (not tied to a Firebase user yet)
      final memberRef = teamRef.collection('members').doc();

      // Normalize email to lowercase (Firebase Auth stores emails lowercase)
      final normalizedEmail = email.isNotEmpty ? email.toLowerCase().trim() : null;

      await memberRef.set({
        'name': name,
        'email': normalizedEmail,
        'role': role,
        'added_at': FieldValue.serverTimestamp(),
        'status': 'invited',
        'user_uid': null, // Will be linked when they accept invite
        'assigned_project_ids': <String>[], // GC picks projects next
      });

      if (mounted) {
        // Let GC assign this member to projects right away
        await _showAssignProjectsDialog(memberRef.id, name);
      }

      // Write email lookup doc so worker can find their invite on signup
      // (avoids complex collectionGroup query with tricky security rules)
      if (normalizedEmail != null) {
        // Re-read the member doc to get the latest assigned_project_ids
        final updatedMember = await memberRef.get();
        final assignedProjectIds = (updatedMember.data()?['assigned_project_ids'] as List<dynamic>?) ?? [];

        await FirebaseFirestore.instance
            .collection('pending_team_invites')
            .doc(normalizedEmail)
            .set({
          'team_id': _teamId,
          'member_id': memberRef.id,
          'name': name,
          'role': role,
          'assigned_project_ids': assignedProjectIds,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        _showInviteDialog(name, email);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAssignProjectsDialog(String memberId, String memberName) async {
    final user = FirebaseAuth.instance.currentUser!;

    // Load all active projects for this contractor
    final projectsSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .where('contractor_uid', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .get();

    if (projectsSnapshot.docs.isEmpty) return; // No projects to assign

    final selected = <String>{};

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Assign $memberName to Projects'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Which projects should they see?',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: projectsSnapshot.docs.length,
                    itemBuilder: (ctx, index) {
                      final doc = projectsSnapshot.docs[index];
                      final project = doc.data();
                      final isSelected = selected.contains(doc.id);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selected.add(doc.id);
                            } else {
                              selected.remove(doc.id);
                            }
                          });
                        },
                        title: Text(project['project_name'] ?? 'Untitled'),
                        subtitle: Text(
                          project['client_name'] ?? 'No client',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () async {
                if (selected.isNotEmpty) {
                  // Save project assignments to member doc
                  await FirebaseFirestore.instance
                      .collection('teams')
                      .doc(_teamId)
                      .collection('members')
                      .doc(memberId)
                      .update({'assigned_project_ids': selected.toList()});
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(selected.isEmpty ? 'Done' : 'Assign (${selected.length})'),
            ),
          ],
        ),
      ),
    );
  }

  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.consciousapps.projectpulse';

  void _showInviteDialog(String memberName, String email) {
    // Get GC's business name for the messages
    final user = FirebaseAuth.instance.currentUser;
    String businessName = 'your team';

    FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid)
        .get()
        .then((doc) {
      final profile =
          doc.data()?['contractor_profile'] as Map<String, dynamic>?;
      businessName = profile?['business_name'] ?? 'your team';
    }).whenComplete(() {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_add,
                          color: Colors.green[700], size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$memberName Added!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tell them to download the app and sign in with $email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Send via Text button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final message =
                              'Hey $memberName! You\'ve been added to $businessName on ProjectPulse. '
                              'Download the app and sign in with $email to get started.\n\n'
                              '$_playStoreUrl';
                          Share.share(message);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.textsms),
                        label: const Text('Send via Text'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Send via Email button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final subject = Uri.encodeComponent(
                              'Join $businessName on ProjectPulse');
                          final body = Uri.encodeComponent(
                              'Hey $memberName!\n\n'
                              'You\'ve been added to $businessName on ProjectPulse. '
                              'Download the app and sign in with $email to get started.\n\n'
                              '$_playStoreUrl\n\n'
                              'See you on the job!');
                          final mailtoUri = Uri.parse(
                              'mailto:$email?subject=$subject&body=$body');
                          await launchUrl(mailtoUri);
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.email_outlined),
                        label: Text('Email $memberName'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Done button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'I\'ll send it later',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _confirmRemoveMember(String memberId, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Team Member'),
        content: Text(
          'Are you sure you want to remove $memberName from your team? '
          'They will no longer be able to post updates to your projects.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeMember(memberId, memberName);
    }
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    try {
      final teamRef =
          FirebaseFirestore.instance.collection('teams').doc(_teamId);

      // Get the member data first to check for user_uid
      final memberDoc = await teamRef.collection('members').doc(memberId).get();
      final memberData = memberDoc.data();

      // Remove from members subcollection
      await teamRef.collection('members').doc(memberId).delete();

      // If they had a linked user, remove from member_uids array
      if (memberData?['user_uid'] != null) {
        await teamRef.update({
          'member_uids': FieldValue.arrayRemove([memberData!['user_uid']]),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$memberName removed from team'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeRole(
      String memberId, String memberName, String currentRole) async {
    final newRole = currentRole == 'foreman' ? 'worker' : 'foreman';

    try {
      final memberRef = FirebaseFirestore.instance
          .collection('teams')
          .doc(_teamId)
          .collection('members')
          .doc(memberId);

      // Read member doc to get user_uid and email
      final memberDoc = await memberRef.get();
      final memberData = memberDoc.data();

      // Update the member doc role
      await memberRef.update({'role': newRole});

      // If member has linked user account, update their user doc too
      final userUid = memberData?['user_uid'] as String?;
      if (userUid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userUid)
            .update({
          'team_member_profile': {
            'name': memberData?['name'] ?? memberName,
            'team_role': newRole,
          },
        });
      } else {
        // Member hasn't signed up yet — update pending invite doc
        final email = memberData?['email'] as String?;
        if (email != null && email.isNotEmpty) {
          final inviteRef = FirebaseFirestore.instance
              .collection('pending_team_invites')
              .doc(email);
          final inviteDoc = await inviteRef.get();
          if (inviteDoc.exists) {
            await inviteRef.update({'role': newRole});
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$memberName is now a ${newRole == 'foreman' ? 'Foreman' : 'Worker'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMemberProjects(String memberName, String memberUid, String memberDocId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      memberName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProjectsSection(memberUid),
                  const SizedBox(height: 20),
                  _buildScheduleSection(memberUid, memberDocId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsSection(String memberUid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.work, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text('Projects',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700],
                )),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .where('assigned_member_uids', arrayContains: memberUid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final projects = snapshot.data?.docs ?? [];
            if (projects.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text('Not assigned to any projects',
                      style: TextStyle(color: Colors.grey[500])),
                ),
              );
            }
            return Column(
              children: projects.map((doc) {
                final project = doc.data() as Map<String, dynamic>;
                final status = project['status'] ?? 'active';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: status == 'active'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      child: Icon(
                        Icons.work,
                        color: status == 'active' ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      project['project_name'] ?? 'Untitled',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      project['client_name'] ?? 'No client',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status == 'active'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status == 'active' ? 'Active' : 'Done',
                        style: TextStyle(
                          fontSize: 11,
                          color: status == 'active'
                              ? Colors.green[700]
                              : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildScheduleSection(String memberUid, String memberDocId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final twoWeeksOut = today.add(const Duration(days: 14));

    // Query by both Firebase UID and member doc ID to handle entries
    // created before member linked their account
    final uidList = <String>{memberUid, memberDocId}.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text('Upcoming Schedule',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700],
                )),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _teamId == null
              ? const Stream.empty()
              : FirebaseFirestore.instance
                  .collection('teams')
                  .doc(_teamId!)
                  .collection('schedule_entries')
                  .where('user_uid', whereIn: uidList)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text('Error loading schedule',
                      style: TextStyle(color: Colors.red[400])),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final allDocs = snapshot.data?.docs ?? [];

            // Filter to recent + upcoming dates client-side
            final entries = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['type'] == 'sub') return false; // exclude sub entries
              final date = (data['date'] as Timestamp?)?.toDate();
              if (date == null) return false;
              final normalized = DateTime(date.year, date.month, date.day);
              return !normalized.isBefore(weekAgo) &&
                  !normalized.isAfter(twoWeeksOut);
            }).toList();
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                      allDocs.isEmpty
                          ? 'No schedule entries found'
                          : 'No entries in the last 7 / next 14 days',
                      style: TextStyle(color: Colors.grey[500])),
                ),
              );
            }
            entries.sort((a, b) {
              final aDate = ((a.data() as Map)['date'] as Timestamp)
                  .millisecondsSinceEpoch;
              final bDate = ((b.data() as Map)['date'] as Timestamp)
                  .millisecondsSinceEpoch;
              return aDate.compareTo(bDate);
            });

            return Column(
              children: entries.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final date = (data['date'] as Timestamp).toDate();
                final projectName =
                    data['project_name'] as String? ?? 'Unknown';
                final isToday = date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;

                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: isToday
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                    title: Text(projectName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      DateFormat('EEEE, MMM d').format(date),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Team')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_teamId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Team')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No team found',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'There was an issue loading your team. Try signing out and back in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Team'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teams')
            .doc(_teamId)
            .collection('members')
            .orderBy('added_at')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final members = snapshot.data?.docs ?? [];

          if (members.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.groups, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'Just you for now',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your foremen and workers so they can post updates from the job site.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _showAddMemberDialog,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Your First Team Member'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: members.length + 1, // +1 for Subcontractors card
            itemBuilder: (context, index) {
              // Subcontractors navigation card at index 0
              if (index == 0) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('teams')
                      .doc(_teamId)
                      .collection('subcontractors')
                      .snapshots(),
                  builder: (context, subSnapshot) {
                    final subCount = subSnapshot.data?.docs.length ?? 0;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.15),
                          child: const Icon(Icons.engineering, color: Colors.orange),
                        ),
                        title: const Text('Subcontractors',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('$subCount sub${subCount == 1 ? '' : 's'} managed'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SubcontractorManagementScreen(),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              final memberIndex = index - 1;
              final member = members[memberIndex];
              final data = member.data() as Map<String, dynamic>;
              final name = data['name'] as String? ?? 'Unknown';
              final email = data['email'] as String?;
              final role = data['role'] as String? ?? 'worker';
              final status = data['status'] as String? ?? 'active';
              final isOwner = role == 'owner';
              final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
              final isCurrentUser = data['user_uid'] == currentUserUid ||
                  member.id == currentUserUid;

              final memberUid = data['user_uid'] as String?;
              final memberDocId = member.id;

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  onTap: memberUid != null ? () => _showMemberProjects(name, memberUid, memberDocId) : null,
                  leading: CircleAvatar(
                    backgroundColor: _roleColor(role).withValues(alpha: 0.15),
                    child: Icon(
                      _roleIcon(role),
                      color: _roleColor(role),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'You',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _roleColor(role).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _roleLabel(role),
                              style: TextStyle(
                                fontSize: 12,
                                color: _roleColor(role),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (status != 'active') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Invited',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (email != null && email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ],
                  ),
                  trailing: isOwner
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'change_role':
                                _changeRole(member.id, name, role);
                                break;
                              case 'remove':
                                _confirmRemoveMember(member.id, name);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'change_role',
                              child: ListTile(
                                leading: Icon(
                                  role == 'foreman'
                                      ? Icons.construction
                                      : Icons.engineering,
                                  size: 20,
                                ),
                                title: Text(
                                  role == 'foreman'
                                      ? 'Change to Worker'
                                      : 'Promote to Foreman',
                                ),
                                contentPadding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: ListTile(
                                leading: Icon(Icons.person_remove,
                                    size: 20, color: Colors.red),
                                title: Text('Remove',
                                    style: TextStyle(color: Colors.red)),
                                contentPadding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.amber[800]!;
      case 'foreman':
        return Colors.blue[700]!;
      case 'worker':
        return Colors.green[700]!;
      default:
        return Colors.grey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'owner':
        return Icons.star;
      case 'foreman':
        return Icons.engineering;
      case 'worker':
        return Icons.construction;
      default:
        return Icons.person;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'foreman':
        return 'Foreman';
      case 'worker':
        return 'Worker';
      default:
        return role;
    }
  }
}
