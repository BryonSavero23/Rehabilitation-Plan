// lib/screens/archived_plans_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/services/weekly_progression_service.dart';

class ArchivedPlansScreen extends StatefulWidget {
  const ArchivedPlansScreen({super.key});

  @override
  State<ArchivedPlansScreen> createState() => _ArchivedPlansScreenState();
}

class _ArchivedPlansScreenState extends State<ArchivedPlansScreen> {
  final WeeklyProgressionService _progressionService =
      WeeklyProgressionService();

  List<Map<String, dynamic>> _archivedPlans = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, graduated, completed

  @override
  void initState() {
    super.initState();
    _loadArchivedPlans();
  }

  Future<void> _loadArchivedPlans() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      if (userId != null) {
        final plans = await _progressionService.getArchivedPlans(userId);
        setState(() {
          _archivedPlans = plans;
        });
      }
    } catch (e) {
      print('❌ Error loading archived plans: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading archived plans: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPlans {
    if (_selectedFilter == 'all') {
      return _archivedPlans;
    } else if (_selectedFilter == 'graduated') {
      return _archivedPlans
          .where((plan) => plan['archiveReason'] == 'graduation')
          .toList();
    } else {
      return _archivedPlans
          .where((plan) => plan['status'] == 'completed')
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Archived Plans'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadArchivedPlans,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _archivedPlans.isEmpty
              ? _buildEmptyState()
              : _buildPlansList(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading archived plans...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Archived Plans',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your rehabilitation plans to see them here',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansList() {
    return Column(
      children: [
        // Filter Tabs
        _buildFilterTabs(),

        // Plans List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadArchivedPlans,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredPlans.length,
              itemBuilder: (context, index) {
                final plan = _filteredPlans[index];
                return _buildPlanCard(plan);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildFilterTab('all', 'All Plans', _archivedPlans.length),
          _buildFilterTab(
              'graduated',
              'Graduated',
              _archivedPlans
                  .where((p) => p['archiveReason'] == 'graduation')
                  .length),
          _buildFilterTab('completed', 'Completed',
              _archivedPlans.where((p) => p['status'] == 'completed').length),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String filter, String label, int count) {
    final isSelected = _selectedFilter == filter;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = filter;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isGraduated = plan['archiveReason'] == 'graduation';
    final title = plan['title'] as String? ?? 'Untitled Plan';
    final description = plan['description'] as String? ?? '';
    final archivedAt =
        plan['archivedAt'] != null ? (plan['archivedAt'] as DateTime?) : null;
    final goalProgress =
        plan['finalGoalProgress'] as Map<String, dynamic>? ?? {};
    final achievementSummary =
        plan['achievementSummary'] as Map<String, dynamic>? ?? {};
    final achievementPercentage =
        achievementSummary['achievementPercentage'] as double? ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showPlanDetails(plan),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: isGraduated
                  ? [Colors.green.shade50, Colors.green.shade25]
                  : [Colors.blue.shade50, Colors.blue.shade25],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isGraduated
                          ? Colors.green.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isGraduated
                          ? Icons.emoji_events
                          : Icons.assignment_turned_in,
                      color: isGraduated
                          ? Colors.green.shade600
                          : Colors.blue.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isGraduated ? Colors.green : Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isGraduated ? 'GRADUATED' : 'COMPLETED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Achievement Progress
              if (achievementPercentage > 0) ...[
                Row(
                  children: [
                    Icon(
                      Icons.track_changes,
                      color: Colors.grey.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Goal Achievement',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${achievementPercentage.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: achievementPercentage >= 80
                                ? Colors.green
                                : Colors.orange,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: achievementPercentage / 100,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    achievementPercentage >= 80 ? Colors.green : Colors.orange,
                  ),
                  minHeight: 6,
                ),
                const SizedBox(height: 16),
              ],

              // Goals Summary
              if (goalProgress.isNotEmpty) ...[
                Text(
                  'Goals Achieved',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: goalProgress.entries.map((entry) {
                    final goalData = entry.value as Map<String, dynamic>;
                    final achieved = goalData['achieved'] as bool? ?? false;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: achieved
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: achieved
                              ? Colors.green.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            achieved ? Icons.check_circle : Icons.schedule,
                            size: 14,
                            color: achieved
                                ? Colors.green.shade600
                                : Colors.orange.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatGoalName(entry.key),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: achieved
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Footer with dates and actions
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    archivedAt != null
                        ? 'Completed ${DateFormat('MMM d, yyyy').format(archivedAt)}'
                        : 'Completion date unknown',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showPlanDetails(plan),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    style: TextButton.styleFrom(
                      foregroundColor: isGraduated
                          ? Colors.green.shade600
                          : Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlanDetails(Map<String, dynamic> plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPlanDetailsModal(plan),
    );
  }

  Widget _buildPlanDetailsModal(Map<String, dynamic> plan) {
    final isGraduated = plan['archiveReason'] == 'graduation';
    final title = plan['title'] as String? ?? 'Untitled Plan';
    final description = plan['description'] as String? ?? '';
    final goalProgress =
        plan['finalGoalProgress'] as Map<String, dynamic>? ?? {};
    final achievementSummary =
        plan['achievementSummary'] as Map<String, dynamic>? ?? {};
    final exercises = plan['exercises'] as List<dynamic>? ?? [];
    final startDate =
        plan['startDate'] != null ? (plan['startDate'] as DateTime?) : null;
    final archivedAt =
        plan['archivedAt'] != null ? (plan['archivedAt'] as DateTime?) : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isGraduated
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isGraduated
                                  ? Icons.emoji_events
                                  : Icons.assignment_turned_in,
                              color: isGraduated
                                  ? Colors.green.shade600
                                  : Colors.blue.shade600,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isGraduated
                                        ? Colors.green
                                        : Colors.blue,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isGraduated ? 'GRADUATED' : 'COMPLETED',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Description
                      if (description.isNotEmpty) ...[
                        Text(
                          'Description',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Duration
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Duration',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    startDate != null && archivedAt != null
                                        ? '${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(archivedAt)}'
                                        : 'Duration information not available',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Goal Progress Details
                      if (goalProgress.isNotEmpty) ...[
                        Text(
                          'Goal Achievement Details',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        ...goalProgress.entries.map((entry) {
                          final goalData = entry.value as Map<String, dynamic>;
                          final current = goalData['current'] as double? ?? 0.0;
                          final target = goalData['target'] as double? ?? 100.0;
                          final progress =
                              goalData['progress'] as double? ?? 0.0;
                          final achieved =
                              goalData['achieved'] as bool? ?? false;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: achieved
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: achieved
                                    ? Colors.green.shade200
                                    : Colors.orange.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getGoalIcon(entry.key),
                                      color: achieved
                                          ? Colors.green.shade600
                                          : Colors.orange.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _formatGoalName(entry.key),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: achieved
                                                  ? Colors.green.shade700
                                                  : Colors.orange.shade700,
                                            ),
                                      ),
                                    ),
                                    if (achieved)
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green.shade600,
                                        size: 20,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Achieved: ${current.toStringAsFixed(1)}${_getGoalUnit(entry.key)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                    Text(
                                      'Target: ${target.toStringAsFixed(1)}${_getGoalUnit(entry.key)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  backgroundColor: Colors.grey.shade300,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    achieved ? Colors.green : Colors.orange,
                                  ),
                                  minHeight: 6,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(progress * 100).toStringAsFixed(1)}% Complete',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: achieved
                                            ? Colors.green.shade600
                                            : Colors.orange.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                      ],

                      // Exercises Summary
                      Text(
                        'Exercises (${exercises.length})',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),

                      ...exercises.take(5).map((exercise) {
                        final exerciseData = exercise as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.fitness_center,
                                color: Colors.grey.shade600,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  exerciseData['name'] as String? ??
                                      'Unknown Exercise',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                '${exerciseData['sets'] ?? 0} sets',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }),

                      if (exercises.length > 5) ...[
                        const SizedBox(height: 8),
                        Text(
                          'And ${exercises.length - 5} more exercises...',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Optionally navigate to create new plan
                            Navigator.of(context).pushNamed('/create_plan');
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Create New Plan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isGraduated ? Colors.green : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatGoalName(String goalType) {
    switch (goalType) {
      case 'painReduction':
        return 'Pain Reduction';
      case 'rangeOfMotion':
        return 'Range of Motion';
      case 'strength':
        return 'Strength Improvement';
      case 'functionalCapacity':
        return 'Functional Capacity';
      default:
        return goalType
            .replaceAllMapped(
              RegExp(r'([A-Z])'),
              (match) => ' ${match.group(1)}',
            )
            .trim();
    }
  }

  IconData _getGoalIcon(String goalType) {
    switch (goalType) {
      case 'painReduction':
        return Icons.healing;
      case 'rangeOfMotion':
        return Icons.rotate_right;
      case 'strength':
        return Icons.fitness_center;
      case 'functionalCapacity':
        return Icons.accessibility_new;
      default:
        return Icons.track_changes;
    }
  }

  String _getGoalUnit(String goalType) {
    switch (goalType) {
      case 'painReduction':
        return '%';
      case 'rangeOfMotion':
        return '°';
      case 'strength':
        return '%';
      case 'functionalCapacity':
        return '%';
      default:
        return '';
    }
  }
}
