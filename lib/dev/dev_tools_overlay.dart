import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/client/client_project_timeline.dart';
import '../screens/client/design_preview_menu.dart';

/// Floating dev tools panel for testing.
/// Remove this file before production release.

// Global state so it survives rebuilds
String? devRoleOverride; // null = use Firestore role

// Test accounts — remove before production
const _devAccounts = [
  {'label': 'GC', 'email': 'collinjmaddox@gmail.com', 'pass': 'Proverbs163', 'icon': Icons.construction},
  {'label': 'Client', 'email': 'thatboycollin.07@gmail.com', 'pass': 'Proverbs163', 'icon': Icons.person},
];

class DevToolsOverlay extends StatefulWidget {
  final Widget child;
  final String firestoreRole;
  final String currentRole;
  final VoidCallback onToggleRole;

  const DevToolsOverlay({
    super.key,
    required this.child,
    required this.firestoreRole,
    required this.currentRole,
    required this.onToggleRole,
  });

  @override
  State<DevToolsOverlay> createState() => _DevToolsOverlayState();
}

class _DevToolsOverlayState extends State<DevToolsOverlay> {
  bool _expanded = false;
  bool _switching = false;

  /// Temporarily switch current user to worker/foreman view
  Future<void> _switchToTeamRole(BuildContext ctx, String teamRole) async {
    setState(() => _switching = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userRef.get();
      final userData = userDoc.data() ?? {};
      final teamId = userData['team_id'] as String?;

      if (teamId == null) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('No team found'), backgroundColor: Colors.red));
        }
        setState(() => _switching = false);
        return;
      }

      // Save original role so we can restore it
      final originalRole = userData['role'] as String?;
      if (originalRole != 'team_member') {
        await userRef.update({'_original_role': originalRole});
      }

      // Find a test member doc to link to (pick the first matching role)
      final membersSnap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('members')
          .where('role', isEqualTo: teamRole)
          .get();

      String memberId = 'test_member';
      String memberName = teamRole == 'foreman' ? 'Mike Johnson' : 'Carlos Rivera';
      if (membersSnap.docs.isNotEmpty) {
        memberId = membersSnap.docs.first.id;
        memberName = membersSnap.docs.first.data()['name'] as String? ?? memberName;
      }

      // Update user doc to team_member role
      await userRef.update({
        'role': 'team_member',
        'team_member_id': memberId,
        'team_member_profile': {
          'name': memberName,
          'team_role': teamRole,
        },
      });

      // Force reload by signing out and back in
      final email = user.email!;
      // Find the password from dev accounts
      final pass = _devAccounts.firstWhere(
        (a) => a['email'] == email,
        orElse: () => {'pass': 'Proverbs163'},
      )['pass'] as String;

      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _switching = false);
  }

  Future<void> _switchAccount(String email, String pass) async {
    setState(() => _switching = true);
    try {
      // Restore original role if we were in worker/foreman preview
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
        final userDoc = await userRef.get();
        final originalRole = userDoc.data()?['_original_role'] as String?;
        if (originalRole != null) {
          await userRef.update({
            'role': originalRole,
            '_original_role': FieldValue.delete(),
            'team_member_id': FieldValue.delete(),
            'team_member_profile': FieldValue.delete(),
          });
        }
      }
      devRoleOverride = null;
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _switching = false);
  }

  /// Reset the last approved milestone on project deta back to 'completed'
  Future<void> _resetLastMilestone(BuildContext ctx) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final projects = await FirebaseFirestore.instance
        .collection('projects')
        .where('contractor_uid', isEqualTo: uid)
        .where('project_name', isEqualTo: 'project deta')
        .get();

    if (projects.docs.isEmpty) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('project deta not found')));
      return;
    }

    final projectRef = projects.docs.first.reference;
    // Get all milestones and filter client-side to avoid composite index
    final allMilestones = await projectRef.collection('milestones').orderBy('order').get();
    // Find last approved or completed milestone to reset to awaiting_approval
    final resettable = allMilestones.docs.where((d) {
      final s = d.data()['status'];
      return s == 'approved' || s == 'completed';
    }).toList();
    final milestones = resettable.isNotEmpty ? [resettable.last] : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    if (milestones.isEmpty) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('No milestones to reset')));
      return;
    }

    final ms = milestones.first;
    final msName = ms.data()['name'] ?? 'Unknown';

    // Also delete the invoice for this milestone
    final invoices = await projectRef.collection('invoices')
        .where('milestone_id', isEqualTo: ms.id)
        .get();
    for (final inv in invoices.docs) {
      await inv.reference.delete();
    }

    await ms.reference.update({
      'status': 'awaiting_approval',
      'approved_at': FieldValue.delete(),
      'released_amount': FieldValue.delete(),
      'transaction_fee': FieldValue.delete(),
      'released_at': FieldValue.delete(),
    });

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Reset "$msName" to completed'), backgroundColor: Colors.purple));
    }
  }

  /// Create a realistic test project with milestones, change orders, updates
  Future<void> _createTestProject(BuildContext ctx) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _switching = true);

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userRef.get();
      final userData = userDoc.data() ?? {};
      final businessName = userData['contractor_profile']?['business_name'] ?? 'Test Contractor';
      final teamId = userData['team_id'] as String?;

      // Client user ref - use known test client UID directly to avoid Firestore rules issue
      // thatboycollin.07@gmail.com UID lookup
      DocumentReference? clientRef;
      try {
        final clientQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: 'thatboycollin.07@gmail.com')
            .get();
        clientRef = clientQuery.docs.isNotEmpty ? clientQuery.docs.first.reference : null;
      } catch (_) {
        // Rules may block this query - that's fine, client_user_ref will be set when client opens the project
        clientRef = null;
      }

      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 21));
      final endDate = now.add(const Duration(days: 30));

      // Create project
      final projectRef = await FirebaseFirestore.instance.collection('projects').add({
        'contractor_ref': userRef,
        'contractor_uid': user.uid,
        'contractor_email': user.email,
        'contractor_business_name': businessName,
        'team_id': teamId,
        'assigned_member_uids': <String>[],
        'assigned_sub_ids': <String>[],
        'project_name': 'Smith Kitchen Remodel',
        'client_name': 'Sarah Smith',
        'client_email': 'thatboycollin.07@gmail.com',
        'client_phone': '555-867-5309',
        'client_user_ref': clientRef,
        'start_date': Timestamp.fromDate(startDate),
        'estimated_end_date': Timestamp.fromDate(endDate),
        'actual_end_date': null,
        'status': 'active',
        'original_cost': 28500.0,
        'current_cost': 30200.0,
        'contract_document_url': null,
        'milestones_enabled': true,
        'payment_status': 'unpaid',
        'invitation_ready': false,
        'created_at': Timestamp.fromDate(startDate),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Milestones - mix of statuses
      final milestones = [
        {'name': 'Demo & Haul Away', 'description': 'Remove existing cabinets, countertops, flooring, and appliances. Haul away debris.', 'amount': 4500.0, 'order': 0, 'status': 'approved', 'approved_at': Timestamp.fromDate(now.subtract(const Duration(days: 14)))},
        {'name': 'Rough Plumbing & Electrical', 'description': 'Run new water lines, drain relocations, dedicated circuits for appliances, undercabinet wiring.', 'amount': 6500.0, 'order': 1, 'status': 'approved', 'approved_at': Timestamp.fromDate(now.subtract(const Duration(days: 7)))},
        {'name': 'Cabinets & Countertops', 'description': 'Install custom shaker cabinets, quartz countertops, undermount sink, and backsplash tile.', 'amount': 12000.0, 'order': 2, 'status': 'awaiting_approval'},
        {'name': 'Appliances & Final Touches', 'description': 'Install appliances, hardware, trim, paint touch-ups, and final walkthrough.', 'amount': 5500.0, 'order': 3, 'status': 'not_started'},
      ];

      for (final m in milestones) {
        final milestoneRef = await projectRef.collection('milestones').add({
          ...m,
          'created_at': FieldValue.serverTimestamp(),
        });

        // Add invoices for approved milestones
        if (m['status'] == 'approved') {
          final amount = m['amount'] as double;
          final fee = amount * 0.05;
          await projectRef.collection('invoices').add({
            'invoice_number': 'INV-${now.millisecondsSinceEpoch.toString().substring(5)}${m['order']}',
            'milestone_id': milestoneRef.id,
            'milestone_name': m['name'],
            'amount': amount,
            'transaction_fee': fee,
            'total_due': amount + fee,
            'status': m['order'] == 0 ? 'paid' : 'sent',
            'pdf_url': null,
            'created_at': m['approved_at'],
            'paid_at': m['order'] == 0 ? Timestamp.fromDate(now.subtract(const Duration(days: 12))) : null,
            'emailed_at': Timestamp.now(), // Prevent Cloud Function from sending test emails
          });
        }
      }

      // Change order
      await projectRef.collection('change_orders').add({
        'title': 'Upgrade to Waterfall Edge Countertop',
        'description': 'Client requested waterfall edge on island instead of standard bullnose. Additional quartz material and labor.',
        'amount': 1700.0,
        'status': 'approved',
        'created_at': Timestamp.fromDate(now.subtract(const Duration(days: 10))),
        'approved_at': Timestamp.fromDate(now.subtract(const Duration(days: 9))),
      });

      // Photo updates with placeholder images
      final updates = [
        {
          'caption': 'Demo Day 1 - All upper and lower cabinets removed. Found minor water damage behind sink area, will patch before new install.',
          'photo_url': 'https://picsum.photos/seed/demo1/800/600',
          'days_ago': 18,
        },
        {
          'caption': 'Rough plumbing complete! New water lines run for island sink. Dedicated gas line for range. Passed inspection.',
          'photo_url': 'https://picsum.photos/seed/plumbing/800/600',
          'days_ago': 14,
        },
        {
          'caption': 'Electrical rough-in done. New 20-amp circuits for dishwasher and microwave. Undercabinet LED wiring in place.',
          'photo_url': 'https://picsum.photos/seed/electrical/800/600',
          'days_ago': 10,
        },
        {
          'caption': 'Cabinets going in! Custom shaker cabinets being installed. Island base cabinet in place.',
          'photo_url': 'https://picsum.photos/seed/cabinets/800/600',
          'days_ago': 6,
        },
        {
          'caption': 'Countertops measured and templated. Quartz slabs selected - going with Calacatta Gold.',
          'photo_url': 'https://picsum.photos/seed/countertop/800/600',
          'days_ago': 3,
        },
        {
          'caption': 'Backsplash tile installed! White subway with dark grout. Really pulls the room together.',
          'photo_url': 'https://picsum.photos/seed/backsplash/800/600',
          'days_ago': 1,
        },
      ];

      for (final u in updates) {
        await projectRef.collection('updates').add({
          'caption': u['caption'],
          'photo_url': u['photo_url'],
          'created_at': Timestamp.fromDate(now.subtract(Duration(days: u['days_ago'] as int))),
          'contractor_uid': user.uid,
          'posted_by_ref': userRef,
          'posted_by_name': businessName,
        });
      }

      // Add team members, subs, and today's schedule
      if (teamId != null) {
        final teamRef = FirebaseFirestore.instance.collection('teams').doc(teamId);

        // Team members
        final members = [
          {'name': 'Mike Johnson', 'role': 'foreman', 'email': 'mike@example.com', 'phone': '555-111-2222'},
          {'name': 'Carlos Rivera', 'role': 'worker', 'email': 'carlos@example.com', 'phone': '555-333-4444'},
          {'name': 'James Wright', 'role': 'worker', 'email': 'james@example.com', 'phone': '555-555-6666'},
          {'name': 'Devon Lee', 'role': 'worker', 'email': 'devon@example.com', 'phone': '555-777-8888'},
        ];

        // Clean up old test team data first
        final oldMembers = await teamRef.collection('members').get();
        for (final doc in oldMembers.docs) {
          final uid = doc.data()['user_uid'] as String? ?? '';
          if (uid.startsWith('test_')) await doc.reference.delete();
        }
        final oldSubs = await teamRef.collection('subcontractors').get();
        for (final doc in oldSubs.docs) {
          if (['Ace Plumbing', 'Spark Electric', 'Premier Tile & Stone']
              .contains(doc.data()['company_name'])) {
            await doc.reference.delete();
          }
        }
        final oldSchedule = await teamRef.collection('schedule_entries').get();
        for (final doc in oldSchedule.docs) {
          final uid = doc.data()['user_uid'] as String? ?? '';
          if (uid.startsWith('test_')) await doc.reference.delete();
        }

        final memberUids = <String, String>{}; // name -> generated uid
        final allMemberUids = <String>[user.uid]; // include owner
        for (final m in members) {
          final fakeUid = 'test_${m['name']!.toLowerCase().replaceAll(' ', '_')}';
          memberUids[m['name']!] = fakeUid;
          allMemberUids.add(fakeUid);
          await teamRef.collection('members').doc(fakeUid).set({
            'name': m['name'],
            'role': m['role'],
            'email': m['email'],
            'phone': m['phone'],
            'user_uid': fakeUid,
            'status': 'active',
            'added_at': FieldValue.serverTimestamp(),
          });
        }

        // Update team doc with member_uids array
        await teamRef.update({
          'member_uids': allMemberUids,
        });

        // Assign members to the Smith Kitchen Remodel project
        final smithMembers = allMemberUids.where((uid) => uid != user.uid).toList();
        await projectRef.update({
          'assigned_member_uids': smithMembers,
        });

        // Subcontractors
        final subs = [
          {'company_name': 'Ace Plumbing', 'trade': 'plumbing', 'contact_name': 'Tony Russo', 'phone': '555-PLM-BING'},
          {'company_name': 'Spark Electric', 'trade': 'electrical', 'contact_name': 'Lisa Chen', 'phone': '555-ELE-CTRC'},
          {'company_name': 'Premier Tile & Stone', 'trade': 'tile', 'contact_name': 'Marco Diaz', 'phone': '555-TIL-WORK'},
        ];

        for (final s in subs) {
          await teamRef.collection('subcontractors').add({
            ...s,
            'status': 'active',
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        // Today's schedule entries
        final today = DateTime(now.year, now.month, now.day);
        final scheduleEntries = [
          {'user_name': 'Mike Johnson', 'user_uid': memberUids['Mike Johnson'], 'project_name': 'Smith Kitchen Remodel', 'project_id': projectRef.id},
          {'user_name': 'Carlos Rivera', 'user_uid': memberUids['Carlos Rivera'], 'project_name': 'Smith Kitchen Remodel', 'project_id': projectRef.id},
          {'user_name': 'James Wright', 'user_uid': memberUids['James Wright'], 'project_name': 'Smith Kitchen Remodel', 'project_id': projectRef.id},
          {'user_name': 'Devon Lee', 'user_uid': memberUids['Devon Lee'], 'project_name': 'project deta', 'project_id': 'existing'},
        ];

        // Find project deta ID for Devon's entry
        final detaQuery = await FirebaseFirestore.instance
            .collection('projects')
            .where('contractor_uid', isEqualTo: user.uid)
            .where('project_name', isEqualTo: 'project deta')
            .get();
        final detaId = detaQuery.docs.isNotEmpty ? detaQuery.docs.first.id : projectRef.id;

        // Assign Devon to project deta
        if (detaQuery.docs.isNotEmpty) {
          await detaQuery.docs.first.reference.update({
            'assigned_member_uids': FieldValue.arrayUnion([memberUids['Devon Lee']]),
          });
        }

        for (final entry in scheduleEntries) {
          final pid = entry['project_id'] == 'existing' ? detaId : entry['project_id'];
          final pname = entry['project_id'] == 'existing' ? 'project deta' : entry['project_name'];
          await teamRef.collection('schedule_entries').add({
            'user_uid': entry['user_uid'],
            'user_name': entry['user_name'],
            'project_id': pid,
            'project_name': pname,
            'date': Timestamp.fromDate(today),
            'created_by_uid': user.uid,
            'created_at': Timestamp.now(),
          });
        }
      }

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Test project created with team + schedule!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => _switching = false);
  }

  /// Delete all projects except the ones in keepNames
  Future<void> _cleanupProjects(BuildContext ctx) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    const keepNames = {'project deta'}; // projects to keep

    final snap = await FirebaseFirestore.instance
        .collection('projects')
        .where('contractor_uid', isEqualTo: uid)
        .get();

    final toDelete = snap.docs.where((d) {
      final name = (d.data()['project_name'] as String?) ?? '';
      return !keepNames.contains(name);
    }).toList();

    if (toDelete.isEmpty) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Nothing to delete'), backgroundColor: Colors.grey));
      }
      return;
    }

    // Confirm
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete test projects?'),
        content: Text('This will delete ${toDelete.length} projects:\n${toDelete.map((d) => "• ${d.data()['project_name']}").join('\n')}\n\nKeeping: ${keepNames.join(', ')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _switching = true);

    // Skip 'messages' — Firestore rules block client-side deletion (allow delete: if false)
    final subcollections = ['milestones', 'updates', 'change_orders', 'expenses', 'documents', 'time_entries', 'invoices'];
    int deleted = 0;

    for (final doc in toDelete) {
      final ref = doc.reference;
      for (final sub in subcollections) {
        try {
          final subDocs = await ref.collection(sub).get();
          for (final sd in subDocs.docs) {
            if (sub == 'milestones') {
              try {
                final crs = await sd.reference.collection('change_requests').get();
                for (final cr in crs.docs) { await cr.reference.delete(); }
              } catch (_) {}
            }
            await sd.reference.delete();
          }
        } catch (e) {
          debugPrint('Cleanup: skipping $sub on ${doc.id}: $e');
        }
      }
      try {
        await ref.delete();
        deleted++;
      } catch (e) {
        debugPrint('Cleanup: failed to delete project ${doc.id}: $e');
      }
    }

    // Also clean up test team members, subs, and schedule entries
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final teamId = userDoc.data()?['team_id'] as String?;
    if (teamId != null) {
      final teamRef = FirebaseFirestore.instance.collection('teams').doc(teamId);
      final members = await teamRef.collection('members').get();
      for (final doc in members.docs) {
        final memberUid = doc.data()['user_uid'] as String? ?? '';
        if (memberUid.startsWith('test_')) await doc.reference.delete();
      }
      final subs = await teamRef.collection('subcontractors').get();
      for (final doc in subs.docs) {
        if (['Ace Plumbing', 'Spark Electric', 'Premier Tile & Stone']
            .contains(doc.data()['company_name'])) {
          await doc.reference.delete();
        }
      }
      final schedule = await teamRef.collection('schedule_entries').get();
      for (final doc in schedule.docs) {
        final memberUid = doc.data()['user_uid'] as String? ?? '';
        if (memberUid.startsWith('test_')) await doc.reference.delete();
      }
      // Reset member_uids to just owner
      await teamRef.update({'member_uids': [uid]});
    }

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Deleted $deleted projects + test team data'), backgroundColor: Colors.green));
    }
    setState(() => _switching = false);
  }

  @override
  Widget build(BuildContext context) {
    final isClient = widget.currentRole == 'client';
    final color = isClient ? Colors.orange : Colors.blue;
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return Stack(
      children: [
        widget.child,
        // Loading overlay during account switch
        if (_switching)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text('Switching account...', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ),
        // Floating dev button
        Positioned(
          left: 8,
          bottom: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expanded panel
              if (_expanded) ...[
                Container(
                  width: 270,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(Icons.bug_report, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          const Text('Dev Tools',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _expanded = false),
                            child: Icon(Icons.close, color: Colors.white54, size: 18),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24),

                      // Account switcher
                      const Text('SWITCH ACCOUNT',
                          style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      Row(
                        children: _devAccounts.map((acct) {
                          final isCurrent = currentEmail == acct['email'];
                          // Always allow switching if we're in team_member preview mode
                          final inPreviewMode = widget.firestoreRole == 'team_member';
                          final isClickable = !isCurrent || inPreviewMode;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: GestureDetector(
                                onTap: isClickable ? () => _switchAccount(acct['email'] as String, acct['pass'] as String) : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isCurrent ? Colors.green.withOpacity(0.25) : Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: isCurrent ? Border.all(color: Colors.green, width: 1.5) : null,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(acct['icon'] as IconData, color: isCurrent ? Colors.green : Colors.white54, size: 20),
                                      const SizedBox(height: 4),
                                      Text(acct['label'] as String,
                                          style: TextStyle(
                                            color: isCurrent ? Colors.green : Colors.white70,
                                            fontSize: 11,
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                          )),
                                      if (isCurrent)
                                        const Text('active', style: TextStyle(color: Colors.green, fontSize: 9)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // Reset last milestone button
                      GestureDetector(
                        onTap: _switching ? null : () => _resetLastMilestone(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.replay, color: Colors.purple[300], size: 18),
                              const SizedBox(width: 8),
                              Text('Reset last milestone (project deta)',
                                  style: TextStyle(color: Colors.purple[300], fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Cleanup button
                      GestureDetector(
                        onTap: _switching ? null : () => _cleanupProjects(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.delete_sweep, color: Colors.red[300], size: 18),
                              const SizedBox(width: 8),
                              Text('Cleanup test projects',
                                  style: TextStyle(color: Colors.red[300], fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Create test project button
                      GestureDetector(
                        onTap: _switching ? null : () => _createTestProject(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.add_business, color: Colors.teal[300], size: 18),
                              const SizedBox(width: 8),
                              Text('Create test project',
                                  style: TextStyle(color: Colors.teal[300], fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Design preview button
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const DesignPreviewMenu(),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.palette, color: Colors.indigo[300], size: 18),
                              const SizedBox(width: 8),
                              Text('Preview designs',
                                  style: TextStyle(color: Colors.indigo[300], fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Role toggle (view swap without re-auth)
                      const Text('VIEW AS',
                          style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: widget.onToggleRole,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.swap_horiz, color: color, size: 18),
                              const SizedBox(width: 8),
                              Text('Switch to ${isClient ? "CONTRACTOR" : "CLIENT"} view',
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Worker/Foreman view buttons
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _switching ? null : () => _switchToTeamRole(context, 'worker'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.construction, color: Colors.green[300], size: 18),
                                    const SizedBox(height: 2),
                                    Text('Worker', style: TextStyle(color: Colors.green[300], fontWeight: FontWeight.bold, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GestureDetector(
                              onTap: _switching ? null : () => _switchToTeamRole(context, 'foreman'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.engineering, color: Colors.amber[300], size: 18),
                                    const SizedBox(height: 2),
                                    Text('Foreman', style: TextStyle(color: Colors.amber[300], fontWeight: FontWeight.bold, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // View any project as client
                      const Text('OPEN PROJECT AS CLIENT',
                          style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 180,
                        child: _ProjectPickerList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Collapsed pill button
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
                  ),
                  child: Text(
                    'DEV: ${widget.currentRole.toUpperCase()}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lists all projects for the current user's team so you can tap one
/// and jump straight into the client timeline view.
class _ProjectPickerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Not signed in', style: TextStyle(color: Colors.white54)));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('contractor_uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('No projects found', style: TextStyle(color: Colors.white54, fontSize: 12)),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final name = data['project_name'] ?? 'Untitled';
            final client = data['client_name'] ?? '';

            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('projects')
                  .doc(docs[i].id)
                  .collection('milestones')
                  .where('status', isEqualTo: 'awaiting_approval')
                  .get(),
              builder: (context, mileSnap) {
                final awaitingCount = mileSnap.data?.docs.length ?? 0;

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ClientProjectTimeline(
                        projectId: docs[i].id,
                        projectData: data,
                        isPreview: true,
                      ),
                    ));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: awaitingCount > 0 ? Colors.orange.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                              if (client.isNotEmpty)
                                Text(client,
                                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                                    overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        if (awaitingCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$awaitingCount',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
