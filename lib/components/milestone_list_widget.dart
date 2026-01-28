import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../backend/schema/milestone_record.dart';

class MilestoneListWidget extends StatelessWidget {
  final String projectId;
  final String userRole; // "contractor" or "client"
  final double projectAmount;
  final VoidCallback? onMilestoneComplete; // Contractor marks complete
  final Function(MilestoneRecord)? onMilestoneApprove; // Client approves

  const MilestoneListWidget({
    super.key,
    required this.projectId,
    required this.userRole,
    required this.projectAmount,
    this.onMilestoneComplete,
    this.onMilestoneApprove,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'awaiting_approval':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'disputed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.circle_outlined;
      case 'in_progress':
        return Icons.construction;
      case 'awaiting_approval':
        return Icons.rate_review;
      case 'approved':
        return Icons.check_circle;
      case 'disputed':
        return Icons.warning;
      default:
        return Icons.circle_outlined;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Not Started';
      case 'in_progress':
        return 'In Progress';
      case 'awaiting_approval':
        return 'Awaiting Approval';
      case 'approved':
        return 'Approved';
      case 'disputed':
        return 'Disputed';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return StreamBuilder<List<MilestoneRecord>>(
      stream: MilestoneRecord.getMilestones(projectId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final milestones = snapshot.data!;

        if (milestones.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.track_changes_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No milestones defined yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (userRole == 'contractor') ...[
                    const SizedBox(height: 8),
                    Text(
                      'Add milestones to enable progress payments',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        final totalReleased = milestones
            .where((m) => m.status == 'approved')
            .fold(0.0, (sum, m) => sum + m.amount);
        final remainingBalance = projectAmount - totalReleased;

        return Column(
          children: [
            // Protected Balance Header (client only)
            if (userRole == 'client')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Protected Balance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Icon(
                          Icons.shield,
                          color: Colors.white.withOpacity(0.7),
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(remainingBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Released: ${currencyFormat.format(totalReleased)} of ${currencyFormat.format(projectAmount)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

            // Milestone list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: milestones.length,
                itemBuilder: (context, index) {
                  final milestone = milestones[index];
                  final statusColor = _getStatusColor(milestone.status);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        // TODO: Show milestone details
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getStatusIcon(milestone.status),
                                    color: statusColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        milestone.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getStatusText(milestone.status),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(milestone.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            if (milestone.description.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                milestone.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                            if (milestone.status == 'approved' && milestone.approvedAt != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Approved ${DateFormat.yMMMd().format(milestone.approvedAt!)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (milestone.releasedAmount != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '• Released: ${currencyFormat.format(milestone.releasedAmount)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            // Action buttons
                            if (userRole == 'contractor' && milestone.status == 'in_progress') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: onMilestoneComplete,
                                  icon: const Icon(Icons.check),
                                  label: const Text('Mark Complete'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ),
                            ],
                            if (userRole == 'client' && milestone.status == 'awaiting_approval') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        // TODO: Request changes
                                      },
                                      child: const Text('Request Changes'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        if (onMilestoneApprove != null) {
                                          onMilestoneApprove!(milestone);
                                        }
                                      },
                                      icon: const Icon(Icons.check),
                                      label: const Text('Approve'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
