import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/schema/milestone_record.dart';
import '../../models/milestone_templates.dart';
import 'package:intl/intl.dart';

class EditMilestonesScreen extends StatefulWidget {
  final String projectId;
  final double projectAmount;

  const EditMilestonesScreen({
    super.key,
    required this.projectId,
    required this.projectAmount,
  });

  @override
  State<EditMilestonesScreen> createState() => _EditMilestonesScreenState();
}

class _EditMilestonesScreenState extends State<EditMilestonesScreen> {
  List<_MilestoneItem> milestones = [];
  bool isLoading = true;
  bool isSaving = false;
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadExistingMilestones();
  }

  Future<void> _loadExistingMilestones() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .orderBy('order')
          .get();

      setState(() {
        milestones = snapshot.docs.map((doc) {
          final milestone = MilestoneRecord.fromFirestore(doc);
          return _MilestoneItem(
            milestoneId: milestone.milestoneId,
            nameController: TextEditingController(text: milestone.name),
            descriptionController: TextEditingController(text: milestone.description),
            percentage: milestone.percentage,
            order: milestone.order,
            status: milestone.status,
            isLocked: _isLocked(milestone.status),
          );
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading milestones: $e')),
        );
        setState(() => isLoading = false);
      }
    }
  }

  bool _isLocked(String status) {
    // Locked if awaiting approval or already approved
    return status == 'awaiting_approval' || status == 'approved' || status == 'disputed';
  }

  double _calculateAmount(double percentage) {
    // Calculate and round to 2 decimal places to avoid floating point errors
    final amount = widget.projectAmount * (percentage / 100);
    return double.parse(amount.toStringAsFixed(2));
  }

  double _getTotalPercentage() {
    return milestones.fold(0.0, (sum, m) => sum + m.percentage);
  }

  void _addMilestone() {
    setState(() {
      milestones.add(_MilestoneItem(
        milestoneId: null, // New milestone
        nameController: TextEditingController(),
        descriptionController: TextEditingController(),
        percentage: 25.0,
        order: milestones.length + 1,
        status: 'pending',
        isLocked: false,
      ));
    });
  }

  void _removeMilestone(int index) {
    if (milestones[index].isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove locked milestone')),
      );
      return;
    }

    setState(() {
      milestones[index].nameController.dispose();
      milestones[index].descriptionController.dispose();
      milestones.removeAt(index);
      // Reorder
      for (int i = 0; i < milestones.length; i++) {
        if (!milestones[i].isLocked) {
          milestones[i].order = i + 1;
        }
      }
    });
  }

  void _reorderMilestones(int oldIndex, int newIndex) {
    // Don't allow reordering locked milestones
    if (milestones[oldIndex].isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot move locked milestone')),
      );
      return;
    }

    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = milestones.removeAt(oldIndex);
      milestones.insert(newIndex, item);
      // Update orders
      for (int i = 0; i < milestones.length; i++) {
        if (!milestones[i].isLocked) {
          milestones[i].order = i + 1;
        }
      }
    });
  }

  Future<void> _saveMilestones() async {
    // Validation
    if (milestones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one milestone')),
      );
      return;
    }

    for (var milestone in milestones) {
      if (milestone.nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All milestones must have a name')),
        );
        return;
      }
    }

    final totalPercentage = _getTotalPercentage();
    if ((totalPercentage - 100).abs() > 0.1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Total must equal 100% (currently ${totalPercentage.toStringAsFixed(0)}%)')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var item in milestones) {
        if (item.isLocked) {
          // Don't update locked milestones
          continue;
        }

        final milestoneData = {
          'name': item.nameController.text.trim(),
          'description': item.descriptionController.text.trim(),
          'amount': _calculateAmount(item.percentage),
          'percentage': item.percentage,
          'order': item.order,
          'status': item.status,
        };

        if (item.milestoneId == null) {
          // New milestone - add
          final docRef = FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('milestones')
              .doc();
          batch.set(docRef, {
            ...milestoneData,
            'created_at': FieldValue.serverTimestamp(),
          });
        } else {
          // Existing milestone - update
          final docRef = FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('milestones')
              .doc(item.milestoneId);
          batch.update(docRef, milestoneData);
        }
      }

      // Add edit history
      final projectRef = FirebaseFirestore.instance.collection('projects').doc(widget.projectId);
      batch.update(projectRef, {
        'milestone_edit_history': FieldValue.arrayUnion([
          {
            'edited_at': FieldValue.serverTimestamp(),
            'status': 'pending_approval',
            'note': 'Milestone structure updated by contractor',
          }
        ]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // TODO: Send notification to client

      if (mounted) {
        Navigator.pop(context, true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milestones updated! Client will be notified.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    for (var milestone in milestones) {
      milestone.nameController.dispose();
      milestone.descriptionController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Milestones')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalPercentage = _getTotalPercentage();
    final isValid = (totalPercentage - 100).abs() < 0.1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Milestones'),
        actions: [
          if (isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: isValid ? _saveMilestones : null,
              child: Text(
                'Save',
                style: TextStyle(
                  fontSize: 16,
                  color: isValid ? Colors.white : Colors.white.withOpacity(0.5),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Client will be notified of changes. Locked milestones (🔒) cannot be edited.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Project amount header
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Project Total:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  currencyFormat.format(widget.projectAmount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Milestone list
          Expanded(
            child: milestones.isEmpty
                ? const Center(
                    child: Text('No milestones found'),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: milestones.length,
                    onReorder: _reorderMilestones,
                    itemBuilder: (context, index) {
                      final item = milestones[index];
                      return _MilestoneCard(
                        key: ValueKey(item.milestoneId ?? 'new_${item.order}'),
                        item: item,
                        index: index,
                        totalMilestones: milestones.length,
                        onRemove: () => _removeMilestone(index),
                        onPercentageChanged: (value) {
                          if (!item.isLocked) {
                            setState(() {
                              item.percentage = value;
                            });
                          }
                        },
                        amount: _calculateAmount(item.percentage),
                        currencyFormat: currencyFormat,
                      );
                    },
                  ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isValid ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      '${totalPercentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isValid ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                if (!isValid) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Total must equal 100%',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red[700],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addMilestone,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Milestone'),
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

class _MilestoneItem {
  final String? milestoneId; // null if new
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  double percentage;
  int order;
  final String status;
  final bool isLocked;

  _MilestoneItem({
    required this.milestoneId,
    required this.nameController,
    required this.descriptionController,
    required this.percentage,
    required this.order,
    required this.status,
    required this.isLocked,
  });
}

class _MilestoneCard extends StatelessWidget {
  final _MilestoneItem item;
  final int index;
  final int totalMilestones;
  final VoidCallback onRemove;
  final ValueChanged<double> onPercentageChanged;
  final double amount;
  final NumberFormat currencyFormat;

  const _MilestoneCard({
    required Key key,
    required this.item,
    required this.index,
    required this.totalMilestones,
    required this.onRemove,
    required this.onPercentageChanged,
    required this.amount,
    required this.currencyFormat,
  }) : super(key: key);

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'awaiting_approval':
        return Colors.orange;
      case 'disputed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: item.isLocked ? Colors.grey[100] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.isLocked ? Icons.lock : Icons.drag_handle,
                  color: item.isLocked ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Milestone ${item.order}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: item.isLocked ? Colors.grey[600] : null,
                        ),
                      ),
                      if (item.isLocked) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(item.status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(item.status),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!item.isLocked && totalMilestones > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onRemove,
                    color: Colors.red[300],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: item.nameController,
              enabled: !item.isLocked,
              decoration: InputDecoration(
                labelText: 'Name *',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: item.isLocked ? Colors.grey[50] : Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: item.descriptionController,
              enabled: !item.isLocked,
              decoration: InputDecoration(
                labelText: 'Description',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: item.isLocked ? Colors.grey[50] : Colors.white,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Percentage: ${item.percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: item.isLocked ? Colors.grey[600] : null,
                        ),
                      ),
                      Slider(
                        value: item.percentage,
                        min: 5,
                        max: 100,
                        divisions: 19,
                        onChanged: item.isLocked ? null : onPercentageChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  currencyFormat.format(amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: item.isLocked ? Colors.grey[600] : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
