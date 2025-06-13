// lib/widgets/weekly_progress_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/services/weekly_progression_service.dart';
import 'package:personalized_rehabilitation_plans/widgets/weekly_feedback_dialog.dart';

class WeeklyProgressDashboard extends StatefulWidget {
  final String planId;
  final Function(Map<String, dynamic>)? onWeekCompleted;

  const WeeklyProgressDashboard({
    super.key,
    required this.planId,
    this.onWeekCompleted,
  });

  @override
  State<WeeklyProgressDashboard> createState() => _WeeklyProgressDashboardState();
}

class _WeeklyProgressDashboardState extends State<WeeklyProgressDashboard>
    with TickerProviderStateMixin {
  final WeeklyProgressionService _progressionService = WeeklyProgressionService();
  
  Map<String, dynamic>? _weeklyProgress;
  int _currentWeek = 1;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Animation controllers
  late AnimationController _progressAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadWeeklyProgress();
  }

  void _initializeAnimations() {
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    // Start pulse animation for active states
    _pulseAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklyProgress() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      if (userId != null) {
        // Get current week number
        final currentWeek = await _progressionService.getCurrentWeekNumber(
          userId, widget.planId
        );
        
        // Get weekly progress summary
        final progress = await _progressionService.getWeeklyProgressSummary(
          userId, widget.planId, currentWeek
        );

        setState(() {
          _currentWeek = currentWeek;
          _weeklyProgress = progress;
        });

        // Start progress animation
        _progressAnimationController.forward();
      }
    } catch (e) {
      print('❌ Error loading weekly progress: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (_weeklyProgress == null) {
      return _buildEmptyWidget();
    }

    return _buildProgressWidget();
  }

  Widget _buildLoadingWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Weekly Progress...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyzing your exercise patterns',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.error_outline,
              color: Colors.red.shade600,
              size: 32,
            ),
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
            'We encountered an issue loading your weekly progress. Please check your connection and try again.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadWeeklyProgress,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to support or contact
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Contact support for assistance'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.support_agent),
                  label: const Text('Support'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.calendar_view_week_outlined,
              color: Colors.grey.shade600,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Progress Data',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start completing exercises to see your weekly progress here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed('/exercises');
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Exercises'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressWidget() {
    final completedExercises = List<String>.from(_weeklyProgress!['completedExercises'] ?? []);
    final totalExercises = _weeklyProgress!['totalExercises'] as int? ?? 0;
    final completionPercentage = _weeklyProgress!['completionPercentage'] as double? ?? 0.0;
    final status = _weeklyProgress!['status'] as String? ?? 'active';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(status),
          const SizedBox(height: 28),
          
          // Progress Visualization
          _buildProgressVisualization(completedExercises, totalExercises, completionPercentage, status),
          
          const SizedBox(height: 28),
          
          // Progress Bar
          _buildProgressBar(completedExercises, totalExercises, completionPercentage),
          
          const SizedBox(height: 28),
          
          // Action Buttons
          if (status == 'completed') ...[
            _buildCompletedWeekActions(),
          ] else ...[
            _buildActiveWeekActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(String status) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.calendar_view_week,
            color: Theme.of(context).primaryColor,
            size: 28,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Week $_currentWeek Progress',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusText(status),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (status == 'completed')
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 20,
            ),
          ),
      ],
    );
  }

  Widget _buildProgressVisualization(List<String> completedExercises, int totalExercises, double completionPercentage, String status) {
    return Row(
      children: [
        // Circular Progress
        Expanded(
          flex: 2,
          child: Column(
            children: [
              ScaleTransition(
                scale: status == 'active' ? _pulseAnimation : 
                       const AlwaysStoppedAnimation(1.0),
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    children: [
                      // Background circle
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.grey.shade200,
                          ),
                        ),
                      ),
                      // Progress circle
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return SizedBox(
                            width: 140,
                            height: 140,
                            child: CircularProgressIndicator(
                              value: (completionPercentage / 100) * _progressAnimation.value,
                              strokeWidth: 12,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getProgressColor(completionPercentage),
                              ),
                            ),
                          );
                        },
                      ),
                      // Center content
                      Positioned.fill(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _progressAnimation,
                              builder: (context, child) {
                                final animatedPercentage = completionPercentage * _progressAnimation.value;
                                return Text(
                                  '${animatedPercentage.toStringAsFixed(0)}%',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getProgressColor(completionPercentage),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Complete',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 32),
        
        // Progress Details
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressItem(
                'Exercises Completed',
                '${completedExercises.length} of $totalExercises',
                Icons.fitness_center,
                Colors.blue,
              ),
              const SizedBox(height: 20),
              _buildProgressItem(
                'Current Week',
                'Week $_currentWeek',
                Icons.calendar_today,
                Colors.green,
              ),
              const SizedBox(height: 20),
              _buildProgressItem(
                'Status',
                _getStatusText(status),
                _getStatusIcon(status),
                _getStatusColor(status),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(List<String> completedExercises, int totalExercises, double completionPercentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weekly Progress',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            Text(
              '${completedExercises.length}/$totalExercises exercises',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (totalExercises > 0 ? completedExercises.length / totalExercises : 0) * _progressAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getProgressColor(completionPercentage),
                        _getProgressColor(completionPercentage).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: _getProgressColor(completionPercentage).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActiveWeekActions() {
    return Column(
      children: [
        // Continue Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // Navigate to exercise list for current week
              Navigator.of(context).pushNamed(
                '/exercises',
                arguments: {
                  'planId': widget.planId,
                  'weekNumber': _currentWeek,
                },
              );
            },
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('Continue Exercises'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Secondary Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loadWeeklyProgress,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate to weekly schedule view
                  Navigator.of(context).pushNamed(
                    '/progress',
                    arguments: {
                      'planId': widget.planId,
                      'weekNumber': _currentWeek,
                    },
                  );
                },
                icon: const Icon(Icons.insights, size: 18),
                label: const Text('Progress'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompletedWeekActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.green.shade25,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.celebration,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Week Completed! 🎉',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Great job! Your exercises have been adjusted for next week based on your performance.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Check weekly goals and show feedback
                    _checkWeeklyGoals();
                  },
                  icon: const Icon(Icons.assessment, size: 18),
                  label: const Text('Review Goals'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to next week preview
                    Navigator.of(context).pushNamed(
                      '/progress',
                      arguments: {
                        'planId': widget.planId,
                        'weekNumber': _currentWeek + 1,
                      },
                    );
                  },
                  icon: const Icon(Icons.navigate_next, size: 18),
                  label: const Text('Next Week'),
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
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _checkWeeklyGoals() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final result = await _progressionService.checkWeeklyGoalsAndGraduate(
        userId: userId,
        planId: widget.planId,
        weekNumber: _currentWeek,
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (result['success'] == true) {
        // Call callback if provided
        if (widget.onWeekCompleted != null) {
          widget.onWeekCompleted!(result);
        }

        // Show weekly feedback dialog
        final goals = await _progressionService.getRehabilitationGoals(widget.planId);
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => WeeklyFeedbackDialog(
              userId: userId,
              planId: widget.planId,
              weekNumber: _currentWeek,
              goals: goals,
              onComplete: (dialogResult) {
                final isGraduated = dialogResult['isGraduated'] as bool? ?? false;
                
                if (isGraduated) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/patient_home',
                    (route) => false,
                  );
                } else {
                  // Refresh the dashboard to show next week
                  _loadWeeklyProgress();
                }
              },
            ),
          );
        }
      } else {
        // Show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error checking goals: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      print('❌ Error checking weekly goals: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking goals: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'In Progress';
      case 'completed':
        return 'Week Completed';
      case 'not_started':
        return 'Not Started';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'not_started':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.play_circle;
      case 'completed':
        return Icons.check_circle;
      case 'not_started':
        return Icons.schedule;
      default:
        return Icons.help;
    }
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 100) {
      return Colors.green;
    } else if (percentage >= 80) {
      return Colors.lightGreen;
    } else if (percentage >= 60) {
      return Colors.blue;
    } else if (percentage >= 40) {
      return Colors.orange;
    } else if (percentage >= 20) {
      return Colors.deepOrange;
    } else {
      return Colors.red;
    }
  }

  // Helper method to get current active plan ID
  Future<String?> _getCurrentActivePlanId(String? userId) async {
    if (userId == null) return null;
    
    try {
      // This should be implemented based on your existing plan management logic
      // For now, returning the planId passed to the widget
      return widget.planId;
    } catch (e) {
      print('Error getting active plan ID: $e');
      return null;
    }
  }

  // Helper method to format duration
  String _formatDuration(DateTime? startDate, DateTime? endDate) {
    if (startDate == null) return 'Duration unknown';
    
    final now = DateTime.now();
    final end = endDate ?? now;
    final duration = end.difference(startDate);
    
    if (duration.inDays > 0) {
      return '${duration.inDays} days';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hours';
    } else {
      return '${duration.inMinutes} minutes';
    }
  }

  // Helper method to get motivational message based on progress
  String _getMotivationalMessage(double completionPercentage, String status) {
    if (status == 'completed') {
      return 'Outstanding work this week! 🌟';
    }
    
    if (completionPercentage >= 80) {
      return 'You\'re almost there! Keep going! 💪';
    } else if (completionPercentage >= 60) {
      return 'Great progress! You\'re doing well! 👍';
    } else if (completionPercentage >= 40) {
      return 'Keep it up! Every exercise counts! 🎯';
    } else if (completionPercentage >= 20) {
      return 'You\'ve made a good start! 🚀';
    } else {
      return 'Ready to begin your week? Let\'s go! ✨';
    }
  }

  // Helper method to get week completion summary
  Map<String, dynamic> _getWeekSummary() {
    if (_weeklyProgress == null) return {};
    
    final completedExercises = List<String>.from(_weeklyProgress!['completedExercises'] ?? []);
    final totalExercises = _weeklyProgress!['totalExercises'] as int? ?? 0;
    final completionPercentage = _weeklyProgress!['completionPercentage'] as double? ?? 0.0;
    final status = _weeklyProgress!['status'] as String? ?? 'active';
    
    return {
      'completedCount': completedExercises.length,
      'totalCount': totalExercises,
      'percentage': completionPercentage,
      'status': status,
      'remainingCount': totalExercises - completedExercises.length,
      'motivationalMessage': _getMotivationalMessage(completionPercentage, status),
    };
  }

  // Method to handle refresh with user feedback
  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact(); // Provide haptic feedback
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing your progress...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    await _loadWeeklyProgress();
  }

  // Method to show detailed progress info
  void _showProgressDetails() {
    final summary = _getWeekSummary();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              'Week $_currentWeek Details',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Progress stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Completed',
                    summary['completedCount'].toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Remaining',
                    summary['remainingCount'].toString(),
                    Colors.orange,
                    Icons.pending,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Progress',
                    '${summary['percentage'].toStringAsFixed(0)}%',
                    Colors.blue,
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Week',
                    _currentWeek.toString(),
                    Colors.purple,
                    Icons.calendar_today,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Motivational message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.1),
                    Theme.of(context).primaryColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                summary['motivationalMessage'],
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
    switch (status) {