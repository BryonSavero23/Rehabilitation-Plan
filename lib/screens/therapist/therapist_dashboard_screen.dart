import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/patient_management_dashboard.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/patient_detail_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/add_patient_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/progress/progress_details_screen.dart';
import 'package:intl/intl.dart';

// Import the enhanced therapist chat screen
import 'enhanced_therapist_chat_screen.dart';

class TherapistDashboardScreen extends StatefulWidget {
  const TherapistDashboardScreen({super.key});

  @override
  State<TherapistDashboardScreen> createState() =>
      _TherapistDashboardScreenState();
}

class _TherapistDashboardScreenState extends State<TherapistDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardStats = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final therapistId = authService.currentUser?.uid;

      if (therapistId != null) {
        // Load patient count
        final patientsSnapshot = await FirebaseFirestore.instance
            .collection('therapists')
            .doc(therapistId)
            .collection('patients')
            .get();

        // Load active plans count
        final activePlansSnapshot = await FirebaseFirestore.instance
            .collection('rehabilitation_plans')
            .where('therapistId', isEqualTo: therapistId)
            .where('status', isEqualTo: 'active')
            .get();

        // Load recent activity count
        final recentActivitySnapshot = await FirebaseFirestore.instance
            .collection('progress_logs')
            .where('therapistId', isEqualTo: therapistId)
            .where('date',
                isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
            .get();

        // Load unread messages count
        final chatsSnapshot = await FirebaseFirestore.instance
            .collection('chats')
            .where('therapistId', isEqualTo: therapistId)
            .get();

        int unreadCount = 0;
        for (var chat in chatsSnapshot.docs) {
          final messagesSnapshot = await FirebaseFirestore.instance
              .collection('chats')
              .doc(chat.id)
              .collection('messages')
              .where('senderId', isNotEqualTo: therapistId)
              .where('isRead', isEqualTo: false)
              .get();
          unreadCount += messagesSnapshot.docs.length;
        }

        setState(() {
          _dashboardStats = {
            'totalPatients': patientsSnapshot.docs.length,
            'activePlans': activePlansSnapshot.docs.length,
            'recentActivity': recentActivitySnapshot.docs.length,
            'unreadMessages': unreadCount,
          };
        });
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDashboardHeader(),
                        const SizedBox(height: 24),
                        _buildStatsGrid(),
                        const SizedBox(height: 24),
                        _buildQuickActions(),
                        const SizedBox(height: 24),
                        _buildRecentActivity(),
                        const SizedBox(height: 24),
                        _buildPatientOverview(),
                        const SizedBox(height: 24),
                        _buildAnalyticsPreview(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDashboardHeader() {
    final authService = Provider.of<AuthService>(context);
    final therapistName = authService.currentUserModel?.name ?? 'Therapist';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Dr. $therapistName',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Today is ${DateFormat('EEEE, MMMM dd').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.medical_services,
            color: AppTheme.primaryBlue,
            size: 32,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          title: 'Total Patients',
          value: _dashboardStats['totalPatients']?.toString() ?? '0',
          icon: Icons.people,
          color: Colors.blue,
          onTap: () => _navigateToPatientManagement(),
        ),
        _buildStatCard(
          title: 'Active Plans',
          value: _dashboardStats['activePlans']?.toString() ?? '0',
          icon: Icons.assignment,
          color: Colors.green,
          onTap: () => _navigateToPatientManagement(),
        ),
        _buildStatCard(
          title: 'Recent Activity',
          value: _dashboardStats['recentActivity']?.toString() ?? '0',
          icon: Icons.trending_up,
          color: Colors.orange,
          onTap: () => _showRecentActivityDialog(),
        ),
        _buildStatCard(
          title: 'Unread Messages',
          value: _dashboardStats['unreadMessages']?.toString() ?? '0',
          icon: Icons.message,
          color: Colors.purple,
          onTap: () => _showMessagesDialog(),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildActionButton(
                title: 'Add Patient',
                icon: Icons.person_add,
                color: AppTheme.primaryBlue,
                onTap: () => _navigateToAddPatient(),
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                title: 'View Patients',
                icon: Icons.group,
                color: Colors.green,
                onTap: () => _navigateToPatientManagement(),
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                title: 'Messages',
                icon: Icons.chat,
                color: Colors.purple,
                onTap: () => _showMessagesDialog(),
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                title: 'Analytics',
                icon: Icons.analytics,
                color: Colors.orange,
                onTap: () => _showAnalyticsDialog(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final authService = Provider.of<AuthService>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () => _showRecentActivityDialog(),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('progress_logs')
              .where('therapistId', isEqualTo: authService.currentUser?.uid)
              .orderBy('date', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildNoActivityCard();
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildActivityCard(data, doc.id);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNoActivityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.timeline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Recent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Patient progress will appear here',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> data, String logId) {
    final patientId = data['userId'] ?? '';
    final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final adherence = data['adherencePercentage'] ?? 0;
    final rating = data['overallRating'] ?? 0;

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(patientId).get(),
      builder: (context, userSnapshot) {
        String patientName = 'Unknown Patient';
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          patientName = userSnapshot.data!.get('name') ?? 'Unknown Patient';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
              child: Text(
                patientName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              '$patientName completed a session',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Adherence: $adherence% • Rating: $rating/5'),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(date),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: () =>
                  _navigateToProgressDetails(logId, patientId, patientName),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPatientOverview() {
    final authService = Provider.of<AuthService>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Patients',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () => _navigateToPatientManagement(),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('therapists')
              .doc(authService.currentUser?.uid)
              .collection('patients')
              .orderBy('lastActivity', descending: true)
              .limit(4)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildNoPatientsCard();
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildPatientCard(data, doc.id);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNoPatientsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Patients Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first patient to get started',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _navigateToAddPatient,
            child: const Text('Add Patient'),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> data, String patientId) {
    final patientName = data['name'] ?? 'Unknown Patient';
    final condition = data['condition'] ?? 'No condition specified';
    final lastActivity = data['lastActivity'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryBlue,
          child: Text(
            patientName.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          patientName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(condition),
            if (lastActivity != null)
              Text(
                'Last activity: ${_formatDate(lastActivity.toDate())}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _navigateToPatientDetail(patientId, patientName),
      ),
    );
  }

  Widget _buildAnalyticsPreview() {
    final authService = Provider.of<AuthService>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Analytics Preview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () => _showAnalyticsDialog(),
              child: const Text('View Full Analytics'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: _getOverallStats(authService.currentUser?.uid ?? ''),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final stats = snapshot.data ?? {};

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'Avg Adherence',
                            '${stats['avgAdherence']?.round() ?? 0}%',
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'Avg Pain Level',
                            '${stats['avgPainLevel']?.toStringAsFixed(1) ?? '0.0'}/10',
                            Icons.healing,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'Total Sessions',
                            '${stats['totalSessions'] ?? 0}',
                            Icons.fitness_center,
                            Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'This Week',
                            '${stats['thisWeekSessions'] ?? 0}',
                            Icons.calendar_today,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Helper methods
  Future<Map<String, dynamic>> _getOverallStats(String therapistId) async {
    try {
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('progress_logs')
          .where('therapistId', isEqualTo: therapistId)
          .get();

      if (progressSnapshot.docs.isEmpty) {
        return {};
      }

      double totalAdherence = 0;
      double totalPain = 0;
      int totalExercises = 0;
      int thisWeekSessions = 0;

      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

      for (var doc in progressSnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();

        totalAdherence += (data['adherencePercentage'] ?? 0).toDouble();

        if (date.isAfter(oneWeekAgo)) {
          thisWeekSessions++;
        }

        final exerciseLogs = data['exerciseLogs'] as List<dynamic>? ?? [];
        for (var exercise in exerciseLogs) {
          totalPain += (exercise['painLevel'] ?? 0).toDouble();
          totalExercises++;
        }
      }

      return {
        'avgAdherence': progressSnapshot.docs.isNotEmpty
            ? totalAdherence / progressSnapshot.docs.length
            : 0,
        'avgPainLevel': totalExercises > 0 ? totalPain / totalExercises : 0,
        'totalSessions': progressSnapshot.docs.length,
        'thisWeekSessions': thisWeekSessions,
      };
    } catch (e) {
      print('Error getting overall stats: $e');
      return {};
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  // Navigation methods
  void _navigateToPatientManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PatientManagementDashboard(),
      ),
    );
  }

  void _navigateToAddPatient() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPatientScreen(),
      ),
    ).then((_) => _loadDashboardData()); // Refresh data when returning
  }

  void _navigateToPatientDetail(String patientId, String patientName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(
          patientId: patientId,
          patientName: patientName,
        ),
      ),
    );
  }

  void _navigateToProgressDetails(
      String progressId, String patientId, String patientName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProgressDetailsScreen(
          progressId: progressId,
          patientId: patientId,
          patientName: patientName,
        ),
      ),
    );
  }

  void _navigateToChat(String patientId, String patientName) {
    final authService = Provider.of<AuthService>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedTherapistChatScreen(
          therapistId: authService.currentUser!.uid,
          therapistName: authService.currentUserModel?.name ?? 'Therapist',
          therapistTitle: 'Dr.',
          patientId: patientId,
          patientName: patientName,
        ),
      ),
    ).then((_) => _loadDashboardData()); // Refresh data when returning
  }

  // Dialog methods
  void _showRecentActivityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recent Activity'),
        content: const Text(
          'This would show detailed recent activity from all patients.',
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

  void _showMessagesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Messages'),
        content: const Text(
          'This would show patient chat conversations.',
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

  void _showAnalyticsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analytics'),
        content: const Text(
          'This would show detailed analytics and progress charts.',
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
