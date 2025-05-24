import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/patient_detail_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/progress/progress_details_screen.dart';
import 'package:intl/intl.dart';

class EnhancedTherapistChatScreen extends StatefulWidget {
  final String therapistId;
  final String therapistName;
  final String therapistTitle;
  final String patientId;
  final String patientName;

  const EnhancedTherapistChatScreen({
    Key? key,
    required this.therapistId,
    required this.therapistName,
    required this.therapistTitle,
    required this.patientId,
    required this.patientName,
  }) : super(key: key);

  @override
  State<EnhancedTherapistChatScreen> createState() =>
      _EnhancedTherapistChatScreenState();
}

class _EnhancedTherapistChatScreenState
    extends State<EnhancedTherapistChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _chatRoomId;
  bool _isLoading = false;
  bool _showQuickReplies = false;

  final List<String> _quickReplies = [
    "Great progress! Keep it up! 👏",
    "How are you feeling today?",
    "Remember to take breaks between exercises",
    "Any pain or discomfort?",
    "Let's schedule a check-up",
    "Your adherence has improved!",
    "Try to maintain this routine",
    "Don't forget to warm up",
  ];

  @override
  void initState() {
    super.initState();
    _initializeChatRoom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeChatRoom() {
    // Create a consistent chat room ID using both user IDs
    final ids = [widget.patientId, widget.therapistId];
    ids.sort(); // Ensure consistent ordering
    _chatRoomId = ids.join('_');
  }

  Future<void> _sendMessage([String? customMessage]) async {
    final messageText = customMessage ?? _messageController.text.trim();
    if (messageText.isEmpty) return;

    if (customMessage == null) {
      _messageController.clear();
    }

    setState(() {
      _isLoading = true;
      _showQuickReplies = false;
    });

    try {
      // Add message to chat room
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderId': widget.therapistId,
        'senderName': '${widget.therapistTitle} ${widget.therapistName}',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'messageType': 'text',
      });

      // Update last message in chat room document
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatRoomId)
          .set({
        'participants': [widget.patientId, widget.therapistId],
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': widget.therapistId,
        'patientId': widget.patientId,
        'therapistId': widget.therapistId,
      }, SetOptions(merge: true));

      // Send notification to patient
      await _sendNotificationToPatient(messageText);

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendNotificationToPatient(String messageText) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .collection('notifications')
          .add({
        'title':
            'Message from ${widget.therapistTitle} ${widget.therapistName}',
        'message': messageText.length > 50
            ? '${messageText.substring(0, 50)}...'
            : messageText,
        'type': 'therapist_message',
        'senderId': widget.therapistId,
        'chatRoomId': _chatRoomId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final unreadMessages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatRoomId)
          .collection('messages')
          .where('senderId', isEqualTo: widget.patientId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryBlue,
              child: Text(
                widget.patientName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.patientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.patientId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      bool isOnline = false;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>?;
                        isOnline = data?['isOnline'] ?? false;
                      }

                      return Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline ? Colors.green : Colors.grey,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _navigateToPatientProfile(),
            tooltip: 'View Profile',
          ),
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () => _showPatientProgressSummary(),
            tooltip: 'View Progress',
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view_plans',
                child: ListTile(
                  leading: Icon(Icons.assignment),
                  title: Text('View Plans'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'schedule_appointment',
                child: ListTile(
                  leading: Icon(Icons.calendar_today),
                  title: Text('Schedule Appointment'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'send_reminder',
                child: ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text('Send Reminder'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
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
        child: Column(
          children: [
            _buildPatientInfoCard(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(_chatRoomId)
                    .collection('messages')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyChatState();
                  }

                  final messages = snapshot.data!.docs;

                  // Mark messages as read when viewing
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markMessagesAsRead();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final messageData =
                          messages[index].data() as Map<String, dynamic>;
                      return _buildMessageBubble(messageData);
                    },
                  );
                },
              ),
            ),
            if (_showQuickReplies) _buildQuickReplies(),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getPatientQuickInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final info = snapshot.data!;
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
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
          child: Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Last Session',
                  info['lastSession'] ?? 'None',
                  Icons.fitness_center,
                ),
              ),
              Container(width: 1, height: 30, color: Colors.grey[300]),
              Expanded(
                child: _buildInfoItem(
                  'Adherence',
                  '${info['adherence'] ?? 0}%',
                  Icons.check_circle,
                ),
              ),
              Container(width: 1, height: 30, color: Colors.grey[300]),
              Expanded(
                child: _buildInfoItem(
                  'Pain Level',
                  '${info['painLevel'] ?? 'N/A'}/10',
                  Icons.healing,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryBlue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChatState() {
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
          Text(
            'Start a conversation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to ${widget.patientName}',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _showQuickReplies = true),
            child: const Text('Use Quick Reply'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData) {
    final text = messageData['text'] ?? '';
    final senderId = messageData['senderId'] ?? '';
    final timestamp = messageData['timestamp'] as Timestamp?;
    final messageType = messageData['messageType'] ?? 'text';
    final isFromTherapist = senderId == widget.therapistId;
    final isFromPatient = senderId == widget.patientId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isFromTherapist ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isFromPatient) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryBlue,
              child: Text(
                widget.patientName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isFromTherapist ? AppTheme.primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (messageType == 'progress_report') ...[
                    Row(
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 16,
                          color: isFromTherapist
                              ? Colors.white70
                              : AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Progress Report',
                          style: TextStyle(
                            color: isFromTherapist
                                ? Colors.white70
                                : AppTheme.primaryBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (messageType == 'pain_update') ...[
                    Row(
                      children: [
                        Icon(
                          Icons.healing,
                          size: 16,
                          color:
                              isFromTherapist ? Colors.white70 : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Pain Update',
                          style: TextStyle(
                            color: isFromTherapist
                                ? Colors.white70
                                : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: isFromTherapist ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timestamp != null
                            ? _formatTime(timestamp.toDate())
                            : 'Sending...',
                        style: TextStyle(
                          color:
                              isFromTherapist ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      if (isFromTherapist) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isFromTherapist) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.vibrantRed.withOpacity(0.1),
              child: const Icon(
                Icons.medical_services,
                size: 16,
                color: AppTheme.vibrantRed,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey, width: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Replies',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _showQuickReplies = false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickReplies.map((reply) {
              return GestureDetector(
                onTap: () => _sendMessage(reply),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    reply,
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey, width: 0.2),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAttachmentOptions(),
            color: Colors.grey[600],
          ),
          IconButton(
            icon: Icon(
              _showQuickReplies ? Icons.keyboard : Icons.comment,
              color: AppTheme.primaryBlue,
            ),
            onPressed: () =>
                setState(() => _showQuickReplies = !_showQuickReplies),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _isLoading ? Colors.grey : AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send),
              onPressed: _isLoading ? null : () => _sendMessage(),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Therapist Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.assignment, color: Colors.blue),
              title: const Text('Send Exercise Plan'),
              subtitle: const Text('Share a rehabilitation plan'),
              onTap: () {
                Navigator.pop(context);
                _sendExercisePlan();
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.green),
              title: const Text('Schedule Appointment'),
              subtitle: const Text('Book a session'),
              onTap: () {
                Navigator.pop(context);
                _scheduleAppointment();
              },
            ),
            ListTile(
              leading: const Icon(Icons.healing, color: Colors.orange),
              title: const Text('Request Pain Update'),
              subtitle: const Text('Ask for current pain level'),
              onTap: () {
                Navigator.pop(context);
                _requestPainUpdate();
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart, color: Colors.purple),
              title: const Text('Request Progress Report'),
              subtitle: const Text('Ask for latest progress'),
              onTap: () {
                Navigator.pop(context);
                _requestProgressReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications, color: Colors.red),
              title: const Text('Send Reminder'),
              subtitle: const Text('Exercise or appointment reminder'),
              onTap: () {
                Navigator.pop(context);
                _sendReminder();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendExercisePlan() async {
    try {
      // Get patient's latest rehabilitation plan
      final plansSnapshot = await FirebaseFirestore.instance
          .collection('rehabilitation_plans')
          .where('userId', isEqualTo: widget.patientId)
          .where('therapistId', isEqualTo: widget.therapistId)
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      if (plansSnapshot.docs.isNotEmpty) {
        final planData = plansSnapshot.docs.first.data();
        final planTitle = planData['title'] ?? 'Rehabilitation Plan';
        final exerciseCount = (planData['exercises'] as List?)?.length ?? 0;

        final message = '''📋 Exercise Plan: $planTitle

I've shared an updated rehabilitation plan with you. It includes $exerciseCount exercises designed specifically for your recovery.

Please review the plan and let me know if you have any questions. Remember to start slowly and listen to your body.''';

        await _sendMessage(message);
      } else {
        await _sendMessage(
            'I\'ll prepare a personalized exercise plan for you soon. Please check back later for updates.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending exercise plan: $e')),
      );
    }
  }

  Future<void> _scheduleAppointment() async {
    final message = '''📅 Appointment Scheduling

I'd like to schedule a follow-up appointment with you. Please let me know your availability for the next week:

• Monday-Friday: 9 AM - 5 PM
• Weekends: 10 AM - 2 PM

We can discuss your progress and adjust your rehabilitation plan as needed.''';

    await _sendMessage(message);
  }

  Future<void> _requestPainUpdate() async {
    final message = '''🩺 Pain Level Check

How are you feeling today? Please share your current pain level on a scale of 0-10:

• 0 = No pain
• 1-3 = Mild pain
• 4-6 = Moderate pain
• 7-10 = Severe pain

Also, let me know if there are any specific areas of concern or if the pain has changed since our last session.''';

    await _sendMessage(message);
  }

  Future<void> _requestProgressReport() async {
    final message = '''📊 Progress Update Request

I'd like to get an update on your recent progress. Please share:

1. How many exercise sessions you completed this week
2. Any difficulties you encountered
3. Your overall comfort level with the current routine
4. Any improvements you've noticed

Your feedback helps me adjust your plan to ensure the best recovery outcomes.''';

    await _sendMessage(message);
  }

  Future<void> _sendReminder() async {
    final message = '''⏰ Friendly Reminder

This is a gentle reminder to:

• Complete your daily exercises
• Take breaks when needed
• Stay hydrated
• Track your progress

Consistency is key to your recovery. You're doing great, and I'm here to support you every step of the way!''';

    await _sendMessage(message);
  }

  Future<Map<String, dynamic>> _getPatientQuickInfo() async {
    try {
      // Get latest progress log
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('progress_logs')
          .where('userId', isEqualTo: widget.patientId)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (progressSnapshot.docs.isEmpty) {
        return {
          'lastSession': 'None',
          'adherence': 0,
          'painLevel': 'N/A',
        };
      }

      final latestLog = progressSnapshot.docs.first.data();
      final date =
          (latestLog['date'] as Timestamp?)?.toDate() ?? DateTime.now();
      final adherence = latestLog['adherencePercentage'] ?? 0;
      final exerciseLogs = latestLog['exerciseLogs'] as List<dynamic>? ?? [];

      // Calculate average pain level
      double avgPain = 0;
      if (exerciseLogs.isNotEmpty) {
        double totalPain = 0;
        for (var exercise in exerciseLogs) {
          totalPain += (exercise['painLevel'] ?? 0);
        }
        avgPain = totalPain / exerciseLogs.length;
      }

      return {
        'lastSession': _formatDate(date),
        'adherence': adherence,
        'painLevel': avgPain.toStringAsFixed(1),
      };
    } catch (e) {
      print('Error getting patient quick info: $e');
      return {
        'lastSession': 'Error',
        'adherence': 0,
        'painLevel': 'N/A',
      };
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

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
      return DateFormat('MMM dd').format(date);
    }
  }

  void _navigateToPatientProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(
          patientId: widget.patientId,
          patientName: widget.patientName,
        ),
      ),
    );
  }

  Future<void> _showPatientProgressSummary() async {
    try {
      final progressData = await _getPatientQuickInfo();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${widget.patientName}\'s Progress'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProgressItem('Last Session', progressData['lastSession']),
              _buildProgressItem(
                  'Adherence Rate', '${progressData['adherence']}%'),
              _buildProgressItem(
                  'Average Pain Level', '${progressData['painLevel']}/10'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _navigateToPatientProfile();
              },
              child: const Text('View Details'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading progress: $e')),
      );
    }
  }

  Widget _buildProgressItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'view_plans':
        _navigateToPatientProfile();
        break;
      case 'schedule_appointment':
        _scheduleAppointment();
        break;
      case 'send_reminder':
        _sendReminder();
        break;
    }
  }
}
