import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:intl/intl.dart';
import 'utils/auth_utils.dart';
import 'screens/contractor/contractor_profile_screen.dart';
import 'screens/contractor/contractor_profile_setup_screen.dart';
import 'screens/contractor/create_project_screen.dart';
import 'screens/contractor/project_details_screen.dart';
import 'screens/contractor/portfolio_screen.dart';
import 'screens/contractor/team_management_screen.dart';
import 'screens/contractor/schedule_screen.dart';
import 'screens/contractor/all_projects_screen.dart';
import 'screens/team_member/team_member_home_screen.dart';
import 'screens/client/client_project_timeline.dart';
import 'screens/client/client_dashboard_screen.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'screens/shared/notification_center_screen.dart';
import 'data/demo_project_data.dart';
import 'components/skeleton_loader.dart';

/// Snappy slide-up + fade page transition (200ms)
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  SlideUpRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeIn,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(
                opacity: curved,
                child: child,
              ),
            );
          },
        );
}

/// Custom page transitions theme that applies the snappy transition on all platforms
class _SnappyTransitionsBuilder extends PageTransitionsBuilder {
  const _SnappyTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 0.06),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(
        opacity: curved,
        child: child,
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize connectivity monitoring
  await ConnectivityService.instance.initialize();

  // Initialize push notifications
  await NotificationService.initialize();
  // Navigator key set after app build via NotificationService.setNavigatorKey

  // Ensure status bar is visible with dark icons on light background
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFF9FAFB),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Hide the navigation bar completely for immersive experience
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [SystemUiOverlay.top], // Keep status bar, hide navbar
  );

  runApp(const ProjectPulseApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ProjectPulseApp extends StatelessWidget {
  const ProjectPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ProjectPulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D3748), // Charcoal
          primary: const Color(0xFF2D3748), // Charcoal - professional, grounded
          secondary: const Color(0xFFFF6B35), // Construction Orange - energy, progress
          tertiary: const Color(0xFF10B981), // Success Green
          error: const Color(0xFFEF4444), // Error Red
          surface: Colors.white,
          background: const Color(0xFFF7FAFC), // Softer background
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SnappyTransitionsBuilder(),
            TargetPlatform.iOS: _SnappyTransitionsBuilder(),
          },
        ),
        scaffoldBackgroundColor: const Color(0xFFF7FAFC),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.black.withOpacity(0.08),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFF2D3748),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2D3748), width: 2),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF4A5568)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      builder: (context, child) {
        return Column(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: ConnectivityService.instance.isOnline,
              builder: (context, online, _) {
                if (online) return const SizedBox.shrink();
                return Material(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    color: Colors.orange[800],
                    child: const SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off,
                              size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Offline — changes will sync when reconnected',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Expanded(child: child!),
          ],
        );
      },
      home: const AuthWrapper(),
    );
  }
}

// Determines which screen to show based on auth state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    // Initialize deep linking and notification key after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deepLinkService.initialize(context);
      NotificationService.setNavigatorKey(navigatorKey);
    });
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          // Check for pending invite after login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _deepLinkService.handlePendingInvite(context);
          });
          return const RoleDetectionScreen();
        }

        // User is not logged in
        return const AuthScreen();
      },
    );
  }
}

// Detects user role and routes to appropriate home screen
class RoleDetectionScreen extends StatefulWidget {
  const RoleDetectionScreen({super.key});

  @override
  State<RoleDetectionScreen> createState() => _RoleDetectionScreenState();
}

class _RoleDetectionScreenState extends State<RoleDetectionScreen> {
  bool _inviteCheckDone = false;

