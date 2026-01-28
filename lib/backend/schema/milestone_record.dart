import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class MilestoneRecord {
  final String milestoneId;
  final String name;
  final String description;
  final double amount;
  final double percentage;
  final int order;
  final String status; // "pending", "in_progress", "awaiting_approval", "approved", "disputed"
  final DateTime? startedAt;
  final DateTime? markedCompleteAt;
  final DateTime? approvedAt;
  final DateTime? releasedAt;
  final double? releasedAmount; // After fees
  final double? transactionFee;
  final String? disputeReason;
  final DateTime createdAt;

  MilestoneRecord({
    required this.milestoneId,
    required this.name,
    required this.description,
    required this.amount,
    required this.percentage,
    required this.order,
    required this.status,
    this.startedAt,
    this.markedCompleteAt,
    this.approvedAt,
    this.releasedAt,
    this.releasedAmount,
    this.transactionFee,
    this.disputeReason,
    required this.createdAt,
  });

  factory MilestoneRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MilestoneRecord(
      milestoneId: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (data['percentage'] as num?)?.toDouble() ?? 0.0,
      order: data['order'] as int? ?? 0,
      status: data['status'] as String? ?? 'pending',
      startedAt: (data['started_at'] as Timestamp?)?.toDate(),
      markedCompleteAt: (data['marked_complete_at'] as Timestamp?)?.toDate(),
      approvedAt: (data['approved_at'] as Timestamp?)?.toDate(),
      releasedAt: (data['released_at'] as Timestamp?)?.toDate(),
      releasedAmount: (data['released_amount'] as num?)?.toDouble(),
      transactionFee: (data['transaction_fee'] as num?)?.toDouble(),
      disputeReason: data['dispute_reason'] as String?,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'amount': amount,
      'percentage': percentage,
      'order': order,
      'status': status,
      'started_at': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'marked_complete_at': markedCompleteAt != null ? Timestamp.fromDate(markedCompleteAt!) : null,
      'approved_at': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'released_at': releasedAt != null ? Timestamp.fromDate(releasedAt!) : null,
      'released_amount': releasedAmount,
      'transaction_fee': transactionFee,
      'dispute_reason': disputeReason,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  static Stream<List<MilestoneRecord>> getMilestones(String projectId) {
    return FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('milestones')
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MilestoneRecord.fromFirestore(doc))
            .toList());
  }

  static Future<void> createMilestone(String projectId, MilestoneRecord milestone) async {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('milestones')
        .add(milestone.toFirestore());
  }

  static Future<void> updateMilestone(String projectId, String milestoneId, Map<String, dynamic> updates) async {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('milestones')
        .doc(milestoneId)
        .update(updates);
  }
}
