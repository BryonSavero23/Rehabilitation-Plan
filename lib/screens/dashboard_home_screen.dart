import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/screens/exercise_recommendation_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/user_input_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/progress/rehabilitation_progress_screen.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist_chat_screen.dart';

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({Key? key}) : super(key: key);

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  String? _selectedPlanId;
  RehabilitationPlan? _selectedPlan;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    // Get the user's rehabilitation plans
    final plansSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(authService.currentUser?.uid)
        .collection('rehabilitation_plans')
        .orderBy('title')
        .limit(1)
        .get();

    if (plansSnapshot.docs.isNotEmpty) {
      final firstPlan = plansSnapshot.docs.first;
      setState(() {
        _selectedPlanId = firstPlan.id;
        _selectedPlan = RehabilitationPlan.fromJson(firstPlan.data());
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _onPlanChanged(String? planId, RehabilitationPlan? plan) {
    setState(() {
      _selectedPlanId = planId;
      _selectedPlan = plan;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userName = authService.currentUserModel?.name ?? 'User';

    return Scaffold(
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
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(userName),
                      const SizedBox(height: 24),
                      _buildPlanSelector(authService),
                      const SizedBox(height: 24),
                      _buildStatsGrid(authService),
                      const SizedBox(height: 24),
                      if (_selectedPlan != null) _buildQuickActions(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(String userName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $userName.',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Doing great, keep it up!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade300,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.emoji_events,
            color: Colors.white,
            size: 32,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanSelector(AuthService authService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserInputScreen(),
                ),
              );
            },
            child: Text(
              'Add New',
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(AuthService authService) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildProgressCard(),
        _buildWeekCard(),
        _buildTherapistChatCard(),
        _buildPainLevelCard(),
      ],
    );
  }

  Widget _buildProgressCard() {
    int completedExercises = 0;
    int totalExercises = 0;

    if (_selectedPlan != null) {
      totalExercises = _selectedPlan!.exercises.length;
      completedExercises =
          _selectedPlan!.exercises.where((e) => e.isCompleted).length;
    }

    double progressPercentage =
        totalExercises > 0 ? (completedExercises / totalExercises) * 100 : 0;

    return _buildStatCard(
      title: 'Progress',
      value: '${progressPercentage.round()}%',
      icon: Icons.bar_chart,
      color: Colors.purple.shade300,
      onTap: () {
        if (_selectedPlan != null && _selectedPlanId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RehabilitationProgressScreen(
                plan: _selectedPlan!,
                planId: _selectedPlanId,
                therapistName: "Your Therapist",
                therapistTitle: "Dr.",
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildWeekCard() {
    return _buildStatCard(
      title: 'View Plan',
      value: 'Details',
      icon: Icons.visibility,
      color: Colors.blue.shade300,
      onTap: () {
        if (_selectedPlan != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExerciseRecommendationScreen(
                plan: _selectedPlan!,
                planId: _selectedPlanId,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a plan first'),
            ),
          );
        }
      },
    );
  }

  Widget _buildTherapistChatCard() {
    return _buildStatCard(
      title: 'Therapist Chat',
      value: 'Tap to chat',
      icon: Icons.chat_bubble_outline,
      color: Colors.teal.shade300,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TherapistChatScreen(
              therapistName: "Sarah Johnson",
              therapistTitle: "Dr.",
            ),
          ),
        );
      },
    );
  }

  Widget _buildPainLevelCard() {
    // This would be fetched from the latest progress log
    int painLevel = 6;
    bool isImproving = true; // This would be calculated from recent progress

    return _buildStatCard(
      title: 'Pain Level',
      value: painLevel.toString(),
      icon: Icons.healing,
      color: Colors.pink.shade300,
      trailing: Icon(
        isImproving ? Icons.trending_down : Icons.trending_up,
        color: isImproving ? Colors.green : Colors.red,
        size: 16,
      ),
      onTap: () {
        // Navigate to pain tracking or progress details
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                title: 'View Plan',
                icon: Icons.visibility,
                color: AppTheme.primaryBlue,
                onTap: () {
                  if (_selectedPlan != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExerciseRecommendationScreen(
                          plan: _selectedPlan!,
                          planId: _selectedPlanId,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                title: 'Progress',
                icon: Icons.trending_up,
                color: Colors.green,
                onTap: () {
                  if (_selectedPlan != null && _selectedPlanId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RehabilitationProgressScreen(
                          plan: _selectedPlan!,
                          planId: _selectedPlanId,
                          therapistName: "Your Therapist",
                          therapistTitle: "Dr.",
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
