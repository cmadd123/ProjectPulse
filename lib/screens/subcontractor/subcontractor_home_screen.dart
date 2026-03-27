import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/auth_utils.dart';
import '../shared/notification_center_screen.dart';
import 'subcontractor_project_screen.dart';

/// Subcontractor home — Design 3 style
/// Shows assigned projects, today's schedule, COI status, notifications
class SubcontractorHomeScreen extends StatefulWidget {
  const SubcontractorHomeScreen({super.key});

  @override
  State<SubcontractorHomeScreen> createState() =>
      _SubcontractorHomeScreenState();
}

class _SubcontractorHomeScreenState extends State<SubcontractorHomeScreen> {
  String? _teamId;
  String? _subId;
  String _companyName = 'Subcontractor';
  String _trade = '';
  bool _loading = true;
  List<Map<String, dynamic>> _coiAlerts = [];
  List<Map<String, dynamic>> _todaySchedule = [];

  @override
  void initState() {
    super.initState();
    _loadSubProfile();
  }

  Future<void> _loadSubProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data();
      if (data == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final teamId = data['team_id'] as String?;
      final subId = data['sub_id'] as String?;

      if (teamId != null && subId != null) {
        final subDoc = await FirebaseFirestore.instance
            .collection('teams')
            .doc(teamId)
            .collection('subcontractors')
            .doc(subId)
            .get();

        if (subDoc.exists) {
          final subData = subDoc.data()!;
          _companyName = subData['company'] as String? ?? 'Subcontractor';
          _trade = subData['trade'] as String? ?? '';

          // Check COI status
          await _loadCoiAlerts(teamId, subId);
        }

        // Load today's schedule
        await _loadTodaySchedule(teamId, user.uid);
      }

      if (mounted) {
        setState(() {
          _teamId = teamId;
          _subId = subId;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCoiAlerts(String teamId, String subId) async {
    try {
      final coiSnap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('subcontractors')
          .doc(subId)
          .collection('coi')
          .get();

      final alerts = <Map<String, dynamic>>[];
      for (final doc in coiSnap.docs) {
        final data = doc.data();
        final expiryDate = (data['expiry_date'] as Timestamp?)?.toDate();
        if (expiryDate != null) {
          final daysUntilExpiry =
              expiryDate.difference(DateTime.now()).inDays;
          if (daysUntilExpiry <= 30) {
            alerts.add({
              ...data,
              'id': doc.id,
              'days_until_expiry': daysUntilExpiry,
            });
          }
        }
      }

      _coiAlerts = alerts;
    } catch (_) {}
  }

  Future<void> _loadTodaySchedule(String teamId, String uid) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('schedule_entries')
          .where('user_uid', isEqualTo: uid)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      _todaySchedule = snap.docs.map((d) => d.data()).toList();
    } catch (_) {}
  }

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

  Color get _tradeColor =>
      _tradeMeta[_trade]?.$3 ?? const Color(0xFF607D8B);
  IconData get _tradeIcon =>
      _tradeMeta[_trade]?.$2 ?? Icons.build;
  String get _tradeLabel =>
      _tradeMeta[_trade]?.$1 ?? 'Subcontractor';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_teamId == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.engineering, size: 40, color: Colors.grey[400]),
                ),
                const SizedBox(height: 20),
                Text(
                  'No team linked yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask the GC to send you an invite link',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 15),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => confirmLogout(context),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_companyName),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Notification bell
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('recipient_uid', isEqualTo: user.uid)
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              final count = snap.hasData ? snap.data!.docs.length : 0;
              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (count > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B35),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationCenterScreen()),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => confirmLogout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          _buildProfileCard(),
          const SizedBox(height: 12),

          // COI alerts
          if (_coiAlerts.isNotEmpty) ...[
            _buildCoiAlertsCard(),
            const SizedBox(height: 12),
          ],

          // Today's schedule
          if (_todaySchedule.isNotEmpty) ...[
            _buildTodayScheduleCard(),
            const SizedBox(height: 12),
          ],

          // Assigned projects
          _buildProjectsSection(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _tradeColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_tradeIcon, color: _tradeColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _companyName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _tradeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _tradeLabel,
                    style: TextStyle(
                      color: _tradeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoiAlertsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
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
          const Row(
            children: [
              Text('\u{26A0}\u{FE0F}', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'Insurance Alerts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._coiAlerts.map((coi) {
            final type = coi['coverage_type'] as String? ?? 'Insurance';
            final daysLeft = coi['days_until_expiry'] as int;
            final isExpired = daysLeft <= 0;
            final color =
                isExpired ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    isExpired ? Icons.error : Icons.warning_amber,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: color,
                          ),
                        ),
                        Text(
                          isExpired
                              ? 'Expired ${-daysLeft} days ago'
                              : 'Expires in $daysLeft days',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: Navigate to COI upload
                    },
                    child: Text(
                      'Update',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTodayScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              const Text('\u{1F4C5}', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                "Today's Schedule",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('EEE, MMM d').format(DateTime.now()),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._todaySchedule.map((entry) {
            final projectName =
                entry['project_name'] as String? ?? 'Unknown Project';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _tradeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _tradeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      projectName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _tradeColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProjectsSection() {
    if (_teamId == null) return const SizedBox.shrink();

    // Get projects where this sub is assigned
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('assigned_sub_ids', arrayContains: _subId)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
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
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.construction,
                      size: 36, color: Colors.grey[400]),
                ),
                const SizedBox(height: 16),
                Text(
                  'No assigned projects',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The GC will assign you to projects as needed',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Assigned Projects',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
            ...snapshot.data!.docs.map((doc) {
              final project = doc.data() as Map<String, dynamic>;
              return _buildProjectCard(context, doc.id, project);
            }),
          ],
        );
      },
    );
  }

  Widget _buildProjectCard(
      BuildContext context, String projectId, Map<String, dynamic> project) {
    final status = project['status'] ?? 'active';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('milestones')
          .orderBy('order')
          .snapshots(),
      builder: (context, milestonesSnap) {
        final milestones =
            milestonesSnap.hasData ? milestonesSnap.data!.docs : [];
        final completedCount = milestones
            .where((m) => (m.data() as Map)['status'] == 'approved')
            .length;
        final totalCount = milestones.length;
        final progress =
            totalCount > 0 ? completedCount / totalCount : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
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
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubcontractorProjectScreen(
                    projectId: projectId,
                    projectData: project,
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2D3748), Color(0xFF4A5568)],
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                project['project_name'] ?? 'Project',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (totalCount > 0)
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          project['client_name'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        if (totalCount > 0) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor:
                                  Colors.white.withOpacity(0.2),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFF6B35)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'active'
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status == 'active' ? 'Active' : 'Completed',
                            style: TextStyle(
                              color: status == 'active'
                                  ? const Color(0xFF10B981)
                                  : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios,
                            size: 14, color: Colors.grey[300]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
