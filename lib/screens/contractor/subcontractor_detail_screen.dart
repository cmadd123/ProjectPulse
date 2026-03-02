import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class SubcontractorDetailScreen extends StatefulWidget {
  final String teamId;
  final String subId;
  final Map<String, dynamic> subData;

  const SubcontractorDetailScreen({
    super.key,
    required this.teamId,
    required this.subId,
    required this.subData,
  });

  @override
  State<SubcontractorDetailScreen> createState() => _SubcontractorDetailScreenState();
}

class _SubcontractorDetailScreenState extends State<SubcontractorDetailScreen> {
  static const _coverageTypes = {
    'general_liability': ('General Liability', Icons.shield, Color(0xFF2196F3)),
    'workers_comp': ("Workers' Comp", Icons.health_and_safety, Color(0xFF4CAF50)),
    'auto': ('Auto', Icons.directions_car, Color(0xFFFF9800)),
    'umbrella': ('Umbrella', Icons.umbrella, Color(0xFF9C27B0)),
  };

  String _coiStatusLabel(DateTime? expiryDate) {
    if (expiryDate == null) return 'Unknown';
    final now = DateTime.now();
    if (expiryDate.isBefore(now)) return 'Expired';
    if (expiryDate.isBefore(now.add(const Duration(days: 30)))) return 'Expiring Soon';
    return 'Valid';
  }

  Color _coiStatusColor(DateTime? expiryDate) {
    if (expiryDate == null) return Colors.grey;
    final now = DateTime.now();
    if (expiryDate.isBefore(now)) return Colors.red;
    if (expiryDate.isBefore(now.add(const Duration(days: 30)))) return Colors.orange;
    return Colors.green;
  }

