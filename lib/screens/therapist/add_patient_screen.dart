import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/widgets/custom_button.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String? _selectedCondition;
  final _notesController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isAdding = false;

  // List of common conditions for dropdown
  final List<String> _conditions = [
    'Post-Surgical Rehabilitation',
    'Sports Injury',
    'Knee Pain/Injury',
    'Shoulder Pain/Injury',
    'Back Pain',
    'Neck Pain',
    'Joint Replacement',
    'Sprain/Strain',
    'Balance/Gait Disorders',
    'Neurological Condition',
    'Other',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Search for patient by email
  Future<void> _searchPatient() async {
    if (_emailController.text.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchResults = [];
    });

    try {
      // Search for user with the specified email
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        // Check if already a patient of this therapist
        final authService = Provider.of<AuthService>(context, listen: false);
        final patientCheckSnapshot = await FirebaseFirestore.instance
            .collection('therapists')
            .doc(authService.currentUser!.uid)
            .collection('patients')
            .where('email', isEqualTo: _emailController.text.trim())
            .get();

        if (patientCheckSnapshot.docs.isNotEmpty) {
          // Already a patient
          setState(() {
            _searchResults = [
              {
                'id': userSnapshot.docs.first.id,
                'name': userSnapshot.docs.first['name'],
                'email': userSnapshot.docs.first['email'],
                'isAlreadyPatient': true,
              }
            ];
          });
        } else {
          // User found but not already a patient
          setState(() {
            _searchResults = [
              {
                'id': userSnapshot.docs.first.id,
                'name': userSnapshot.docs.first['name'],
                'email': userSnapshot.docs.first['email'],
                'isAlreadyPatient': false,
              }
            ];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching for patient: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // Add patient to therapist's patient list
  Future<void> _addPatient(
      String patientId, String patientName, String patientEmail) async {
    if (_selectedCondition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a condition'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final therapistId = authService.currentUser!.uid;

      // Get therapist details
      final therapistSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(therapistId)
          .get();

      final therapistName =
          therapistSnapshot.data()?['name'] ?? 'Your Therapist';
      final therapistEmail = authService.currentUserModel?.email ?? '';

      print('🔄 Adding patient with therapistId: $therapistId');

      // Create a batch for atomic operations
      final batch = FirebaseFirestore.instance.batch();

      // 1. Add patient to therapist's patients collection
      final therapistPatientRef = FirebaseFirestore.instance
          .collection('therapists')
          .doc(therapistId)
          .collection('patients')
          .doc(patientId);

      batch.set(therapistPatientRef, {
        'id': patientId,
        'name': patientName,
        'email': patientEmail,
        'condition': _selectedCondition,
        'notes': _notesController.text.trim(),
        'dateAdded': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'therapistId': therapistId, // NEW: Add therapistId here too
      });

      // 2. Add therapist to patient's therapists collection
      final patientTherapistRef = FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('therapists')
          .doc(therapistId);

      batch.set(patientTherapistRef, {
        'id': therapistId,
        'name': therapistName,
        'email': therapistEmail,
        'dateAdded': FieldValue.serverTimestamp(),
      });

      // 3. NEW: Update patient's main user document with therapistId
      final patientUserRef =
          FirebaseFirestore.instance.collection('users').doc(patientId);

      batch.update(patientUserRef, {
        'assignedTherapistId':
            therapistId, // NEW: Store therapistId in main user doc
        'assignedTherapistName': therapistName, // NEW: Store therapist name too
        'therapistAssignedAt':
            FieldValue.serverTimestamp(), // NEW: Track when assigned
      });

      // 4. NEW: Create a patient-therapist relationship document for easy querying
      final relationshipRef = FirebaseFirestore.instance
          .collection('patient_therapist_relationships')
          .doc('${patientId}_${therapistId}');

      batch.set(relationshipRef, {
        'patientId': patientId,
        'patientName': patientName,
        'patientEmail': patientEmail,
        'therapistId': therapistId,
        'therapistName': therapistName,
        'therapistEmail': therapistEmail,
        'condition': _selectedCondition,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // 5. Add notification for the patient
      final notificationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('notifications')
          .doc(); // Auto-generate ID

      batch.set(notificationRef, {
        'title': 'New Therapist',
        'message': '$therapistName is now your therapist',
        'type': 'therapist_added',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'therapistId': therapistId, // NEW: Include therapistId in notification
        'therapistName': therapistName, // NEW: Include therapist name
      });

      // 6. NEW: Add entry to therapist's activity log
      final activityRef = FirebaseFirestore.instance
          .collection('therapists')
          .doc(therapistId)
          .collection('activity_log')
          .doc();

      batch.set(activityRef, {
        'action': 'patient_added',
        'patientId': patientId,
        'patientName': patientName,
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'condition': _selectedCondition,
          'notes': _notesController.text.trim(),
        },
      });

      // Execute all operations atomically
      await batch.commit();

      print('✅ Patient added successfully with therapistId: $therapistId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient added successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error adding patient: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding patient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Patient'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'To add a patient, search by their email address',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The patient must already have an account in the system. They will receive a notification that you have been assigned as their therapist.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Patient Search
              Text(
                'Search for Patient',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Email Field with Search Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Patient Email',
                        hintText: 'Enter patient\'s email address',
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    height: 56, // Match TextFormField height
                    child: ElevatedButton(
                      onPressed: _isSearching ? null : _searchPatient,
                      child: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Search'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Search Results
              if (_hasSearched) ...[
                const Divider(),
                Text(
                  'Search Results',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                if (_searchResults.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No user found with this email address',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Make sure the patient has created an account',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  for (var result in _searchResults)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  child: Text(
                                    result['name']
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        result['name'],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        result['email'],
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
                            const SizedBox(height: 16),
                            if (result['isAlreadyPatient'])
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber,
                                        color: Colors.orange),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'This patient is already assigned to you',
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              // Patient details form
                              const Text(
                                'Patient Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Condition Dropdown
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Primary Condition',
                                  prefixIcon: Icon(Icons.medical_services),
                                ),
                                value: _selectedCondition,
                                items: _conditions.map((condition) {
                                  return DropdownMenuItem(
                                    value: condition,
                                    child: Text(condition),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCondition = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a condition';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Notes TextField
                              TextFormField(
                                controller: _notesController,
                                decoration: const InputDecoration(
                                  labelText: 'Notes (Optional)',
                                  hintText:
                                      'Add any additional information about this patient',
                                  prefixIcon: Icon(Icons.note),
                                ),
                                maxLines: 3,
                              ),
                              const SizedBox(height: 16),

                              // Add Patient Button
                              CustomButton(
                                text: 'Add Patient',
                                onPressed: () => _addPatient(
                                  result['id'],
                                  result['name'],
                                  result['email'],
                                ),
                                isLoading: _isAdding,
                                width: double.infinity,
                                icon: Icons.person_add,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
