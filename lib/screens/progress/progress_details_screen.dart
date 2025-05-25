import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personalized_rehabilitation_plans/models/progress_model.dart';
import 'package:personalized_rehabilitation_plans/widgets/custom_button.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';

class ProgressDetailsScreen extends StatefulWidget {
  final String progressId;
  final String patientId;
  final String patientName;

  const ProgressDetailsScreen({
    super.key,
    required this.progressId,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<ProgressDetailsScreen> createState() => _ProgressDetailsScreenState();
}

class _ProgressDetailsScreenState extends State<ProgressDetailsScreen> {
  bool _isLoading = true;
  ProgressModel? _progressData;
  final _noteController = TextEditingController();
  bool _isSavingNote = false;

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadProgressData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('progressLogs')
          .doc(widget.progressId)
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          _progressData = ProgressModel.fromMap(doc.data()!, doc.id);
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress log not found')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading progress data: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addTherapistNote() async {
    if (_noteController.text.trim().isEmpty) return;

    setState(() {
      _isSavingNote = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('progressLogs')
          .doc(widget.progressId)
          .update({
        'therapistNotes': FieldValue.arrayUnion([
          {
            'text': _noteController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
          }
        ])
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note added successfully')),
      );
      _noteController.clear();
      _loadProgressData(); // Reload data to show the new note
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding note: $e')),
      );
    } finally {
      setState(() {
        _isSavingNote = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.patientName}\'s Progress'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildProgressDetails(),
      ),
    );
  }

  Widget _buildProgressDetails() {
    if (_progressData == null) {
      return const Center(child: Text('No progress data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Header
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Session Date: ${DateFormat('MMM dd, yyyy').format(_progressData!.date)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildAdherenceBadge(_progressData!.adherencePercentage),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoItem(
                        'Overall Rating',
                        '${_progressData!.overallRating}/5',
                        Icons.star,
                        Colors.amber,
                      ),
                      const SizedBox(width: 16),
                      _buildInfoItem(
                        'Exercises Completed',
                        _progressData!.exerciseLogs.length.toString(),
                        Icons.fitness_center,
                        Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                  if (_progressData!.feedback != null &&
                      _progressData!.feedback!.isNotEmpty) ...[
                    const Divider(height: 32),
                    const Text(
                      'Patient Feedback:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _progressData!.feedback!,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Exercise Logs
          const Text(
            'Exercise Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _progressData!.exerciseLogs.length,
            itemBuilder: (context, index) {
              final exercise = _progressData!.exerciseLogs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                (index + 1).toString(),
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              exercise.exerciseName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildPainBadge(exercise.painLevel),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildExerciseDetail(
                            'Sets Completed',
                            exercise.setsCompleted.toString(),
                            Icons.repeat,
                          ),
                          const SizedBox(width: 16),
                          _buildExerciseDetail(
                            'Reps Completed',
                            exercise.repsCompleted.toString(),
                            Icons.fitness_center,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildExerciseDetail(
                        'Duration',
                        '${exercise.durationSeconds} seconds',
                        Icons.timer,
                      ),
                      if (exercise.notes != null &&
                          exercise.notes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Patient Notes:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exercise.notes!,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Therapist Notes Section
          const Text(
            'Therapist Notes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Add Note',
                      hintText: 'Enter observations or feedback for patient',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Save Note',
                    onPressed: _addTherapistNote,
                    isLoading: _isSavingNote,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Previous Notes:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Display existing therapist notes
                  // This is a placeholder for where you would display therapist notes
                  // retrieved from Firestore
                  Center(
                    child: Text(
                      'No notes yet',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseDetail(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAdherenceBadge(int adherence) {
    Color color;
    if (adherence >= 80) {
      color = Colors.green;
    } else if (adherence >= 50) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        'Adherence: $adherence%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPainBadge(int painLevel) {
    Color color;
    if (painLevel <= 3) {
      color = Colors.green;
    } else if (painLevel <= 6) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.healing,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            'Pain: $painLevel/10',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
