import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddTimeEntryBottomSheet extends StatefulWidget {
  final String projectId;
  final String enteredByUid;
  final String enteredByName;
  final String enteredByRole;
  final List<Map<String, dynamic>>? assignableMembers;

  const AddTimeEntryBottomSheet({
    super.key,
    required this.projectId,
    required this.enteredByUid,
    required this.enteredByName,
    required this.enteredByRole,
    this.assignableMembers,
  });

  @override
  State<AddTimeEntryBottomSheet> createState() =>
      _AddTimeEntryBottomSheetState();
}

class _AddTimeEntryBottomSheetState extends State<AddTimeEntryBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _hoursController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedMemberUid;
  String? _selectedMemberName;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _hoursController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitTimeEntry() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('time_entries')
          .add({
        'date': Timestamp.fromDate(
            DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)),
        'hours': double.parse(_hoursController.text.trim()),
        'description': _descriptionController.text.trim(),
        'logged_by_uid': _selectedMemberUid ?? widget.enteredByUid,
        'logged_by_name': _selectedMemberName ?? widget.enteredByName,
        'logged_by_role': widget.enteredByRole,
        'entered_by_uid': widget.enteredByUid,
        'entered_by_name': widget.enteredByName,
        'created_at': Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'updated_at': FieldValue.serverTimestamp()});

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text('Log Time',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(height: 2),
                          Text(dateFormat.format(_selectedDate),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Hours
              TextFormField(
                controller: _hoursController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Hours',
                  hintText: 'e.g. 8.0',
                  suffixText: 'hrs',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter hours';
                  }
                  final hours = double.tryParse(value.trim());
                  if (hours == null || hours <= 0) {
                    return 'Please enter a valid number';
                  }
                  if (hours > 24) {
                    return 'Hours cannot exceed 24';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Member dropdown (GC/foreman only)
              if (widget.assignableMembers != null &&
                  widget.assignableMembers!.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: _selectedMemberUid,
                  decoration: InputDecoration(
                    labelText: 'Log time for',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('Myself (${widget.enteredByName})'),
                    ),
                    ...widget.assignableMembers!.map((member) =>
                        DropdownMenuItem<String>(
                          value: member['uid'] as String,
                          child: Text(member['name'] as String),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedMemberUid = value;
                      if (value != null) {
                        _selectedMemberName = widget.assignableMembers!
                            .firstWhere((m) => m['uid'] == value)['name']
                            as String;
                      } else {
                        _selectedMemberName = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g., Framing north wall',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 24),

              // Error
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: TextStyle(
                                fontSize: 13, color: Colors.red[900])),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTimeEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save Time Entry',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
