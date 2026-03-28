import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'create_estimate_screen.dart';

/// Preview-only estimates list — no backend connections
class EstimatesListScreen extends StatelessWidget {
  const EstimatesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    // Demo data
    final estimates = [
      {
        'client': 'Mike Thompson',
        'title': 'Master Bath Remodel',
        'address': '421 Oak Lane, Austin TX',
        'total': 18500.0,
        'status': 'sent',
        'date': DateTime.now().subtract(const Duration(days: 2)),
        'items': 12,
      },
      {
        'client': 'Jennifer Walsh',
        'title': 'Deck Build + Pergola',
        'address': '88 Pine St, Round Rock TX',
        'total': 9200.0,
        'status': 'draft',
        'date': DateTime.now().subtract(const Duration(hours: 5)),
        'items': 8,
      },
      {
        'client': 'David Chen',
        'title': 'Kitchen Cabinets + Countertops',
        'address': '1502 Elm Dr, Cedar Park TX',
        'total': 24750.0,
        'status': 'accepted',
        'date': DateTime.now().subtract(const Duration(days: 7)),
        'items': 15,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Estimates'),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary row
          Row(
            children: [
              _buildSummaryChip('3 Total', Colors.grey),
              const SizedBox(width: 8),
              _buildSummaryChip('1 Draft', Colors.orange),
              const SizedBox(width: 8),
              _buildSummaryChip('1 Sent', Colors.blue),
              const SizedBox(width: 8),
              _buildSummaryChip('1 Won', Colors.green),
            ],
          ),
          const SizedBox(height: 16),

          ...estimates.map((est) {
            final status = est['status'] as String;
            final statusColor = status == 'accepted'
                ? Colors.green
                : status == 'sent'
                    ? Colors.blue
                    : Colors.orange;
            final statusLabel = status == 'accepted' ? 'Won' : status == 'sent' ? 'Sent' : 'Draft';
            final date = est['date'] as DateTime;
            final daysAgo = DateTime.now().difference(date).inDays;
            final timeLabel = daysAgo == 0 ? 'Today' : daysAgo == 1 ? 'Yesterday' : '${daysAgo}d ago';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const CreateEstimateScreen(),
                  ));
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              est['title'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        est['client'] as String,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        est['address'] as String,
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            currency.format(est['total']),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${est['items']} items',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            timeLabel,
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => const CreateEstimateScreen(),
          ));
        },
        icon: const Icon(Icons.add),
        label: const Text('New Estimate'),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSummaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
