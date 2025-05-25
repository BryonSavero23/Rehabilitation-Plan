// lib/screens/exercise_screen.dart (Enhanced Version)
import 'package:flutter/material.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/screens/exercise_completion_screen.dart';
import 'package:personalized_rehabilitation_plans/widgets/pain_feedback_widget.dart';
import 'package:personalized_rehabilitation_plans/widgets/custom_button.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'dart:async';

class ExerciseScreen extends StatefulWidget {
  final Exercise exercise;
  final String? planId;

  const ExerciseScreen({
    super.key,
    required this.exercise,
    this.planId,
  });

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with TickerProviderStateMixin {
  // Exercise tracking variables
  int _currentSet = 1;
  int _currentRep = 0;
  int _completedSets = 0;
  int _completedReps = 0;
  bool _isExercising = false;
  bool _isPaused = false;
  bool _isCompleted = false;

  // Pain tracking
  int _prePainLevel = 5;
  bool _hasSetPrePain = false;

  // Timer variables
  Timer? _exerciseTimer;
  Timer? _restTimer;
  int _exerciseTimeElapsed = 0;
  int _restTimeRemaining = 0;
  bool _isResting = false;

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  // Constants
  static const int restDurationSeconds = 30;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));

    // Start pulse animation for breathing cue
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _exerciseTimer?.cancel();
    _restTimer?.cancel();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startExercise() {
    if (!_hasSetPrePain) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please rate your pain level before starting'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isExercising = true;
      _isPaused = false;
      _currentRep = 1;
    });

    _startExerciseTimer();
    _pulseController.repeat(reverse: true);
  }

  void _startExerciseTimer() {
    _exerciseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _exerciseTimeElapsed++;
      });
    });
  }

  void _pauseExercise() {
    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _exerciseTimer?.cancel();
      _restTimer?.cancel();
      _pulseController.stop();
    } else {
      if (_isResting) {
        _startRestTimer();
      } else {
        _startExerciseTimer();
        _pulseController.repeat(reverse: true);
      }
    }
  }

  void _completeRep() {
    if (!_isExercising || _isPaused || _isResting) return;

    setState(() {
      _currentRep++;
      _completedReps++;
    });

    _progressController.forward().then((_) {
      _progressController.reset();
    });

    if (_currentRep > widget.exercise.reps) {
      _completeSet();
    }
  }

  void _completeSet() {
    setState(() {
      _completedSets++;
      _currentSet++;
      _currentRep = 0;
    });

    if (_completedSets >= widget.exercise.sets) {
      _completeExercise();
    } else {
      _startRest();
    }
  }

  void _startRest() {
    setState(() {
      _isResting = true;
      _restTimeRemaining = restDurationSeconds;
    });

    _exerciseTimer?.cancel();
    _pulseController.stop();

    _startRestTimer();
  }

  void _startRestTimer() {
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _restTimeRemaining--;
      });

      if (_restTimeRemaining <= 0) {
        _endRest();
      }
    });
  }

  void _endRest() {
    setState(() {
      _isResting = false;
      _currentRep = 1;
    });

    _restTimer?.cancel();
    _startExerciseTimer();
    _pulseController.repeat(reverse: true);
  }

  void _skipRest() {
    _restTimer?.cancel();
    _endRest();
  }

  void _completeExercise() {
    setState(() {
      _isExercising = false;
      _isCompleted = true;
    });

    _exerciseTimer?.cancel();
    _restTimer?.cancel();
    _pulseController.stop();

    // Navigate to completion screen
    _navigateToCompletionScreen();
  }

  void _navigateToCompletionScreen() async {
    // FIX: Check if widget is still mounted before navigation
    if (!mounted) {
      print('❌ Widget unmounted, cannot navigate to completion screen');
      return;
    }

    try {
      final result = await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ExerciseCompletionScreen(
            exercise: widget.exercise,
            completedSets: _completedSets,
            completedReps: _completedReps,
            actualDurationSeconds: _exerciseTimeElapsed,
            prePainLevel: _prePainLevel,
            planId: widget.planId,
          ),
        ),
      );

      // FIX: Check if widget is still mounted before using context
      if (mounted && result != null && result is Map<String, dynamic>) {
        // Pop back to progress screen with the completion data
        Navigator.of(context).pop(result);
      } else if (mounted) {
        // If no result, still indicate completion
        Navigator.of(context).pop({
          'completed': true,
          'exerciseId': widget.exercise.id,
        });
      }
    } catch (e) {
      print('Error navigating to completion screen: $e');
      // FIX: Check mounted before using context
      if (mounted) {
        // Fallback - return basic completion data
        Navigator.of(context).pop({
          'completed': true,
          'exerciseId': widget.exercise.id,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      appBar: AppBar(
        title: Text(widget.exercise.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.primaryBlue,
        actions: [
          if (_isExercising)
            IconButton(
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: _pauseExercise,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pre-exercise pain assessment
            if (!_hasSetPrePain) ...[
              PainFeedbackWidget(
                initialPainLevel: _prePainLevel,
                title: 'How do you feel right now?',
                subtitle: 'Rate your pain level before starting the exercise',
                onPainLevelChanged: (level) {
                  setState(() {
                    _prePainLevel = level;
                  });
                },
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Set Pre-Exercise Pain Level',
                onPressed: () {
                  setState(() {
                    _hasSetPrePain = true;
                  });
                },
                width: double.infinity,
              ),
              const SizedBox(height: 24),
            ],

            // Exercise information
            if (_hasSetPrePain) ...[
              _buildExerciseInfo(),
              const SizedBox(height: 24),

              // Exercise progress
              _buildExerciseProgress(),
              const SizedBox(height: 24),

              // Exercise controls
              _buildExerciseControls(),
              const SizedBox(height: 24),

              // Rest timer (when resting)
              if (_isResting) ...[
                _buildRestTimer(),
                const SizedBox(height: 24),
              ],

              // Exercise instructions
              _buildExerciseInstructions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.exercise.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.exercise.bodyPart,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Sets',
                  widget.exercise.sets.toString(),
                  Icons.repeat,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Reps',
                  widget.exercise.reps.toString(),
                  Icons.fitness_center,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Duration',
                  '${(widget.exercise.durationSeconds / 60).ceil()}m',
                  Icons.timer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseProgress() {
    final totalReps = widget.exercise.sets * widget.exercise.reps;
    final progressPercentage = totalReps > 0 ? _completedReps / totalReps : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Set $_currentSet of ${widget.exercise.sets}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_formatTime(_exerciseTimeElapsed)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress bar
          LinearProgressIndicator(
            value: progressPercentage,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            minHeight: 8,
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rep $_currentRep of ${widget.exercise.reps}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$_completedReps/$totalReps total reps',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (!_isExercising && !_isCompleted) ...[
            CustomButton(
              text: 'Start Exercise',
              onPressed: _startExercise,
              width: double.infinity,
              backgroundColor: Colors.green,
            ),
          ] else if (_isExercising && !_isResting) ...[
            // Rep counter with breathing animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryBlue,
                        width: 3,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(60),
                        onTap: _completeRep,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentRep.toString(),
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              Text(
                                'TAP',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: _isPaused ? 'Resume' : 'Pause',
                    onPressed: _pauseExercise,
                    backgroundColor: _isPaused ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: 'Complete Set',
                    onPressed: _completeSet,
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ],
          if (_isCompleted) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Exercise Completed!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Great job! You completed $_completedSets sets and $_completedReps reps.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRestTimer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.pause_circle_filled,
            color: Colors.orange,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Rest Time',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatTime(_restTimeRemaining),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Skip Rest',
                  onPressed: _skipRest,
                  backgroundColor: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Exercise Instructions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            widget.exercise.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          // Safety tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.health_and_safety,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Safety Tips',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSafetyTip('Stop if you feel sharp or increasing pain'),
                _buildSafetyTip('Maintain proper form throughout the exercise'),
                _buildSafetyTip('Breathe regularly - don\'t hold your breath'),
                _buildSafetyTip(
                    'Start slowly and gradually increase intensity'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.blue,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
