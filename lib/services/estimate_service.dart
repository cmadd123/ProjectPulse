import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class EstimateService {
  static final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _currencyRound = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  /// Create a new estimate in Firestore
  static Future<String> create({
    required String title,
    required String clientName,
    required String clientEmail,
    required String address,
    required String scope,
    required String exclusions,
    required String timeline,
    required List<Map<String, dynamic>> lineItems,
    required double total,
    List<String> photoUrls = const [],
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('estimates').add({
      'title': title,
      'client_name': clientName,
      'client_email': clientEmail,
      'address': address,
      'scope': scope,
      'exclusions': exclusions,
      'timeline': timeline,
      'line_items': lineItems,
      'total': total,
      'photo_urls': photoUrls,
      'status': 'draft',
      'contractor_uid': uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Update an existing estimate
  static Future<void> update(String estimateId, Map<String, dynamic> data) async {
    data['updated_at'] = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance.collection('estimates').doc(estimateId).update(data);
  }

  /// Get estimates stream for current contractor
  static Stream<QuerySnapshot> getEstimates() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('estimates')
        .where('contractor_uid', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// Generate PDF, upload to Storage, update estimate with PDF URL, and mark as sent
  static Future<String> generateAndSend(String estimateId) async {
    final doc = await FirebaseFirestore.instance.collection('estimates').doc(estimateId).get();
    if (!doc.exists) throw Exception('Estimate not found');
    final data = doc.data()!;

    // Get contractor info
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final profile = userDoc.data()?['contractor_profile'] as Map<String, dynamic>? ?? {};
    final contractorName = profile['business_name'] ?? 'Contractor';
    final contractorPhone = profile['phone'] ?? '';
    final contractorEmail = userDoc.data()?['email'] ?? '';

    final lineItems = (data['line_items'] as List).cast<Map<String, dynamic>>();

    // Build PDF
    final pdfBytes = await _buildPdf(
      contractorName: contractorName,
      contractorPhone: contractorPhone,
      contractorEmail: contractorEmail,
      clientName: data['client_name'] ?? '',
      clientEmail: data['client_email'] ?? '',
      address: data['address'] ?? '',
      title: data['title'] ?? 'Estimate',
      scope: data['scope'] ?? '',
      exclusions: data['exclusions'] ?? '',
      timeline: data['timeline'] ?? '',
      lineItems: lineItems,
      total: (data['total'] as num).toDouble(),
    );

    // Upload to Storage
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'estimates/$uid/EST_$timestamp.pdf';
    final storageRef = FirebaseStorage.instance.ref().child(storagePath);
    await storageRef.putData(pdfBytes, SettableMetadata(contentType: 'application/pdf'));
    final pdfUrl = await storageRef.getDownloadURL();

    // Update estimate
    await FirebaseFirestore.instance.collection('estimates').doc(estimateId).update({
      'pdf_url': pdfUrl,
      'status': 'sent',
      'sent_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    return pdfUrl;
  }

  /// Share estimate PDF via native share sheet
  static Future<void> sharePdf(String estimateId) async {
    final doc = await FirebaseFirestore.instance.collection('estimates').doc(estimateId).get();
    if (!doc.exists) return;
    final data = doc.data()!;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final profile = userDoc.data()?['contractor_profile'] as Map<String, dynamic>? ?? {};
    final contractorName = profile['business_name'] ?? 'Contractor';
    final contractorPhone = profile['phone'] ?? '';
    final contractorEmail = userDoc.data()?['email'] ?? '';

    final lineItems = (data['line_items'] as List).cast<Map<String, dynamic>>();

    final pdfBytes = await _buildPdf(
      contractorName: contractorName,
      contractorPhone: contractorPhone,
      contractorEmail: contractorEmail,
      clientName: data['client_name'] ?? '',
      clientEmail: data['client_email'] ?? '',
      address: data['address'] ?? '',
      title: data['title'] ?? 'Estimate',
      scope: data['scope'] ?? '',
      exclusions: data['exclusions'] ?? '',
      timeline: data['timeline'] ?? '',
      lineItems: lineItems,
      total: (data['total'] as num).toDouble(),
    );

    final dir = await getTemporaryDirectory();
    final title = (data['title'] as String? ?? 'Estimate').replaceAll(RegExp(r'[^\w\s]'), '');
    final file = File('${dir.path}/Estimate_$title.pdf');
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(file.path)], subject: 'Estimate: ${data['title']}');
  }

  /// Convert accepted estimate to a project
  static Future<String> convertToProject(String estimateId) async {
    final doc = await FirebaseFirestore.instance.collection('estimates').doc(estimateId).get();
    if (!doc.exists) throw Exception('Estimate not found');
    final data = doc.data()!;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Get contractor ref and info
    final contractorRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final userDoc = await contractorRef.get();
    final profile = userDoc.data()?['contractor_profile'] as Map<String, dynamic>? ?? {};
    final teamId = userDoc.data()?['team_id'] as String?;

    final total = (data['total'] as num).toDouble();

    // Create project
    final projectDoc = await FirebaseFirestore.instance.collection('projects').add({
      'project_name': data['title'],
      'client_name': data['client_name'],
      'client_email': data['client_email'],
      'address': data['address'],
      'original_cost': total,
      'current_cost': total,
      'status': 'active',
      'contractor_uid': uid,
      'contractor_ref': contractorRef,
      'contractor_business_name': profile['business_name'] ?? '',
      'team_id': teamId,
      'start_date': Timestamp.now(),
      'estimated_end_date': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'estimate_id': estimateId,
    });

    // Group line items by category to create milestones
    final lineItems = (data['line_items'] as List).cast<Map<String, dynamic>>();
    final categoryGroups = <String, List<Map<String, dynamic>>>{};
    for (final item in lineItems) {
      final cat = item['category'] as String? ?? 'Other';
      categoryGroups.putIfAbsent(cat, () => []).add(item);
    }

    int order = 0;
    for (final entry in categoryGroups.entries) {
      final catTotal = entry.value.fold<double>(
        0, (sum, item) => sum + ((item['qty'] as num) * (item['unit_price'] as num)).toDouble(),
      );
      final pct = total > 0 ? (catTotal / total * 100) : 0.0;
      final desc = entry.value.map((i) => i['description'] as String).join(', ');

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectDoc.id)
          .collection('milestones')
          .add({
        'name': entry.key,
        'description': desc,
        'amount': catTotal,
        'percentage': pct,
        'order': order++,
        'status': 'not_started',
        'created_at': FieldValue.serverTimestamp(),
      });
    }

    // Mark estimate as accepted
    await FirebaseFirestore.instance.collection('estimates').doc(estimateId).update({
      'status': 'accepted',
      'project_id': projectDoc.id,
      'accepted_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    return projectDoc.id;
  }

  // ── PDF Builder ────────────────────────────────────────────────
  static Future<Uint8List> _buildPdf({
    required String contractorName,
    required String contractorPhone,
    required String contractorEmail,
    required String clientName,
    required String clientEmail,
    required String address,
    required String title,
    required String scope,
    required String exclusions,
    required String timeline,
    required List<Map<String, dynamic>> lineItems,
    required double total,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(contractorName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    if (contractorPhone.isNotEmpty)
                      pw.Text(contractorPhone, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    if (contractorEmail.isNotEmpty)
                      pw.Text(contractorEmail, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FF6B35'),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text('ESTIMATE', style: pw.TextStyle(
                    color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12, letterSpacing: 1.5,
                  )),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(contractorName, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                pw.Text('Powered by ProjectPulse', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
              ],
            ),
          ],
        ),
        build: (context) => [
          // Client info + date
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PREPARED FOR', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                    pw.SizedBox(height: 4),
                    pw.Text(clientName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    if (clientEmail.isNotEmpty)
                      pw.Text(clientEmail, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    if (address.isNotEmpty)
                      pw.Text(address, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('DATE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                  pw.SizedBox(height: 4),
                  pw.Text(dateStr, style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 6),
                  pw.Text('VALID FOR', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                  pw.SizedBox(height: 4),
                  pw.Text('30 days', style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Project title
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border(left: pw.BorderSide(color: PdfColor.fromHex('#FF6B35'), width: 4)),
            ),
            child: pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),

          // Line items table
          pw.Table(
            border: pw.TableBorder.symmetric(
              outside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey800),
                children: ['Description', 'Qty', 'Unit Price', 'Total'].map((h) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(h, style: pw.TextStyle(
                      color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10,
                    ), textAlign: h == 'Description' ? pw.TextAlign.left : pw.TextAlign.right),
                  ),
                ).toList(),
              ),
              ...lineItems.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final qty = (item['qty'] as num).toInt();
                final price = (item['unit_price'] as num).toDouble();
                final itemTotal = qty * price;
                final bg = i % 2 == 0 ? PdfColors.grey50 : PdfColors.white;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(item['description'] as String, style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(item['category'] as String, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                        ],
                      ),
                    ),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$qty', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(_currency.format(price), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(_currency.format(itemTotal), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 10),

          // Total
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey800,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text('TOTAL:  ', style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_currencyRound.format(total), style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 24),

          // Scope
          if (scope.isNotEmpty) ...[
            pw.Text('SCOPE OF WORK', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
            pw.SizedBox(height: 6),
            pw.Text(scope, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 16),
          ],

          // Exclusions
          if (exclusions.isNotEmpty) ...[
            pw.Text('EXCLUSIONS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
            pw.SizedBox(height: 6),
            pw.Text(exclusions, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 16),
          ],

          // Timeline
          if (timeline.isNotEmpty) ...[
            pw.Text('ESTIMATED TIMELINE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
            pw.SizedBox(height: 6),
            pw.Text(timeline, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
          ],

          // Terms
          pw.Text('TERMS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
          pw.SizedBox(height: 6),
          pw.Text(
            'This estimate is valid for 30 days from the date above. Prices are subject to change after expiration. Any additional work not outlined in this estimate will require a separate change order.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
