import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'leave_review_screen.dart';
import 'project_gallery_screen.dart';
import '../shared/project_chat_screen.dart';
import '../../components/project_timeline_widget.dart';

class ClientProjectTimeline extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> projectData;

  const ClientProjectTimeline({
    super.key,
    required this.projectId,
    required this.projectData,
  });

  @override
  State<ClientProjectTimeline> createState() => _ClientProjectTimelineState();
}

class _ClientProjectTimelineState extends State<ClientProjectTimeline> {
  int _pendingMilestonesCount = 0;
  int _pendingActivityCount = 0;

  @override
  void initState() {
    super.initState();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    // Listen to pending milestones (awaiting approval)
    FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('milestones')
        .where('status', isEqualTo: 'awaiting_approval')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _pendingMilestonesCount = snapshot.docs.length;
        });
      }
    });

    // Listen to pending change orders
    FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('change_orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _pendingActivityCount = snapshot.docs.length;
        });
      }
    });
  }

  Future<bool> _hasLeftReview() async {
    try {
      final contractorRef = widget.projectData['contractor_ref'] as DocumentReference;
      final projectRef = FirebaseFirestore.instance.collection('projects').doc(widget.projectId);

      final reviewsSnapshot = await contractorRef
          .collection('reviews')
          .where('project_ref', isEqualTo: projectRef)
          .limit(1)
          .get();

      return reviewsSnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _respondToChangeOrder(
    BuildContext context,
    String changeOrderId,
    bool approve,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // Update change order status
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('change_orders')
          .doc(changeOrderId)
          .update({
        'status': approve ? 'approved' : 'declined',
        'responded_at': FieldValue.serverTimestamp(),
        'responded_by_ref': userRef,
      });

      // If approved, update project's current_cost
      if (approve) {
        final changeOrderDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('change_orders')
            .doc(changeOrderId)
            .get();

        final costChange = changeOrderDoc.data()?['cost_change'] as num? ?? 0;

        await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
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

  Stream<List<Map<String, dynamic>>> _getCombinedActivityStream() {
    final updatesStream = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('updates')
        .orderBy('created_at', descending: true)
        .snapshots();

    final changeOrdersStream = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('change_orders')
        .orderBy('requested_at', descending: true)
        .snapshots();

    final milestoneUpdatesStream = FirebaseFirestore.instance
        .collectionGroup('milestone_updates')
        .where('project_id', isEqualTo: widget.projectId)
        .orderBy('posted_at', descending: true)
        .snapshots();

    // Combine the three streams using Rx.combineLatest3
    return Rx.combineLatest3(
      updatesStream,
      changeOrdersStream,
      milestoneUpdatesStream,
      (QuerySnapshot updates, QuerySnapshot changeOrders, QuerySnapshot milestoneUpdates) {
        final List<Map<String, dynamic>> combined = [];

        // Add photo updates
        for (var doc in updates.docs) {
          final data = doc.data() as Map<String, dynamic>;
          combined.add({
            'type': 'photo_update',
            'id': doc.id,
            'data': data,
            'timestamp': (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          });
        }

        // Add change orders
        for (var doc in changeOrders.docs) {
          final data = doc.data() as Map<String, dynamic>;
          combined.add({
            'type': 'change_order',
            'id': doc.id,
            'data': data,
            'timestamp': (data['requested_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          });
        }

        // Add milestone updates
        for (var doc in milestoneUpdates.docs) {
          final data = doc.data() as Map<String, dynamic>;
          combined.add({
            'type': 'milestone_update',
            'id': doc.id,
            'data': data,
            'timestamp': (data['posted_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          });
        }

        // Sort by timestamp (newest first)
        combined.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

        return combined;
      },
    );
  }

  Widget _buildPhotoUpdateCard(BuildContext context, Map<String, dynamic> activity, int index) {
    final data = activity['data'] as Map<String, dynamic>;
    final date = activity['timestamp'] as DateTime;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _FullScreenImage(
              imageUrl: data['photo_url'] ?? '',
              caption: data['caption'] ?? '',
              date: date,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 20),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            Hero(
              tag: 'photo_${activity['id']}',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  data['photo_url'] ?? '',
                  width: double.infinity,
                  height: 280,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 280,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 50),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 280,
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Caption and date
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.photo_camera,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Photo Update',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM d, h:mm a').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  if (data['caption'] != null &&
                      data['caption'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      data['caption'],
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeOrderCard(BuildContext context, Map<String, dynamic> activity) {
    final data = activity['data'] as Map<String, dynamic>;
    final date = activity['timestamp'] as DateTime;
    final status = data['status'] as String;
    final costChange = data['cost_change'] as num;
    final description = data['description'] as String;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    if (status == 'approved') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusLabel = 'APPROVED';
    } else if (status == 'declined') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusLabel = 'DECLINED';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
      statusLabel = 'PENDING';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      color: status == 'pending' ? Colors.amber[50] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  Icons.request_quote,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Change Order',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, h:mm a').format(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Change order content
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${costChange >= 0 ? '+' : ''}\$${costChange.abs()}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: costChange >= 0
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.green,
                  ),
                ),
              ],
            ),

            // Approve/Decline buttons for pending orders
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _respondToChangeOrder(
                        context,
                        activity['id'],
                        false,
                      ),
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
                      onPressed: () => _respondToChangeOrder(
                        context,
                        activity['id'],
                        true,
                      ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneCard(Map<String, dynamic> activity) {
    final data = activity['data'] as Map<String, dynamic>;
    final date = activity['timestamp'] as DateTime;
    final name = data['name'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      color: Colors.green[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  Icons.flag,
                  size: 16,
                  color: Colors.green[700],
                ),
                const SizedBox(width: 6),
                Text(
                  'Milestone Completed',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, h:mm a').format(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Milestone content
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

  Widget _buildMilestoneUpdateCard(Map<String, dynamic> activity) {
    final data = activity['data'] as Map<String, dynamic>;
    final date = activity['timestamp'] as DateTime;
    final text = data['text'] as String;
    final milestoneId = data['milestone_id'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue[200]!, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  Icons.update,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Milestone Update',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, h:mm a').format(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Update text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final startDate = (widget.projectData['start_date'] as Timestamp?)?.toDate();
    final estimatedEndDate = (widget.projectData['estimated_end_date'] as Timestamp?)?.toDate();

    int? totalDays;
    int? daysElapsed;

    if (startDate != null && estimatedEndDate != null) {
      totalDays = estimatedEndDate.difference(startDate).inDays;
      daysElapsed = DateTime.now().difference(startDate).inDays;
      if (daysElapsed < 0) daysElapsed = 0;
      if (daysElapsed > totalDays) daysElapsed = totalDays;
    }

    return Scaffold(
      extendBody: false,
      appBar: AppBar(
        title: Text(widget.projectData['project_name'] ?? 'Project'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: 'Gallery View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectGalleryScreen(
                    projectId: widget.projectId,
                    projectData: widget.projectData,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectChatScreen(
                    projectId: widget.projectId,
                    projectName: widget.projectData['project_name'] ?? 'Project',
                    isContractor: false,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Review prompt banner (if project completed and no review yet)
          if (widget.projectData['status'] == 'completed')
            FutureBuilder<bool>(
              future: _hasLeftReview(),
              builder: (context, snapshot) {
                if (snapshot.data == false) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.amber[200]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber[700], size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Project Complete!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[900],
                                ),
                              ),
                              Text(
                                'How was your experience?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LeaveReviewScreen(
                                  projectId: widget.projectId,
                                  projectData: widget.projectData,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[700],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Leave Review'),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

          // Project header with progress
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Project cost
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Project Cost',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${(widget.projectData['current_cost'] ?? widget.projectData['original_cost'] ?? 0).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (widget.projectData['current_cost'] != null &&
                        widget.projectData['original_cost'] != null &&
                        widget.projectData['current_cost'] != widget.projectData['original_cost']) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Original',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              '\$${(widget.projectData['original_cost'] ?? 0).toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Progress bar
                if (totalDays != null && daysElapsed != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Day $daysElapsed of $totalDays',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${((daysElapsed / totalDays) * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: daysElapsed / totalDays,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Timeline dates
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Started',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          startDate != null ? dateFormat.format(startDate) : 'TBD',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Expected completion',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          estimatedEndDate != null ? dateFormat.format(estimatedEndDate) : 'TBD',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Combined Timeline: Milestones + Activity
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Milestones'),
                              if (_pendingMilestonesCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _pendingMilestonesCount > 9 ? '9+' : '$_pendingMilestonesCount',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Activity'),
                              if (_pendingActivityCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _pendingActivityCount > 9 ? '9+' : '$_pendingActivityCount',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Milestones
                        ProjectTimelineWidget(
                          projectId: widget.projectId,
                          projectData: widget.projectData,
                          userRole: 'client',
                          showProgressHeader: false,
                        ),
                        // Tab 2: Activity (photos, change orders)
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _getCombinedActivityStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.photo_library_outlined,
                                        size: 80,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No activity yet',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Photo updates and change orders will appear here',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final activities = snapshot.data!;

                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                              itemCount: activities.length,
                              itemBuilder: (context, index) {
                                final activity = activities[index];
                                final type = activity['type'] as String;

                                if (type == 'photo_update') {
                                  return _buildPhotoUpdateCard(context, activity, index);
                                } else if (type == 'change_order') {
                                  return _buildChangeOrderCard(context, activity);
                                } else if (type == 'milestone') {
                                  return _buildMilestoneCard(activity);
                                } else if (type == 'milestone_update') {
                                  return _buildMilestoneUpdateCard(activity);
                                }

                                return const SizedBox.shrink();
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Full-screen image viewer
class _FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String caption;
  final DateTime date;

  const _FullScreenImage({
    required this.imageUrl,
    required this.caption,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image, size: 100, color: Colors.white),
                    );
                  },
                ),
              ),
            ),
          ),
          if (caption.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.black.withOpacity(0.7),
              child: Text(
                caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
