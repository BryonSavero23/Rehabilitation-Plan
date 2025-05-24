import 'package:flutter/material.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/screens/profile/profile_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/user_input_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/progress/rehabilitation_progress_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/dashboard_home_screen.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../saved_plans/saved_rehabilitation_plans.dart';

class BottomBarScreen extends StatefulWidget {
  const BottomBarScreen({super.key});

  @override
  State<BottomBarScreen> createState() => _BottomBarScreenState();
}

class _BottomBarScreenState extends State<BottomBarScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.initializeUser();

      // Redirect therapists to therapist interface
      final isTherapist = await authService.isUserTherapist();
      if (mounted && isTherapist) {
        Navigator.of(context).pushReplacementNamed('/therapist_home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          if (authService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Patient screens only
          if (_selectedIndex == 0) {
            return const DashboardHomeScreen(); // Dashboard home
          } else if (_selectedIndex == 1) {
            return const UserInputScreen(); // Create plan
          } else if (_selectedIndex == 2) {
            return const SavedRehabilitationPlans(); // Saved plans
          } else if (_selectedIndex == 3) {
            // Show progress screen using StreamBuilder to get plans
            return StreamBuilder(
              stream: authService.getRehabilitationPlans(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final firstPlanDoc = snapshot.data!.docs.first;
                  final planData = firstPlanDoc.data();
                  final plan = RehabilitationPlan.fromJson(planData);
                  final planId = firstPlanDoc.id;

                  return RehabilitationProgressScreen(
                    plan: plan,
                    planId: planId,
                    therapistName: "Your Therapist",
                    therapistTitle: "Dr.",
                  );
                } else {
                  return const Center(
                    child: Text(
                        'No rehabilitation plans found. Create one to see progress.'),
                  );
                }
              },
            );
          } else {
            return const ProfileScreen();
          }
        },
      ),
      bottomNavigationBar: _buildPatientBottomNav(),
    );
  }

  // Bottom navigation for patient users - 5 tabs including Dashboard
  Widget _buildPatientBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed, // Required for 5 items
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          label: 'Create Plan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark),
          label: 'My Plans',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.show_chart),
          label: 'Progress',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
