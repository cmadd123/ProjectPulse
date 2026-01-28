import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/schema/milestone_record.dart';
import '../../models/milestone_templates.dart';
import 'package:intl/intl.dart';

class CreateMilestonesScreen extends StatefulWidget {
  final String projectId;
  final double projectAmount;

  const CreateMilestonesScreen({
    super.key,
    required this.projectId,
    required this.projectAmount,
  });

  @override
  State<CreateMilestonesScreen> createState() => _CreateMilestonesScreenState();
}

class _CreateMilestonesScreenState extends State<CreateMilestonesScreen> {
  String? selectedTemplate;
  List<_MilestoneItem> milestones = [];
  bool isLoading = false;
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    // Start with custom template
    _loadTemplate('Custom');
  }

  void _loadTemplate(String templateName) {
    final template = MilestoneTemplates.getTemplateByName(templateName);
    if (template != null) {
      setState(() {
        selectedTemplate = templateName;
        milestones = template.milestones
            .asMap()
            .entries
            .map((entry) => _MilestoneItem(
                  nameController: TextEditingController(text: entry.value.name),
                  descriptionController: TextEditingController(text: entry.value.description),
                  percentage: entry.value.percentage,
                  order: entry.key + 1,
                ))
            .toList();
      });
    }
  }

  double _calculateAmount(double percentage) {
    return widget.projectAmount * (percentage / 100);
  }

  double _getTotalPercentage() {
    return milestones.fold(0.0, (sum, m) => sum + m.percentage);
  }

  void _addMilestone() {
    setState(() {
      milestones.add(_MilestoneItem(
        nameController: TextEditingController(),
        descriptionController: TextEditingController(),
        percentage: 25.0,
        order: milestones.length + 1,
      ));
    });
  }

  void _removeMilestone(int index) {
    setState(() {
      milestones[index].nameController.dispose();
      milestones[index].descriptionController.dispose();
      milestones.removeAt(index);
      // Reorder
      for (int i = 0; i < milestones.length; i++) {
        milestones[i].order = i + 1;
      }
    });
  }

  void _reorderMilestones(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = milestones.removeAt(oldIndex);
      milestones.insert(newIndex, item);
      // Update orders
      for (int i = 0; i < milestones.length; i++) {
        milestones[i].order = i + 1;
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

    setState(() => isLoading = true);

    try {
      // Save each milestone
      for (var item in milestones) {
        final milestone = MilestoneRecord(
          milestoneId: '',
          name: item.nameController.text.trim(),
          description: item.descriptionController.text.trim(),
          amount: _calculateAmount(item.percentage),
          percentage: item.percentage,
          order: item.order,
          status: 'pending',
          createdAt: DateTime.now(),
        );
        await MilestoneRecord.createMilestone(widget.projectId, milestone);
      }

      // Update project to enable milestones
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({
        'milestones_enabled': true,
        'payment_status': 'unpaid',
      });

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => isLoading = false);
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
    final totalPercentage = _getTotalPercentage();
    final isValid = (totalPercentage - 100).abs() < 0.1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Define Milestones'),
        actions: [
          if (isLoading)
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

          // Template selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose a template:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MilestoneTemplates.templates.map((template) {
                    final isSelected = selectedTemplate == template.name;
                    return FilterChip(
                      label: Text(template.name),
                      selected: isSelected,
                      onSelected: (_) => _loadTemplate(template.name),
                      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Milestone list
          Expanded(
            child: milestones.isEmpty
                ? const Center(
                    child: Text('No milestones added yet'),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: milestones.length,
                    onReorder: _reorderMilestones,
                    itemBuilder: (context, index) {
                      final item = milestones[index];
                      return _MilestoneCard(
                        key: ValueKey(item.order),
                        item: item,
                        index: index,
                        totalMilestones: milestones.length,
                        onRemove: () => _removeMilestone(index),
                        onPercentageChanged: (value) {
                          setState(() {
                            item.percentage = value;
                          });
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
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  double percentage;
  int order;

  _MilestoneItem({
    required this.nameController,
    required this.descriptionController,
    required this.percentage,
    required this.order,
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drag_handle, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Milestone ${item.order}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (totalMilestones > 1)
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
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: item.descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
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
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        value: item.percentage,
                        min: 5,
                        max: 100,
                        divisions: 19,
                        onChanged: onPercentageChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  currencyFormat.format(amount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
