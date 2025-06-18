import 'package:flutter/material.dart';
import 'package:personalized_rehabilitation_plans/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist_chat_screen.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isTherapist = false;
  bool _isLoading = false;
  int _selectedTabIndex = 0; // 0: Profile, 1: Education

  // Therapist information for patients
  String? _assignedTherapistName;
  String? _assignedTherapistTitle;
  String? _assignedTherapistId;
  bool _isLoadingTherapist = false;

  late AuthService authService;

  @override
  void initState() {
    super.initState();
    authService = Provider.of<AuthService>(context, listen: false);
    _loadUserData();
  }

  void _loadUserData() {
    if (authService.currentUserModel != null) {
      _nameController.text = authService.currentUserModel!.name;
      _emailController.text = authService.currentUserModel!.email;
      _isTherapist = authService.currentUserModel!.isTherapist;

      // Load therapist information for patients
      if (!_isTherapist) {
        _loadAssignedTherapist();
      }
    }
  }

  Future<void> _loadAssignedTherapist() async {
    setState(() {
      _isLoadingTherapist = true;
    });

    try {
      final user = authService.currentUser;
      if (user != null) {
        // Get user document to check for assigned therapist
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final therapistId = userData['assignedTherapistId'] as String?;
          final therapistName = userData['assignedTherapistName'] as String?;

          if (therapistId != null && therapistName != null) {
            // Get therapist details from therapists collection
            final therapistDoc = await FirebaseFirestore.instance
                .collection('therapists')
                .doc(therapistId)
                .get();

            String therapistTitle = 'Physical Therapist'; // Default
            if (therapistDoc.exists) {
              final therapistData = therapistDoc.data()!;
              therapistTitle = therapistData['specialization'] ??
                  therapistData['specialty'] ??
                  'Physical Therapist';
            }

            setState(() {
              _assignedTherapistName = therapistName;
              _assignedTherapistTitle = therapistTitle;
              _assignedTherapistId = therapistId;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading assigned therapist: $e');
      // Set to null if there's an error
      setState(() {
        _assignedTherapistName = null;
        _assignedTherapistTitle = null;
        _assignedTherapistId = null;
      });
    } finally {
      setState(() {
        _isLoadingTherapist = false;
      });
    }
  }

  Future<void> _navigateToTherapistChat() async {
    if (_assignedTherapistId == null || _assignedTherapistName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No therapist assigned yet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Navigate to the chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TherapistChatScreen(
            therapistId: _assignedTherapistId!,
            therapistName: _assignedTherapistName!,
            therapistTitle: _assignedTherapistTitle ?? 'Dr.',
            patientId: authService.currentUser!.uid,
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to therapist chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening chat: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveData() async {
    try {
      if (!_formKey.currentState!.validate()) return;

      setState(() {
        _isLoading = true;
      });

      authService.currentUserModel!.name = _nameController.text.trim();
      authService.currentUserModel!.isTherapist = _isTherapist;

      await authService.updateUserData(authService.currentUserModel!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundStart,
              AppTheme.backgroundEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Tab Bar
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTabIndex = 0),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedTabIndex == 0
                                ? AppTheme.primaryBlue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Profile',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _selectedTabIndex == 0
                                  ? Colors.white
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTabIndex = 1),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedTabIndex == 1
                                ? AppTheme.primaryBlue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Education',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _selectedTabIndex == 1
                                  ? Colors.white
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _selectedTabIndex == 0
                    ? _buildProfileTab()
                    : _buildEducationTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.primaryBlue,
                    child: Text(
                      _nameController.text.isNotEmpty
                          ? _nameController.text[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome Back!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          _nameController.text.isNotEmpty
                              ? _nameController.text
                              : 'Your Name',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Profile Form
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field (Read-only)
                  TextFormField(
                    controller: _emailController,
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Assigned Therapist - Only show for patients
                  if (!_isTherapist) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_pin,
                                color: AppTheme.primaryBlue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Assigned Therapist',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_isLoadingTherapist) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Loading therapist information...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (_assignedTherapistName != null) ...[
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppTheme.primaryBlue,
                                  child: Text(
                                    _assignedTherapistName!
                                        .split(' ')
                                        .map((name) => name[0])
                                        .take(2)
                                        .join(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _assignedTherapistName!,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        _assignedTherapistTitle ??
                                            'Physical Therapist',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _navigateToTherapistChat,
                                  icon: Icon(
                                    Icons.message,
                                    color: AppTheme.primaryBlue,
                                  ),
                                  tooltip:
                                      'Message ${_assignedTherapistName ?? 'Therapist'}',
                                ),
                              ],
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'No therapist assigned yet',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Therapist Switch - Only show for therapists as verification badge
                  if (_isTherapist) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Therapist Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sign Out Button
            Container(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _signOut,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.red, width: 2),
                  backgroundColor: Colors.white,
                ),
                child: Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationTab() {
    // Different content based on user type
    if (_isTherapist) {
      return _buildTherapistEducationTab();
    } else {
      return _buildPatientEducationTab();
    }
  }

  Widget _buildPatientEducationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.school,
                      size: 28,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Patient Education Hub',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Learn about your condition and understand the importance of your prescribed exercises',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Educational Categories for Patients
          _buildEducationCategory(
            'Understanding Your Condition',
            'Learn about different types of injuries and conditions',
            Icons.medical_information,
            Colors.blue,
            [
              EducationItem(
                'Common Sports Injuries',
                'Understanding sprains, strains, and their recovery',
                'article',
              ),
              EducationItem(
                'Post-Surgery Recovery',
                'What to expect during your rehabilitation journey',
                'video',
              ),
              EducationItem(
                'Chronic Pain Management',
                'Strategies for managing long-term conditions',
                'article',
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildEducationCategory(
            'Exercise Importance',
            'Why your prescribed exercises matter',
            Icons.fitness_center,
            Colors.green,
            [
              EducationItem(
                'Consistency is Key',
                'How regular exercise accelerates healing',
                'video',
              ),
              EducationItem(
                'Proper Form Guide',
                'Performing exercises safely and effectively',
                'article',
              ),
              EducationItem(
                'Progression Explained',
                'Understanding why exercises get harder over time',
                'video',
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildEducationCategory(
            'Frequently Asked Questions',
            'Common questions about rehabilitation',
            Icons.help_outline,
            Colors.orange,
            [
              EducationItem(
                'How long will my recovery take?',
                'Factors that influence recovery timelines',
                'faq',
              ),
              EducationItem(
                'What if I experience pain during exercises?',
                'When to push through vs. when to stop',
                'faq',
              ),
              EducationItem(
                'Can I do additional exercises?',
                'Safety guidelines for supplementary activities',
                'faq',
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildEducationCategory(
            'Lifestyle & Recovery',
            'Supporting your healing through daily habits',
            Icons.favorite,
            Colors.red,
            [
              EducationItem(
                'Nutrition for Healing',
                'Foods that support tissue repair and recovery',
                'article',
              ),
              EducationItem(
                'Sleep and Recovery',
                'The importance of quality sleep in rehabilitation',
                'video',
              ),
              EducationItem(
                'Stress Management',
                'How stress affects healing and recovery',
                'article',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTherapistEducationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header for Therapists
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.medical_services,
                      size: 28,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Therapist Resource Center',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Professional resources and patient education materials to enhance your practice',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Educational Categories for Therapists
          _buildEducationCategory(
            'Patient Education Materials',
            'Resources to share with your patients',
            Icons.share,
            Colors.blue,
            [
              EducationItem(
                'Exercise Instruction Videos',
                'Comprehensive library of exercise demonstrations',
                'video',
              ),
              EducationItem(
                'Condition-Specific Handouts',
                'Educational materials for different conditions',
                'article',
              ),
              EducationItem(
                'Home Exercise Programs',
                'Templates for creating effective home programs',
                'article',
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildEducationCategory(
            'Clinical Best Practices',
            'Evidence-based treatment approaches',
            Icons.psychology,
            Colors.green,
            [
              EducationItem(
                'Assessment Protocols',
                'Standardized assessment techniques and tools',
                'article',
              ),
              EducationItem(
                'Treatment Progression',
                'Guidelines for advancing patient programs safely',
                'video',
              ),
              EducationItem(
                'Outcome Measures',
                'Tracking patient progress effectively',
                'article',
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildEducationCategory(
            'Professional Development',
            'Continuing education and skill enhancement',
            Icons.trending_up,
            Colors.purple,
            [
              EducationItem(
                'Latest Research Updates',
                'Recent findings in rehabilitation science',
                'article',
              ),
              EducationItem(
                'Technology in Therapy',
                'Integrating digital tools in practice',
                'video',
              ),
              EducationItem(
                'Patient Communication',
                'Effective strategies for patient engagement',
                'article',
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildEducationCategory(
            'Practice Management',
            'Tools for efficient clinic operations',
            Icons.business_center,
            Colors.orange,
            [
              EducationItem(
                'Documentation Guidelines',
                'Best practices for clinical documentation',
                'article',
              ),
              EducationItem(
                'Insurance & Billing',
                'Navigating insurance requirements',
                'faq',
              ),
              EducationItem(
                'Quality Assurance',
                'Maintaining high standards of care',
                'article',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEducationCategory(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    List<EducationItem> items,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Category Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: color.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Category Items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey[200],
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                onTap: () => _openEducationItem(item),
                leading: Icon(
                  _getIconForType(item.type),
                  color: color,
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  item.description,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'video':
        return Icons.play_circle_outline;
      case 'article':
        return Icons.article_outlined;
      case 'faq':
        return Icons.quiz_outlined;
      default:
        return Icons.info_outlined;
    }
  }

  void _openEducationItem(EducationItem item) {
    showDialog(
      context: context,
      builder: (context) => EducationItemDialog(item: item),
    );
  }
}

class EducationItem {
  final String title;
  final String description;
  final String type; // 'video', 'article', 'faq'

  EducationItem(this.title, this.description, this.type);
}

class EducationItemDialog extends StatelessWidget {
  final EducationItem item;

  const EducationItemDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getIconForType(item.type),
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.type == 'video') ...[
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Playing: ${item.title}'),
                                ],
                              ),
                              backgroundColor: AppTheme.primaryBlue,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryBlue.withOpacity(0.3),
                                AppTheme.primaryBlue.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Play button overlay
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.play_arrow,
                                        size: 48,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Watch Video',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Duration badge
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '5:30',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      _getContentForItem(item),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bookmarked for later reading'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                    ),
                    child: const Text(
                      'Bookmark',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'video':
        return Icons.play_circle_outline;
      case 'article':
        return Icons.article_outlined;
      case 'faq':
        return Icons.quiz_outlined;
      default:
        return Icons.info_outlined;
    }
  }

  String _getContentForItem(EducationItem item) {
    switch (item.title) {
      // Patient Content
      case 'Common Sports Injuries':
        return '''Sports injuries are common and can range from minor to severe. Understanding the type of injury you have is crucial for proper treatment and recovery.

**Common Types:**
• **Sprains:** Injury to ligaments that connect bones to joints
• **Strains:** Injury to muscles or tendons
• **Contusions:** Bruising of muscle tissue
• **Fractures:** Breaks in bones

**Recovery Principles:**
• Rest: Allow injured tissue to heal
• Ice: Reduce inflammation and pain
• Compression: Support the injured area
• Elevation: Minimize swelling

Your personalized rehabilitation plan is designed specifically for your type of injury and will help restore strength, flexibility, and function safely.''';

      case 'Consistency is Key':
        return '''Consistency in performing your prescribed exercises is the most important factor in achieving optimal recovery outcomes.

**Why Consistency Matters:**
• Promotes tissue healing and remodeling
• Maintains and improves range of motion
• Prevents muscle weakness and atrophy
• Reduces risk of re-injury

**Creating a Routine:**
• Set specific times for your exercises
• Start with shorter sessions if needed
• Track your progress daily
• Celebrate small victories

Remember: Missing a few days can set back your progress significantly. Your body heals and adapts through consistent, progressive movement.''';

      case 'How long will my recovery take?':
        return '''Recovery time varies greatly depending on several factors:

**Factors Affecting Recovery Time:**
• Type and severity of injury
• Your age and overall health
• Previous injury history
• Compliance with treatment plan
• Individual healing rate

**Typical Timelines:**
• Minor sprains: 2-6 weeks
• Moderate injuries: 6-12 weeks
• Post-surgical: 3-6 months
• Complex conditions: 6-12 months

**Important:** These are general guidelines. Your therapist will provide more specific timelines based on your individual case and progress assessments.''';

      // Therapist Content
      case 'Exercise Instruction Videos':
        return '''Access a comprehensive library of professionally produced exercise demonstration videos for patient education and reference.

**Features:**
• High-quality HD video demonstrations
• Multiple camera angles for clarity
• Anatomical explanations
• Common mistake corrections
• Progression variations

**Categories Available:**
• Strengthening exercises by body region
• Flexibility and mobility routines
• Balance and proprioception training
• Sport-specific rehabilitation
• Post-surgical protocols

**Usage Tips:**
• Share specific videos with patients via email
• Use during patient education sessions
• Reference for form corrections
• Create custom playlists for conditions''';

      case 'Assessment Protocols':
        return '''Evidence-based assessment tools and protocols to ensure comprehensive patient evaluation and treatment planning.

**Included Assessments:**
• Functional Movement Screen (FMS)
• Range of Motion measurements
• Strength testing procedures
• Pain assessment scales
• Activity-specific evaluations

**Documentation Features:**
• Standardized forms and templates
• Progress tracking charts
• Outcome measurement tools
• Report generation capabilities

**Best Practices:**
• Establish baseline measurements
• Use validated assessment tools
• Document findings thoroughly
• Reassess at regular intervals
• Share results with patients for motivation''';

      case 'Latest Research Updates':
        return '''Stay current with the latest developments in rehabilitation science and evidence-based practice.

**Recent Findings:**
• Neuroplasticity in injury recovery
• Exercise dosage optimization
• Pain science applications
• Technology-assisted rehabilitation
• Patient adherence strategies

**Research Categories:**
• Peer-reviewed journal articles
• Clinical trial summaries
• Meta-analysis reviews
• Practice guideline updates
• Conference presentations

**Implementation:**
• Evidence-based treatment modifications
• Updated clinical protocols
• Patient education improvements
• Quality outcome measures
• Continuing education credits''';

      case 'Documentation Guidelines':
        return '''Comprehensive guidelines for clinical documentation that meets legal, ethical, and insurance requirements.

**Key Components:**
• Initial evaluation documentation
• Treatment note requirements
• Progress report standards
• Discharge planning documentation
• Insurance authorization processes

**Legal Considerations:**
• HIPAA compliance requirements
• Liability protection strategies
• Record retention policies
• Patient consent documentation
• Quality assurance standards

**Efficiency Tips:**
• Template development
• Electronic documentation systems
• Time-saving strategies
• Common documentation errors to avoid
• Billing code optimization''';

      default:
        return '''This educational content is designed to enhance your professional practice and improve patient outcomes.

For specific questions about implementation or additional resources, please consult with your professional development team or continuing education providers.

Remember that staying current with best practices and evidence-based approaches is essential for providing the highest quality of care to your patients.''';
    }
  }
}
