import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ContractorPublicProfile extends StatelessWidget {
  final String contractorId;

  const ContractorPublicProfile({
    super.key,
    required this.contractorId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(contractorId)
            .get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Contractor not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final contractorProfile =
              userData['contractor_profile'] as Map<String, dynamic>?;

          if (contractorProfile == null) {
            return const Center(child: Text('Invalid contractor profile'));
          }

          final businessName = contractorProfile['business_name'] ?? 'Contractor';
          final ownerName = contractorProfile['owner_name'] ?? '';
          final phone = contractorProfile['phone'] ?? '';
          final logoUrl = contractorProfile['logo_url'] as String?;
          final specialties = (contractorProfile['specialties'] as List?)
                  ?.cast<String>() ??
              [];
          final ratingAverage = contractorProfile['rating_average'] ?? 0.0;
          final totalReviews = contractorProfile['total_reviews'] ?? 0;

          return CustomScrollView(
            slivers: [
              // Header with business info
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          // Logo
                          if (logoUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: Image.network(
                                logoUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultLogo();
                                },
                              ),
                            )
                          else
                            _buildDefaultLogo(),
                          const SizedBox(height: 12),
                          Text(
                            businessName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (ownerName.isNotEmpty)
                            Text(
                              ownerName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Business info card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rating
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                ratingAverage.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '($totalReviews ${totalReviews == 1 ? 'review' : 'reviews'})',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Specialties
                          if (specialties.isNotEmpty) ...[
                            Text(
                              'Specialties',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: specialties.map((specialty) {
                                return Chip(
                                  label: Text(specialty),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Contact button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showContactDialog(
                                context,
                                businessName,
                                phone,
                              ),
                              icon: const Icon(Icons.phone),
                              label: const Text('Contact'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Portfolio section header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    'Portfolio',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),

              // Portfolio grid
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('projects')
                    .where('contractor_ref',
                        isEqualTo: FirebaseFirestore.instance
                            .collection('users')
                            .doc(contractorId))
                    .where('status', isEqualTo: 'completed')
                    .snapshots(),
                builder: (context, projectSnapshot) {
                  if (projectSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  if (!projectSnapshot.hasData ||
                      projectSnapshot.data!.docs.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No completed projects yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final projects = projectSnapshot.data!.docs;

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final project = projects[index].data()
                              as Map<String, dynamic>;
                          final projectId = projects[index].id;

                          return _PortfolioProjectCard(
                            projectId: projectId,
                            project: project,
                          );
                        },
                        childCount: projects.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDefaultLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
      ),
      child: const Icon(
        Icons.business,
        size: 50,
        color: Colors.grey,
      ),
    );
  }

  void _showContactDialog(
      BuildContext context, String businessName, String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact $businessName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phone.isNotEmpty) ...[
              const Text('Phone:'),
              const SizedBox(height: 8),
              SelectableText(
                phone,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final tel = 'tel:${phone.replaceAll(RegExp(r'[^0-9]'), '')}';
                    launchUrl(Uri.parse(tel));
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Call Now'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else
              const Text('Contact information not available'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _PortfolioProjectCard extends StatelessWidget {
  final String projectId;
  final Map<String, dynamic> project;

  const _PortfolioProjectCard({
    required this.projectId,
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('updates')
          .orderBy('created_at', descending: false)
          .limit(1)
          .snapshots(),
      builder: (context, updateSnapshot) {
        String? firstPhotoUrl;
        if (updateSnapshot.hasData && updateSnapshot.data!.docs.isNotEmpty) {
          final firstUpdate =
              updateSnapshot.data!.docs.first.data() as Map<String, dynamic>;
          firstPhotoUrl = firstUpdate['photo_url'] as String?;
        }

        return GestureDetector(
          onTap: () {
            _showProjectDialog(context);
          },
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: firstPhotoUrl != null
                        ? Image.network(
                            firstPhotoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.image_not_supported,
                                size: 50,
                                color: Colors.grey[400],
                              );
                            },
                          )
                        : Icon(
                            Icons.photo_library_outlined,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                  ),
                ),
                // Project info
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          project['project_name'] ?? 'Untitled',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProjectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ProjectDetailsDialog(
        projectId: projectId,
        project: project,
      ),
    );
  }
}

class _ProjectDetailsDialog extends StatelessWidget {
  final String projectId;
  final Map<String, dynamic> project;

  const _ProjectDetailsDialog({
    required this.projectId,
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      project['project_name'] ?? 'Untitled Project',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Photo gallery
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('projects')
                    .doc(projectId)
                    .collection('updates')
                    .orderBy('created_at', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No photos',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  final updates = snapshot.data!.docs;

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: updates.length,
                    itemBuilder: (context, index) {
                      final update =
                          updates[index].data() as Map<String, dynamic>;
                      final photoUrl = update['photo_url'] as String?;

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: photoUrl != null
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.grey[400],
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.image,
                                  color: Colors.grey[400],
                                ),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
