import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/demo_project_data.dart';

/// Writes a realistic demo project (Johnson Residence kitchen remodel) into
/// Firestore for the currently signed-in contractor. Used for:
///   1. QA — verifying what a tester sees the first time they open the app
///   2. Empty-state onboarding (future) — new GCs with zero projects can tap
///      "Try a demo project" and poke around a pre-filled example
///
/// Marks everything with `is_demo: true` so downstream code can skip demos
/// for notifications, invoicing, etc. (Not wired yet; TODO per ROADMAP 1b.)
class DemoProjectSeeder {
  DemoProjectSeeder._();

  /// Creates the demo project for the signed-in contractor.
  ///
  /// If a prior demo project exists on this account it's cleaned up first —
  /// so re-seeding produces a consistent state. Returns the new project ID.
  static Future<String> seed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Sign in as a contractor first.');

    final db = FirebaseFirestore.instance;
    await cleanup(); // idempotent — safe if nothing exists

    // Need the contractor's team_id (auto-created at signup).
    final userSnap = await db.collection('users').doc(user.uid).get();
    final teamId = userSnap.data()?['team_id'] as String?;
    if (teamId == null) {
      throw Exception(
        'No team_id on user doc. Sign out + back in to trigger team creation.',
      );
    }

    // Pull business name for display consistency.
    final profile = userSnap.data()?['contractor_profile'] as Map<String, dynamic>?;
    final businessName = profile?['business_name'] as String?
        ?? DemoProjectData.project['contractor_business_name']
        ?? 'Smith Construction';

    final now = DateTime.now();
    final projectRef = db.collection('projects').doc();

