import 'package:flutter/material.dart';
import 'preview_home_design1.dart';
import 'preview_home_design2.dart';
import 'preview_home_design3.dart';
import 'preview_timeline_minimal.dart';
import 'preview_timeline_design3.dart';

/// Menu to preview all 3 client home page designs
class DesignPreviewMenu extends StatelessWidget {
  const DesignPreviewMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Home Designs Preview'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose a design to preview:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Design 1
          _DesignCard(
            designNumber: '1',
            title: 'Card-Based Home',
            subtitle: 'Priority Grid',
            description: 'Quick actions front and center with 2x2 grid, minimal scrolling, functional over emotional',
            pros: [
              'Less scrolling (grid is compact)',
              'Quick actions immediately tappable',
              'Contractor info visible without scrolling',
            ],
            cons: [
              'Requires contractor to input "This Week" data',
              'Medium visual impact',
            ],
            color: Colors.orange[100]!,
            icon: Icons.grid_view,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PreviewHomeDesign1()),
              );
            },
          ),

          const SizedBox(height: 16),

          // Design 2
          _DesignCard(
            designNumber: '2',
            title: 'Timeline-Focused Home',
            subtitle: 'Photo Hero',
            description: 'Large hero photo from current milestone, visual-first approach, highest differentiation',
            pros: [
              'Best differentiation (no competitor does this)',
              'High emotional connection (photo hero)',
              'Share-worthy (hero photo is screenshot material)',
            ],
            cons: [
              'Requires contractors to post photos regularly',
              'Needs photo-milestone tagging feature',
            ],
            color: Colors.blue[100]!,
            icon: Icons.photo_library,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PreviewHomeDesign2()),
              );
            },
          ),

          const SizedBox(height: 16),

          // Design 3
          _DesignCard(
            designNumber: '3',
            title: 'Personality Injection',
            subtitle: 'Polished Current',
            description: 'Keep existing vertical layout, add warm language and human touches throughout',
            pros: [
              'Fastest to implement (~1 hour)',
              'Lowest risk (no layout changes)',
              'Works with current data (no dependencies)',
            ],
            cons: [
              'Doesn\'t solve "too vertical" issue',
              'Lower differentiation (just text changes)',
            ],
            color: Colors.green[100]!,
            icon: Icons.format_quote,
            isRecommended: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PreviewHomeDesign3()),
              );
            },
          ),

          const SizedBox(height: 24),

          // Timeline Preview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal[200]!, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timeline, color: Colors.teal[700], size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Timeline Tab Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[900],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Minimal timeline with vertical line and condensed events:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.teal[900],
                  ),
                ),
                const SizedBox(height: 8),
                _TimelineFeature(
                  icon: Icons.timeline,
                  label: 'Timeline Line',
                  description: 'Vertical line down left side with color-coded dots',
                  color: Colors.teal[700]!,
                ),
                _TimelineFeature(
                  icon: Icons.photo_size_select_actual,
                  label: 'Large Photos',
                  description: 'Photos remain 280px height as visual anchors',
                  color: Colors.teal[700]!,
                ),
                _TimelineFeature(
                  icon: Icons.compress,
                  label: 'Condensed Events',
                  description: 'Milestones/changes/chat in compact cards',
                  color: Colors.teal[700]!,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PreviewTimelineMinimal()),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Preview Timeline (Minimal)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Milestone Page Redesign Preview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.deepPurple[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple[200]!, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.list_alt, color: Colors.deepPurple[700], size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Milestone Page Redesign (Option C)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple[900],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Clean cards matching home page aesthetic:',
                  style: TextStyle(fontSize: 14, color: Colors.deepPurple[900]),
                ),
                const SizedBox(height: 8),
                _TimelineFeature(
                  icon: Icons.view_headline,
                  label: 'Header Card',
                  description: 'Progress summary at top (no dark header bar)',
                  color: Colors.deepPurple[700]!,
                ),
                _TimelineFeature(
                  icon: Icons.cleaning_services,
                  label: 'Clean Cards',
                  description: 'White cards with subtle shadows, timeline circles on left',
                  color: Colors.deepPurple[700]!,
                ),
                _TimelineFeature(
                  icon: Icons.circle,
                  label: 'Status Indicators',
                  description: 'Color-coded circles on timeline (green = done, blue = active, grey = pending)',
                  color: Colors.deepPurple[700]!,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PreviewTimelineDesign3()),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Preview Milestone Page Redesign'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

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
                    Icon(Icons.lightbulb, color: Colors.purple[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Recommendation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Start with Design 3 (Personality Injection) for pre-launch:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple[900],
                  ),
                ),
                const SizedBox(height: 8),
                _RecommendationBullet(
                  text: 'Fast to implement (~1 hour)',
                  color: Colors.purple[700]!,
                ),
                _RecommendationBullet(
                  text: 'Low risk (no layout changes)',
                  color: Colors.purple[700]!,
                ),
                _RecommendationBullet(
                  text: 'Adds warmth without complexity',
                  color: Colors.purple[700]!,
                ),
                const SizedBox(height: 12),
                Text(
                  'Post-launch evolution:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple[900],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Validate contractor photo-posting behavior, then evolve to Design 2 (Timeline Hero) for best differentiation.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.purple[800],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignCard extends StatelessWidget {
  final String designNumber;
  final String title;
  final String subtitle;
  final String description;
  final List<String> pros;
  final List<String> cons;
  final Color color;
  final IconData icon;
  final bool isRecommended;
  final VoidCallback onTap;

  const _DesignCard({
    required this.designNumber,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.pros,
    required this.cons,
    required this.color,
    required this.icon,
    this.isRecommended = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRecommended
            ? BorderSide(color: Colors.green[700]!, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(icon, size: 28, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Design $designNumber',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isRecommended) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Recommended',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[900],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _ProsCons(
                label: 'Pros',
                items: pros,
                color: Colors.green[700]!,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 8),
              _ProsCons(
                label: 'Cons',
                items: cons,
                color: Colors.orange[700]!,
                icon: Icons.info_outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProsCons extends StatelessWidget {
  final String label;
  final List<String> items;
  final Color color;
  final IconData icon;

  const _ProsCons({
    required this.label,
    required this.items,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 18, top: 2),
              child: Text(
                '• $item',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  height: 1.3,
                ),
              ),
            )),
      ],
    );
  }
}

class _RecommendationBullet extends StatelessWidget {
  final String text;
  final Color color;

  const _RecommendationBullet({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineFeature extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;

  const _TimelineFeature({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
