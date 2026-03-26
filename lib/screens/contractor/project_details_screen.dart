import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'create_change_order_screen.dart';
import 'manage_milestones_screen.dart';
import 'edit_milestones_screen.dart';
import '../shared/project_chat_screen.dart';
import '../client/enhanced_photo_timeline.dart';
import '../../services/notification_service.dart';
import '../../components/project_timeline_widget.dart';
import '../../components/project_timeline_clean.dart';
import '../../services/notification_service.dart';
import '../../components/expenses_tab_widget.dart';
import '../../components/add_expense_bottom_sheet.dart';
import '../../components/documents_tab_widget.dart';
import '../../components/time_tab_widget.dart';
import 'project_team_screen.dart';
import '../client/client_project_timeline.dart';
import '../../services/invoice_service.dart';
import 'debug_tools_screen.dart';
import '../../components/client_changes_activity_widget.dart';
import '../../components/debug_console.dart';

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

      // Smart default: Pre-select the first "in_progress" milestone
      final inProgressMilestones = _milestones.where((m) => m['status'] == 'in_progress').toList();

      if (inProgressMilestones.length == 1) {
        _selectedMilestone = inProgressMilestones[0]['ref'] as DocumentReference;
      } else if (inProgressMilestones.length > 1) {
        _selectedMilestone = inProgressMilestones[0]['ref'] as DocumentReference;
      } else {
        _selectedMilestone = null;
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

  Future<void> _showAssignTeamDialog() async {
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final teamId = (userDoc.data() as Map<String, dynamic>?)?['team_id'] as String?;

    if (teamId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No team found. Set up your team first.')),
        );
      }
      return;
    }

    // Get current assigned members
    final projectDoc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .get();
    final currentAssigned = List<String>.from(
      (projectDoc.data()?['assigned_member_uids'] as List<dynamic>?) ?? [],
    );

    // Get team members (exclude owner)
    final membersSnapshot = await FirebaseFirestore.instance
        .collection('teams')
        .doc(teamId)
        .collection('members')
        .where('status', isEqualTo: 'active')
        .get();

    final members = membersSnapshot.docs
        .where((doc) => doc.data()['role'] != 'owner')
        .map((doc) => {
              'id': doc.id,
              'name': doc.data()['name'] ?? 'Unknown',
              'role': doc.data()['role'] ?? 'worker',
              'user_uid': doc.data()['user_uid'] as String?,
            })
        .where((m) => m['user_uid'] != null) // Only show linked members
        .toList();

    if (members.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active team members. Add members from the Team screen.')),
        );
      }
      return;
    }

    // Track selected UIDs
    final selected = Set<String>.from(currentAssigned);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Assign Team Members'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: members.length,
              itemBuilder: (ctx, index) {
                final member = members[index];
                final uid = member['user_uid'] as String;
                final isSelected = selected.contains(uid);
                final role = member['role'] as String;

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        selected.add(uid);
                      } else {
                        selected.remove(uid);
                      }
                    });
                  },
                  title: Text(member['name'] as String),
                  subtitle: Text(
                    role == 'foreman' ? 'Foreman' : 'Worker',
                    style: TextStyle(
                      color: role == 'foreman' ? Colors.blue : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  secondary: CircleAvatar(
                    backgroundColor: role == 'foreman'
                        ? Colors.blue.withOpacity(0.15)
                        : Colors.green.withOpacity(0.15),
                    child: Icon(
                      role == 'foreman' ? Icons.engineering : Icons.construction,
                      color: role == 'foreman' ? Colors.blue : Colors.green,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('projects')
                    .doc(widget.projectId)
                    .update({'assigned_member_uids': selected.toList()});

                // Notify newly assigned members
                final newlyAssigned = selected.difference(Set<String>.from(currentAssigned));
                final projectName = widget.projectData['project_name'] as String? ?? 'Project';
                for (final uid in newlyAssigned) {
                  NotificationService.sendCrewAssignmentNotification(
                    userUid: uid,
                    projectId: widget.projectId,
                    projectName: projectName,
                  );
                }

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${selected.length} team member${selected.length == 1 ? '' : 's'} assigned'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
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

                              return DropdownButton<DocumentReference?>(
                                value: validValue,
                                isExpanded: true,
                                hint: const Text('Select milestone'),
                                items: allItems,
                                onChanged: (value) {
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
      debugPrint('Photo Upload - User UID: ${user.uid}');
      debugPrint('Photo Upload - Project ID: ${widget.projectId}');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'projects/${widget.projectId}/updates/$timestamp.jpg';
      debugPrint('Photo Upload - Storage path: $fileName');

      String debugLog = '';
      debugLog += 'User UID: ${user.uid}\n';
      debugLog += 'Project ID: ${widget.projectId}\n';
      debugLog += 'Storage path: $fileName\n\n';

      try {
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        debugLog += '✓ Storage reference created\n';
        debugPrint('Photo Upload - Starting Firebase Storage upload...');

        await storageRef.putData(compressedImage);
        debugLog += '✓ Firebase Storage upload SUCCESS\n';
        debugPrint('Photo Upload - Storage upload SUCCESS');

        final downloadUrl = await storageRef.getDownloadURL();
        debugLog += '✓ Download URL obtained\n';
        debugPrint('Photo Upload - Download URL: $downloadUrl');

        // Save update to Firestore
        debugLog += '\nAttempting Firestore write...\n';
        debugPrint('Photo Upload - Starting Firestore document creation...');
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('updates')
            .add({
          'photo_url': downloadUrl,
          'thumbnail_url': downloadUrl, // Use same for now, could create smaller version
          'caption': _captionController.text.trim(),
          'posted_by_ref': FirebaseFirestore.instance.collection('users').doc(user.uid),
          'posted_by_name': user.displayName ?? 'Contractor',
          'posted_by_role': 'contractor',
          'created_at': Timestamp.now(), // Use client timestamp instead of server timestamp to avoid orderBy null issue
          'milestone_ref': _selectedMilestone, // Can be null for "General/Other"
        });
        debugLog += '✓ Firestore document created SUCCESS\n';
        debugPrint('Photo Upload - Firestore document created SUCCESS');
      } catch (uploadError) {
        debugLog += '\n❌ ERROR:\n$uploadError\n';
        debugPrint('Photo Upload - ERROR at upload stage: $uploadError');

        // Show debug dialog
        if (mounted) {
          setState(() => _isUploading = false);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Photo Upload Debug'),
              content: SingleChildScrollView(
                child: SelectableText(
                  debugLog,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
        return;
      }

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
            child: CachedNetworkImage(
              imageUrl: data['photo_url'] ?? '',
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) {
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
                      data['posted_by_name'] as String? ?? 'Photo Update',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (data['posted_by_role'] != null && data['posted_by_role'] != 'contractor') ...[
                      const SizedBox(width: 4),
                      Text(
                        data['posted_by_role'] == 'foreman' ? 'Foreman' : 'Worker',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
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

      // Notify client that project is complete and request review
      final projectName = widget.projectData['project_name'] as String? ?? 'Project';
      NotificationService.sendProjectCompletedNotification(
        projectId: widget.projectId,
        projectName: projectName,
      );

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

  void _showDeleteProjectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
          'Are you sure you want to delete "${widget.projectData['project_name']}"?\n\n'
          'This will permanently remove the project and all its milestones, updates, '
          'change orders, and messages. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _deleteProject();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignSubsDialog() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final teamId = userDoc.data()?['team_id'] as String?;
      if (teamId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No team found. Create a team first.')),
          );
        }
        return;
      }

      final subsSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('subcontractors')
          .where('status', isEqualTo: 'active')
          .get();

      if (subsSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No subcontractors yet. Add some in My Team.')),
          );
        }
        return;
      }

      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();
      final currentAssigned = List<String>.from(
          (projectDoc.data()?['assigned_sub_ids'] as List<dynamic>?) ?? []);

      final selectedIds = Set<String>.from(currentAssigned);

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Assign Subcontractors'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: subsSnapshot.docs.map((doc) {
                  final data = doc.data();
                  final companyName = data['company_name'] as String? ?? '';
                  final trade = data['trade'] as String? ?? 'other';
                  final isSelected = selectedIds.contains(doc.id);

                  return CheckboxListTile(
                    title: Text(companyName),
                    subtitle: Text(trade[0].toUpperCase() + trade.substring(1)),
                    value: isSelected,
                    onChanged: (checked) {
                      setDialogState(() {
                        if (checked == true) {
                          selectedIds.add(doc.id);
                        } else {
                          selectedIds.remove(doc.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('projects')
                      .doc(widget.projectId)
                      .update({'assigned_sub_ids': selectedIds.toList()});
                  if (context.mounted) Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Subcontractors updated!')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteProject() async {
    try {
      final projectRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId);

      // Delete subcollections
      final subcollections = ['milestones', 'updates', 'change_orders', 'messages', 'expenses', 'documents', 'time_entries'];
      for (final subcollection in subcollections) {
        final docs = await projectRef.collection(subcollection).get();
        for (final doc in docs.docs) {
          // For milestones, also delete their change_requests subcollection
          if (subcollection == 'milestones') {
            final changeRequests = await doc.reference.collection('change_requests').get();
            for (final cr in changeRequests.docs) {
              await cr.reference.delete();
            }
          }
          await doc.reference.delete();
        }
      }

      // Delete the project document itself
      await projectRef.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project deleted'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context); // Go back to project list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting project: $e')),
        );
      }
    }
  }

  Widget _buildInvoicesTab() {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('invoices')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final invoices = snapshot.data?.docs ?? [];

        if (invoices.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No invoices yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  Text(
                    'Invoices are generated automatically when a client approves a milestone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invoices.length,
          itemBuilder: (context, index) {
            final data = invoices[index].data() as Map<String, dynamic>;
            final invoiceId = invoices[index].id;
            final status = data['status'] as String? ?? 'sent';
            final amount = (data['amount'] as num?)?.toDouble() ?? 0;
            final totalDue = (data['total_due'] as num?)?.toDouble() ?? amount;
            final milestoneName = data['milestone_name'] as String? ?? '';
            final invoiceNumber = data['invoice_number'] as String? ?? '';
            final createdAt = (data['created_at'] as Timestamp?)?.toDate();
            final paidAt = (data['paid_at'] as Timestamp?)?.toDate();
            final pdfUrl = data['pdf_url'] as String?;
            final isPaid = status == 'paid';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            invoiceNumber,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPaid ? Colors.green[50] : Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isPaid ? 'Paid' : 'Sent',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isPaid ? Colors.green[700] : Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(milestoneName, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          currencyFormat.format(totalDue),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (createdAt != null)
                          Text(
                            DateFormat('MMM d, yyyy').format(createdAt),
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                      ],
                    ),
                    if (isPaid && paidAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Paid on ${DateFormat('MMM d, yyyy').format(paidAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.green[600]),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (pdfUrl != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Downloading...'), duration: Duration(seconds: 1)),
                                  );
                                  final ref = FirebaseStorage.instance.refFromURL(pdfUrl);
                                  final bytes = await ref.getData();
                                  if (bytes == null) throw Exception('Download failed');
                                  final dir = await getTemporaryDirectory();
                                  final file = File('${dir.path}/$invoiceNumber.pdf');
                                  await file.writeAsBytes(bytes);
                                  await Share.shareXFiles(
                                    [XFile(file.path, mimeType: 'application/pdf')],
                                    subject: 'Invoice $invoiceNumber',
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Download'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        if (pdfUrl != null)
                          const SizedBox(width: 8),
                        if (pdfUrl != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await Share.share(
                                  'Invoice $invoiceNumber\n$pdfUrl',
                                  subject: 'Invoice $invoiceNumber',
                                );
                              },
                              icon: const Icon(Icons.share, size: 16),
                              label: const Text('Share'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        if (pdfUrl != null && !isPaid)
                          const SizedBox(width: 8),
                        if (!isPaid)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Mark as Paid?'),
                                    content: Text('Mark invoice $invoiceNumber as paid?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                        child: const Text('Mark Paid'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await InvoiceService.markAsPaid(widget.projectId, invoiceId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Invoice marked as paid!'), backgroundColor: Colors.green),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Mark Paid'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      extendBody: false,
      appBar: AppBar(
        title: Text(widget.projectData['project_name'] ?? 'Project'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Share invite button (primary action)
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Project Link',
            onPressed: () => _shareProjectInvite(context),
          ),
          // Overflow menu with all other actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More Options',
            onSelected: (value) {
              if (value == 'client_view') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClientProjectTimeline(
                      projectId: widget.projectId,
                      projectData: widget.projectData,
                      isPreview: true,
                    ),
                  ),
                );
              } else if (value == 'gallery') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EnhancedPhotoTimeline(
                      projectId: widget.projectId,
                      projectData: widget.projectData,
                    ),
                  ),
                );
              } else if (value == 'chat') {
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
              } else if (value == 'client_requests') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Client Requests'),
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                      ),
                      body: ClientChangesActivityWidget(
                        projectId: widget.projectId,
                        userRole: 'contractor',
                      ),
                    ),
                  ),
                );
              } else if (value == 'manage_team') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectTeamScreen(
                      projectId: widget.projectId,
                      projectData: widget.projectData,
                    ),
                  ),
                );
              } else if (value == 'change_order') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateChangeOrderScreen(
                      projectId: widget.projectId,
                    ),
                  ),
                );
              } else if (value == 'add_expense') {
                final user = FirebaseAuth.instance.currentUser!;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: AddExpenseBottomSheet(
                      projectId: widget.projectId,
                      enteredByUid: user.uid,
                      enteredByName: user.displayName ?? 'Contractor',
                      enteredByRole: 'contractor',
                    ),
                  ),
                ).then((result) {
                  if (result == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Expense saved!')),
                    );
                  }
                });
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
              } else if (value == 'debug') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DebugToolsScreen(),
                  ),
                );
              } else if (value == 'delete') {
                _showDeleteProjectDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'client_view',
                child: Row(
                  children: [
                    Icon(Icons.visibility),
                    SizedBox(width: 12),
                    Text('Preview Client View'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'gallery',
                child: Row(
                  children: [
                    Icon(Icons.photo_library),
                    SizedBox(width: 12),
                    Text('Gallery View'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'chat',
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline),
                    SizedBox(width: 12),
                    Text('Project Chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'client_requests',
                child: Row(
                  children: [
                    Icon(Icons.list_alt),
                    SizedBox(width: 12),
                    Text('Client Requests'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'manage_team',
                child: Row(
                  children: [
                    Icon(Icons.groups),
                    SizedBox(width: 12),
                    Text('Manage Team'),
                  ],
                ),
              ),
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
                value: 'add_expense',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long),
                    SizedBox(width: 12),
                    Text('Add Expense'),
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
              const PopupMenuDivider(),
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
              const PopupMenuItem(
                value: 'debug',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('Debug Tools'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete Project', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[50], // Light background matching milestone page
        child: Column(
          children: [
            // Project info header - Clean card design
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
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
                  // Client name
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.projectData['client_name'] ?? 'No client',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: widget.projectData['status'] == 'active'
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.projectData['status'] == 'active' ? 'Active' : 'Completed',
                          style: TextStyle(
                            color: widget.projectData['status'] == 'active'
                                ? Colors.blue[700]
                                : Colors.green[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Project total
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Project Total:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(
                          (widget.projectData['current_cost'] ?? widget.projectData['original_cost'] ?? 0) as num,
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  // Assigned crew chips
                  Builder(
                    builder: (context) {
                      final assignedUids = (widget.projectData['assigned_member_uids'] as List?)?.cast<String>() ?? [];
                      if (assignedUids.isEmpty) return const SizedBox.shrink();
                      final teamId = widget.projectData['team_id'] as String?;
                      if (teamId == null) return const SizedBox.shrink();
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('teams')
                            .doc(teamId)
                            .collection('members')
                            .snapshots(),
                        builder: (context, snap) {
                          if (!snap.hasData) return const SizedBox.shrink();
                          final members = snap.data!.docs
                              .where((d) {
                                final data = d.data() as Map<String, dynamic>;
                                final uid = data['user_uid'] as String?;
                                return uid != null && assignedUids.contains(uid);
                              })
                              .map((d) => d.data() as Map<String, dynamic>)
                              .toList();
                          if (members.isEmpty) return const SizedBox.shrink();
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProjectTeamScreen(
                                  projectId: widget.projectId,
                                  projectData: widget.projectData,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.groups, size: 16, color: Colors.grey[500]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: members.map((m) {
                                        final role = m['role'] as String? ?? 'worker';
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: role == 'foreman'
                                                ? Colors.blue.withOpacity(0.1)
                                                : Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${m['name'] ?? 'Unknown'}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: role == 'foreman' ? Colors.blue[700] : Colors.green[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // Timeline View with Activity Tab
            Expanded(
              child: DefaultTabController(
                length: 6,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.center,
                        labelColor: Colors.blue[700],
                        unselectedLabelColor: Colors.grey[600],
                        indicatorColor: Colors.blue[700],
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                        tabs: const [
                          Tab(text: 'Milestones'),
                          Tab(text: 'Activity'),
                          Tab(text: 'Expenses'),
                          Tab(text: 'Docs'),
                          Tab(text: 'Time'),
                          Tab(text: 'Invoices'),
                        ],
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Milestones (Clean design)
                        ProjectTimelineClean(
                          projectId: widget.projectId,
                          projectData: widget.projectData,
                          userRole: 'contractor',
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
                        // Tab 3: Expenses
                        ExpensesTabWidget(
                          projectId: widget.projectId,
                          canAddExpense: true,
                          currentUserUid: FirebaseAuth.instance.currentUser?.uid,
                          currentUserName: FirebaseAuth.instance.currentUser?.displayName ?? 'Contractor',
                          currentUserRole: 'contractor',
                        ),
                        // Tab 4: Documents
                        DocumentsTabWidget(
                          projectId: widget.projectId,
                          canManage: true,
                          currentUserUid: FirebaseAuth.instance.currentUser?.uid,
                          currentUserName: FirebaseAuth.instance.currentUser?.displayName ?? 'Contractor',
                          currentUserRole: 'contractor',
                          teamId: widget.projectData['team_id'] as String?,
                        ),
                        // Tab 5: Time
                        TimeTabWidget(
                          projectId: widget.projectId,
                          canLogTime: true,
                          currentUserUid: FirebaseAuth.instance.currentUser?.uid,
                          currentUserName: FirebaseAuth.instance.currentUser?.displayName ?? 'Contractor',
                          currentUserRole: 'contractor',
                          teamId: widget.projectData['team_id'] as String?,
                        ),
                        // Tab 6: Invoices
                        _buildInvoicesTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ), // Close Container
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
        ],
      ),
          */
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DebugConsoleButton(),
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