    // Stretch the "started 21 days ago" timeline around the current date
    // so the demo always looks recent regardless of when it's seeded.
    final projectData = {
      ...DemoProjectData.project,
      'contractor_ref': db.collection('users').doc(user.uid),
      'contractor_uid': user.uid,
      'contractor_business_name': businessName,
      'team_id': teamId,
      'assigned_member_uids': <String>[user.uid],
      'assigned_sub_ids': <String>[],
      'address': '1234 Maple Ave, Anytown, USA',
      'client_user_ref': null,
      'actual_end_date': null,
      'budget_amount': 45000.0,
      'contract_document_url': null,
      'is_demo': true,
      'demo_seeded_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    await projectRef.set(projectData);

    // Milestones with realistic timestamps based on current status.
    // Track the cabinets milestone so we can link the change order to it.
    DocumentReference? cabinetsMilestoneRef;
    String? cabinetsMilestoneName;

    for (final m in DemoProjectData.milestones) {
      final order = m['order'] as int;
      final status = m['status'] as String;
      final daysAgo = (3 - order) * 5; // spread the timeline out
      final startedAt = now.subtract(Duration(days: daysAgo + 4));
      final completedAt = now.subtract(Duration(days: daysAgo));

      final milestone = <String, dynamic>{
        'name': m['name'],
        'description': m['description'],
        'amount': m['amount'],
        'percentage': 0.0,
        'order': order,
        'status': status,
        'started_at': status == 'pending' ? null : Timestamp.fromDate(startedAt),
        'marked_complete_at': (status == 'awaiting_approval' || status == 'approved')
            ? Timestamp.fromDate(completedAt) : null,
        'approved_at': status == 'approved' ? Timestamp.fromDate(completedAt) : null,
        'released_at': null,
        'released_amount': null,
        'transaction_fee': null,
        'dispute_reason': null,
        'changes_requested': false,
        'last_change_request_at': null,
        'created_at': FieldValue.serverTimestamp(),
      };

      final milestoneRef = projectRef.collection('milestones').doc();
      await milestoneRef.set(milestone);

      final name = m['name'] as String;
      if (name.toLowerCase().contains('cabinet')) {
        cabinetsMilestoneRef = milestoneRef;
        cabinetsMilestoneName = name;
      }

      // Photo updates tied to the milestone.
      final photoUrls = List<String>.from(m['photo_urls'] as List);
      for (var i = 0; i < photoUrls.length; i++) {
        final captionPool = _captionsForMilestone(name);
        await projectRef.collection('updates').add({
          'photo_url': photoUrls[i],
          'thumbnail_url': photoUrls[i],
          'caption': captionPool[i % captionPool.length],
          'posted_by_ref': db.collection('users').doc(user.uid),
          'posted_by_name': profile?['full_name'] ?? 'Demo Contractor',
          'posted_by_role': 'contractor',
          'created_at': Timestamp.fromDate(
            startedAt.add(Duration(hours: i * 6)),
          ),
          'milestone_ref': milestoneRef,
          'is_demo': true,
        });
      }
    }

    // Change order tied to the Cabinets milestone — matches the app's
    // create_change_order_screen schema (description, cost_change,
    // requested_at, milestone_ref, milestone_name, responded_*).
    // Description is in the contractor's voice — they wrote it, client approves.
    await projectRef.collection('change_orders').add({
      'description': 'Upgrade countertops from laminate to 3cm quartz per client request. '
          'Adds 3 days to schedule.',
      'cost_change': 2500.0,
      'status': 'pending',
      'milestone_ref': cabinetsMilestoneRef,
      'milestone_name': cabinetsMilestoneName,
      'requested_at': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
      'responded_at': null,
      'responded_by_ref': null,
      'created_by_ref': db.collection('users').doc(user.uid),
      'is_demo': true,
    });

    // Client-authored requests ─ the "client_changes" subcollection captures
    // both quality issues and addition requests. These are what Sarah
    // Johnson would submit to the contractor from the client timeline.
    // `requested_by_ref` points at the contractor user since no real client
    // user exists in the demo — display shows a name, not a login identity.
    final clientStandInRef = db.collection('users').doc(user.uid);

    await projectRef.collection('client_changes').add({
      'type': 'quality_issue',
      'request_text':
          'Small crack in the tile by the fridge — noticed it after the '
          'countertop install. Want to make sure it gets fixed before '
          'appliances go back in.',
      'photo_url': 'https://picsum.photos/seed/demo-qi1/400/300',
      'milestone_ref': cabinetsMilestoneRef,
      'milestone_name': cabinetsMilestoneName ?? 'General',
      'requested_by_ref': clientStandInRef,
      'status': 'pending',
      'created_at': Timestamp.fromDate(now.subtract(const Duration(hours: 20))),
      'updated_at': Timestamp.fromDate(now.subtract(const Duration(hours: 20))),
      'is_demo': true,
    });

    await projectRef.collection('client_changes').add({
      'type': 'addition_request',
      'request_text':
          'Can we also replace the pantry door with a barn-style slider '
          'while the kitchen is torn up? Would love to get a price.',
      'photo_url': null,
      'milestone_ref': null,
      'milestone_name': 'General',
      'requested_by_ref': clientStandInRef,
      'status': 'pending',
      'contractor_response': null,
      'change_order_ref': null,
      'created_at': Timestamp.fromDate(now.subtract(const Duration(hours: 6))),
      'updated_at': Timestamp.fromDate(now.subtract(const Duration(hours: 6))),
      'is_demo': true,
    });

    // Expenses — receipts the GC has logged against the project.
    final contractorName = profile?['full_name'] as String? ?? 'Demo Contractor';
    final expenses = [
      {
        'amount': 450.0,
        'vendor': 'BigBox Rentals',
        'description': '30-yd roll-off dumpster for demo debris',
        'category': 'other',
        'daysAgo': 20,
      },
      {
        'amount': 682.50,
        'vendor': 'Hardwood Supply Co',
        'description': 'Subfloor patches + underlayment',
        'category': 'materials',
        'daysAgo': 18,
      },
      {
        'amount': 85.0,
        'vendor': 'City of Anytown',
        'description': 'Plumbing permit',
        'category': 'permits',
        'daysAgo': 14,
      },
      {
        'amount': 324.18,
        'vendor': "Mike's Plumbing Supply",
        'description': 'Rough-in PEX + fittings + shutoffs',
        'category': 'materials',
        'daysAgo': 11,
      },
    ];
    for (final e in expenses) {
      await projectRef.collection('expenses').add({
        'amount': e['amount'],
        'vendor': e['vendor'],
        'description': e['description'],
        'category': e['category'],
        'receipt_photo_url': null,
        'entered_by_uid': user.uid,
        'entered_by_name': contractorName,
        'entered_by_role': 'contractor',
        'created_at': Timestamp.fromDate(
          now.subtract(Duration(days: e['daysAgo'] as int)),
        ),
        'is_demo': true,
      });
    }

    // Team members — two fake crew so the "Crew" count + today's
    // schedule strip isn't empty. These uids don't correspond to real
    // Firebase users; the app displays the `name` field directly.
    const demoForemanUid = 'demo_foreman_mike';
    const demoWorkerUid = 'demo_worker_jake';
    final teamRef = db.collection('teams').doc(teamId);

    await teamRef.collection('members').doc(demoForemanUid).set({
      'name': 'Mike Reyes',
      'email': 'mike@demo.invalid',
      'role': 'foreman',
      'user_uid': demoForemanUid,
      'added_at': Timestamp.fromDate(now.subtract(const Duration(days: 60))),
      'status': 'active',
      'is_demo': true,
    });
    await teamRef.collection('members').doc(demoWorkerUid).set({
      'name': 'Jake Hensley',
      'email': 'jake@demo.invalid',
      'role': 'worker',
      'user_uid': demoWorkerUid,
      'added_at': Timestamp.fromDate(now.subtract(const Duration(days: 35))),
      'status': 'active',
      'is_demo': true,
    });

    // Assign the fake crew to the Johnson project so the dashboard
    // shows "3 crew" and schedule strip knows about them.
    await projectRef.update({
      'assigned_member_uids': FieldValue.arrayUnion([demoForemanUid, demoWorkerUid]),
    });

    // Schedule entries spanning this week — Mike + Jake on Johnson a few days.
    final scheduleDays = <Map<String, dynamic>>[
      {'uid': demoForemanUid, 'name': 'Mike Reyes', 'daysAgo': 2},
      {'uid': demoForemanUid, 'name': 'Mike Reyes', 'daysAgo': 1},
      {'uid': demoWorkerUid, 'name': 'Jake Hensley', 'daysAgo': 1},
      {'uid': demoForemanUid, 'name': 'Mike Reyes', 'daysAgo': 0}, // today
      {'uid': demoWorkerUid, 'name': 'Jake Hensley', 'daysAgo': 0},
      {'uid': user.uid, 'name': contractorName, 'daysAgo': 0},
      {'uid': demoForemanUid, 'name': 'Mike Reyes', 'daysAgo': -1}, // tomorrow
    ];
    for (final s in scheduleDays) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: s['daysAgo'] as int));
      await teamRef.collection('schedule_entries').add({
        'user_uid': s['uid'],
        'user_name': s['name'],
        'project_id': projectRef.id,
        'project_name': DemoProjectData.project['project_name'],
        'date': Timestamp.fromDate(d),
        'created_by_uid': user.uid,
        'created_at': Timestamp.now(),
        'is_demo': true,
      });
    }

    // Estimate — the accepted quote that became this project. Matches
    // the schema from EstimateService.create.
    await db.collection('estimates').add({
      'title': 'Johnson Residence — Kitchen Remodel',
      'client_name': 'Sarah Johnson',
      'client_email': 'sarah.johnson@example.com',
      'address': '1234 Maple Ave, Anytown, USA',
      'scope': 'Full kitchen remodel: demo existing cabinets/flooring, '
          'rough-in plumbing + electrical, install shaker cabinets + '
          'laminate counters, tile backsplash, appliance reinstall.',
      'exclusions': 'Appliances (client supplied). Countertop upgrade '
          'billed separately if selected.',
      'timeline': 'Approx 8 weeks from start',
      'line_items': [
        {'description': 'Demolition & disposal', 'amount': 8000.0},
        {'description': 'Plumbing + electrical rough-in', 'amount': 12000.0},
        {'description': 'Cabinets + counters (laminate)', 'amount': 15500.0},
        {'description': 'Backsplash + finishes', 'amount': 9500.0},
      ],
      'total': 45000.0,
      'photo_urls': <String>[],
      'status': 'accepted',
      'contractor_uid': user.uid,
      'linked_project_id': projectRef.id,
      'created_at': Timestamp.fromDate(now.subtract(const Duration(days: 32))),
      'updated_at': Timestamp.fromDate(now.subtract(const Duration(days: 22))),
      'is_demo': true,
    });

    // Time entries — hours the GC has logged against the project recently.
    final timeLogs = [
      {'daysAgo': 6, 'hours': 7.5, 'note': 'Demolition + debris cleanup'},
      {'daysAgo': 4, 'hours': 6.0, 'note': 'Plumbing rough-in, island sink + dishwasher line'},
      {'daysAgo': 2, 'hours': 8.0, 'note': 'Cabinet hang — base units leveled, uppers started'},
      {'daysAgo': 1, 'hours': 5.5, 'note': 'Counter templating + finishing uppers'},
    ];
    for (final t in timeLogs) {
      final entryDate = DateTime(
        now.year, now.month, now.day,
      ).subtract(Duration(days: t['daysAgo'] as int));
      await projectRef.collection('time_entries').add({
        'date': Timestamp.fromDate(entryDate),
        'hours': t['hours'],
        'description': t['note'],
        'logged_by_uid': user.uid,
        'logged_by_name': contractorName,
        'logged_by_role': 'contractor',
        'entered_by_uid': user.uid,
        'entered_by_name': contractorName,
        'created_at': Timestamp.fromDate(entryDate),
        'is_demo': true,
      });
    }

    return projectRef.id;
  }

  /// Deletes every project (and subcollections) owned by the signed-in user
  /// that has `is_demo: true`, plus demo-tagged estimates, team members, and
  /// schedule entries. Safe to call repeatedly.
  static Future<int> cleanup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    final db = FirebaseFirestore.instance;

    // Team-scoped demo data (members + schedule entries).
    try {
      final userSnap = await db.collection('users').doc(user.uid).get();
      final teamId = userSnap.data()?['team_id'] as String?;
      if (teamId != null) {
        final teamRef = db.collection('teams').doc(teamId);
        for (final sub in ['members', 'schedule_entries']) {
          try {
            final demoSnap = await teamRef.collection(sub)
                .where('is_demo', isEqualTo: true).get();
            for (final d in demoSnap.docs) {
              try {
                await d.reference.delete();
              } catch (e) {
                // ignore: avoid_print
                print('Cleanup: could not delete team/$sub/${d.id}: $e');
              }
            }
          } catch (e) {
            // ignore: avoid_print
            print('Cleanup: skipping team/$sub: $e');
          }
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Cleanup: skipping team data: $e');
    }

    // Demo estimates owned by this contractor.
    try {
      final estSnap = await db.collection('estimates')
          .where('contractor_uid', isEqualTo: user.uid)
          .where('is_demo', isEqualTo: true).get();
      for (final d in estSnap.docs) {
        try {
          await d.reference.delete();
        } catch (e) {
          // ignore: avoid_print
          print('Cleanup: could not delete estimate ${d.id}: $e');
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Cleanup: skipping estimates: $e');
    }

    final demos = await db.collection('projects')
        .where('contractor_uid', isEqualTo: user.uid)
        .where('is_demo', isEqualTo: true)
        .get();

    var removed = 0;
    for (final projectDoc in demos.docs) {
      // Delete known subcollections. Firestore doesn't cascade and each
      // subcollection may have different rules — one permission error
      // shouldn't kill the whole cleanup, so each is in its own try.
      for (final sub in [
        'milestones',
        'updates',
        'change_orders',
        'client_changes',
        'expenses',
        'time_entries',
        'invoices',
        'documents',
      ]) {
        try {
          final subSnap = await projectDoc.reference.collection(sub).get();
          for (final d in subSnap.docs) {
            try {
              await d.reference.delete();
            } catch (e) {
              // Log and keep going.
              // ignore: avoid_print
              print('Cleanup: could not delete $sub/${d.id}: $e');
            }
          }
        } catch (e) {
          // ignore: avoid_print
          print('Cleanup: skipping $sub on ${projectDoc.id}: $e');
        }
      }
      try {
        await projectDoc.reference.delete();
        removed += 1;
      } catch (e) {
        // ignore: avoid_print
        print('Cleanup: could not delete project ${projectDoc.id}: $e');
      }
    }
    return removed;
  }

  static List<String> _captionsForMilestone(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('demo')) {
      return [
        'Old cabinets out, walls prepped.',
        'Got the flooring up — subfloor looks solid.',
        'Ready for rough-in tomorrow.',
      ];
    }
    if (lower.contains('rough')) {
      return [
        'Plumbing roughed in for island sink.',
        'Electrical in place — all outlets to code.',
        'Gas line stubbed out for range.',
      ];
    }
    if (lower.contains('cabinet') || lower.contains('counter')) {
      return [
        'Base cabinets set and leveled.',
        'Uppers installed — love the lines.',
        'Quartz counters going in today.',
        'Templated the counter overhang — perfect fit.',
      ];
    }
    if (lower.contains('walkthrough') || lower.contains('final')) {
      return [
        'Appliances delivered.',
        'Final walkthrough scheduled.',
      ];
    }
    return ['Update from the jobsite.'];
  }
}
