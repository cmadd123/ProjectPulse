import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class MilestoneUpdateRecord {
  final String updateId;
  final String projectId;
  final String milestoneId;
  final String text;
  final DocumentReference postedBy;
  final DateTime postedAt;
  final bool clientNotified;
  final String? clientResponse;
  final DateTime? clientResponseAt;

  MilestoneUpdateRecord({
    required this.updateId,
    required this.projectId,
    required this.milestoneId,
    required this.text,
    required this.postedBy,
    required this.postedAt,
    this.clientNotified = false,
    this.clientResponse,
    this.clientResponseAt,
  });

  factory MilestoneUpdateRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MilestoneUpdateRecord(
      updateId: doc.id,
      projectId: data['project_id'] as String? ?? '',
      milestoneId: data['milestone_id'] as String? ?? '',
      text: data['text'] as String? ?? '',
      postedBy: data['posted_by'] as DocumentReference,
      postedAt: (data['posted_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clientNotified: data['client_notified'] as bool? ?? false,
      clientResponse: data['client_response'] as String?,
      clientResponseAt: (data['client_response_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'project_id': projectId,
      'milestone_id': milestoneId,
      'text': text,
      'posted_by': postedBy,
      'posted_at': Timestamp.fromDate(postedAt),
      'client_notified': clientNotified,
      'client_response': clientResponse,
      'client_response_at': clientResponseAt != null ? Timestamp.fromDate(clientResponseAt!) : null,
    };
  }

  static Stream<List<MilestoneUpdateRecord>> getUpdates(String projectId, String milestoneId) {
    return FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('milestones')
        .doc(milestoneId)
        .collection('updates')
        .orderBy('posted_at', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MilestoneUpdateRecord.fromFirestore(doc))
            .toList());
  }

  static Future<void> createUpdate(String projectId, String milestoneId, MilestoneUpdateRecord update) async {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('milestones')
        .doc(milestoneId)
        .collection('updates')
        .add(update.toFirestore());
  }

  static Future<void> addClientResponse(String projectId, String milestoneId, String updateId, String response) async {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('milestones')
        .doc(milestoneId)
        .collection('updates')
        .doc(updateId)
        .update({
          'client_response': response,
          'client_response_at': FieldValue.serverTimestamp(),
        });
  }
}
