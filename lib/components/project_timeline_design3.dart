import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../backend/schema/milestone_record.dart';
import '../backend/schema/milestone_update_record.dart';
import '../services/notification_service.dart';
import '../services/connectivity_service.dart';
import '../services/invoice_service.dart';
import 'add_milestone_update_bottom_sheet.dart';
import 'reply_to_update_bottom_sheet.dart';
import 'change_type_selector_bottom_sheet.dart';
// TODO: Removed client changes cards - will be redesigned in Activity Center overhaul
// import 'contractor_quality_issues_card.dart';
// import 'contractor_addition_requests_card.dart';
// import 'client_addition_requests_card.dart';

// Design 3: Clean milestone page matching home page aesthetic
//
// VISUAL PREVIEW:
// ┌─────────────────────────────────────────────┐
// │  Project Phases                             │
// │  3 of 5 milestones completed                │  <- Clean white header card
// │  Making steady progress                     │     (subtle shadow, 16px rounded)
// └─────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────┐
// │  Foundation & Framing            $6,000     │  <- Clean white milestone card
// │  Phase 1 of 3                               │     (NO timeline circles)
// │  Demo, framing, and structural work         │     (subtle shadow, 16px rounded)
// │  ✅ Completed Mar 11                        │     (emoji status indicators)
// └─────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────┐
// │  🔨 Electrical                   $3,500     │  <- Active milestone
// │  Phase 2 of 3                               │     (subtle blue border)
// │  Rough-in and panel install                 │     (light blue background tint)
// │  Started 2 days ago                         │
// │  [Mark Complete] [Add Update]               │
// └─────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────┐
// │  ⏱️ Plumbing                     $4,000     │  <- Pending milestone
// │  Phase 3 of 3                               │     (grey emoji, collapsed)
// │  Tap to expand                              │
// └─────────────────────────────────────────────┘
//
// KEY CHANGES:
// - Header card with progress message (warm, encouraging)
// - Remove timeline circles on the left
// - Clean white cards with subtle shadows (matching home page)
// - 16px margins, 16px border radius
// - Emoji status indicators (✅ 🔨 ⏱️)
// - Light grey page background (Colors.grey[50])
// - Collapsed by default for pending/completed (cleaner)
// - Active milestones expanded with subtle border + tint

class ProjectTimelineDesign3 extends StatelessWidget {
  final String projectId;
  final Map<String, dynamic> projectData;
  final String userRole; // "contractor", "client", or "team_member"
  final bool showProgressHeader; // Show progress bar at top
  final bool isPreview; // Preview mode (contractor viewing as client) - disables actions
  final bool showAmounts; // Show dollar amounts on milestones (false for foreman/worker)
  final Function(String milestoneId, String milestoneName)? onAddPhotoUpdate; // Callback for photo upload

