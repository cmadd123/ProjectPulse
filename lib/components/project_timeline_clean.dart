import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../backend/schema/milestone_record.dart';
import '../services/notification_service.dart';
import 'change_type_selector_bottom_sheet.dart';

/// Clean milestone timeline matching home page aesthetic
/// - Light grey background
/// - White cards with subtle shadows
/// - Timeline circles on left
/// - Color-coded status (green = done, blue = active, grey = pending)
/// - Action buttons for contractors only
class ProjectTimelineClean extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> projectData;
  final String userRole; // "contractor" or "client"
  final Function(String milestoneId, String milestoneName)? onAddPhotoUpdate;

  const ProjectTimelineClean({
    super.key,
    required this.projectId,
    required this.projectData,
    required this.userRole,
    this.onAddPhotoUpdate,
  });

  @override
  State<ProjectTimelineClean> createState() => _ProjectTimelineCleanState();
}

class _ProjectTimelineCleanState extends State<ProjectTimelineClean> {
  final Map<String, GlobalKey> _milestoneKeys = {};

  void _scrollToAwaitingApproval(List<MilestoneRecord> milestones) {
    // Find the first awaiting approval milestone
    final awaitingIndex = milestones.indexWhere((m) => m.status == 'awaiting_approval');
    if (awaitingIndex != -1) {
      final milestoneId = milestones[awaitingIndex].milestoneId;
      final key = _milestoneKeys[milestoneId];
      if (key?.currentContext != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.2, // Scroll so it's 20% from the top
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // White background to match other tabs
      child: StreamBuilder<List<MilestoneRecord>>(
        stream: MilestoneRecord.getMilestones(widget.projectId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final milestones = snapshot.data!;

          if (milestones.isEmpty) {
            return _buildEmptyState();
          }

          // Ensure we have keys for all milestones
          for (var milestone in milestones) {
            _milestoneKeys.putIfAbsent(milestone.milestoneId, () => GlobalKey());
          }

          // Auto-scroll to awaiting approval milestone when client views
          if (widget.userRole == 'client') {
            _scrollToAwaitingApproval(milestones);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: milestones.length + 1 + (widget.userRole == 'client' ? 1 : 0), // +1 for header, +1 for request changes button (client only)
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildHeaderCard(milestones);
              }

              // Request Changes button for clients (between header and first milestone)
              if (widget.userRole == 'client' && index == 1) {
                return _buildRequestChangesButton(context);
              }

              final milestoneIndex = widget.userRole == 'client' ? index - 2 : index - 1;
              final milestone = milestones[milestoneIndex];
              final isLast = milestoneIndex == milestones.length - 1;

              return _buildMilestoneItem(
                context,
                milestone,
                milestoneIndex + 1,
                milestones.length,
                isLast,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.track_changes_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No milestones defined yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestChangesButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton.icon(
        onPressed: () => _showRequestChangesDialog(context),
        icon: const Icon(Icons.change_circle_outlined, size: 18),
        label: const Text('Request Changes'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.blue[700]!),
          foregroundColor: Colors.blue[700],
          backgroundColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _showRequestChangesDialog(BuildContext context) async {
    // Show change type selector FIRST (Quality Issue or Addition Request)
    // The forms will handle optional milestone selection
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ChangeTypeSelectorBottomSheet(
        projectId: widget.projectId,
        milestoneId: '', // Empty - form will let user optionally select milestone
        milestoneName: 'General', // Default to "General" if no milestone selected
      ),
    );
  }

  Widget _buildHeaderCard(List<MilestoneRecord> milestones) {
    final completedCount = milestones.where((m) => m.status == 'approved').length;
    final totalCount = milestones.length;
    final projectTotal = milestones.fold(0.0, (sum, m) => sum + m.amount);
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Phases',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$completedCount of $totalCount milestones completed',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (widget.userRole == 'contractor') ...[
                        const SizedBox(height: 4),
                        Text(
                          'Project Total: ${currencyFormat.format(projectTotal)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Percentage text in top-right (GC only)
                if (widget.userRole == 'contractor') ...[
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Segmented progress bar at bottom (GC only)
          if (widget.userRole == 'contractor' && milestones.isNotEmpty) ...[
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Row(
                children: milestones.map((milestone) {
                  Color segmentColor;
                  switch (milestone.status) {
                    case 'approved':
                      segmentColor = Colors.green;
                      break;
                    case 'in_progress':
                      segmentColor = Colors.blue;
                      break;
                    case 'awaiting_approval':
                      segmentColor = Colors.orange;
                      break;
                    default: // 'not_started'
                      segmentColor = Colors.grey[300]!;
                  }
                  return Expanded(
                    child: Container(
                      height: 6,
                      color: segmentColor,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMilestoneItem(
    BuildContext context,
    MilestoneRecord milestone,
    int phaseNumber,
    int totalPhases,
    bool isLast,
  ) {
    final isCompleted = milestone.status == 'approved';
    final isAwaitingApproval = milestone.status == 'awaiting_approval';
    final isInProgress = milestone.status == 'in_progress';
    final isPending = milestone.status == 'pending' || milestone.status == 'not_started';

    final circleColor = isCompleted
        ? Colors.green
        : isAwaitingApproval
            ? Colors.orange
            : isInProgress
                ? Colors.blue
                : Colors.grey[300]!;

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline circle indicator
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : isAwaitingApproval
                        ? const Icon(Icons.pending, color: Colors.white, size: 12)
                        : isInProgress
                            ? const Icon(Icons.construction, color: Colors.white, size: 12)
                            : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey[300],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // Card content
          Expanded(
            child: Container(
              key: isAwaitingApproval ? _milestoneKeys[milestone.milestoneId] : null,
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isAwaitingApproval
                    ? Colors.orange.withOpacity(0.02)
                    : isInProgress
                        ? Colors.blue.withOpacity(0.02)
                        : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isAwaitingApproval
                    ? Border.all(color: Colors.orange.withOpacity(0.3), width: 2)
                    : isInProgress
                        ? Border.all(color: Colors.blue.withOpacity(0.3), width: 2)
                        : null,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          milestone.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: (isAwaitingApproval || isInProgress) ? FontWeight.bold : FontWeight.w600,
                            color: Colors.black87, // Always black, not orange
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Phase $phaseNumber of $totalPhases',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      if (isAwaitingApproval) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.userRole == 'client' ? 'Awaiting Your Approval' : 'Awaiting Client Approval',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (milestone.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      milestone.description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                  if (isCompleted && milestone.approvedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Completed ${DateFormat.yMMM().format(milestone.approvedAt!)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],

                  // Action buttons for contractors
                  if (widget.userRole == 'contractor') ...[
                    const SizedBox(height: 12),
                    // Show "Start Working" button for pending milestones
                    if (milestone.status == 'pending' || milestone.status == 'not_started') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _startWorking(context, milestone),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Working'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                    // Show photo update and complete buttons for in-progress milestones
                    if (milestone.status == 'in_progress') ...[
                      // Primary action: Add Photo Update
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _addUpdate(context, milestone),
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Add Photo Update'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Secondary action: Mark Complete
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _markComplete(context, milestone),
                          icon: const Icon(Icons.check),
                          label: const Text('Mark Complete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ],

                  // Approve button for clients on awaiting_approval milestones
                  if (widget.userRole == 'client' && milestone.status == 'awaiting_approval') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _approveMilestone(context, milestone),
                        icon: const Icon(Icons.attach_money, size: 18),
                        label: Text('Approve & Pay ${currencyFormat.format(milestone.amount)}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addUpdate(BuildContext context, MilestoneRecord milestone) {
    if (widget.onAddPhotoUpdate != null) {
      widget.onAddPhotoUpdate!(milestone.milestoneId, milestone.name);
    }
  }

  Future<void> _startWorking(BuildContext context, MilestoneRecord milestone) async {
    try {
      // Update milestone status to in_progress
      await MilestoneRecord.updateMilestone(widget.projectId, milestone.milestoneId, {
        'status': 'in_progress',
        'started_at': FieldValue.serverTimestamp(),
      });

      // Send notification to client (non-blocking - don't await)
      NotificationService.sendMilestoneStartedNotification(
        projectId: widget.projectId,
        projectName: widget.projectData['project_name'] as String? ?? 'Project',
        milestoneName: milestone.name,
      ).catchError((error) {
        debugPrint('Failed to send notification: $error');
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started working on "${milestone.name}"'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
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

  Future<void> _markComplete(BuildContext context, MilestoneRecord milestone) async {
    try {
      // Update milestone status to awaiting_approval
      await MilestoneRecord.updateMilestone(widget.projectId, milestone.milestoneId, {
        'status': 'awaiting_approval',
        'marked_complete_at': FieldValue.serverTimestamp(),
      });

      // Send notification to client (non-blocking - don't await)
      NotificationService.sendMilestoneNotification(
        projectId: widget.projectId,
        projectName: widget.projectData['project_name'] as String? ?? 'Project',
        milestoneName: milestone.name,
      ).catchError((error) {
        debugPrint('Failed to send notification: $error');
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milestone marked complete! Client notified.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
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

  Future<void> _approveMilestone(BuildContext context, MilestoneRecord milestone) async {
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve & Pay'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    debugPrint('🔍 _approveMilestone: Starting approval for ${milestone.name}');

    try {
      // Update milestone status to approved
      debugPrint('🔍 _approveMilestone: Updating Firestore...');
      await MilestoneRecord.updateMilestone(widget.projectId, milestone.milestoneId, {
        'status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
      });
      debugPrint('🔍 _approveMilestone: Firestore updated successfully');

      // Show success SnackBar IMMEDIATELY after Firestore update
      if (context.mounted) {
        debugPrint('🔍 _approveMilestone: Context is mounted, showing SnackBar');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milestone approved! Contractor will be notified.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        debugPrint('❌ _approveMilestone: Context NOT mounted, cannot show SnackBar');
      }

      // Send notification to contractor (non-blocking - happens in background)
      debugPrint('🔍 _approveMilestone: Sending notification in background...');
      NotificationService.sendMilestoneApprovedNotification(
        projectId: widget.projectId,
        projectName: widget.projectData['project_name'] as String? ?? 'Project',
        milestoneName: milestone.name,
      ).catchError((error) {
        debugPrint('❌ Failed to send notification: $error');
      });
    } catch (e) {
      debugPrint('❌ _approveMilestone: Error occurred: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