  /// Check if this new user's email matches a pending team invite.
  /// If yes, _linkTeamMember creates the user doc with role: team_member
  /// and the StreamBuilder will automatically pick it up.
  Future<void> _checkForTeamInvite() async {
    if (_inviteCheckDone) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Simple doc read — no collectionGroup query needed
      final email = user.email?.toLowerCase().trim();
      if (email == null || email.isEmpty) {
        if (mounted) setState(() => _inviteCheckDone = true);
        return;
      }

      final inviteDoc = await FirebaseFirestore.instance
          .collection('pending_team_invites')
          .doc(email)
          .get();

      if (inviteDoc.exists) {
        final inviteData = inviteDoc.data()!;
        final teamId = inviteData['team_id'] as String;
        final memberId = inviteData['member_id'] as String;
        final name = inviteData['name'] as String? ?? user.displayName ?? '';
        final role = inviteData['role'] as String? ?? 'worker';
        final assignedProjectIds = (inviteData['assigned_project_ids'] as List<dynamic>?) ?? [];

        final teamRef = FirebaseFirestore.instance.collection('teams').doc(teamId);
        final memberRef = teamRef.collection('members').doc(memberId);

        // Link member doc: set user_uid and status
        await memberRef.update({
          'user_uid': user.uid,
          'status': 'active',
        });

        // Add to team's member_uids
        await teamRef.update({
          'member_uids': FieldValue.arrayUnion([user.uid]),
        });

        // Create user doc with team_member role
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'user_id': user.uid,
          'email': user.email,
          'role': 'team_member',
          'team_id': teamId,
          'team_member_id': memberId,
          'team_member_profile': {
            'name': name,
            'team_role': role,
          },
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Auto-assign to projects the GC pre-selected
        for (final projectId in assignedProjectIds) {
          try {
            await FirebaseFirestore.instance
                .collection('projects')
                .doc(projectId as String)
                .update({
              'assigned_member_uids': FieldValue.arrayUnion([user.uid]),
            });
          } catch (e) {
            debugPrint('Error assigning to project $projectId: $e');
          }
        }

        // Clean up the lookup doc
        await inviteDoc.reference.delete();

        debugPrint('Auto-linked team member via email lookup (${assignedProjectIds.length} projects)');
        // StreamBuilder will auto-detect the new role
      }
    } catch (e) {
      debugPrint('Error checking team invite: $e');
    }

    if (mounted) {
      setState(() => _inviteCheckDone = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user doc exists with a role, route immediately
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final role = data?['role'] as String?;

          if (role == 'contractor') {
            return const ContractorHomeScreen();
          } else if (role == 'team_member') {
            return const TeamMemberHomeScreen();
          } else if (role == 'client') {
            return const ClientDashboardScreen();
          }
        }

        // No user doc or no role — check for pending team invite first
        if (!_inviteCheckDone) {
          // Kick off the invite check (runs once)
          _checkForTeamInvite();

          // Show loading while checking
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Setting up your account...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        // Invite check is done and no role was set — show role selection
        return const RoleSelectionScreen();
      },
    );
  }
}

