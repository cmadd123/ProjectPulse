import 'package:flutter/material.dart';

/// Color-coded segmented progress bar showing milestone statuses
/// Each segment = one milestone, colored by status
class SegmentedProgressBar extends StatelessWidget {
  final List<String> statuses;
  final double height;
  final bool showLegend;

  const SegmentedProgressBar({
    super.key,
    required this.statuses,
    this.height = 8,
    this.showLegend = false,
  });

  static Color colorForStatus(String status) {
    switch (status) {
      case 'approved':
      case 'complete':
        return const Color(0xFF10B981); // Green
      case 'in_progress':
        return const Color(0xFF3B82F6); // Blue
      case 'awaiting_approval':
        return const Color(0xFFF59E0B); // Orange
      case 'pending':
      case 'not_started':
      default:
        return const Color(0xFFE5E7EB); // Grey
    }
  }

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Row(
              children: statuses.asMap().entries.map((entry) {
                final isLast = entry.key == statuses.length - 1;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: isLast ? 0 : 2),
                    color: colorForStatus(entry.value),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (showLegend) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (statuses.any((s) => s == 'approved' || s == 'complete'))
                _legendDot(const Color(0xFF10B981), 'Done'),
              if (statuses.any((s) => s == 'in_progress'))
                _legendDot(const Color(0xFF3B82F6), 'Active'),
              if (statuses.any((s) => s == 'awaiting_approval'))
                _legendDot(const Color(0xFFF59E0B), 'Review'),
              if (statuses.any((s) => s == 'pending' || s == 'not_started'))
                _legendDot(const Color(0xFFE5E7EB), 'Pending'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}
