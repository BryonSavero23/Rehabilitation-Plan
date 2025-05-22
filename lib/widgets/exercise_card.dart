import 'package:flutter/material.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_plan_model.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final bool isActive;
  final String startTime;
  final VoidCallback? onPressed;

  const ExerciseCard({
    Key? key,
    required this.exercise,
    required this.isActive,
    required this.startTime,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                _buildExerciseImage(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildExerciseInfo(),
                      const SizedBox(height: 4),
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildSessionDetails(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildActionButton(context),
        ],
      ),
    );
  }

  Widget _buildExerciseImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: exercise.imageUrl != null && exercise.imageUrl!.isNotEmpty
          ? Image.network(
              exercise.imageUrl!,
              width: 80,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderImage();
              },
            )
          : _buildPlaceholderImage(),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 60,
      color: Colors.grey.shade300,
      child: Icon(
        _getBodyPartIcon(),
        color: Colors.white,
      ),
    );
  }

  IconData _getBodyPartIcon() {
    // Choose icon based on body part
    switch (exercise.bodyPart.toLowerCase()) {
      case 'knee':
        return Icons.accessibility_new;
      case 'shoulder':
        return Icons.sports_gymnastics;
      case 'back':
        return Icons.airline_seat_recline_normal;
      case 'arm':
      case 'elbow':
      case 'wrist':
        return Icons.fitness_center;
      case 'leg':
      case 'ankle':
      case 'hip':
        return Icons.directions_walk;
      case 'neck':
        return Icons.person;
      default:
        return Icons.fitness_center;
    }
  }

  Widget _buildExerciseInfo() {
    return Row(
      children: [
        const Icon(
          Icons.fitness_center,
          size: 14,
          color: Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(
          '${exercise.sets} Sets, ${exercise.reps} Reps',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionDetails() {
    // Format duration from seconds to minutes
    final minutes = (exercise.durationSeconds / 60).ceil();
    String duration;

    if (minutes <= 5) {
      duration = '5 min';
    } else if (minutes <= 10) {
      duration = '5-10 min';
    } else if (minutes <= 15) {
      duration = '10-15 min';
    } else if (minutes <= 20) {
      duration = '15-20 min';
    } else {
      duration = '$minutes min';
    }

    return Row(
      children: [
        Text(
          duration,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '|',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Start session from $startTime',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isActive ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? const Color(0xFFCCDD00) // Yellow-green color for active
              : Colors.grey.shade400,
          foregroundColor: isActive ? Colors.black : Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
        ),
        child: Text(
          isActive ? 'Start Now' : 'Complete Previous Therapy First',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class CircularProgressWidget extends StatelessWidget {
  final int completed;
  final int total;
  final int remaining;
  final int missed;
  final String phaseName;
  final DateTime checkupDate;

  const CircularProgressWidget({
    Key? key,
    required this.completed,
    required this.total,
    required this.remaining,
    required this.missed,
    required this.phaseName,
    required this.checkupDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            phaseName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProgressCounter(
                  remaining, 'Remaining', Colors.grey.shade300),
              _buildProgressIndicator(),
              _buildProgressCounter(missed, 'Missed', Colors.orange),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildProgressCounter(int count, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade100,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: total > 0 ? completed / total : 0,
              backgroundColor: Colors.grey.shade200,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFCCDD00)),
              strokeWidth: 8,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                completed.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'of $total Completed',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