// Auth screen (Login/Signup)
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showForgotPassword() {
    final resetController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email and we\'ll send a reset link.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetController.text.trim();
              if (email.isEmpty) return;
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset email sent! Check your inbox.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message ?? 'Error sending reset email')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Authentication failed')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo placeholder
                Icon(
                  Icons.home_repair_service,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'ProjectPulse',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Beautiful project communication',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 48),

                // Email field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Password field
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitAuth,
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
                        : Text(
                            _isLogin ? 'Sign In' : 'Create Account',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Forgot password (login mode only)
                if (_isLogin)
                  TextButton(
                    onPressed: _showForgotPassword,
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),

                // Toggle login/signup
                TextButton(
                  onPressed: () {
                    setState(() => _isLogin = !_isLogin);
                  },
                  child: Text(
                    _isLogin
                        ? 'Need an account? Sign up'
                        : 'Have an account? Sign in',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Role selection screen
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = false;

  Future<void> _selectRole(String role) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser!;

    try {
      // If contractor, show profile setup screen first
      if (role == 'contractor') {
        if (mounted) {
          final profileData = await Navigator.push<Map<String, String>>(
            context,
            MaterialPageRoute(
              builder: (context) => const ContractorProfileSetupScreen(),
            ),
          );

          if (profileData == null) {
            // User cancelled
            setState(() => _isLoading = false);
            return;
          }

          final businessName = profileData['business_name'] ?? 'My Business';
          final ownerName = profileData['owner_name'] ?? user.displayName ?? '';

          // Create the team first
          final teamRef = await FirebaseFirestore.instance.collection('teams').add({
            'owner_uid': user.uid,
            'name': businessName,
            'member_uids': [user.uid],
            'created_at': FieldValue.serverTimestamp(),
          });

          // Add owner as first team member
          await teamRef.collection('members').doc(user.uid).set({
            'name': ownerName,
            'email': user.email,
            'role': 'owner',
            'added_at': FieldValue.serverTimestamp(),
            'status': 'active',
          });

          // Save user with contractor profile + team reference
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'user_id': user.uid,
            'email': user.email,
            'role': role,
            'team_id': teamRef.id,
            'contractor_profile': {
              'business_name': businessName,
              'owner_name': ownerName,
              'phone': profileData['phone'] ?? '',
              'specialties': [],
              'rating_average': 0.0,
              'total_reviews': 0,
            },
            'created_at': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Client - just save basic info
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'user_id': user.uid,
          'email': user.email,
          'role': role,
          'client_profile': {
            'name': user.displayName ?? '',
            'phone': '',
            'accessible_projects': [],
          },
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      // Navigation will happen automatically via AuthWrapper stream
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
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'I am a...',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 48),

                  // Contractor button
                  _RoleCard(
                    icon: Icons.construction,
                    title: 'Contractor',
                    description: 'I work on construction projects',
                    color: Theme.of(context).colorScheme.primary,
                    onTap: _isLoading ? () {} : () => _selectRole('contractor'),
                  ),
                  const SizedBox(height: 24),

                  // Client button
                  _RoleCard(
                    icon: Icons.person,
                    title: 'Client',
                    description: 'I\'m hiring a contractor',
                    color: Theme.of(context).colorScheme.secondary,
                    onTap: _isLoading ? () {} : () => _selectRole('client'),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 40),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color),
          ],
        ),
      ),
    );
  }
}

// Contractor home screen - checks if profile exists
class ContractorHomeScreen extends StatelessWidget {
  const ContractorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final hasProfile = data?['contractor_profile'] != null;

        // If no profile, show setup screen
        if (!hasProfile) {
          return _ContractorSetupScreen();
        }

        // Show projects list
        return _ContractorProjectsScreen(
          businessName: data!['contractor_profile']['business_name'] ?? 'My Business',
        );
      },
    );
  }
}

// Setup screen when no profile exists
class _ContractorSetupScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to ProjectPulse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => confirmLogout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.engineering,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Let\'s set up your profile',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Add your business details to start creating projects',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContractorProfileScreen(),
                      ),
                    );
                    // Profile screen will return true if saved successfully
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Set Up Profile',
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

// Projects list screen
class _ContractorProjectsScreen extends StatefulWidget {
  final String businessName;

  const _ContractorProjectsScreen({required this.businessName});

  @override
  State<_ContractorProjectsScreen> createState() =>
      _ContractorProjectsScreenState();
}

