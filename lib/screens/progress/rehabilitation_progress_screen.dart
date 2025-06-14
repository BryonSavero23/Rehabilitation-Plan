// lib/screens/progress/rehabilitation_progress_screen.dart (COMPLETE VERSION)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/screens/exercise_screen.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/services/exercise_adjustment_service.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'package:personalized_rehabilitation_plans/widgets/progress_chart_widget.dart';
import 'package:personalized_rehabilitation_plans/services/progress_service.dart';
import 'package:provider/provider.dart';

class RehabilitationProgressScreen extends StatefulWidget {
  final RehabilitationPlan? plan;
  final String? planId;
  final String? therapistName;
  final String? therapistTitle;

  const RehabilitationProgressScreen({
    super.key,
    this.plan,
    this.planId,
    this.therapistName,
    this.therapistTitle,
  });

  @override
  State<RehabilitationProgressScreen> createState() =>
      _RehabilitationProgressScreenState();
}

class _RehabilitationProgressScreenState
    extends State<RehabilitationProgressScreen> {
  int _selectedDay = 0;
  int _selectedTopTabIndex = 0; // 0: This Week, 1: Next Week, 2: Progress Chart
  final List<DateTime> _weekDays = [];
  final List<DateTime> _nextWeekDays = [];
  bool _isLoading = false;

  // Plan selection state
  String? _selectedPlanId;
  RehabilitationPlan? _selectedPlan;
  String? _therapistName;
  String? _therapistTitle;

  // Services for scheduling
  final ExerciseAdjustmentService _adjustmentService =
      ExerciseAdjustmentService();
  Map<String, dynamic>? _weeklyScheduleSummary;
  List<Map<String, dynamic>> _nextWeekScheduledExercises = [];

  @override
  void initState() {
    super.initState();
    _generateWeekDays();
    _generateNextWeekDays();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      // Load plan data
      if (widget.plan != null && widget.planId != null) {
        setState(() {
          _selectedPlan = widget.plan;
          _selectedPlanId = widget.planId;
          _therapistName = widget.therapistName;
          _therapistTitle = widget.therapistTitle;
        });
        await _loadTherapistInfo();
      } else {
        // Load first available plan
        final plansSnapshot = await FirebaseFirestore.instance
            .collection('rehabilitation_plans')
            .where('userId', isEqualTo: authService.currentUser?.uid)
            .orderBy('lastUpdated', descending: true)
            .limit(1)
            .get();

        if (plansSnapshot.docs.isNotEmpty) {
          final firstPlan = plansSnapshot.docs.first;
          final planData = firstPlan.data();
          setState(() {
            _selectedPlanId = firstPlan.id;
            _selectedPlan = RehabilitationPlan.fromJson(planData);
          });
          await _loadTherapistInfo();
        }
      }

      // Load weekly schedule data
      await _loadWeeklyScheduleData();
    } catch (e) {
      print('Error loading initial data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Load weekly schedule data
  Future<void> _loadWeeklyScheduleData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      if (userId != null) {
        // Load weekly summary
        final summary =
            await _adjustmentService.getWeeklyScheduleSummary(userId);

        // Load next week's scheduled exercises
        final nextWeekExercises =
            await _adjustmentService.getNextWeekScheduledExercises(userId);

        setState(() {
          _weeklyScheduleSummary = summary;
          _nextWeekScheduledExercises = nextWeekExercises;
        });

        print('📅 Loaded ${nextWeekExercises.length} exercises for next week');
      }
    } catch (e) {
      print('❌ Error loading weekly schedule data: $e');
    }
  }

  void _generateWeekDays() {
    _weekDays.clear();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Generate current week (Monday to Sunday)
    final monday = today.subtract(Duration(days: today.weekday - 1));
    for (int i = 0; i < 7; i++) {
      _weekDays.add(monday.add(Duration(days: i)));
    }
  }

  // Generate next week days
  void _generateNextWeekDays() {
    _nextWeekDays.clear();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Generate next week (Monday to Sunday)
    final nextMonday = today
        .subtract(Duration(days: today.weekday - 1))
        .add(const Duration(days: 7));
    for (int i = 0; i < 7; i++) {
      _nextWeekDays.add(nextMonday.add(Duration(days: i)));
    }
  }

  Future<void> _loadTherapistInfo() async {
    if (_selectedPlan == null || _selectedPlanId == null) return;

    try {
      final planSnapshot = await FirebaseFirestore.instance
          .collection('rehabilitation_plans')
          .doc(_selectedPlanId)
          .get();

      if (planSnapshot.exists) {
        final planData = planSnapshot.data();
        final therapistId = planData?['therapistId'];

        if (therapistId != null && therapistId.isNotEmpty) {
          final therapistDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(therapistId)
              .get();

          if (therapistDoc.exists) {
            final therapistData = therapistDoc.data()!;
            final therapistProfileDoc = await FirebaseFirestore.instance
                .collection('therapists')
                .doc(therapistId)
                .get();

            String therapistName = therapistData['name'] ?? 'Unknown Therapist';
            String therapistTitle = 'Dr.';

            if (therapistProfileDoc.exists) {
              final profileData = therapistProfileDoc.data();
              therapistTitle = profileData?['title'] ??
                  profileData?['specialization'] ??
                  'Dr.';
            }

            setState(() {
              _therapistName = therapistName;
              _therapistTitle = therapistTitle;
            });
          } else {
            setState(() {
              _therapistName = 'Therapist Not Found';
              _therapistTitle = 'Dr.';
            });
          }
        } else {
          setState(() {
            _therapistName = 'No Therapist Assigned';
            _therapistTitle = '';
          });
        }
      }
    } catch (e) {
      print('Error loading therapist info: $e');
      setState(() {
        _therapistName = widget.therapistName ?? 'Your Therapist';
        _therapistTitle = widget.therapistTitle ?? 'Dr.';
      });
    }
  }

  void _onPlanChanged(String? planId, RehabilitationPlan? plan) {
    setState(() {
      _selectedPlanId = planId;
      _selectedPlan = plan;
    });
    _loadTherapistInfo();
    _loadWeeklyScheduleData();
  }

  // Calculated getters for current plan
  int get _completedExercisesCount {
    if (_selectedPlan == null) return 0;
    return _selectedPlan!.exercises.where((e) => e.isCompleted).length;
  }

  int get _remainingExercisesCount {
    if (_selectedPlan == null) return 0;
    final total = _selectedPlan!.exercises.length;
    final completed = _completedExercisesCount;
    return total - completed;
  }

  int get _totalExercisesCount {
    if (_selectedPlan == null) return 0;
    return _selectedPlan!.exercises.length;
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
                  if (_selectedPlan != null) _buildTopTabBar(),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: _selectedPlan == null
                          ? _buildPlanSelection()
                          : _buildBodyContent(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final authService = Provider.of<AuthService>(context);
    final therapistName = _therapistName ?? "Your Therapist";
    final therapistTitle = _therapistTitle ?? "";

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                    'https://placehold.co/100x100/orange/white?text=T'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress Tracking',
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
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
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
          const SizedBox(height: 16),

          // Plan selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: authService.getRehabilitationPlans(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text(
                          'No plans available',
                          style: TextStyle(color: Colors.grey),
                        );
                      }

                      final plans = snapshot.data!.docs;

                      return DropdownButton<String>(
                        value: _selectedPlanId,
                        hint: const Text('Select a plan'),
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: plans.map((doc) {
                          final planData = doc.data() as Map<String, dynamic>;
                          final title = planData['title'] ?? 'Unnamed Plan';
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (String? planId) {
                          if (planId != null) {
                            final selectedDoc =
                                plans.firstWhere((doc) => doc.id == planId);
                            final planData =
                                selectedDoc.data() as Map<String, dynamic>;
                            final plan = RehabilitationPlan.fromJson(planData);
                            _onPlanChanged(planId, plan);
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Select Plan',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced top tab bar with 3 tabs
  Widget _buildTopTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTopTabIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTopTabIndex == 0
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  'This Week',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTopTabIndex == 0
                        ? Theme.of(context).primaryColor
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTopTabIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTopTabIndex == 1
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'Next Week',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _selectedTopTabIndex == 1
                            ? Theme.of(context).primaryColor
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    // Show badge if there are scheduled exercises
                    if (_nextWeekScheduledExercises.isNotEmpty)
                      Positioned(
                        top: 2,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTopTabIndex = 2),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTopTabIndex == 2
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  'Charts',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTopTabIndex == 2
                        ? Theme.of(context).primaryColor
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.healing_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Rehabilitation Plan Selected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please select a plan to view your progress',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Go Back to Dashboard'),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_selectedTopTabIndex) {
      case 0:
        return _buildCurrentWeekTab();
      case 1:
        return _buildNextWeekTab();
      case 2:
        return _buildProgressChartTab();
      default:
        return _buildCurrentWeekTab();
    }
  }

  // Current week tab
  Widget _buildCurrentWeekTab() {
    return Column(
      children: [
        _buildProgressSection(),
        _buildCalendar(_weekDays, false), // Current week calendar
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSessionsForDay(_weekDays[_selectedDay], false),
          ),
        ),
      ],
    );
  }

  // Next week tab
  Widget _buildNextWeekTab() {
    return Column(
      children: [
        _buildNextWeekSummary(),
        _buildCalendar(_nextWeekDays, true), // Next week calendar
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSessionsForDay(_nextWeekDays[_selectedDay], true),
          ),
        ),
      ],
    );
  }

  // Next week summary
  Widget _buildNextWeekSummary() {
    if (_weeklyScheduleSummary == null) {
      return const SizedBox.shrink();
    }

    final nextWeekData =
        _weeklyScheduleSummary!['nextWeek'] as Map<String, dynamic>? ?? {};
    final hasAdjustedExercises =
        nextWeekData['hasAdjustedExercises'] as bool? ?? false;
    final totalScheduled = nextWeekData['total'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (hasAdjustedExercises) ...[
            // Adjusted exercises notification
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade50, Colors.indigo.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_fix_high,
                      color: Colors.purple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI-Optimized Exercises Ready',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        Text(
                          '$totalScheduled exercises optimized based on your feedback',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Regular next week info
            Text(
              'Next Week Schedule',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.primaryBlue,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              totalScheduled > 0
                  ? '$totalScheduled exercises scheduled'
                  : 'No exercises scheduled yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],

          const SizedBox(height: 12),

          // 🚨 NUCLEAR OPTION BUTTON - ALWAYS SHOWS ON NEXT WEEK TAB
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final authService =
                    Provider.of<AuthService>(context, listen: false);
                final userId = authService.currentUser?.uid;

                if (userId != null) {
                  // Show confirmation dialog
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('🚨 Nuclear Option'),
                      content: Text(
                          'This will delete ALL scheduled exercises. Continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text('DELETE ALL',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    // Show loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        content: Row(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 16),
                            Text('Nuking all exercises...'),
                          ],
                        ),
                      ),
                    );

                    try {
                      print('🚨 Starting nuclear option...');
                      await _adjustmentService
                          .nukeAllScheduledExercises(userId);
                      print('✅ Nuclear option completed!');

                      // Close loading dialog
                      Navigator.of(context).pop();

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '✅ ALL exercises deleted! Refresh to see changes.'),
                          backgroundColor: Colors.green,
                        ),
                      );

                      // Refresh the screen
                      await _loadWeeklyScheduleData();
                      setState(() {});
                    } catch (e) {
                      // Close loading dialog
                      Navigator.of(context).pop();

                      // Show error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              icon: Icon(Icons.clear, color: Colors.white),
              label: Text('🚨 NUCLEAR OPTION - DELETE ALL',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
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
            'Current Progress',
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
                  0, 'Missed', AppTheme.vibrantRed), // Simplified for now
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

  Widget _buildProgressIndicator() {
    final totalExercises = _selectedPlan?.exercises.length ?? 0;
    final completedExercises =
        _selectedPlan?.exercises.where((e) => e.isCompleted).length ?? 0;

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
              value:
                  totalExercises > 0 ? completedExercises / totalExercises : 0,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFCCDD00),
              ),
              strokeWidth: 8,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                completedExercises.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'of $totalExercises Completed',
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

  // Enhanced calendar to handle both current and next week
  Widget _buildCalendar(List<DateTime> weekDays, bool isNextWeek) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              weekDays.length,
              (index) => _buildCalendarDay(index, weekDays, isNextWeek),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getExercisesForDay(weekDays[_selectedDay], isNextWeek),
            builder: (context, snapshot) {
              final exerciseCount = snapshot.data?.length ?? 0;
              final dayName = isNextWeek ? 'Next' : 'Today';

              return Text(
                '$dayName, ${DateFormat('dd MMM yyyy').format(weekDays[_selectedDay])} ($exerciseCount exercises)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCalendarDay(
      int index, List<DateTime> weekDays, bool isNextWeek) {
    final day = weekDays[index];
    final isSelected = index == _selectedDay;
    final isToday = !isNextWeek && DateUtils.isSameDay(day, DateTime.now());
    final accentColor = isNextWeek ? Colors.purple : AppTheme.vibrantRed;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = index;
        });
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getExercisesForDay(day, isNextWeek),
        builder: (context, snapshot) {
          final hasExercises = (snapshot.data?.length ?? 0) > 0;

          return Container(
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
                if (hasExercises && !isSelected) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isNextWeek ? Colors.purple : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // Get exercises for specific day (enhanced for next week scheduling)
  Future<List<Map<String, dynamic>>> _getExercisesForDay(
      DateTime day, bool isNextWeek) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      if (userId == null) return [];

      if (isNextWeek) {
        // ✅ FIXED: Pass the current plan ID to filter exercises by plan
        return await _adjustmentService.getExercisesForDate(
          userId,
          day,
          currentPlanId: _selectedPlanId, // This was missing!
        );
      } else {
        // Get current plan exercises for current week (simplified logic)
        if (_selectedPlan == null) return [];

        // For current week, show exercises based on day of week
        final exercises = _selectedPlan!.exercises;
        if (exercises.isEmpty) return [];

        // Simple logic: show different exercise each day
        final dayIndex = day.weekday - 1; // Monday = 0
        if (dayIndex < exercises.length) {
          return [exercises[dayIndex].toJson()];
        }

        return [];
      }
    } catch (e) {
      print('❌ Error getting exercises for day: $e');
      return [];
    }
  }

  // Enhanced sessions display for specific day
  Widget _buildSessionsForDay(DateTime selectedDay, bool isNextWeek) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getExercisesForDay(selectedDay, isNextWeek),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Error loading exercises: ${snapshot.error}',
                style: TextStyle(color: Colors.red[600]),
              ),
            ),
          );
        }

        final exercises = snapshot.data ?? [];

        if (exercises.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    isNextWeek ? Icons.schedule : Icons.fitness_center,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isNextWeek
                        ? 'No exercises scheduled for this day'
                        : 'No exercises for today',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: exercises.asMap().entries.map((entry) {
            final index = entry.key;
            final exerciseData = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildExerciseCard(
                exerciseData: exerciseData,
                isNextWeek: isNextWeek,
                startTime: index == 0 ? '9 am' : '2 pm',
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // Enhanced exercise card for both current and next week
  Widget _buildExerciseCard({
    required Map<String, dynamic> exerciseData,
    required bool isNextWeek,
    required String startTime,
  }) {
    final isScheduled = exerciseData['isScheduled'] as bool? ?? false;
    final isAdjusted = exerciseData['isAdjusted'] as bool? ?? false;
    final exerciseCompleted = exerciseData['isCompleted'] as bool? ?? false;
    final status = exerciseData['status'] as String? ?? 'pending';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Exercise header with adjustment indicator
          if (isAdjusted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_fix_high,
                      color: Colors.purple, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'AI-Optimized',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ADJUSTED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Exercise image/icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: (isAdjusted ? Colors.purple : AppTheme.primaryBlue)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getExerciseIcon(
                        exerciseData['bodyPart'] as String? ?? 'General'),
                    color: isAdjusted ? Colors.purple : AppTheme.primaryBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Exercise name
                      Text(
                        exerciseData['name'] as String? ?? 'Exercise',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Exercise parameters
                      Row(
                        children: [
                          const Icon(Icons.fitness_center,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${exerciseData['sets'] ?? 0} Sets, ${exerciseData['reps'] ?? 0} Reps',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Status and timing
                      Row(
                        children: [
                          if (isNextWeek) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(status),
                                ),
                              ),
                            ),
                          ] else ...[
                            if (exerciseCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'COMPLETED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            'Start from $startTime',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () =>
                  _handleExerciseButtonTap(exerciseData, isNextWeek),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _getExerciseButtonColor(exerciseData, isNextWeek),
                foregroundColor:
                    _getExerciseButtonTextColor(exerciseData, isNextWeek),
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getExerciseButtonIcon(exerciseData, isNextWeek),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getExerciseButtonText(exerciseData, isNextWeek),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for exercise cards
  IconData _getExerciseIcon(String bodyPart) {
    switch (bodyPart.toLowerCase()) {
      case 'knee':
        return Icons.accessibility_new;
      case 'shoulder':
        return Icons.sports_gymnastics;
      case 'back':
        return Icons.airline_seat_recline_normal;
      case 'arm':
      case 'elbow':
      case 'wrist':
        return Icons.fitness_center;
      case 'leg':
      case 'ankle':
      case 'hip':
        return Icons.directions_walk;
      case 'neck':
        return Icons.person;
      default:
        return Icons.fitness_center;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'skipped':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getExerciseButtonColor(
      Map<String, dynamic> exerciseData, bool isNextWeek) {
    if (isNextWeek) {
      final status = exerciseData['status'] as String? ?? 'scheduled';
      switch (status) {
        case 'completed':
          return Colors.green;
        case 'scheduled':
          return const Color(0xFFCCDD00);
        default:
          return Colors.grey.shade400;
      }
    } else {
      final isCompleted = exerciseData['isCompleted'] as bool? ?? false;
      return isCompleted ? Colors.grey.shade400 : const Color(0xFFCCDD00);
    }
  }

  Color _getExerciseButtonTextColor(
      Map<String, dynamic> exerciseData, bool isNextWeek) {
    if (isNextWeek) {
      final status = exerciseData['status'] as String? ?? 'scheduled';
      return status == 'completed' ? Colors.white : Colors.black;
    } else {
      final isCompleted = exerciseData['isCompleted'] as bool? ?? false;
      return isCompleted ? Colors.white : Colors.black;
    }
  }

  IconData _getExerciseButtonIcon(
      Map<String, dynamic> exerciseData, bool isNextWeek) {
    if (isNextWeek) {
      final status = exerciseData['status'] as String? ?? 'scheduled';
      switch (status) {
        case 'completed':
          return Icons.check_circle;
        case 'scheduled':
          return Icons.schedule;
        default:
          return Icons.play_arrow;
      }
    } else {
      final isCompleted = exerciseData['isCompleted'] as bool? ?? false;
      return isCompleted ? Icons.check_circle : Icons.play_arrow;
    }
  }

  String _getExerciseButtonText(
      Map<String, dynamic> exerciseData, bool isNextWeek) {
    if (isNextWeek) {
      final status = exerciseData['status'] as String? ?? 'scheduled';
      switch (status) {
        case 'completed':
          return 'Completed';
        case 'scheduled':
          return 'Scheduled for Next Week';
        default:
          return 'Not Scheduled';
      }
    } else {
      final isCompleted = exerciseData['isCompleted'] as bool? ?? false;
      return isCompleted ? 'View Details' : 'Start Now';
    }
  }

  void _handleExerciseButtonTap(
      Map<String, dynamic> exerciseData, bool isNextWeek) {
    if (isNextWeek) {
      final status = exerciseData['status'] as String? ?? 'scheduled';
      if (status == 'scheduled') {
        _showNextWeekExerciseDetails(exerciseData);
      } else if (status == 'completed') {
        _showCompletedExerciseDetails(exerciseData);
      }
    } else {
      final isCompleted = exerciseData['isCompleted'] as bool? ?? false;
      if (isCompleted) {
        _showExerciseDetails(exerciseData);
      } else {
        _navigateToExerciseDetail(exerciseData);
      }
    }
  }

  // Show next week exercise details
  void _showNextWeekExerciseDetails(Map<String, dynamic> exerciseData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Exercise header with AI badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_fix_high,
                      color: Colors.purple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exerciseData['name'] as String? ?? 'Exercise',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'AI-Optimized for Next Week',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.purple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Adjusted parameters
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Optimized Parameters',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildParameterItem(
                            'Sets',
                            '${exerciseData['sets'] ?? 0}',
                            Icons.repeat,
                          ),
                        ),
                        Expanded(
                          child: _buildParameterItem(
                            'Reps',
                            '${exerciseData['reps'] ?? 0}',
                            Icons.fitness_center,
                          ),
                        ),
                        Expanded(
                          child: _buildParameterItem(
                            'Duration',
                            '${((exerciseData['durationSeconds'] ?? 0) / 60).ceil()}m',
                            Icons.timer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Exercise description
              const Text(
                'Exercise Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                exerciseData['description'] as String? ??
                    'No description available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Adjustment info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'This exercise has been automatically adjusted based on your previous feedback and performance patterns.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: const Text('Reschedule'),
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Implement rescheduling
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParameterItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.purple, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.purple,
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
    );
  }

  void _showExerciseDetails(Map<String, dynamic> exerciseData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Exercise details
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exerciseData['name'] as String? ?? 'Exercise',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Completed Exercise',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Exercise stats
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'Sets',
                            '${exerciseData['sets'] ?? 0}',
                            Icons.repeat,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'Reps',
                            '${exerciseData['reps'] ?? 0}',
                            Icons.fitness_center,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'Duration',
                            '${((exerciseData['durationSeconds'] ?? 0) / 60).ceil()}m',
                            Icons.timer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Exercise description
              const Text(
                'Exercise Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                exerciseData['description'] as String? ??
                    'No description available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.repeat),
                      label: const Text('Do Again'),
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToExerciseDetail(exerciseData);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
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
    );
  }

  void _showCompletedExerciseDetails(Map<String, dynamic> exerciseData) {
    // Similar to _showExerciseDetails but for completed next week exercises
    _showExerciseDetails(exerciseData);
  }

  void _navigateToExerciseDetail(Map<String, dynamic> exerciseData) async {
    try {
      final exercise = Exercise.fromJson(exerciseData);

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExerciseScreen(
            exercise: exercise,
            planId: _selectedPlanId,
          ),
        ),
      );

      if (result != null && result is Map<String, dynamic>) {
        final bool isCompleted = result['completed'] ?? false;

        if (isCompleted) {
          // Refresh the plan data
          await _refreshPlanData();

          // Reload weekly schedule data to show any new adjustments
          await _loadWeeklyScheduleData();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${exercise.name} completed! Check next week for optimized version.'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error navigating to exercise: $e');
    }
  }

  Future<void> _refreshPlanData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      if (userId == null || _selectedPlanId == null) return;

      // Fetch updated plan data
      DocumentSnapshot? planDoc;

      // Try user's collection first
      final userPlanQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('rehabilitation_plans')
          .where(FieldPath.documentId, isEqualTo: _selectedPlanId)
          .get();

      if (userPlanQuery.docs.isNotEmpty) {
        planDoc = userPlanQuery.docs.first;
      } else {
        // Try main collection
        planDoc = await FirebaseFirestore.instance
            .collection('rehabilitation_plans')
            .doc(_selectedPlanId)
            .get();
      }

      if (planDoc != null && planDoc.exists) {
        final planData = planDoc.data() as Map<String, dynamic>;
        final updatedPlan = RehabilitationPlan.fromJson(planData);

        setState(() {
          _selectedPlan = updatedPlan;
        });

        print('✅ Plan data refreshed successfully');
      }
    } catch (e) {
      print('❌ Error refreshing plan data: $e');
    }
  }

  Widget _buildProgressChartTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress Charts',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Progress data display
          Consumer<ProgressService>(
            builder: (context, progressService, child) {
              return FutureBuilder<Map<String, dynamic>>(
                future: _getProgressData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Center(
                      child: Text('Unable to load progress data'),
                    );
                  }

                  final data = snapshot.data!;
                  final painLevels =
                      List<double>.from(data['painLevels'] ?? []);
                  final adherenceRates =
                      List<int>.from(data['adherenceRates'] ?? []);
                  final dates = List<String>.from(data['dates'] ?? []);

                  if (painLevels.isEmpty || adherenceRates.isEmpty) {
                    return _buildNoDataMessage();
                  }

                  return Column(
                    children: [
                      // Combined Progress Chart
                      ProgressChartWidget(
                        painLevels: painLevels,
                        adherenceRates: adherenceRates,
                        dates: dates,
                        title: 'Pain Level & Adherence Trends',
                      ),
                      const SizedBox(height: 20),

                      // Progress Summary Cards
                      _buildProgressSummaryCards(data),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.show_chart,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No Progress Data Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete some exercises to see your progress charts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSummaryCards(Map<String, dynamic> data) {
    final painLevels = List<double>.from(data['painLevels'] ?? []);
    final adherenceRates = List<int>.from(data['adherenceRates'] ?? []);

    final avgPain = painLevels.isNotEmpty
        ? painLevels.reduce((a, b) => a + b) / painLevels.length
        : 0;
    final avgAdherence = adherenceRates.isNotEmpty
        ? adherenceRates.reduce((a, b) => a + b) / adherenceRates.length
        : 0;

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.trending_down,
                    color: avgPain <= 5 ? Colors.green : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Avg Pain Level',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    avgPain.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: avgAdherence >= 80 ? Colors.green : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Avg Adherence',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${avgAdherence.round()}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getProgressData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final progressService =
        Provider.of<ProgressService>(context, listen: false);

    if (authService.currentUser?.uid != null) {
      return await progressService.getProgressTrends(
        authService.currentUser!.uid,
        daysBack: 30,
      );
    }

    // Return mock data if no user
    return {
      'painLevels': [8.0, 7.5, 6.0, 5.5, 4.0, 3.5, 3.0],
      'adherenceRates': [60, 70, 75, 80, 85, 90, 95],
      'dates': ['1/12', '2/12', '3/12', '4/12', '5/12', '6/12', '7/12'],
    };
  }
}
