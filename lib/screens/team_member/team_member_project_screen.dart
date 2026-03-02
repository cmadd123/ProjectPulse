import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
import '../../components/expenses_tab_widget.dart';
import '../../components/time_tab_widget.dart';
import '../../components/documents_tab_widget.dart';

class TeamMemberProjectScreen extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> projectData;
  final String teamRole;

  const TeamMemberProjectScreen({
    super.key,
    required this.projectId,
    required this.projectData,
    this.teamRole = 'worker',
  });

  @override
  State<TeamMemberProjectScreen> createState() =>
      _TeamMemberProjectScreenState();
}

class _TeamMemberProjectScreenState extends State<TeamMemberProjectScreen> {
  final _captionController = TextEditingController();
  bool _isUploading = false;
  File? _selectedImage;
  DocumentReference? _selectedMilestone;
  List<Map<String, dynamic>> _milestones = [];

  @override
  void initState() {
    super.initState();
    _loadMilestones();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadMilestones() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .orderBy('order')
          .get();

      final milestones = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed',
          'status': data['status'] ?? 'not_started',
          'ref': doc.reference,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _milestones = milestones;
          // Auto-select first in_progress milestone
          final inProgress =
              milestones.where((m) => m['status'] == 'in_progress');
          if (inProgress.isNotEmpty) {
            _selectedMilestone = inProgress.first['ref'] as DocumentReference;
          }
        });
      }
    } catch (_) {
      // Milestones failed to load — UI will show empty state
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
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
      setState(() => _selectedImage = File(pickedFile.path));
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
                    hintText:
                        'Add a caption (e.g., "Framing complete on north wall")',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),
                // Milestone selector
                if (_milestones.isNotEmpty) ...[
                  Text(
                    'Project Phase',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: Builder(builder: (context) {
                        final validValue = _selectedMilestone != null &&
                                _milestones
                                    .any((m) => m['ref'] == _selectedMilestone)
                            ? _selectedMilestone
                            : null;

                        final inProgressItems = _milestones
                            .where((m) => m['status'] == 'in_progress')
                            .map((m) => DropdownMenuItem<DocumentReference?>(
                                  value: m['ref'],
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${m['name']} - Current',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
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
                            .map((m) => DropdownMenuItem<DocumentReference?>(
                                  value: m['ref'],
                                  child: Text(m['name']),
                                ))
                            .toList();

                        return DropdownButton<DocumentReference?>(
                          value: validValue,
                          isExpanded: true,
                          hint: const Text('Select milestone'),
                          items: [
                            ...inProgressItems,
                            ...otherItems,
                            const DropdownMenuItem<DocumentReference?>(
                              value: null,
                              child: Text(
                                'General/Other',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedMilestone = value);
                          },
                        );
                      }),
                    ),
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
                const SizedBox(height: 24),
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
        'thumbnail_url': downloadUrl,
        'caption': _captionController.text.trim(),
        'posted_by_ref':
            FirebaseFirestore.instance.collection('users').doc(user.uid),
        'posted_by_name': user.displayName ?? 'Team Member',
        'posted_by_role': widget.teamRole,
        'created_at': Timestamp.now(),
        'milestone_ref': _selectedMilestone,
      });

      // Update project timestamp
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
        });
        _captionController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update posted!')),
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

  Widget _buildMilestoneAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }

  Future<void> _updateMilestoneStatus(
    DocumentReference milestoneRef,
    String milestoneName,
    String newStatus,
  ) async {
    final actionLabel = newStatus == 'in_progress' ? 'start working on' : 'mark as done';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newStatus == 'in_progress' ? 'Start Milestone' : 'Complete Milestone'),
        content: Text('Are you sure you want to $actionLabel "$milestoneName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'in_progress' ? Colors.blue : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(newStatus == 'in_progress' ? 'Start' : 'Mark Done'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
      };

      if (newStatus == 'in_progress') {
        updateData['started_at'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'awaiting_approval') {
        updateData['completed_at'] = FieldValue.serverTimestamp();
      }

      await milestoneRef.update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'in_progress'
                  ? '"$milestoneName" started'
                  : '"$milestoneName" marked as done — awaiting approval',
            ),
            backgroundColor: newStatus == 'in_progress' ? Colors.blue : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating milestone: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isForeman = widget.teamRole == 'foreman';
    return DefaultTabController(
      length: isForeman ? 5 : 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.projectData['project_name'] ?? 'Project'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Project info header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    widget.projectData['client_name'] ?? 'No client',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (widget.projectData['status'] ?? 'active') == 'active'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (widget.projectData['status'] ?? 'active') == 'active' ? 'Active' : 'Completed',
                      style: TextStyle(
                        color: (widget.projectData['status'] ?? 'active') == 'active'
                            ? Colors.green[700]
                            : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Tab bar
            Container(
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: [
                  const Tab(text: 'Milestones'),
                  const Tab(text: 'Activity'),
                  if (isForeman) const Tab(text: 'Expenses'),
                  if (isForeman) const Tab(text: 'Docs'),
                  const Tab(text: 'Time'),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  _buildMilestonesTab(),
                  _buildActivityTab(),
                  if (isForeman)
                    ExpensesTabWidget(
                      projectId: widget.projectId,
                      canAddExpense: true,
                      currentUserUid: FirebaseAuth.instance.currentUser?.uid,
                      currentUserName: FirebaseAuth.instance.currentUser?.displayName ?? 'Team Member',
                      currentUserRole: widget.teamRole,
                    ),
                  if (isForeman)
                    DocumentsTabWidget(
                      projectId: widget.projectId,
                      canManage: true,
                      currentUserUid: FirebaseAuth.instance.currentUser?.uid,
                      currentUserName: FirebaseAuth.instance.currentUser?.displayName ?? 'Team Member',
                      currentUserRole: widget.teamRole,
                    ),
                  TimeTabWidget(
                    projectId: widget.projectId,
                    canLogTime: true,
                    currentUserUid: FirebaseAuth.instance.currentUser?.uid,
                    currentUserName: FirebaseAuth.instance.currentUser?.displayName ?? 'Team Member',
                    currentUserRole: widget.teamRole,
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'camera',
              onPressed: _takePicture,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.camera_alt),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'gallery',
              onPressed: _pickImage,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.photo_library),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestonesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No milestones yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your GC will set up project milestones',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final completedCount = docs.where((d) =>
            (d.data() as Map<String, dynamic>)['status'] == 'approved').length;
        final progress = docs.isNotEmpty ? completedCount / docs.length : 0.0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Progress summary card
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Project Progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$completedCount of ${docs.length} milestones complete',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Timeline milestones
            ...List.generate(docs.length, (index) {
              final doc = docs[index];
              final milestone = doc.data() as Map<String, dynamic>;
              final status = milestone['status'] ?? 'pending';
              final isLast = index == docs.length - 1;
              final isNotStarted = status == 'pending' || status == 'not_started';

              Color statusColor;
              IconData statusIcon;
              String statusLabel;
              switch (status) {
                case 'in_progress':
                  statusColor = Colors.blue;
                  statusIcon = Icons.play_circle_filled;
                  statusLabel = 'In Progress';
                  break;
                case 'awaiting_approval':
                  statusColor = Colors.orange;
                  statusIcon = Icons.hourglass_bottom;
                  statusLabel = 'Awaiting Approval';
                  break;
                case 'approved':
                  statusColor = Colors.green;
                  statusIcon = Icons.check_circle;
                  statusLabel = 'Completed';
                  break;
                default:
                  statusColor = Colors.grey[400]!;
                  statusIcon = Icons.circle_outlined;
                  statusLabel = 'Not Started';
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline line + dot
                    SizedBox(
                      width: 40,
                      child: Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: status == 'approved'
                                  ? statusColor
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: statusColor, width: 2.5),
                            ),
                            child: Icon(
                              status == 'approved'
                                  ? Icons.check
                                  : (status == 'in_progress'
                                      ? Icons.play_arrow
                                      : null),
                              size: 16,
                              color: status == 'approved'
                                  ? Colors.white
                                  : statusColor,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2.5,
                                color: status == 'approved'
                                    ? Colors.green.withOpacity(0.5)
                                    : Colors.grey[300],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Card content
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: status == 'in_progress'
                              ? Colors.blue.withOpacity(0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: status == 'in_progress'
                                ? Colors.blue.withOpacity(0.3)
                                : Colors.grey[200]!,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    milestone['name'] ?? 'Unnamed',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: status == 'approved'
                                          ? Colors.grey[600]
                                          : Colors.black87,
                                      decoration: status == 'approved'
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Action buttons column
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Foreman: Start Working button for pending/not_started milestones
                                if (widget.teamRole == 'foreman' && isNotStarted)
                                  _buildMilestoneAction(
                                    icon: Icons.play_arrow,
                                    color: Colors.blue,
                                    tooltip: 'Start Working',
                                    onTap: () => _updateMilestoneStatus(
                                      doc.reference,
                                      milestone['name'] ?? 'Unnamed',
                                      'in_progress',
                                    ),
                                  ),
                                // Camera button for in_progress milestones (all roles)
                                if (status == 'in_progress')
                                  _buildMilestoneAction(
                                    icon: Icons.add_a_photo,
                                    color: Theme.of(context).colorScheme.primary,
                                    tooltip: 'Add photo',
                                    onTap: () {
                                      setState(() {
                                        _selectedMilestone = doc.reference;
                                      });
                                      showDialog<ImageSource>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Add Photo Update'),
                                          content: const Text('Choose photo source:'),
                                          actions: [
                                            TextButton.icon(
                                              onPressed: () => Navigator.pop(
                                                  ctx, ImageSource.gallery),
                                              icon: const Icon(Icons.photo_library),
                                              label: const Text('Gallery'),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => Navigator.pop(
                                                  ctx, ImageSource.camera),
                                              icon: const Icon(Icons.camera_alt),
                                              label: const Text('Camera'),
                                            ),
                                          ],
                                        ),
                                      ).then((source) {
                                        if (source == ImageSource.gallery) {
                                          _pickImage();
                                        } else if (source == ImageSource.camera) {
                                          _takePicture();
                                        }
                                      });
                                    },
                                  ),
                                // Foreman: Mark Done button for in_progress milestones
                                if (widget.teamRole == 'foreman' && status == 'in_progress') ...[
                                  const SizedBox(height: 4),
                                  _buildMilestoneAction(
                                    icon: Icons.check,
                                    color: Colors.green,
                                    tooltip: 'Mark Done',
                                    onTap: () => _updateMilestoneStatus(
                                      doc.reference,
                                      milestone['name'] ?? 'Unnamed',
                                      'awaiting_approval',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildActivityTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('updates')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No updates yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the camera button to post your first photo update',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final update = doc.data() as Map<String, dynamic>;
            final createdAt = update['created_at'] as Timestamp?;
            final caption = update['caption'] as String? ?? '';
            final photoUrl = update['photo_url'] as String?;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photoUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 250,
                          color: Colors.grey[100],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 250,
                          color: Colors.grey[200],
                          child: const Center(
                              child: Icon(Icons.broken_image, size: 48)),
                        ),
                      ),
                    ),
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
                              update['posted_by_name'] as String? ?? 'Photo Update',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (update['posted_by_role'] != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                update['posted_by_role'] == 'foreman' ? 'Foreman'
                                  : update['posted_by_role'] == 'contractor' ? 'GC'
                                  : 'Worker',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (createdAt != null)
                              Text(
                                DateFormat('MMM d, h:mm a')
                                    .format(createdAt.toDate()),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                        if (caption.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            caption,
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
          },
        );
      },
    );
  }
}
