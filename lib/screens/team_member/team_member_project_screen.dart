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
import '../../components/project_timeline_design3.dart';
import '../shared/project_chat_design3.dart';

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

class _TeamMemberProjectScreenState extends State<TeamMemberProjectScreen>
    with SingleTickerProviderStateMixin {
  final _captionController = TextEditingController();
  bool _isUploading = false;
  File? _selectedImage;
  DocumentReference? _selectedMilestone;
  List<Map<String, dynamic>> _milestones = [];
  late TabController _tabController;

  bool get isForeman => widget.teamRole == 'foreman' || widget.teamRole == 'owner';

  // Tabs: Milestones, Activity, Chat, Change Orders, Expenses*, Docs*, Time
  // * = foreman only
  List<_TabDef> get _tabs {
    return [
      const _TabDef('Milestones', Icons.flag_outlined),
      const _TabDef('Activity', Icons.timeline),
      const _TabDef('Chat', Icons.chat_bubble_outline),
      const _TabDef('Changes', Icons.request_quote_outlined),
      if (isForeman) const _TabDef('Expenses', Icons.receipt_long_outlined),
      if (isForeman) const _TabDef('Docs', Icons.folder_outlined),
      const _TabDef('Time', Icons.schedule_outlined),
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadMilestones();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _tabController.dispose();
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
          final inProgress =
              milestones.where((m) => m['status'] == 'in_progress');
          if (inProgress.isNotEmpty) {
            _selectedMilestone = inProgress.first['ref'] as DocumentReference;
          }
        });
      }
    } catch (_) {}
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
                    hintText:
                        'Add a caption (e.g., "Framing complete on north wall")',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey[700],
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
                                      const Icon(Icons.construction,
                                          size: 16, color: Color(0xFF3B82F6)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${m['name']} - Current',
                                          style: const TextStyle(
                                            color: Color(0xFF3B82F6),
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

      if (compressedImage == null) throw Exception('Image compression failed');

      final user = FirebaseAuth.instance.currentUser!;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'projects/${widget.projectId}/updates/$timestamp.jpg';

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
        'posted_by_name': user.displayName ?? 'Team Member',
        'posted_by_role': widget.teamRole,
        'created_at': Timestamp.now(),
        'milestone_ref': _selectedMilestone,
      });

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'updated_at': FieldValue.serverTimestamp()});

      await NotificationService.sendPhotoUpdateNotification(
        projectId: widget.projectId,
        projectName: widget.projectData['project_name'] ?? 'Your Project',
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
            content: Text('Update posted! Client notified.'),
            backgroundColor: Color(0xFF10B981),
          ),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final tabs = _tabs;

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
          // Project info header — Design 3
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
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 13,
              ),
              tabs: tabs.map((t) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.icon, size: 16),
                    const SizedBox(width: 6),
                    Text(t.label),
                  ],
                ),
              )).toList(),
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Milestones — reuse Design 3 timeline (no dollar amounts for crew)
                ProjectTimelineDesign3(
                  projectId: widget.projectId,
                  projectData: widget.projectData,
                  userRole: isForeman ? 'contractor' : 'team_member',
                  showProgressHeader: true,
                  showAmounts: false,
                  onAddPhotoUpdate: (milestoneId, milestoneName) {
                    // Find the milestone ref and select it before opening photo picker
                    final match = _milestones.where((m) => m['id'] == milestoneId);
                    if (match.isNotEmpty) {
                      _selectedMilestone = match.first['ref'] as DocumentReference;
                    }
                    _showPhotoSourceDialog();
                  },
                ),

                // 2. Activity feed — unified timeline
                _buildActivityTab(),

                // 3. Chat
                ProjectChatDesign3(
                  projectId: widget.projectId,
                  projectName: widget.projectData['project_name'] ?? 'Project',
                  isContractor: false,
                  embedded: true,
                  emptyStateHint: 'Send a message about this project',
                  inputHint: 'Send a message...',
                ),

                // 4. Change Orders
                _buildChangeOrdersTab(),

                // 5. Expenses (foreman only)
                if (isForeman)
                  ExpensesTabWidget(
                    projectId: widget.projectId,
                    canAddExpense: true,
                    currentUserUid: user?.uid,
                    currentUserName: user?.displayName ?? 'Team Member',
                    currentUserRole: widget.teamRole,
                  ),

                // 6. Docs (foreman only)
                if (isForeman)
                  DocumentsTabWidget(
                    projectId: widget.projectId,
                    canManage: true,
                    currentUserUid: user?.uid,
                    currentUserName: user?.displayName ?? 'Team Member',
                    currentUserRole: widget.teamRole,
                  ),

                // 7. Time
                TimeTabWidget(
                  projectId: widget.projectId,
                  canLogTime: true,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName ?? 'Team Member',
                  currentUserRole: widget.teamRole,
                ),
              ],
            ),
          ),
        ],
      ),

      // FAB for camera/gallery
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'camera',
            onPressed: _takePicture,
            backgroundColor: const Color(0xFF2D3748),
            foregroundColor: Colors.white,
            child: const Icon(Icons.camera_alt, size: 20),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'gallery',
            onPressed: _pickImage,
            backgroundColor: const Color(0xFFFF6B35),
            foregroundColor: Colors.white,
            child: const Icon(Icons.photo_library, size: 20),
          ),
        ],
      ),
    );
  }

  void _showPhotoSourceDialog() {
    showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Photo Update'),
        content: const Text('Choose photo source:'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
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
  }

  // ---------------------------------------------------------------------------
  // Project header — Design 3
  // ---------------------------------------------------------------------------
  Widget _buildProjectHeader() {
    final status = widget.projectData['status'] ?? 'active';
    final clientName = widget.projectData['client_name'] ?? 'No client';
    final address = widget.projectData['address'] as String? ?? '';
    final crewCount =
        ((widget.projectData['assigned_member_uids'] as List?)?.length ?? 0);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
        children: [
          Icon(Icons.person_outline, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(
            clientName,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          if (crewCount > 0) ...[
            const SizedBox(width: 16),
            Icon(Icons.groups, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              '$crewCount crew',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
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
          if (address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Expanded(child: Text(address, style: TextStyle(fontSize: 12, color: Colors.grey[500]), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Activity tab — unified feed of photos, milestones, change orders, chat
  // ---------------------------------------------------------------------------
  Widget _buildActivityTab() {
    // Merge updates + milestone changes into a single timeline
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('updates')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, updatesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('milestones')
              .orderBy('order')
              .snapshots(),
          builder: (context, milestonesSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('projects')
                  .doc(widget.projectId)
                  .collection('change_orders')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, changeOrdersSnap) {
                final loading = updatesSnap.connectionState ==
                        ConnectionState.waiting &&
                    !updatesSnap.hasData;

                if (loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Build unified timeline items
                final items = <_TimelineItem>[];

                // Photo updates
                if (updatesSnap.hasData) {
                  for (final doc in updatesSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final createdAt = data['created_at'] as Timestamp?;
                    items.add(_TimelineItem(
                      type: 'photo',
                      data: data,
                      timestamp: createdAt?.toDate() ?? DateTime.now(),
                    ));
                  }
                }

                // Milestone events (started, completed, approved)
                if (milestonesSnap.hasData) {
                  for (final doc in milestonesSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] as String? ?? 'pending';

                    if (data['started_at'] != null) {
                      items.add(_TimelineItem(
                        type: 'milestone_started',
                        data: data,
                        timestamp:
                            (data['started_at'] as Timestamp).toDate(),
                      ));
                    }
                    if (data['marked_complete_at'] != null ||
                        data['completed_at'] != null) {
                      final ts = (data['marked_complete_at'] ??
                          data['completed_at']) as Timestamp;
                      items.add(_TimelineItem(
                        type: 'milestone_completed',
                        data: data,
                        timestamp: ts.toDate(),
                      ));
                    }
                    if (status == 'approved' && data['approved_at'] != null) {
                      items.add(_TimelineItem(
                        type: 'milestone_approved',
                        data: data,
                        timestamp:
                            (data['approved_at'] as Timestamp).toDate(),
                      ));
                    }
                  }
                }

                // Change orders
                if (changeOrdersSnap.hasData) {
                  for (final doc in changeOrdersSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final createdAt = data['created_at'] as Timestamp?;
                    items.add(_TimelineItem(
                      type: 'change_order',
                      data: data,
                      timestamp: createdAt?.toDate() ?? DateTime.now(),
                    ));
                  }
                }

                // Sort by timestamp descending
                items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
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
                          Text(
                            'No activity yet',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Photo updates, milestone changes, and change orders will appear here',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: Colors.grey[500], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _buildTimelineCard(items[index]);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTimelineCard(_TimelineItem item) {
    switch (item.type) {
      case 'photo':
        return _buildPhotoCard(item.data, item.timestamp);
      case 'milestone_started':
        return _buildMilestoneEventCard(
          item.data,
          item.timestamp,
          emoji: '\u{1F528}',
          label: 'Milestone Started',
          color: const Color(0xFF3B82F6),
        );
      case 'milestone_completed':
        return _buildMilestoneEventCard(
          item.data,
          item.timestamp,
          emoji: '\u{2705}',
          label: 'Milestone Completed',
          color: const Color(0xFFF59E0B),
        );
      case 'milestone_approved':
        return _buildMilestoneEventCard(
          item.data,
          item.timestamp,
          emoji: '\u{1F389}',
          label: 'Milestone Approved',
          color: const Color(0xFF10B981),
        );
      case 'change_order':
        return _buildChangeOrderCard(item.data, item.timestamp);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPhotoCard(Map<String, dynamic> data, DateTime timestamp) {
    final photoUrl = data['photo_url'] as String?;
    final caption = data['caption'] as String? ?? '';
    final postedBy = data['posted_by_name'] as String? ?? '';
    final role = data['posted_by_role'] as String? ?? '';
    final roleLabel = role == 'foreman'
        ? 'Foreman'
        : role == 'contractor'
            ? 'GC'
            : 'Worker';

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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: photoUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 220,
                  color: Colors.grey[100],
                  child: const Center(child: CircularProgressIndicator()),
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
                    Text(
                      postedBy.isNotEmpty ? postedBy : 'Photo Update',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (role.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500]),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _formatTimeAgo(timestamp),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
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
                      color: Color(0xFF2D3748),
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

  Widget _buildMilestoneEventCard(
    Map<String, dynamic> data,
    DateTime timestamp, {
    required String emoji,
    required String label,
    required Color color,
  }) {
    final name = data['name'] as String? ?? 'Milestone';
    final amount = data['amount'] as num?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTimeAgo(timestamp),
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeOrderCard(
      Map<String, dynamic> data, DateTime timestamp) {
    final title = data['title'] as String? ?? 'Change Order';
    final status = data['status'] as String? ?? 'pending';
    final amount = data['amount'] as num?;

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'Approved';
        break;
      case 'declined':
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'Declined';
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.request_quote, color: statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change Order',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
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
              ],
            ),
          ),
          Text(
            _formatTimeAgo(timestamp),
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Change Orders tab — list all change orders for this project
  // ---------------------------------------------------------------------------
  Widget _buildChangeOrdersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('change_orders')
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
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.request_quote_outlined,
                        size: 36, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No change orders',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Change orders from the GC will appear here for visibility',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 14),
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
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] as String? ?? 'Change Order';
            final description = data['description'] as String? ?? '';
            final status = data['status'] as String? ?? 'pending';
            final amount = data['amount'] as num?;
            final createdAt = (data['created_at'] as Timestamp?)?.toDate();

            Color statusColor;
            String statusLabel;
            String statusEmoji;
            switch (status) {
              case 'approved':
                statusColor = const Color(0xFF10B981);
                statusLabel = 'Approved';
                statusEmoji = '\u{2705}';
                break;
              case 'declined':
                statusColor = const Color(0xFFEF4444);
                statusLabel = 'Declined';
                statusEmoji = '\u{274C}';
                break;
              default:
                statusColor = const Color(0xFFF59E0B);
                statusLabel = 'Pending';
                statusEmoji = '\u{23F3}';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: statusColor.withOpacity(0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
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
                      Text(statusEmoji,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (createdAt != null)
                        Text(
                          _formatTimeAgo(createdAt),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[400]),
                        ),
                    ],
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

// =============================================================================
// Helper classes
// =============================================================================

class _TabDef {
  final String label;
  final IconData icon;
  const _TabDef(this.label, this.icon);
}

class _TimelineItem {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  const _TimelineItem({
    required this.type,
    required this.data,
    required this.timestamp,
  });
}
