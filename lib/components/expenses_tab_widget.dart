import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'add_expense_bottom_sheet.dart';

class ExpensesTabWidget extends StatelessWidget {
  final String projectId;
  final bool canAddExpense;
  final String? currentUserUid;
  final String? currentUserName;
  final String? currentUserRole;

  const ExpensesTabWidget({
    super.key,
    required this.projectId,
    required this.canAddExpense,
    this.currentUserUid,
    this.currentUserName,
    this.currentUserRole,
  });

  static const _categoryMeta = {
    'materials': ('Materials', Icons.inventory_2, Color(0xFF2196F3)),
    'tools': ('Tools', Icons.build, Color(0xFFFF9800)),
    'permits': ('Permits', Icons.description, Color(0xFF9C27B0)),
    'labor': ('Labor', Icons.engineering, Color(0xFF4CAF50)),
    'other': ('Other', Icons.more_horiz, Color(0xFF607D8B)),
  };

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${diff.inDays}d ago';
  }

  void _openAddExpense(BuildContext context) {
    if (currentUserUid == null || currentUserName == null || currentUserRole == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddExpenseBottomSheet(
          projectId: projectId,
          enteredByUid: currentUserUid!,
          enteredByName: currentUserName!,
          enteredByRole: currentUserRole!,
        ),
      ),
    ).then((result) {
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense saved!')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('expenses')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.red[600]),
                  ),
                ],
              ),
            ),
          );
        }

        final expensesDocs = snapshot.data?.docs ?? [];
        // Sort client-side since we removed orderBy
        expensesDocs.sort((a, b) {
          final aTime = ((a.data() as Map<String, dynamic>)['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTime = ((b.data() as Map<String, dynamic>)['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime); // descending
        });
        final expenses = expensesDocs;

        if (expenses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses yet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    canAddExpense
                        ? 'Log materials, tools, and other costs'
                        : 'Expenses will appear here once added',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[500],
                      height: 1.5,
                    ),
                  ),
                  if (canAddExpense) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _openAddExpense(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Expense'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        // Calculate totals
        double totalSpend = 0;
        final categoryTotals = <String, double>{};
        for (final doc in expenses) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num?)?.toDouble() ?? 0;
          final cat = data['category'] as String? ?? 'other';
          totalSpend += amount;
          categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amount;
        }

        final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

        return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Add Expense button
                if (canAddExpense)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _openAddExpense(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Summary card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet,
                                size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text(
                              'Total Expenses',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${expenses.length} item${expenses.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormat.format(totalSpend),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (categoryTotals.length > 1) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          ...categoryTotals.entries.map((entry) {
                            final meta = _categoryMeta[entry.key];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(meta?.$2 ?? Icons.more_horiz,
                                      size: 16, color: meta?.$3 ?? Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    meta?.$1 ?? 'Other',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const Spacer(),
                                  Text(
                                    currencyFormat.format(entry.value),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Expense list
                ...expenses.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                  final vendor = data['vendor'] as String? ?? '';
                  final description = data['description'] as String? ?? '';
                  final category = data['category'] as String? ?? 'other';
                  final receiptUrl = data['receipt_photo_url'] as String?;
                  final enteredByName = data['entered_by_name'] as String? ?? '';
                  final createdAt = data['created_at'] as Timestamp?;
                  final meta = _categoryMeta[category];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category icon
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: (meta?.$3 ?? Colors.grey).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              meta?.$2 ?? Icons.more_horiz,
                              color: meta?.$3 ?? Colors.grey,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        vendor,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      currencyFormat.format(amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (meta?.$3 ?? Colors.grey)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        meta?.$1 ?? 'Other',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: meta?.$3 ?? Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (enteredByName.isNotEmpty)
                                      Text(
                                        enteredByName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    const Spacer(),
                                    if (receiptUrl != null)
                                      GestureDetector(
                                        onTap: () => _showReceiptDialog(
                                            context, receiptUrl),
                                        child: Icon(Icons.receipt,
                                            size: 16, color: Colors.blue[400]),
                                      ),
                                    if (receiptUrl != null)
                                      const SizedBox(width: 8),
                                    if (createdAt != null)
                                      Text(
                                        _formatTimeAgo(createdAt.toDate()),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
      },
    );
  }

  void _showReceiptDialog(BuildContext context, String receiptUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: receiptUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => const SizedBox(
                  height: 200,
                  child: Center(child: Text('Failed to load receipt')),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
