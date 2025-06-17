import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart'; // Fixed import
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/widgets/custom_button.dart';
import 'package:intl/intl.dart';

class EditRehabilitationPlanScreen extends StatefulWidget {
  final String planId;
  final String patientId;
  final String patientName;

  const EditRehabilitationPlanScreen({
    super.key,
    required this.planId,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<EditRehabilitationPlanScreen> createState() =>
      _EditRehabilitationPlanScreenState();
}

class _EditRehabilitationPlanScreenState
    extends State<EditRehabilitationPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late DateTime _startDate;
  DateTime? _endDate;
  String _selectedBodyPart = 'Knee';
  List<Exercise> _exercises = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDynamicallyAdjusted = true;
  Map<String, dynamic> _goals = {};
  String _planStatus = 'active';

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
    _loadPlanData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadPlanData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fixed: Use correct collection path
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .collection('rehabilitation_plans')
          .doc(widget.planId)
          .get();

      if (doc.exists && doc.data() != null) {
        final plan = RehabilitationPlan.fromJson(doc.data()!);

        setState(() {
          _titleController.text = plan.title;
          _descriptionController.text = plan.description;
          _exercises = List.from(plan.exercises);
          _goals = Map.from(plan.goals);
          _startDate = plan.startDate ?? DateTime.now();
          _planStatus = plan.status ?? 'active';

          // Get body part from goals
          if (_goals.containsKey('bodyPart')) {
            _selectedBodyPart = _goals['bodyPart'];
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plan not found'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
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
      builder: (context) => _buildExerciseDialog(),
    );
  }

  void _editExercise(int index) {
    showDialog(
      context: context,
      builder: (context) =>
          _buildExerciseDialog(exercise: _exercises[index], index: index),
    );
  }

  Widget _buildExerciseDialog({Exercise? exercise, int? index}) {
    final isEditing = exercise != null;
    final nameController = TextEditingController(text: exercise?.name ?? '');
    final descriptionController =
        TextEditingController(text: exercise?.description ?? '');
    final setsController =
        TextEditingController(text: exercise?.sets.toString() ?? '3');
    final repsController =
        TextEditingController(text: exercise?.reps.toString() ?? '10');
    final durationController = TextEditingController(
        text: exercise?.durationSeconds.toString() ?? '30');
    String selectedDifficulty = exercise?.difficultyLevel ?? 'beginner';

    return AlertDialog(
      title: Text(isEditing ? 'Edit Exercise' : 'Add Exercise'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Exercise Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsController,
                    decoration: const InputDecoration(
                      labelText: 'Sets',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: repsController,
                    decoration: const InputDecoration(
                      labelText: 'Reps',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: durationController,
              decoration: const InputDecoration(
                labelText: 'Duration (seconds)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedDifficulty,
              decoration: const InputDecoration(
                labelText: 'Difficulty Level',
                border: OutlineInputBorder(),
              ),
              items: ['beginner', 'intermediate', 'advanced'].map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(level.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedDifficulty = value;
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
          onPressed: () {
            if (nameController.text.isNotEmpty) {
              final newExercise = Exercise(
                id: exercise?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text,
                description: descriptionController.text,
                bodyPart: _selectedBodyPart,
                sets: int.tryParse(setsController.text) ?? 3,
                reps: int.tryParse(repsController.text) ?? 10,
                durationSeconds: int.tryParse(durationController.text) ?? 30,
                difficultyLevel: selectedDifficulty,
                isCompleted: exercise?.isCompleted ?? false,
              );

              setState(() {
                if (isEditing && index != null) {
                  _exercises[index] = newExercise;
                } else {
                  _exercises.add(newExercise);
                }
              });
              Navigator.pop(context);
            }
          },
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
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
      builder: (context) => AlertDialog(
        title: const Text('Edit Goals'),
        content:
            const Text('Goals editing functionality can be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;

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
      _isSaving = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      final updatedPlan = RehabilitationPlan(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        exercises: _exercises,
        goals: _goals.isEmpty ? {'bodyPart': _selectedBodyPart} : _goals,
        startDate: _startDate,
        lastUpdated: DateTime.now(),
        status: _planStatus,
        userId: widget.patientId,
        therapistId: authService.currentUser!.uid,
      );

      // Fixed: Save to correct collection path
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .collection('rehabilitation_plans')
          .doc(widget.planId)
          .update(updatedPlan.toJson());

      // Log the update activity
      await FirebaseFirestore.instance.collection('progress_logs').add({
        'userId': widget.patientId,
        'therapistId': authService.currentUser!.uid,
        'date': FieldValue.serverTimestamp(),
        'type': 'plan_updated',
        'planId': widget.planId,
        'planTitle': updatedPlan.title,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rehabilitation plan updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deletePlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: const Text(
            'Are you sure you want to delete this rehabilitation plan? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.patientId)
            .collection('rehabilitation_plans')
            .doc(widget.planId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plan deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting plan: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Edit Plan for ${widget.patientName}'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Plan for ${widget.patientName}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deletePlan,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Plan Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a plan title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Plan Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Plan Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a plan description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Body Part Selection
              DropdownButtonFormField<String>(
                value: _selectedBodyPart,
                decoration: const InputDecoration(
                  labelText: 'Target Body Part',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.accessibility),
                ),
                items: _bodyParts.map((part) {
                  return DropdownMenuItem(
                    value: part,
                    child: Text(part),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedBodyPart = value;
                      _goals['bodyPart'] = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Dates Section
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectStartDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM dd, yyyy').format(_startDate),
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectEndDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.event),
                        ),
                        child: Text(
                          _endDate != null
                              ? DateFormat('MMM dd, yyyy').format(_endDate!)
                              : 'Not set',
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Plan Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_important),
                ),
                value: _planStatus,
                items: ['active', 'paused', 'completed'].map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _planStatus = value;
                    });
                  }
                },
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Goals'),
                    onPressed: _showGoalsDialog,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Exercises Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Exercises',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Exercise'),
                    onPressed: _addNewExercise,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Exercises List
              if (_exercises.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(Icons.fitness_center,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        const Text('No exercises added yet'),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Exercise'),
                          onPressed: _addNewExercise,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = _exercises[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        leading: const Icon(Icons.fitness_center),
                        title: Text(exercise.name),
                        subtitle: Text(
                          '${exercise.sets} sets × ${exercise.reps} reps (${exercise.durationSeconds}s)',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editExercise(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeExercise(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _isSaving ? 'Updating Plan...' : 'Update Plan',
                  icon: _isSaving ? null : Icons.save,
                  onPressed: _isSaving ? null : _savePlan,
                  backgroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
