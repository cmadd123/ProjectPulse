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
    await projectRef.collection('change_orders').add({
      'description': 'Upgrade counters from laminate to 3cm quartz slab. '
          'Client-approved upgrade adds \$2,500 material and ~3 days to schedule.',
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

    return projectRef.id;
  }

  /// Deletes every project (and subcollections) owned by the signed-in user
  /// that has `is_demo: true`. Safe to call repeatedly.
  static Future<int> cleanup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    final db = FirebaseFirestore.instance;

    final demos = await db.collection('projects')
        .where('contractor_uid', isEqualTo: user.uid)
        .where('is_demo', isEqualTo: true)
        .get();

    var removed = 0;
    for (final projectDoc in demos.docs) {
      // Delete known subcollections in batches. Firestore doesn't cascade.
      for (final sub in ['milestones', 'updates', 'change_orders', 'invoices']) {
        final subSnap = await projectDoc.reference.collection(sub).get();
        for (final d in subSnap.docs) {
          await d.reference.delete();
        }
      }
      await projectDoc.reference.delete();
      removed += 1;
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
