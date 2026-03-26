import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../components/live_timeline_widget.dart';

/// Enhanced photo timeline with Instagram Stories-style full-screen viewer
class EnhancedPhotoTimeline extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> projectData;
  final bool showAppBar;

  const EnhancedPhotoTimeline({
    super.key,
    required this.projectId,
    required this.projectData,
    this.showAppBar = true,
  });

  @override
  State<EnhancedPhotoTimeline> createState() => _EnhancedPhotoTimelineState();
}

class _EnhancedPhotoTimelineState extends State<EnhancedPhotoTimeline> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAppBar) {
      // Embedded mode: no Scaffold/AppBar
      return Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.primary,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Timeline'),
                Tab(text: 'All Photos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                LiveTimelineWidget(projectId: widget.projectId, projectData: widget.projectData),
                _buildAllPhotosView(),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Timeline'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Timeline'),
            Tab(text: 'All Photos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          LiveTimelineWidget(projectId: widget.projectId, projectData: widget.projectData),
          _buildAllPhotosView(),
        ],
      ),
    );
  }

  Widget _buildMilestoneGroupedView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .orderBy('order')
          .snapshots(),
      builder: (context, milestonesSnapshot) {
        if (milestonesSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!milestonesSnapshot.hasData || milestonesSnapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timeline,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No milestones yet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final milestones = milestonesSnapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: milestones.length,
          itemBuilder: (context, index) {
            final milestone = milestones[index];
            final milestoneData = milestone.data() as Map<String, dynamic>;
            final milestoneTitle = milestoneData['name'] ?? 'Milestone';
            final milestoneStatus = milestoneData['status'] ?? 'not_started';

            return _MilestoneCard(
              projectId: widget.projectId,
              projectData: widget.projectData,
              milestoneRef: milestone.reference,
              milestoneTitle: milestoneTitle,
              milestoneStatus: milestoneStatus,
            );
          },
        );
      },
    );
  }

  Widget _buildAllPhotosView() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('updates')
            .orderBy('created_at', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 100,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No photos yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your contractor hasn\'t posted any updates',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[500],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // On-screen debug info (like dropdown pattern)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Debug Info:',
                            style: TextStyle(fontSize: 10, color: Colors.blue[900], fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Query: projects/${widget.projectId}/updates',
                            style: TextStyle(fontSize: 9, color: Colors.blue[700]),
                          ),
                          Text(
                            'Connection: ${snapshot.connectionState}',
                            style: TextStyle(fontSize: 9, color: Colors.blue[700]),
                          ),
                          Text(
                            'Has data: ${snapshot.hasData}',
                            style: TextStyle(fontSize: 9, color: Colors.blue[700]),
                          ),
                          Text(
                            'Doc count: ${snapshot.data?.docs.length ?? 0}',
                            style: TextStyle(fontSize: 9, color: Colors.blue[700]),
                          ),
                          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty)
                            Text(
                              'First doc: ${snapshot.data!.docs.first.id}',
                              style: TextStyle(fontSize: 9, color: Colors.green[700]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final updates = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1,
            ),
            itemCount: updates.length,
            itemBuilder: (context, index) {
              final update = updates[index].data() as Map<String, dynamic>;
              final photoUrl = update['photo_url'] as String?;
              final createdAt = update['created_at'] as Timestamp?;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StoryStylePhotoViewer(
                        updates: updates,
                        initialIndex: index,
                        projectData: widget.projectData,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        photoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[100],
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[100],
                                  child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey[400]),
                                ),
                              )
                            : Container(
                                color: Colors.grey[100],
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                              ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.5),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                        // Photo number badge
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        // Date badge
                        if (createdAt != null)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatDateShort(createdAt),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }

  String _formatDateShort(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }

/// Instagram Stories-style full-screen photo viewer
class StoryStylePhotoViewer extends StatefulWidget {
  final List<QueryDocumentSnapshot> updates;
  final int initialIndex;
  final Map<String, dynamic> projectData;

  const StoryStylePhotoViewer({
    super.key,
    required this.updates,
    required this.initialIndex,
    required this.projectData,
  });

  @override
  State<StoryStylePhotoViewer> createState() => _StoryStylePhotoViewerState();
}

class _StoryStylePhotoViewerState extends State<StoryStylePhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  int _getDayNumber() {
    final update = widget.updates[_currentIndex].data() as Map<String, dynamic>;
    final createdAt = update['created_at'] as Timestamp?;
    final startDate = (widget.projectData['start_date'] as Timestamp?)?.toDate();

