import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/screens/exercise_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/exercise_recommendation_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist_chat_screen.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'package:personalized_rehabilitation_plans/widgets/progress_chart_widget.dart';
import 'package:personalized_rehabilitation_plans/screens/profile/profile_screen.dart';
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
  int _selectedTopTabIndex = 0; // 0: Activity, 1: Progress Chart
  final List<DateTime> _weekDays = [];
  bool _isLoading = false;

  // Plan selection state - following dashboard pattern
  String? _selectedPlanId;
  RehabilitationPlan? _selectedPlan;
  String? _therapistName;
  String? _therapistTitle;

  @override
  void initState() {
    super.initState();
    _generateWeekDays();
    _loadInitialData();
  }

  // Following dashboard pattern for loading initial data
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      // If plan is passed via constructor (like from dashboard), use it
      if (widget.plan != null && widget.planId != null) {
        setState(() {
          _selectedPlan = widget.plan;
          _selectedPlanId = widget.planId;
          _therapistName = widget.therapistName;
          _therapistTitle = widget.therapistTitle;
        });
        await _loadTherapistInfo();
      } else {
        // Otherwise, load the first available plan (following dashboard pattern)
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
    } catch (e) {
      print('Error loading initial data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Following dashboard pattern for plan changes
  void _onPlanChanged(String? planId, RehabilitationPlan? plan) {
    setState(() {
      _selectedPlanId = planId;
      _selectedPlan = plan;
    });
    _loadTherapistInfo();
  }

  Future<void> _loadTherapistInfo() async {
    if (_selectedPlan == null || _selectedPlanId == null) return;

    try {
      // Get therapist ID from the plan data
      final planSnapshot = await FirebaseFirestore.instance
          .collection('rehabilitation_plans')
          .doc(_selectedPlanId)
          .get();

      if (planSnapshot.exists) {
        final planData = planSnapshot.data();
        final therapistId = planData?['therapistId'];

        print('DEBUG: Plan data - therapistId: $therapistId'); // Debug log

        if (therapistId != null && therapistId.isNotEmpty) {
          // Get therapist user data
          final therapistDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(therapistId)
              .get();

          print(
              'DEBUG: Therapist doc exists: ${therapistDoc.exists}'); // Debug log

          if (therapistDoc.exists) {
            final therapistData = therapistDoc.data()!;
            print('DEBUG: Therapist data: $therapistData'); // Debug log

            // Get therapist profile for additional info
            final therapistProfileDoc = await FirebaseFirestore.instance
                .collection('therapists')
                .doc(therapistId)
                .get();

            print(
                'DEBUG: Therapist profile exists: ${therapistProfileDoc.exists}'); // Debug log

            String therapistName = therapistData['name'] ?? 'Unknown Therapist';
            String therapistTitle = 'Dr.';

            if (therapistProfileDoc.exists) {
              final profileData = therapistProfileDoc.data();
              print('DEBUG: Profile data: $profileData'); // Debug log

              // Try different possible fields for title/specialization
              therapistTitle = profileData?['title'] ??
                  profileData?['specialization'] ??
                  'Dr.';
            }

            setState(() {
              _therapistName = therapistName;
              _therapistTitle = therapistTitle;
            });

            print(
                'DEBUG: Set therapist name: $_therapistName, title: $_therapistTitle'); // Debug log
          } else {
            print('DEBUG: Therapist document not found for ID: $therapistId');
            setState(() {
              _therapistName = 'Therapist Not Found';
              _therapistTitle = 'Dr.';
            });
          }
        } else {
          print('DEBUG: No therapistId in plan data');
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

  void _generateWeekDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _weekDays.add(today);
    for (int i = 1; i < 6; i++) {
      _weekDays.add(today.add(Duration(days: i)));
    }
  }

  // FIX: Calculated getters that always recalculate from current plan state
  int get _completedExercisesCount {
    if (_selectedPlan == null) return 0;
    final count = _selectedPlan!.exercises.where((e) => e.isCompleted).length;
    return count;
  }

  int get _remainingExercisesCount {
    if (_selectedPlan == null) return 0;
    final total = _selectedPlan!.exercises.length;
    final completed = _completedExercisesCount;
    final remaining = total - completed;
    return remaining;
  }

  int get _missedExercisesCount {
    return 0; // Placeholder
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

          // Plan selector following dashboard pattern
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
                  'Activity',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTopTabIndex == 0
                        ? Theme.of(context).primaryColor
                        : Colors.white,
                    fontWeight: FontWeight.w600,
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
                child: Text(
                  'Progress Chart',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTopTabIndex == 1
                        ? Theme.of(context).primaryColor
                        : Colors.white,
                    fontWeight: FontWeight.w600,
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
              // Navigate back to dashboard (index 0 in bottom navigation)
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
        return _buildActivityTab();
      case 1:
        return _buildProgressChartTab();
      default:
        return _buildActivityTab();
    }
  }

  Widget _buildActivityTab() {
    return Column(
      children: [
        _buildProgressSection(),
        _buildCalendar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSessionsForToday(),
          ),
        ),
      ],
    );
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

          // Fetch and display progress data
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

                      // Individual Pain Chart
                      SimpleProgressChart(
                        values: painLevels,
                        labels: dates,
                        title: 'Pain Level Over Time',
                        color: Colors.red,
                        maxValue: 10,
                        yAxisLabel: 'Pain Level (0-10)',
                      ),
                      const SizedBox(height: 20),

                      // Individual Adherence Chart
                      SimpleProgressChart(
                        values:
                            adherenceRates.map((e) => e.toDouble()).toList(),
                        labels: dates,
                        title: 'Adherence Rate Over Time',
                        color: Colors.green,
                        maxValue: 100,
                        yAxisLabel: 'Adherence (%)',
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

  Widget _buildProgressIndicator() {
    // FIX: Recalculate progress values on every rebuild
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
    if (_selectedPlan == null) return [];

    // This is a simplified implementation
    // In a real app, you would filter exercises based on scheduled dates
    if (day.weekday <= _selectedPlan!.exercises.length) {
      // Return a subset of exercises based on the day of week
      return [
        _selectedPlan!
            .exercises[(day.weekday - 1) % _selectedPlan!.exercises.length]
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
                          // Completion status indicator
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
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.pending,
                                    size: 12,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Pending',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.orange,
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
                            exerciseCompleted
                                ? 'Completed today'
                                : 'Start session from $startTime',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: exerciseCompleted
                                          ? Colors.green
                                          : Colors.grey,
                                      fontWeight: exerciseCompleted
                                          ? FontWeight.w500
                                          : FontWeight.normal,
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
              onPressed: () =>
                  _handleExerciseButtonTap(exercise, exerciseCompleted),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getExerciseButtonColor(exerciseCompleted),
                foregroundColor: _getExerciseButtonTextColor(exerciseCompleted),
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
                    _getExerciseButtonIcon(exerciseCompleted),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getExerciseButtonText(exerciseCompleted),
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

  Color _getExerciseButtonColor(bool isCompleted) {
    if (isCompleted) {
      return Colors.grey.shade400; // Completed - gray
    } else {
      return const Color(0xFFCCDD00); // Not completed - active green
    }
  }

  Color _getExerciseButtonTextColor(bool isCompleted) {
    if (isCompleted) {
      return Colors.white;
    } else {
      return Colors.black;
    }
  }

  IconData _getExerciseButtonIcon(bool isCompleted) {
    if (isCompleted) {
      return Icons.check_circle;
    } else {
      return Icons.play_arrow;
    }
  }

  String _getExerciseButtonText(bool isCompleted) {
    if (isCompleted) {
      return 'View Details';
    } else {
      return 'Start Now';
    }
  }

  void _handleExerciseButtonTap(Exercise exercise, bool isCompleted) {
    if (isCompleted) {
      // Show exercise details or feedback
      _showExerciseDetails(exercise);
    } else {
      // Start the exercise
      _navigateToExerciseDetail(exercise);
    }
  }

  void _showExerciseDetails(Exercise exercise) {
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
                          exercise.name,
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
                            exercise.sets.toString(),
                            Icons.repeat,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'Reps',
                            exercise.reps.toString(),
                            Icons.fitness_center,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'Duration',
                            '${(exercise.durationSeconds / 60).ceil()}m',
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
                exercise.description,
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
                        _navigateToExerciseDetail(exercise);
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

  // FIX: Updated navigation method with proper state management
  void _navigateToExerciseDetail(Exercise exercise) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Navigate to exercise screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExerciseScreen(
            exercise: exercise,
            planId: _selectedPlanId,
          ),
        ),
      );

      // Handle the result from exercise completion
      if (result != null && result is Map<String, dynamic>) {
        final bool isCompleted = result['completed'] ?? false;
        final String? exerciseId = result['exerciseId'];

        if (isCompleted &&
            exerciseId != null &&
            _selectedPlan != null &&
            _selectedPlanId != null) {
          // FIX: Update the local plan state immediately for instant UI feedback
          final exerciseIndex =
              _selectedPlan!.exercises.indexWhere((e) => e.id == exerciseId);
          if (exerciseIndex != -1) {
            setState(() {
              _selectedPlan!.exercises[exerciseIndex].isCompleted = true;
            });
          }

          // Update the plan in Firestore in the background
          await _updatePlanInFirestore(exerciseId);

          // Refresh the plan data from Firestore to ensure consistency
          await _refreshPlanData();

          // Show success message with updated progress
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${exercise.name} completed! Progress: ${_completedExercisesCount}/${_totalExercisesCount}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePlanInFirestore(String exerciseId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      if (userId == null || _selectedPlanId == null) return;

      // Try user's collection first
      final userPlanQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('rehabilitation_plans')
          .where(FieldPath.documentId, isEqualTo: _selectedPlanId)
          .get();

      if (userPlanQuery.docs.isNotEmpty) {
        await _updatePlanDocument(userPlanQuery.docs.first, exerciseId);
        return;
      }

      // Try main rehabilitation_plans collection
      final mainPlanDoc = await FirebaseFirestore.instance
          .collection('rehabilitation_plans')
          .doc(_selectedPlanId)
          .get();

      if (mainPlanDoc.exists) {
        await _updatePlanDocument(mainPlanDoc, exerciseId);
        return;
      }

      print('❌ Plan document not found: $_selectedPlanId');
    } catch (e) {
      print('❌ Error updating plan in Firestore: $e');
    }
  }

  Future<void> _updatePlanDocument(
      DocumentSnapshot planDoc, String exerciseId) async {
    try {
      final planData = planDoc.data() as Map<String, dynamic>;
      List<dynamic> exercises = List.from(planData['exercises'] ?? []);

      bool exerciseFound = false;
      for (int i = 0; i < exercises.length; i++) {
        if (exercises[i]['id'] == exerciseId) {
          exercises[i]['isCompleted'] = true;
          exercises[i]['completedAt'] = FieldValue.serverTimestamp();
          exerciseFound = true;
          break;
        }
      }

      if (exerciseFound) {
        await planDoc.reference.update({
          'exercises': exercises,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print('✅ Exercise $exerciseId marked as completed in Firestore');
      } else {
        print('❌ Exercise $exerciseId not found in plan');
      }
    } catch (e) {
      print('❌ Error updating plan document: $e');
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
}

// Simple Progress Chart Widget (included in progress_chart_widget.dart but referenced here)
class SimpleProgressChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String title;
  final Color color;
  final double maxValue;
  final String yAxisLabel;

  const SimpleProgressChart({
    Key? key,
    required this.values,
    required this.labels,
    required this.title,
    required this.color,
    required this.maxValue,
    required this.yAxisLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                painter: SimpleChartPainter(
                  values: values,
                  labels: labels,
                  color: color,
                  maxValue: maxValue,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              yAxisLabel,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple Chart Painter
class SimpleChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final double maxValue;

  SimpleChartPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final points = <Offset>[];

    // Calculate points
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - (values[i] / maxValue) * size.height;
      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw line
    canvas.drawPath(path, paint);

    // Draw points
    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
