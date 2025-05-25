import 'package:flutter/material.dart';
import 'package:personalized_rehabilitation_plans/models/rehabilitation_models.dart';
import 'package:personalized_rehabilitation_plans/screens/exercise_recommendation_screen.dart';
import 'package:personalized_rehabilitation_plans/services/rehabilitation_service.dart';
import 'package:personalized_rehabilitation_plans/widgets/enhanced_dropdown.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';

class UserInputScreen extends StatefulWidget {
  const UserInputScreen({super.key});

  @override
  State<UserInputScreen> createState() => _UserInputScreenState();
}

class _UserInputScreenState extends State<UserInputScreen> {
  final _formKey = GlobalKey<FormState>();

  // Medical History Fields
  String _selectedPreviousInjury = 'None';
  String _otherPreviousInjury = '';
  String _selectedSurgicalHistory = 'None';
  String _otherSurgicalHistory = '';

  // Physical Condition Fields
  String _selectedBodyPart = 'Knee';
  String _otherBodyPart = '';
  final _painLevelController = TextEditingController(text: '5');
  String _selectedPainLocation = 'Joint';
  String _otherPainLocation = '';

  // Rehabilitation Goals
  final List<String> _selectedGoals = [];
  final _otherGoalController = TextEditingController();

  bool _isLoading = false;
  int _currentStep = 0;

  // Dropdown options
  final List<String> _previousInjuries = [
    'None',
    'Sprain',
    'Strain',
    'Fracture',
    'Dislocation',
    'Tear (Ligament/Muscle)',
    'Tendonitis',
    'Bursitis',
    'Arthritis',
    'Other',
  ];

  final List<String> _surgicalHistories = [
    'None',
    'ACL Reconstruction',
    'Meniscus Repair',
    'Rotator Cuff Repair',
    'Shoulder Arthroscopy',
    'Hip Replacement',
    'Knee Replacement',
    'Spinal Fusion',
    'Carpal Tunnel Release',
    'Other',
  ];

  final List<String> _bodyParts = [
    'Knee',
    'Shoulder',
    'Ankle',
    'Wrist',
    'Elbow',
    'Hip',
    'Back',
    'Neck',
  ];

  final List<String> _painLocations = [
    'Joint',
    'Muscle',
    'Tendon',
    'Ligament',
  ];

  final List<String> _rehabilitationGoals = [
    'Pain reduction',
    'Improve range of motion',
    'Increase strength',
    'Return to sports',
    'Improve daily function',
    'Prevent re-injury',
    'Post-surgery recovery',
  ];

  @override
  void dispose() {
    _painLevelController.dispose();
    _otherGoalController.dispose();
    super.dispose();
  }

