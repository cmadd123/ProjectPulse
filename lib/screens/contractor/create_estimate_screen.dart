import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'estimate_preview_screen.dart';

/// Preview-only estimate builder — no backend connections
class CreateEstimateScreen extends StatefulWidget {
  const CreateEstimateScreen({super.key});

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

  final List<_LineItem> _lineItems = [];
  final List<String> _photos = []; // Would hold file paths
  int _currentStep = 0;

  static const _categories = ['Materials', 'Labor', 'Subcontractor', 'Permits', 'Other'];

  @override
  void initState() {
    super.initState();
    // Pre-fill with demo data for preview
    _clientNameController.text = 'Mike Thompson';
    _clientEmailController.text = 'mike.thompson@email.com';
    _addressController.text = '421 Oak Lane, Austin TX';
    _titleController.text = 'Master Bath Remodel';
    _scopeController.text = 'Full gut and remodel of master bathroom including new tile, vanity, fixtures, and glass shower enclosure.';
    _exclusionsController.text = 'Electrical panel upgrades, mold remediation if discovered behind walls.';
    _timelineController.text = '3-4 weeks';

    _lineItems.addAll([
      _LineItem(desc: 'Demo existing bath', qty: 1, unitPrice: 1200, category: 'Labor'),
      _LineItem(desc: 'Plumbing rough-in', qty: 1, unitPrice: 2800, category: 'Subcontractor'),
      _LineItem(desc: 'Electrical rough-in', qty: 1, unitPrice: 1500, category: 'Subcontractor'),
      _LineItem(desc: 'Cement board + waterproofing', qty: 1, unitPrice: 900, category: 'Materials'),
      _LineItem(desc: 'Floor tile (porcelain 12x24)', qty: 85, unitPrice: 8, category: 'Materials'),
      _LineItem(desc: 'Shower tile (subway 3x12)', qty: 120, unitPrice: 6, category: 'Materials'),
      _LineItem(desc: 'Tile installation labor', qty: 1, unitPrice: 3200, category: 'Labor'),
      _LineItem(desc: 'Vanity + countertop', qty: 1, unitPrice: 1800, category: 'Materials'),
      _LineItem(desc: 'Glass shower door', qty: 1, unitPrice: 1400, category: 'Materials'),
      _LineItem(desc: 'Fixtures (faucet, showerhead, toilet)', qty: 1, unitPrice: 950, category: 'Materials'),
      _LineItem(desc: 'Paint + trim', qty: 1, unitPrice: 600, category: 'Labor'),
      _LineItem(desc: 'Permit', qty: 1, unitPrice: 350, category: 'Permits'),
    ]);
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
                      const Expanded(
                        child: Text('Add Line Item',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'e.g., Floor tile (porcelain 12x24)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
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
                            filled: true,
                            fillColor: Colors.grey[50],
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
                            filled: true,
                            fillColor: Colors.grey[50],
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
                          setState(() {
                            _lineItems.add(_LineItem(desc: desc, qty: qty, unitPrice: price, category: category));
                          });
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
        title: const Text('New Estimate'),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => EstimatePreviewScreen(
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
            },
            child: const Text('Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
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

          // Content
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                // Tab 0: Client & Job
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Job Title',
                        hintText: 'e.g., Master Bath Remodel',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _clientNameController,
                      decoration: InputDecoration(
                        labelText: 'Client Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _clientEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Client Email',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Job Address',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Site Photos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildPhotoButton(Icons.camera_alt, 'Camera'),
                              const SizedBox(width: 10),
                              _buildPhotoButton(Icons.photo_library, 'Gallery'),
                            ],
                          ),
                          if (_photos.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Add photos from the site visit', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                            ),
                        ],
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
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D3748),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimate Total', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text(currency.format(_total),
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_categoryTotals.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _categoryTotals.entries.map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${e.key}: ${currency.format(e.value)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ..._lineItems.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.desc, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.qty} × ${currencyDetail.format(item.unitPrice)} · ${item.category}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              currencyDetail.format(item.total),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _lineItems.removeAt(i)),
                              child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                            ),
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
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),

                // Tab 2: Scope & Terms
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: _scopeController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Scope of Work',
                        hintText: 'Describe what\'s included...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _exclusionsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Exclusions',
                        hintText: 'What\'s NOT included...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _timelineController,
                      decoration: InputDecoration(
                        labelText: 'Estimated Timeline',
                        hintText: 'e.g., 3-4 weeks',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
            border: Border.all(
              color: isActive ? const Color(0xFF2D3748) : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoButton(IconData icon, String label) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera/gallery will be connected in production')),
          );
        },
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _LineItem {
  final String desc;
  final int qty;
  final double unitPrice;
  final String category;

  _LineItem({required this.desc, required this.qty, required this.unitPrice, required this.category});

  double get total => qty * unitPrice;
}