    if (createdAt != null && startDate != null) {
      return createdAt.toDate().difference(startDate).inDays + 1;
    }
    return _currentIndex + 1;
  }

  int _getTotalDays() {
    final startDate = (widget.projectData['start_date'] as Timestamp?)?.toDate();
    final estimatedEnd = (widget.projectData['estimated_end_date'] as Timestamp?)?.toDate();

    if (startDate != null && estimatedEnd != null) {
      return estimatedEnd.difference(startDate).inDays;
    }
    return widget.updates.length;
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.updates[_currentIndex].data() as Map<String, dynamic>;
    final photoUrl = update['photo_url'] as String?;
    final caption = update['caption'] as String?;
    final createdAt = update['created_at'] as Timestamp?;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleUI,
        child: Stack(
          children: [
            // Main photo viewer with tap zones
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: widget.updates.length,
              itemBuilder: (context, index) {
                final update = widget.updates[index].data() as Map<String, dynamic>;
                final photoUrl = update['photo_url'] as String?;

                return GestureDetector(
                  onTapUp: (details) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final tapPosition = details.globalPosition.dx;

                    // Tap left third to go back
                    if (tapPosition < screenWidth / 3 && index > 0) {
                      _navigateToPage(index - 1);
                    }
                    // Tap right third to go forward
                    else if (tapPosition > (screenWidth * 2 / 3) &&
                        index < widget.updates.length - 1) {
                      _navigateToPage(index + 1);
                    }
                  },
                  child: Center(
                    child: photoUrl != null
                        ? Hero(
                            tag: 'photo_$index',
                            child: InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: CachedNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                                ),
                                errorWidget: (context, url, error) => const Icon(
                                  Icons.broken_image, size: 100, color: Colors.white54,
                                ),
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.image,
                            size: 100,
                            color: Colors.white54,
                          ),
                  ),
                );
              },
            ),

            // Top UI overlay
            AnimatedOpacity(
              opacity: _showUI ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top bar with close button, counter, and day progress
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const Spacer(),
                          // Day X of Y indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Day ${_getDayNumber()} of ${_getTotalDays()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Photo counter
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentIndex + 1}/${widget.updates.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Horizontal progress dots (Instagram Stories style)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: List.generate(widget.updates.length, (index) {
                          final isActive = index == _currentIndex;
                          final isPast = index < _currentIndex;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _navigateToPage(index),
                              child: Container(
                                height: 3,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: isPast || isActive
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom caption overlay
            if (caption != null && caption.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showUI ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
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
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (createdAt != null)
                            Text(
                              _formatDate(createdAt),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            caption,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Left/Right navigation indicators (subtle hints)
            if (_showUI)
              Positioned.fill(
                child: IgnorePointer(
                  child: Row(
                    children: [
                      // Left zone indicator
                      if (_currentIndex > 0)
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 16),
                            child: Icon(
                              Icons.chevron_left,
                              color: Colors.white.withOpacity(0.3),
                              size: 40,
                            ),
                          ),
                        )
                      else
                        const Expanded(child: SizedBox()),
                      // Middle zone (no indicator)
                      const Expanded(child: SizedBox()),
                      // Right zone indicator
                      if (_currentIndex < widget.updates.length - 1)
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: Icon(
                              Icons.chevron_right,
                              color: Colors.white.withOpacity(0.3),
                              size: 40,
                            ),
                          ),
                        )
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

/// Card showing a milestone with photo count
class _MilestoneCard extends StatelessWidget {
  final String projectId;
  final Map<String, dynamic> projectData;
  final DocumentReference milestoneRef;
  final String milestoneTitle;
  final String milestoneStatus;

  const _MilestoneCard({
    required this.projectId,
    required this.projectData,
    required this.milestoneRef,
    required this.milestoneTitle,
    required this.milestoneStatus,
  });

  Color _getStatusColor() {
    switch (milestoneStatus) {
      case 'complete':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (milestoneStatus) {
      case 'complete':
        return 'Complete ✓';
      case 'in_progress':
        return 'In Progress';
      default:
        return 'Not Started';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('updates')
          .where('milestone_ref', isEqualTo: milestoneRef)
          .snapshots(),
      builder: (context, updatesSnapshot) {
        // Handle loading state
        if (updatesSnapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    milestoneTitle.toUpperCase(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          );
        }

        // Handle error state
        if (updatesSnapshot.hasError) {
          if (kDebugMode) {
            print('=== MILESTONE QUERY ERROR ===');
            print('Milestone: $milestoneTitle');
            print('Milestone Ref: ${milestoneRef.path}');
            print('ERROR: ${updatesSnapshot.error}');
          }
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestoneTitle.toUpperCase(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading photos: ${updatesSnapshot.error}',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }

        final photoCount = updatesSnapshot.hasData ? updatesSnapshot.data!.docs.length : 0;
        final updates = updatesSnapshot.hasData ? updatesSnapshot.data!.docs : <QueryDocumentSnapshot>[];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: photoCount > 0
                ? () {
                    // Open photo viewer showing only photos from this milestone
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StoryStylePhotoViewer(
                          updates: updates,
                          initialIndex: 0,
                          projectData: projectData,
                        ),
                      ),
                    );
                  }
                : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          milestoneTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getStatusText(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _getStatusColor(),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (photoCount > 0) ...[
                    // Photo grid preview
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: photoCount > 4 ? 4 : photoCount,
                        itemBuilder: (context, index) {
                          if (index == 3 && photoCount > 4) {
                            // Show "+X more" overlay on 4th photo
                            return Container(
                              width: 110,
                              margin: const EdgeInsets.only(right: 10),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: (updates[index].data() as Map<String, dynamic>)['photo_url'] ?? '',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '+${photoCount - 3}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Container(
                            width: 110,
                            margin: const EdgeInsets.only(right: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: (updates[index].data() as Map<String, dynamic>)['photo_url'] ?? '',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[100],
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[100],
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey[400],
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.photo_library, size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Text(
                          '$photoCount photo${photoCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to view timeline',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ] else
                    Text(
                      'No photos yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
