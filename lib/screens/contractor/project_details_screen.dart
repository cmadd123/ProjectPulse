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
import '../client/enhanced_photo_timeline.dart';
import '../../components/project_timeline_widget.dart';
import '../../services/notification_service.dart';

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
  DocumentReference? _selectedMilestone;
  bool _milestonePreselected = false; // Track if milestone was preselected from card button
  List<Map<String, dynamic>> _milestones = [];

  @override
  void initState() {
    super.initState();
    _loadMilestones();
  }

  Future<void> _loadMilestones() async {
    final milestonesSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('milestones')
        .orderBy('order')
        .get();

    setState(() {
      _milestones = milestonesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'ref': doc.reference,
          'name': data['name'] as String? ?? '',
          'status': data['status'] as String? ?? 'not_started',
        };
      }).toList();

      print('DEBUG: Loaded ${_milestones.length} milestones');
      for (var m in _milestones) {
        print('  - ${m['name']}: ${m['status']}');
      }

      // Smart default: Pre-select the first "in_progress" milestone
      final inProgressMilestones = _milestones.where((m) => m['status'] == 'in_progress').toList();
      print('DEBUG: Found ${inProgressMilestones.length} in-progress milestones');

      if (inProgressMilestones.length == 1) {
        _selectedMilestone = inProgressMilestones[0]['ref'] as DocumentReference;
        print('DEBUG: Auto-selected: ${inProgressMilestones[0]['name']}');
      } else if (inProgressMilestones.length > 1) {
        // If multiple in-progress, select the most recently posted to
        // For now, just select the first one (we can enhance this later)
        _selectedMilestone = inProgressMilestones[0]['ref'] as DocumentReference;
        print('DEBUG: Multiple in-progress, selected first: ${inProgressMilestones[0]['name']}');
      } else {
        // No in-progress milestones - reset to null so dropdown shows hint
        _selectedMilestone = null;
        print('DEBUG: No in-progress milestones, dropdown will show all (starting with null)');
      }
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _shareProjectInvite(BuildContext context) {
    final projectName = widget.projectData['project_name'] ?? 'Project';
    final clientName = widget.projectData['client_name'] ?? 'client';

    // Generate deep link using new domain
    final inviteLink = 'https://projectpulsehub.com/join/${widget.projectId}';

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
                      setState(() {
                        _selectedImage = null;
                        _milestonePreselected = false;
                      });
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
              // Milestone selector
              if (_milestones.isEmpty) ...[
                // Show message when no milestones exist
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No milestones set up yet. Photo will be posted as "General".',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Row(
                  children: [
                    Text(
                      'Project Phase *',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${_milestones.length} loaded)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Show read-only field if milestone was preselected from card button
                if (_milestonePreselected)
                  // Wait for milestones to load before showing the selected milestone
                  _milestones.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Loading milestone...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _milestones.firstWhere(
                                    (m) => m['ref'] == _selectedMilestone,
                                    orElse: () => <String, Object>{'name': 'Unknown', 'status': 'pending', 'ref': _selectedMilestone!, 'id': ''},
                                  )['name'] as String,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                // Show dropdown if milestone NOT preselected (FAB flow)
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: Builder(
                            builder: (context) {
                              // Ensure value is either null or exists in the items list
                              final validValue = _selectedMilestone != null &&
                                  _milestones.any((m) => m['ref'] == _selectedMilestone)
                                  ? _selectedMilestone
                                  : null;

                              // Build items list with debugging
                              final inProgressItems = _milestones
                                  .where((m) => m['status'] == 'in_progress')
                                  .map((milestone) => DropdownMenuItem<DocumentReference?>(
                                        value: milestone['ref'],
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${milestone['name']} - Current',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList();

                              final otherItems = _milestones
                                  .where((m) => m['status'] != 'in_progress')
                                  .map((milestone) => DropdownMenuItem<DocumentReference?>(
                                        value: milestone['ref'],
                                        child: Text(milestone['name']),
                                      ))
                                  .toList();

                              final allItems = [
                                ...inProgressItems,
                                ...otherItems,
                                const DropdownMenuItem<DocumentReference?>(
                                  value: null,
                                  child: Text(
                                    'General/Other',
                                    style: TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ];

                              print('DEBUG DROPDOWN: Building dropdown with ${allItems.length} items');
                              print('  - In-progress items: ${inProgressItems.length}');
                              print('  - Other items: ${otherItems.length}');
                              print('  - Selected value: ${validValue?.path ?? "null"}');

                              return DropdownButton<DocumentReference?>(
                                value: validValue,
                                isExpanded: true,
                                hint: const Text('Select milestone'),
                                items: allItems,
                                onChanged: (value) {
                                  print('DEBUG: Dropdown changed to: ${value?.path ?? "null (General/Other)"}');
                                  setState(() {
                                    _selectedMilestone = value;
                                  });
                                },
                              );
                        }
                          ),
                        ),
                      ),
                      if (_milestones.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber, size: 16, color: Colors.orange[800]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No milestones found. Create milestones first.',
                                  style: TextStyle(fontSize: 11, color: Colors.orange[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
              ],
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
      print('DEBUG: Posting update with milestone_ref: ${_selectedMilestone?.path ?? "null (General/Other)"}');

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('updates')
          .add({
        'photo_url': downloadUrl,
        'thumbnail_url': downloadUrl, // Use same for now, could create smaller version
        'caption': _captionController.text.trim(),
        'posted_by_ref': FirebaseFirestore.instance.collection('users').doc(user.uid),
        'created_at': Timestamp.now(), // Use client timestamp instead of server timestamp to avoid orderBy null issue
        'milestone_ref': _selectedMilestone, // Can be null for "General/Other"
      });

      // Update project's updated_at timestamp
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'updated_at': FieldValue.serverTimestamp()});

      // Send push notification to client
      await NotificationService.sendPhotoUpdateNotification(
        projectId: widget.projectId,
        projectName: widget.projectData['project_name'] ?? 'Your Project',
        caption: _captionController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        setState(() {
          _selectedImage = null;
          _isUploading = false;
          _milestonePreselected = false;
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

  // Show photo upload with preselected milestone (triggered from milestone card button)
  Future<void> _showPostUpdateDialogWithMilestone(
    DocumentReference milestoneRef,
    String milestoneName,
  ) async {
    // Pre-select the milestone and mark it as preselected
    setState(() {
      _selectedMilestone = milestoneRef;
      _milestonePreselected = true;
    });

    // Show choice: Gallery or Camera
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Photo Update'),
        content: const Text('Choose photo source:'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
          ),
        ],
      ),
    );

    if (source == null) return;

    // Pick image based on source
    if (source == ImageSource.gallery) {
      await _pickImage();
    } else {
      await _takePicture();
    }
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
            icon: const Icon(Icons.photo_library),
            tooltip: 'Gallery View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EnhancedPhotoTimeline(
                    projectId: widget.projectId,
                    projectData: widget.projectData,
                  ),
                ),
              );
            },
          ),
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
                          onAddPhotoUpdate: (milestoneId, milestoneName) {
                            // Get milestone reference and trigger photo upload
                            final milestoneRef = FirebaseFirestore.instance
                                .collection('projects')
                                .doc(widget.projectId)
                                .collection('milestones')
                                .doc(milestoneId);
                            _showPostUpdateDialogWithMilestone(milestoneRef, milestoneName);
                          },
                        ),
                        // Tab 2: Activity (photos, change orders, milestones) - Nested StreamBuilders
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('projects')
                              .doc(widget.projectId)
                              .collection('updates')
                              .orderBy('created_at', descending: true)
                              .snapshots(),
                          builder: (context, updatesSnapshot) {
                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(widget.projectId)
                                  .collection('change_orders')
                                  .orderBy('requested_at', descending: true)
                                  .snapshots(),
                              builder: (context, ordersSnapshot) {
                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('projects')
                                      .doc(widget.projectId)
                                      .collection('milestones')
                                      .where('is_completed', isEqualTo: true)
                                      .snapshots(),
                                  builder: (context, milestonesSnapshot) {
                                    // Show loading only if all are waiting
                                    if (updatesSnapshot.connectionState == ConnectionState.waiting &&
                                        ordersSnapshot.connectionState == ConnectionState.waiting &&
                                        milestonesSnapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }

                                    final updates = updatesSnapshot.data?.docs ?? [];
                                    final orders = ordersSnapshot.data?.docs ?? [];
                                    final milestones = milestonesSnapshot.data?.docs ?? [];

                                    // Combine all items
                                    final List<Map<String, dynamic>> allItems = [];

                                    // Add photos
                                    for (var doc in updates) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      allItems.add({
                                        'type': 'photo_update',
                                        'id': doc.id,
                                        'data': data,
                                        'timestamp': (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
                                      });
                                    }

                                    // Add change orders
                                    for (var doc in orders) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      allItems.add({
                                        'type': 'change_order',
                                        'id': doc.id,
                                        'data': data,
                                        'timestamp': (data['requested_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
                                      });
                                    }

                                    // Add completed milestones
                                    for (var doc in milestones) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      allItems.add({
                                        'type': 'milestone',
                                        'id': doc.id,
                                        'data': data,
                                        'timestamp': (data['completed_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
                                      });
                                    }

                                    // Sort by timestamp
                                    allItems.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

                                    if (allItems.isEmpty) {
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

                                    return ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: allItems.length,
                                      itemBuilder: (context, index) {
                                        final activity = allItems[index];
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
                                );
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
            foregroundColor: Colors.white,
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'gallery',
            onPressed: _pickImage,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.photo_library),
          ),
        ],
      ),
    );
  }
}
