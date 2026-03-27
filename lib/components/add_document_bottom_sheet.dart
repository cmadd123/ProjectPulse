import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class AddDocumentBottomSheet extends StatefulWidget {
  final String projectId;
  final String uploadedByUid;
  final String uploadedByName;
  final String uploadedByRole;
  final String? teamId;
  final String? preselectedCategory;

  const AddDocumentBottomSheet({
    super.key,
    required this.projectId,
    required this.uploadedByUid,
    required this.uploadedByName,
    required this.uploadedByRole,
    this.teamId,
    this.preselectedCategory,
  });

  @override
  State<AddDocumentBottomSheet> createState() => _AddDocumentBottomSheetState();
}

class _AddDocumentBottomSheetState extends State<AddDocumentBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lienFromController = TextEditingController();
  final _lienAmountController = TextEditingController();
  late String _category;
  String _lienWaiverType = 'conditional';
  String _lienWaiverStatus = 'pending';
  PlatformFile? _selectedFile;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _subcontractors = [];

  static const _docCategories = [
    ('contracts', 'Contracts', Icons.handshake),
    ('permits', 'Permits', Icons.verified),
    ('plans', 'Plans', Icons.architecture),
    ('lien_waivers', 'Lien Waivers', Icons.gavel),
    ('insurance', 'Insurance', Icons.security),
    ('specs', 'Specs', Icons.description),
    ('other', 'Other', Icons.folder),
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.preselectedCategory ?? 'contracts';
    _loadSubcontractors();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lienFromController.dispose();
    _lienAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadSubcontractors() async {
    if (widget.teamId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('subcontractors')
          .where('status', isEqualTo: 'active')
          .get();
      if (mounted) {
        setState(() {
          _subcontractors = snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'company_name': doc.data()['company_name'] as String? ?? '',
                  })
              .toList();
        });
      }
    } catch (_) {
      // Subcontractor list stays empty — document upload still works
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFile = result.files.first);
    }
  }

  Future<void> _submitDocument() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;
    if (_selectedFile == null) {
      setState(() => _errorMessage = 'Please select a file to upload');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final ext = _selectedFile!.extension ?? 'jpg';
      final isImage = ['jpg', 'jpeg', 'png'].contains(ext.toLowerCase());
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = _nameController.text.trim().replaceAll(RegExp(r'[^\w\s.-]'), '');
      final storagePath = 'documents/${widget.projectId}/${timestamp}_$sanitizedName.$ext';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      if (isImage && _selectedFile!.path != null) {
        final compressed = await FlutterImageCompress.compressWithFile(
          _selectedFile!.path!,
          quality: 85,
        );
        if (compressed != null) {
          await storageRef.putData(compressed);
        }
      } else if (_selectedFile!.path != null) {
        await storageRef.putFile(File(_selectedFile!.path!));
      }

      final fileUrl = await storageRef.getDownloadURL();
      final fileSize = _selectedFile!.size;

      final docData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'category': _category,
        'file_url': fileUrl,
        'file_type': isImage ? 'image' : 'pdf',
        'file_size': fileSize,
        'uploaded_by_uid': widget.uploadedByUid,
        'uploaded_by_name': widget.uploadedByName,
        'uploaded_at': Timestamp.now(),
      };

      // Add lien waiver fields if applicable
      if (_category == 'lien_waivers') {
        docData['lien_waiver_type'] = _lienWaiverType;
        docData['lien_waiver_from'] = _lienFromController.text.trim();
        final amount = double.tryParse(_lienAmountController.text.trim());
        if (amount != null) docData['lien_waiver_amount'] = amount;
        docData['lien_waiver_status'] = _lienWaiverStatus;
      }

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('documents')
          .add(docData);

      // Update project timestamp
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
    final isLienWaiver = _category == 'lien_waivers';

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
                    child: Text('Upload Document',
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

              // Document name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Document Name',
                  hintText: 'e.g., Kitchen Contract',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a document name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category chips
              Text('Category',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _docCategories.map((cat) {
                  final isSelected = _category == cat.$1;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.$3, size: 16,
                            color: isSelected ? Colors.white : Colors.grey[700]),
                        const SizedBox(width: 4),
                        Text(cat.$2),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _category = cat.$1),
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[800],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Lien Waiver fields
              if (isLienWaiver) ...[
                // Waiver type
                Text('Waiver Type',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'conditional', label: Text('Conditional')),
                    ButtonSegment(value: 'unconditional', label: Text('Unconditional')),
                  ],
                  selected: {_lienWaiverType},
                  onSelectionChanged: (s) => setState(() => _lienWaiverType = s.first),
                ),
                const SizedBox(height: 12),

                // From (sub dropdown or text)
                if (_subcontractors.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _lienFromController.text.isNotEmpty &&
                            _subcontractors.any(
                                (s) => s['company_name'] == _lienFromController.text)
                        ? _lienFromController.text
                        : null,
                    decoration: InputDecoration(
                      labelText: 'From (Subcontractor)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: [
                      ..._subcontractors.map((s) => DropdownMenuItem(
                            value: s['company_name'] as String,
                            child: Text(s['company_name'] as String),
                          )),
                      const DropdownMenuItem(
                        value: '__other__',
                        child: Text('Other (type manually)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == '__other__') {
                        setState(() => _lienFromController.clear());
                      } else if (value != null) {
                        setState(() => _lienFromController.text = value);
                      }
                    },
                  )
                else
                  TextFormField(
                    controller: _lienFromController,
                    decoration: InputDecoration(
                      labelText: 'From (Vendor/Sub)',
                      hintText: 'e.g., ABC Plumbing',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                const SizedBox(height: 12),

                // Manual text field if "Other" selected from dropdown
                if (_subcontractors.isNotEmpty && _lienFromController.text.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _lienFromController,
                      decoration: InputDecoration(
                        labelText: 'Vendor/Sub Name',
                        hintText: 'Type vendor name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ),

                // Amount
                TextFormField(
                  controller: _lienAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 12),

                // Status
                Text('Status',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'pending', label: Text('Pending')),
                    ButtonSegment(value: 'received', label: Text('Received')),
                  ],
                  selected: {_lienWaiverStatus},
                  onSelectionChanged: (s) =>
                      setState(() => _lienWaiverStatus = s.first),
                ),
                const SizedBox(height: 16),
              ],

              // File picker
              if (_selectedFile != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedFile!.extension == 'pdf'
                            ? Icons.picture_as_pdf
                            : Icons.image,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_selectedFile!.name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _selectedFile = null),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Select File (PDF, JPG, PNG)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              const SizedBox(height: 20),

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
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: TextStyle(fontSize: 13, color: Colors.red[900])),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Upload Document',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
