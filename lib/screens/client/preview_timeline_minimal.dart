import 'package:flutter/material.dart';
import 'package:projectpulse/utils/construction_emojis.dart';

/// Minimal Timeline with Vertical Line
/// Photos are larger, non-photo events are condensed with timeline line
class PreviewTimelineMinimal extends StatefulWidget {
  const PreviewTimelineMinimal({super.key});

  @override
  State<PreviewTimelineMinimal> createState() => _PreviewTimelineMinimalState();
}

class _PreviewTimelineMinimalState extends State<PreviewTimelineMinimal> {
  String _selectedFilter = 'All';

  // Sample timeline data
  final List<Map<String, dynamic>> _timelineEvents = [
    {
      'type': 'photo',
      'title': 'Cabinets Installed!',
      'emoji': ConstructionEmojis.wood,
      'author': 'John',
      'date': 'March 18, 10:05 AM',
      'photoColor': Colors.brown,
    },
    {
      'type': 'milestone',
      'title': 'Framing',
      'emoji': ConstructionEmojis.moneyBag,
      'subtitle': 'You Approved',
      'amount': '\$5,000',
      'date': 'March 15, 3:42 PM',
    },
    {
      'type': 'photo',
      'title': 'Framing Complete!',
      'emoji': ConstructionEmojis.hammer,
      'author': 'John',
      'date': 'March 15, 2:18 PM',
      'photoColor': Colors.orange,
    },
    {
      'type': 'change_order',
      'title': 'Add outlet in pantry',
      'emoji': ConstructionEmojis.lightning,
      'subtitle': 'You Approved',
      'amount': '+\$150',
      'date': 'March 14, 10:00 AM',
    },
    {
      'type': 'photo',
      'title': 'Framing Day 3',
      'emoji': ConstructionEmojis.crane,
      'author': 'John',
      'date': 'March 14, 4:15 PM',
      'photoColor': Colors.orange[300],
    },
    {
      'type': 'chat',
      'title': 'Cabinets arrive tomorrow!',
      'emoji': ConstructionEmojis.speechBalloon,
      'author': 'John',
      'date': 'March 13, 11:22 AM',
    },
    {
      'type': 'photo',
      'title': 'Framing Day 2',
      'emoji': ConstructionEmojis.hammerAndWrench,
      'author': 'John',
      'date': 'March 12, 2:45 PM',
      'photoColor': Colors.orange[200],
    },
    {
      'type': 'milestone',
      'title': 'Demo',
      'emoji': ConstructionEmojis.moneyBag,
      'subtitle': 'You Approved',
      'amount': '\$4,000',
      'date': 'March 10, 2:00 PM',
    },
    {
      'type': 'photo',
      'title': 'Demo Complete!',
      'emoji': ConstructionEmojis.brick,
      'author': 'John',
      'date': 'March 8, 5:30 PM',
      'photoColor': Colors.red,
    },
    {
      'type': 'photo',
      'title': 'Demo Day 2',
      'emoji': ConstructionEmojis.hammerAndWrench,
      'author': 'John',
      'date': 'March 5, 3:20 PM',
      'photoColor': Colors.red[300],
    },
  ];

  List<Map<String, dynamic>> get _filteredEvents {
    if (_selectedFilter == 'All') return _timelineEvents;
    if (_selectedFilter == 'Photos') {
      return _timelineEvents.where((e) => e['type'] == 'photo').toList();
    }
    if (_selectedFilter == 'Payments') {
      return _timelineEvents.where((e) => e['type'] == 'milestone').toList();
    }
    if (_selectedFilter == 'Changes') {
      return _timelineEvents.where((e) => e['type'] == 'change_order').toList();
    }
    return _timelineEvents;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Timeline'),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _selectedFilter == 'All',
                    onTap: () => setState(() => _selectedFilter = 'All'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Photos',
                    isSelected: _selectedFilter == 'Photos',
                    onTap: () => setState(() => _selectedFilter = 'Photos'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Payments',
                    isSelected: _selectedFilter == 'Payments',
                    onTap: () => setState(() => _selectedFilter = 'Payments'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Changes',
                    isSelected: _selectedFilter == 'Changes',
                    onTap: () => setState(() => _selectedFilter = 'Changes'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Timeline with vertical line
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              itemCount: _filteredEvents.length,
              itemBuilder: (context, index) {
                final event = _filteredEvents[index];
                final isLast = index == _filteredEvents.length - 1;

                return _TimelineItem(
                  event: event,
                  isLast: isLast,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isLast;

  const _TimelineItem({
    required this.event,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final type = event['type'];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line section (left side)
          SizedBox(
            width: 60,
            child: Column(
              children: [
                // Dot
                Container(
                  margin: EdgeInsets.only(top: type == 'photo' ? 140 : 20),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getDotColor(type),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                // Line below (if not last)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey[300],
                    ),
                  ),
              ],
            ),
          ),

          // Content section (right side)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 16),
              child: _buildContent(type),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDotColor(String type) {
    switch (type) {
      case 'photo':
        return Colors.blue[600]!;
      case 'milestone':
        return Colors.green[600]!;
      case 'change_order':
        return Colors.orange[600]!;
      case 'chat':
        return Colors.purple[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildContent(String type) {
    if (type == 'photo') {
      return _PhotoContent(
        title: event['title'],
        emoji: event['emoji'],
        author: event['author'],
        date: event['date'],
        photoColor: event['photoColor'],
      );
    } else if (type == 'milestone') {
      return _MilestoneContent(
        title: event['title'],
        emoji: event['emoji'],
        subtitle: event['subtitle'],
        amount: event['amount'],
        date: event['date'],
      );
    } else if (type == 'change_order') {
      return _ChangeOrderContent(
        title: event['title'],
        emoji: event['emoji'],
        subtitle: event['subtitle'],
        amount: event['amount'],
        date: event['date'],
      );
    } else if (type == 'chat') {
      return _ChatContent(
        title: event['title'],
        emoji: event['emoji'],
        author: event['author'],
        date: event['date'],
      );
    }
    return const SizedBox();
  }
}

class _PhotoContent extends StatelessWidget {
  final String title;
  final String emoji;
  final String author;
  final String date;
  final Color photoColor;

  const _PhotoContent({
    required this.title,
    required this.emoji,
    required this.author,
    required this.date,
    required this.photoColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Large photo
        Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                photoColor,
                photoColor.withOpacity(0.7),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 80),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Posted by $author',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          date,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

class _MilestoneContent extends StatelessWidget {
  final String title;
  final String emoji;
  final String subtitle;
  final String amount;
  final String date;

  const _MilestoneContent({
    required this.title,
    required this.emoji,
    required this.subtitle,
    required this.amount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$title Milestone',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeOrderContent extends StatelessWidget {
  final String title;
  final String emoji;
  final String subtitle;
  final String amount;
  final String date;

  const _ChangeOrderContent({
    required this.title,
    required this.emoji,
    required this.subtitle,
    required this.amount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatContent extends StatelessWidget {
  final String title;
  final String emoji;
  final String author;
  final String date;

  const _ChatContent({
    required this.title,
    required this.emoji,
    required this.author,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$author • $date',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
