import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Timeline Tab Preview - Shows both List View and Story Mode
class PreviewTimelineTab extends StatefulWidget {
  const PreviewTimelineTab({super.key});

  @override
  State<PreviewTimelineTab> createState() => _PreviewTimelineTabState();
}

class _PreviewTimelineTabState extends State<PreviewTimelineTab> {
  bool _isStoryMode = false;
  String _selectedFilter = 'All';
  int _storyIndex = 0;

  // Sample timeline data
  final List<Map<String, dynamic>> _timelineEvents = [
    {
      'type': 'photo',
      'title': 'Cabinets Installed!',
      'emoji': '🪵',
      'author': 'John',
      'date': 'March 18, 10:05 AM',
      'photoColor': Colors.brown,
    },
    {
      'type': 'milestone',
      'title': 'Framing Milestone',
      'emoji': '💵',
      'subtitle': 'You Approved',
      'amount': '\$5,000',
      'date': 'March 15, 3:42 PM',
    },
    {
      'type': 'photo',
      'title': 'Framing Complete!',
      'emoji': '🔨',
      'author': 'John',
      'date': 'March 15, 2:18 PM',
      'photoColor': Colors.orange,
    },
    {
      'type': 'change_order',
      'title': 'Change Order Approved',
      'emoji': '🔌',
      'subtitle': 'Add outlet in pantry',
      'amount': '+\$150',
      'date': 'March 14, 10:00 AM',
    },
    {
      'type': 'photo',
      'title': 'Framing Day 3',
      'emoji': '🏗️',
      'author': 'John',
      'date': 'March 14, 4:15 PM',
      'photoColor': Colors.orange[300],
    },
    {
      'type': 'milestone',
      'title': 'Demo Milestone',
      'emoji': '💵',
      'subtitle': 'You Approved',
      'amount': '\$4,000',
      'date': 'March 10, 2:00 PM',
    },
    {
      'type': 'photo',
      'title': 'Demo Complete!',
      'emoji': '🧱',
      'author': 'John',
      'date': 'March 8, 5:30 PM',
      'photoColor': Colors.red,
    },
    {
      'type': 'photo',
      'title': 'Demo Day 2',
      'emoji': '⚒️',
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
    return _isStoryMode ? _buildStoryMode() : _buildListView();
  }

  Widget _buildListView() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: [
          // Toggle to Story Mode
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Story Mode',
            onPressed: () {
              setState(() {
                _isStoryMode = true;
                _storyIndex = 0;
              });
            },
          ),
        ],
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

          // Timeline list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _filteredEvents.length,
              itemBuilder: (context, index) {
                final event = _filteredEvents[index];

                if (event['type'] == 'photo') {
                  return _ListPhotoItem(
                    title: event['title'],
                    emoji: event['emoji'],
                    author: event['author'],
                    date: event['date'],
                    photoColor: event['photoColor'],
                  );
                } else if (event['type'] == 'milestone') {
                  return _ListMilestoneItem(
                    title: event['title'],
                    emoji: event['emoji'],
                    subtitle: event['subtitle'],
                    amount: event['amount'],
                    date: event['date'],
                  );
                } else {
                  return _ListChangeOrderItem(
                    title: event['title'],
                    emoji: event['emoji'],
                    subtitle: event['subtitle'],
                    amount: event['amount'],
                    date: event['date'],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryMode() {
    final event = _timelineEvents[_storyIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! < 0) {
            // Swipe up - next
            if (_storyIndex < _timelineEvents.length - 1) {
              setState(() => _storyIndex++);
            }
          } else if (details.primaryVelocity! > 0) {
            // Swipe down - previous
            if (_storyIndex > 0) {
              setState(() => _storyIndex--);
            }
          }
        },
        child: Stack(
          children: [
            // Content
            if (event['type'] == 'photo')
              _StoryPhotoScreen(
                title: event['title'],
                emoji: event['emoji'],
                author: event['author'],
                date: event['date'],
                photoColor: event['photoColor'],
              )
            else if (event['type'] == 'milestone')
              _StoryMilestoneScreen(
                title: event['title'],
                emoji: event['emoji'],
                subtitle: event['subtitle'],
                amount: event['amount'],
                date: event['date'],
              )
            else
              _StoryChangeOrderScreen(
                title: event['title'],
                emoji: event['emoji'],
                subtitle: event['subtitle'],
                amount: event['amount'],
                date: event['date'],
              ),

            // Progress dots at top
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_timelineEvents.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _storyIndex
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                    ),
                  );
                }),
              ),
            ),

            // Exit button
            Positioned(
              top: 44,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() => _isStoryMode = false);
                },
              ),
            ),

            // Position indicator
            Positioned(
              top: 52,
              right: 16,
              child: Text(
                '${_storyIndex + 1}/${_timelineEvents.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[200],
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

// List View Items
class _ListPhotoItem extends StatelessWidget {
  final String title;
  final String emoji;
  final String author;
  final String date;
  final Color photoColor;

  const _ListPhotoItem({
    required this.title,
    required this.emoji,
    required this.author,
    required this.date,
    required this.photoColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          // Large photo
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  'Posted by $author • $date',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
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

class _ListMilestoneItem extends StatelessWidget {
  final String title;
  final String emoji;
  final String subtitle;
  final String amount;
  final String date;

  const _ListMilestoneItem({
    required this.title,
    required this.emoji,
    required this.subtitle,
    required this.amount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!, width: 2),
      ),
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListChangeOrderItem extends StatelessWidget {
  final String title;
  final String emoji;
  final String subtitle;
  final String amount;
  final String date;

  const _ListChangeOrderItem({
    required this.title,
    required this.emoji,
    required this.subtitle,
    required this.amount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!, width: 2),
      ),
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"$subtitle"',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

// Story Mode Screens
class _StoryPhotoScreen extends StatelessWidget {
  final String title;
  final String emoji;
  final String author;
  final String date;
  final Color photoColor;

  const _StoryPhotoScreen({
    required this.title,
    required this.emoji,
    required this.author,
    required this.date,
    required this.photoColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-screen photo
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                photoColor,
                photoColor.withOpacity(0.7),
              ],
            ),
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 120),
            ),
          ),
        ),

        // Gradient overlay at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Posted by $author',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Swipe up for next ↑',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryMilestoneScreen extends StatelessWidget {
  final String title;
  final String emoji;
  final String subtitle;
  final String amount;
  final String date;

  const _StoryMilestoneScreen({
    required this.title,
    required this.emoji,
    required this.subtitle,
    required this.amount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 60),
            ),
            const SizedBox(height: 20),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              amount,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.green[900],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              date,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Swipe up for next ↑',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryChangeOrderScreen extends StatelessWidget {
  final String title;
  final String emoji;
  final String subtitle;
  final String amount;
  final String date;

  const _StoryChangeOrderScreen({
    required this.title,
    required this.emoji,
    required this.subtitle,
    required this.amount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 60),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '"$subtitle"',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              amount,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              date,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Swipe up for next ↑',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
