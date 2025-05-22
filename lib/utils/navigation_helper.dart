import 'package:flutter/material.dart';
import 'package:personalized_rehabilitation_plans/screens/auth/login_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/bottom_bar/bottom_bar.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/therapist_registration_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/patient_management_dashboard.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/patient_detail_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/add_patient_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/create_rehabilitation_plan_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/edit_rehabilitation_plan_screen.dart';

class NavigationHelper {
  // Navigation for auth flow
  static void navigateToMain(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BottomBarScreen()),
      (route) => false,
    );
  }

  static void navigateToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  static void navigateToTherapistRegistration(
      BuildContext context, String userId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TherapistRegistrationScreen(
          userId: userId,
        ),
      ),
    );
  }

  // Navigation for therapist flow
  static void navigateToPatientManagement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PatientManagementDashboard(),
      ),
    );
  }

  static void navigateToPatientDetail(
    BuildContext context, {
    required String patientId,
    required String patientName,
    int initialTabIndex = 0,
    String? selectedPlanId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientDetailScreen(
          patientId: patientId,
          patientName: patientName,
          initialTabIndex: initialTabIndex,
          selectedPlanId: selectedPlanId,
        ),
      ),
    );
  }

  static void navigateToAddPatient(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddPatientScreen(),
      ),
    );
  }

  static void navigateToCreatePlan(
    BuildContext context, {
    required String patientId,
    required String patientName,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateRehabilitationPlanScreen(
          patientId: patientId,
          patientName: patientName,
        ),
      ),
    );
  }

  static void navigateToEditPlan(
    BuildContext context, {
    required String planId,
    required String patientId,
    required String patientName,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditRehabilitationPlanScreen(
          planId: planId,
          patientId: patientId,
          patientName: patientName,
        ),
      ),
    );
  }
}