  const ProjectTimelineDesign3({
    super.key,
    required this.projectId,
    required this.projectData,
    required this.userRole,
    this.showProgressHeader = true,
    this.isPreview = false,
    this.showAmounts = true,
    this.onAddPhotoUpdate,
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
      // Get milestone name for notification
      final milestoneDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('milestones')
          .doc(milestoneId)
          .get();
      final milestoneName = milestoneDoc.data()?['name'] as String? ?? 'Milestone';

      await MilestoneRecord.updateMilestone(projectId, milestoneId, {
        'status': 'in_progress',
        'started_at': FieldValue.serverTimestamp(),
      });

      // Notify client that milestone has started
      NotificationService.sendMilestoneStartedNotification(
        projectId: projectId,
        projectName: projectData['project_name'] as String? ?? 'Project',
        milestoneName: milestoneName,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milestone started! Client notified.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
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

  void _addPhotoUpdate(BuildContext context, String milestoneId, String milestoneName) {
    // Trigger photo upload with preselected milestone via callback
    if (onAddPhotoUpdate != null) {
      onAddPhotoUpdate!(milestoneId, milestoneName);
    }
  }

  Future<void> _markComplete(BuildContext context, String milestoneId, String milestoneName) async {
    try {
      await MilestoneRecord.updateMilestone(projectId, milestoneId, {
        'status': 'awaiting_approval',
        'marked_complete_at': FieldValue.serverTimestamp(),
      });

      // Notify client about milestone completion
      NotificationService.sendMilestoneNotification(
        projectId: projectId,
        projectName: projectData['project_name'] ?? 'Project',
        milestoneName: milestoneName,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Milestone completed! Client notified.'),
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

  Future<void> _approveMilestone(BuildContext context, String milestoneId, String milestoneName, double milestoneAmount) async {
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
      ScaffoldMessenger.of(context).clearSnackBars(); // Clear any existing snackbars first
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
          duration: Duration(seconds: 5), // Reduced from 30 to 5 seconds
        ),
      );
    }

    try {
      debugPrint('Approving milestone: $milestoneId');

      await MilestoneRecord.updateMilestone(projectId, milestoneId, {
        'status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
      });

      debugPrint('Milestone status updated successfully');

      // Generate invoice for the approved milestone
      try {
        debugPrint('=== INVOICE GENERATION START ===');
        debugPrint('Project ID: $projectId');
        debugPrint('Milestone ID: $milestoneId');
        debugPrint('Milestone Name: $milestoneName');
        debugPrint('Milestone Amount: \$${milestoneAmount.toStringAsFixed(2)}');
        debugPrint('Project Data Keys: ${projectData.keys.join(', ')}');
        debugPrint('Project Name: ${projectData['project_name']}');
        debugPrint('Contractor Business: ${projectData['contractor_business_name']}');
        debugPrint('Client Name: ${projectData['client_name']}');
        debugPrint('Client Email: ${projectData['client_email']}');

        await InvoiceService.generateAndSave(
          projectId: projectId,
          milestoneId: milestoneId,
          milestoneName: milestoneName,
          milestoneAmount: milestoneAmount,
          projectData: projectData,
        );

        debugPrint('✅ Invoice generated successfully');
      } catch (invoiceError, stackTrace) {
        debugPrint('❌ INVOICE GENERATION FAILED');
        debugPrint('Error: $invoiceError');
        debugPrint('Stack trace: $stackTrace');

        // Show error to user via long-lasting snackbar
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ Invoice Generation Failed',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Error: $invoiceError'),
                  const SizedBox(height: 8),
                  const Text(
                    'Milestone approved, but invoice not created. Check debug logs.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: Colors.orange[900],
              duration: const Duration(seconds: 15),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }

      final projectName = projectData['project_name'] as String? ?? 'Project';
      debugPrint('Sending notifications...');

      // Notify contractor that milestone was approved
      NotificationService.sendMilestoneApprovedNotification(
        projectId: projectId,
        projectName: projectName,
        milestoneName: milestoneName,
      );

      // Notify client that payment was processed
      NotificationService.sendPaymentProcessedNotification(
        projectId: projectId,
        projectName: projectName,
        milestoneName: milestoneName,
        amount: milestoneAmount,
      );

      debugPrint('Notifications sent');

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Payment approved! Contractor notified.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Done',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Milestone approval error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving milestone: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Segmented progress bar — each milestone is a segment colored by status
  Widget _buildSegmentedBar(List<MilestoneRecord> milestones, {bool darkMode = false}) {
    if (milestones.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: 0,
          minHeight: darkMode ? 12 : 8,
          backgroundColor: darkMode ? Colors.white.withOpacity(0.2) : Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: darkMode ? 12 : 8,
        child: Row(
          children: milestones.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            Color color;
            switch (m.status) {
              case 'approved':
                color = const Color(0xFF10B981); // green
                break;
              case 'in_progress':
                color = const Color(0xFF3B82F6); // blue
                break;
              case 'awaiting_approval':
                color = const Color(0xFFF59E0B); // orange
                break;
              default:
                color = darkMode ? Colors.white.withOpacity(0.15) : Colors.grey[300]!;
            }

            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < milestones.length - 1 ? 2 : 0),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.horizontal(
                    left: i == 0 ? const Radius.circular(8) : Radius.zero,
                    right: i == milestones.length - 1 ? const Radius.circular(8) : Radius.zero,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildProgressBar(List<MilestoneRecord> milestones) {
    final completedCount = milestones.where((m) => m.status == 'approved').length;
    final totalCount = milestones.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    // Design 3 white-card style for team members; dark style for GC/client
    if (!showAmounts) {
      return Container(
        margin: const EdgeInsets.all(16),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Project Phases',
                  style: TextStyle(
                    color: Color(0xFF2D3748),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: progress >= 1.0
                        ? const Color(0xFF10B981)
                        : const Color(0xFF2D3748),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$completedCount of $totalCount milestones complete',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 14),
            _buildSegmentedBar(milestones),
            const SizedBox(height: 10),
            // Legend
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _buildLegendDot(const Color(0xFF10B981), 'Done'),
                _buildLegendDot(const Color(0xFF3B82F6), 'Active'),
                _buildLegendDot(const Color(0xFFF59E0B), 'Review'),
                _buildLegendDot(Colors.grey[300]!, 'Pending'),
              ],
            ),
            if (projectData['estimated_end_date'] != null) ...[
              const SizedBox(height: 10),
              Text(
                'Due: ${DateFormat.yMMMd().format((projectData['estimated_end_date'] as Timestamp).toDate())}',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ],
        ),
      );
    }

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
          _buildSegmentedBar(milestones, darkMode: true),
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

  Widget _buildMilestoneCard(BuildContext context, MilestoneRecord milestone, bool isFirst, bool isLast, int phaseNumber, int totalPhases) {
    final statusColor = _getStatusColor(milestone.status);
    final isCompleted = milestone.status == 'approved';
    final isPending = milestone.status == 'pending';
    final isActive = milestone.status == 'in_progress' || milestone.status == 'awaiting_approval';
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    // Use collapsible widget for completed AND pending milestones
    // Only "in_progress" and "awaiting_approval" are expanded by default
    if (isCompleted || isPending) {
      return _CollapsibleMilestoneCard(
        milestone: milestone,
        isFirst: isFirst,
        isLast: isLast,
        statusColor: statusColor,
        projectId: projectId,
        userRole: userRole,
        isCompleted: isCompleted,
        showAmounts: showAmounts,
        onStartWorking: (userRole == 'contractor' || userRole == 'team_member') && isPending ? () => _startWorking(context, milestone.milestoneId) : null,
        phaseNumber: phaseNumber,
        totalPhases: totalPhases,
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator - simplified (Option B)
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 16), // Top spacing
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isCompleted ? statusColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : (isActive
                          ? Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null),
                ),
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(width: 8),

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
                        if (showAmounts)
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
                    const SizedBox(height: 4),
                    Text(
                      'Phase $phaseNumber of $totalPhases',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
                    if (userRole == 'client' && milestone.status == 'awaiting_approval') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Approving this phase releases ${currencyFormat.format(milestone.amount)} to your contractor',
                                style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                              ),
                            ),
                          ],
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
                            if (showAmounts && milestone.releasedAmount != null) ...[
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 16, color: Colors.orange),
                            const SizedBox(width: 6),
                            Text(
                              userRole == 'client' ? 'Awaiting your approval' : 'Awaiting approval',
                              style: const TextStyle(
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
                      if (milestone.changesRequested)
                        _ChangeRequestWidget(
                          projectId: projectId,
                          milestoneId: milestone.milestoneId,
                          lastChangeRequestAt: milestone.lastChangeRequestAt,
                          userRole: userRole,
                        )
                      else
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
                    // Request Change button for client (moved here from approval section)
                    if (userRole == 'client' && (milestone.status == 'in_progress' || milestone.status == 'awaiting_approval') && !isPreview) ...[
                      const SizedBox(height: 12),
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
                              builder: (context) => ChangeTypeSelectorBottomSheet(
                                projectId: projectId,
                                milestoneId: milestone.milestoneId,
                                milestoneName: milestone.name,
                              ),
                            );
                          },
                          icon: const Icon(Icons.change_circle_outlined, size: 18),
                          label: const Text('Request Change'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.blue[700]!),
                            foregroundColor: Colors.blue[700],
                          ),
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
                    // TODO: Client changes cards removed - will be redesigned in Activity Center overhaul
                    // See CLAUDE.md "Contractor Side Overhaul" section for placement strategy

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
                            // Primary action: Add Photo Update
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _addPhotoUpdate(context, milestone.milestoneId, milestone.name),
                                icon: const Icon(Icons.add_a_photo),
                                label: const Text('Add Photo Update'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
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
                                onPressed: () => _markComplete(context, milestone.milestoneId, milestone.name),
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
                        ),
                    ],
                    if (userRole == 'client' && milestone.status == 'awaiting_approval' && !isPreview) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _approveMilestone(context, milestone.milestoneId, milestone.name, milestone.amount),
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
    // Design 3: Light grey background matching home page
    return Container(
      color: Colors.grey[50],
      child: StreamBuilder<List<MilestoneRecord>>(
      stream: MilestoneRecord.getMilestones(projectId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final milestones = snapshot.data!;

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
              child: _buildMilestoneCard(context, milestone, isFirst, isLast, milestoneIndex + 1, milestones.length),
            );
          },
        );
      },
      ),
    );
  }
}

// Collapsible change request widget
class _ChangeRequestWidget extends StatefulWidget {
  final String projectId;
  final String milestoneId;
  final DateTime? lastChangeRequestAt;
  final String userRole;

  const _ChangeRequestWidget({
    required this.projectId,
    required this.milestoneId,
    this.lastChangeRequestAt,
    required this.userRole,
  });

  @override
  State<_ChangeRequestWidget> createState() => _ChangeRequestWidgetState();
}

class _ChangeRequestWidgetState extends State<_ChangeRequestWidget> {
  bool _isExpanded = false;

  Future<void> _markChangeRequestAsAddressed(String requestId) async {
    try {
      // Update change request status to 'addressed'
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .doc(widget.milestoneId)
          .collection('change_requests')
          .doc(requestId)
          .update({
        'status': 'addressed',
        'addressed_at': FieldValue.serverTimestamp(),
      });

      // Get project name for notification
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();
      final projectData = projectDoc.data();
      final projectName = projectData?['project_name'] as String? ?? 'Project';

      // Get milestone name
      final milestoneDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .doc(widget.milestoneId)
          .get();
      final milestoneData = milestoneDoc.data();
      final milestoneName = milestoneData?['name'] as String? ?? 'milestone';

      // Notify client that their change request was addressed
      NotificationService.sendChangeRequestAddressedNotification(
        projectId: widget.projectId,
        projectName: projectName,
        milestoneName: milestoneName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change request marked as addressed'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userRole == 'client' ? 'You requested changes' : 'Changes requested',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.lastChangeRequestAt != null)
                        Text(
                          DateFormat.yMMMd().format(widget.lastChangeRequestAt!),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.orange,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('milestones')
                .doc(widget.milestoneId)
                .collection('change_requests')
                .orderBy('created_at', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, changeSnapshot) {
              // DEBUG: Check snapshot state
              debugPrint('Change Request Snapshot - hasData: ${changeSnapshot.hasData}, docs count: ${changeSnapshot.data?.docs.length ?? 0}');

              if (!changeSnapshot.hasData || changeSnapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'No feedback available',
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                );
              }

              final requestDoc = changeSnapshot.data!.docs.first;
              final requestData = requestDoc.data() as Map<String, dynamic>;

              // DEBUG: Print the full change request data
              debugPrint('Change Request Data: $requestData');

              // Handle both old field name (dispute_reason) and new (request_text)
              final requestText = (requestData['request_text'] as String?) ??
                                  (requestData['dispute_reason'] as String?) ?? '';
              final requestStatus = requestData['status'] as String? ?? 'pending';
              final requestId = requestDoc.id;

              // DEBUG: Print extracted values
              debugPrint('Request Text: "$requestText" (length: ${requestText.length})');
              debugPrint('Request Status: $requestStatus');
              debugPrint('Request ID: $requestId');

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: requestStatus == 'addressed'
                      ? Colors.green.withOpacity(0.05)
                      : Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: requestStatus == 'addressed'
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          requestStatus == 'addressed' ? Icons.check_circle : Icons.message,
                          size: 14,
                          color: requestStatus == 'addressed' ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.userRole == 'client'
                                ? (requestStatus == 'addressed' ? 'Your feedback (addressed):' : 'Your feedback:')
                                : (requestStatus == 'addressed' ? 'Feedback (addressed):' : 'Feedback:'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        // Show "Mark as Addressed" button for contractors if status is pending
                        if (widget.userRole == 'contractor' && requestStatus == 'pending')
                          TextButton(
                            onPressed: () => _markChangeRequestAsAddressed(requestId),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Mark as Addressed',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      requestText,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: requestStatus == 'addressed' ? Colors.grey[600] : Colors.black87,
                        decoration: requestStatus == 'addressed' ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

// Collapsible milestone card (for completed and pending milestones)
class _CollapsibleMilestoneCard extends StatefulWidget {
  final MilestoneRecord milestone;
  final bool isFirst;
  final bool isLast;
  final Color statusColor;
  final String projectId;
  final String userRole;
  final bool isCompleted;
  final bool showAmounts;
  final VoidCallback? onStartWorking; // For pending milestones
  final int phaseNumber;
  final int totalPhases;

  const _CollapsibleMilestoneCard({
    required this.milestone,
    required this.isFirst,
    required this.isLast,
    required this.statusColor,
    required this.projectId,
    required this.userRole,
    required this.isCompleted,
    this.showAmounts = true,
    this.onStartWorking,
    required this.phaseNumber,
    required this.totalPhases,
  });

  @override
  State<_CollapsibleMilestoneCard> createState() => _CollapsibleMilestoneCardState();
}

class _CollapsibleMilestoneCardState extends State<_CollapsibleMilestoneCard> {
  bool _isExpanded = false;
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator - simplified (Option B)
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 16), // Top spacing
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: widget.isCompleted ? widget.statusColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.statusColor,
                      width: 2,
                    ),
                  ),
                  child: widget.isCompleted
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : Icon(Icons.schedule, size: 10, color: widget.statusColor),
                ),
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Milestone card
          Expanded(
            child: Card(
              margin: EdgeInsets.only(
                bottom: widget.isLast ? 0 : 16,
                top: widget.isFirst ? 0 : 0,
              ),
              elevation: 1,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.milestone.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (widget.showAmounts)
                            Text(
                              currencyFormat.format(widget.milestone.amount),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: widget.statusColor,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Icon(
                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Phase ${widget.phaseNumber} of ${widget.totalPhases}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      if (_isExpanded) ...[
                        if (widget.milestone.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.milestone.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (widget.isCompleted) ...[
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
                                  'Completed ${DateFormat.yMMMd().format(widget.milestone.approvedAt!)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (widget.showAmounts && widget.milestone.releasedAmount != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '• Released: ${currencyFormat.format(widget.milestone.releasedAmount)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ] else ...[
                          // Pending milestone - show Start Working button for contractor
                          if (widget.onStartWorking != null)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: widget.onStartWorking,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Start Working'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.schedule, size: 16, color: Colors.grey),
                                  SizedBox(width: 6),
                                  Text(
                                    'Not started',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        // Show milestone updates only for completed milestones
                        if (widget.isCompleted)
                          StreamBuilder<List<MilestoneUpdateRecord>>(
                            stream: MilestoneUpdateRecord.getUpdates(widget.projectId, widget.milestone.milestoneId),
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
                                  ...updates.map((update) => Container(
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
                                            Text(
                                              DateFormat('MMM d, h:mm a').format(update.postedAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              update.text,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      )),
                                ],
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
