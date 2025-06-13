// lib/widgets/weekly_feedback_dialog.dart
import 'package:flutter/material.dart';
import 'package:personalized_rehabilitation_plans/services/weekly_progression_service.dart';

class WeeklyFeedbackDialog extends StatefulWidget {
  final String userId;
  final String planId;
  final int weekNumber;
  final Map<String, dynamic> goals;
  final Function(Map<String, dynamic>) onComplete;

  const WeeklyFeedbackDialog({
    super.key,
    required this.userId,
    required this.planId,
    required this.weekNumber,
    required this.goals,
    required this.onComplete,
  });

  @override
  State<WeeklyFeedbackDialog> createState() => _WeeklyFeedbackDialogState();
}

class _WeeklyFeedbackDialogState extends State<WeeklyFeedbackDialog> {
  final WeeklyProgressionService _progressionService =
      WeeklyProgressionService();

  bool _isLoading = false;
  bool _showGoalProgress = false;
  Map<String, dynamic>? _goalProgress;
  Map<String, dynamic>? _achievementSummary;

  @override
  void initState() {
    super.initState();
    _checkGoalProgress();
  }

  Future<void> _checkGoalProgress() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _progressionService.checkWeeklyGoalsAndGraduate(
        userId: widget.userId,
        planId: widget.planId,
        weekNumber: widget.weekNumber,
      );

      if (result['success'] == true) {
        setState(() {
          _goalProgress = result['goalProgress'] as Map<String, dynamic>?;
          _achievementSummary =
              result['achievementSummary'] as Map<String, dynamic>?;
          _showGoalProgress = true;
        });

        // Call the completion callback with results
        widget.onComplete(result);
      }
    } catch (e) {
      print('❌ Error checking goal progress: $e');
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking goal progress: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: _isLoading
            ? _buildLoadingContent()
            : _showGoalProgress
                ? _buildGoalProgressContent()
                : _buildErrorContent(),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Analyzing Your Progress...',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'re evaluating your rehabilitation goals and determining your next steps.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgressContent() {
    final isGraduated = _achievementSummary?['isGraduated'] as bool? ?? false;
    final achievedGoals =
        List<String>.from(_achievementSummary?['achievedGoals'] ?? []);
    final unachievedGoals =
        List<String>.from(_achievementSummary?['unachievedGoals'] ?? []);
    final achievementPercentage =
        _achievementSummary?['achievementPercentage'] as double? ?? 0.0;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isGraduated ? Colors.green.shade50 : Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isGraduated ? Icons.celebration : Icons.assessment,
                  size: 48,
                  color: isGraduated ? Colors.green : Colors.blue,
                ),
                const SizedBox(height: 12),
                Text(
                  isGraduated
                      ? 'Congratulations! 🎉'
                      : 'Week ${widget.weekNumber} Complete!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isGraduated
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  isGraduated
                      ? 'You have successfully completed your rehabilitation plan!'
                      : 'Let\'s review your progress towards your rehabilitation goals.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),

          // Goal Progress Section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall Progress
                Row(
                  children: [
                    Icon(
                      Icons.track_changes,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Overall Progress',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Progress Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Goal Achievement',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            '${achievementPercentage.toStringAsFixed(1)}%',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: achievementPercentage >= 80
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: achievementPercentage / 100,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          achievementPercentage >= 80
                              ? Colors.green
                              : Colors.orange,
                        ),
                        minHeight: 8,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Individual Goals
                if (_goalProgress != null) ...[
                  Text(
                    'Individual Goals Progress',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...(_goalProgress!.entries.map((entry) {
                    return _buildGoalProgressItem(entry.key, entry.value);
                  }).toList()),
                ],

                const SizedBox(height: 24),

                // Achievement Summary
                if (achievedGoals.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Goals Achieved',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...achievedGoals.map((goal) => Padding(
                              padding:
                                  const EdgeInsets.only(left: 28, bottom: 4),
                              child: Text(
                                '• ${_formatGoalName(goal)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.green.shade700,
                                    ),
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (unachievedGoals.isNotEmpty && !isGraduated) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: Colors.orange.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Goals In Progress',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...unachievedGoals.map((goal) => Padding(
                              padding:
                                  const EdgeInsets.only(left: 28, bottom: 4),
                              child: Text(
                                '• ${_formatGoalName(goal)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.orange.shade700,
                                    ),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                if (isGraduated) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Navigate to create new plan
                        _navigateToCreateNewPlan();
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Create New Plan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Navigate to archived plans
                        _navigateToArchivedPlans();
                      },
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('View Archived Plans'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: BorderSide(color: Colors.green.shade300),
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Continue to next week
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continue to Next Week'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgressItem(
      String goalType, Map<String, dynamic> goalData) {
    final current = goalData['current'] as double? ?? 0.0;
    final target = goalData['target'] as double? ?? 100.0;
    final progress = goalData['progress'] as double? ?? 0.0;
    final achieved = goalData['achieved'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: achieved ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: achieved ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getGoalIcon(goalType),
                color: achieved ? Colors.green.shade600 : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatGoalName(goalType),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: achieved
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                ),
              ),
              if (achieved)
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current: ${current.toStringAsFixed(1)}${_getGoalUnit(goalType)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              Text(
                'Target: ${target.toStringAsFixed(1)}${_getGoalUnit(goalType)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              achieved ? Colors.green : Colors.orange,
            ),
            minHeight: 6,
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% Complete',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      achieved ? Colors.green.shade600 : Colors.orange.shade600,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to Load Progress',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'We encountered an error while analyzing your progress. Please try again.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _checkGoalProgress,
                  child: const Text('Retry'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatGoalName(String goalType) {
    switch (goalType) {
      case 'painReduction':
        return 'Pain Reduction';
      case 'rangeOfMotion':
        return 'Range of Motion';
      case 'strength':
        return 'Strength Improvement';
      case 'functionalCapacity':
        return 'Functional Capacity';
      default:
        return goalType
            .replaceAllMapped(
              RegExp(r'([A-Z])'),
              (match) => ' ${match.group(1)}',
            )
            .trim();
    }
  }

  IconData _getGoalIcon(String goalType) {
    switch (goalType) {
      case 'painReduction':
        return Icons.healing;
      case 'rangeOfMotion':
        return Icons.rotate_right;
      case 'strength':
        return Icons.fitness_center;
      case 'functionalCapacity':
        return Icons.accessibility_new;
      default:
        return Icons.track_changes;
    }
  }

  String _getGoalUnit(String goalType) {
    switch (goalType) {
      case 'painReduction':
        return '%';
      case 'rangeOfMotion':
        return '°';
      case 'strength':
        return '%';
      case 'functionalCapacity':
        return '%';
      default:
        return '';
    }
  }

  void _navigateToCreateNewPlan() {
    // Navigate to create new plan screen
    // This would be implemented based on your app's navigation structure
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/create_plan',
      (route) => route.isFirst,
    );
  }

  void _navigateToArchivedPlans() {
    // Navigate to archived plans screen
    // This would be implemented based on your app's navigation structure
    Navigator.of(context).pushNamed('/archived_plans');
  }
}
