import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../services/receipt_scanner_service.dart';

class AddExpenseBottomSheet extends StatefulWidget {
  final String projectId;
  final String enteredByUid;
  final String enteredByName;
  final String enteredByRole;

  const AddExpenseBottomSheet({
    super.key,
    required this.projectId,
    required this.enteredByUid,
    required this.enteredByName,
    required this.enteredByRole,
  });

  @override
  State<AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends State<AddExpenseBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _vendorController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'materials';
  File? _receiptImage;
  bool _isSubmitting = false;
  bool _isScanning = false;
  String? _errorMessage;

  static const _categories = [
    ('materials', 'Materials', Icons.inventory_2),
    ('tools', 'Tools', Icons.build),
    ('permits', 'Permits', Icons.description),
    ('labor', 'Labor', Icons.engineering),
    ('other', 'Other', Icons.more_horiz),
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _vendorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        _receiptImage = file;
        _isScanning = true;
      });

      try {
        final result = await ReceiptScannerService.scanReceipt(file);

        if (mounted) {
          setState(() => _isScanning = false);

          // Pre-fill fields if scanner found data and fields are empty
          bool filled = false;
          if (result.amount != null && _amountController.text.trim().isEmpty) {
            _amountController.text = result.amount!.toStringAsFixed(2);
            filled = true;
          }
          if (result.vendor != null && _vendorController.text.trim().isEmpty) {
            _vendorController.text = result.vendor!;
            filled = true;
          }

          if (filled) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Receipt scanned${result.vendor != null ? ' — ${result.vendor}' : ''}${result.amount != null ? ' \$${result.amount!.toStringAsFixed(2)}' : ''}',
                    )),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isScanning = false);
        }
      }
    }
  }

  Future<String?> _uploadReceipt() async {
    if (_receiptImage == null) return null;

    final compressedImage = await FlutterImageCompress.compressWithFile(
      _receiptImage!.path,
      quality: 85,
    );

    if (compressedImage == null) throw Exception('Image compression failed');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'receipts/${widget.projectId}/$timestamp.jpg';

    final storageRef = FirebaseStorage.instance.ref().child(fileName);
    await storageRef.putData(compressedImage);
    return await storageRef.getDownloadURL();
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final receiptUrl = await _uploadReceipt();

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('expenses')
          .add({
        'amount': double.parse(_amountController.text.trim()),
        'vendor': _vendorController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
        'receipt_photo_url': receiptUrl,
        'entered_by_uid': widget.enteredByUid,
        'entered_by_name': widget.enteredByName,
        'entered_by_role': widget.enteredByRole,
        'created_at': Timestamp.now(),
      });

      // Update project's updated_at timestamp
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'updated_at': FieldValue.serverTimestamp()});

      if (mounted) {
        Navigator.pop(context, true);
      }
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.93,
        ),
        child: Container(
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
                      child: Text(
                        'Add Expense',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // === RECEIPT SCAN SECTION (TOP) ===
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.document_scanner, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Scan a Receipt',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Take a photo and we\'ll fill in the vendor and amount for you',
                        style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                      ),
                      const SizedBox(height: 10),
                      if (_receiptImage != null) ...[
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _receiptImage!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (_isScanning)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      SizedBox(height: 8),
                                      Text('Scanning receipt...', style: TextStyle(color: Colors.white, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.white),
                                onPressed: _isScanning ? null : () => setState(() => _receiptImage = null),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _pickReceipt(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: const Text('Camera'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickReceipt(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library, size: 18),
                                label: const Text('Gallery'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Divider with "or enter manually"
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or enter manually', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$ ',
                    hintText: '247.53',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter amount';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Vendor
                TextFormField(
                  controller: _vendorController,
                  decoration: InputDecoration(
                    labelText: 'Vendor',
                    hintText: 'e.g., Home Depot',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter vendor name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Description (optional)
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g., 2x4 framing lumber, screws',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),

                // Category chips
                Text(
                  'Category',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final isSelected = _category == cat.$1;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat.$3,
                            size: 16,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
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
                const SizedBox(height: 20),

                // Error message
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
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(fontSize: 13, color: Colors.red[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitExpense,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Expense',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
