// lib/services/error_handling_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ErrorHandlingService {
  static void logError(String error, {StackTrace? stackTrace}) {
    if (kDebugMode) {
      print('ERROR: $error');
      if (stackTrace != null) {
        print('STACK TRACE: $stackTrace');
      }
    }
    // In production, send to crash reporting service
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showWarningSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<void> handleAsyncError(
    Future<void> Function() operation,
    BuildContext context,
    String errorMessage,
  ) async {
    try {
      await operation();
    } catch (e, stackTrace) {
      logError(e.toString(), stackTrace: stackTrace);
      if (context.mounted) {
        showErrorSnackBar(context, errorMessage);
      }
    }
  }
}
