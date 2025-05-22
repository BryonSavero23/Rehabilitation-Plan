import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/screens/exercise_screen.dart';
import 'package:personalized_rehabilitation_plans/widgets/custom_button.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ExerciseRecommendationScreen extends StatefulWidget {
  final RehabilitationPlan plan;
  final String? planId;

  const ExerciseRecommendationScreen({
    Key? key,
    required this.plan,
    this.planId,
  }) : super(key: key);

  @override
  State<ExerciseRecommendationScreen> createState() =>
      _ExerciseRecommendationScreenState();
}

class _ExerciseRecommendationScreenState
    extends State<ExerciseRecommendationScreen> {
  bool _isLoading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Rehabilitation Plan'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryBlue,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPlanHeader(context),
              const SizedBox(height: 24),
              _buildPlanDescription(context),
              const SizedBox(height: 24),
              _buildExercisesList(context),
              const SizedBox(height: 32),
              _buildNextStepsSection(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.plan.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Personalized for ${widget.plan.goals['bodyPart']}',
            style: TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanDescription(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Plan Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.plan.description,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        if (widget.plan.goals.isNotEmpty) ...[
          const Text(
            'Your Goals',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.plan.goals.entries.map((entry) {
            if (entry.key == 'painReduction' && entry.value is String) {
              return _buildGoalItem(
                'Pain reduction',
                'Priority: ${_formatPriority(entry.value as String)}',
                Icons.healing,
              );
            } else if (entry.key == 'primary' && entry.value is String) {
              return _buildGoalItem(
                'Primary goal',
                entry.value as String,
                Icons.stars,
              );
            } else if (entry.key != 'bodyPart') {
              return _buildGoalItem(
                entry.key,
                entry.value.toString(),
                Icons.check_circle_outline,
              );
            } else {
              return const SizedBox.shrink();
            }
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildGoalItem(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExercisesList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recommended Exercises',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.plan.exercises.length} exercises',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(widget.plan.exercises.length, (index) {
          final exercise = widget.plan.exercises[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              title: Text(
                exercise.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${exercise.sets} sets, ${exercise.reps} reps | ${_formatDifficulty(exercise.difficultyLevel)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.1),
                child: Text(
                  (index + 1).toString(),
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Instructions:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        exercise.description,
                        style: TextStyle(
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildExerciseDetails(exercise),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                              onPressed: () async {
                                try {
                                  setState(() {
                                    exercise.isCompleted =
                                        !exercise.isCompleted;
                                    widget.plan.exercises[index] = exercise;
                                  });
                                  final authService = Provider.of<AuthService>(
                                      context,
                                      listen: false);
                                  await authService.updateRehabilitationPlan(
                                      widget.planId!, widget.plan);
                                } catch (e) {
                                  log("Error: $e");
                                }
                              },
                              icon: Icon(
                                Icons.check_circle,
                                size: 28,
                                color: exercise.isCompleted
                                    ? const Color.fromARGB(255, 5, 239, 13)
                                    : Colors.grey,
                              )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                          child: CustomButton(
                        text: 'Start Exercise',
                        onPressed: () async {
                          bool? isCompleted = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ExerciseScreen(exercise: exercise),
                              ));

                          try {
                            setState(() {
                              if (!exercise.isCompleted) {
                                exercise.isCompleted = isCompleted ?? false;
                                widget.plan.exercises[index] = exercise;
                              }
                            });
                            final authService = Provider.of<AuthService>(
                                context,
                                listen: false);
                            await authService.updateRehabilitationPlan(
                                widget.planId!, widget.plan);
                          } catch (e) {
                            log("Error: $e");
                          }
                        },
                        width: double.infinity,
                      ))
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExerciseDetails(Exercise exercise) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Details:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDetailItem(
                'Sets',
                exercise.sets.toString(),
                Icons.repeat,
              ),
            ),
            Expanded(
              child: _buildDetailItem(
                'Reps',
                exercise.reps.toString(),
                Icons.fitness_center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDetailItem(
                'Duration',
                '${exercise.durationSeconds} sec',
                Icons.timer,
              ),
            ),
            Expanded(
              child: _buildDetailItem(
                'Body Part',
                exercise.bodyPart,
                Icons.accessibility_new,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNextStepsSection(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Next Steps',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildNextStepItem(
              '1. Start slowly',
              'Begin with a comfortable intensity and gradually increase as you progress.',
              Icons.trending_up,
            ),
            _buildNextStepItem(
              '2. Be consistent',
              'Try to perform your exercises regularly as recommended.',
              Icons.calendar_today,
            ),
            _buildNextStepItem(
              '3. Track your progress',
              'Monitor improvements in pain level, strength, and mobility.',
              Icons.insert_chart,
            ),
            _buildNextStepItem(
              '4. Consult with a professional',
              'Consider reviewing this plan with your healthcare provider.',
              Icons.medical_services,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : widget.planId == null
                        ? savePlan
                        : deletePlan,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(widget.planId != null ? 'Delete Plan' : 'Save Plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deletePlan() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.deleteRehabilitationPlan(widget.planId!);

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> savePlan() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.saveRehabilitationPlan(widget.plan);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This rehabilitation plan has been saved!'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildNextStepItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return priority;
    }
  }

  String _formatDifficulty(String difficulty) {
    return difficulty.substring(0, 1).toUpperCase() + difficulty.substring(1);
  }
}
