import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:personalized_rehabilitation_plans/screens/bottom_bar/bottom_bar.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/therapist_bottom_bar_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:personalized_rehabilitation_plans/screens/splash_screen.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/services/progress_service.dart';
import 'package:personalized_rehabilitation_plans/services/notification_service.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ProgressService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: MaterialApp(
        title: 'Personalized Rehab Plan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthStateWrapper(),
        routes: {
          '/patient_home': (context) => const BottomBarScreen(),
          '/therapist_home': (context) => const TherapistBottomBarScreen(),
        },
      ),
    );
  }
}

class AuthStateWrapper extends StatelessWidget {
  const AuthStateWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return StreamBuilder<User?>(
          stream: authService.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            if (snapshot.hasData && snapshot.data != null) {
              // User is logged in, determine their role
              return FutureBuilder<void>(
                future: authService.initializeUser(),
                builder: (context, initSnapshot) {
                  if (initSnapshot.connectionState == ConnectionState.waiting) {
                    return const SplashScreen();
                  }

                  // Check if user is a therapist
                  final isTherapist =
                      authService.currentUserModel?.isTherapist ?? false;

                  if (isTherapist) {
                    return const TherapistBottomBarScreen();
                  } else {
                    return const BottomBarScreen();
                  }
                },
              );
            } else {
              // User is not logged in
              return const SplashScreen();
            }
          },
        );
      },
    );
  }
}
