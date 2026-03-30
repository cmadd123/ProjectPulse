import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../backend/schema/milestone_record.dart';
import '../../services/notification_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/invoice_service.dart';
import '../../services/stripe_service.dart';

/// Design 3: Personality Injection (Polished Current)
/// Keep existing layout, add warmth and human touches
class HomeTabDesign3 extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> projectData;
  final Color brandColor;
  final ValueChanged<int> onTabSwitch;

  const HomeTabDesign3({
    super.key,
    required this.projectId,
    required this.projectData,
    required this.brandColor,
    required this.onTabSwitch,
  });

  @override
  State<HomeTabDesign3> createState() => _HomeTabDesign3State();
}

class _HomeTabDesign3State extends State<HomeTabDesign3> {
  bool _welcomeMessageDismissed = false;

  Future<void> _approveMilestone(String milestoneId, String milestoneName, double milestoneAmount) async {
    try {
      await MilestoneRecord.updateMilestone(widget.projectId, milestoneId, {
        'status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
      });

      final projectName = widget.projectData['project_name'] as String? ?? 'Project';
      NotificationService.sendMilestoneApprovedNotification(
        projectId: widget.projectId,
        projectName: projectName,
        milestoneName: milestoneName,
      );

      // Generate invoice
      String? invoiceId;
      try {
        invoiceId = await InvoiceService.generateAndSave(
          projectId: widget.projectId,
          milestoneId: milestoneId,
          milestoneName: milestoneName,
          milestoneAmount: milestoneAmount,
          projectData: widget.projectData,
        );
      } catch (invoiceErr) {
        debugPrint('Invoice generation failed: $invoiceErr');
      }

      if (mounted) {
        ConnectivityService.showOfflineWriteFeedback(context);
        // Show payment dialog after a short delay so rebuild completes
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          _showPaymentDialog(milestoneName, milestoneAmount, invoiceId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showPaymentDialog(String milestoneName, double milestoneAmount, String? invoiceId) {
    final currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final contractorName = widget.projectData['contractor_business_name'] as String? ?? '';
    final clientEmail = widget.projectData['client_email'] as String?;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
                child: Icon(Icons.check, color: Colors.green[700], size: 32),
              ),
              const SizedBox(height: 12),
              const Text('Milestone Approved!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(milestoneName, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50], borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(children: [
                  _dialogRow('Amount Due', currencyFmt.format(milestoneAmount), isBold: true),
                ]),
              ),
              const SizedBox(height: 20),
              // Pay Online (Stripe)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (invoiceId != null) {
                      final success = await StripeService.openCheckout(
                        projectId: widget.projectId,
                        invoiceId: invoiceId,
                        amount: milestoneAmount,
                        milestoneName: milestoneName,
                        clientEmail: clientEmail,
                        contractorName: contractorName,
                      );
                      if (!success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Unable to open payment page. You can pay your contractor directly.'), backgroundColor: Colors.orange),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.credit_card, size: 20),
                  label: Text('Pay Online ${currencyFmt.format(milestoneAmount)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600], foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('Card or bank transfer · small processing fee applies', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 12),
              // Pay Another Way
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Pay $contractorName directly via Zelle, Venmo, or check. They\'ll mark it as paid.'),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Pay Another Way', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w700 : FontWeight.normal, color: isBold ? Colors.black : Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: isBold ? 18 : 14, fontWeight: isBold ? FontWeight.w700 : FontWeight.w600, color: valueColor ?? (isBold ? Colors.black : null))),
      ],
    );
  }

  Future<void> _respondToChangeOrder(String changeOrderId, bool approve) async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('change_orders')
          .doc(changeOrderId)
          .update({
        'status': approve ? 'approved' : 'declined',
        'responded_at': FieldValue.serverTimestamp(),
        'responded_by_ref': userRef,
      });

      if (approve) {
        final changeOrderDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('change_orders')
            .doc(changeOrderId)
            .get();

        final costChange = changeOrderDoc.data()?['cost_change'] as num? ?? 0;

        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .update({
          'current_cost': FieldValue.increment(costChange.toDouble()),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Change order approved' : 'Change order declined'),
            backgroundColor: approve ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 1) return '1 hour ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MMM d').format(dateTime);
  }

