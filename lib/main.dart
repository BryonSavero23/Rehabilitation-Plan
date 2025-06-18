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

class AuthStateWrapper extends StatefulWidget {
  const AuthStateWrapper({super.key});

  @override
  State<AuthStateWrapper> createState() => _AuthStateWrapperState();
}

class _AuthStateWrapperState extends State<AuthStateWrapper> {
  bool _isInitializing = false;

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
              // 🔧 FIXED: Initialize user data safely after build completes
              if (!_isInitializing && authService.currentUserModel == null) {
                _isInitializing = true;
                // Use addPostFrameCallback to defer the initialization until after build
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  try {
                    await authService.initializeUser();
                  } catch (e) {
                    print('Error initializing user: $e');
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isInitializing = false;
                      });
                    }
                  }
                });
                return const SplashScreen();
              }

              // Check if we're still initializing
              if (_isInitializing || authService.currentUserModel == null) {
                return const SplashScreen();
              }

              // User is initialized, determine their role
              final isTherapist =
                  authService.currentUserModel?.isTherapist ?? false;

              if (isTherapist) {
                return const TherapistBottomBarScreen();
              } else {
                return const BottomBarScreen();
              }
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
