import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';

class TherapistChatScreen extends StatefulWidget {
  final String therapistId;
  final String therapistName;
  final String therapistTitle;
  final String patientId;

  const TherapistChatScreen({
    super.key,
    required this.therapistId,
    required this.therapistName,
    required this.therapistTitle,
    required this.patientId,
  });

  @override
  State<TherapistChatScreen> createState() => _TherapistChatScreenState();
}

class _TherapistChatScreenState extends State<TherapistChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _chatRoomId;
  bool _isLoading = false;

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

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _isLoading = true;
    });

    try {
      // Add message to chat room
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderId': widget.patientId,
        'senderName': 'Patient', // You can get this from user data
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update last message in chat room document
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatRoomId)
          .set({
        'participants': [widget.patientId, widget.therapistId],
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': widget.patientId,
        'patientId': widget.patientId,
        'therapistId': widget.therapistId,
      }, SetOptions(merge: true));

      // Send notification to therapist
      await _sendNotificationToTherapist(messageText);

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

  Future<void> _sendNotificationToTherapist(String messageText) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.therapistId)
          .collection('notifications')
          .add({
        'title': 'New Message from Patient',
        'message': messageText.length > 50
            ? '${messageText.substring(0, 50)}...'
            : messageText,
        'type': 'patient_message',
        'senderId': widget.patientId,
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
          .where('senderId', isEqualTo: widget.therapistId)
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
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
              child: Text(
                widget.therapistName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: AppTheme.primaryBlue,
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
                    '${widget.therapistTitle} ${widget.therapistName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.therapistId)
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
            icon: const Icon(Icons.videocam),
            onPressed: () {
              _showVideoCallDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              _showCallDialog();
            },
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
            _buildMessageInput(),
          ],
        ),
      ),
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
            'Send a message to ${widget.therapistTitle} ${widget.therapistName}',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData) {
    final text = messageData['text'] ?? '';
    final senderId = messageData['senderId'] ?? '';
    final timestamp = messageData['timestamp'] as Timestamp?;
    final isFromTherapist = senderId == widget.therapistId;
    final isFromCurrentUser = senderId == widget.patientId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isFromCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isFromTherapist) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
              child: Text(
                widget.therapistName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: AppTheme.primaryBlue,
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
                color: isFromCurrentUser ? AppTheme.primaryBlue : Colors.white,
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
                  Text(
                    text,
                    style: TextStyle(
                      color: isFromCurrentUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timestamp != null
                        ? _formatTime(timestamp.toDate())
                        : 'Sending...',
                    style: TextStyle(
                      color:
                          isFromCurrentUser ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isFromCurrentUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.vibrantRed.withOpacity(0.1),
              child: const Icon(
                Icons.person,
                size: 16,
                color: AppTheme.vibrantRed,
              ),
            ),
          ],
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
            icon: const Icon(Icons.attach_file),
            onPressed: () {
              _showAttachmentOptions();
            },
            color: Colors.grey[600],
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
              onPressed: _isLoading ? null : _sendMessage,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
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

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Content',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.blue),
              title: const Text('Camera'),
              subtitle: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _sendProgressPhoto('camera');
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Photo Library'),
              subtitle: const Text('Share a photo'),
              onTap: () {
                Navigator.pop(context);
                _sendProgressPhoto('gallery');
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart, color: Colors.purple),
              title: const Text('Progress Report'),
              subtitle: const Text('Share your latest progress'),
              onTap: () {
                Navigator.pop(context);
                _sendProgressReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.healing, color: Colors.orange),
              title: const Text('Pain Level Update'),
              subtitle: const Text('Report current pain level'),
              onTap: () {
                Navigator.pop(context);
                _sendPainLevelUpdate();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sendProgressPhoto(String source) {
    // Placeholder for photo functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$source feature will be implemented with image picker'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  void _sendProgressReport() async {
    try {
      // Get latest progress data and send as message
      final progressMessage = await _generateProgressReport();

      if (progressMessage.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(_chatRoomId)
            .collection('messages')
            .add({
          'text': progressMessage,
          'senderId': widget.patientId,
          'senderName': 'Patient',
          'type': 'progress_report',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        await _sendNotificationToTherapist('Shared a progress report');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing progress: $e')),
      );
    }
  }

  Future<String> _generateProgressReport() async {
    try {
      // Get recent progress logs
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('progressLogs')
          .where('userId', isEqualTo: widget.patientId)
          .orderBy('date', descending: true)
          .limit(7)
          .get();

      if (progressSnapshot.docs.isEmpty) {
        return '📊 Progress Report: No recent activity to report.';
      }

      final logs = progressSnapshot.docs;
      final totalLogs = logs.length;

      // Calculate averages
      double totalAdherence = 0;
      double totalPain = 0;
      int exercisesCompleted = 0;

      for (var log in logs) {
        final data = log.data();
        totalAdherence += (data['adherencePercentage'] ?? 0).toDouble();

        final exerciseLogs = data['exerciseLogs'] as List<dynamic>? ?? [];
        exercisesCompleted += exerciseLogs.length;

        for (var exercise in exerciseLogs) {
          totalPain += (exercise['painLevel'] ?? 0).toDouble();
        }
      }

      final avgAdherence = (totalAdherence / totalLogs).round();
      final avgPain =
          exercisesCompleted > 0 ? (totalPain / exercisesCompleted) : 0.0;

      return '''📊 Progress Report (Last 7 days)

• Sessions completed: $totalLogs
• Average adherence: $avgAdherence%
• Average pain level: ${avgPain.toStringAsFixed(1)}/10
• Total exercises: $exercisesCompleted

${_getPainTrend(avgPain)} ${_getAdherenceFeedback(avgAdherence)}''';
    } catch (e) {
      return '📊 Progress Report: Unable to generate report at this time.';
    }
  }

  String _getPainTrend(double avgPain) {
    if (avgPain <= 3.0) {
      return '✅ Pain levels are well managed!';
    } else if (avgPain <= 6.0) {
      return '⚠️ Moderate pain levels reported.';
    } else {
      return '🔴 High pain levels need attention.';
    }
  }

  String _getAdherenceFeedback(int avgAdherence) {
    if (avgAdherence >= 80) {
      return 'Great consistency with exercises!';
    } else if (avgAdherence >= 60) {
      return 'Good progress, could improve consistency.';
    } else {
      return 'Need to focus on exercise adherence.';
    }
  }

  void _sendPainLevelUpdate() {
    showDialog(
      context: context,
      builder: (context) => _PainLevelDialog(
        onSubmit: (painLevel, notes) async {
          final message = '''🩺 Pain Level Update

Current pain level: $painLevel/10
${notes.isNotEmpty ? 'Notes: $notes' : ''}

Reported at: ${DateTime.now().toString().split('.')[0]}''';

          await FirebaseFirestore.instance
              .collection('chats')
              .doc(_chatRoomId)
              .collection('messages')
              .add({
            'text': message,
            'senderId': widget.patientId,
            'senderName': 'Patient',
            'type': 'pain_update',
            'painLevel': painLevel,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });

          await _sendNotificationToTherapist(
              'Reported pain level: $painLevel/10');
        },
      ),
    );
  }

  void _showVideoCallDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Call'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam,
              size: 48,
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(height: 16),
            Text(
                'Start a video call with ${widget.therapistTitle} ${widget.therapistName}?'),
            const SizedBox(height: 8),
            const Text(
              'This will send a call request notification.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendCallRequest('video');
            },
            child: const Text('Start Call'),
          ),
        ],
      ),
    );
  }

  void _showCallDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Call'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.call,
              size: 48,
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(height: 16),
            Text(
                'Start a voice call with ${widget.therapistTitle} ${widget.therapistName}?'),
            const SizedBox(height: 8),
            const Text(
              'This will send a call request notification.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendCallRequest('voice');
            },
            child: const Text('Start Call'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCallRequest(String callType) async {
    try {
      // Send call request notification to therapist
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.therapistId)
          .collection('notifications')
          .add({
        'title': '${callType == 'video' ? 'Video' : 'Voice'} Call Request',
        'message': 'Patient is requesting a $callType call',
        'type': 'call_request',
        'callType': callType,
        'senderId': widget.patientId,
        'chatRoomId': _chatRoomId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Send message in chat
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'text': '📞 Requested a $callType call',
        'senderId': widget.patientId,
        'senderName': 'Patient',
        'type': 'call_request',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$callType call request sent to ${widget.therapistTitle} ${widget.therapistName}'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending call request: $e')),
      );
    }
  }
}

class _PainLevelDialog extends StatefulWidget {
  final Function(int painLevel, String notes) onSubmit;

  const _PainLevelDialog({required this.onSubmit});

  @override
  State<_PainLevelDialog> createState() => _PainLevelDialogState();
}

class _PainLevelDialogState extends State<_PainLevelDialog> {
  int _painLevel = 5;
  final _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pain Level Update'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How is your pain level right now?'),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('0'),
              Expanded(
                child: Slider(
                  value: _painLevel.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: _painLevel.toString(),
                  onChanged: (value) {
                    setState(() {
                      _painLevel = value.round();
                    });
                  },
                ),
              ),
              const Text('10'),
            ],
          ),
          Text(
            'Pain Level: $_painLevel/10',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Additional notes (optional)',
              hintText: 'Describe your pain or symptoms...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSubmit(_painLevel, _notesController.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Share Update'),
        ),
      ],
    );
  }
}