  void _showUploadCoiSheet() {
    final insuranceCompanyController = TextEditingController();
    final policyNumberController = TextEditingController();
    String coverageType = 'general_liability';
    DateTime? expiryDate;
    PlatformFile? selectedFile;
    bool isUploading = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Upload COI',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: insuranceCompanyController,
                    decoration: InputDecoration(
                      labelText: 'Insurance Company *',
                      hintText: 'e.g., State Farm',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: policyNumberController,
                    decoration: InputDecoration(
                      labelText: 'Policy Number *',
                      hintText: 'e.g., PLB-123456',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Coverage Type',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _coverageTypes.entries.map((entry) {
                      final isSelected = coverageType == entry.key;
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(entry.value.$2, size: 16,
                                color: isSelected ? Colors.white : Colors.grey[700]),
                            const SizedBox(width: 4),
                            Text(entry.value.$1),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (_) =>
                            setSheetState(() => coverageType = entry.key),
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[800],
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Expiry Date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) {
                        setSheetState(() => expiryDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Expiry Date *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        expiryDate != null
                            ? DateFormat('MMM d, yyyy').format(expiryDate!)
                            : 'Select date',
                        style: TextStyle(
                          color: expiryDate != null ? Colors.black : Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // File picker
                  if (selectedFile != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedFile!.extension == 'pdf'
                                ? Icons.picture_as_pdf
                                : Icons.image,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(selectedFile!.name,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setSheetState(() => selectedFile = null),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                          );
                          if (result != null && result.files.isNotEmpty) {
                            setSheetState(() => selectedFile = result.files.first);
                          }
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Select COI Document'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(errorMessage!,
                                style: TextStyle(fontSize: 13, color: Colors.red[900])),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isUploading
                          ? null
                          : () async {
                              if (insuranceCompanyController.text.trim().isEmpty ||
                                  policyNumberController.text.trim().isEmpty) {
                                setSheetState(() => errorMessage = 'Insurance company and policy number are required');
                                return;
                              }
                              if (expiryDate == null) {
                                setSheetState(() => errorMessage = 'Please select an expiry date');
                                return;
                              }

                              setSheetState(() {
                                isUploading = true;
                                errorMessage = null;
                              });

                              try {
                                String? documentUrl;
                                if (selectedFile != null && selectedFile!.path != null) {
                                  final ext = selectedFile!.extension ?? 'jpg';
                                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                                  final storagePath =
                                      'coi/${widget.teamId}/${widget.subId}/$timestamp.$ext';
                                  final storageRef =
                                      FirebaseStorage.instance.ref().child(storagePath);

                                  if (['jpg', 'jpeg', 'png'].contains(ext.toLowerCase())) {
                                    final compressed =
                                        await FlutterImageCompress.compressWithFile(
                                      selectedFile!.path!,
                                      quality: 85,
                                    );
                                    if (compressed != null) {
                                      await storageRef.putData(compressed);
                                    }
                                  } else {
                                    final file = File(selectedFile!.path!);
                                    await storageRef.putFile(file);
                                  }
                                  documentUrl = await storageRef.getDownloadURL();
                                }

                                await FirebaseFirestore.instance
                                    .collection('teams')
                                    .doc(widget.teamId)
                                    .collection('subcontractors')
                                    .doc(widget.subId)
                                    .collection('coi')
                                    .add({
                                  'insurance_company':
                                      insuranceCompanyController.text.trim(),
                                  'policy_number':
                                      policyNumberController.text.trim(),
                                  'coverage_type': coverageType,
                                  'expiry_date': Timestamp.fromDate(expiryDate!),
                                  'document_url': documentUrl,
                                  'uploaded_at': Timestamp.now(),
                                });

                                if (context.mounted) Navigator.pop(context, true);
                              } catch (e) {
                                setSheetState(() {
                                  isUploading = false;
                                  errorMessage = '$e';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isUploading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Upload COI',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('COI uploaded!')),
        );
      }
    });
  }

  void _viewDocument(String url, String? ext) {
    if (ext == 'pdf') {
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
    final companyName = widget.subData['company_name'] as String? ?? '';
    final contactName = widget.subData['contact_name'] as String? ?? '';
    final email = widget.subData['email'] as String? ?? '';
    final phone = widget.subData['phone'] as String? ?? '';
    final trade = widget.subData['trade'] as String? ?? 'other';
    final notes = widget.subData['notes'] as String? ?? '';
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(companyName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sub info card
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
                      const Icon(Icons.person, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(contactName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.work, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(trade[0].toUpperCase() + trade.substring(1),
                          style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                    ],
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse('mailto:$email')),
                      child: Row(
                        children: [
                          const Icon(Icons.email, size: 18, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(email,
                              style: const TextStyle(fontSize: 14, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ],
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse('tel:$phone')),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, size: 18, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(phone,
                              style: const TextStyle(fontSize: 14, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ],
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(notes,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // COI Section header
          Row(
            children: [
              const Icon(Icons.security, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Certificates of Insurance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              TextButton.icon(
                onPressed: _showUploadCoiSheet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add COI'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // COI list
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('teams')
                .doc(widget.teamId)
                .collection('subcontractors')
                .doc(widget.subId)
                .collection('coi')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final cois = snapshot.data?.docs ?? [];
              cois.sort((a, b) {
                final aExp = ((a.data() as Map<String, dynamic>)['expiry_date'] as Timestamp?)
                        ?.millisecondsSinceEpoch ?? 0;
                final bExp = ((b.data() as Map<String, dynamic>)['expiry_date'] as Timestamp?)
                        ?.millisecondsSinceEpoch ?? 0;
                return bExp.compareTo(aExp);
              });

              if (cois.isEmpty) {
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.shield_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No COI on file',
                            style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showUploadCoiSheet,
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('Upload COI'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: cois.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final insuranceCompany = data['insurance_company'] as String? ?? '';
                  final policyNumber = data['policy_number'] as String? ?? '';
                  final coverageType = data['coverage_type'] as String? ?? 'general_liability';
                  final expiryDate = (data['expiry_date'] as Timestamp?)?.toDate();
                  final documentUrl = data['document_url'] as String?;
                  final coverage = _coverageTypes[coverageType];
                  final statusColor = _coiStatusColor(expiryDate);
                  final statusLabel = _coiStatusLabel(expiryDate);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(coverage?.$2 ?? Icons.shield,
                                  color: coverage?.$3 ?? Colors.grey, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(insuranceCompany,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 15)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(statusLabel,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: statusColor,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (coverage?.$3 ?? Colors.grey).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(coverage?.$1 ?? 'Other',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: coverage?.$3 ?? Colors.grey,
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 12),
                              Text('Policy: $policyNumber',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.event, size: 14, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                expiryDate != null
                                    ? 'Expires: ${dateFormat.format(expiryDate)}'
                                    : 'No expiry date',
                                style: TextStyle(fontSize: 12, color: statusColor),
                              ),
                              const Spacer(),
                              if (documentUrl != null)
                                GestureDetector(
                                  onTap: () {
                                    final ext = documentUrl.contains('.pdf') ? 'pdf' : 'image';
                                    _viewDocument(documentUrl, ext);
                                  },
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility, size: 14, color: Colors.blue[400]),
                                      const SizedBox(width: 4),
                                      Text('View',
                                          style: TextStyle(
                                              fontSize: 12, color: Colors.blue[400])),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
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
}
