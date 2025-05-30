import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'enhanced_therapist_chat_screen.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/screens/profile/profile_screen.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/patient_management_dashboard.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/patient_detail_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/add_patient_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/progress/progress_details_screen.dart';
import 'package:personalized_rehabilitation_plans/widgets/progress_chart_widget.dart';
import 'package:personalized_rehabilitation_plans/services/progress_service.dart';

// Import the therapist dashboard screen
import 'therapist_dashboard_screen.dart';

class TherapistBottomBarScreen extends StatefulWidget {
  const TherapistBottomBarScreen({super.key});

  @override
  State<TherapistBottomBarScreen> createState() =>
      _TherapistBottomBarScreenState();
}

class _TherapistBottomBarScreenState extends State<TherapistBottomBarScreen> {
  int _selectedIndex = 0;
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
    final authService = Provider.of<AuthService>(context);

    // Check if user is a therapist
    if (authService.currentUserModel?.isTherapist != true) {
      // Redirect non-therapists back to patient interface
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/patient_home');
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _buildDashboardTab(),
                _buildPatientsTab(),
                _buildNotificationsScreen(),
                _buildChatsTab(),
                _buildAnalyticsTab(),
                const ProfileScreen(),
              ],
            ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // Dashboard Tab - from therapist_dashboard_screen.dart
  Widget _buildDashboardTab() {
    final authService = Provider.of<AuthService>(context);
    final therapistName = authService.currentUserModel?.name ?? 'Therapist';

    return Container(
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDashboardHeader(therapistName),
              const SizedBox(height: 24),
              _buildStatsGrid(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildRecentActivity(),
              const SizedBox(height: 24),
              _buildPatientOverview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardHeader(String therapistName) {
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
          onTap: () => setState(() => _selectedIndex = 1),
        ),
        _buildStatCard(
          title: 'Active Plans',
          value: _dashboardStats['activePlans']?.toString() ?? '0',
          icon: Icons.assignment,
          color: Colors.green,
          onTap: () => setState(() => _selectedIndex = 1),
        ),
        _buildStatCard(
          title: 'Recent Activity',
          value: _dashboardStats['recentActivity']?.toString() ?? '0',
          icon: Icons.trending_up,
          color: Colors.orange,
          onTap: () => setState(() => _selectedIndex = 4),
        ),
        _buildStatCard(
          title: 'Unread Messages',
          value: _dashboardStats['unreadMessages']?.toString() ?? '0',
          icon: Icons.message,
          color: Colors.purple,
          onTap: () => setState(() => _selectedIndex = 3),
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
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                title: 'Add Patient',
                icon: Icons.person_add,
                color: AppTheme.primaryBlue,
                onTap: () => _navigateToAddPatient(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                title: 'View All Patients',
                icon: Icons.group,
                color: Colors.green,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
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
              onPressed: () => setState(() => _selectedIndex = 4),
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
              onPressed: () => setState(() => _selectedIndex = 1),
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

  // Patients Tab
  Widget _buildPatientsTab() {
    return const PatientManagementDashboard();
  }

  // Notifications Tab
  Widget _buildNotificationsScreen() {
    final authService = Provider.of<AuthService>(context);

    return Container(
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
            AppBar(
              title: const Text('Notifications'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: AppTheme.primaryBlue,
              automaticallyImplyLeading: false,
              actions: [
                TextButton(
                  onPressed: () => _markAllNotificationsAsRead(),
                  child: const Text('Mark All Read'),
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(authService.currentUser?.uid)
                    .collection('notifications')
                    .orderBy('timestamp', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildNoNotificationsMessage();
                  }

                  final notifications = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notificationData =
                          notifications[index].data() as Map<String, dynamic>;
                      final notificationId = notifications[index].id;
                      return _buildNotificationCard(
                          notificationData, notificationId);
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

  Widget _buildNoNotificationsMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You\'re all caught up! New notifications will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
      Map<String, dynamic> data, String notificationId) {
    final title = data['title'] ?? 'Notification';
    final message = data['message'] ?? '';
    final type = data['type'] ?? 'general';
    final isRead = data['isRead'] ?? false;
    final timestamp = data['timestamp'] as Timestamp?;
    final senderId = data['senderId'] as String?;

    final time = timestamp != null
        ? _formatNotificationTime(timestamp.toDate())
        : 'Unknown time';

    // Get icon and color based on notification type
    IconData icon;
    Color color;

    switch (type) {
      case 'patient_message':
        icon = Icons.message;
        color = Colors.blue;
        break;
      case 'progress_update':
        icon = Icons.trending_up;
        color = Colors.green;
        break;
      case 'new_patient':
        icon = Icons.person_add;
        color = Colors.teal;
        break;
      case 'appointment_request':
        icon = Icons.calendar_today;
        color = Colors.purple;
        break;
      case 'plan_completed':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'call_request':
        icon = Icons.call;
        color = Colors.orange;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 3,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            color: isRead ? Colors.grey[700] : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(
                color: isRead ? Colors.grey[600] : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        isThreeLine: true,
        onTap: () => _handleNotificationTap(
          type: type,
          notificationId: notificationId,
          senderId: senderId,
          isRead: isRead,
        ),
      ),
    );
  }

  // Chats Tab
  Widget _buildChatsTab() {
    final authService = Provider.of<AuthService>(context);

    return Container(
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
            AppBar(
              title: const Text('Patient Chats'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: AppTheme.primaryBlue,
              automaticallyImplyLeading: false,
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('therapistId',
                        isEqualTo: authService.currentUser?.uid)
                    .orderBy('lastMessageTime', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildNoChatsCard();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final chatData = snapshot.data!.docs[index].data()
                          as Map<String, dynamic>;
                      return _buildChatCard(chatData);
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

  Widget _buildNoChatsCard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Conversations Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Patient messages will appear here',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildChatCard(Map<String, dynamic> chatData) {
    final patientId = chatData['patientId'] ?? '';
    final lastMessage = chatData['lastMessage'] ?? '';
    final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
    final lastMessageSender = chatData['lastMessageSender'] ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(patientId).get(),
      builder: (context, userSnapshot) {
        String patientName = 'Unknown Patient';
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          patientName = userSnapshot.data!.get('name') ?? 'Unknown Patient';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
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
                Text(
                  lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (lastMessageTime != null)
                  Text(
                    _formatChatTime(lastMessageTime.toDate()),
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _navigateToChat(patientId, patientName),
          ),
        );
      },
    );
  }

  // Analytics Tab
  Widget _buildAnalyticsTab() {
    return Container(
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBar(
                title: const Text('Analytics'),
                backgroundColor: Colors.transparent,
                elevation: 0,
                foregroundColor: AppTheme.primaryBlue,
                automaticallyImplyLeading: false,
              ),
              const SizedBox(height: 16),
              _buildOverallStatsCard(),
              const SizedBox(height: 24),
              _buildPatientProgressChart(),
              const SizedBox(height: 24),
              _buildRecentProgressLogs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverallStatsCard() {
    final authService = Provider.of<AuthService>(context);

    return FutureBuilder<Map<String, dynamic>>(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Average Adherence',
                        '${stats['avgAdherence']?.round() ?? 0}%',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Average Pain Level',
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
            fontSize: 20,
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

  Widget _buildPatientProgressChart() {
    final authService = Provider.of<AuthService>(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: _getProgressTrendsData(authService.currentUser?.uid ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Progress Data Available',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Patient progress charts will appear here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final painLevels = List<double>.from(data['painLevels'] ?? []);
        final adherenceRates = List<int>.from(data['adherenceRates'] ?? []);
        final dates = List<String>.from(data['dates'] ?? []);

        return ProgressChartWidget(
          painLevels: painLevels,
          adherenceRates: adherenceRates,
          dates: dates,
          title: 'Patient Progress Trends (Last 30 Days)',
        );
      },
    );
  }

  Widget _buildRecentProgressLogs() {
    final authService = Provider.of<AuthService>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Progress Logs',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('progress_logs')
              .where('therapistId', isEqualTo: authService.currentUser?.uid)
              .orderBy('date', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.timeline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Progress Logs',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Patient progress logs will appear here',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildProgressLogCard(data, doc.id);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProgressLogCard(Map<String, dynamic> data, String logId) {
    final patientId = data['userId'] ?? '';
    final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final adherence = data['adherencePercentage'] ?? 0;
    final rating = data['overallRating'] ?? 0;
    final exerciseLogs = data['exerciseLogs'] as List<dynamic>? ?? [];

    // Calculate average pain level
    double avgPain = 0;
    if (exerciseLogs.isNotEmpty) {
      double totalPain = 0;
      for (var exercise in exerciseLogs) {
        totalPain += (exercise['painLevel'] ?? 0);
      }
      avgPain = totalPain / exerciseLogs.length;
    }

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(patientId).get(),
      builder: (context, userSnapshot) {
        String patientName = 'Unknown Patient';
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          patientName = userSnapshot.data!.get('name') ?? 'Unknown Patient';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getAdherenceColor(adherence).withOpacity(0.2),
              child: Text(
                patientName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: _getAdherenceColor(adherence),
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
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: _getAdherenceColor(adherence),
                    ),
                    const SizedBox(width: 4),
                    Text('$adherence% adherence'),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.healing,
                      size: 14,
                      color: _getPainColor(avgPain),
                    ),
                    const SizedBox(width: 4),
                    Text('${avgPain.toStringAsFixed(1)}/10 pain'),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${exerciseLogs.length} exercises • ${DateFormat('MMM dd, yyyy').format(date)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
            onTap: () =>
                _navigateToProgressDetails(logId, patientId, patientName),
          ),
        );
      },
    );
  }

  // Bottom Navigation
  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          // Reload dashboard data when switching to dashboard
          if (index == 0) {
            _loadDashboardData();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Patients',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                // Add notification badge here if needed
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: const Text(
                      '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            activeIcon: const Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_outlined),
                if ((_dashboardStats['unreadMessages'] ?? 0) > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_dashboardStats['unreadMessages']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: const Icon(Icons.chat),
            label: 'Chats',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
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

  Future<Map<String, dynamic>> _getProgressTrendsData(
      String therapistId) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      final progressSnapshot = await FirebaseFirestore.instance
          .collection('progress_logs')
          .where('therapistId', isEqualTo: therapistId)
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .orderBy('date')
          .get();

      if (progressSnapshot.docs.isEmpty) {
        return {};
      }

      List<double> painLevels = [];
      List<int> adherenceRates = [];
      List<String> dates = [];

      for (var doc in progressSnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();

        adherenceRates.add(data['adherencePercentage'] ?? 0);

        final exerciseLogs = data['exerciseLogs'] as List<dynamic>? ?? [];
        double avgPain = 0;
        if (exerciseLogs.isNotEmpty) {
          double totalPain = 0;
          for (var exercise in exerciseLogs) {
            totalPain += (exercise['painLevel'] ?? 0);
          }
          avgPain = totalPain / exerciseLogs.length;
        }
        painLevels.add(avgPain);
        dates.add('${date.day}/${date.month}');
      }

      return {
        'painLevels': painLevels,
        'adherenceRates': adherenceRates,
        'dates': dates,
      };
    } catch (e) {
      print('Error getting progress trends: $e');
      return {};
    }
  }

  Color _getAdherenceColor(int adherence) {
    if (adherence >= 80) return Colors.green;
    if (adherence >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _getPainColor(double pain) {
    if (pain <= 3) return Colors.green;
    if (pain <= 6) return Colors.orange;
    return Colors.red;
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

  String _formatChatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(time);
    }
  }

  String _formatNotificationTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Navigation methods
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

  // Notification handling methods
  Future<void> _handleNotificationTap({
    required String type,
    required String notificationId,
    String? senderId,
    required bool isRead,
  }) async {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Mark notification as read if not already read
    if (!isRead) {
      await _markNotificationAsRead(notificationId, authService);
    }

    switch (type) {
      case 'patient_message':
        if (senderId != null) {
          await _navigateToPatientChat(senderId, authService);
        }
        break;

      case 'progress_update':
        // Navigate to analytics tab
        setState(() {
          _selectedIndex = 4; // Analytics tab
        });
        break;

      case 'new_patient':
        // Navigate to patients tab
        setState(() {
          _selectedIndex = 1; // Patients tab
        });
        break;

      case 'appointment_request':
        // Handle appointment request
        _showAppointmentDialog();
        break;

      case 'call_request':
        if (senderId != null) {
          _showCallResponseDialog(senderId);
        }
        break;

      default:
        // For unknown types, just mark as read
        break;
    }
  }

  Future<void> _markNotificationAsRead(
      String notificationId, AuthService authService) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(authService.currentUser?.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllNotificationsAsRead() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final batch = FirebaseFirestore.instance.batch();

      final notifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(authService.currentUser?.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking notifications as read: $e')),
      );
    }
  }

  Future<void> _navigateToPatientChat(
      String patientId, AuthService authService) async {
    try {
      // Get patient details
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();

      if (patientDoc.exists) {
        final patientData = patientDoc.data()!;
        final patientName = patientData['name'] ?? 'Unknown Patient';

        // Navigate to enhanced chat screen
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
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading patient: $e')),
      );
    }
  }

  void _showAppointmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appointment Request'),
        content: const Text(
          'A patient has requested an appointment. Would you like to view your schedule or contact them directly?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Calendar feature coming soon'),
                ),
              );
            },
            child: const Text('View Schedule'),
          ),
        ],
      ),
    );
  }

  void _showCallResponseDialog(String patientId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Request'),
        content: const Text(
          'A patient is requesting a call. How would you like to respond?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToCallRequest(patientId, 'schedule');
            },
            child: const Text('Schedule Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToCallRequest(patientId, 'accept');
            },
            child: const Text('Call Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _respondToCallRequest(String patientId, String response) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Create a response message
      String responseMessage;
      switch (response) {
        case 'accept':
          responseMessage = 'I\'m calling you now. Please answer your phone.';
          break;
        case 'schedule':
          responseMessage =
              'I received your call request. Let\'s schedule a time that works for both of us. When are you available?';
          break;
        default:
          responseMessage =
              'I received your call request but I\'m not available right now. Please send a message instead.';
      }

      // Send response message
      final chatRoomId = [patientId, authService.currentUser!.uid]..sort();

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId.join('_'))
          .collection('messages')
          .add({
        'text': responseMessage,
        'senderId': authService.currentUser!.uid,
        'senderName':
            'Dr. ${authService.currentUserModel?.name ?? 'Therapist'}',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'messageType': 'call_response',
      });

      // Send notification to patient
      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('notifications')
          .add({
        'title': 'Call Response',
        'message': responseMessage,
        'type': 'call_response',
        'senderId': authService.currentUser!.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (response == 'accept') {
        // In a real app, you would integrate with a calling service here
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Calling feature will be integrated with VoIP service'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Response sent to patient'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error responding to call: $e')),
      );
    }
  }
}
