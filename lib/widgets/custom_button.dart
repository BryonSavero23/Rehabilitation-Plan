// lib/widgets/custom_button.dart (UPDATED - Replace your existing file)
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final IconData? icon;

  // 🌙 NEW: Dark mode support (optional parameters)
  final bool isDestructive; // For delete/error buttons
  final bool isSuccess; // For completion/success buttons

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 50,
    this.borderRadius = 8,
    this.padding,
    this.icon,
    this.isDestructive = false, // 🆕 NEW
    this.isSuccess = false, // 🆕 NEW
  });

  @override
  Widget build(BuildContext context) {
    // 🌙 Smart color selection based on theme and button type
    Color? buttonColor = backgroundColor;
    Color? buttonTextColor = textColor;

    if (buttonColor == null) {
      if (isDestructive) {
        buttonColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.red.shade300
            : Colors.red;
      } else if (isSuccess) {
        buttonColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.green.shade300
            : Colors.green;
      } else {
        buttonColor = Theme.of(context).primaryColor;
      }
    }

    if (buttonTextColor == null) {
      if (isDestructive || isSuccess) {
        buttonTextColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white;
      } else {
        buttonTextColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white;
      }
    }

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: buttonTextColor,
          padding: padding ?? const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: Theme.of(context).brightness == Brightness.dark ? 6 : 3,
          shadowColor: buttonColor.withOpacity(0.4),
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    buttonTextColor,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/* 
🎯 USAGE EXAMPLES (Your existing code will work + new options):

// ✅ Your existing buttons work exactly the same:
CustomButton(
  text: 'Submit Feedback',
  onPressed: _submitFeedback,
)

// 🆕 NEW: Enhanced buttons with smart colors:
CustomButton(
  text: 'Complete Exercise',
  onPressed: _completeExercise,
  isSuccess: true,  // Green color, works in both themes
  icon: Icons.check_circle,
)

CustomButton(
  text: 'Delete Plan',
  onPressed: _deletePlan,
  isDestructive: true,  // Red color, works in both themes
  icon: Icons.delete,
)
*/