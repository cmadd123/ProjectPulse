import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/estimate_service.dart';
import 'create_estimate_screen.dart';
import 'project_details_screen.dart';

class EstimatePreviewScreen extends StatefulWidget {
  final String? estimateId;
  final String clientName;
  final String clientEmail;
  final String address;
  final String title;
  final String scope;
  final String exclusions;
  final String timeline;
  final List lineItems;
  final double total;
  final Map<String, double> categoryTotals;

  const EstimatePreviewScreen({
    super.key,
    this.estimateId,
    required this.clientName,
    required this.clientEmail,
    required this.address,
    required this.title,
    required this.scope,
    required this.exclusions,
    required this.timeline,
    required this.lineItems,
    required this.total,
    required this.categoryTotals,
  });

  @override
  State<EstimatePreviewScreen> createState() => _EstimatePreviewScreenState();
}

class _EstimatePreviewScreenState extends State<EstimatePreviewScreen> {
  bool _isSending = false;
  bool _isConverting = false;
  String _contractorName = '';
  String _contractorPhone = '';
  String _contractorEmail = '';

  @override
  void initState() {
    super.initState();
    _loadContractorInfo();
  }

  Future<void> _loadContractorInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final profile = doc.data()?['contractor_profile'] as Map<String, dynamic>? ?? {};
    if (mounted) {
      setState(() {
        _contractorName = profile['business_name'] as String? ?? 'Contractor';
        _contractorPhone = profile['phone'] as String? ?? '';
        _contractorEmail = doc.data()?['email'] as String? ?? '';
      });
    }
  }

  Future<void> _sendEstimate() async {
    if (widget.estimateId == null) return;
    setState(() => _isSending = true);
    try {
      await EstimateService.generateAndSend(widget.estimateId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estimate PDF generated and sent!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _shareEstimate() async {
    if (widget.estimateId == null) return;
    try {
      await EstimateService.sharePdf(widget.estimateId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _convertToProject() async {
    if (widget.estimateId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to Project?'),
        content: Text('This will create a new project from "${widget.title}" with milestones based on your line item categories.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white),
            child: const Text('Create Project'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isConverting = true);
    try {
      final projectId = await EstimateService.convertToProject(widget.estimateId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project created!'), backgroundColor: Color(0xFF10B981)),
        );
        // Navigate to the new project
        final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(projectId).get();
        if (mounted && projectDoc.exists) {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => ProjectDetailsScreen(
              projectId: projectId,
              projectData: projectDoc.data()!,
            ),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isConverting = false);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final currencyRound = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final contractorName = _contractorName.isNotEmpty ? _contractorName : 'Contractor';

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Estimate Preview'),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.estimateId != null)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share PDF',
              onPressed: _shareEstimate,
            ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else if (widget.estimateId != null)
            TextButton.icon(
              onPressed: _sendEstimate,
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              label: const Text('Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // PDF preview card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2D3748),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(contractorName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                          if (_contractorPhone.isNotEmpty)
                            Text(_contractorPhone, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                          if (_contractorEmail.isNotEmpty)
                            Text(_contractorEmail, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: const Color(0xFFFF6B35), borderRadius: BorderRadius.circular(6)),
                          child: const Text('ESTIMATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.5)),
                        ),
                      ],
                    ),
                  ),

                  // Client info
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Prepared for:', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(widget.clientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        if (widget.clientEmail.isNotEmpty) Text(widget.clientEmail, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        if (widget.address.isNotEmpty) Text(widget.address, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('Date:', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text('Valid for:', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text('30 days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ]),
                    ]),
                  ),

                  // Project title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(left: BorderSide(color: Color(0xFFFF6B35), width: 4)),
                      ),
                      child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D3748))),
                    ),
                  ),

                  // Line items
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('LINE ITEMS', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFF2D3748), borderRadius: BorderRadius.circular(6)),
                        child: const Row(children: [
                          Expanded(flex: 4, child: Text('Description', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(flex: 1, child: Text('Qty', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('Price', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text('Total', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                        ]),
                      ),
                      ...widget.lineItems.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          color: i % 2 == 0 ? Colors.grey[50] : Colors.white,
                          child: Row(children: [
                            Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.desc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              Text(item.category, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                            ])),
                            Expanded(flex: 1, child: Text('${item.qty}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text(currency.format(item.unitPrice), style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                            Expanded(flex: 2, child: Text(currency.format(item.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                          ]),
                        );
                      }),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[300]!, width: 2))),
                        child: Row(children: [
                          const Expanded(flex: 7, child: Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
                          Expanded(flex: 2, child: Text(currencyRound.format(widget.total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2D3748)), textAlign: TextAlign.right)),
                        ]),
                      ),
                    ]),
                  ),

                  // Category summary
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                    child: Wrap(spacing: 12, runSpacing: 6, children: widget.categoryTotals.entries.map((e) {
                      final pct = (e.value / widget.total * 100).round();
                      return Text('${e.key}: ${currencyRound.format(e.value)} ($pct%)', style: TextStyle(fontSize: 11, color: Colors.grey[500]));
                    }).toList()),
                  ),

                  if (widget.scope.isNotEmpty)
                    Padding(padding: const EdgeInsets.fromLTRB(28, 24, 28, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('SCOPE OF WORK', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(widget.scope, style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5)),
                    ])),

                  if (widget.exclusions.isNotEmpty)
                    Padding(padding: const EdgeInsets.fromLTRB(28, 20, 28, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('EXCLUSIONS', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(widget.exclusions, style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5)),
                    ])),

                  if (widget.timeline.isNotEmpty)
                    Padding(padding: const EdgeInsets.fromLTRB(28, 20, 28, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('ESTIMATED TIMELINE', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(widget.timeline, style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w600)),
                    ])),

                  // Footer
                  Padding(padding: const EdgeInsets.all(28), child: Column(children: [
                    Divider(color: Colors.grey[200]),
                    const SizedBox(height: 12),
                    Text(contractorName, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3748))),
                    if (_contractorPhone.isNotEmpty || _contractorEmail.isNotEmpty)
                      Text([_contractorPhone, _contractorEmail].where((s) => s.isNotEmpty).join(' · '), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 8),
                    Text('Powered by ProjectPulse', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                  ])),
                ],
              ),
            ),

            // Action buttons below the card
            if (widget.estimateId != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isConverting ? null : _convertToProject,
                  icon: _isConverting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.rocket_launch),
                  label: const Text('Convert to Project', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
