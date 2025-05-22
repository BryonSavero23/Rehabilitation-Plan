import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/screens/bottom_bar/bottom_bar.dart';

class TherapistGuard extends StatefulWidget {
  final Widget child;

  const TherapistGuard({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<TherapistGuard> createState() => _TherapistGuardState();
}

class _TherapistGuardState extends State<TherapistGuard> {
  bool _isLoading = true;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    // Check if the user is a therapist
    final isTherapist = await authService.isUserTherapist();

    setState(() {
      _hasAccess = isTherapist;
      _isLoading = false;
    });

    // If not a therapist, redirect to main screen
    if (!isTherapist && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Access denied. Only therapists can access this feature.'),
          backgroundColor: Colors.red,
        ),
      );

      // Navigate back to main screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BottomBarScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Verifying access...',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Fix: Return the child widget if the user has access
    return _hasAccess ? widget.child : const SizedBox.shrink();
  }
}

// Extension method for BuildContext to easily check if user is a therapist
extension TherapistCheck on BuildContext {
  Future<bool> isTherapist() async {
    final authService = Provider.of<AuthService>(this, listen: false);
    return await authService.isUserTherapist();
  }
}
