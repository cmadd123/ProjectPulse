import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManageMilestonesScreen extends StatefulWidget {
  final String projectId;

  const ManageMilestonesScreen({
    super.key,
    required this.projectId,
  });

  @override
  State<ManageMilestonesScreen> createState() => _ManageMilestonesScreenState();
}

class _ManageMilestonesScreenState extends State<ManageMilestonesScreen> {
  final _nameController = TextEditingController();
  bool _isAdding = false;

  // Project-specific milestone templates
  final Map<String, List<String>> _projectTemplates = {
    'Kitchen Remodel': [
      'Demolition',
      'Plumbing Rough-In',
      'Electrical Rough-In',
      'Drywall & Patching',
      'Cabinet Installation',
      'Countertop Installation',
      'Backsplash',
      'Appliance Installation',
      'Final Plumbing & Electrical',
      'Final Walkthrough',
    ],
    'Bathroom Remodel': [
      'Demolition',
      'Plumbing Rough-In',
      'Electrical Rough-In',
      'Tile Work',
      'Vanity Installation',
      'Toilet & Fixtures',
      'Shower/Tub Installation',
      'Painting',
      'Final Walkthrough',
    ],
    'Room Addition': [
      'Site Preparation',
      'Foundation',
      'Framing',
      'Roof Installation',
      'Windows & Doors',
      'Electrical Rough-In',
      'Plumbing Rough-In',
      'HVAC Installation',
      'Insulation',
      'Drywall',
      'Interior Trim',
      'Painting',
      'Flooring',
      'Final Walkthrough',
    ],
    'Deck/Patio': [
      'Site Preparation',
      'Footings & Posts',
      'Framing',
      'Decking Installation',
      'Railing Installation',
      'Staining/Sealing',
      'Final Inspection',
    ],
    'General': [
      'Site Preparation',
      'Demolition',
      'Framing',
      'Electrical Rough-In',
      'Plumbing Rough-In',
      'HVAC Installation',
      'Insulation',
      'Drywall',
      'Interior Trim',
      'Painting',
      'Flooring',
      'Final Fixtures',
      'Final Walkthrough',
    ],
  };

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addMilestone(String name) async {
    if (name.trim().isEmpty) return;

    setState(() => _isAdding = true);

    try {
      // Get current milestone count for ordering
      final milestones = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .get();

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .add({
        'name': name.trim(),
        'is_completed': false,
        'order': milestones.docs.length,
        'created_at': FieldValue.serverTimestamp(),
        'completed_at': null,
      });

      _nameController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milestone added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<void> _toggleMilestone(String milestoneId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .doc(milestoneId)
          .update({
        'is_completed': !currentStatus,
        'completed_at': !currentStatus ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteMilestone(String milestoneId) async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .doc(milestoneId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milestone deleted')),
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

  void _showTemplateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Milestone Templates'),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _projectTemplates.entries.map((entry) {
                final projectType = entry.key;
                final milestones = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        projectType,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    ...milestones.map((milestone) => ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: Text(milestone, style: const TextStyle(fontSize: 14)),
                      trailing: const Icon(Icons.add_circle_outline, size: 20),
                      onTap: () {
                        _addMilestone(milestone);
                        // Don't close dialog - stay open for quick adding
                      },
                    )),
                    const Divider(height: 8),
                  ],
                );
              }).toList(),
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Milestones'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton.icon(
              icon: Icon(Icons.list_alt, color: Colors.blue[700]),
              label: Text('Templates', style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600)),
              onPressed: _showTemplateDialog,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Add milestone input
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Type milestone name and press Enter (e.g., "Framing")',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                suffixIcon: _isAdding
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onSubmitted: _addMilestone,
              textInputAction: TextInputAction.done,
            ),
          ),

          // Milestones list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No milestones yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add milestones to track project progress',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _showTemplateDialog,
                            icon: const Icon(Icons.list_alt),
                            label: const Text('Browse Templates'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final milestones = snapshot.data!.docs;

                return Column(
                  children: [
                    // Instructions
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.blue[50],
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap and hold to reorder milestones',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: milestones.length,
                  onReorder: (oldIndex, newIndex) async {
                    // Update order in Firestore
                    if (oldIndex < newIndex) newIndex--;

                    final milestone = milestones[oldIndex];
                    await FirebaseFirestore.instance
                        .collection('projects')
                        .doc(widget.projectId)
                        .collection('milestones')
                        .doc(milestone.id)
                        .update({'order': newIndex});
                  },
                  itemBuilder: (context, index) {
                    final doc = milestones[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isCompleted = data['is_completed'] as bool? ?? false;
                    final name = data['name'] as String;
                    final completedAt = data['completed_at'] as Timestamp?;

                    return Container(
                      key: ValueKey(doc.id),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Checkbox(
                          value: isCompleted,
                          onChanged: (value) => _toggleMilestone(doc.id, isCompleted),
                          activeColor: Colors.green,
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCompleted ? Colors.grey : null,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: completedAt != null
                            ? Text(
                                'Completed ${DateFormat('MMM d, yyyy').format(completedAt.toDate())}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.drag_indicator,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: Colors.red,
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Milestone'),
                                    content: Text(
                                        'Delete "$name"? This cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteMilestone(doc.id);
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
