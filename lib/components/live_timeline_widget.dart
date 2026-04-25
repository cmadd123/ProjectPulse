import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

/// Live timeline with vertical line — merges photos, milestones, and change orders
/// chronologically from Firestore. Based on PreviewTimelineMinimal design.
class LiveTimelineWidget extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> projectData;

  const LiveTimelineWidget({
    super.key,
    required this.projectId,
    required this.projectData,
  });

  @override
  State<LiveTimelineWidget> createState() => _LiveTimelineWidgetState();
}

class _LiveTimelineWidgetState extends State<LiveTimelineWidget> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Photos', 'Milestones', 'Changes'].map((label) {
                final isSelected = _selectedFilter == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = label),
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
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1),

        // Timeline content
        Expanded(
          child: _buildTimeline(),
        ),
      ],
    );
  }

  Widget _buildTimeline() {
    final projectRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId);

    return StreamBuilder<List<QuerySnapshot>>(
      stream: _mergedStream(projectRef),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No activity yet'));
        }

        // Merge all events into a single sorted list
        final events = <_TimelineEvent>[];

        final snapshots = snapshot.data!;

        // Updates (photos)
        for (final doc in snapshots[0].docs) {
          final data = doc.data() as Map<String, dynamic>;
          events.add(_TimelineEvent(
            type: 'photo',
            title: data['caption'] as String? ?? 'Photo update',
            photoUrl: data['photo_url'] as String?,
            author: data['posted_by_name'] as String? ?? 'Contractor',
            timestamp: data['created_at'] as Timestamp?,
          ));
        }

        // Milestones (only approved/completed ones show as events)
        for (final doc in snapshots[1].docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? '';
          if (status == 'approved' || status == 'completed' || status == 'awaiting_approval') {
            final amount = (data['amount'] as num?)?.toDouble() ?? 0;
            String subtitle;
            if (status == 'approved') {
              subtitle = 'You Approved';
            } else if (status == 'awaiting_approval') {
              subtitle = 'Ready for Approval';
            } else {
              subtitle = 'Completed';
            }
            events.add(_TimelineEvent(
              type: 'milestone',
              title: data['name'] as String? ?? 'Milestone',
              subtitle: subtitle,
              amount: '\$${amount.toStringAsFixed(0)}',
              timestamp: data['approved_at'] as Timestamp? ?? data['created_at'] as Timestamp?,
              status: status,
            ));
          }
        }

        // Change orders (contractor-initiated)
        for (final doc in snapshots[2].docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? 'pending';
          final amount = (data['amount'] as num?)?.toDouble() ?? 0;
          events.add(_TimelineEvent(
            type: 'change_order',
            title: data['title'] as String? ?? 'Change Order',
            subtitle: status == 'approved' ? 'Approved' : status == 'declined' ? 'Declined' : 'Pending',
            amount: '+\$${amount.toStringAsFixed(0)}',
            timestamp: data['approved_at'] as Timestamp? ?? data['created_at'] as Timestamp?,
          ));
        }

        // Client-authored changes (addition requests + quality issues)
        if (snapshots.length > 3) {
          for (final doc in snapshots[3].docs) {
            final data = doc.data() as Map<String, dynamic>;
            final type = (data['type'] as String?) ?? 'addition_request';
            final status = (data['status'] as String?) ?? 'pending';
            final requestText = (data['request_text'] as String?) ?? '';
            final isQualityIssue = type == 'quality_issue';
            final friendlyTitle = isQualityIssue
                ? 'Quality Issue Reported'
                : 'Addition Requested';
            final friendlyStatus = status == 'addressed'
                ? 'Addressed'
                : status == 'approved'
                    ? 'Approved'
                    : status == 'declined'
                        ? 'Declined'
                        : 'Pending';
            // Truncate the body so the timeline card stays compact.
            final preview = requestText.length > 60
                ? '${requestText.substring(0, 60).trim()}…'
                : requestText;
            events.add(_TimelineEvent(
              type: 'client_change',
              title: friendlyTitle,
              subtitle: preview.isNotEmpty
                  ? '$friendlyStatus · $preview'
                  : friendlyStatus,
              amount: '',
              timestamp: data['created_at'] as Timestamp?,
            ));
          }
        }

        // Sort by timestamp descending (newest first)
        events.sort((a, b) {
          final aTime = a.timestamp?.millisecondsSinceEpoch ?? 0;
          final bTime = b.timestamp?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

        // Apply filter. "Changes" lumps both contractor-side change_orders
        // and client-side change requests since users think of them as the
        // same category mentally.
        final filtered = events.where((e) {
          if (_selectedFilter == 'All') return true;
          if (_selectedFilter == 'Photos') return e.type == 'photo';
          if (_selectedFilter == 'Milestones') return e.type == 'milestone';
          if (_selectedFilter == 'Changes') {
            return e.type == 'change_order' || e.type == 'client_change';
          }
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timeline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No activity yet', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 24, bottom: 24),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return _buildTimelineItem(filtered[index], index == filtered.length - 1);
          },
        );
      },
    );
  }

  Stream<List<QuerySnapshot>> _mergedStream(DocumentReference projectRef) {
    // Drive on the updates stream; refetch the others on each tick so we
    // get fresh state for every collection without nesting subscriptions.
    final updatesStream = projectRef.collection('updates')
        .orderBy('created_at', descending: true)
        .snapshots();

    return updatesStream.asyncMap((updates) async {
      final milestones = await projectRef.collection('milestones').orderBy('order').get();
      final changeOrders = await projectRef.collection('change_orders').orderBy('created_at', descending: true).get();
      // Client-authored changes (addition requests + quality issues) are a
      // separate subcollection; pull them in so they show up alongside
      // contractor-side change orders on the timeline.
      final clientChanges = await projectRef.collection('client_changes').get();
      return [updates, milestones, changeOrders, clientChanges];
    });
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }

  Widget _buildTimelineItem(_TimelineEvent event, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 60,
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(top: event.type == 'photo' ? 140 : 20),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getDotColor(event.type),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: Colors.grey[300]),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 16),
              child: _buildEventContent(event),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDotColor(String type) {
    switch (type) {
      case 'photo': return Colors.blue[600]!;
      case 'milestone': return Colors.green[600]!;
      case 'change_order': return Colors.orange[600]!;
      default: return Colors.grey[600]!;
    }
  }

  Widget _buildEventContent(_TimelineEvent event) {
    if (event.type == 'photo') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo
          if (event.photoUrl != null && event.photoUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: event.photoUrl!,
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.photo, size: 48, color: Colors.grey[400]),
                ),
              ),
            )
          else
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(Icons.photo_camera, size: 48, color: Colors.blue[200]),
              ),
            ),
          const SizedBox(height: 12),
          Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Posted by ${event.author}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(_formatDate(event.timestamp), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      );
    } else if (event.type == 'milestone') {
      final borderColor = event.status == 'awaiting_approval' ? Colors.orange[200]! : Colors.green[200]!;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.subtitle ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 2),
                      Text('${event.title} Milestone', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Text(event.amount ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[900])),
              ],
            ),
            const SizedBox(height: 8),
            Text(_formatDate(event.timestamp), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      );
    } else if (event.type == 'change_order') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.subtitle ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 2),
                      Text(event.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Text(event.amount ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[900])),
              ],
            ),
            const SizedBox(height: 8),
            Text(_formatDate(event.timestamp), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      );
    }
    return const SizedBox();
  }
}

class _TimelineEvent {
  final String type;
  final String title;
  final String? subtitle;
  final String? amount;
  final String? photoUrl;
  final String? author;
  final Timestamp? timestamp;
  final String? status;

  _TimelineEvent({
    required this.type,
    required this.title,
    this.subtitle,
    this.amount,
    this.photoUrl,
    this.author,
    this.timestamp,
    this.status,
  });
}
