// lib/main.dart (UPDATE your existing main.dart)
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:personalized_rehabilitation_plans/screens/auth/login_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/bottom_bar/bottom_bar.dart';
import 'package:personalized_rehabilitation_plans/screens/splash_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/therapist_bottom_bar_screen.dart';
import 'package:provider/provider.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart'; // Your updated theme

// 🆕 NEW: Theme provider for managing theme state
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    // For system mode, check the current brightness
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // 🆕 NEW
      ],
      child: Consumer<ThemeProvider>(
        // 🆕 NEW: Listen to theme changes
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'PRP',
            debugShowCheckedModeBanner: false,

            // 🌙 UPDATED: Add dark theme support
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme, // 🆕 NEW
            themeMode: themeProvider.themeMode, // 🆕 NEW

            home: const SplashScreen(),

            // 🎨 Optional: Custom route for theme transitions
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const BottomBarScreen(),
              '/therapist_home': (context) => const TherapistBottomBarScreen(),
            },
          );
        },
      ),
    );
  }
}
