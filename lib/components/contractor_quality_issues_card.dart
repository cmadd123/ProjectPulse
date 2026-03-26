import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../services/notification_service.dart';
import 'debug_console.dart';

/// Card that shows quality issues for a specific milestone (contractor view)
class ContractorQualityIssuesCard extends StatelessWidget {
  final String projectId;
  final String milestoneId;

  const ContractorQualityIssuesCard({
    super.key,
    required this.projectId,
    required this.milestoneId,
  });

  Future<void> _markAsFixed(
    BuildContext context,
    String changeId,
    String projectName,
    String description,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('client_changes')
          .doc(changeId)
          .update({
        'status': 'fixed',
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Send notification to client
      await NotificationService.sendQualityIssueFixedNotification(
        projectId: projectId,
        projectName: projectName,
        description: description,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Marked as fixed. Client notified.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
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
    DebugConsole().log('🔍 QUALITY ISSUES CARD - Building for projectId: $projectId, milestoneId: $milestoneId');

    final milestoneRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('milestones')
        .doc(milestoneId);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('client_changes')
          .where('type', isEqualTo: 'quality_issue')
          .where('milestone_ref', isEqualTo: milestoneRef)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        DebugConsole().log('🔍 QUALITY ISSUES CARD - StreamBuilder state: hasData=${snapshot.hasData}, hasError=${snapshot.hasError}');

        if (snapshot.hasError) {
          DebugConsole().log('❌ QUALITY ISSUES CARD - Query error: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          DebugConsole().log('⏳ QUALITY ISSUES CARD - Loading data...');
          return const SizedBox.shrink();
        }

        final docCount = snapshot.data!.docs.length;
        DebugConsole().log('🔍 QUALITY ISSUES CARD - Found $docCount quality issue(s)');

        if (snapshot.data!.docs.isEmpty) {
          DebugConsole().log('ℹ️ QUALITY ISSUES CARD - No quality issues found, hiding card');
          return const SizedBox.shrink();
        }

        final issues = snapshot.data!.docs;

        // Log each issue's actual status from Firestore
        for (var i = 0; i < issues.length; i++) {
          final data = issues[i].data() as Map<String, dynamic>;
          final status = data['status'];
          final statusStr = status?.toString() ?? 'null';
          DebugConsole().log('🔍 QUALITY ISSUES CARD - Issue $i: status="$statusStr" (length: ${statusStr.length}, equals "pending": ${statusStr == "pending"})');
        }

        final pendingIssues = issues.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status']?.toString() ?? '';
          DebugConsole().log('🔍 QUALITY ISSUES CARD - Filtering doc ${doc.id}: status="$status", matches pending: ${status == "pending"}');
          return status == 'pending';
        }).toList();

        final fixedIssues = issues.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status']?.toString() ?? '';
          return status == 'fixed';
        }).toList();

        DebugConsole().log('✅ QUALITY ISSUES CARD - FINAL: ${pendingIssues.length} pending, ${fixedIssues.length} fixed issues');

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          constraints: const BoxConstraints(maxHeight: 350),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (fixed at top)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.report_problem_outlined,
                      color: Color(0xFFEF4444),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Quality Issues',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    if (pendingIssues.isNotEmpty) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pendingIssues.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pending issues (direct rendering)
                      if (pendingIssues.isNotEmpty) ...[
                        Builder(
                          builder: (context) {
                            DebugConsole().log('🚀 QUALITY ISSUES - About to render ${pendingIssues.length} pending issues');
                            return const SizedBox.shrink();
                          },
                        ),
                        ...pendingIssues.asMap().entries.map((entry) {
                          final index = entry.key;
                          final issue = entry.value;
                          final data = issue.data() as Map<String, dynamic>;
                          final issueStatus = data['status'] ?? 'unknown';
                          final requestText = data['request_text'] ?? 'no text';
                          final preview = requestText.length > 30 ? requestText.substring(0, 30) : requestText;
                          DebugConsole().log('🔍 QUALITY ISSUES - Rendering pending issue #$index: status=$issueStatus, text=$preview...');
                          return _IssueItem(
                            description: data['request_text'] ?? '',
                            photoUrl: data['photo_url'],
                            createdAt: data['created_at'] as Timestamp?,
                            status: 'pending',
                            onMarkAsFixed: () async {
                              DebugConsole().log('🔍 QUALITY ISSUES - "Mark as Fixed" button tapped for issue ${issue.id}');
                              // Get project name
                              final projectDoc = await FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(projectId)
                                  .get();
                              final projectName = projectDoc.data()?['project_name'] ?? 'Project';

                              if (context.mounted) {
                                _markAsFixed(
                                  context,
                                  issue.id,
                                  projectName,
                                  data['request_text'] ?? '',
                                );
                              }
                            },
                          );
                        }),
                      ],

                      // Fixed issues (collapsed)
                      if (fixedIssues.isNotEmpty)
                        ExpansionTile(
                          title: Text(
                            'Fixed (${fixedIssues.length})',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          children: fixedIssues.map((issue) {
                            final data = issue.data() as Map<String, dynamic>;
                            return _IssueItem(
                              description: data['request_text'] ?? '',
                              photoUrl: data['photo_url'],
                              createdAt: data['created_at'] as Timestamp?,
                              status: 'fixed',
                              onMarkAsFixed: null,
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IssueItem extends StatelessWidget {
  final String description;
  final String? photoUrl;
  final Timestamp? createdAt;
  final String status;
  final VoidCallback? onMarkAsFixed;

  const _IssueItem({
    required this.description,
    this.photoUrl,
    this.createdAt,
    required this.status,
    this.onMarkAsFixed,
  });

  @override
  Widget build(BuildContext context) {
    final descPreview = description.length > 20 ? description.substring(0, 20) : description;
    DebugConsole().log('🔍 ISSUE ITEM - Building: status=$status, hasCallback=${onMarkAsFixed != null}, desc=$descPreview...');
    DebugConsole().log('🔍 ISSUE ITEM - Condition check: status=="pending"? ${status == "pending"}, hasCallback? ${onMarkAsFixed != null}');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              color: status == 'fixed' ? Colors.grey[600] : Colors.black87,
              decoration: status == 'fixed' ? TextDecoration.lineThrough : null,
            ),
          ),

          // Photo if available
          if (photoUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                photoUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.error_outline, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Timestamp and action button
          Row(
            children: [
              if (createdAt != null)
                Text(
                  _formatTimestamp(createdAt!),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              const Spacer(),
              Builder(
                builder: (context) {
                  final shouldShowButton = status == 'pending' && onMarkAsFixed != null;
                  DebugConsole().log('🔍 ISSUE ITEM BUTTON CHECK - status="$status", status=="pending": ${status == "pending"}, hasCallback: ${onMarkAsFixed != null}, SHOW BUTTON: $shouldShowButton');

                  if (shouldShowButton) {
                    DebugConsole().log('✅ ISSUE ITEM - Rendering "Mark as Fixed" button NOW');
                    return ElevatedButton.icon(
                      onPressed: onMarkAsFixed,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Mark as Fixed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    );
                  } else {
                    DebugConsole().log('❌ ISSUE ITEM - Button NOT rendered because: status=$status (expected "pending"), hasCallback=${onMarkAsFixed != null}');
                    return const SizedBox.shrink();
                  }
                },
              ),
              if (status == 'fixed')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Fixed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
