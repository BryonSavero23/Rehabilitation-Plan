// lib/widgets/pain_feedback_widget.dart
import 'package:flutter/material.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';

class PainFeedbackWidget extends StatefulWidget {
  final int initialPainLevel;
  final String title;
  final String subtitle;
  final Function(int) onPainLevelChanged;
  final bool showComparison;
  final int? previousPainLevel;

  const PainFeedbackWidget({
    super.key,
    required this.initialPainLevel,
    required this.title,
    required this.subtitle,
    required this.onPainLevelChanged,
    this.showComparison = false,
    this.previousPainLevel,
  });

  @override
  State<PainFeedbackWidget> createState() => _PainFeedbackWidgetState();
}

class _PainFeedbackWidgetState extends State<PainFeedbackWidget>
    with TickerProviderStateMixin {
  late int _currentPainLevel;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _currentPainLevel = widget.initialPainLevel;
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _updatePainLevel(int newLevel) {
    setState(() {
      _currentPainLevel = newLevel;
    });
    widget.onPainLevelChanged(newLevel);
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
  }

  Color _getPainColor(int level) {
    if (level == 0) return Colors.green;
    if (level <= 3) return Colors.lightGreen;
    if (level <= 5) return Colors.yellow.shade700;
    if (level <= 7) return Colors.orange;
    return Colors.red;
  }

  String _getPainDescription(int level) {
    if (level == 0) return 'No Pain';
    if (level <= 2) return 'Mild';
    if (level <= 4) return 'Moderate';
    if (level <= 6) return 'Noticeable';
    if (level <= 8) return 'Severe';
    return 'Extreme';
  }

  Widget _buildPainFace(int level) {
    IconData icon;
    if (level == 0) {
      icon = Icons.sentiment_very_satisfied;
    } else if (level <= 3) {
      icon = Icons.sentiment_satisfied;
    } else if (level <= 5) {
      icon = Icons.sentiment_neutral;
    } else if (level <= 7) {
      icon = Icons.sentiment_dissatisfied;
    } else {
      icon = Icons.sentiment_very_dissatisfied;
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _currentPainLevel == level ? _scaleAnimation.value : 1.0,
          child: Icon(
            icon,
            size: 32,
            color: _getPainColor(level),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
            children: [
              Icon(
                Icons.healing,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Pain Level Selector with Faces
          Center(
            child: Column(
              children: [
                _buildPainFace(_currentPainLevel),
                const SizedBox(height: 16),

                // Current Pain Level Display
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getPainColor(_currentPainLevel).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getPainColor(_currentPainLevel),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _currentPainLevel.toString(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _getPainColor(_currentPainLevel),
                        ),
                      ),
                      Text(
                        _getPainDescription(_currentPainLevel),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _getPainColor(_currentPainLevel),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Pain Level Slider
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '0',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'Pain Level',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '10',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),

              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _getPainColor(_currentPainLevel),
                  inactiveTrackColor: Colors.grey.shade300,
                  thumbColor: _getPainColor(_currentPainLevel),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12,
                  ),
                  overlayColor:
                      _getPainColor(_currentPainLevel).withOpacity(0.2),
                  trackHeight: 8,
                ),
                child: Slider(
                  value: _currentPainLevel.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  onChanged: (value) {
                    _updatePainLevel(value.round());
                  },
                ),
              ),

              // Number buttons for precise selection
              Wrap(
                spacing: 8,
                children: List.generate(11, (index) {
                  return GestureDetector(
                    onTap: () => _updatePainLevel(index),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _currentPainLevel == index
                            ? _getPainColor(index)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getPainColor(index).withOpacity(0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          index.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _currentPainLevel == index
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),

          // Comparison with previous level
          if (widget.showComparison && widget.previousPainLevel != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.compare_arrows,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPainComparison(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPainComparison() {
    final previous = widget.previousPainLevel!;
    final current = _currentPainLevel;
    final change = current - previous;

    String changeText;
    Color changeColor;
    IconData changeIcon;

    if (change > 0) {
      changeText = '+$change (increased)';
      changeColor = Colors.red;
      changeIcon = Icons.trending_up;
    } else if (change < 0) {
      changeText = '${change} (decreased)';
      changeColor = Colors.green;
      changeIcon = Icons.trending_down;
    } else {
      changeText = 'No change';
      changeColor = Colors.grey;
      changeIcon = Icons.trending_flat;
    }

    return Row(
      children: [
        Text(
          'Previous: $previous → Current: $current',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 8),
        Icon(changeIcon, size: 16, color: changeColor),
        const SizedBox(width: 4),
        Text(
          changeText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: changeColor,
          ),
        ),
      ],
    );
  }
}
