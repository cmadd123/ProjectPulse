import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import '../../services/estimate_service.dart';
import 'estimate_preview_screen.dart';

class CreateEstimateScreen extends StatefulWidget {
  final String? estimateId; // null = new estimate

  const CreateEstimateScreen({super.key, this.estimateId});

  @override
  State<CreateEstimateScreen> createState() => _CreateEstimateScreenState();
}

class _CreateEstimateScreenState extends State<CreateEstimateScreen> {
  final _clientNameController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _addressController = TextEditingController();
  final _titleController = TextEditingController();
  final _scopeController = TextEditingController();
  final _exclusionsController = TextEditingController();
  final _timelineController = TextEditingController();

  final List<LineItem> _lineItems = [];
  final List<String> _photoUrls = [];
  int _currentStep = 0;
  bool _isSaving = false;
  String? _estimateId;

  static const _categories = ['Materials', 'Labor', 'Subcontractor', 'Permits', 'Other'];

  @override
  void initState() {
    super.initState();
    _estimateId = widget.estimateId;
    if (_estimateId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final doc = await FirebaseFirestore.instance.collection('estimates').doc(_estimateId).get();
    if (!doc.exists || !mounted) return;
    final data = doc.data()!;

    _titleController.text = data['title'] ?? '';
    _clientNameController.text = data['client_name'] ?? '';
    _clientEmailController.text = data['client_email'] ?? '';
    _addressController.text = data['address'] ?? '';
    _scopeController.text = data['scope'] ?? '';
    _exclusionsController.text = data['exclusions'] ?? '';
    _timelineController.text = data['timeline'] ?? '';
    _photoUrls.addAll((data['photo_urls'] as List?)?.cast<String>() ?? []);

    final items = (data['line_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (final item in items) {
      _lineItems.add(LineItem(
        desc: item['description'] as String? ?? '',
        qty: (item['qty'] as num?)?.toInt() ?? 1,
        unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0,
        category: item['category'] as String? ?? 'Materials',
      ));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _addressController.dispose();
    _titleController.dispose();
    _scopeController.dispose();
    _exclusionsController.dispose();
    _timelineController.dispose();
    super.dispose();
  }

  double get _total => _lineItems.fold(0, (sum, item) => sum + item.total);

  Map<String, double> get _categoryTotals {
    final map = <String, double>{};
    for (final item in _lineItems) {
      map[item.category] = (map[item.category] ?? 0) + item.total;
    }
    return map;
  }

  List<Map<String, dynamic>> get _lineItemMaps => _lineItems.map((i) => {
    'description': i.desc,
    'qty': i.qty,
    'unit_price': i.unitPrice,
    'category': i.category,
  }).toList();

  Future<void> _save({bool silent = false}) async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'title': _titleController.text.trim(),
        'client_name': _clientNameController.text.trim(),
        'client_email': _clientEmailController.text.trim(),
        'address': _addressController.text.trim(),
        'scope': _scopeController.text.trim(),
        'exclusions': _exclusionsController.text.trim(),
        'timeline': _timelineController.text.trim(),
        'line_items': _lineItemMaps,
        'total': _total,
        'photo_urls': _photoUrls,
      };

      if (_estimateId == null) {
        _estimateId = await EstimateService.create(
          title: data['title'] as String,
          clientName: data['client_name'] as String,
          clientEmail: data['client_email'] as String,
          address: data['address'] as String,
          scope: data['scope'] as String,
          exclusions: data['exclusions'] as String,
          timeline: data['timeline'] as String,
          lineItems: _lineItemMaps,
          total: _total,
          photoUrls: _photoUrls,
        );
      } else {
        await EstimateService.update(_estimateId!, data);
      }

      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estimate saved'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1920);
    if (picked == null) return;

    final file = File(picked.path);
    final compressed = await FlutterImageCompress.compressWithFile(file.path, quality: 85);
    if (compressed == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'estimate_photos/${_estimateId ?? 'temp'}/$timestamp.jpg';
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    await ref.putData(compressed);
    final url = await ref.getDownloadURL();

    setState(() => _photoUrls.add(url));
  }

  void _addLineItem() {
    final descController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    String category = 'Materials';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                    children: [
                      const Expanded(child: Text('Add Line Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'e.g., Floor tile (porcelain 12x24)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true, fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Qty',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true, fillColor: Colors.grey[50],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Unit Price',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true, fillColor: Colors.grey[50],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = category == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) => setSheetState(() => category = cat),
                        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final desc = descController.text.trim();
                        final qty = int.tryParse(qtyController.text) ?? 1;
                        final price = double.tryParse(priceController.text) ?? 0;
                        if (desc.isNotEmpty && price > 0) {
                          setState(() => _lineItems.add(LineItem(desc: desc, qty: qty, unitPrice: price, category: category)));
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Add Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final currencyDetail = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_estimateId == null ? 'New Estimate' : 'Edit Estimate'),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else ...[
            TextButton(
              onPressed: () async {
                await _save(silent: true);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => EstimatePreviewScreen(
                      estimateId: _estimateId,
                      clientName: _clientNameController.text,
                      clientEmail: _clientEmailController.text,
                      address: _addressController.text,
                      title: _titleController.text,
                      scope: _scopeController.text,
                      exclusions: _exclusionsController.text,
                      timeline: _timelineController.text,
                      lineItems: _lineItems,
                      total: _total,
                      categoryTotals: _categoryTotals,
                    ),
                  ));
                }
              },
              child: const Text('Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Tab selector
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: const Color(0xFFF8F9FA),
            child: Row(
              children: [
                _buildTab(0, 'Job Info'),
                const SizedBox(width: 8),
                _buildTab(1, 'Items (${_lineItems.length})'),
                const SizedBox(width: 8),
                _buildTab(2, 'Scope'),
              ],
            ),
          ),

          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                // Tab 0: Client & Job
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(controller: _titleController, decoration: _inputDeco('Job Title', hint: 'e.g., Master Bath Remodel', helper: 'This appears on the estimate your client receives')),
                    const SizedBox(height: 12),
                    TextField(controller: _clientNameController, decoration: _inputDeco('Client Name')),
                    const SizedBox(height: 12),
                    TextField(controller: _clientEmailController, keyboardType: TextInputType.emailAddress, decoration: _inputDeco('Client Email')),
                    const SizedBox(height: 12),
                    TextField(controller: _addressController, decoration: _inputDeco('Job Address')),
                    const SizedBox(height: 12),
                    // Site photos
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Site Photos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                          const SizedBox(height: 8),
                          if (_photoUrls.isNotEmpty) ...[
                            SizedBox(
                              height: 80,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _photoUrls.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (_, i) => Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(_photoUrls[i], width: 80, height: 80, fit: BoxFit.cover),
                                    ),
                                    Positioned(top: 2, right: 2, child: GestureDetector(
                                      onTap: () => setState(() => _photoUrls.removeAt(i)),
                                      child: Container(
                                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        padding: const EdgeInsets.all(2),
                                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              _buildPhotoButton(Icons.camera_alt, 'Camera', () => _pickPhoto(ImageSource.camera)),
                              const SizedBox(width: 10),
                              _buildPhotoButton(Icons.photo_library, 'Gallery', () => _pickPhoto(ImageSource.gallery)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D3748),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(_estimateId == null ? 'Save Draft' : 'Save Changes',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),

                // Tab 1: Line Items
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF2D3748), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimate Total', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text(currency.format(_total), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_categoryTotals.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Wrap(
                          spacing: 8, runSpacing: 6,
                          children: _categoryTotals.entries.map((e) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                            child: Text('${e.key}: ${currency.format(e.value)}', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                          )).toList(),
                        ),
                      ),
                    ..._lineItems.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[200]!)),
                        child: Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.desc, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text('${item.qty} x ${currencyDetail.format(item.unitPrice)} · ${item.category}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            ])),
                            Text(currencyDetail.format(item.total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            GestureDetector(onTap: () => setState(() => _lineItems.removeAt(i)), child: Icon(Icons.close, size: 18, color: Colors.grey[400])),
                          ],
                        ),
                      );
                    }),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addLineItem,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Line Item'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],
                ),

                // Tab 2: Scope & Terms
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(controller: _scopeController, maxLines: 4, decoration: _inputDeco('Scope of Work', hint: 'Describe what\'s included...')),
                    const SizedBox(height: 12),
                    TextField(controller: _exclusionsController, maxLines: 3, decoration: _inputDeco('Exclusions', hint: 'What\'s NOT included...')),
                    const SizedBox(height: 12),
                    TextField(controller: _timelineController, decoration: _inputDeco('Estimated Timeline', hint: 'e.g., 3-4 weeks')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, {String? hint, String? helper}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildTab(int index, String label) {
    final isActive = _currentStep == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentStep = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2D3748) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? const Color(0xFF2D3748) : Colors.grey[300]!),
          ),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.white : Colors.grey[600])),
        ),
      ),
    );
  }

  Widget _buildPhotoButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    );
  }
}

class LineItem {
  final String desc;
  final int qty;
  final double unitPrice;
  final String category;

  LineItem({required this.desc, required this.qty, required this.unitPrice, required this.category});

  double get total => qty * unitPrice;
}
