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
import '../../components/time_tab_widget.dart';
import '../../components/documents_tab_widget.dart';
import '../shared/project_chat_design3.dart';

/// Subcontractor project view — Design 3 style
/// Tabs: Milestones (read-only), Activity, Chat, Docs, Time
class SubcontractorProjectScreen extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> projectData;

  const SubcontractorProjectScreen({
    super.key,
    required this.projectId,
    required this.projectData,
  });

  @override
  State<SubcontractorProjectScreen> createState() =>
      _SubcontractorProjectScreenState();
}

class _SubcontractorProjectScreenState
    extends State<SubcontractorProjectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _captionController = TextEditingController();
  bool _isUploading = false;
  File? _selectedImage;

  static const _tabs = [
    _TabDef('Milestones', Icons.flag_outlined),
    _TabDef('Activity', Icons.timeline),
    _TabDef('Chat', Icons.chat_bubble_outline),
    _TabDef('Docs', Icons.folder_outlined),
    _TabDef('Time', Icons.schedule_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _captionController.dispose();
    super.dispose();
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
      _showPostUpdateSheet();
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
      _showPostUpdateSheet();
    }
  }

  void _showPostUpdateSheet() {
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
                    const Text(
                      'Post Update',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
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
                    hintText: 'Add a caption...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
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
                      backgroundColor: const Color(0xFF2D3748),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
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
                            'Post Update',
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
      final compressedImage = await FlutterImageCompress.compressWithFile(
        _selectedImage!.path,
        quality: 85,
      );
      if (compressedImage == null) throw Exception('Compression failed');

      final user = FirebaseAuth.instance.currentUser!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'projects/${widget.projectId}/updates/$ts.jpg';

      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      await storageRef.putData(compressedImage);
      final downloadUrl = await storageRef.getDownloadURL();

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
        'posted_by_name': user.displayName ?? 'Subcontractor',
        'posted_by_role': 'subcontractor',
        'created_at': Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'updated_at': FieldValue.serverTimestamp()});

      await NotificationService.sendPhotoUpdateNotification(
        projectId: widget.projectId,
        projectName: widget.projectData['project_name'] ?? 'Project',
        caption: _captionController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        setState(() {
          _selectedImage = null;
          _isUploading = false;
        });
        _captionController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Update posted!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.projectData['project_name'] ?? 'Project'),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Project header
          _buildProjectHeader(),

          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF2D3748),
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: const Color(0xFFFF6B35),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: _tabs
                  .map((t) => Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(t.icon, size: 16),
                            const SizedBox(width: 6),
                            Text(t.label),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Milestones (read-only view)
                _buildMilestonesTab(),

                // Activity
                _buildActivityTab(),

                // Chat
                ProjectChatDesign3(
                  projectId: widget.projectId,
                  projectName:
                      widget.projectData['project_name'] ?? 'Project',
                  isContractor: false,
                  embedded: true,
                  emptyStateHint: 'Send a message about this project',
                  inputHint: 'Send a message...',
                ),

                // Docs (read-only)
                DocumentsTabWidget(
                  projectId: widget.projectId,
                  canManage: false,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName ?? 'Subcontractor',
                  currentUserRole: 'subcontractor',
                ),

                // Time
                TimeTabWidget(
                  projectId: widget.projectId,
                  canLogTime: true,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName ?? 'Subcontractor',
                  currentUserRole: 'subcontractor',
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'sub_camera',
            onPressed: _takePicture,
            backgroundColor: const Color(0xFF2D3748),
            foregroundColor: Colors.white,
            child: const Icon(Icons.camera_alt, size: 20),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'sub_gallery',
            onPressed: _pickImage,
            backgroundColor: const Color(0xFFFF6B35),
            foregroundColor: Colors.white,
            child: const Icon(Icons.photo_library, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectHeader() {
    final clientName = widget.projectData['client_name'] ?? '';
    final status = widget.projectData['status'] ?? 'active';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (clientName.isNotEmpty) ...[
            Icon(Icons.person_outline, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text(clientName,
                style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          ],
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'active'
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status == 'active' ? 'Active' : 'Completed',
              style: TextStyle(
                color: status == 'active'
                    ? const Color(0xFF10B981)
                    : Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Read-only milestones tab
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
                Text('No milestones yet',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final completedCount = docs
            .where(
                (d) => (d.data() as Map)['status'] == 'approved')
            .length;
        final progress =
            docs.isNotEmpty ? completedCount / docs.length : 0.0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Progress card
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D3748), Color(0xFF4A5568)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Project Progress',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      Text('${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF6B35)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$completedCount of ${docs.length} milestones complete',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 12),
                  ),
                ],
              ),
            ),

            // Milestone list
            ...docs.map((doc) {
              final m = doc.data() as Map<String, dynamic>;
              final status = m['status'] as String? ?? 'pending';
              final name = m['name'] as String? ?? 'Milestone';

              String emoji;
              Color color;
              String label;
              switch (status) {
                case 'in_progress':
                  emoji = '\u{1F528}';
                  color = const Color(0xFF3B82F6);
                  label = 'In Progress';
                  break;
                case 'awaiting_approval':
                  emoji = '\u{23F3}';
                  color = const Color(0xFFF59E0B);
                  label = 'Awaiting Approval';
                  break;
                case 'approved':
                  emoji = '\u{2705}';
                  color = const Color(0xFF10B981);
                  label = 'Completed';
                  break;
                default:
                  emoji = '\u{23F1}\u{FE0F}';
                  color = Colors.grey;
                  label = 'Not Started';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: status == 'in_progress'
                      ? Border.all(color: color.withOpacity(0.3))
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: status == 'approved'
                                    ? Colors.grey[500]
                                    : const Color(0xFF2D3748),
                                decoration: status == 'approved'
                                    ? TextDecoration.lineThrough
                                    : null,
                              )),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
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

  // Activity tab — photos and milestone events
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.timeline,
                      size: 36, color: Colors.grey[400]),
                ),
                const SizedBox(height: 16),
                Text('No activity yet',
                    style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Post a photo update to get started',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final photoUrl = data['photo_url'] as String?;
            final caption = data['caption'] as String? ?? '';
            final postedBy = data['posted_by_name'] as String? ?? '';
            final createdAt = (data['created_at'] as Timestamp?)?.toDate();

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photoUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 220,
                          color: Colors.grey[100],
                          child: const Center(
                              child: CircularProgressIndicator()),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 220,
                          color: Colors.grey[200],
                          child: const Center(
                              child: Icon(Icons.broken_image, size: 48)),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.camera_alt,
                                size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 6),
                            Text(postedBy,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600)),
                            const Spacer(),
                            if (createdAt != null)
                              Text(
                                _formatTimeAgo(createdAt),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500]),
                              ),
                          ],
                        ),
                        if (caption.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(caption,
                              style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                  color: Color(0xFF2D3748))),
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

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  const _TabDef(this.label, this.icon);
}
