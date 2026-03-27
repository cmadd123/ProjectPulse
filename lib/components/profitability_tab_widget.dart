import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Profitability tab for project details — answers "Am I making money on this job?"
/// Uses existing Firestore data: expenses, invoices, milestones, time_entries
class ProfitabilityTabWidget extends StatelessWidget {
  final String projectId;
  final Map<String, dynamic> projectData;

  const ProfitabilityTabWidget({
    super.key,
    required this.projectId,
    required this.projectData,
  });

  static const _categoryMeta = {
    'materials': ('Materials', Icons.inventory_2, Color(0xFF2196F3)),
    'tools': ('Tools', Icons.build, Color(0xFFFF9800)),
    'permits': ('Permits', Icons.description, Color(0xFF9C27B0)),
    'labor': ('Labor', Icons.engineering, Color(0xFF4CAF50)),
    'other': ('Other', Icons.more_horiz, Color(0xFF607D8B)),
  };

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final currencyDetailed = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final contractValue = ((projectData['current_cost'] ?? projectData['original_cost'] ?? 0) as num).toDouble();
    final budgetAmount = (projectData['budget_amount'] as num?)?.toDouble();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('expenses')
          .snapshots(),
      builder: (context, expensesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('invoices')
              .snapshots(),
          builder: (context, invoicesSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('projects')
                  .doc(projectId)
                  .collection('time_entries')
                  .snapshots(),
              builder: (context, timeSnap) {
                if (!expensesSnap.hasData || !invoicesSnap.hasData || !timeSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Calculate totals
                final expenses = expensesSnap.data!.docs;
                final invoices = invoicesSnap.data!.docs;
                final timeEntries = timeSnap.data!.docs;

                double totalExpenses = 0;
                final categoryTotals = <String, double>{};
                for (final doc in expenses) {
                  final data = doc.data() as Map<String, dynamic>;
                  final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                  final category = data['category'] as String? ?? 'other';
                  totalExpenses += amount;
                  categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
                }

                double revenueCollected = 0;
                double revenueOutstanding = 0;
                for (final doc in invoices) {
                  final data = doc.data() as Map<String, dynamic>;
                  final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                  final status = data['status'] as String? ?? 'sent';
                  if (status == 'paid') {
                    revenueCollected += amount;
                  } else {
                    revenueOutstanding += amount;
                  }
                }

                double totalHours = 0;
                final memberHours = <String, double>{};
                for (final doc in timeEntries) {
                  final data = doc.data() as Map<String, dynamic>;
                  final hours = (data['hours'] as num?)?.toDouble() ?? 0;
                  final name = data['logged_by_name'] as String? ?? data['member_name'] as String? ?? 'Unknown';
                  totalHours += hours;
                  memberHours[name] = (memberHours[name] ?? 0) + hours;
                }

                final netProfit = revenueCollected - totalExpenses;
                final margin = revenueCollected > 0 ? (netProfit / revenueCollected * 100) : 0.0;
                final hasData = expenses.isNotEmpty || invoices.isNotEmpty || timeEntries.isNotEmpty;

                if (!hasData) {
                  return _buildEmptyState();
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Profit summary card
                    _buildProfitSummary(context, netProfit, margin, revenueCollected, contractValue, currency),
                    const SizedBox(height: 16),

                    // Revenue cards
                    _buildRevenueRow(context, revenueCollected, revenueOutstanding, contractValue, currency),
                    const SizedBox(height: 16),

                    // Cost breakdown
                    if (totalExpenses > 0) ...[
                      _buildCostBreakdown(context, totalExpenses, categoryTotals, currencyDetailed),
                      const SizedBox(height: 16),
                    ],

                    // Budget vs Actual
                    if (budgetAmount != null && budgetAmount > 0) ...[
                      _buildBudgetCard(context, budgetAmount, totalExpenses, currency),
                      const SizedBox(height: 16),
                    ],

                    // Contract value with change orders
                    _buildContractCard(context, contractValue, currency),
                    const SizedBox(height: 16),

                    // Hours summary
                    if (totalHours > 0) ...[
                      _buildHoursSummary(context, totalHours, memberHours),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No financial data yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete milestones and log expenses to see profitability',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitSummary(BuildContext context, double netProfit, double margin,
      double revenueCollected, double contractValue, NumberFormat currency) {
    final isPositive = netProfit >= 0;
    final profitColor = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final marginColor = margin > 15
        ? const Color(0xFF10B981)
        : margin > 5
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text('Net Profit', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            '${isPositive ? '+' : ''}${currency.format(netProfit)}',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: profitColor),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: marginColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${margin.toStringAsFixed(1)}% margin',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: marginColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'on ${currency.format(revenueCollected)} collected of ${currency.format(contractValue)} contract',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Progress bar
          _buildProgressBar(revenueCollected, contractValue - revenueCollected),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double collected, double remaining) {
    final total = collected + remaining;
    if (total <= 0) return const SizedBox.shrink();
    final collectedPct = collected / total;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Flexible(
                  flex: (collectedPct * 100).round().clamp(1, 100),
                  child: Container(color: const Color(0xFF10B981)),
                ),
                if (collectedPct < 1)
                  Flexible(
                    flex: ((1 - collectedPct) * 100).round().clamp(1, 100),
                    child: Container(color: Colors.grey[200]),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Collected', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            Text('Remaining', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueRow(BuildContext context, double collected, double outstanding,
      double contractValue, NumberFormat currency) {
    return Row(
      children: [
        Expanded(child: _buildMetricCard('Collected', currency.format(collected), const Color(0xFF10B981), Icons.check_circle)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('Outstanding', currency.format(outstanding), const Color(0xFFF59E0B), Icons.schedule)),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildCostBreakdown(BuildContext context, double totalExpenses,
      Map<String, double> categoryTotals, NumberFormat currency) {
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expenses', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[800])),
              Text(currency.format(totalExpenses),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
            ],
          ),
          const Divider(height: 20),
          for (final entry in sortedCategories) ...[
            _buildCategoryRow(entry.key, entry.value, totalExpenses, currency),
            if (entry != sortedCategories.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String category, double amount, double total, NumberFormat currency) {
    final meta = _categoryMeta[category] ?? ('Other', Icons.more_horiz, const Color(0xFF607D8B));
    final pct = total > 0 ? (amount / total * 100) : 0.0;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: meta.$3.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(meta.$2, size: 16, color: meta.$3),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meta.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(meta.$3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(currency.format(amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  Widget _buildBudgetCard(BuildContext context, double budget, double spent, NumberFormat currency) {
    final remaining = budget - spent;
    final pctUsed = budget > 0 ? (spent / budget).clamp(0.0, 1.5) : 0.0;
    final isOver = spent > budget;
    final statusColor = pctUsed < 0.75
        ? const Color(0xFF10B981)
        : pctUsed < 1.0
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isOver ? Border.all(color: const Color(0xFFEF4444), width: 1.5) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Budget', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[800])),
                  if (isOver) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Over budget', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                    ),
                  ],
                ],
              ),
              Text('${(pctUsed * 100).toStringAsFixed(0)}% used',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor)),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: pctUsed.clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(statusColor),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildBudgetMetric('Budget', currency.format(budget), Colors.grey[700]!)),
              Expanded(child: _buildBudgetMetric('Spent', currency.format(spent), statusColor)),
              Expanded(child: _buildBudgetMetric(
                isOver ? 'Over by' : 'Remaining',
                currency.format(remaining.abs()),
                isOver ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetMetric(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildContractCard(BuildContext context, double contractValue, NumberFormat currency) {
    final originalCost = ((projectData['original_cost'] ?? 0) as num).toDouble();
    final changeOrderDiff = contractValue - originalCost;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contract', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[800])),
          const SizedBox(height: 12),
          _buildContractRow('Original Value', currency.format(originalCost), Colors.grey[800]!),
          if (changeOrderDiff != 0) ...[
            const SizedBox(height: 8),
            _buildContractRow(
              'Change Orders',
              '${changeOrderDiff > 0 ? '+' : ''}${currency.format(changeOrderDiff)}',
              changeOrderDiff > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ],
          const Divider(height: 20),
          _buildContractRow('Current Total', currency.format(contractValue), const Color(0xFF2D3748), bold: true),
        ],
      ),
    );
  }

  Widget _buildContractRow(String label, String value, Color valueColor, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(value, style: TextStyle(
          fontSize: bold ? 16 : 14,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          color: valueColor,
        )),
      ],
    );
  }

  Widget _buildHoursSummary(BuildContext context, double totalHours, Map<String, double> memberHours) {
    final sortedMembers = memberHours.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Hours Logged', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[800])),
              Text('${totalHours.toStringAsFixed(1)} hrs',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
            ],
          ),
          if (sortedMembers.isNotEmpty) ...[
            const Divider(height: 20),
            for (final entry in sortedMembers) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  Text('${entry.value.toStringAsFixed(1)} hrs',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[800])),
                ],
              ),
              if (entry != sortedMembers.last) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}
