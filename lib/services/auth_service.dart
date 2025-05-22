import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user
  User? get currentUser => _auth.currentUser;
  bool _isLoading = true;

  UserModel? _currentUserModel;
  UserModel? get currentUserModel => _currentUserModel;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isLoading => _isLoading;

  // Is user logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // Initialize user data after login or app start
  Future<void> initializeUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      final User? user = _auth.currentUser;

      if (user != null) {
        await fetchUserData(user.uid);
      }
    } catch (e) {
      print('Error initializing user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check if the current user is a therapist
  Future<bool> isUserTherapist() async {
    try {
      if (_currentUserModel != null) {
        return _currentUserModel!.isTherapist;
      }

      if (currentUser == null) {
        return false;
      }

      final doc =
          await _firestore.collection('users').doc(currentUser!.uid).get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!['isTherapist'] ?? false;
      }

      return false;
    } catch (e) {
      print('Error checking therapist status: $e');
      return false;
    }
  }

  // Update the fetchUserData method to include isTherapist flag:
  Future<void> fetchUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        _currentUserModel = UserModel.fromMap(doc.data()!);

        // Check if user has therapist profile
        if (_currentUserModel!.isTherapist) {
          final therapistDoc =
              await _firestore.collection('therapists').doc(userId).get();
          if (therapistDoc.exists) {
            // User has therapist profile, no changes needed
          } else {
            // User is marked as therapist but has no therapist profile
            // This can happen if registration was interrupted
            // You might want to handle this case (e.g., redirect to registration)
          }
        }
      } else {
        print('User document does not exist');
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }

    notifyListeners();
  }

  // Create user with email and password
  Future<User?> createUserWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // Save user data to Firestore
  Future<void> saveUserData({
    required String userId,
    required String email,
    required String name,
    String? profileImageUrl,
    bool isTherapist = false,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'id': userId,
        'email': email,
        'name': name,
        'profileImageUrl': profileImageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'isTherapist': isTherapist,
      });
    } catch (e) {
      throw Exception('Failed to save user data: $e');
    }
  }

  Future<void> updateUserData(UserModel userModel) async {
    try {
      await _firestore
          .collection('users')
          .doc(userModel.id)
          .update(userModel.toMap());
    } catch (e) {
      throw Exception('Failed to save user data: $e');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  Future<void> saveRehabilitationPlan(
      RehabilitationPlan rehabilitationPlan) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('rehabilitation_plans')
          .doc()
          .set(rehabilitationPlan.toJson());
    } catch (e) {
      throw Exception('Failed to store rehabilitation plan');
    }
  }

  Future<void> updateRehabilitationPlan(
      String id, RehabilitationPlan rehabilitationPlan) async {
    try {
      if (currentUser == null) {
        return;
      }
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('rehabilitation_plans')
          .doc(id)
          .set(rehabilitationPlan.toJson());
    } catch (e) {
      throw Exception('Failed to store rehabilitation plan');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getRehabilitationPlans() {
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('rehabilitation_plans')
        .snapshots();
  }

  Future<void> deleteRehabilitationPlan(String planId) async {
    try {
      return _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('rehabilitation_plans')
          .doc(planId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete rehabilitation plan');
    }
  }

  // Handle firebase auth exceptions
  String _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }

  Future<void> saveTherapistProfile(
      String userId, Map<String, Object> therapistProfileData) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update(therapistProfileData);
    } catch (e) {
      throw Exception('Failed to save user data: $e');
    }
  }
}
