import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'create_estimate_screen.dart';
import '../../services/estimate_service.dart';

class EstimatesListScreen extends StatelessWidget {
  const EstimatesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Estimates'),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: EstimateService.getEstimates(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.request_quote, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No estimates yet',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                    const SizedBox(height: 8),
                    Text('Create your first estimate after a site visit',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const CreateEstimateScreen(),
                      )),
                      icon: const Icon(Icons.add),
                      label: const Text('New Estimate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D3748),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Count statuses
          int drafts = 0, sent = 0, accepted = 0;
          for (final doc in docs) {
            final s = (doc.data() as Map<String, dynamic>)['status'] as String? ?? 'draft';
            if (s == 'draft') drafts++;
            else if (s == 'sent') sent++;
            else if (s == 'accepted') accepted++;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary chips
              Row(
                children: [
                  _buildSummaryChip('${docs.length} Total', Colors.grey),
                  if (drafts > 0) ...[const SizedBox(width: 8), _buildSummaryChip('$drafts Draft', Colors.orange)],
                  if (sent > 0) ...[const SizedBox(width: 8), _buildSummaryChip('$sent Sent', Colors.blue)],
                  if (accepted > 0) ...[const SizedBox(width: 8), _buildSummaryChip('$accepted Won', Colors.green)],
                ],
              ),
              const SizedBox(height: 16),

              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] as String? ?? 'draft';
                final statusColor = status == 'accepted'
                    ? Colors.green
                    : status == 'sent' ? Colors.blue : Colors.orange;
                final statusLabel = status == 'accepted' ? 'Won' : status == 'sent' ? 'Sent' : 'Draft';
                final createdAt = (data['created_at'] as Timestamp?)?.toDate();
                final daysAgo = createdAt != null ? DateTime.now().difference(createdAt).inDays : 0;
                final timeLabel = daysAgo == 0 ? 'Today' : daysAgo == 1 ? 'Yesterday' : '${daysAgo}d ago';
                final items = (data['line_items'] as List?)?.length ?? 0;
                final total = (data['total'] as num?)?.toDouble() ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CreateEstimateScreen(estimateId: doc.id),
                    )),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(data['title'] as String? ?? 'Untitled',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2D3748))),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(data['client_name'] as String? ?? '', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                          if ((data['address'] as String? ?? '').isNotEmpty)
                            Text(data['address'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(currency.format(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D3748))),
                              const Spacer(),
                              Text('$items items', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              const SizedBox(width: 12),
                              Text(timeLabel, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const CreateEstimateScreen(),
        )),
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
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
