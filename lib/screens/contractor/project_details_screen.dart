import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'create_change_order_screen.dart';
import 'manage_milestones_screen.dart';
import 'edit_milestones_screen.dart';
import '../shared/project_chat_screen.dart';
import '../../components/project_timeline_widget.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> projectData;

  const ProjectDetailsScreen({
    super.key,
    required this.projectId,
    required this.projectData,
  });

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  final _captionController = TextEditingController();
  bool _isUploading = false;
  File? _selectedImage;
  late final Stream<List<Map<String, dynamic>>> _activityStream;

  @override
  void initState() {
    super.initState();
    _activityStream = _getCombinedActivityStream();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _shareProjectInvite(BuildContext context) {
    final projectName = widget.projectData['project_name'] ?? 'Project';
    final clientName = widget.projectData['client_name'] ?? 'client';

    // Generate deep link
    final inviteLink = 'https://projectpulse.app/invite/${widget.projectId}';

    // Share message
    final message = '''
Hey $clientName! 👋

I've created a project for you in ProjectPulse: "$projectName"

Click this link to view real-time updates, photos, and communicate about your project:
$inviteLink

Looking forward to working with you!
''';

    Share.share(
      message,
      subject: 'You\'ve been invited to view your project: $projectName',
    );

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link shared!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      _showPostUpdateDialog();
    }
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      _showPostUpdateDialog();
    }
  }

  void _showPostUpdateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Post Update',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _selectedImage = null);
                      _captionController.clear();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _captionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add a caption (e.g., "Demo complete - ready for electrical")',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _postUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24), // Extra bottom padding
            ],
              ),
            ),
        ),
      ),
    );
  }

  Future<void> _postUpdate() async {
    if (_selectedImage == null) return;

    setState(() => _isUploading = true);

    try {
      // Compress image
      final compressedImage = await FlutterImageCompress.compressWithFile(
        _selectedImage!.path,
        quality: 85,
      );

      if (compressedImage == null) throw Exception('Image compression failed');

      // Upload to Firebase Storage
      final user = FirebaseAuth.instance.currentUser!;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'projects/${widget.projectId}/updates/$timestamp.jpg';

      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      await storageRef.putData(compressedImage);
      final downloadUrl = await storageRef.getDownloadURL();

      // Save update to Firestore
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('updates')
          .add({
        'photo_url': downloadUrl,
        'thumbnail_url': downloadUrl, // Use same for now, could create smaller version
        'caption': _captionController.text.trim(),
        'posted_by_ref': FirebaseFirestore.instance.collection('users').doc(user.uid),
        'created_at': FieldValue.serverTimestamp(),
      });

      // Update project's updated_at timestamp
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'updated_at': FieldValue.serverTimestamp()});

      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        setState(() {
          _selectedImage = null;
          _isUploading = false;
        });
        _captionController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update posted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting update: $e')),
        );
      }
    }
  }

  Stream<List<Map<String, dynamic>>> _getCombinedActivityStream() {
    final updatesStream = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('updates')
        .snapshots();

    final changeOrdersStream = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('change_orders')
        .snapshots();

    final milestonesStream = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('milestones')
        .where('is_completed', isEqualTo: true)
        .snapshots();

    return updatesStream.asyncExpand((updatesSnapshot) async* {
      await for (final changeOrdersSnapshot in changeOrdersStream) {
        await for (final milestonesSnapshot in milestonesStream) {

      final List<Map<String, dynamic>> combined = [];

      // Add photo updates
      for (var doc in updatesSnapshot.docs) {
        final data = doc.data();
        combined.add({
          'type': 'photo_update',
          'id': doc.id,
          'data': data,
          'timestamp': (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        });
      }

      // Add change orders
      for (var doc in changeOrdersSnapshot.docs) {
        final data = doc.data();
        combined.add({
          'type': 'change_order',
          'id': doc.id,
          'data': data,
          'timestamp': (data['requested_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        });
      }

      // Add completed milestones
      for (var doc in milestonesSnapshot.docs) {
        final data = doc.data();
        combined.add({
          'type': 'milestone',
          'id': doc.id,
          'data': data,
          'timestamp': (data['completed_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        });
      }

      // Sort by timestamp (newest first)
      combined.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

      yield combined;
        }
      }
    });
  }

  Widget _buildPhotoUpdateCard(Map<String, dynamic> activity) {
    final data = activity['data'] as Map<String, dynamic>;
    final date = activity['timestamp'] as DateTime;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            child: Image.network(
              data['photo_url'] ?? '',
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 50),
                  ),
                );
              },
            ),
          ),

          // Caption and date
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.photo_camera,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Photo Update',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('MMM d, h:mm a').format(date),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (data['caption'] != null && data['caption'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    data['caption'],
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeOrderCard(Map<String, dynamic> activity) {
    final data = activity['data'] as Map<String, dynamic>;
    final date = activity['timestamp'] as DateTime;
    final status = data['status'] as String;
    final costChange = data['cost_change'] as num;
    final description = data['description'] as String;

    Color statusColor;
    IconData statusIcon;
    if (status == 'approved') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == 'declined') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: status == 'pending' ? Colors.amber[50] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.request_quote,
                  size: 14,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Change Order',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, h:mm a').format(date),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Content
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${costChange >= 0 ? '+' : ''}\$${costChange.abs()}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: costChange >= 0
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneCard(Map<String, dynamic> activity) {
    final data = activity['data'] as Map<String, dynamic>;
    final date = activity['timestamp'] as DateTime;
    final name = data['name'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.flag,
                  size: 14,
                  color: Colors.green[700],
                ),
                const SizedBox(width: 6),
                Text(
                  'Milestone Completed',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, h:mm a').format(date),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Content
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCompleteProjectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Project Complete'),
        content: const Text(
          'Are you sure you want to mark this project as complete? '
          'The client will be notified and prompted to leave a review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _completeProject();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Mark Complete'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeProject() async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({
        'status': 'completed',
        'actual_end_date': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project marked as complete! Client notified.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      extendBody: false,
      appBar: AppBar(
        title: Text(widget.projectData['project_name'] ?? 'Project'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectChatScreen(
                    projectId: widget.projectId,
                    projectName: widget.projectData['project_name'] ?? 'Project',
                    isContractor: true,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'change_order') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateChangeOrderScreen(
                      projectId: widget.projectId,
                    ),
                  ),
                );
              } else if (value == 'milestones') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManageMilestonesScreen(
                      projectId: widget.projectId,
                    ),
                  ),
                );
              } else if (value == 'edit_milestones') {
                final projectCost = (widget.projectData['original_cost'] as num?)?.toDouble() ?? 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditMilestonesScreen(
                      projectId: widget.projectId,
                      projectAmount: projectCost,
                    ),
                  ),
                );
              } else if (value == 'complete') {
                _showCompleteProjectDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'change_order',
                child: Row(
                  children: [
                    Icon(Icons.request_quote),
                    SizedBox(width: 12),
                    Text('Create Change Order'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'milestones',
                child: Row(
                  children: [
                    Icon(Icons.flag),
                    SizedBox(width: 12),
                    Text('Manage Milestones'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit_milestones',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 12),
                    Text('Edit Milestone Structure'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'complete',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Text('Mark Complete'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Project info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.projectData['client_name'] ?? 'No client',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    Text(
                      '\$${widget.projectData['current_cost'] ?? widget.projectData['original_cost'] ?? 0}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.projectData['status'] == 'active' ? 'Active' : 'Completed',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Timeline View with Activity Tab
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      tabs: const [
                        Tab(text: 'Milestones'),
                        Tab(text: 'Activity'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Milestones
                        ProjectTimelineWidget(
                          projectId: widget.projectId,
                          projectData: widget.projectData,
                          userRole: 'contractor',
                          showProgressHeader: true,
                        ),
                        // Tab 2: Activity (photos, change orders)
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _activityStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.photo_library_outlined,
                                        size: 80,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No activity yet',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Post photos and manage change orders',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final activities = snapshot.data!;
                            return ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: activities.length,
                              itemBuilder: (context, index) {
                                final activity = activities[index];
                                switch (activity['type']) {
                                  case 'photo_update':
                                    return _buildPhotoUpdateCard(activity);
                                  case 'change_order':
                                    return _buildChangeOrderCard(activity);
                                  case 'milestone':
                                    return _buildMilestoneCard(activity);
                                  default:
                                    return const SizedBox.shrink();
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // OLD: Unified Activity Timeline (commenting out for now)
          /*
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getCombinedActivityStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timeline,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No activity yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Post photos and manage change orders',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final activities = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    final type = activity['type'] as String;

                    if (type == 'photo_update') {
                      return _buildPhotoUpdateCard(activity);
                    } else if (type == 'change_order') {
                      return _buildChangeOrderCard(activity);
                    } else if (type == 'milestone') {
                      return _buildMilestoneCard(activity);
                    }

                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
          */
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'share',
            onPressed: () => _shareProjectInvite(context),
            backgroundColor: Colors.green,
            tooltip: 'Share Invite Link',
            child: const Icon(Icons.share),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'camera',
            onPressed: _takePicture,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'gallery',
            onPressed: _pickImage,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.photo_library),
          ),
        ],
      ),
    );
  }
}
