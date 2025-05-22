import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_plan_model.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/widgets/custom_button.dart';

class CreateRehabilitationPlanScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const CreateRehabilitationPlanScreen({
    Key? key,
    required this.patientId,
    required this.patientName,
  }) : super(key: key);

  @override
  State<CreateRehabilitationPlanScreen> createState() =>
      _CreateRehabilitationPlanScreenState();
}

class _CreateRehabilitationPlanScreenState
    extends State<CreateRehabilitationPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late DateTime _startDate;
  DateTime? _endDate;
  String _selectedBodyPart = 'Knee';
  final List<Exercise> _exercises = [];
  bool _isLoading = false;
  bool _isDynamicallyAdjusted = true;
  Map<String, dynamic> _goals = {};

  // Available body parts for selection
  final List<String> _bodyParts = [
    'Knee',
    'Shoulder',
    'Ankle',
    'Wrist',
    'Elbow',
    'Hip',
    'Back',
    'Neck',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();

    // Initialize with a template exercise for the selected body part
    _addTemplateExercises();
  }

  void _addTemplateExercises() {
    setState(() {
      _exercises.clear();

      // Add 3 template exercises based on the selected body part
      switch (_selectedBodyPart.toLowerCase()) {
        case 'knee':
          _exercises.addAll([
            Exercise(
              id: DateTime.now().millisecondsSinceEpoch.toString() + '1',
              name: 'Straight Leg Raises',
              description:
                  'Lie flat on your back with one leg bent and the other straight. Tighten the thigh muscle of the straight leg and slowly raise it to the height of the bent knee.',
              bodyPart: 'Knee',
              sets: 3,
              reps: 10,
              durationSeconds: 30,
              difficultyLevel: 'beginner',
            ),
            Exercise(
              id: DateTime.now().millisecondsSinceEpoch.toString() + '2',
              name: 'Hamstring Curls',
              description:
                  'Stand facing a wall or sturdy object for balance. Bend your affected knee, bringing your heel toward your buttocks. Hold, then lower slowly.',
              bodyPart: 'Knee',
              sets: 3,
              reps: 10,
              durationSeconds: 45,
              difficultyLevel: 'beginner',
            ),
            Exercise(
              id: DateTime.now().millisecondsSinceEpoch.toString() + '3',
              name: 'Wall Squats',
              description:
                  'Stand with your back against a wall, feet shoulder-width apart. Slide down the wall until your knees are bent at about 45 degrees. Hold, then slide back up.',
              bodyPart: 'Knee',
              sets: 2,
              reps: 8,
              durationSeconds: 60,
              difficultyLevel: 'beginner',
            ),
          ]);
          break;

        case 'shoulder':
          _exercises.addAll([
            Exercise(
              id: DateTime.now().millisecondsSinceEpoch.toString() + '1',
              name: 'Pendulum Exercise',
              description:
                  'Lean forward slightly with support, allowing your affected arm to hang down. Swing your arm gently in small circles, then in larger circles. Repeat in the opposite direction.',
              bodyPart: 'Shoulder',
              sets: 2,
              reps: 10,
              durationSeconds: 30,
              difficultyLevel: 'beginner',
            ),
            Exercise(
              id: DateTime.now().millisecondsSinceEpoch.toString() + '2',
              name: 'Wall Crawl',
              description:
                  'Stand facing a wall with your affected arm. Walk your fingers up the wall as high as comfortable. Slowly lower back down.',
              bodyPart: 'Shoulder',
              sets: 3,
              reps: 10,
              durationSeconds: 45,
              difficultyLevel: 'beginner',
            ),
            Exercise(
              id: DateTime.now().millisecondsSinceEpoch.toString() + '3',
              name: 'External Rotation',
              description:
                  'Holding a light resistance band, keep your elbow at 90 degrees and close to your side. Rotate your forearm outward, away from your body.',
              bodyPart: 'Shoulder',
              sets: 3,
              reps: 10,
              durationSeconds: 60,
              difficultyLevel: 'intermediate',
            ),
          ]);
          break;

        // Add more cases for other body parts

        default:
          // Default template for any other body part
          _exercises.add(
            Exercise(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: 'Basic Range of Motion',
              description:
                  'Perform gentle range of motion exercises for the affected area.',
              bodyPart: _selectedBodyPart,
              sets: 3,
              reps: 10,
              durationSeconds: 30,
              difficultyLevel: 'beginner',
            ),
          );
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;

        // Reset end date if it's before new start date
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: _startDate.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _addNewExercise() {
    showDialog(
      context: context,
      builder: (context) => ExerciseFormDialog(
        bodyPart: _selectedBodyPart,
        onSave: (exercise) {
          setState(() {
            _exercises.add(exercise);
          });
        },
      ),
    );
  }

  void _editExercise(int index) {
    showDialog(
      context: context,
      builder: (context) => ExerciseFormDialog(
        bodyPart: _selectedBodyPart,
        exercise: _exercises[index],
        onSave: (exercise) {
          setState(() {
            _exercises[index] = exercise;
          });
        },
      ),
    );
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  void _showGoalsDialog() {
    showDialog(
      context: context,
      builder: (context) => GoalsFormDialog(
        initialGoals: _goals,
        selectedBodyPart: _selectedBodyPart,
        onSave: (goals) {
          setState(() {
            _goals = goals;
          });
        },
      ),
    );
  }

  Future<void> _createPlan() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if we have at least one exercise
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one exercise to the plan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Create the plan model
      final plan = RehabilitationPlanModel(
        id: '', // This will be set by Firestore
        userId: widget.patientId,
        therapistId: authService.currentUser!.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        exercises: _exercises,
        startDate: _startDate,
        endDate: _endDate,
        status: 'active',
        goals: _goals.isEmpty ? {'bodyPart': _selectedBodyPart} : _goals,
        lastUpdated: DateTime.now(),
        isDynamicallyAdjusted: _isDynamicallyAdjusted,
      );

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('rehabilitation_plans')
          .add(plan.toMap());

      // Log the creation activity
      await FirebaseFirestore.instance.collection('progress_logs').add({
        'userId': widget.patientId,
        'therapistId': authService.currentUser!.uid,
        'date': FieldValue.serverTimestamp(),
        'type': 'plan_created',
        'planId': docRef.id,
        'planTitle': plan.title,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rehabilitation plan created successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Plan for ${widget.patientName}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan Details Section
              const Text(
                'Plan Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Plan Title',
                  hintText: 'E.g., Knee Rehabilitation Plan',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title for the plan';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe the purpose and goals of this plan',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Body Part Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Target Body Part',
                  prefixIcon: Icon(Icons.accessibility_new),
                ),
                value: _selectedBodyPart,
                items: _bodyParts.map((bodyPart) {
                  return DropdownMenuItem(
                    value: bodyPart,
                    child: Text(bodyPart),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && value != _selectedBodyPart) {
                    setState(() {
                      _selectedBodyPart = value;

                      // Update goals with new body part
                      if (_goals.isNotEmpty) {
                        _goals['bodyPart'] = value;
                      } else {
                        _goals = {'bodyPart': value};
                      }

                      // Add template exercises for the new body part
                      _addTemplateExercises();
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a body part';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dates Row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectStartDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _formatDate(_startDate),
                          style: TextStyle(
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectEndDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Date (Optional)',
                          prefixIcon: Icon(Icons.event),
                        ),
                        child: Text(
                          _endDate != null ? _formatDate(_endDate!) : 'Not set',
                          style: TextStyle(
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dynamic Adjustment Switch
              SwitchListTile(
                title: const Text('Dynamic Plan Adjustment'),
                subtitle: const Text(
                    'Automatically adjust plan based on patient progress'),
                value: _isDynamicallyAdjusted,
                activeColor: Theme.of(context).primaryColor,
                onChanged: (value) {
                  setState(() {
                    _isDynamicallyAdjusted = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Goals Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rehabilitation Goals',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Goals'),
                    onPressed: _showGoalsDialog,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Goals Display
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _goals.isEmpty
                      ? const Text(
                          'No specific goals set. Tap "Edit Goals" to add.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _goals.entries.map((entry) {
                            // Skip the bodyPart entry as it's already shown elsewhere
                            if (entry.key == 'bodyPart')
                              return const SizedBox.shrink();

                            String label = entry.key.replaceAll('_', ' ');
                            label = label[0].toUpperCase() + label.substring(1);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      size: 16, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$label: ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry.value.toString(),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Exercises Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Exercises',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Exercise'),
                    onPressed: _addNewExercise,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Exercises List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exercises.length,
                itemBuilder: (context, index) {
                  final exercise = _exercises[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Text(
                          (index + 1).toString(),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(exercise.name),
                      subtitle: Text(
                        '${exercise.sets} sets × ${exercise.reps} reps • ${_formatDifficulty(exercise.difficultyLevel)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Instructions:',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Text(exercise.description),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildExerciseDetail(
                                            'Sets', exercise.sets.toString()),
                                        _buildExerciseDetail(
                                            'Reps', exercise.reps.toString()),
                                        _buildExerciseDetail('Duration',
                                            '${exercise.durationSeconds} sec'),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildExerciseDetail(
                                            'Body Part', exercise.bodyPart),
                                        _buildExerciseDetail(
                                            'Difficulty',
                                            _formatDifficulty(
                                                exercise.difficultyLevel)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Edit'),
                                    onPressed: () => _editExercise(index),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete,
                                        size: 16, color: Colors.red),
                                    label: const Text('Remove',
                                        style: TextStyle(color: Colors.red)),
                                    onPressed: () => _removeExercise(index),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Submit Button
              CustomButton(
                text: 'Create Rehabilitation Plan',
                onPressed: _createPlan,
                isLoading: _isLoading,
                width: double.infinity,
                height: 50,
                icon: Icons.check_circle,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDifficulty(String difficulty) {
    return difficulty.substring(0, 1).toUpperCase() + difficulty.substring(1);
  }
}

// Dialog for adding/editing exercises
class ExerciseFormDialog extends StatefulWidget {
  final String bodyPart;
  final Exercise? exercise;
  final Function(Exercise) onSave;

  const ExerciseFormDialog({
    Key? key,
    required this.bodyPart,
    this.exercise,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ExerciseFormDialog> createState() => _ExerciseFormDialogState();
}

class _ExerciseFormDialogState extends State<ExerciseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _sets = 3;
  int _reps = 10;
  int _durationSeconds = 30;
  String _difficultyLevel = 'beginner';

  final List<String> _difficultyLevels = [
    'beginner',
    'intermediate',
    'advanced'
  ];

  @override
  void initState() {
    super.initState();

    if (widget.exercise != null) {
      // Editing existing exercise
      _nameController.text = widget.exercise!.name;
      _descriptionController.text = widget.exercise!.description;
      _sets = widget.exercise!.sets;
      _reps = widget.exercise!.reps;
      _durationSeconds = widget.exercise!.durationSeconds;
      _difficultyLevel = widget.exercise!.difficultyLevel;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveExercise() {
    if (!_formKey.currentState!.validate()) return;

    final exercise = Exercise(
      id: widget.exercise?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      bodyPart: widget.bodyPart,
      sets: _sets,
      reps: _reps,
      durationSeconds: _durationSeconds,
      difficultyLevel: _difficultyLevel,
    );

    widget.onSave(exercise);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.exercise != null ? 'Edit Exercise' : 'Add New Exercise'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Exercise Name',
                  hintText: 'E.g., Knee Extension',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter exercise name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText:
                      'Provide detailed instructions for performing this exercise',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter exercise instructions';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sets:'),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _sets > 1
                                  ? () => setState(() => _sets--)
                                  : null,
                            ),
                            Text(
                              _sets.toString(),
                              style: const TextStyle(fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setState(() => _sets++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reps:'),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _reps > 1
                                  ? () => setState(() => _reps--)
                                  : null,
                            ),
                            Text(
                              _reps.toString(),
                              style: const TextStyle(fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setState(() => _reps++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Duration (seconds):'),
              Slider(
                min: 5,
                max: 120,
                divisions: 23,
                value: _durationSeconds.toDouble(),
                label: _durationSeconds.toString(),
                onChanged: (value) {
                  setState(() {
                    _durationSeconds = value.round();
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('Difficulty Level:'),
              DropdownButtonFormField<String>(
                value: _difficultyLevel,
                items: _difficultyLevels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(_formatDifficulty(level)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _difficultyLevel = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveExercise,
          child: Text(widget.exercise != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  String _formatDifficulty(String difficulty) {
    return difficulty.substring(0, 1).toUpperCase() + difficulty.substring(1);
  }
}

// Dialog for setting rehabilitation goals
class GoalsFormDialog extends StatefulWidget {
  final Map<String, dynamic> initialGoals;
  final String selectedBodyPart;
  final Function(Map<String, dynamic>) onSave;

  const GoalsFormDialog({
    Key? key,
    required this.initialGoals,
    required this.selectedBodyPart,
    required this.onSave,
  }) : super(key: key);

  @override
  State<GoalsFormDialog> createState() => _GoalsFormDialogState();
}

class _GoalsFormDialogState extends State<GoalsFormDialog> {
  late Map<String, dynamic> _goals;
  String _painReduction = 'medium';
  final _primaryGoalController = TextEditingController();
  final _rangeOfMotionController = TextEditingController();
  final _strengthController = TextEditingController();
  bool _includeRangeOfMotion = false;
  bool _includeStrength = false;
  bool _includeReturnToSport = false;
  String _expectedTimeframe = '4-6 weeks';

  final List<String> _painReductionLevels = ['low', 'medium', 'high'];
  final List<String> _timeframes = [
    '1-2 weeks',
    '2-4 weeks',
    '4-6 weeks',
    '6-8 weeks',
    '8-12 weeks',
    '3-6 months'
  ];

  @override
  void initState() {
    super.initState();

    // Initialize with existing goals if any
    _goals = Map<String, dynamic>.from(widget.initialGoals);

    // Always include the body part
    if (!_goals.containsKey('bodyPart')) {
      _goals['bodyPart'] = widget.selectedBodyPart;
    }

    // Set up the form with existing values
    if (_goals.containsKey('painReduction')) {
      _painReduction = _goals['painReduction'];
    }

    if (_goals.containsKey('primary')) {
      _primaryGoalController.text = _goals['primary'];
    }

    if (_goals.containsKey('rangeOfMotion')) {
      _includeRangeOfMotion = true;
      _rangeOfMotionController.text = _goals['rangeOfMotion'];
    }

    if (_goals.containsKey('strength')) {
      _includeStrength = true;
      _strengthController.text = _goals['strength'];
    }

    if (_goals.containsKey('returnToSport')) {
      _includeReturnToSport = true;
    }

    if (_goals.containsKey('timeframe')) {
      _expectedTimeframe = _goals['timeframe'];
    }
  }

  @override
  void dispose() {
    _primaryGoalController.dispose();
    _rangeOfMotionController.dispose();
    _strengthController.dispose();
    super.dispose();
  }

  void _saveGoals() {
    // Always update the body part
    _goals['bodyPart'] = widget.selectedBodyPart;

    // Set pain reduction level
    _goals['painReduction'] = _painReduction;

    // Primary goal
    if (_primaryGoalController.text.isNotEmpty) {
      _goals['primary'] = _primaryGoalController.text.trim();
    } else {
      _goals.remove('primary');
    }

    // Range of motion goal
    if (_includeRangeOfMotion && _rangeOfMotionController.text.isNotEmpty) {
      _goals['rangeOfMotion'] = _rangeOfMotionController.text.trim();
    } else {
      _goals.remove('rangeOfMotion');
    }

    // Strength goal
    if (_includeStrength && _strengthController.text.isNotEmpty) {
      _goals['strength'] = _strengthController.text.trim();
    } else {
      _goals.remove('strength');
    }

    // Return to sport goal
    if (_includeReturnToSport) {
      _goals['returnToSport'] = true;
    } else {
      _goals.remove('returnToSport');
    }

    // Timeframe
    _goals['timeframe'] = _expectedTimeframe;

    widget.onSave(_goals);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Rehabilitation Goals'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pain Reduction Priority:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            DropdownButtonFormField<String>(
              value: _painReduction,
              items: _painReductionLevels.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(
                      level.substring(0, 1).toUpperCase() + level.substring(1)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _painReduction = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _primaryGoalController,
              decoration: const InputDecoration(
                labelText: 'Primary Goal',
                hintText: 'E.g., Return to daily activities without pain',
              ),
            ),
            const SizedBox(height: 16),

            // Range of Motion Goal
            CheckboxListTile(
              title: const Text('Improve Range of Motion'),
              value: _includeRangeOfMotion,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setState(() {
                  _includeRangeOfMotion = value ?? false;
                });
              },
            ),
            if (_includeRangeOfMotion)
              TextFormField(
                controller: _rangeOfMotionController,
                decoration: const InputDecoration(
                  labelText: 'Range of Motion Goal',
                  hintText: 'E.g., Achieve 120 degrees of knee flexion',
                ),
              ),

            // Strength Goal
            CheckboxListTile(
              title: const Text('Improve Strength'),
              value: _includeStrength,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setState(() {
                  _includeStrength = value ?? false;
                });
              },
            ),
            if (_includeStrength)
              TextFormField(
                controller: _strengthController,
                decoration: const InputDecoration(
                  labelText: 'Strength Goal',
                  hintText: 'E.g., Regain 90% of pre-injury strength',
                ),
              ),

            // Return to Sport Goal
            CheckboxListTile(
              title: const Text('Return to Sports/Activities'),
              value: _includeReturnToSport,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setState(() {
                  _includeReturnToSport = value ?? false;
                });
              },
            ),

            const SizedBox(height: 16),

            // Expected Timeframe
            const Text(
              'Expected Recovery Timeframe:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            DropdownButtonFormField<String>(
              value: _expectedTimeframe,
              items: _timeframes.map((timeframe) {
                return DropdownMenuItem(
                  value: timeframe,
                  child: Text(timeframe),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _expectedTimeframe = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveGoals,
          child: const Text('Save Goals'),
        ),
      ],
    );
  }
}
