import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Displays contractor branding and info on client-facing screens
class ContractorInfoCard extends StatefulWidget {
  final Map<String, dynamic> projectData;
  final bool compact;

  const ContractorInfoCard({
    super.key,
    required this.projectData,
    this.compact = false,
  });

  @override
  State<ContractorInfoCard> createState() => _ContractorInfoCardState();
}

class _ContractorInfoCardState extends State<ContractorInfoCard> {
  Map<String, dynamic>? _contractorData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchContractorData();
  }

  @override
  void didUpdateWidget(ContractorInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch if project changed (different contractor_ref)
    final oldRef = oldWidget.projectData['contractor_ref'];
    final newRef = widget.projectData['contractor_ref'];
    if (oldRef != newRef) {
      _fetchContractorData();
    }
  }

  Future<void> _fetchContractorData() async {
    try {
      final contractorRef = widget.projectData['contractor_ref'] as DocumentReference?;
      if (contractorRef == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final contractorUserDoc = await contractorRef.get();
      if (!contractorUserDoc.exists) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userData = contractorUserDoc.data() as Map<String, dynamic>?;
      final profile = userData?['contractor_profile'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _contractorData = profile;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_contractorData == null) {
      return const SizedBox.shrink();
    }

    final contractorData = _contractorData!;
    final businessName = contractorData['business_name'] as String? ?? 'Contractor';
    final ownerName = contractorData['owner_name'] as String?;
    final phone = contractorData['phone'] as String?;
    final logoUrl = contractorData['logo_url'] as String?;
    final specialties = contractorData['specialties'] as List<dynamic>?;
    final rating = contractorData['rating_average'] as num?;
    final totalReviews = contractorData['total_reviews'] as int?;

    if (widget.compact) {
      return _buildCompactCard(
        context,
        businessName,
        logoUrl,
        rating,
        totalReviews,
      );
    }

    return _buildFullCard(
      context,
      businessName,
      ownerName,
      phone,
      logoUrl,
      specialties,
      rating,
      totalReviews,
    );
  }

  Widget _buildCompactCard(
    BuildContext context,
    String businessName,
    String? logoUrl,
    num? rating,
    int? totalReviews,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo
          _buildLogo(logoUrl, size: 40),
          const SizedBox(width: 12),
          // Business name and rating
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  businessName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (rating != null && totalReviews != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.amber[700],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${rating.toStringAsFixed(1)} ($totalReviews)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // "Powered by" badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'ProjectPulse',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullCard(
    BuildContext context,
    String businessName,
    String? ownerName,
    String? phone,
    String? logoUrl,
    List<dynamic>? specialties,
    num? rating,
    int? totalReviews,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Logo
              _buildLogo(logoUrl, size: 60),
              const SizedBox(width: 16),
              // Business info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (ownerName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        ownerName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (rating != null && totalReviews != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber[700],
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${rating.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            ' ($totalReviews reviews)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Specialties
          if (specialties != null && specialties.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: specialties.map((specialty) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    specialty.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Contact info
          if (phone != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.phone,
                  size: 18,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          // Powered by ProjectPulse badge
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Powered by ProjectPulse',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(String? logoUrl, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(size / 4),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: logoUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size / 4),
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) {
                  return _buildDefaultLogo(size);
                },
              ),
            )
          : _buildDefaultLogo(size),
    );
  }

  Widget _buildDefaultLogo(double size) {
    return Icon(
      Icons.business,
      size: size * 0.5,
      color: Colors.grey[400],
    );
  }
}
