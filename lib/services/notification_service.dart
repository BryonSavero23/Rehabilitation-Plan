// lib/services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> initializeNotifications(String userId) async {
    // Request permission
    await _requestPermission();

    // Get FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToFirestore(userId, token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) {
      _saveTokenToFirestore(userId, token);
    });

    // Load existing notifications
    await _loadNotifications(userId);

    // Listen for new notifications
    _listenForNotifications(userId);
  }

  Future<void> _requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }
  }

  Future<void> _saveTokenToFirestore(String userId, String token) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  Future<void> _loadNotifications(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    _notifications = snapshot.docs
        .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
        .toList();

    notifyListeners();
  }

  void _listenForNotifications(String userId) {
    _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _notifications = snapshot.docs
          .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
          .toList();

      notifyListeners();
    });
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();

    for (final notification in _notifications.where((n) => !n.isRead)) {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notification.id);

      batch.update(docRef, {'isRead': true});
    }

    await batch.commit();
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'title': title,
      'message': message,
      'type': type,
      'data': data,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.data,
    required this.isRead,
    required this.timestamp,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? '',
      data: map['data'],
      isRead: map['isRead'] ?? false,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  IconData get icon {
    switch (type) {
      case 'therapist_added':
        return Icons.person_add;
      case 'therapist_removed':
        return Icons.person_remove;
      case 'plan_created':
        return Icons.assignment;
      case 'plan_update':
        return Icons.edit;
      case 'progress_reminder':
        return Icons.alarm;
      case 'achievement':
        return Icons.emoji_events;
      default:
        return Icons.notifications;
    }
  }

  Color get color {
    switch (type) {
      case 'therapist_added':
        return Colors.green;
      case 'therapist_removed':
        return Colors.orange;
      case 'plan_created':
        return Colors.blue;
      case 'plan_update':
        return Colors.purple;
      case 'progress_reminder':
        return Colors.amber;
      case 'achievement':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }
}