  Widget _buildMedicalHistoryForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundStart.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
          ),
          child: const Text(
            'Please provide information about your medical history to help us create a personalized rehabilitation plan.',
            style: TextStyle(
              color: Color(0xFF2C3E50),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Previous Injuries Dropdown
        EnhancedDropdown(
          label: 'Previous Injuries',
          items: _previousInjuries,
          value: _selectedPreviousInjury,
          onChanged: (value) {
            setState(() {
              _selectedPreviousInjury = value;
            });
          },
          otherValue: _otherPreviousInjury,
          onOtherChanged: (value) {
            setState(() {
              _otherPreviousInjury = value;
            });
          },
          otherHintText: 'Describe your injury',
        ),
        const SizedBox(height: 20),

        // Surgical History Dropdown
        EnhancedDropdown(
          label: 'Surgical History',
          items: _surgicalHistories,
          value: _selectedSurgicalHistory,
          onChanged: (value) {
            setState(() {
              _selectedSurgicalHistory = value;
            });
          },
          otherValue: _otherSurgicalHistory,
          onOtherChanged: (value) {
            setState(() {
              _otherSurgicalHistory = value;
            });
          },
          otherHintText: 'Describe your surgery',
        ),
      ],
    );
  }

  Widget _buildPhysicalConditionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundStart.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
          ),
          child: const Text(
            'Tell us about your current physical condition and limitations.',
            style: TextStyle(
              color: Color(0xFF2C3E50),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Body Part with Enhanced Dropdown
        EnhancedDropdown(
          label: 'Affected Body Part',
          items: _bodyParts,
          value: _selectedBodyPart,
          onChanged: (value) {
            setState(() {
              _selectedBodyPart = value;
            });
          },
          otherValue: _otherBodyPart,
          onOtherChanged: (value) {
            setState(() {
              _otherBodyPart = value;
            });
          },
          otherHintText: 'Specify the affected body part',
          isRequired: true,
        ),
        const SizedBox(height: 20),

        // Pain Level
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pain Level (0-10)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildPainLevelIndicator(0, 'No Pain'),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        thumbColor: _getPainLevelColor(
                            int.tryParse(_painLevelController.text) ?? 5),
                        activeTrackColor: _getPainLevelColor(
                                int.tryParse(_painLevelController.text) ?? 5)
                            .withOpacity(0.7),
                        inactiveTrackColor: Colors.grey.shade200,
                        trackHeight: 6,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: Slider(
                        value:
                            double.tryParse(_painLevelController.text) ?? 5.0,
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: _painLevelController.text,
                        onChanged: (value) {
                          setState(() {
                            // FIXED: Store as integer string to ensure proper parsing
                            _painLevelController.text =
                                value.round().toString();
                          });
                        },
                      ),
                    ),
                  ),
                  _buildPainLevelIndicator(10, 'Extreme'),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getPainLevelColor(
                            int.tryParse(_painLevelController.text) ?? 5)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Current Level: ${_painLevelController.text}',
                        style: TextStyle(
                          color: _getPainLevelColor(
                              int.tryParse(_painLevelController.text) ?? 5),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getPainLevelDescription(
                            int.tryParse(_painLevelController.text) ?? 5),
                        style: TextStyle(
                          color: _getPainLevelColor(
                              int.tryParse(_painLevelController.text) ?? 5),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Pain Location with Enhanced Dropdown
        EnhancedDropdown(
          label: 'Pain Location',
          items: _painLocations,
          value: _selectedPainLocation,
          onChanged: (value) {
            setState(() {
              _selectedPainLocation = value;
            });
          },
          otherValue: _otherPainLocation,
          onOtherChanged: (value) {
            setState(() {
              _otherPainLocation = value;
            });
          },
          otherHintText: 'Specify the pain location',
        ),
      ],
    );
  }

  Widget _buildPainLevelIndicator(int level, String label) {
    return Column(
      children: [
        Text(
          level.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: level == 0
                ? Colors.green
                : (level == 10 ? Colors.red : Colors.grey.shade700),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildRehabilitationGoalsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundStart.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
          ),
          child: const Text(
            'What goals do you want to achieve through rehabilitation?',
            style: TextStyle(
              color: Color(0xFF2C3E50),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Rehabilitation Goals Checkboxes
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select all that apply:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(_rehabilitationGoals.length, (index) {
                final goal = _rehabilitationGoals[index];
                return Theme(
                  data: Theme.of(context).copyWith(
                    checkboxTheme: CheckboxThemeData(
                      fillColor:
                          WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppTheme.primaryBlue;
                        }
                        return Colors.grey.shade400;
                      }),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  child: CheckboxListTile(
                    title: Text(goal),
                    value: _selectedGoals.contains(goal),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          if (!_selectedGoals.contains(goal)) {
                            _selectedGoals.add(goal);
                          }
                        } else {
                          _selectedGoals.remove(goal);
                        }
                      });
                    },
                    activeColor: AppTheme.primaryBlue,
                    checkColor: Colors.white,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                );
              }),

              // "Other" option for goals
              Theme(
                data: Theme.of(context).copyWith(
                  checkboxTheme: CheckboxThemeData(
                    fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppTheme.primaryBlue;
                      }
                      return Colors.grey.shade400;
                    }),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                child: CheckboxListTile(
                  title: const Text('Other'),
                  value: _selectedGoals.contains('Other'),
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        if (!_selectedGoals.contains('Other')) {
                          _selectedGoals.add('Other');
                        }
                      } else {
                        _selectedGoals.remove('Other');
                      }
                    });
                  },
                  activeColor: AppTheme.primaryBlue,
                  checkColor: Colors.white,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              // Other Goal Text Field (shown only if 'Other' is selected)
              if (_selectedGoals.contains('Other'))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 32.0),
                  child: TextFormField(
                    controller: _otherGoalController,
                    decoration: InputDecoration(
                      labelText: 'Specify Other Goal',
                      hintText: 'Enter your goal',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: AppTheme.primaryBlue.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: AppTheme.primaryBlue.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppTheme.primaryBlue, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (_selectedGoals.contains('Other') &&
                          (value == null || value.isEmpty)) {
                        return 'Please specify your other goal';
                      }
                      return null;
                    },
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundEnd.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppTheme.primaryBlue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This information will be used to create your personalized rehabilitation plan.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getPainLevelDescription(int level) {
    if (level <= 2) {
      return 'Mild pain';
    } else if (level <= 5) {
      return 'Moderate pain';
    } else if (level <= 7) {
      return 'Severe pain';
    } else {
      return 'Very severe pain';
    }
  }

  Color _getPainLevelColor(int level) {
    if (level <= 2) {
      return Colors.green;
    } else if (level <= 5) {
      return Colors.orange;
    } else if (level <= 7) {
      return Colors.deepOrange;
    } else {
      return Colors.red;
    }
  }

  void _nextStep() {
    setState(() {
      _currentStep < 2 ? _currentStep += 1 : null;
    });
  }

  void _previousStep() {
    setState(() {
      _currentStep > 0 ? _currentStep -= 1 : null;
    });
  }

  StepState _getStepState(int step) {
    if (_currentStep > step) {
      return StepState.complete;
    } else if (_currentStep == step) {
      return StepState.editing;
    } else {
      return StepState.indexed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFDFF),
      appBar: AppBar(
        title: const Text('Create Your Rehab Plan'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryBlue,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppTheme.primaryBlue,
                onSurface: Color(0xFF2C3E50),
                secondary: AppTheme.vibrantRed,
              ),
            ),
            child: Stepper(
              type: StepperType.vertical,
              currentStep: _currentStep,
              elevation: 0,
              margin: EdgeInsets.zero,
              onStepContinue: () {
                if (_currentStep < 2) {
                  _nextStep();
                } else {
                  _generateRehabilitationPlan();
                }
              },
              onStepCancel: _previousStep,
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading && _currentStep == 2
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  _currentStep < 2
                                      ? 'Continue'
                                      : 'Generate Plan',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: details.onStepCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryBlue,
                              side:
                                  const BorderSide(color: AppTheme.primaryBlue),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              steps: [
                // Step 1: Medical History
                Step(
                  title: const Text('Medical History'),
                  subtitle:
                      const Text('Previous injuries and medical conditions'),
                  content: _buildMedicalHistoryForm(),
                  isActive: _currentStep >= 0,
                  state: _getStepState(0),
                ),

                // Step 2: Physical Condition
                Step(
                  title: const Text('Physical Condition'),
                  subtitle: const Text('Current condition and limitations'),
                  content: _buildPhysicalConditionForm(),
                  isActive: _currentStep >= 1,
                  state: _getStepState(1),
                ),

                // Step 3: Rehabilitation Goals
                Step(
                  title: const Text('Rehabilitation Goals'),
                  subtitle: const Text('What you want to achieve'),
                  content: _buildRehabilitationGoalsForm(),
                  isActive: _currentStep >= 2,
                  state: _getStepState(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateRehabilitationPlan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare medical history data
      final String previousInjury = _selectedPreviousInjury == 'Other'
          ? _otherPreviousInjury
          : _selectedPreviousInjury;

      final String surgicalHistory = _selectedSurgicalHistory == 'Other'
          ? _otherSurgicalHistory
          : _selectedSurgicalHistory;

      final medicalHistory = {
        'previousInjuries': previousInjury,
        'surgicalHistory': surgicalHistory,
      };

      // Prepare physical condition data - FIXED: Ensure pain level is integer
      final String bodyPart =
          _selectedBodyPart == 'Other' ? _otherBodyPart : _selectedBodyPart;

      final String painLocation = _selectedPainLocation == 'Other'
          ? _otherPainLocation
          : _selectedPainLocation;

      // FIX: Parse pain level as integer and ensure it's within valid range
      int painLevelInt;
      try {
        painLevelInt = int.parse(_painLevelController.text.trim());
        // Ensure pain level is within 0-10 range
        painLevelInt = painLevelInt.clamp(0, 10);
      } catch (e) {
        // Default to 5 if parsing fails
        painLevelInt = 5;
        print('Error parsing pain level: $e, defaulting to 5');
      }

      final physicalCondition = {
        'bodyPart': bodyPart,
        'painLevel': painLevelInt, // Now properly as integer
        'painLocation': painLocation,
      };

      // Prepare rehabilitation goals
      List<String> goals = List.from(_selectedGoals);
      if (_selectedGoals.contains('Other') &&
          _otherGoalController.text.isNotEmpty) {
        goals.remove('Other');
        goals.add(_otherGoalController.text.trim());
      }

      // Create rehabilitation data
      final rehabData = RehabilitationData(
        medicalHistory: medicalHistory,
        physicalCondition: physicalCondition,
        rehabilitationGoals: goals,
      );

      // Debug: Print the data being sent to backend
      print('Sending rehabilitation data to backend:');
      print(
          'Pain Level: ${physicalCondition['painLevel']} (${physicalCondition['painLevel'].runtimeType})');
      print('Body Part: ${physicalCondition['bodyPart']}');
      print('Goals: $goals');

      // Generate a plan
      final service = RehabilitationService();
      final plan = await service.generatePlan(rehabData);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExerciseRecommendationScreen(plan: plan),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating plan: ${e.toString()}'),
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
}