  String _getProgressMessage(int completed, int total) {
    if (total == 0) return 'Getting started';
    final percentage = (completed / total * 100).round();

    if (percentage == 0) return 'Just beginning';
    if (percentage < 25) return 'Off to a great start';
    if (percentage < 50) return 'Making steady progress';
    if (percentage < 75) return 'More than halfway there';
    if (percentage < 100) return 'Almost complete';
    return 'Project complete';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Welcome Message (Dismissible)
          if (!_welcomeMessageDismissed) _buildWelcomeMessage(),

          // Progress Ring Hero
          _buildProgressHero(),

          // Needs Your Attention
          _buildActionCards(),

          // Coming Up This Week
          _buildComingUp(),

          // Project Budget
          _buildBudgetCard(),

          // What's Happening (Activity Feed)
          _buildActivityFeed(),

          // Your Contractor
          _buildContractorCard(),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'Powered by ProjectPulse',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    final clientName = widget.projectData['client_name'] as String? ?? 'there';
    final firstName = clientName.split(' ').first;
    final contractorName = widget.projectData['contractor_business_name'] as String? ?? 'Your contractor';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.brandColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.brandColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $firstName! 👋',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.brandColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$contractorName will post updates here as work progresses',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
            onPressed: () => setState(() => _welcomeMessageDismissed = true),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHero() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: StreamBuilder<List<MilestoneRecord>>(
        stream: MilestoneRecord.getMilestones(widget.projectId),
        builder: (context, snapshot) {
          final milestones = snapshot.data ?? [];
          final total = milestones.length;
          final completed = milestones.where(
            (m) => m.status == 'approved' || m.status == 'complete',
          ).length;
          final progress = total > 0 ? completed / total : 0.0;

          return Column(
            children: [
              // Progress Ring
              SizedBox(
                height: 140,
                width: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 140,
                      width: 140,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(widget.brandColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$completed of $total',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: widget.brandColor,
                          ),
                        ),
                        Text(
                          'milestones',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _getProgressMessage(completed, total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '$completed of $total milestones completed',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              _buildDayCounter(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayCounter() {
    final endDate = (widget.projectData['estimated_end_date'] as Timestamp?)?.toDate();

    if (endDate == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final daysLeft = endDate.difference(now).inDays;
    final isOverdue = daysLeft < 0;
    final dateStr = DateFormat('MMM d, yyyy').format(endDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isOverdue
            ? const Color(0xFFEF4444).withOpacity(0.08)
            : const Color(0xFF3B82F6).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOverdue
            ? 'Due: $dateStr (${-daysLeft} days overdue)'
            : daysLeft == 0
                ? 'Due: Today!'
                : 'Due: $dateStr ($daysLeft days left)',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
        ),
      ),
    );
  }

  Widget _buildActionCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .where('status', isEqualTo: 'awaiting_approval')
          .snapshots(),
      builder: (context, milestoneSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('change_orders')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, coSnap) {
            final pendingMilestones = milestoneSnap.data?.docs ?? [];
            final pendingCOs = coSnap.data?.docs ?? [];

            if (pendingMilestones.isEmpty && pendingCOs.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📋 Needs Your Attention',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...pendingMilestones.map((doc) => _buildMilestoneActionCard(doc)),
                  ...pendingCOs.map((doc) => _buildChangeOrderActionCard(doc)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMilestoneActionCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? 'Milestone';
    final description = data['description'] as String? ?? '';
    final amount = (data['payment_amount'] as num? ?? data['amount'] as num? ?? 0).toDouble();
    final icon = data['icon'] as String? ?? '💵';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name milestone ready for approval',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Payment: \$${amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '👉 Tap to review photos and approve',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onTabSwitch(1), // Go to Photos tab to review work
                  child: const Text('View Details'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approveMilestone(doc.id, name, amount),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 18),
                      const SizedBox(width: 4),
                      const Text('Approve'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChangeOrderActionCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Change Order';
    final description = data['description'] as String? ?? '';
    final costChange = data['cost_change'] as num? ?? 0;
    final icon = data['icon'] as String? ?? '🔧';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change order waiting for your decision',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '"$title"',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Cost: ${costChange >= 0 ? '+' : ''}\$${costChange.abs().toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '👉 Tap to approve or ask questions',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respondToChangeOrder(doc.id, false),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondToChangeOrder(doc.id, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComingUp() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .snapshots(),
      builder: (context, snapshot) {
        final allDocs = snapshot.data?.docs ?? [];
        // Filter to upcoming milestones, sorted by order
        final docs = allDocs.where((doc) {
          final status = (doc.data() as Map<String, dynamic>)['status'] as String? ?? 'pending';
          return status == 'pending' || status == 'not_started' || status == 'in_progress';
        }).toList()
          ..sort((a, b) {
            final aOrder = ((a.data() as Map<String, dynamic>)['order'] as num?) ?? 999;
            final bOrder = ((b.data() as Map<String, dynamic>)['order'] as num?) ?? 999;
            return aOrder.compareTo(bOrder);
          });
        final displayDocs = docs.take(4).toList();
        if (displayDocs.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '\u26A1 Coming Up',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...displayDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] as String? ?? 'Milestone';
                final status = data['status'] as String? ?? 'pending';
                final isActive = status == 'in_progress';
                final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? const Color(0xFF3B82F6) : Colors.grey[300],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                            color: isActive ? const Color(0xFF1E293B) : Colors.grey[700],
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'In Progress',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        )
                      else
                        Text(
                          currencyFormat.format(amount),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetCard() {
    final originalCost = widget.projectData['original_cost'] as num? ?? 0;
    final currentCost = widget.projectData['current_cost'] as num? ?? originalCost;
    final costDifference = currentCost - originalCost;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💰 Project Budget',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _BudgetRow(
            label: 'Started at:',
            amount: '\$${originalCost.toStringAsFixed(0)}',
          ),
          if (costDifference != 0) ...[
            const SizedBox(height: 8),
            _BudgetRow(
              label: 'Changes so far:',
              sublabel: costDifference > 0 ? 'additions' : 'reductions',
              amount: '${costDifference >= 0 ? '+' : ''}\$${costDifference.abs().toStringAsFixed(0)}',
              isChange: true,
            ),
          ],
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _BudgetRow(
            label: 'Current Total:',
            amount: '\$${currentCost.toStringAsFixed(0)}',
            isBold: true,
          ),
          // Payment History
          _buildPaymentHistory(),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('invoices')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();

        final invoices = snap.data!.docs;
        final currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
        final paidTotal = invoices
            .where((d) => (d.data() as Map<String, dynamic>)['status'] == 'paid')
            .fold<double>(0, (sum, d) => sum + ((d.data() as Map<String, dynamic>)['amount'] as num? ?? 0).toDouble());
        final outstandingTotal = invoices
            .where((d) => (d.data() as Map<String, dynamic>)['status'] != 'paid')
            .fold<double>(0, (sum, d) => sum + ((d.data() as Map<String, dynamic>)['total_due'] as num? ?? 0).toDouble());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text('📋 Payment History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...invoices.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['milestone_name'] as String? ?? '';
              final amount = (data['total_due'] as num?)?.toDouble() ?? 0;
              final isPaid = data['status'] == 'paid';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(isPaid ? Icons.check_circle : Icons.schedule, size: 16,
                      color: isPaid ? Colors.green : Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                    Text(currencyFmt.format(amount), style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isPaid ? Colors.green[700] : Colors.orange[700],
                    )),
                  ],
                ),
              );
            }),
            if (paidTotal > 0 || outstandingTotal > 0) ...[
              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 6),
              if (paidTotal > 0) _BudgetRow(label: 'Paid:', amount: currencyFmt.format(paidTotal)),
              if (outstandingTotal > 0) ...[
                const SizedBox(height: 4),
                _BudgetRow(label: 'Outstanding:', amount: currencyFmt.format(outstandingTotal)),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildActivityFeed() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚡ What\'s Happening',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('updates')
                .orderBy('created_at', descending: true)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text(
                  'Updates will appear here when work begins',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                );
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final caption = data['caption'] as String? ?? '';
                  final createdAt = (data['created_at'] as Timestamp?)?.toDate();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ActivityItem(
                      time: createdAt != null ? _getTimeAgo(createdAt) : 'Recently',
                      description: caption,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContractorCard() {
    final contractorBusinessName = widget.projectData['contractor_business_name'] as String? ?? 'Your Contractor';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👷 Your Contractor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.brandColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business,
                  size: 32,
                  color: widget.brandColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contractorBusinessName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Questions about your project?',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => widget.onTabSwitch(2), // Go to Chat tab
                  icon: const Icon(Icons.message, size: 18),
                  label: const Text('Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.brandColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final String label;
  final String? sublabel;
  final String amount;
  final bool isBold;
  final bool isChange;

  const _BudgetRow({
    required this.label,
    this.sublabel,
    required this.amount,
    this.isBold = false,
    this.isChange = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 15 : 14,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                color: Colors.grey[700],
              ),
            ),
            if (sublabel != null) ...[
              const SizedBox(height: 2),
              Text(
                sublabel!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isChange ? Colors.green[700] : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String time;
  final String description;

  const _ActivityItem({
    required this.time,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🕐 $time',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
