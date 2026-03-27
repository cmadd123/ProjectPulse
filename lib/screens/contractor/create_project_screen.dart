import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'create_milestones_screen.dart';
import 'send_invitation_screen.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _projectNameController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _originalCostController = TextEditingController();
  final _budgetController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _estimatedEndDate = DateTime.now().add(const Duration(days: 14));
  bool _isLoading = false;

  String? _teamId;
  List<Map<String, dynamic>> _teamMembers = [];
  List<Map<String, dynamic>> _subcontractors = [];
  final Set<String> _selectedMemberUids = {};
  final Set<String> _selectedSubIds = {};

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final teamId = userDoc.data()?['team_id'] as String?;
      if (teamId == null || !mounted) return;

      _teamId = teamId;

      final membersSnap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('members')
          .where('status', isEqualTo: 'active')
          .get();

      final subsSnap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('subcontractors')
          .where('status', isEqualTo: 'active')
          .get();

      if (mounted) {
        setState(() {
          _teamMembers = membersSnap.docs
              .where((d) => d.id != user.uid)
              .map((d) => {
                    'uid': d.data()['user_uid'] as String? ?? d.id,
                    'name': d.data()['name'] as String? ?? 'Unknown',
                    'role': d.data()['role'] as String? ?? 'worker',
                  })
              .toList();
          _subcontractors = subsSnap.docs
              .map((d) => {
                    'id': d.id,
                    'company_name':
                        d.data()['company_name'] as String? ?? 'Unknown',
                    'trade': d.data()['trade'] as String? ?? 'other',
                  })
              .toList();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load team data. Crew/sub assignment may be unavailable.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _clientPhoneController.dispose();
    _originalCostController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _estimatedEndDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Ensure end date is after start date
          if (_estimatedEndDate.isBefore(_startDate)) {
            _estimatedEndDate = _startDate.add(const Duration(days: 14));
          }
        } else {
          _estimatedEndDate = picked;
        }
      });
    }
  }

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // Fetch contractor's business name
      final userDoc = await userRef.get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final contractorBusinessName = userData?['contractor_profile']?['business_name'] ?? 'Contractor';
      final teamId = userData?['team_id'] as String?;

      final projectCost = double.tryParse(_originalCostController.text.trim()) ?? 0;
      final budgetAmount = double.tryParse(_budgetController.text.trim());

      final projectData = {
        'contractor_ref': userRef,
        'contractor_uid': user.uid, // Add UID string for easier querying
        'contractor_business_name': contractorBusinessName, // Add business name for client display
        'team_id': teamId, // For team member access
        'assigned_member_uids': _selectedMemberUids.toList(),
        'assigned_sub_ids': _selectedSubIds.toList(),
        'project_name': _projectNameController.text.trim(),
        'client_name': _clientNameController.text.trim(),
        'client_email': _clientEmailController.text.trim(),
        'client_phone': _clientPhoneController.text.trim(),
        'client_user_ref': null, // Will be set when client signs up
        'start_date': Timestamp.fromDate(_startDate),
        'estimated_end_date': Timestamp.fromDate(_estimatedEndDate),
        'actual_end_date': null,
        'status': 'active',
        'original_cost': projectCost,
        'current_cost': projectCost,
        'budget_amount': budgetAmount,
        'contract_document_url': null,
        'milestones_enabled': false, // Will be set to true after milestones are created
        'payment_status': 'unpaid',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      final projectDoc = await FirebaseFirestore.instance.collection('projects').add(projectData);

      if (!mounted) return;

      // Ask if user wants to add milestones
      bool milestonesResult = false;
      final addMilestones = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Project Created!'),
          content: const Text('Would you like to set up milestones now? You can always add them later.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("I'll add later"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Milestones'),
            ),
          ],
        ),
      );

      if (addMilestones == true && mounted) {
        milestonesResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateMilestonesScreen(
              projectId: projectDoc.id,
              projectAmount: projectCost,
            ),
          ),
        ) == true;
      }

      if (!mounted) return;

      // Navigate to SendInvitationScreen to show email preview
      final invitationSent = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => SendInvitationScreen(
            projectId: projectDoc.id,
            projectName: _projectNameController.text.trim(),
            clientName: _clientNameController.text.trim(),
            clientEmail: _clientEmailController.text.trim(),
            contractorName: contractorBusinessName,
          ),
        ),
      ) ?? false;

      // Go back to contractor home
      if (mounted) {
        Navigator.pop(context, true);

        String message = 'Project created';
        if (milestonesResult) {
          message += ' with milestones';
        }
        if (invitationSent) {
          message += ' and invitation sent';
        }
        message += '!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Project'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _createProject,
              child: const Text('Create', style: TextStyle(fontSize: 16)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project name
              TextFormField(
                controller: _projectNameController,
                decoration: InputDecoration(
                  labelText: 'Project Name *',
                  hintText: 'e.g., Smith Kitchen Remodel',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter project name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Client name
              TextFormField(
                controller: _clientNameController,
                decoration: InputDecoration(
                  labelText: 'Client Name *',
                  hintText: 'e.g., John Smith',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter client name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Client email
              TextFormField(
                controller: _clientEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Client Email *',
                  hintText: 'john@email.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter client email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Client phone
              TextFormField(
                controller: _clientPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Client Phone *',
                  hintText: '(555) 123-4567',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter client phone';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Original cost
              TextFormField(
                controller: _originalCostController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Project Cost *',
                  hintText: '15000',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter project cost';
                  }
                  if (double.tryParse(value.trim()) == null) {
                    return 'Please enter valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Budget (optional)
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Your Budget (optional)',
                  hintText: 'What you plan to spend',
                  prefixText: '\$ ',
                  helperText: 'Track your costs vs this budget — only you see this',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (double.tryParse(value.trim()) == null) {
                      return 'Please enter valid number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Start date
              Text(
                'Timeline',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _selectDate(context, true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateFormat.format(_startDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Estimated end date
              InkWell(
                onTap: () => _selectDate(context, false),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimated End Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateFormat.format(_estimatedEndDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Duration display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_estimatedEndDate.difference(_startDate).inDays} days',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Assign Team Members
              if (_teamMembers.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Assign Crew',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Optional — you can also assign later',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _teamMembers.map((member) {
                    final uid = member['uid'] as String;
                    final isSelected = _selectedMemberUids.contains(uid);
                    final role = member['role'] as String;
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(member['name'] as String),
                          if (role == 'foreman') ...[
                            const SizedBox(width: 4),
                            Icon(Icons.star, size: 14,
                                color: isSelected ? Colors.white : Colors.orange[700]),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedMemberUids.add(uid);
                          } else {
                            _selectedMemberUids.remove(uid);
                          }
                        });
                      },
                      avatar: Icon(Icons.person, size: 18,
                          color: isSelected ? Colors.white : Colors.grey[600]),
                      selectedColor: Theme.of(context).colorScheme.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[800],
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Assign Subcontractors
              if (_subcontractors.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Assign Subs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Optional — you can also assign later',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _subcontractors.map((sub) {
                    final id = sub['id'] as String;
                    final isSelected = _selectedSubIds.contains(id);
                    return FilterChip(
                      label: Text(sub['company_name'] as String),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSubIds.add(id);
                          } else {
                            _selectedSubIds.remove(id);
                          }
                        });
                      },
                      avatar: Icon(Icons.engineering, size: 18,
                          color: isSelected ? Colors.white : Colors.grey[600]),
                      selectedColor: const Color(0xFFFF6B35),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[800],
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 32),

              // Create button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createProject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Project',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
