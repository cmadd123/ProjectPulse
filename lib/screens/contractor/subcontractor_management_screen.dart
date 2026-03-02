import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'subcontractor_detail_screen.dart';

class SubcontractorManagementScreen extends StatefulWidget {
  const SubcontractorManagementScreen({super.key});

  @override
  State<SubcontractorManagementScreen> createState() =>
      _SubcontractorManagementScreenState();
}

class _SubcontractorManagementScreenState
    extends State<SubcontractorManagementScreen> {
  String? _teamId;
  bool _isLoading = true;

  static const _tradeMeta = {
    'plumbing': ('Plumbing', Icons.plumbing, Color(0xFF2196F3)),
    'electrical': ('Electrical', Icons.electrical_services, Color(0xFFFF9800)),
    'hvac': ('HVAC', Icons.ac_unit, Color(0xFF00BCD4)),
    'roofing': ('Roofing', Icons.roofing, Color(0xFF795548)),
    'painting': ('Painting', Icons.format_paint, Color(0xFF9C27B0)),
    'concrete': ('Concrete', Icons.view_module, Color(0xFF607D8B)),
    'drywall': ('Drywall', Icons.dashboard, Color(0xFF8BC34A)),
    'framing': ('Framing', Icons.grid_on, Color(0xFFFF5722)),
    'other': ('Other', Icons.build, Color(0xFF9E9E9E)),
  };

  @override
  void initState() {
    super.initState();
    _loadTeamId();
  }

  Future<void> _loadTeamId() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final teamId = userDoc.data()?['team_id'] as String?;

      if (mounted) {
        setState(() {
          _teamId = teamId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading team: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddSubSheet() async {
    final companyController = TextEditingController();
    final contactController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();
    String selectedTrade = 'other';
    bool isSaving = false;

    final result = await showModalBottomSheet<bool>(
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
                        child: Text(
                          'Add Subcontractor',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: companyController,
                    decoration: InputDecoration(
                      labelText: 'Company Name *',
                      hintText: 'e.g., ABC Plumbing',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: contactController,
                    decoration: InputDecoration(
                      labelText: 'Contact Name *',
                      hintText: 'e.g., John Smith',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'john@abc.com',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone',
                            hintText: '555-1234',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Trade',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tradeMeta.entries.map((entry) {
                      final isSelected = selectedTrade == entry.key;
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
                        onSelected: (_) => setSheetState(() => selectedTrade = entry.key),
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[800],
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (companyController.text.trim().isEmpty ||
                                  contactController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Company and contact name are required')),
                                );
                                return;
                              }
                              setSheetState(() => isSaving = true);
                              try {
                                await FirebaseFirestore.instance
                                    .collection('teams')
                                    .doc(_teamId)
                                    .collection('subcontractors')
                                    .add({
                                  'company_name': companyController.text.trim(),
                                  'contact_name': contactController.text.trim(),
                                  'email': emailController.text.trim(),
                                  'phone': phoneController.text.trim(),
                                  'trade': selectedTrade,
                                  'status': 'active',
                                  'notes': notesController.text.trim(),
                                  'added_at': Timestamp.now(),
                                });
                                if (context.mounted) Navigator.pop(context, true);
                              } catch (e) {
                                setSheetState(() => isSaving = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Add Subcontractor',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subcontractor added!')),
      );
    }
  }

  Future<String> _getCoiStatus(String subId) async {
    final cois = await FirebaseFirestore.instance
        .collection('teams')
        .doc(_teamId)
        .collection('subcontractors')
        .doc(subId)
        .collection('coi')
        .get();

    if (cois.docs.isEmpty) return 'none';

    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));
    bool hasExpired = false;
    bool hasExpiringSoon = false;
    bool hasValid = false;

    for (final doc in cois.docs) {
      final data = doc.data();
      final expiryDate = (data['expiry_date'] as Timestamp?)?.toDate();
      if (expiryDate == null) continue;

      if (expiryDate.isBefore(now)) {
        hasExpired = true;
      } else if (expiryDate.isBefore(thirtyDaysFromNow)) {
        hasExpiringSoon = true;
      } else {
        hasValid = true;
      }
    }

    if (hasExpired) return 'expired';
    if (hasExpiringSoon) return 'expiring';
    if (hasValid) return 'valid';
    return 'none';
  }

  void _showDeleteSubDialog(String subId, String companyName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Subcontractor'),
        content: Text('Remove $companyName from your subcontractors?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Delete COI subcollection first
              final cois = await FirebaseFirestore.instance
                  .collection('teams')
                  .doc(_teamId)
                  .collection('subcontractors')
                  .doc(subId)
                  .collection('coi')
                  .get();
              for (final doc in cois.docs) {
                await doc.reference.delete();
              }
              await FirebaseFirestore.instance
                  .collection('teams')
                  .doc(_teamId)
                  .collection('subcontractors')
                  .doc(subId)
                  .delete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showSubDetails(String subId, Map<String, dynamic> subData) {
    final companyName = subData['company_name'] as String? ?? 'Unknown';
    final trade = subData['trade'] as String? ?? 'other';
    final tradeMeta = _tradeMeta[trade];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        (tradeMeta?.$3 ?? Colors.grey).withOpacity(0.15),
                    child: Icon(tradeMeta?.$2 ?? Icons.build,
                        color: tradeMeta?.$3 ?? Colors.grey, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(companyName,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(tradeMeta?.$1 ?? 'Other',
                            style: TextStyle(
                                fontSize: 12,
                                color: tradeMeta?.$3 ?? Colors.grey,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSubProjectsSection(subId),
                  const SizedBox(height: 20),
                  _buildSubScheduleSection(subId),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubcontractorDetailScreen(
                            teamId: _teamId!,
                            subId: subId,
                            subData: subData,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View Full Details & COI'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubProjectsSection(String subId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.work, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text('Assigned Projects',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700],
                )),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .where('assigned_sub_ids', arrayContains: subId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final projects = snapshot.data?.docs ?? [];
            if (projects.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text('Not assigned to any projects',
                      style: TextStyle(color: Colors.grey[500])),
                ),
              );
            }
            return Column(
              children: projects.map((doc) {
                final project = doc.data() as Map<String, dynamic>;
                final status = project['status'] ?? 'active';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: status == 'active'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      child: Icon(Icons.work,
                          color:
                              status == 'active' ? Colors.green : Colors.grey,
                          size: 20),
                    ),
                    title: Text(project['project_name'] ?? 'Untitled',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(project['client_name'] ?? 'No client',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status == 'active'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status == 'active' ? 'Active' : 'Done',
                        style: TextStyle(
                          fontSize: 11,
                          color: status == 'active'
                              ? Colors.green[700]
                              : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubScheduleSection(String subId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final twoWeeksOut = today.add(const Duration(days: 14));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text('Upcoming Schedule',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700],
                )),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _teamId == null
              ? const Stream.empty()
              : FirebaseFirestore.instance
                  .collection('teams')
                  .doc(_teamId!)
                  .collection('schedule_entries')
                  .where('sub_id', isEqualTo: subId)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text('Error loading schedule',
                      style: TextStyle(color: Colors.red[400])),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final allDocs = snapshot.data?.docs ?? [];

            // Filter to recent + upcoming dates client-side
            final entries = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final date = (data['date'] as Timestamp?)?.toDate();
              if (date == null) return false;
              final normalized = DateTime(date.year, date.month, date.day);
              return !normalized.isBefore(weekAgo) &&
                  !normalized.isAfter(twoWeeksOut);
            }).toList();
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                      allDocs.isEmpty
                          ? 'No schedule entries found'
                          : 'No entries in the last 7 / next 14 days',
                      style: TextStyle(color: Colors.grey[500])),
                ),
              );
            }
            entries.sort((a, b) {
              final aDate = ((a.data() as Map)['date'] as Timestamp)
                  .millisecondsSinceEpoch;
              final bDate = ((b.data() as Map)['date'] as Timestamp)
                  .millisecondsSinceEpoch;
              return aDate.compareTo(bDate);
            });

            return Column(
              children: entries.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final date = (data['date'] as Timestamp).toDate();
                final projectName =
                    data['project_name'] as String? ?? 'Unknown';
                final isToday = date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;

                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: isToday
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                    title: Text(projectName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      DateFormat('EEEE, MMM d').format(date),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Subcontractors'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_teamId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Subcontractors'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('No team found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subcontractors'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teams')
            .doc(_teamId)
            .collection('subcontractors')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          docs.sort((a, b) {
            final aTime = ((a.data() as Map<String, dynamic>)['added_at'] as Timestamp?)
                    ?.millisecondsSinceEpoch ?? 0;
            final bTime = ((b.data() as Map<String, dynamic>)['added_at'] as Timestamp?)
                    ?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.engineering, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No subcontractors yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add your subs to track insurance and assign to projects',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey[500], height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showAddSubSheet,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Subcontractor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final companyName = data['company_name'] as String? ?? '';
              final contactName = data['contact_name'] as String? ?? '';
              final trade = data['trade'] as String? ?? 'other';
              final status = data['status'] as String? ?? 'active';
              final tradeMeta = _tradeMeta[trade];

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: (tradeMeta?.$3 ?? Colors.grey).withOpacity(0.15),
                    child: Icon(tradeMeta?.$2 ?? Icons.build,
                        color: tradeMeta?.$3 ?? Colors.grey, size: 22),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(companyName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      if (status == 'inactive')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Inactive',
                              style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        ),
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(contactName,
                            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (tradeMeta?.$3 ?? Colors.grey).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(tradeMeta?.$1 ?? 'Other',
                            style: TextStyle(
                                fontSize: 11,
                                color: tradeMeta?.$3 ?? Colors.grey,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  trailing: FutureBuilder<String>(
                    future: _getCoiStatus(doc.id),
                    builder: (context, coiSnapshot) {
                      final coiStatus = coiSnapshot.data ?? 'none';
                      Color dotColor;
                      String tooltip;
                      switch (coiStatus) {
                        case 'valid':
                          dotColor = Colors.green;
                          tooltip = 'COI Valid';
                        case 'expiring':
                          dotColor = Colors.orange;
                          tooltip = 'COI Expiring Soon';
                        case 'expired':
                          dotColor = Colors.red;
                          tooltip = 'COI Expired';
                        default:
                          dotColor = Colors.grey[300]!;
                          tooltip = 'No COI';
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: tooltip,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'remove') {
                                _showDeleteSubDialog(doc.id, companyName);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Remove', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  onTap: () => _showSubDetails(doc.id, data),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSubSheet,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Sub'),
      ),
    );
  }
}
