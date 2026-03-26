import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../backend/schema/milestone_record.dart';
import '../../services/notification_service.dart';
import '../../services/connectivity_service.dart';

/// Design 3: Personality Injection (Polished Current)
/// Keep existing layout, add warmth and human touches
class HomeTabDesign3 extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> projectData;
  final Color brandColor;
  final ValueChanged<int> onTabSwitch;

  const HomeTabDesign3({
    super.key,
    required this.projectId,
    required this.projectData,
    required this.brandColor,
    required this.onTabSwitch,
  });

  @override
  State<HomeTabDesign3> createState() => _HomeTabDesign3State();
}

class _HomeTabDesign3State extends State<HomeTabDesign3> {
  bool _welcomeMessageDismissed = false;

  Future<void> _approveMilestone(String milestoneId, String milestoneName) async {
    try {
      await MilestoneRecord.updateMilestone(widget.projectId, milestoneId, {
        'status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
      });

      final projectName = widget.projectData['project_name'] as String? ?? 'Project';
      NotificationService.sendMilestoneApprovedNotification(
        projectId: widget.projectId,
        projectName: projectName,
        milestoneName: milestoneName,
      );

      if (mounted) {
        ConnectivityService.showOfflineWriteFeedback(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milestone approved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _respondToChangeOrder(String changeOrderId, bool approve) async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

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

      if (approve) {
        final changeOrderDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('change_orders')
            .doc(changeOrderId)
            .get();

        final costChange = changeOrderDoc.data()?['cost_change'] as num? ?? 0;

        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .update({
          'current_cost': FieldValue.increment(costChange.toDouble()),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Change order approved' : 'Change order declined'),
            backgroundColor: approve ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 1) return '1 hour ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MMM d').format(dateTime);
  }

  String _getProgressMessage(int completed, int total) {
    if (total == 0) return 'Getting started';
    final percentage = (completed / total * 100).round();

    if (percentage == 0) return 'Just beginning';
    if (percentage < 25) return 'Off to a great start';
    if (percentage < 50) return 'Making steady progress';
    if (percentage < 75) return 'More than halfway there';
    if (percentage < 100) return 'Almost complete';
    return 'Project complete';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Welcome Message (Dismissible)
          if (!_welcomeMessageDismissed) _buildWelcomeMessage(),

          // Progress Ring Hero
          _buildProgressHero(),

          // Needs Your Attention
          _buildActionCards(),

          // Coming Up This Week
          _buildComingUp(),

          // Project Budget
          _buildBudgetCard(),

          // What's Happening (Activity Feed)
          _buildActivityFeed(),

          // Your Contractor
          _buildContractorCard(),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'Powered by ProjectPulse',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    final clientName = widget.projectData['client_name'] as String? ?? 'there';
    final firstName = clientName.split(' ').first;
    final contractorName = widget.projectData['contractor_business_name'] as String? ?? 'Your contractor';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.brandColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.brandColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $firstName! 👋',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.brandColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$contractorName will post updates here as work progresses',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
            onPressed: () => setState(() => _welcomeMessageDismissed = true),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHero() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
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
      child: StreamBuilder<List<MilestoneRecord>>(
        stream: MilestoneRecord.getMilestones(widget.projectId),
        builder: (context, snapshot) {
          final milestones = snapshot.data ?? [];
          final total = milestones.length;
          final completed = milestones.where(
            (m) => m.status == 'approved' || m.status == 'complete',
          ).length;
          final progress = total > 0 ? completed / total : 0.0;

          return Column(
            children: [
              // Progress Ring
              SizedBox(
                height: 140,
                width: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 140,
                      width: 140,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(widget.brandColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$completed of $total',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: widget.brandColor,
                          ),
                        ),
                        Text(
                          'milestones',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _getProgressMessage(completed, total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '$completed of $total milestones completed',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayCounter() {
    final startDate = (widget.projectData['start_date'] as Timestamp?)?.toDate();
    final endDate = (widget.projectData['estimated_end_date'] as Timestamp?)?.toDate();

    if (startDate == null || endDate == null) {
      return Text(
        'Timeline will be set soon',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[500],
        ),
      );
    }

    final totalDays = endDate.difference(startDate).inDays;
    var daysElapsed = DateTime.now().difference(startDate).inDays;
    if (daysElapsed < 0) daysElapsed = 0;
    if (daysElapsed > totalDays) daysElapsed = totalDays;

    String message = 'Day $daysElapsed of $totalDays';
    if (daysElapsed > totalDays * 0.75) {
      message += ' • Almost done!';
    } else if (daysElapsed > totalDays * 0.5) {
      message += ' • More than halfway!';
    }

    return Text(
      message,
      style: TextStyle(
        fontSize: 13,
        color: Colors.grey[500],
      ),
    );
  }

  Widget _buildActionCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .where('status', isEqualTo: 'awaiting_approval')
          .snapshots(),
      builder: (context, milestoneSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('change_orders')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, coSnap) {
            final pendingMilestones = milestoneSnap.data?.docs ?? [];
            final pendingCOs = coSnap.data?.docs ?? [];

            if (pendingMilestones.isEmpty && pendingCOs.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(20),
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
                    '📋 Needs Your Attention',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...pendingMilestones.map((doc) => _buildMilestoneActionCard(doc)),
                  ...pendingCOs.map((doc) => _buildChangeOrderActionCard(doc)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMilestoneActionCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? 'Milestone';
    final description = data['description'] as String? ?? '';
    final amount = data['payment_amount'] as num? ?? 0;
    final icon = data['icon'] as String? ?? '💵';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name milestone ready for approval',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Payment: \$${amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '👉 Tap to review photos and approve',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onTabSwitch(1), // Go to Photos tab to review work
                  child: const Text('View Details'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => widget.onTabSwitch(3), // Navigate to Milestones tab
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12), // Match outlined button height
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Approve'),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChangeOrderActionCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Change Order';
    final description = data['description'] as String? ?? '';
    final costChange = data['cost_change'] as num? ?? 0;
    final icon = data['icon'] as String? ?? '🔧';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change order waiting for your decision',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '"$title"',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Cost: ${costChange >= 0 ? '+' : ''}\$${costChange.abs().toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '👉 Tap to approve or ask questions',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respondToChangeOrder(doc.id, false),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondToChangeOrder(doc.id, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComingUp() {
    // For now, show a simple placeholder
    // TODO: Implement sequential/chronological upcoming work logic
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
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
            '⚡ Coming Up',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Work starting soon!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
    final originalCost = widget.projectData['original_cost'] as num? ?? 0;
    final currentCost = widget.projectData['current_cost'] as num? ?? originalCost;
    final costDifference = currentCost - originalCost;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
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
            '💰 Project Budget',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _BudgetRow(
            label: 'Started at:',
            amount: '\$${originalCost.toStringAsFixed(0)}',
          ),
          if (costDifference != 0) ...[
            const SizedBox(height: 8),
            _BudgetRow(
              label: 'Changes so far:',
              sublabel: costDifference > 0 ? 'additions' : 'reductions',
              amount: '${costDifference >= 0 ? '+' : ''}\$${costDifference.abs().toStringAsFixed(0)}',
              isChange: true,
            ),
          ],
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _BudgetRow(
            label: 'Current Total:',
            amount: '\$${currentCost.toStringAsFixed(0)}',
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
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
            '⚡ What\'s Happening',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('updates')
                .orderBy('created_at', descending: true)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text(
                  'Updates will appear here when work begins',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                );
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final caption = data['caption'] as String? ?? '';
                  final createdAt = (data['created_at'] as Timestamp?)?.toDate();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ActivityItem(
                      time: createdAt != null ? _getTimeAgo(createdAt) : 'Recently',
                      description: caption,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContractorCard() {
    final contractorBusinessName = widget.projectData['contractor_business_name'] as String? ?? 'Your Contractor';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
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
            '👷 Your Contractor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.brandColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business,
                  size: 32,
                  color: widget.brandColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contractorBusinessName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Questions about your project?',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => widget.onTabSwitch(2), // Go to Chat tab
                  icon: const Icon(Icons.message, size: 18),
                  label: const Text('Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.brandColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final String label;
  final String? sublabel;
  final String amount;
  final bool isBold;
  final bool isChange;

  const _BudgetRow({
    required this.label,
    this.sublabel,
    required this.amount,
    this.isBold = false,
    this.isChange = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 15 : 14,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                color: Colors.grey[700],
              ),
            ),
            if (sublabel != null) ...[
              const SizedBox(height: 2),
              Text(
                sublabel!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isChange ? Colors.green[700] : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String time;
  final String description;

  const _ActivityItem({
    required this.time,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🕐 $time',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
