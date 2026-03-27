import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Full client demo preview — tabbed experience with real GC branding + sample data
/// GC uses this in bid meetings to show clients what the app looks like.
class PreviewHomeDesign3 extends StatefulWidget {
  const PreviewHomeDesign3({super.key});

  @override
  State<PreviewHomeDesign3> createState() => _PreviewHomeDesign3State();
}

class _PreviewHomeDesign3State extends State<PreviewHomeDesign3>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _businessName = 'Your Business';
  String _ownerName = 'You';
  String _firstName = 'You';
  String _phone = '';
  double _rating = 0;
  int _totalReviews = 0;
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadGcProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGcProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data == null) return;
      final profile =
          data['contractor_profile'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _businessName =
              profile['business_name'] as String? ?? 'Your Business';
          _ownerName = profile['owner_name'] as String? ?? 'You';
          _firstName = _ownerName.split(' ').first;
          _phone = profile['phone'] as String? ?? '';
          _rating = (profile['rating_average'] as num?)?.toDouble() ?? 0;
          _totalReviews = profile['total_reviews'] as int? ?? 0;
          _logoUrl = profile['logo_url'] as String?;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Kitchen Remodel'),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Preview banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: const Color(0xFFF59E0B).withOpacity(0.15),
            child: Row(
              children: [
                Icon(Icons.visibility, size: 16, color: Colors.amber[800]),
                const SizedBox(width: 8),
                Text(
                  'Demo Mode — Show this to your client',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.amber[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Contractor branding bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                _buildLogo(36, 16, 8),
                const SizedBox(width: 10),
                Text(
                  _businessName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const Spacer(),
                Text(
                  'Sarah Smith',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF2D3748),
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: const Color(0xFFFF6B35),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Home'),
                Tab(text: 'Photos'),
                Tab(text: 'Milestones'),
                Tab(text: 'Chat'),
                Tab(text: 'Budget'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHomeTab(),
                _buildPhotosTab(),
                _buildMilestonesTab(),
                _buildChatTab(),
                _buildBudgetTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SHARED
  // ===========================================================================

  Widget _buildLogo(double size, double fontSize, double radius) {
    if (_logoUrl != null && _logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          _logoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialAvatar(size, fontSize, radius),
        ),
      );
    }
    return _buildInitialAvatar(size, fontSize, radius);
  }

  Widget _buildInitialAvatar(double size, double fontSize, double radius) {
    final initial =
        _businessName.isNotEmpty ? _businessName[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2D3748).withOpacity(0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2D3748),
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(16, 0, 16, 14),
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
      child: child,
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  // ===========================================================================
  // TAB 1: HOME
  // ===========================================================================

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // Progress hero
          _card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                SizedBox(
                  height: 120,
                  width: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 120,
                        width: 120,
                        child: CircularProgressIndicator(
                          value: 0.6,
                          strokeWidth: 10,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF6B35)),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('3 of 5',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748))),
                          Text('milestones',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Great progress, Sarah!',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748))),
                const SizedBox(height: 4),
                Text('Your kitchen remodel is more than halfway there',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 12),
                _buildSegmentedBar(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  children: [
                    _legendDot(const Color(0xFF10B981), 'Done'),
                    _legendDot(const Color(0xFF3B82F6), 'Active'),
                    _legendDot(const Color(0xFFF59E0B), 'Review'),
                    _legendDot(Colors.grey[300]!, 'Pending'),
                  ],
                ),
              ],
            ),
          ),

          // Action items
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Needs Your Attention',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748))),
                const SizedBox(height: 14),
                _actionItem(
                  '\u{1F4B5}',
                  'Demo milestone ready for approval',
                  '$_firstName completed demolition work',
                  const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 10),
                _actionItem(
                  '\u{1F50C}',
                  'Change order needs review',
                  '"Add outlet in pantry for microwave" \u{2022} +\$150',
                  const Color(0xFF3B82F6),
                ),
              ],
            ),
          ),

          // Coming up
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Coming Up This Week',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748))),
                const SizedBox(height: 14),
                _scheduleRow('\u{1F6BF}', 'Plumbing rough-in starts', 'Monday'),
                const SizedBox(height: 10),
                _scheduleRow(
                    '\u{1F4E6}', 'Drywall delivery scheduled', 'Thursday'),
              ],
            ),
          ),

          // Contractor card
          _buildContractorCard(),

          const SizedBox(height: 8),
          Center(
            child: Text('Powered by ProjectPulse',
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSegmentedBar() {
    final statuses = [
      const Color(0xFF10B981),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      Colors.grey[300]!,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 8,
        child: Row(
          children: statuses.asMap().entries.map((e) {
            return Expanded(
              child: Container(
                margin:
                    EdgeInsets.only(right: e.key < statuses.length - 1 ? 2 : 0),
                color: e.value,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _actionItem(String emoji, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF2D3748))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleRow(String emoji, String title, String day) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2D3748))),
        ),
        Text(day,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: PHOTOS
  // ===========================================================================

  Widget _buildPhotosTab() {
    final photos = [
      _SamplePhoto(
        caption: 'Backsplash tile installed! White subway with dark grout. Really pulls the room together.',
        postedBy: _firstName,
        timeAgo: '2 hours ago',
        color: const Color(0xFF8B7355),
        icon: Icons.kitchen,
      ),
      _SamplePhoto(
        caption: 'Countertops measured and templated. Going with Calacatta Gold — going to look incredible.',
        postedBy: _firstName,
        timeAgo: '1 day ago',
        color: const Color(0xFF607D8B),
        icon: Icons.straighten,
      ),
      _SamplePhoto(
        caption: 'Electrical rough-in complete. All new circuits for appliances, under-cabinet lighting wired.',
        postedBy: _firstName,
        timeAgo: '3 days ago',
        color: const Color(0xFFF59E0B),
        icon: Icons.electrical_services,
      ),
      _SamplePhoto(
        caption: 'Demo day! Old cabinets, countertops, and flooring removed. Ready for the new layout.',
        postedBy: _firstName,
        timeAgo: '1 week ago',
        color: const Color(0xFFEF4444),
        icon: Icons.construction,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final p = photos[index];
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sample photo placeholder
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: p.color.withOpacity(0.15),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p.icon, size: 48, color: p.color.withOpacity(0.5)),
                      const SizedBox(height: 8),
                      Text(
                        'Photo Update',
                        style: TextStyle(
                          color: p.color.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.camera_alt,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(p.postedBy,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(p.timeAgo,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(p.caption,
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: Color(0xFF2D3748))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 3: MILESTONES
  // ===========================================================================

  Widget _buildMilestonesTab() {
    final milestones = [
      _SampleMilestone('Demo & Haul Away', 'approved', '\$4,000'),
      _SampleMilestone('Rough Plumbing & Electrical', 'approved', '\$6,500'),
      _SampleMilestone('Cabinets & Countertops', 'awaiting_approval', '\$12,000'),
      _SampleMilestone('Painting & Tile', 'in_progress', '\$3,500'),
      _SampleMilestone('Appliances & Final Touches', 'pending', '\$4,000'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress card
        _card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Project Phases',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748))),
                  const Text('60%',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748))),
                ],
              ),
              const SizedBox(height: 4),
              Text('3 of 5 milestones complete',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 14),
              _buildSegmentedBar(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                children: [
                  _legendDot(const Color(0xFF10B981), 'Done'),
                  _legendDot(const Color(0xFF3B82F6), 'Active'),
                  _legendDot(const Color(0xFFF59E0B), 'Review'),
                  _legendDot(Colors.grey[300]!, 'Pending'),
                ],
              ),
            ],
          ),
        ),

        // Milestone cards
        ...milestones.asMap().entries.map((entry) {
          final i = entry.key;
          final m = entry.value;

          String emoji;
          Color color;
          String label;
          switch (m.status) {
            case 'approved':
              emoji = '\u{2705}';
              color = const Color(0xFF10B981);
              label = 'Completed';
              break;
            case 'in_progress':
              emoji = '\u{1F528}';
              color = const Color(0xFF3B82F6);
              label = 'In Progress';
              break;
            case 'awaiting_approval':
              emoji = '\u{23F3}';
              color = const Color(0xFFF59E0B);
              label = 'Awaiting Your Approval';
              break;
            default:
              emoji = '\u{23F1}\u{FE0F}';
              color = Colors.grey;
              label = 'Coming Up';
          }

          final isActive =
              m.status == 'in_progress' || m.status == 'awaiting_approval';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border:
                  isActive ? Border.all(color: color.withOpacity(0.3)) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: m.status == 'approved'
                                    ? Colors.grey[500]
                                    : const Color(0xFF2D3748),
                                decoration: m.status == 'approved'
                                    ? TextDecoration.lineThrough
                                    : null,
                              )),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text('Phase ${i + 1} of 5',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500])),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(label,
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(m.amount,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: m.status == 'approved'
                              ? const Color(0xFF10B981)
                              : const Color(0xFF2D3748),
                        )),
                  ],
                ),
                if (m.status == 'awaiting_approval') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('View Photos'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: CHAT
  // ===========================================================================

  Widget _buildChatTab() {
    final messages = [
      _SampleMessage(
          true, 'Hi $_firstName! When will the countertops be installed?'),
      _SampleMessage(false,
          'Hey Sarah! Template is done, fabrication takes about 10 days. Targeting the week of the 24th.'),
      _SampleMessage(true, 'Perfect, thanks! Can we add under-cabinet lighting?'),
      _SampleMessage(false,
          'Absolutely! I\'ll put together a change order for that. Should be around \$400-500 for LED strips.'),
      _SampleMessage(true, 'Sounds good, send it over'),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              return Align(
                alignment:
                    msg.isClient ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: msg.isClient
                        ? const Color(0xFF2D3748)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight:
                          msg.isClient ? const Radius.circular(4) : null,
                      bottomLeft:
                          !msg.isClient ? const Radius.circular(4) : null,
                    ),
                    boxShadow: [
                      if (!msg.isClient)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!msg.isClient)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(_firstName,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[500])),
                        ),
                      Text(
                        msg.text,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: msg.isClient
                              ? Colors.white
                              : const Color(0xFF2D3748),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text('Ask a question...',
                      style: TextStyle(color: Colors.grey[400], fontSize: 15)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF2D3748),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 5: BUDGET
  // ===========================================================================

  Widget _buildBudgetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary
          _card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Project Budget',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748))),
                const SizedBox(height: 16),
                _budgetRow('Original contract:', '\$30,000'),
                const SizedBox(height: 8),
                _budgetRow('Change orders (1):', '+\$150',
                    valueColor: const Color(0xFF10B981)),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _budgetRow('Current total:', '\$30,150', isBold: true),
              ],
            ),
          ),

          // Payment progress
          _card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment Progress',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748))),
                const SizedBox(height: 16),
                _paymentRow(
                    '\u{2705}', 'Demo & Haul Away', '\$4,000', 'Paid'),
                const SizedBox(height: 10),
                _paymentRow('\u{2705}', 'Rough Plumbing & Electrical',
                    '\$6,500', 'Paid'),
                const SizedBox(height: 10),
                _paymentRow('\u{23F3}', 'Cabinets & Countertops', '\$12,000',
                    'Awaiting approval'),
                const SizedBox(height: 10),
                _paymentRow('\u{1F528}', 'Painting & Tile', '\$3,500',
                    'In progress'),
                const SizedBox(height: 10),
                _paymentRow('\u{23F1}\u{FE0F}', 'Appliances & Final',
                    '\$4,000', 'Upcoming'),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _budgetRow('Paid so far:', '\$10,500',
                    valueColor: const Color(0xFF10B981)),
                const SizedBox(height: 4),
                _budgetRow('Remaining:', '\$19,650'),
              ],
            ),
          ),

          // Contractor card
          _buildContractorCard(),
        ],
      ),
    );
  }

  Widget _budgetRow(String label, String amount,
      {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: isBold ? 15 : 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: Colors.grey[700],
            )),
        Text(amount,
            style: TextStyle(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ??
                  (isBold ? const Color(0xFF2D3748) : Colors.grey[800]),
            )),
      ],
    );
  }

  Widget _paymentRow(
      String emoji, String name, String amount, String status) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2D3748))),
              Text(status,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
        Text(amount,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748))),
      ],
    );
  }

  // ===========================================================================
  // CONTRACTOR CARD (reused across tabs)
  // ===========================================================================

  Widget _buildContractorCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Contractor',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748))),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildLogo(48, 20, 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_businessName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3748))),
                    if (_rating > 0 && _totalReviews > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                              '${_rating.toStringAsFixed(1)} \u{2022} $_totalReviews reviews',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_phone.isNotEmpty)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.phone, size: 16),
                    label: Text('Call $_firstName'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D3748),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              if (_phone.isNotEmpty) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.message, size: 16),
                  label: const Text('Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Sample data classes
// =============================================================================

class _SamplePhoto {
  final String caption;
  final String postedBy;
  final String timeAgo;
  final Color color;
  final IconData icon;
  const _SamplePhoto({
    required this.caption,
    required this.postedBy,
    required this.timeAgo,
    required this.color,
    required this.icon,
  });
}

class _SampleMilestone {
  final String name;
  final String status;
  final String amount;
  const _SampleMilestone(this.name, this.status, this.amount);
}

class _SampleMessage {
  final bool isClient;
  final String text;
  const _SampleMessage(this.isClient, this.text);
}
