import 'package:flutter/material.dart';
import 'quality_issue_form_bottom_sheet.dart';
import 'addition_request_form_bottom_sheet.dart';

/// Bottom sheet that lets client choose between Quality Issue or Addition Request
class ChangeTypeSelectorBottomSheet extends StatelessWidget {
  final String projectId;
  final String milestoneId;
  final String milestoneName;

  const ChangeTypeSelectorBottomSheet({
    super.key,
    required this.projectId,
    required this.milestoneId,
    required this.milestoneName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.change_circle_outlined,
                size: 28,
                color: Color(0xFF6366F1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request Change',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      milestoneName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Instruction text
          Text(
            'What type of change?',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          // Quality Issue card
          _ChangeTypeCard(
            icon: Icons.report_problem_outlined,
            iconColor: const Color(0xFFEF4444),
            iconBackgroundColor: const Color(0xFFFEE2E2),
            title: 'Report Quality Issue',
            subtitle: 'Something needs fixing (no extra cost)',
            example: 'e.g., crooked tile, paint overspray, missing outlet',
            onTap: () async {
              Navigator.pop(context);
              final result = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => QualityIssueFormBottomSheet(
                  projectId: projectId,
                  milestoneId: milestoneId,
                  milestoneName: milestoneName,
                ),
              );

              // Show success message after bottom sheet closes
              if (result == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Issue reported! Contractor notified.'),
                    backgroundColor: Color(0xFF10B981), // Green
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 12),

          // Addition Request card
          _ChangeTypeCard(
            icon: Icons.add_circle_outline,
            iconColor: const Color(0xFF3B82F6),
            iconBackgroundColor: const Color(0xFFDBEAFE),
            title: 'Request Addition',
            subtitle: 'New work not in original plan (will be quoted)',
            example: 'e.g., add outlet in pantry, extra shelving',
            onTap: () async {
              Navigator.pop(context);
              final result = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => AdditionRequestFormBottomSheet(
                  projectId: projectId,
                  milestoneId: milestoneId,
                  milestoneName: milestoneName,
                ),
              );

              // Show success message after bottom sheet closes
              if (result == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Request submitted! Contractor notified.'),
                    backgroundColor: Color(0xFF10B981), // Green
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 12),

          // Help text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Not sure? Quality issues are free fixes, additions will be quoted.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ChangeTypeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String subtitle;
  final String example;
  final VoidCallback onTap;

  const _ChangeTypeCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    required this.subtitle,
    required this.example,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 26,
                ),
              ),

              const SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      example,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
