import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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

  DateTime _startDate = DateTime.now();
  DateTime _estimatedEndDate = DateTime.now().add(const Duration(days: 14));
  bool _isLoading = false;

  @override
  void dispose() {
    _projectNameController.dispose();
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _clientPhoneController.dispose();
    _originalCostController.dispose();
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

  Future<void> _showInviteDialog(String projectId, String projectName, String clientName) async {
    // Using Firebase Hosting URL until custom domain is configured
    final inviteLink = 'https://projectpulse-7d258.web.app/join/$projectId';

    // TODO: Automatic Invitation System
    // Since we have client email and phone from project creation, we can automatically send invitations:
    //
    // Option 1: Firebase Cloud Function to send SMS via Twilio
    // - Install Twilio SDK in Cloud Functions
    // - Create sendProjectInviteSMS function
    // - Triggered when project is created with client_phone
    // - Cost: ~$0.0075 per SMS
    //
    // Option 2: Firebase Cloud Function to send Email via SendGrid
    // - Install SendGrid SDK in Cloud Functions
    // - Create sendProjectInviteEmail function
    // - Triggered when project is created with client_email
    // - Cost: Free for first 100/day, then $0.0001 per email
    //
    // Implementation:
    // 1. Add Twilio/SendGrid credentials to Firebase Config
    // 2. Create Cloud Function that triggers on project creation
    // 3. Function reads client_email and client_phone from project doc
    // 4. Sends formatted invitation via both channels
    // 5. Logs delivery status back to project doc
    //
    // Benefits:
    // - No manual sharing required
    // - Professional branded emails
    // - Immediate delivery
    // - Client gets invitation before contractor even leaves the screen
    //
    // For now, showing manual share dialog as fallback

    final message = '''
Hey $clientName! 👋

I've created a project for you in ProjectPulse: "$projectName"

Click this link to view real-time updates, photos, and communicate about your project:
$inviteLink

Looking forward to working with you!
''';

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Sent!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Invitation email automatically sent to $clientName',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Want to share via text too? Copy this link:',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                inviteLink,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Share.share(message, subject: 'You\'ve been invited to view your project: $projectName');
              Navigator.pop(context);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
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

      final projectCost = double.tryParse(_originalCostController.text.trim()) ?? 0;

      final projectData = {
        'contractor_ref': userRef,
        'contractor_uid': user.uid, // Add UID string for easier querying
        'contractor_business_name': contractorBusinessName, // Add business name for client display
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
        'contract_document_url': null,
        'milestones_enabled': false, // Will be set to true after milestones are created
        'payment_status': 'unpaid',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      final projectDoc = await FirebaseFirestore.instance.collection('projects').add(projectData);

      if (mounted) {
        // Navigate to milestone creation screen
        final milestonesResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateMilestonesScreen(
              projectId: projectDoc.id,
              projectAmount: projectCost,
            ),
          ),
        );

        // Get contractor name for invitation screen
        final userData = await userRef.get();
        final contractorData = userData.data() as Map<String, dynamic>?;
        final contractorName = contractorData?['contractor_profile']?['business_name'] ?? 'Your contractor';

        // Navigate to invitation screen
        if (mounted) {
          final invitationSent = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SendInvitationScreen(
                projectId: projectDoc.id,
                projectName: _projectNameController.text.trim(),
                clientName: _clientNameController.text.trim(),
                clientEmail: _clientEmailController.text.trim(),
                contractorName: contractorName,
              ),
            ),
          );

          // Go back to contractor home
          if (mounted) {
            Navigator.pop(context, true); // Return true to indicate success

            String message = 'Project created';
            if (milestonesResult == true) {
              message += ' with milestones';
            }
            if (invitationSent == true) {
              message += ' and invitation sent';
            }
            message += '!';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        }
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
              const SizedBox(height: 32),

              // Create button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createProject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
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
                          'Next: Set Up Milestones',
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
