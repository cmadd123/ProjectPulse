import 'package:flutter/material.dart';

/// Preview of segmented progress bar variations
/// Shows: Equal-width segments vs Proportional segments vs Simple bar
class PreviewTimelineDesign3 extends StatefulWidget {
  const PreviewTimelineDesign3({super.key});

  @override
  State<PreviewTimelineDesign3> createState() => _PreviewTimelineDesign3State();
}

class _PreviewTimelineDesign3State extends State<PreviewTimelineDesign3> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Segmented Progress Bar Preview'),
        backgroundColor: Colors.grey[800],
      ),
      body: Container(
        color: Colors.grey[50],
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Preview label
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Text(
                '📱 PREVIEW: Multi-state progress bars showing milestone statuses',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),

            // Option C1: Equal Width Segments (Recommended)
            Row(
              children: [
                const Text(
                  'Option C1: Equal Width Segments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Recommended',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Each milestone = equal width (easy to count)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            _buildHeaderCardWithEqualSegments(),
            const SizedBox(height: 24),

            // Option C2: Proportional Width Segments
            const Text(
              'Option C2: Proportional Width Segments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Segment width based on milestone cost',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            _buildHeaderCardWithProportionalSegments(),
            const SizedBox(height: 24),

            // Option C3: Simple Progress Bar
            const Text(
              'Option C3: Simple Progress Bar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Single color showing overall completion %',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            _buildHeaderCardWithSimpleBar(),
            const SizedBox(height: 24),

            // Color Legend
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Status Colors',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLegendItem(Colors.green, 'Approved (Completed)'),
                  _buildLegendItem(Colors.blue, 'In Progress (Active)'),
                  _buildLegendItem(Colors.orange, 'Awaiting Approval (Review)'),
                  _buildLegendItem(Colors.grey[300]!, 'Not Started (Pending)'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Comparison notes
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.purple[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Design Analysis',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildComparisonRow('Equal Width', '✓ Easy to count', '✓ Simple', '✓ Clear'),
                  _buildComparisonRow('Proportional', '✓ Shows cost', '? Complex', '✓ Accurate'),
                  _buildComparisonRow('Simple Bar', '✓ Minimal', '✗ No detail', '✓ Clean'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String option, String pro1, String pro2, String pro3) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              option,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              '$pro1 • $pro2 • $pro3',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  // Option C1: Equal Width Segments (Recommended)
  // Each milestone gets 25% width, colored by status
  Widget _buildHeaderCardWithEqualSegments() {
    return Container(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Phases',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1 approved, 1 in progress, 1 awaiting approval, 1 not started',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Project Total: \$16,000',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '25%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          // Segmented progress bar - Equal width
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(child: Container(height: 6, color: Colors.green)), // Approved
                Expanded(child: Container(height: 6, color: Colors.blue)), // In Progress
                Expanded(child: Container(height: 6, color: Colors.orange)), // Awaiting Approval
                Expanded(child: Container(height: 6, color: Colors.grey[300])), // Not Started
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Option C2: Proportional Width Segments
  // Segment width based on milestone cost
  Widget _buildHeaderCardWithProportionalSegments() {
    // Mock data: Foundation=$6k, Electrical=$4k, Plumbing=$4k, Finishes=$2k
    const segment1Width = 0.375; // $6k / $16k = 37.5%
    const segment2Width = 0.25;  // $4k / $16k = 25%
    const segment3Width = 0.25;  // $4k / $16k = 25%
    const segment4Width = 0.125; // $2k / $16k = 12.5%

    return Container(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Phases',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$6k approved, \$4k in progress, \$4k awaiting, \$2k pending',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Project Total: \$16,000',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '37.5%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          // Segmented progress bar - Proportional width
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(flex: (segment1Width * 100).round(), child: Container(height: 6, color: Colors.green)),
                Expanded(flex: (segment2Width * 100).round(), child: Container(height: 6, color: Colors.blue)),
                Expanded(flex: (segment3Width * 100).round(), child: Container(height: 6, color: Colors.orange)),
                Expanded(flex: (segment4Width * 100).round(), child: Container(height: 6, color: Colors.grey[300])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Option C3: Simple Progress Bar
  // Single color showing overall completion percentage
  Widget _buildHeaderCardWithSimpleBar() {
    const progress = 0.25; // 25% (1 of 4 approved)

    return Container(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Phases',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1 of 4 milestones completed',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Project Total: \$16,000',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '25%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          // Simple progress bar
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