class _ContractorProjectsScreenState
    extends State<_ContractorProjectsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';

  // Aggregate metrics (loaded async from subcollections)
  int _totalMilestones = 0;
  int _completedMilestones = 0;
  int _awaitingApproval = 0;
  int _pendingCOs = 0;
  bool _aggregatesLoaded = false;
  bool _isLoadingAggregates = false;

  // Per-project aggregates for badges & action item navigation
  Map<String, Map<String, int>> _perProjectAggregates = {};
  List<String> _projectsWithAwaitingApproval = [];
  List<String> _projectsWithPendingCOs = [];

  // Today's crew schedule
  List<Map<String, dynamic>> _todaySchedule = [];
  bool _scheduleLoaded = false;
  String? _teamId;

  // Periodic aggregate refresh
  List<QueryDocumentSnapshot>? _lastProjectDocs;
  late final _aggregateTimer = Timer.periodic(
    const Duration(seconds: 30),
    (_) {
      if (_lastProjectDocs != null) _loadAggregates(_lastProjectDocs!, force: true);
    },
  );

  @override
  void initState() {
    super.initState();
    _loadTeamId();
    _aggregateTimer; // start the timer
  }

  @override
  void dispose() {
    _searchController.dispose();
    _aggregateTimer.cancel();
    super.dispose();
  }

  Future<void> _loadTeamId() async {
    final user = FirebaseAuth.instance.currentUser!;
    final teamSnap = await FirebaseFirestore.instance
        .collection('teams')
        .where('owner_uid', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (teamSnap.docs.isNotEmpty && mounted) {
      setState(() => _teamId = teamSnap.docs.first.id);
      _loadTodaySchedule();
    }
  }

  Future<void> _loadTodaySchedule() async {
    if (_teamId == null) return;
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final scheduleSnap = await FirebaseFirestore.instance
        .collection('teams')
        .doc(_teamId)
        .collection('schedule_entries')
        .where('date', isEqualTo: todayStr)
        .get();

    if (mounted) {
      setState(() {
        _todaySchedule = scheduleSnap.docs
            .map((d) => d.data())
            .toList();
        _scheduleLoaded = true;
      });
    }
  }

  Future<void> _loadAggregates(List<QueryDocumentSnapshot> projects, {bool force = false}) async {
    _lastProjectDocs = projects;
    if (_isLoadingAggregates && !force) return;
    if (_aggregatesLoaded && !force) return;
    _isLoadingAggregates = true;

    int totalM = 0, completedM = 0, awaitingM = 0, pendingCO = 0;
    final perProject = <String, Map<String, int>>{};
    final awaitingIds = <String>[];
    final coIds = <String>[];

    final futures = projects.map((doc) async {
      final milestoneSnap = await FirebaseFirestore.instance
          .collection('projects')
          .doc(doc.id)
          .collection('milestones')
          .get();
      final coSnap = await FirebaseFirestore.instance
          .collection('projects')
          .doc(doc.id)
          .collection('change_orders')
          .where('status', isEqualTo: 'pending')
          .get();

      final aw = milestoneSnap.docs
          .where((m) => (m.data())['status'] == 'awaiting_approval')
          .length;
      final pc = coSnap.docs.length;

      return {
        'projectId': doc.id,
        'total': milestoneSnap.docs.length,
        'completed': milestoneSnap.docs
            .where((m) => (m.data())['status'] == 'approved')
            .length,
        'awaiting': aw,
        'pendingCO': pc,
      };
    });

    final results = await Future.wait(futures);
    for (final r in results) {
      totalM += r['total'] as int;
      completedM += r['completed'] as int;
      awaitingM += r['awaiting'] as int;
      pendingCO += r['pendingCO'] as int;

      final pid = r['projectId'] as String;
      perProject[pid] = {
        'awaiting': r['awaiting'] as int,
        'pendingCO': r['pendingCO'] as int,
      };
      if ((r['awaiting'] as int) > 0) awaitingIds.add(pid);
      if ((r['pendingCO'] as int) > 0) coIds.add(pid);
    }

    if (mounted) {
      setState(() {
        _totalMilestones = totalM;
        _completedMilestones = completedM;
        _awaitingApproval = awaitingM;
        _pendingCOs = pendingCO;
        _perProjectAggregates = perProject;
        _projectsWithAwaitingApproval = awaitingIds;
        _projectsWithPendingCOs = coIds;
        _aggregatesLoaded = true;
        _isLoadingAggregates = false;
      });
    }
  }

  List<QueryDocumentSnapshot> _filterProjects(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
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
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.businessName),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('recipient_uid', isEqualTo: user.uid)
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count', style: const TextStyle(fontSize: 10)),
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationCenterScreen(),
                  ),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.85),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolbarButton(context, Icons.calendar_month, 'Schedule', () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ScheduleScreen(),
                  ));
                }),
                _buildToolbarButton(context, Icons.groups, 'Team', () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const TeamManagementScreen(),
                  ));
                }),
                _buildToolbarButton(context, Icons.photo_library, 'Portfolio', () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const PortfolioScreen(),
                  ));
                }),
                _buildToolbarButton(context, Icons.person, 'Profile', () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ContractorProfileScreen(),
                  ));
                }),
                _buildToolbarButton(context, Icons.logout, 'Logout', () {
                  confirmLogout(context);
                }),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
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
                debugPrint('Error loading projects: ${snapshot.error}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
                      const SizedBox(height: 16),
                      Text('Error loading projects',
                          style: TextStyle(color: Colors.red[600])),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Welcome card
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            children: [
                              Icon(Icons.handyman, size: 56, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(height: 16),
                              const Text(
                                'Welcome to ProjectPulse',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Keep your clients in the loop with real-time project updates, photos, and milestones.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
                                    );
                                    if (result == true && mounted) {
                                      setState(() {});
                                    }
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Your First Project',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ClientProjectTimeline(
                                          projectId: DemoProjectData.demoProjectId,
                                          projectData: DemoProjectData.project,
                                          isPreview: true,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('See a Demo Project',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
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

              final allDocs = snapshot.data!.docs;
              // Trigger aggregate loading
              _loadAggregates(allDocs);

              // Compute metrics from project docs
              final activeProjects = allDocs.where((d) =>
                  (d.data() as Map<String, dynamic>)['status'] != 'completed').toList();
              final activeCount = activeProjects.length;
              final totalValue = allDocs.fold<double>(0, (sum, d) {
                final p = d.data() as Map<String, dynamic>;
                return sum + ((p['current_cost'] ?? p['original_cost'] ?? 0) as num).toDouble();
              });
              final allCrewUids = <String>{};
              for (final d in allDocs) {
                final p = d.data() as Map<String, dynamic>;
                final uids = (p['assigned_member_uids'] as List?)?.cast<String>() ?? [];
                allCrewUids.addAll(uids);
              }
              final completionPct = _totalMilestones > 0
                  ? (_completedMilestones / _totalMilestones * 100).round()
                  : 0;

              final filtered = _filterProjects(allDocs);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                children: [
                  // === TODAY HEADER ===
                  Text(
                    'Today — ${DateFormat('EEE, MMM d').format(DateTime.now())}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // === SECTION A: Action Items (always visible) ===
                  if (_aggregatesLoaded && _awaitingApproval == 0 && _pendingCOs == 0)
                    Card(
                      elevation: 0,
                      color: Colors.green[50],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'No action items today',
                              style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w500, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_aggregatesLoaded &&
                      (_awaitingApproval > 0 || _pendingCOs > 0)) ...[
                    if (_awaitingApproval > 0)
                      _buildActionItem(
                        icon: Icons.rate_review,
                        color: Colors.orange,
                        text: '$_awaitingApproval milestone${_awaitingApproval == 1 ? '' : 's'} awaiting approval',
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AllProjectsScreen(
                            filterToProjectIds: _projectsWithAwaitingApproval,
                            filterLabel: 'Projects with milestones awaiting approval',
                          ),
                        )),
                      ),
                    if (_pendingCOs > 0)
                      _buildActionItem(
                        icon: Icons.request_quote,
                        color: Colors.blue,
                        text: '$_pendingCOs change order${_pendingCOs == 1 ? '' : 's'} pending',
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AllProjectsScreen(
                            filterToProjectIds: _projectsWithPendingCOs,
                            filterLabel: 'Projects with pending change orders',
                          ),
                        )),
                      ),
                  ],
                  const SizedBox(height: 12),

                  // === SECTION B: Today's Crew ===
                  if (_scheduleLoaded && _todaySchedule.isNotEmpty) ...[
                    _buildSectionHeader("Today's Crew"),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: _todaySchedule.map((entry) {
                            final memberName = entry['member_name'] ?? entry['sub_name'] ?? 'Unknown';
                            final projectName = entry['project_name'] ?? 'Unassigned';
                            final projectId = entry['project_id'] as String?;
                            final isSub = entry['type'] == 'sub';
                            final initials = memberName.split(' ')
                                .where((w) => w.isNotEmpty)
                                .take(2)
                                .map((w) => w[0].toUpperCase())
                                .join();
                            final dotColors = [
                              Colors.blue, Colors.green, Colors.orange,
                              Colors.purple, Colors.teal, Colors.pink,
                              Colors.indigo, Colors.deepOrange,
                            ];
                            final dotColor = projectId != null
                                ? dotColors[projectId.hashCode.abs() % dotColors.length]
                                : Colors.grey;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isSub
                                        ? Colors.amber.withOpacity(0.15)
                                        : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    child: Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSub ? Colors.amber[800] : Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            memberName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isSub) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.amber[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('SUB', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber[900])),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      projectName,
                                      style: TextStyle(
                                          color: Colors.grey[700], fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_scheduleLoaded && _todaySchedule.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'No crew scheduled today',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ),

                  // === SECTION C: Summary Metrics ===
                  Row(
                    children: [
                      _buildMetricCard(
                        context,
                        icon: Icons.work,
                        value: '$activeCount',
                        label: 'Active',
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const AllProjectsScreen(initialStatusFilter: 'active'),
                        )),
                      ),
                      const SizedBox(width: 10),
                      _buildMetricCard(
                        context,
                        icon: Icons.attach_money,
                        value: currencyFormat.format(totalValue),
                        label: 'Total Value',
                        color: Colors.green[700]!,
                      ),
                      const SizedBox(width: 10),
                      _buildMetricCard(
                        context,
                        icon: Icons.pie_chart,
                        value: '$completionPct%',
                        label: 'Complete',
                        color: Colors.blue[700]!,
                      ),
                      const SizedBox(width: 10),
                      _buildMetricCard(
                        context,
                        icon: Icons.groups,
                        value: '${allCrewUids.length}',
                        label: 'Crew',
                        color: Colors.purple[600]!,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TeamManagementScreen(),
                        )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // === SECTION D: Projects (compact tiles) ===
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader('Projects'),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AllProjectsScreen(),
                            ),
                          );
                        },
                        child: Text('View All',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Search bar
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
                  // Filter chips
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
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${filtered.length} of ${allDocs.length} projects',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Compact project tiles
                  ...filtered.map((doc) {
                    final project = doc.data() as Map<String, dynamic>;
                    final status = project['status'] ?? 'active';
                    final cost = ((project['current_cost'] ??
                                project['original_cost'] ??
                                0) as num)
                        .toDouble();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProjectDetailsScreen(
                                projectId: doc.id,
                                projectData: project,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              // Project name
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      project['project_name'] ??
                                          'Untitled',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      project['client_name'] ??
                                          'No client',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Cost
                              Text(
                                currencyFormat.format(cost),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Status chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: status == 'active'
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Text(
                                  status == 'active'
                                      ? 'Active'
                                      : 'Done',
                                  style: TextStyle(
                                    color: status == 'active'
                                        ? Colors.green[700]
                                        : Colors.grey[600],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Notification badges
                              if (_aggregatesLoaded) ...[
                                Builder(builder: (_) {
                                  final agg = _perProjectAggregates[doc.id];
                                  final aw = agg?['awaiting'] ?? 0;
                                  final co = agg?['pendingCO'] ?? 0;
                                  if (aw == 0 && co == 0) {
                                    return const SizedBox(width: 4);
                                  }
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(width: 6),
                                      if (aw > 0)
                                        Container(
                                          width: 8, height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.orange,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      if (aw > 0 && co > 0)
                                        const SizedBox(width: 3),
                                      if (co > 0)
                                        Container(
                                          width: 8, height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.blue[600],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      const SizedBox(width: 4),
                                    ],
                                  );
                                }),
                              ],
                              if (!_aggregatesLoaded)
                                const SizedBox(width: 4),
                              Icon(Icons.chevron_right,
                                  size: 18, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (filtered.isEmpty && _searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('No projects match your search',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14)),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _statusFilter = 'all';
                              });
                            },
                            child: const Text('Clear filters'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          // Version number in bottom left
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'v0.0.72',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateProjectScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildToolbarButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color color,
    required String text,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// Client home screen - shows their projects
class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Projects'),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('recipient_uid', isEqualTo: user.uid)
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count', style: const TextStyle(fontSize: 10)),
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationCenterScreen(),
                  ),
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
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .where('client_email', isEqualTo: user.email)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.home_work_outlined,
                          size: 100,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No projects yet',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'When your contractor creates a project for you, it will appear here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[500],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final project = doc.data() as Map<String, dynamic>;

              // Get number of updates AND pending change orders using snapshots for real-time updates
              final updatesStream = FirebaseFirestore.instance
                  .collection('projects')
                  .doc(doc.id)
                  .collection('updates')
                  .snapshots();

              final pendingChangeOrdersStream = FirebaseFirestore.instance
                  .collection('projects')
                  .doc(doc.id)
                  .collection('change_orders')
                  .where('status', isEqualTo: 'pending')
                  .snapshots();

              return StreamBuilder<List<QuerySnapshot>>(
                stream: Rx.combineLatest2(
                  updatesStream,
                  pendingChangeOrdersStream,
                  (QuerySnapshot a, QuerySnapshot b) => [a, b],
                ),
                builder: (context, countsSnapshot) {
                  final photosCount = countsSnapshot.hasData ? countsSnapshot.data![0].docs.length : 0;
                  final pendingChangeOrdersCount = countsSnapshot.hasData ? countsSnapshot.data![1].docs.length : 0;
                  final updatesCount = photosCount + pendingChangeOrdersCount;

                  // Beautiful dashboard-style project card with milestone preview
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('projects')
                        .doc(doc.id)
                        .collection('milestones')
                        .orderBy('order')
                        .snapshots(),
                    builder: (context, milestonesSnapshot) {
                      final milestones = milestonesSnapshot.hasData ? milestonesSnapshot.data!.docs : [];
                      final completedCount = milestones.where((m) => (m.data() as Map)['status'] == 'approved').length;
                      final totalCount = milestones.length;
                      final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 20),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ClientProjectTimeline(
                                  projectId: doc.id,
                                  projectData: project,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with gradient background
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            project['project_name'] ?? 'Untitled Project',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${(progress * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      project['contractor_business_name'] ?? 'Contractor',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Progress bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 8,
                                        backgroundColor: Colors.white.withOpacity(0.3),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$completedCount of $totalCount milestones complete',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Milestone preview list
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (milestones.isNotEmpty) ...[
                                      ...milestones.take(3).map((milestoneDoc) {
                                        final milestone = milestoneDoc.data() as Map<String, dynamic>;
                                        final status = milestone['status'] as String;
                                        final isCompleted = status == 'approved';
                                        final isActive = status == 'in_progress' || status == 'awaiting_approval';

                                        Color statusColor = Colors.grey;
                                        if (isCompleted) statusColor = Colors.green;
                                        else if (status == 'awaiting_approval') statusColor = Colors.orange;
                                        else if (status == 'in_progress') statusColor = Colors.blue;

                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Row(
                                            children: [
                                              // Status indicator
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: isCompleted ? statusColor : Colors.white,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: statusColor, width: 2),
                                                ),
                                                child: isCompleted
                                                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                                                    : (isActive
                                                        ? Center(
                                                            child: Container(
                                                              width: 10,
                                                              height: 10,
                                                              decoration: BoxDecoration(
                                                                color: statusColor,
                                                                shape: BoxShape.circle,
                                                              ),
                                                            ),
                                                          )
                                                        : null),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  milestone['name'] ?? 'Untitled',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                                    color: isCompleted ? Colors.grey[600] : Colors.black87,
                                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(milestone['amount'] ?? 0),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: isCompleted ? Colors.green : Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      if (milestones.length > 3) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '+${milestones.length - 3} more milestones',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    // Activity row at bottom
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.photo_library_outlined,
                                          size: 18,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$photosCount ${photosCount == 1 ? 'photo' : 'photos'}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        if (pendingChangeOrdersCount > 0) ...[
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.warning, size: 12, color: Colors.white),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$pendingChangeOrdersCount pending',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        Icon(
                                          Icons.arrow_forward,
                                          size: 20,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ],
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
          // Version number in bottom left
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'v0.0.70',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
