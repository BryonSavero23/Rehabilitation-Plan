import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/screens/profile/profile_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/user_input_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/progress/rehabilitation_progress_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/dashboard_home_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist_chat_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/exercise_recommendation_screen.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../saved_plans/saved_rehabilitation_plans.dart';

class BottomBarScreen extends StatefulWidget {
  const BottomBarScreen({super.key});

  @override
  State<BottomBarScreen> createState() => _BottomBarScreenState();
}

class _BottomBarScreenState extends State<BottomBarScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.initializeUser();

      // Redirect therapists to therapist interface
      final isTherapist = await authService.isUserTherapist();
      if (mounted && isTherapist) {
        Navigator.of(context).pushReplacementNamed('/therapist_home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          if (authService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Patient screens
          if (_selectedIndex == 0) {
            return const DashboardHomeScreen(); // Dashboard home
          } else if (_selectedIndex == 1) {
            return const UserInputScreen(); // Create plan
          } else if (_selectedIndex == 2) {
            return const SavedRehabilitationPlans(); // Saved plans
          } else if (_selectedIndex == 3) {
            // Show progress screen using StreamBuilder to get plans
            return StreamBuilder(
              stream: authService.getRehabilitationPlans(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  // Use the progress screen without pre-selecting a plan
                  return const RehabilitationProgressScreen();
                } else {
                  return const Center(
                    child: Text(
                        'No rehabilitation plans found. Create one to see progress.'),
                  );
                }
              },
            );
          } else if (_selectedIndex == 4) {
            return _buildNotificationsScreen(authService);
          } else {
            return const ProfileScreen();
          }
        },
      ),
      bottomNavigationBar: _buildPatientBottomNav(),
    );
  }

  Widget _buildNotificationsScreen(AuthService authService) {
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
                  onPressed: () => _markAllNotificationsAsRead(authService),
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
                  final unreadCount = notifications
                      .where((doc) =>
                          !(doc.data() as Map<String, dynamic>)['isRead'] ??
                          false)
                      .length;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length + 1, // +1 for header
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Header with unread count
                        return _buildNotificationHeader(unreadCount);
                      }

                      final notificationData = notifications[index - 1].data()
                          as Map<String, dynamic>;
                      final notificationId = notifications[index - 1].id;

                      return _buildNotificationCard(
                        notificationId: notificationId,
                        data: notificationData,
                        authService: authService,
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

  Widget _buildNotificationHeader(int unreadCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _buildNotificationCard({
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
          therapistId: therapistId,
          planId: planId,
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
    required AuthService authService,
    required bool isRead,
  }) async {
    // Mark notification as read if not already read
    if (!isRead) {
      await _markNotificationAsRead(notificationId, authService);
    }

    switch (type) {
      case 'exercise_reminder':
        // Navigate to progress tab
        setState(() {
          _selectedIndex = 3; // Progress tab
        });
        break;

      case 'progress_update':
        // Navigate to progress tab
        setState(() {
          _selectedIndex = 3; // Progress tab
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
          setState(() {
            _selectedIndex = 2; // Saved plans tab
          });
        }
        break;

      case 'therapist_added':
      case 'therapist_removed':
        // Navigate to profile
        setState(() {
          _selectedIndex = 5; // Profile tab
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

  Future<void> _markAllNotificationsAsRead(AuthService authService) async {
    try {
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

  // Bottom navigation for patient users - 6 tabs including Notifications
  Widget _buildPatientBottomNav() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(Provider.of<AuthService>(context).currentUser?.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed, // Required for 6 items
          selectedItemColor: AppTheme.primaryBlue,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              label: 'Create Plan',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.bookmark),
              label: 'My Plans',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.show_chart),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Stack(
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
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        );
      },
    );
  }
}
