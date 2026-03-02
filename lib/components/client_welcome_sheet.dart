import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// One-time welcome bottom sheet for clients on their first project view.
/// Shows contractor branding and quick overview of what they can do.
class ClientWelcomeSheet extends StatelessWidget {
  final Map<String, dynamic> projectData;

  const ClientWelcomeSheet({super.key, required this.projectData});

  /// Check if the client has seen the welcome sheet; if not, show it.
  static Future<void> showIfFirstVisit(
      BuildContext context, Map<String, dynamic> projectData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.data()?['hasSeenWelcome'] == true) return;

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ClientWelcomeSheet(projectData: projectData),
    );

    // Mark as seen
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'hasSeenWelcome': true}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final businessName =
        projectData['contractor_business_name'] as String? ?? 'your contractor';
    final contractorRef =
        projectData['contractor_ref'] as DocumentReference?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Contractor logo + name
          if (contractorRef != null)
            FutureBuilder<DocumentSnapshot>(
              future: contractorRef.get(),
              builder: (context, snapshot) {
                final profile = (snapshot.data?.data()
                    as Map<String, dynamic>?)?['contractor_profile'];
                final logoUrl = profile?['logo_url'] as String?;

                return Column(
                  children: [
                    if (logoUrl != null && logoUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: logoUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 72,
                            height: 72,
                            color: Colors.grey[200],
                          ),
                          errorWidget: (_, __, ___) =>
                              _buildFallbackLogo(businessName),
                        ),
                      )
                    else
                      _buildFallbackLogo(businessName),
                    const SizedBox(height: 12),
                  ],
                );
              },
            )
          else
            _buildFallbackLogo(businessName),

          const SizedBox(height: 4),

          Text(
            'Welcome to your project\nwith $businessName!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),

          // Feature bullets
          _buildFeatureRow(
            Icons.photo_library_outlined,
            'See photos and progress updates',
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            Icons.check_circle_outline,
            'Approve milestones when work is complete',
            Colors.green,
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            Icons.chat_bubble_outline,
            'Message your contractor directly',
            Colors.orange,
          ),
          const SizedBox(height: 32),

          // Got it button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackLogo(String name) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'C',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, height: 1.3),
          ),
        ),
      ],
    );
  }
}
