import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/screens/exercise_screen.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'package:provider/provider.dart';

class RehabilitationProgressScreen extends StatefulWidget {
  final RehabilitationPlan plan;
  final String? planId;
  final String? therapistName;
  final String? therapistTitle;

  const RehabilitationProgressScreen({
    Key? key,
    required this.plan,
    this.planId,
    this.therapistName,
    this.therapistTitle,
  }) : super(key: key);

  @override
  State<RehabilitationProgressScreen> createState() =>
      _RehabilitationProgressScreenState();
}

class _RehabilitationProgressScreenState
    extends State<RehabilitationProgressScreen> {
  int _selectedDay = 0;
  final List<DateTime> _weekDays = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateWeekDays();
  }

  void _generateWeekDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _weekDays.add(today);
    for (int i = 1; i < 6; i++) {
      _weekDays.add(today.add(Duration(days: i)));
    }
  }

  // Calculate completed exercises count
  int get _completedExercisesCount {
    return widget.plan.exercises.where((e) => e.isCompleted).length;
  }

  // Calculate remaining exercises
  int get _remainingExercisesCount {
    return widget.plan.exercises.length - _completedExercisesCount;
  }

  // Calculate missed exercises (placeholder)
  int get _missedExercisesCount {
    // This is simplified - in a real app, you'd track missed sessions
    return 1; // Placeholder
  }

  // Total exercises
  int get _totalExercisesCount {
    return widget.plan.exercises.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildProgressSection(),
                          _buildCalendar(),
                          Expanded(
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: _buildSessionsForToday(),
                            ),
                          ),
                          _buildBottomNavigation(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final therapistName = widget.therapistName ?? "Your Therapist";
    final therapistTitle = widget.therapistTitle ?? "";

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(
                'https://placehold.co/100x100/orange/white?text=T'),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.plan.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              Text(
                '$therapistTitle $therapistName',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'First Phase of Recovery',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProgressItem(
                  _remainingExercisesCount, 'Remaining', Colors.grey.shade300),
              _buildProgressIndicator(),
              _buildProgressItem(
                  _missedExercisesCount, 'Missed', AppTheme.vibrantRed),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Complete all exercises to finish your rehabilitation plan',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(int count, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade100,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.2),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: _completedExercisesCount /
                  (_totalExercisesCount > 0 ? _totalExercisesCount : 1),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFFCCDD00),
              ),
              strokeWidth: 8,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _completedExercisesCount.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'of $_totalExercisesCount Completed',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              _weekDays.length,
              (index) => _buildCalendarDay(index),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Today, ${DateFormat('dd MMM yyyy').format(_weekDays[_selectedDay])} (${_getSessionsForDay(_weekDays[_selectedDay]).length} therapy sessions)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCalendarDay(int index) {
    final day = _weekDays[index];
    final isSelected = index == _selectedDay;
    final isToday = index == 0;
    final accentColor = AppTheme.vibrantRed;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = index;
        });
      },
      child: Container(
        width: 40,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? accentColor : Colors.transparent,
          border: isToday && !isSelected
              ? Border.all(color: accentColor, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E').format(day).toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              day.day.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Get exercises scheduled for a specific day
  List<Exercise> _getSessionsForDay(DateTime day) {
    // This is a simplified implementation
    // In a real app, you would filter exercises based on scheduled dates
    if (day.weekday <= widget.plan.exercises.length) {
      // Return a subset of exercises based on the day of week
      return [
        widget.plan.exercises[(day.weekday - 1) % widget.plan.exercises.length]
      ];
    }
    return [];
  }

  Widget _buildSessionsForToday() {
    final selectedDayExercises = _getSessionsForDay(_weekDays[_selectedDay]);

    if (selectedDayExercises.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'No exercises scheduled for today',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ),
      );
    }

    return Column(
      children: selectedDayExercises.asMap().entries.map((entry) {
        final index = entry.key;
        final exercise = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildExerciseCard(
            exercise: exercise,
            isActive: !exercise.isCompleted, // Active if not completed
            startTime: index == 0 ? '9 am' : '2 pm', // Example times
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExerciseCard({
    required Exercise exercise,
    required bool isActive,
    required String startTime,
  }) {
    final bool exerciseCompleted = exercise.isCompleted;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child:
                      exercise.imageUrl != null && exercise.imageUrl!.isNotEmpty
                          ? Image.network(
                              exercise.imageUrl!,
                              width: 80,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 60,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.fitness_center,
                                      color: Colors.white),
                                );
                              },
                            )
                          : Container(
                              width: 80,
                              height: 60,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.fitness_center,
                                  color: Colors.white),
                            ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.fitness_center,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${exercise.sets} Sets, ${exercise.reps} Reps',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                          const Spacer(),
                          if (exerciseCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 12,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Completed',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exercise.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${exercise.durationSeconds ~/ 60}-${(exercise.durationSeconds ~/ 60) + 5} min',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '|',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Start session from $startTime',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: exerciseCompleted
                  ? () {
                      // Show completion details or allow to redo
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Exercise already completed!')),
                      );
                    }
                  : () => _navigateToExerciseDetail(exercise),
              style: ElevatedButton.styleFrom(
                backgroundColor: exerciseCompleted
                    ? Colors.grey.shade400 // Completed
                    : const Color(0xFFCCDD00), // Not completed - active
                foregroundColor:
                    exerciseCompleted ? Colors.white : Colors.black,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),
              child: Text(
                exerciseCompleted ? 'View Details' : 'Start Now',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToExerciseDetail(Exercise exercise) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Navigate to exercise screen
      bool? isCompleted = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExerciseScreen(exercise: exercise),
        ),
      );

      if (isCompleted == true && widget.planId != null) {
        // Update the exercise completion status
        final index =
            widget.plan.exercises.indexWhere((e) => e.id == exercise.id);
        if (index != -1) {
          setState(() {
            widget.plan.exercises[index].isCompleted = true;
          });

          // Save the updated plan
          final authService = Provider.of<AuthService>(context, listen: false);
          await authService.updateRehabilitationPlan(
              widget.planId!, widget.plan);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.2),
            blurRadius: 6,
            spreadRadius: 2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomNavItem(Icons.show_chart, 'Activity', true),
          _buildBottomNavItem(Icons.bar_chart, 'Progress Chart', false),
          _buildBottomNavItem(Icons.notifications_none, 'Notification', false,
              hasBadge: true),
          _buildBottomNavItem(Icons.person_outline, 'Profile', false),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, bool isSelected,
      {bool hasBadge = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            if (hasBadge)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '2',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
        ),
      ],
    );
  }
}
