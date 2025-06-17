import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/screens/profile/profile_screen.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/patient_management_dashboard.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/patient_detail_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/add_patient_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/enhanced_therapist_chat_screen.dart';

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

        // Load active plans count - Fixed to use users subcollection
        int activePlansCount = 0;
        for (var patient in patientsSnapshot.docs) {
          final patientId = patient.id;
          final plansSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(patientId)
              .collection('rehabilitation_plans')
              .where('status', isEqualTo: 'active')
              .get();
          activePlansCount += plansSnapshot.docs.length;
        }

        // Load recent activity count
        final recentActivitySnapshot = await FirebaseFirestore.instance
            .collection('progress_logs')
            .where('therapistId', isEqualTo: therapistId)
            .where('date',
                isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
            .get();

        setState(() {
          _dashboardStats = {
            'totalPatients': patientsSnapshot.docs.length,
            'activePlans': activePlansCount,
            'recentActivity': recentActivitySnapshot.docs.length,
            'unreadMessages': 0, // Will be updated in real implementation
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardTab(),
          _buildPatientsTab(),
          _buildNotificationsTab(),
          _buildChatsTab(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // Dashboard Tab
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with PRP Logo on the right
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppTheme.primaryBlue,
                            child: Text(
                              therapistName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
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
                                  'Welcome back,',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  'Dr. $therapistName',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // PRP Logo on the right
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'PRP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Stats Cards
                      Text(
                        'Overview',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatsGrid(),
                      const SizedBox(height: 32),

                      // Quick Actions
                      Text(
                        'Quick Actions',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildQuickActions(),
                      const SizedBox(height: 32),

                      // Recent Activity
                      Text(
                        'Recent Activity',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildRecentActivity(),
                    ],
                  ),
                ),
              ),
      ),
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
          'Total Patients',
          '${_dashboardStats['totalPatients'] ?? 0}',
          Icons.people,
          Colors.blue,
          onTap: () =>
              setState(() => _selectedIndex = 1), // Navigate to Patients tab
        ),
        _buildStatCard(
          'Active Plans',
          '${_dashboardStats['activePlans'] ?? 0}',
          Icons.assignment,
          Colors.green,
          onTap: () =>
              setState(() => _selectedIndex = 1), // Navigate to Patients tab
        ),
        _buildStatCard(
          'Recent Activity',
          '${_dashboardStats['recentActivity'] ?? 0}',
          Icons.timeline,
          Colors.orange,
          onTap: () =>
              _buildRecentActivityBottomSheet(), // Show recent activity
        ),
        _buildStatCard(
          'Messages',
          '${_dashboardStats['unreadMessages'] ?? 0}',
          Icons.message,
          Colors.purple,
          onTap: () => setState(
              () => _selectedIndex = 3), // Navigate to Chats tab (index 3)
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              if (onTap != null) const SizedBox(height: 4),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Add Patient',
            Icons.person_add,
            Colors.blue,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddPatientScreen(),
                ),
              ).then((_) => _loadDashboardData());
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            'View All Patients',
            Icons.people,
            Colors.green,
            () {
              setState(() => _selectedIndex = 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, Color color, VoidCallback onPressed) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('progress_logs')
          .where('therapistId', isEqualTo: authService.currentUser?.uid)
          .orderBy('date', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No recent activity'),
            ),
          );
        }

        return Card(
          child: Column(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final type = data['type'] ?? 'activity';
              final date = (data['date'] as Timestamp).toDate();

              return ListTile(
                leading: Icon(_getActivityIcon(type)),
                title: Text(_getActivityTitle(type, data)),
                subtitle: Text(DateFormat('MMM dd, yyyy - HH:mm').format(date)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'plan_created':
        return Icons.add_circle;
      case 'plan_updated':
        return Icons.edit;
      case 'exercise_completed':
        return Icons.check_circle;
      default:
        return Icons.timeline;
    }
  }

  String _getActivityTitle(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'plan_created':
        return 'Created new plan: ${data['planTitle'] ?? 'Untitled'}';
      case 'plan_updated':
        return 'Updated plan: ${data['planTitle'] ?? 'Untitled'}';
      case 'exercise_completed':
        return 'Patient completed exercise';
      default:
        return 'Activity recorded';
    }
  }

  // Patients Tab
  Widget _buildPatientsTab() {
    return const PatientManagementDashboard();
  }

  // Notifications Tab - FIXED
  Widget _buildNotificationsTab() {
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
                  onPressed: _markAllNotificationsAsRead,
                  child: const Text('Mark All Read'),
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(
                        'users') // FIXED: Changed from 'therapists' to 'users'
                    .doc(authService.currentUser?.uid)
                    .collection('notifications')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You\'re all caught up!',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final notification = snapshot.data!.docs[index].data()
                          as Map<String, dynamic>;
                      final notificationId = snapshot.data!.docs[index].id;
                      final title = notification['title'] ?? 'Notification';
                      final message = notification['message'] ?? '';
                      final isRead = notification['isRead'] ?? false;
                      final timestamp = notification['timestamp'] as Timestamp?;
                      final type = notification['type'] ?? 'general';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isRead
                                  ? Colors.grey[200]
                                  : AppTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              _getNotificationIcon(type),
                              color:
                                  isRead ? Colors.grey : AppTheme.primaryBlue,
                            ),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              fontWeight:
                                  isRead ? FontWeight.normal : FontWeight.bold,
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
                                  color: isRead
                                      ? Colors.grey[600]
                                      : Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (timestamp != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatNotificationTime(timestamp.toDate()),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
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
                              notificationId, notification),
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

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'patient_added':
        return Icons.person_add;
      case 'plan_completed':
        return Icons.check_circle;
      case 'message':
        return Icons.message;
      case 'progress_update':
        return Icons.trending_up;
      default:
        return Icons.notifications;
    }
  }

  String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleNotificationTap(
      String notificationId, Map<String, dynamic> notification) {
    // Mark as read if not already read
    if (!(notification['isRead'] ?? false)) {
      _markNotificationAsRead(notificationId);
    }

    // Handle navigation based on notification type
    final type = notification['type'] ?? 'general';
    final patientId = notification['patientId'];
    final patientName = notification['patientName'];

    switch (type) {
      case 'patient_added':
        if (patientId != null && patientName != null) {
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
        break;
      case 'message':
        if (patientId != null && patientName != null) {
          _navigateToChat(patientId, patientName);
        }
        break;
      default:
        // Show notification details or do nothing
        break;
    }
  }

  // FIXED: Mark notification as read
  Future<void> _markNotificationAsRead(String notificationId) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await FirebaseFirestore.instance
          .collection('users') // FIXED: Changed from 'therapists' to 'users'
          .doc(authService.currentUser?.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // FIXED: Mark all notifications as read
  Future<void> _markAllNotificationsAsRead() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final notifications = await FirebaseFirestore.instance
          .collection('users') // FIXED: Changed from 'therapists' to 'users'
          .doc(authService.currentUser?.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  void _buildRecentActivityBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: _buildFullRecentActivity(scrollController),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFullRecentActivity(ScrollController scrollController) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('progress_logs')
          .where('therapistId', isEqualTo: authService.currentUser?.uid)
          .orderBy('date', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No recent activity'),
          );
        }

        return ListView.builder(
          controller: scrollController,
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] ?? 'activity';
            final date = (data['date'] as Timestamp).toDate();

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: _getActivityColor(type),
                child: Icon(
                  _getActivityIcon(type),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(_getActivityTitle(type, data)),
              subtitle: Text(DateFormat('MMM dd, yyyy - HH:mm').format(date)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            );
          },
        );
      },
    );
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'plan_created':
        return Colors.green;
      case 'plan_updated':
        return Colors.orange;
      case 'exercise_completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

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
                    .collection('therapists')
                    .doc(authService.currentUser?.uid)
                    .collection('patients')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No patients to chat with',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add patients to start conversations',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final patient = snapshot.data!.docs[index].data()
                          as Map<String, dynamic>;
                      final patientId = snapshot.data!.docs[index].id;
                      final patientName = patient['name'] ?? 'Unknown Patient';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryBlue,
                            child: Text(
                              patientName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(patientName),
                          subtitle: const Text('Tap to start conversation'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _navigateToChat(patientId, patientName),
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
    );
  }

  // Bottom Navigation - FIXED
  Widget _buildBottomNavigation() {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users') // FIXED: Changed from 'therapists' to 'users'
          .doc(authService.currentUser?.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
            if (index == 0) {
              _loadDashboardData(); // Refresh dashboard when selected
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryBlue,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 8,
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
                  if (unreadCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications),
                  if (unreadCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Notifications',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.chat_outlined),
              activeIcon: Icon(Icons.chat),
              label: 'Chats',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        );
      },
    );
  }
}
