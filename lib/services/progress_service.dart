import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:personalized_rehabilitation_plans/models/progress_model.dart';

class ProgressService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<List<ProgressModel>> getUserProgressLogs(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('progressLogs')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ProgressModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting user progress logs: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<ProgressModel>> getPlanProgressLogs(String planId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('progressLogs')
          .where('planId', isEqualTo: planId)
          .orderBy('date')
          .get();

      return snapshot.docs
          .map((doc) => ProgressModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting plan progress logs: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getProgressTrends(String userId,
      {int daysBack = 30}) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: daysBack));

      final snapshot = await _firestore
          .collection('progressLogs')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .orderBy('date')
          .get();

      final logs = snapshot.docs
          .map((doc) => ProgressModel.fromMap(doc.data(), doc.id))
          .toList();

      if (logs.isEmpty) {
        return {
          'painLevels': [],
          'adherenceRates': [],
          'dates': [],
        };
      }

      // Process logs to extract trends
      List<double> painLevels = [];
      List<int> adherenceRates = [];
      List<String> dates = [];

      for (var log in logs) {
        // Calculate average pain for this log
        double totalPain = 0;
        for (var exercise in log.exerciseLogs) {
          totalPain += exercise.painLevel;
        }
        double avgPain = log.exerciseLogs.isNotEmpty
            ? totalPain / log.exerciseLogs.length
            : 0;

        painLevels.add(avgPain);
        adherenceRates.add(log.adherencePercentage);
        dates.add('${log.date.day}/${log.date.month}');
      }

      return {
        'painLevels': painLevels,
        'adherenceRates': adherenceRates,
        'dates': dates,
      };
    } catch (e) {
      print('Error getting progress trends: $e');
      return {
        'painLevels': [],
        'adherenceRates': [],
        'dates': [],
      };
    }
  }

  Future<Map<String, dynamic>> getBodyPartProgress(
      String userId, String bodyPart,
      {int daysBack = 90}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: daysBack));

      final snapshot = await _firestore
          .collection('progressLogs')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .orderBy('date')
          .get();

      final logs = snapshot.docs
          .map((doc) => ProgressModel.fromMap(doc.data(), doc.id))
          .toList();

      if (logs.isEmpty) {
        return {
          'painLevels': [],
          'dates': [],
          'rom': [],
          'strength': [],
        };
      }

      // Process logs to extract body part specific progress
      List<double> painLevels = [];
      List<String> dates = [];
      List<double> rom = []; // Range of motion
      List<double> strength = [];

      for (var log in logs) {
        // Filter exercises for specified body part
        final bodyPartExercises = log.exerciseLogs
            .where((e) =>
                e.exerciseName.toLowerCase().contains(bodyPart.toLowerCase()))
            .toList();

        if (bodyPartExercises.isNotEmpty) {
          // Calculate average pain for this body part
          double totalPain = 0;
          for (var exercise in bodyPartExercises) {
            totalPain += exercise.painLevel;
          }
          double avgPain = totalPain / bodyPartExercises.length;

          painLevels.add(avgPain);
          dates.add('${log.date.day}/${log.date.month}');

          // Extract ROM and strength metrics if available
          if (log.metrics != null) {
            if (log.metrics!.containsKey('${bodyPart}_rom')) {
              rom.add(log.metrics!['${bodyPart}_rom']);
            }
            if (log.metrics!.containsKey('${bodyPart}_strength')) {
              strength.add(log.metrics!['${bodyPart}_strength']);
            }
          }
        }
      }

      return {
        'painLevels': painLevels,
        'dates': dates,
        'rom': rom,
        'strength': strength,
      };
    } catch (e) {
      print('Error getting body part progress: $e');
      return {
        'painLevels': [],
        'dates': [],
        'rom': [],
        'strength': [],
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProgressLog(ProgressModel log) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore
          .collection('progressLogs')
          .doc(log.id)
          .update(log.toMap());
    } catch (e) {
      print('Error updating progress log: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteProgressLog(String logId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('progressLogs').doc(logId).delete();
    } catch (e) {
      print('Error deleting progress log: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
