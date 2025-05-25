import 'package:flutter/material.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';

class ProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String title;
  final String subtitle;
  final Color? color;
  final double height;
  final bool showPercentage;

  const ProgressIndicator({
    super.key,
    required this.progress,
    required this.title,
    this.subtitle = '',
    this.color,
    this.height = 8.0,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? AppTheme.primaryBlue;
    final percentage = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (showPercentage)
              Text(
                '$percentage%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                  fontSize: 14,
                ),
              ),
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: height,
          ),
        ),
      ],
    );
  }
}

class CustomCircularProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String centerText;
  final double size;
  final double strokeWidth;
  final Color? color;

  const CustomCircularProgressIndicator({
    super.key,
    required this.progress,
    this.centerText = '',
    this.size = 80.0,
    this.strokeWidth = 8.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? AppTheme.primaryBlue;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              strokeWidth: strokeWidth,
            ),
          ),
          if (centerText.isNotEmpty)
            Text(
              centerText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: progressColor,
                fontSize: size * 0.15,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
