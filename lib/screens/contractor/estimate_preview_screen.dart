import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'create_estimate_screen.dart';

/// Preview-only estimate PDF view — no backend connections
/// Shows what the client would receive as a professional PDF proposal
class EstimatePreviewScreen extends StatelessWidget {
  final String clientName;
  final String clientEmail;
  final String address;
  final String title;
  final String scope;
  final String exclusions;
  final String timeline;
  final List lineItems; // _LineItem objects
  final double total;
  final Map<String, double> categoryTotals;

  const EstimatePreviewScreen({
    super.key,
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
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final currencyRound = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());

    // Use contractor name placeholder
    const contractorName = 'Team 1';
    const contractorPhone = '(512) 555-0147';
    const contractorEmail = 'info@team1construction.com';

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Estimate Preview'),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PDF generation + email will be connected in production'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            icon: const Icon(Icons.send, color: Colors.white, size: 18),
            label: const Text('Send to Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                contractorName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contractorPhone,
                                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                              ),
                              Text(
                                contractorEmail,
                                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ESTIMATE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Client info + date
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Prepared for:', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(clientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          Text(clientEmail, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                          if (address.isNotEmpty)
                            Text(address, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Date:', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text('Valid for:', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text('30 days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
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
                    border: Border(left: BorderSide(color: const Color(0xFFFF6B35), width: 4)),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D3748)),
                  ),
                ),
              ),

              // Line items table
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LINE ITEMS', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    // Header row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D3748),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 4, child: Text('Description', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(flex: 1, child: Text('Qty', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('Unit Price', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text('Total', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                        ],
                      ),
                    ),
                    // Item rows
                    ...lineItems.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final isEven = i % 2 == 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        color: isEven ? Colors.grey[50] : Colors.white,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.desc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  Text(item.category, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                                ],
                              ),
                            ),
                            Expanded(flex: 1, child: Text('${item.qty}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text(currency.format(item.unitPrice), style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                            Expanded(flex: 2, child: Text(currency.format(item.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                          ],
                        ),
                      );
                    }),
                    // Total row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 2)),
                      ),
                      child: Row(
                        children: [
                          const Expanded(flex: 7, child: Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
                          Expanded(flex: 2, child: Text(
                            currencyRound.format(total),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2D3748)),
                            textAlign: TextAlign.right,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Category summary
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: categoryTotals.entries.map((e) {
                    final pct = (e.value / total * 100).round();
                    return Text(
                      '${e.key}: ${currencyRound.format(e.value)} ($pct%)',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    );
                  }).toList(),
                ),
              ),

              // Scope of Work
              if (scope.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SCOPE OF WORK', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(scope, style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5)),
                    ],
                  ),
                ),

              // Exclusions
              if (exclusions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EXCLUSIONS', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(exclusions, style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5)),
                    ],
                  ),
                ),

              // Timeline
              if (timeline.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ESTIMATED TIMELINE', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(timeline, style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

              // Accept section
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'To accept this estimate, reply to this email or tap below.',
                        style: TextStyle(fontSize: 13, color: Colors.green[800]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Accept Estimate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Divider(color: Colors.grey[200]),
                    const SizedBox(height: 12),
                    Text(contractorName, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3748))),
                    const SizedBox(height: 2),
                    Text('$contractorPhone · $contractorEmail', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 8),
                    Text('Powered by ProjectPulse', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
