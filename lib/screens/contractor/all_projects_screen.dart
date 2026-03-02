import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'project_details_screen.dart';
import '../../components/skeleton_loader.dart';

/// Full project card list with search/filter — moved from GC home
class AllProjectsScreen extends StatefulWidget {
  final String? initialStatusFilter;
  final List<String>? filterToProjectIds;
  final String? filterLabel;

  const AllProjectsScreen({
    super.key,
    this.initialStatusFilter,
    this.filterToProjectIds,
    this.filterLabel,
  });

  @override
  State<AllProjectsScreen> createState() => _AllProjectsScreenState();
}

class _AllProjectsScreenState extends State<AllProjectsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      _statusFilter = widget.initialStatusFilter!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return DateFormat('MMM d').format(date);
  }

  List<QueryDocumentSnapshot> _filterProjects(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      if (widget.filterToProjectIds != null &&
          !widget.filterToProjectIds!.contains(doc.id)) {
        return false;
      }
      final project = doc.data() as Map<String, dynamic>;
      if (_statusFilter != 'all') {
        final status = project['status'] ?? 'active';
        if (status != _statusFilter) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = (project['project_name'] ?? '').toString().toLowerCase();
        final client = (project['client_name'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !client.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filterLabel != null ? 'Filtered Projects' : 'All Projects'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('contractor_uid', isEqualTo: user.uid)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonProjectList();
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading projects',
                  style: TextStyle(color: Colors.red[600])),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No projects yet'));
          }

          final allDocs = snapshot.data!.docs;
          final filtered = _filterProjects(allDocs);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: filtered.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.filterLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.filter_list,
                                size: 16, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.filterLabel!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search projects...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final filter in [
                          {'key': 'all', 'label': 'All'},
                          {'key': 'active', 'label': 'Active'},
                          {'key': 'completed', 'label': 'Completed'},
                        ]) ...[
                          ChoiceChip(
                            label: Text(filter['label']!),
                            selected: _statusFilter == filter['key'],
                            onSelected: (selected) {
                              if (selected) {
                                setState(
                                    () => _statusFilter = filter['key']!);
                              }
                            },
                            selectedColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.15),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              color: _statusFilter == filter['key']
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[600],
                              fontWeight: _statusFilter == filter['key']
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            showCheckmark: false,
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    if (_searchQuery.isNotEmpty || _statusFilter != 'all')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${filtered.length} of ${allDocs.length} projects',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                );
              }

              final doc = filtered[index - 1];
              final project = doc.data() as Map<String, dynamic>;
              final status = project['status'] ?? 'active';
              final currencyFormat =
                  NumberFormat.currency(symbol: '\$', decimalDigits: 0);
              final currentCost = (project['current_cost'] ??
                      project['original_cost'] ??
                      0)
                  .toDouble();
              final assignedUids =
                  (project['assigned_member_uids'] as List?)
                          ?.cast<String>() ??
                      [];
              final crewCount = assignedUids.length;
              final assignedSubIds =
                  (project['assigned_sub_ids'] as List?)?.cast<String>() ??
                      [];
              final subCount = assignedSubIds.length;
              final updatedAt = project['updated_at'] as Timestamp?;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('projects')
                    .doc(doc.id)
                    .collection('milestones')
                    .orderBy('order')
                    .snapshots(),
                builder: (context, milestonesSnapshot) {
                  final milestones = milestonesSnapshot.hasData
                      ? milestonesSnapshot.data!.docs
                      : [];
                  final completedCount = milestones
                      .where((m) =>
                          (m.data() as Map)['status'] == 'approved')
                      .length;
                  final awaitingCount = milestones
                      .where((m) =>
                          (m.data() as Map)['status'] ==
                          'awaiting_approval')
                      .length;
                  final totalCount = milestones.length;
                  final progress =
                      totalCount > 0 ? completedCount / totalCount : 0.0;

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('projects')
                        .doc(doc.id)
                        .collection('change_orders')
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, coSnapshot) {
                      final pendingCOs =
                          coSnapshot.data?.docs.length ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProjectDetailsScreen(
                                  projectId: doc.id,
                                  projectData: project,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ],
                                  ),
                                  borderRadius:
                                      const BorderRadius.vertical(
                                          top: Radius.circular(16)),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            project['project_name'] ??
                                                'Untitled Project',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight:
                                                  FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          currencyFormat
                                              .format(currentCost),
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight:
                                                FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline,
                                            size: 14,
                                            color: Colors.white
                                                .withOpacity(0.9)),
                                        const SizedBox(width: 4),
                                        Text(
                                          project['client_name'] ??
                                              'No client',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white
                                                .withOpacity(0.9),
                                          ),
                                        ),
                                        if (crewCount > 0) ...[
                                          const SizedBox(width: 12),
                                          Icon(Icons.groups,
                                              size: 14,
                                              color: Colors.white
                                                  .withOpacity(0.9)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$crewCount crew',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white
                                                  .withOpacity(0.9),
                                            ),
                                          ),
                                        ],
                                        if (subCount > 0) ...[
                                          const SizedBox(width: 12),
                                          Icon(Icons.engineering,
                                              size: 14,
                                              color: Colors.white
                                                  .withOpacity(0.9)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$subCount sub${subCount == 1 ? '' : 's'}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white
                                                  .withOpacity(0.9),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (totalCount > 0) ...[
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        child:
                                            LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 6,
                                          backgroundColor: Colors
                                              .white
                                              .withOpacity(0.3),
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                      Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$completedCount of $totalCount milestones complete',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white
                                              .withOpacity(0.9),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4),
                                      decoration: BoxDecoration(
                                        color: status == 'active'
                                            ? Colors.green
                                                .withOpacity(0.1)
                                            : Colors.grey
                                                .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status == 'active'
                                            ? 'Active'
                                            : 'Completed',
                                        style: TextStyle(
                                          color: status == 'active'
                                              ? Colors.green[700]
                                              : Colors.grey[600],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (awaitingCount > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 10,
                                            vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12),
                                        ),
                                        child: Row(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            Icon(Icons.rate_review,
                                                size: 12,
                                                color: Colors
                                                    .orange[700]),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$awaitingCount awaiting',
                                              style: TextStyle(
                                                color: Colors
                                                    .orange[700],
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (pendingCOs > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 10,
                                            vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12),
                                        ),
                                        child: Row(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            Icon(
                                                Icons.request_quote,
                                                size: 12,
                                                color:
                                                    Colors.blue[700]),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$pendingCOs CO pending',
                                              style: TextStyle(
                                                color:
                                                    Colors.blue[700],
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    if (updatedAt != null)
                                      Text(
                                        _formatTimeAgo(
                                            updatedAt.toDate()),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey[400],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
