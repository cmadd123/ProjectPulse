import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../backend/schema/milestone_record.dart';
import '../backend/schema/milestone_update_record.dart';
import 'add_milestone_update_bottom_sheet.dart';
import 'reply_to_update_bottom_sheet.dart';

class ProjectTimelineWidget extends StatelessWidget {
  final String projectId;
  final Map<String, dynamic> projectData;
  final String userRole; // "contractor" or "client"
  final bool showProgressHeader; // Show progress bar at top

  const ProjectTimelineWidget({
    super.key,
    required this.projectId,
    required this.projectData,
    required this.userRole,
    this.showProgressHeader = true,
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
        return Icons.schedule;
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

  Future<void> _startWorking(BuildContext context, String milestoneId) async {
    try {
      await MilestoneRecord.updateMilestone(projectId, milestoneId, {
        'status': 'in_progress',
        'started_at': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milestone started! You can now add updates.')),
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

  void _addUpdate(BuildContext context, String milestoneId, String milestoneName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddMilestoneUpdateBottomSheet(
        projectId: projectId,
        milestoneId: milestoneId,
        milestoneName: milestoneName,
      ),
    );
  }

  Future<void> _markComplete(BuildContext context, String milestoneId) async {
    try {
      await MilestoneRecord.updateMilestone(projectId, milestoneId, {
        'status': 'awaiting_approval',
        'marked_complete_at': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milestone marked complete! Client will be notified.')),
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

  Future<void> _approveMilestone(BuildContext context, String milestoneId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Milestone?'),
        content: const Text('This will release payment to the contractor. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading indicator
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Approving milestone...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      print('DEBUG: Approving milestone $milestoneId in project $projectId');

      await MilestoneRecord.updateMilestone(projectId, milestoneId, {
        'status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
      });

      print('DEBUG: Milestone approved successfully');

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Milestone approved! Payment will be released.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error approving milestone: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildProgressBar(List<MilestoneRecord> milestones) {
    final completedCount = milestones.where((m) => m.status == 'approved').length;
    final totalCount = milestones.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    print('DEBUG: Progress bar - $completedCount of $totalCount approved (${(progress * 100).toStringAsFixed(0)}%)');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2D3748),
            const Color(0xFF2D3748).withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                projectData['project_name'] ?? 'Project',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            projectData['client_name'] ?? 'Client',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedCount of $totalCount milestones complete',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                ),
              ),
              if (projectData['estimated_end_date'] != null)
                Text(
                  'Due: ${DateFormat.yMMMd().format((projectData['estimated_end_date'] as Timestamp).toDate())}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(BuildContext context, MilestoneRecord milestone, bool isFirst, bool isLast) {
    final statusColor = _getStatusColor(milestone.status);
    final isCompleted = milestone.status == 'approved';
    final isActive = milestone.status == 'in_progress' || milestone.status == 'awaiting_approval';
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 3,
                      color: isCompleted ? statusColor : Colors.grey[300],
                    ),
                  ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted ? statusColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor,
                      width: 3,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: isActive ? statusColor : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      color: isCompleted ? statusColor : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Milestone card
          Expanded(
            child: Card(
              margin: EdgeInsets.only(
                bottom: isLast ? 0 : 16,
                top: isFirst ? 0 : 0,
              ),
              elevation: isActive ? 4 : 1,
              color: isActive ? statusColor.withOpacity(0.05) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isActive ? statusColor : Colors.grey[200]!,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getStatusIcon(milestone.status),
                          color: statusColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            milestone.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                              color: isActive ? statusColor : Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          currencyFormat.format(milestone.amount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? Colors.green : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    if (milestone.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        milestone.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                    if (milestone.approvedAt != null) ...[
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
                              'Completed ${DateFormat.yMMMd().format(milestone.approvedAt!)}',
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
                    ] else if (milestone.status == 'awaiting_approval') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, size: 16, color: Colors.orange),
                            SizedBox(width: 6),
                            Text(
                              'Awaiting your approval',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (milestone.status == 'in_progress') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.construction, size: 16, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              milestone.startedAt != null
                                ? 'Started ${DateFormat.yMMMd().format(milestone.startedAt!)}'
                                : 'In progress',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Progress updates section
                    StreamBuilder<List<MilestoneUpdateRecord>>(
                      stream: MilestoneUpdateRecord.getUpdates(projectId, milestone.milestoneId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final updates = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Progress Updates (${updates.length})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...updates.map((update) => _buildUpdateItem(context, milestone.milestoneId, update)),
                          ],
                        );
                      },
                    ),
                    // Action buttons
                    if (userRole == 'contractor') ...[
                      const SizedBox(height: 12),
                      if (milestone.status == 'pending')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _startWorking(context, milestone.milestoneId),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Working'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        )
                      else if (milestone.status == 'in_progress')
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _addUpdate(context, milestone.milestoneId, milestone.name),
                                icon: const Icon(Icons.add_comment),
                                label: const Text('Add Update'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _markComplete(context, milestone.milestoneId),
                                icon: const Icon(Icons.check),
                                label: const Text('Mark Complete'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                    if (userRole == 'client' && milestone.status == 'awaiting_approval') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Request changes
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Changes'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => _approveMilestone(context, milestone.milestoneId),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateItem(BuildContext context, String milestoneId, MilestoneUpdateRecord update) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM d, h:mm a').format(update.postedAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            update.text,
            style: const TextStyle(fontSize: 14),
          ),
          if (update.clientResponse != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reply, size: 12, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'Client Response',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    update.clientResponse!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
          if (userRole == 'client' && update.clientResponse == null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => ReplyToUpdateBottomSheet(
                      projectId: projectId,
                      milestoneId: milestoneId,
                      updateId: update.updateId,
                      updateText: update.text,
                    ),
                  );
                },
                icon: const Icon(Icons.reply, size: 16),
                label: const Text('Reply', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MilestoneRecord>>(
      stream: MilestoneRecord.getMilestones(projectId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final milestones = snapshot.data!;
        print('DEBUG: StreamBuilder rebuilt with ${milestones.length} milestones');
        for (var m in milestones) {
          print('DEBUG:   - ${m.name}: ${m.status}');
        }

        if (milestones.isEmpty) {
          return SingleChildScrollView(
            child: Column(
              children: [
                if (showProgressHeader) _buildProgressBar([]),
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.track_changes_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No milestones defined yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      if (userRole == 'contractor') ...[
                        const SizedBox(height: 8),
                        Text(
                          'Add milestones to track project progress',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(0),
          itemCount: milestones.length + (showProgressHeader ? 1 : 0),
          itemBuilder: (context, index) {
            if (showProgressHeader && index == 0) {
              return _buildProgressBar(milestones);
            }

            final milestoneIndex = showProgressHeader ? index - 1 : index;
            final milestone = milestones[milestoneIndex];
            final isFirst = milestoneIndex == 0;
            final isLast = milestoneIndex == milestones.length - 1;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: isFirst ? 24 : 0,
                bottom: isLast ? 16 : 0,
              ),
              child: _buildMilestoneCard(context, milestone, isFirst, isLast),
            );
          },
        );
      },
    );
  }
}
