import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_document_bottom_sheet.dart';

class DocumentsTabWidget extends StatelessWidget {
  final String projectId;
  final bool canManage;
  final String? currentUserUid;
  final String? currentUserName;
  final String? currentUserRole;
  final String? teamId;

  const DocumentsTabWidget({
    super.key,
    required this.projectId,
    required this.canManage,
    this.currentUserUid,
    this.currentUserName,
    this.currentUserRole,
    this.teamId,
  });

  static const _docCategoryMeta = {
    'contracts': ('Contracts', Icons.handshake, Color(0xFF2196F3)),
    'permits': ('Permits', Icons.verified, Color(0xFF4CAF50)),
    'plans': ('Plans', Icons.architecture, Color(0xFF9C27B0)),
    'lien_waivers': ('Lien Waivers', Icons.gavel, Color(0xFFFF9800)),
    'insurance': ('Insurance', Icons.security, Color(0xFF00BCD4)),
    'specs': ('Specs', Icons.description, Color(0xFF607D8B)),
    'other': ('Other', Icons.folder, Color(0xFF9E9E9E)),
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

  void _openAddDocument(BuildContext context, {String? preselectedCategory}) {
    if (currentUserUid == null || currentUserName == null || currentUserRole == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddDocumentBottomSheet(
          projectId: projectId,
          uploadedByUid: currentUserUid!,
          uploadedByName: currentUserName!,
          uploadedByRole: currentUserRole!,
          teamId: teamId,
          preselectedCategory: preselectedCategory,
        ),
      ),
    ).then((result) {
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded!')),
        );
      }
    });
  }

  void _viewDocument(BuildContext context, String url, String fileType) {
    if (fileType == 'pdf') {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const SizedBox(
                    height: 200,
                    child: Center(child: Text('Failed to load document')),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('documents')
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
                  Text('${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.red[600])),
                ],
              ),
            ),
          );
        }

        final docsList = snapshot.data?.docs ?? [];
        docsList.sort((a, b) {
          final aTime = ((a.data() as Map<String, dynamic>)['uploaded_at'] as Timestamp?)
                  ?.millisecondsSinceEpoch ?? 0;
          final bTime = ((b.data() as Map<String, dynamic>)['uploaded_at'] as Timestamp?)
                  ?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

        if (docsList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No documents yet',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const SizedBox(height: 12),
                  Text(
                    canManage
                        ? 'Upload contracts, permits, and other project documents'
                        : 'Documents will appear here once uploaded',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[500], height: 1.5),
                  ),
                  if (canManage) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _openAddDocument(context),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Document'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        // Calculate category counts and lien waiver stats
        final categoryCounts = <String, int>{};
        int lienWaiverTotal = 0;
        int lienWaiverReceived = 0;
        final pendingWaivers = <Map<String, dynamic>>[];

        for (final doc in docsList) {
          final data = doc.data() as Map<String, dynamic>;
          final cat = data['category'] as String? ?? 'other';
          categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
          if (cat == 'lien_waivers') {
            lienWaiverTotal++;
            final status = data['lien_waiver_status'] as String? ?? 'pending';
            if (status == 'received') {
              lienWaiverReceived++;
            } else {
              pendingWaivers.add(data);
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Upload button
            if (canManage)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openAddDocument(context),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Document',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

            // Summary card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('Project Documents',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text('${docsList.length} file${docsList.length == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...categoryCounts.entries.map((entry) {
                      final meta = _docCategoryMeta[entry.key];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(meta?.$2 ?? Icons.folder,
                                size: 16, color: meta?.$3 ?? Colors.grey),
                            const SizedBox(width: 8),
                            Text(meta?.$1 ?? 'Other',
                                style: const TextStyle(fontSize: 13)),
                            const Spacer(),
                            Text('${entry.value}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Lien Waiver Tracker (if any lien waivers exist)
            if (lienWaiverTotal > 0) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.gavel, size: 18, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Text('Lien Waiver Tracker',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange)),
                          const Spacer(),
                          Text('$lienWaiverReceived / $lienWaiverTotal received',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: lienWaiverReceived == lienWaiverTotal
                                      ? Colors.green
                                      : Colors.orange[800],
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: lienWaiverTotal > 0
                              ? lienWaiverReceived / lienWaiverTotal
                              : 0,
                          backgroundColor: Colors.orange[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                          minHeight: 6,
                        ),
                      ),
                      if (pendingWaivers.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...pendingWaivers.map((w) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.pending, size: 14, color: Colors.orange[700]),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${w['lien_waiver_from'] ?? 'Unknown'} - \$${NumberFormat('#,##0.00').format(w['lien_waiver_amount'] ?? 0)}',
                                      style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Document list
            ...docsList.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] as String? ?? 'Untitled';
              final category = data['category'] as String? ?? 'other';
              final fileUrl = data['file_url'] as String? ?? '';
              final fileType = data['file_type'] as String? ?? 'image';
              final uploadedByName = data['uploaded_by_name'] as String? ?? '';
              final uploadedAt = data['uploaded_at'] as Timestamp?;
              final meta = _docCategoryMeta[category];

              // Lien waiver extra fields
              final isLienWaiver = category == 'lien_waivers';
              final lienFrom = data['lien_waiver_from'] as String?;
              final lienType = data['lien_waiver_type'] as String?;
              final lienAmount = (data['lien_waiver_amount'] as num?)?.toDouble();
              final lienStatus = data['lien_waiver_status'] as String?;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: fileUrl.isNotEmpty
                      ? () => _viewDocument(context, fileUrl, fileType)
                      : null,
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
                            meta?.$2 ?? Icons.folder,
                            color: meta?.$3 ?? Colors.grey,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Icon(
                                    fileType == 'pdf'
                                        ? Icons.picture_as_pdf
                                        : Icons.image,
                                    size: 16,
                                    color: fileType == 'pdf'
                                        ? Colors.red[400]
                                        : Colors.blue[400],
                                  ),
                                ],
                              ),
                              // Lien waiver extra info
                              if (isLienWaiver && lienFrom != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (lienType != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          lienType == 'conditional'
                                              ? 'Conditional'
                                              : 'Unconditional',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '$lienFrom${lienAmount != null ? ' - \$${NumberFormat('#,##0.00').format(lienAmount)}' : ''}',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey[600]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (lienStatus != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: lienStatus == 'received'
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          lienStatus == 'received'
                                              ? 'Received'
                                              : 'Pending',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: lienStatus == 'received'
                                                ? Colors.green
                                                : Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (meta?.$3 ?? Colors.grey).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(meta?.$1 ?? 'Other',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: meta?.$3 ?? Colors.grey,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 8),
                                  if (uploadedByName.isNotEmpty)
                                    Text(uploadedByName,
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.grey[500])),
                                  const Spacer(),
                                  if (uploadedAt != null)
                                    Text(_formatTimeAgo(uploadedAt.toDate()),
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.grey[500])),
                                ],
                              ),
                            ],
                          ),
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
    );
  }
}
