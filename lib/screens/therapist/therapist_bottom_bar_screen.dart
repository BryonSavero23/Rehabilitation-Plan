import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'enhanced_therapist_chat_screen.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/screens/profile/profile_screen.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';

// Import the therapist dashboard
import 'therapist_dashboard_screen.dart';

class TherapistBottomBarScreen extends StatefulWidget {
  const TherapistBottomBarScreen({Key? key}) : super(key: key);

  @override
  State<TherapistBottomBarScreen> createState() =>
      _TherapistBottomBarScreenState();
}

class _TherapistBottomBarScreenState extends State<TherapistBottomBarScreen> {
  int _selectedIndex = 0;

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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const TherapistDashboardScreen(),
          _buildNotificationsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
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
          onTap: (index) => setState(() => _selectedIndex = index),
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
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined),
                  // You can add notification badge here
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
                        '3',
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
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

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
        // Navigate to dashboard analytics tab
        setState(() {
          _selectedIndex = 0; // Dashboard tab
        });
        break;

      case 'new_patient':
        // Navigate to patient management
        Navigator.pushNamed(context, '/patient_management');
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
