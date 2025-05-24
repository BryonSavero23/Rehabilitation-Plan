import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/screens/exercise_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/exercise_recommendation_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist_chat_screen.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'package:personalized_rehabilitation_plans/widgets/progress_chart_widget.dart';
import 'package:personalized_rehabilitation_plans/screens/profile/profile_screen.dart';
import 'package:personalized_rehabilitation_plans/services/progress_service.dart';
import 'package:provider/provider.dart';

class RehabilitationProgressScreen extends StatefulWidget {
  final RehabilitationPlan plan;
  final String? planId;
  final String? therapistName;
  final String? therapistTitle;

  const RehabilitationProgressScreen({
    Key? key,
    required this.plan,
    this.planId,
    this.therapistName,
    this.therapistTitle,
  }) : super(key: key);

  @override
  State<RehabilitationProgressScreen> createState() =>
      _RehabilitationProgressScreenState();
}

class _RehabilitationProgressScreenState
    extends State<RehabilitationProgressScreen> {
  int _selectedDay = 0;
  int _selectedBottomNavIndex =
      0; // 0: Activity, 1: Progress Chart, 2: Notification, 3: Profile
  final List<DateTime> _weekDays = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateWeekDays();
  }

  void _generateWeekDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _weekDays.add(today);
    for (int i = 1; i < 6; i++) {
      _weekDays.add(today.add(Duration(days: i)));
    }
  }

  // Calculate completed exercises count
  int get _completedExercisesCount {
    return widget.plan.exercises.where((e) => e.isCompleted).length;
  }

  // Calculate remaining exercises
  int get _remainingExercisesCount {
    return widget.plan.exercises.length - _completedExercisesCount;
  }

  // Calculate missed exercises (placeholder)
  int get _missedExercisesCount {
    // This is simplified - in a real app, you'd track missed sessions
    return 1; // Placeholder
  }

  // Total exercises
  int get _totalExercisesCount {
    return widget.plan.exercises.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: _buildBodyContent(),
                    ),
                  ),
                  _buildBottomNavigation(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final therapistName = widget.therapistName ?? "Your Therapist";
    final therapistTitle = widget.therapistTitle ?? "";

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(
                'https://placehold.co/100x100/orange/white?text=T'),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.plan.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              Text(
                '$therapistTitle $therapistName',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_selectedBottomNavIndex) {
      case 0:
        return _buildActivityTab();
      case 1:
        return _buildProgressChartTab();
      case 2:
        return _buildNotificationTab();
      case 3:
        return _buildProfileTab();
      default:
        return _buildActivityTab();
    }
  }

  Widget _buildActivityTab() {
    return Column(
      children: [
        _buildProgressSection(),
        _buildCalendar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSessionsForToday(),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressChartTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress Charts',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Fetch and display progress data
          Consumer<ProgressService>(
            builder: (context, progressService, child) {
              return FutureBuilder<Map<String, dynamic>>(
                future: _getProgressData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Center(
                      child: Text('Unable to load progress data'),
                    );
                  }

                  final data = snapshot.data!;
                  final painLevels =
                      List<double>.from(data['painLevels'] ?? []);
                  final adherenceRates =
                      List<int>.from(data['adherenceRates'] ?? []);
                  final dates = List<String>.from(data['dates'] ?? []);

                  if (painLevels.isEmpty || adherenceRates.isEmpty) {
                    return _buildNoDataMessage();
                  }

                  return Column(
                    children: [
                      // Combined Progress Chart
                      ProgressChartWidget(
                        painLevels: painLevels,
                        adherenceRates: adherenceRates,
                        dates: dates,
                        title: 'Pain Level & Adherence Trends',
                      ),
                      const SizedBox(height: 20),

                      // Individual Pain Chart
                      SimpleProgressChart(
                        values: painLevels,
                        labels: dates,
                        title: 'Pain Level Over Time',
                        color: Colors.red,
                        maxValue: 10,
                        yAxisLabel: 'Pain Level (0-10)',
                      ),
                      const SizedBox(height: 20),

                      // Individual Adherence Chart
                      SimpleProgressChart(
                        values:
                            adherenceRates.map((e) => e.toDouble()).toList(),
                        labels: dates,
                        title: 'Adherence Rate Over Time',
                        color: Colors.green,
                        maxValue: 100,
                        yAxisLabel: 'Adherence (%)',
                      ),
                      const SizedBox(height: 20),

                      // Progress Summary Cards
                      _buildProgressSummaryCards(data),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.show_chart,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No Progress Data Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete some exercises to see your progress charts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSummaryCards(Map<String, dynamic> data) {
    final painLevels = List<double>.from(data['painLevels'] ?? []);
    final adherenceRates = List<int>.from(data['adherenceRates'] ?? []);

    final avgPain = painLevels.isNotEmpty
        ? painLevels.reduce((a, b) => a + b) / painLevels.length
        : 0;
    final avgAdherence = adherenceRates.isNotEmpty
        ? adherenceRates.reduce((a, b) => a + b) / adherenceRates.length
        : 0;

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.trending_down,
                    color: avgPain <= 5 ? Colors.green : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Avg Pain Level',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    avgPain.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: avgAdherence >= 80 ? Colors.green : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Avg Adherence',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${avgAdherence.round()}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationTab() {
    final authService = Provider.of<AuthService>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Real notifications from Firestore
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(authService.currentUser?.uid)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildNoNotificationsMessage();
              }

              final notifications = snapshot.data!.docs;
              final unreadCount = notifications
                  .where((doc) =>
                      !(doc.data() as Map<String, dynamic>)['isRead'] ?? false)
                  .length;

              return Column(
                children: [
                  // Unread count badge
                  if (unreadCount > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$unreadCount unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Notifications list
                  ...notifications.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildRealNotificationCard(
                      notificationId: doc.id,
                      data: data,
                      authService: authService,
                    );
                  }).toList(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoNotificationsMessage() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
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
      ),
    );
  }

  Widget _buildRealNotificationCard({
    required String notificationId,
    required Map<String, dynamic> data,
    required AuthService authService,
  }) {
    final title = data['title'] ?? 'Notification';
    final message = data['message'] ?? '';
    final type = data['type'] ?? 'general';
    final isRead = data['isRead'] ?? false;
    final timestamp = data['timestamp'] as Timestamp?;
    final therapistId = data['therapistId'] as String?;
    final planId = data['planId'] as String?;
    final progressId = data['progressId'] as String?;

    final time = timestamp != null
        ? _formatNotificationTime(timestamp.toDate())
        : 'Unknown time';

    // Get icon and color based on notification type
    IconData icon;
    Color color;

    switch (type) {
      case 'exercise_reminder':
        icon = Icons.fitness_center;
        color = Colors.blue;
        break;
      case 'progress_update':
        icon = Icons.trending_up;
        color = Colors.green;
        break;
      case 'therapist_message':
        icon = Icons.message;
        color = Colors.purple;
        break;
      case 'plan_updated':
        icon = Icons.update;
        color = Colors.orange;
        break;
      case 'therapist_added':
        icon = Icons.person_add;
        color = Colors.teal;
        break;
      case 'therapist_removed':
        icon = Icons.person_remove;
        color = Colors.red;
        break;
      case 'appointment_reminder':
        icon = Icons.calendar_today;
        color = Colors.indigo;
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
          therapistId: therapistId,
          planId: planId,
          progressId: progressId,
          authService: authService,
          isRead: isRead,
        ),
      ),
    );
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

  Future<void> _handleNotificationTap({
    required String type,
    required String notificationId,
    String? therapistId,
    String? planId,
    String? progressId,
    required AuthService authService,
    required bool isRead,
  }) async {
    // Mark notification as read if not already read
    if (!isRead) {
      await _markNotificationAsRead(notificationId, authService);
    }

    switch (type) {
      case 'exercise_reminder':
        // Navigate to activity tab (exercises)
        setState(() {
          _selectedBottomNavIndex = 0; // Activity tab
        });
        break;

      case 'progress_update':
        // Navigate to activity tab to show progress
        setState(() {
          _selectedBottomNavIndex = 0; // Activity tab
        });
        break;

      case 'therapist_message':
        if (therapistId != null) {
          await _navigateToTherapistChat(therapistId, authService);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Therapist information not available')),
          );
        }
        break;

      case 'plan_updated':
        if (planId != null) {
          await _navigateToPlanDetails(planId);
        } else {
          // Navigate to saved plans
          Navigator.pushNamed(context, '/saved_plans');
        }
        break;

      case 'therapist_added':
      case 'therapist_removed':
        // Navigate to profile or therapist management
        setState(() {
          _selectedBottomNavIndex = 3; // Profile tab
        });
        break;

      case 'appointment_reminder':
        // Could navigate to calendar or appointment screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calendar feature coming soon')),
        );
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

  Future<void> _navigateToTherapistChat(
      String therapistId, AuthService authService) async {
    try {
      // Get therapist details
      final therapistDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(therapistId)
          .get();

      if (therapistDoc.exists) {
        final therapistData = therapistDoc.data()!;
        final therapistName = therapistData['name'] ?? 'Unknown Therapist';

        // Get therapist profile for title
        final therapistProfileDoc = await FirebaseFirestore.instance
            .collection('therapists')
            .doc(therapistId)
            .get();

        String therapistTitle = 'Dr.'; // Default title
        if (therapistProfileDoc.exists) {
          therapistTitle = therapistProfileDoc.data()?['title'] ?? 'Dr.';
        }

        // Navigate to chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TherapistChatScreen(
              therapistId: therapistId,
              therapistName: therapistName,
              therapistTitle: therapistTitle,
              patientId: authService.currentUser!.uid,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Therapist not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading therapist: $e')),
      );
    }
  }

  Future<void> _navigateToPlanDetails(String planId) async {
    try {
      final planDoc = await FirebaseFirestore.instance
          .collection('rehabilitation_plans')
          .doc(planId)
          .get();

      if (planDoc.exists) {
        final planData = planDoc.data()!;
        final plan = RehabilitationPlan.fromJson(planData);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExerciseRecommendationScreen(
              plan: plan,
              planId: planId,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading plan: $e')),
      );
    }
  }

  Widget _buildProfileTab() {
    return const ProfileScreen();
  }

  Future<Map<String, dynamic>> _getProgressData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final progressService =
        Provider.of<ProgressService>(context, listen: false);

    if (authService.currentUser?.uid != null) {
      return await progressService.getProgressTrends(
        authService.currentUser!.uid,
        daysBack: 30,
      );
    }

    // Return mock data if no user
    return {
      'painLevels': [8.0, 7.5, 6.0, 5.5, 4.0, 3.5, 3.0],
      'adherenceRates': [60, 70, 75, 80, 85, 90, 95],
      'dates': ['1/12', '2/12', '3/12', '4/12', '5/12', '6/12', '7/12'],
    };
  }

  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'First Phase of Recovery',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProgressItem(
                  _remainingExercisesCount, 'Remaining', Colors.grey.shade300),
              _buildProgressIndicator(),
              _buildProgressItem(
                  _missedExercisesCount, 'Missed', AppTheme.vibrantRed),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Complete all exercises to finish your rehabilitation plan',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(int count, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade100,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.2),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: _completedExercisesCount /
                  (_totalExercisesCount > 0 ? _totalExercisesCount : 1),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFFCCDD00),
              ),
              strokeWidth: 8,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _completedExercisesCount.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'of $_totalExercisesCount Completed',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              _weekDays.length,
              (index) => _buildCalendarDay(index),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Today, ${DateFormat('dd MMM yyyy').format(_weekDays[_selectedDay])} (${_getSessionsForDay(_weekDays[_selectedDay]).length} therapy sessions)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCalendarDay(int index) {
    final day = _weekDays[index];
    final isSelected = index == _selectedDay;
    final isToday = index == 0;
    final accentColor = AppTheme.vibrantRed;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = index;
        });
      },
      child: Container(
        width: 40,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? accentColor : Colors.transparent,
          border: isToday && !isSelected
              ? Border.all(color: accentColor, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E').format(day).toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              day.day.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Get exercises scheduled for a specific day
  List<Exercise> _getSessionsForDay(DateTime day) {
    // This is a simplified implementation
    // In a real app, you would filter exercises based on scheduled dates
    if (day.weekday <= widget.plan.exercises.length) {
      // Return a subset of exercises based on the day of week
      return [
        widget.plan.exercises[(day.weekday - 1) % widget.plan.exercises.length]
      ];
    }
    return [];
  }

  Widget _buildSessionsForToday() {
    final selectedDayExercises = _getSessionsForDay(_weekDays[_selectedDay]);

    if (selectedDayExercises.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'No exercises scheduled for today',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ),
      );
    }

    return Column(
      children: selectedDayExercises.asMap().entries.map((entry) {
        final index = entry.key;
        final exercise = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildExerciseCard(
            exercise: exercise,
            isActive: !exercise.isCompleted, // Active if not completed
            startTime: index == 0 ? '9 am' : '2 pm', // Example times
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExerciseCard({
    required Exercise exercise,
    required bool isActive,
    required String startTime,
  }) {
    final bool exerciseCompleted = exercise.isCompleted;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child:
                      exercise.imageUrl != null && exercise.imageUrl!.isNotEmpty
                          ? Image.network(
                              exercise.imageUrl!,
                              width: 80,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 60,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.fitness_center,
                                      color: Colors.white),
                                );
                              },
                            )
                          : Container(
                              width: 80,
                              height: 60,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.fitness_center,
                                  color: Colors.white),
                            ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.fitness_center,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${exercise.sets} Sets, ${exercise.reps} Reps',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                          const Spacer(),
                          if (exerciseCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 12,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Completed',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exercise.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${exercise.durationSeconds ~/ 60}-${(exercise.durationSeconds ~/ 60) + 5} min',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '|',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Start session from $startTime',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: exerciseCompleted
                  ? () {
                      // Show completion details or allow to redo
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Exercise already completed!')),
                      );
                    }
                  : () => _navigateToExerciseDetail(exercise),
              style: ElevatedButton.styleFrom(
                backgroundColor: exerciseCompleted
                    ? Colors.grey.shade400 // Completed
                    : const Color(0xFFCCDD00), // Not completed - active
                foregroundColor:
                    exerciseCompleted ? Colors.white : Colors.black,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),
              child: Text(
                exerciseCompleted ? 'View Details' : 'Start Now',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToExerciseDetail(Exercise exercise) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Navigate to exercise screen
      bool? isCompleted = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExerciseScreen(exercise: exercise),
        ),
      );

      if (isCompleted == true && widget.planId != null) {
        // Update the exercise completion status
        final index =
            widget.plan.exercises.indexWhere((e) => e.id == exercise.id);
        if (index != -1) {
          setState(() {
            widget.plan.exercises[index].isCompleted = true;
          });

          // Save the updated plan
          final authService = Provider.of<AuthService>(context, listen: false);
          await authService.updateRehabilitationPlan(
              widget.planId!, widget.plan);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.2),
            blurRadius: 6,
            spreadRadius: 2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomNavItem(
            Icons.show_chart,
            'Activity',
            0,
          ),
          _buildBottomNavItem(
            Icons.bar_chart,
            'Progress Chart',
            1,
          ),
          _buildBottomNavItem(
            Icons.notifications_none,
            'Notification',
            2,
            hasBadge: true,
          ),
          _buildBottomNavItem(
            Icons.person_outline,
            'Profile',
            3,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(
    IconData icon,
    String label,
    int index, {
    bool hasBadge = false,
  }) {
    final isSelected = _selectedBottomNavIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBottomNavIndex = index;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              if (hasBadge)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '2',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
