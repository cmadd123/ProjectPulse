import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class ContractorProfileScreen extends StatefulWidget {
  const ContractorProfileScreen({super.key});

  @override
  State<ContractorProfileScreen> createState() => _ContractorProfileScreenState();
}

class _ContractorProfileScreenState extends State<ContractorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();

  final List<String> _allSpecialties = [
    'Kitchen',
    'Bathroom',
    'General',
    'Plumbing',
    'Electrical',
    'HVAC',
    'Roofing',
    'Flooring',
    'Painting',
    'Carpentry',
  ];

  List<String> _selectedSpecialties = [];
  bool _isLoading = false;
  File? _logoFile;
  String? _existingLogoUrl;
  Color _brandColor = const Color(0xFFFF6B35);
  Color? _extractedLogoColor; // Auto-extracted from logo
  bool _isExtractingColor = false;
  bool _isSoloContractor = false;

  static const List<Color> _presetColors = [
    Color(0xFFFF6B35), // Construction Orange
    Color(0xFF2563EB), // Blue
    Color(0xFF059669), // Green
    Color(0xFFDC2626), // Red
    Color(0xFF7C3AED), // Purple
    Color(0xFFD97706), // Amber
    Color(0xFF0891B2), // Teal
    Color(0xFFBE185D), // Pink
    Color(0xFF4F46E5), // Indigo
    Color(0xFF374151), // Charcoal
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data()?['contractor_profile'] != null) {
      final profile = doc.data()!['contractor_profile'] as Map<String, dynamic>;
      setState(() {
        _businessNameController.text = profile['business_name'] ?? '';
        _ownerNameController.text = profile['owner_name'] ?? '';
        _phoneController.text = profile['phone'] ?? '';
        _selectedSpecialties = List<String>.from(profile['specialties'] ?? []);
        _existingLogoUrl = profile['logo_url'] as String?;
        final colorHex = profile['brand_color'] as String?;
        if (colorHex != null && colorHex.isNotEmpty) {
          _brandColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
        }
        _isSoloContractor = profile['is_solo'] == true;
      });
      // Extract color from existing logo for the "Recommended" swatch
      if (_existingLogoUrl != null) {
        _extractColorFromUrl(_existingLogoUrl!);
      }
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (pickedFile != null) {
      setState(() {
        _logoFile = File(pickedFile.path);
      });
      _extractColorFromFile(File(pickedFile.path));
    }
  }

  Future<void> _extractColorFromFile(File file) async {
    setState(() => _isExtractingColor = true);
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: FileImage(file),
      );
      if (mounted) {
        setState(() {
          _extractedLogoColor = scheme.primary;
          _brandColor = scheme.primary;
          _isExtractingColor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isExtractingColor = false);
    }
  }

  Future<void> _extractColorFromUrl(String url) async {
    setState(() => _isExtractingColor = true);
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: NetworkImage(url),
      );
      if (mounted) {
        setState(() {
          _extractedLogoColor = scheme.primary;
          _isExtractingColor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isExtractingColor = false);
    }
  }

  void _shareProfile() {
    final user = FirebaseAuth.instance.currentUser!;
    final businessName = _businessNameController.text.trim().isEmpty
        ? 'Contractor'
        : _businessNameController.text.trim();

    final profileLink = 'https://projectpulse.app/contractor/${user.uid}';

    final message = '''
Check out my business profile on ProjectPulse!

$businessName

View my portfolio, reviews, and contact me for your next project:
$profileLink
''';

    Share.share(
      message,
      subject: '$businessName on ProjectPulse',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile link shared!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSpecialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one specialty')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Upload logo to Firebase Storage if a new file was picked
      String? logoUrl = _existingLogoUrl;
      if (_logoFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('contractor_logos')
            .child('${user.uid}.jpg');
        await ref.putFile(
          _logoFile!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        logoUrl = await ref.getDownloadURL();
      }

      // Convert brand color to hex string for storage (always 6 chars RGB)
      final brandColorHex = '#${_brandColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

      // Use dot-notation to update only these fields, preserving
      // rating_average, total_reviews, and any other existing fields
      final updates = <String, dynamic>{
        'contractor_profile.business_name': _businessNameController.text.trim(),
        'contractor_profile.owner_name': _ownerNameController.text.trim(),
        'contractor_profile.phone': _phoneController.text.trim(),
        'contractor_profile.specialties': _selectedSpecialties,
        'contractor_profile.brand_color': brandColorHex,
        'contractor_profile.is_solo': _isSoloContractor,
        'contractor_profile.subscription_tier': 'free',
        'contractor_profile.subscription_status': 'active',
      };
      if (logoUrl != null) {
        updates['contractor_profile.logo_url'] = logoUrl;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updates);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
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

  Widget _previewNavItem(IconData icon, String label, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: active ? _brandColor : Colors.grey[400],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: active ? _brandColor : Colors.grey[400],
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contractor Profile'),
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
              onPressed: _saveProfile,
              child: const Text('Save', style: TextStyle(fontSize: 16)),
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
              // Logo picker
              Center(
                child: GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: _logoFile != null
                        ? ClipOval(
                            child: Image.file(
                              _logoFile!,
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                            ),
                          )
                        : _existingLogoUrl != null
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: _existingLogoUrl!,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.add_photo_alternate,
                                    size: 40,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.add_photo_alternate,
                                size: 40,
                                color: Colors.grey[600],
                              ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _logoFile != null || _existingLogoUrl != null
                      ? 'Tap to change logo'
                      : 'Tap to add logo',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 32),

              // Business name
              TextFormField(
                controller: _businessNameController,
                decoration: InputDecoration(
                  labelText: 'Business Name *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your business name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Owner name
              TextFormField(
                controller: _ownerNameController,
                decoration: InputDecoration(
                  labelText: 'Owner Name *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Solo contractor toggle
              InkWell(
                onTap: () => setState(() => _isSoloContractor = !_isSoloContractor),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _isSoloContractor ? Colors.blue[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSoloContractor ? Colors.blue[300]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSoloContractor ? Icons.person : Icons.groups,
                        color: _isSoloContractor ? Colors.blue[700] : Colors.grey[600],
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSoloContractor ? 'Solo Contractor' : 'I have a crew',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: _isSoloContractor ? Colors.blue[800] : Colors.grey[800],
                              ),
                            ),
                            Text(
                              _isSoloContractor
                                  ? 'Schedule and team features hidden'
                                  : 'Manage crew schedules and assignments',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isSoloContractor,
                        onChanged: (v) => setState(() => _isSoloContractor = v),
                        activeColor: Colors.blue[600],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Specialties
              Text(
                'Specialties *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allSpecialties.map((specialty) {
                  final isSelected = _selectedSpecialties.contains(specialty);
                  return FilterChip(
                    label: Text(specialty),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSpecialties.add(specialty);
                        } else {
                          _selectedSpecialties.remove(specialty);
                        }
                      });
                    },
                    selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Brand color picker
              Text(
                'Brand Color',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your clients will see this color on their dashboard',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 12),

              // Extracted color recommendation
              if (_isExtractingColor)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Extracting color from your logo...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                )
              else if (_extractedLogoColor != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () => setState(() => _brandColor = _extractedLogoColor!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _brandColor.value == _extractedLogoColor!.value
                            ? _extractedLogoColor!.withOpacity(0.1)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _brandColor.value == _extractedLogoColor!.value
                              ? _extractedLogoColor!
                              : Colors.grey[300]!,
                          width: _brandColor.value == _extractedLogoColor!.value ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _extractedLogoColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black12),
                            ),
                            child: _brandColor.value == _extractedLogoColor!.value
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Recommended from your logo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _brandColor.value == _extractedLogoColor!.value
                                      ? 'Selected'
                                      : 'Tap to use this color',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Preset color options
              if (_extractedLogoColor != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Or choose a different color:',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presetColors.map((color) {
                  final isSelected = _brandColor.value == color.value;
                  return GestureDetector(
                    onTap: () => setState(() => _brandColor = color),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.grey[300]!,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 22)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Client preview
              Text(
                'Client Preview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'This is how your clients will see their dashboard',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Mini AppBar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: _brandColor,
                      child: Row(
                        children: [
                          // Logo
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: _logoFile != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.file(
                                      _logoFile!,
                                      fit: BoxFit.cover,
                                      width: 28,
                                      height: 28,
                                    ),
                                  )
                                : _existingLogoUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: CachedNetworkImage(
                                          imageUrl: _existingLogoUrl!,
                                          fit: BoxFit.cover,
                                          width: 28,
                                          height: 28,
                                          errorWidget: (_, __, ___) => Icon(
                                            Icons.business,
                                            size: 16,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.business,
                                        size: 16,
                                        color: Colors.grey[400],
                                      ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _businessNameController.text.isEmpty
                                  ? 'Project Name'
                                  : 'Kitchen Remodel',
                              style: TextStyle(
                                color: _brandColor.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.notifications_outlined,
                            size: 20,
                            color: _brandColor.computeLuminance() > 0.5
                                ? Colors.black54
                                : Colors.white70,
                          ),
                        ],
                      ),
                    ),
                    // Mini hero header
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF2D3748),
                            const Color(0xFF4A5568),
                            _brandColor.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Mini progress ring
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: 0.67,
                                    strokeWidth: 3,
                                    backgroundColor: Colors.white24,
                                    color: _brandColor,
                                  ),
                                  const Text(
                                    '67%',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Day 18 of 45',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Mini content area
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          // Fake action card
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, size: 18, color: Colors.green[700]),
                                const SizedBox(width: 8),
                                Text(
                                  "You're all caught up!",
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mini bottom nav
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _previewNavItem(Icons.home, 'Home', true),
                          _previewNavItem(Icons.photo_library, 'Photos', false),
                          _previewNavItem(Icons.chat_bubble_outline, 'Chat', false),
                          _previewNavItem(Icons.flag_outlined, 'Milestones', false),
                          _previewNavItem(Icons.more_horiz, 'More', false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Share Profile button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _shareProfile,
                  icon: const Icon(Icons.share),
                  label: const Text('Share My Public Profile'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Reviews section
              Text(
                'Client Reviews',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('reviews')
                    .orderBy('created_at', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.rate_review_outlined,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No reviews yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final reviews = snapshot.data!.docs;

                  // Calculate average rating
                  final ratings =
                      reviews.map((doc) => (doc.data() as Map)['rating'] as int).toList();
                  final avgRating = ratings.isEmpty
                      ? 0.0
                      : ratings.reduce((a, b) => a + b) / ratings.length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star, size: 40, color: Colors.amber[700]),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  avgRating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[900],
                                  ),
                                ),
                                Text(
                                  '${ratings.length} review${ratings.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Review list
                      ...reviews.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final rating = data['rating'] as int;
                        final reviewText = data['review_text'] as String? ?? '';
                        final clientName = data['client_name'] as String? ?? 'Anonymous';
                        final createdAt = (data['created_at'] as Timestamp?)?.toDate();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      clientName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (index) => Icon(
                                        index < rating ? Icons.star : Icons.star_border,
                                        size: 16,
                                        color: Colors.amber[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (reviewText.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  reviewText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                              if (createdAt != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${createdAt.month}/${createdAt.day}/${createdAt.year}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Save button (mobile-friendly)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
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
                          'Save Profile',
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
