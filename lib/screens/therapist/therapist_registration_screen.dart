import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/screens/bottom_bar/bottom_bar.dart';
import 'package:personalized_rehabilitation_plans/theme/app_theme.dart';

class TherapistRegistrationScreen extends StatefulWidget {
  final String userId;

  const TherapistRegistrationScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<TherapistRegistrationScreen> createState() =>
      _TherapistRegistrationScreenState();
}

class _TherapistRegistrationScreenState
    extends State<TherapistRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenseNumberController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _yearsOfExperienceController = TextEditingController();
  final _educationController = TextEditingController();
  final _clinicNameController = TextEditingController();
  final _clinicAddressController = TextEditingController();
  String _selectedSpecialization = 'Physical Therapy';
  bool _isLoading = false;

  final List<String> _specializations = [
    'Physical Therapy',
    'Occupational Therapy',
    'Sports Medicine',
    'Orthopedic Rehabilitation',
    'Neurological Rehabilitation',
    'Pediatric Rehabilitation',
    'Geriatric Rehabilitation',
    'Other'
  ];

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.initializeUser();
    });
    super.initState();
  }

  @override
  void dispose() {
    _licenseNumberController.dispose();
    _specialtyController.dispose();
    _yearsOfExperienceController.dispose();
    _educationController.dispose();
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    super.dispose();
  }

  Future<void> _submitTherapistProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Prepare therapist profile data
      final therapistProfileData = {
        'licenseNumber': _licenseNumberController.text.trim(),
        'specialty': _specialtyController.text.trim(),
        'yearsOfExperience':
            int.tryParse(_yearsOfExperienceController.text.trim()) ?? 0,
        'education': _educationController.text.trim(),
        'clinicName': _clinicNameController.text.trim(),
        'clinicAddress': _clinicAddressController.text.trim(),
        'specialization': _selectedSpecialization,
        'isVerified': false, // Therapists start as unverified
        'verificationSubmittedDate': DateTime.now(),
      };

      // Save therapist profile data
      await authService.saveTherapistProfile(
          widget.userId, therapistProfileData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Therapist profile submitted successfully. Your account will be verified soon.'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to main app
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BottomBarScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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
        title: const Text('Therapist Registration'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryBlue,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundStart,
              AppTheme.backgroundEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Registration Info
                  Text(
                    'Professional Information',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please provide your professional details to complete your therapist profile.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // License Number
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _licenseNumberController,
                            decoration: const InputDecoration(
                              labelText: 'License Number',
                              hintText:
                                  'Enter your professional license number',
                              prefixIcon: Icon(Icons.badge),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your license number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Specialization Dropdown
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Specialization',
                              prefixIcon: Icon(Icons.medical_services_outlined),
                            ),
                            value: _selectedSpecialization,
                            items: _specializations.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedSpecialization = newValue!;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your specialization';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Years of Experience
                          TextFormField(
                            controller: _yearsOfExperienceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Years of Experience',
                              prefixIcon: Icon(Icons.timeline),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your years of experience';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Education/Qualifications
                          TextFormField(
                            controller: _educationController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Education/Qualifications',
                              prefixIcon: Icon(Icons.school),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your education details';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Clinic Information Card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clinic Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _clinicNameController,
                            decoration: const InputDecoration(
                              labelText: 'Clinic/Hospital Name',
                              prefixIcon: Icon(Icons.local_hospital),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your clinic name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _clinicAddressController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Clinic/Hospital Address',
                              prefixIcon: Icon(Icons.location_on),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your clinic address';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitTherapistProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : const Text(
                              'Complete Registration',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
