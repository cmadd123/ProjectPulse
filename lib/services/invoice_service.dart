import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'analytics_service.dart';

class InvoiceService {
  static final _currencyFormat =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  /// Generate PDF invoice, upload to Storage, create Firestore doc.
  /// Called after a milestone is approved.
  static Future<String?> generateAndSave({
    required String projectId,
    required String milestoneId,
    required String milestoneName,
    required double milestoneAmount,
    required Map<String, dynamic> projectData,
  }) async {
    // No fee baked into invoice — fee only applied at Stripe Checkout time
    final invoiceNumber =
        'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    // Generate PDF
    final pdfBytes = await _buildPdf(
      invoiceNumber: invoiceNumber,
      projectName: projectData['project_name'] as String? ?? 'Project',
      contractorName:
          projectData['contractor_business_name'] as String? ?? 'Contractor',
      clientName: projectData['client_name'] as String? ?? 'Client',
      clientEmail: projectData['client_email'] as String? ?? '',
      milestoneName: milestoneName,
      milestoneAmount: milestoneAmount,
      fee: 0,
      totalDue: milestoneAmount,
    );

    // Upload to Firebase Storage
    final storagePath =
        'invoices/$projectId/${invoiceNumber.replaceAll('-', '_')}.pdf';
    final storageRef = FirebaseStorage.instance.ref().child(storagePath);
    await storageRef.putData(pdfBytes, SettableMetadata(contentType: 'application/pdf'));
    final pdfUrl = await storageRef.getDownloadURL();

    // Create invoice doc in Firestore
    final invoiceDoc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('invoices')
        .add({
      'invoice_number': invoiceNumber,
      'milestone_id': milestoneId,
      'milestone_name': milestoneName,
      'amount': milestoneAmount,
      'status': 'sent',
      'pdf_url': pdfUrl,
      'created_at': FieldValue.serverTimestamp(),
      'paid_at': null,
    });

    // Update milestone with released amount info
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('milestones')
        .doc(milestoneId)
        .update({
      'released_amount': milestoneAmount,
      'released_at': FieldValue.serverTimestamp(),
    });

    Analytics.invoiceGenerated(
      projectId: projectId,
      invoiceId: invoiceDoc.id,
      amount: milestoneAmount,
    );

    return invoiceDoc.id;
  }

  static Future<Uint8List> _buildPdf({
    required String invoiceNumber,
    required String projectName,
    required String contractorName,
    required String clientName,
    required String clientEmail,
    required String milestoneName,
    required double milestoneAmount,
    required double fee,
    required double totalDue,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        contractorName,
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey600,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        invoiceNumber,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        dateStr,
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 20),

              // Bill To
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BILL TO',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(clientName,
                            style: const pw.TextStyle(fontSize: 13)),
                        if (clientEmail.isNotEmpty)
                          pw.Text(clientEmail,
                              style: const pw.TextStyle(
                                  fontSize: 11, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PROJECT',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(projectName,
                            style: const pw.TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Line items table
              pw.Table(
                border: pw.TableBorder.symmetric(
                  outside: const pw.BorderSide(
                      color: PdfColors.grey300, width: 0.5),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          'Amount',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Milestone row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              milestoneName,
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Milestone payment - approved ${DateFormat('M/d/yyyy').format(DateTime.now())}',
                              style: const pw.TextStyle(
                                  fontSize: 10, color: PdfColors.grey600),
                            ),
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          _currencyFormat.format(milestoneAmount),
                          style: const pw.TextStyle(fontSize: 12),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Fee row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          'Payment Processing Fee',
                          style: const pw.TextStyle(
                              fontSize: 11, color: PdfColors.grey600),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          _currencyFormat.format(fee),
                          style: const pw.TextStyle(
                              fontSize: 11, color: PdfColors.grey600),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Total
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'TOTAL DUE:  ',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _currencyFormat.format(totalDue),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 40),

              // Payment terms
              pw.Text(
                'PAYMENT TERMS',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Payment is due upon receipt. Please contact your contractor for accepted payment methods.',
                style:
                    const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
              ),
              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Generated by ProjectPulse',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey400),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Mark an invoice as paid with payment method tracking
  static Future<void> markAsPaid(
      String projectId, String invoiceId, {
      String paymentMethod = 'other',
      String? paymentReference,
  }) async {
    final updates = <String, dynamic>{
      'status': 'paid',
      'paid_at': FieldValue.serverTimestamp(),
      'payment_method': paymentMethod,
    };
    if (paymentReference != null) {
      updates['payment_reference'] = paymentReference;
    }
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('invoices')
        .doc(invoiceId)
        .update(updates);

    Analytics.paymentMarkedPaid(
      projectId: projectId,
      invoiceId: invoiceId,
    );
  }
}
