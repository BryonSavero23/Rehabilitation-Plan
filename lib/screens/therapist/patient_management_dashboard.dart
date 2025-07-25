import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:personalized_rehabilitation_plans/services/auth_service.dart';
import 'package:personalized_rehabilitation_plans/widgets/custom_button.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/patient_detail_screen.dart';
import 'package:personalized_rehabilitation_plans/screens/therapist/add_patient_screen.dart';

class PatientManagementDashboard extends StatefulWidget {
  const PatientManagementDashboard({super.key});

  @override
  State<PatientManagementDashboard> createState() =>
      _PatientManagementDashboardState();
}

class _PatientManagementDashboardState extends State<PatientManagementDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search patients...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                autofocus: true,
              )
            : const Text('Patient Management'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All Patients'),
            Tab(text: 'Active Plans'),
            Tab(text: 'Recent Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPatientsTab(authService),
          _buildActivePlansTab(authService),
          _buildRecentActivityTab(authService),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddPatientScreen(),
            ),
          ).then((_) {
            // Refresh data when returning
            setState(() {});
          });
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildPatientsTab(AuthService authService) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('therapists')
          .doc(authService.currentUser!.uid)
          .collection('patients')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: Colors.red.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No patients found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Add Your First Patient',
                  icon: Icons.person_add,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddPatientScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }

        final patients = snapshot.data!.docs;

        // Filter patients based on search query
        final filteredPatients = _searchQuery.isEmpty
            ? patients
            : patients.where((doc) {
                final patientData = doc.data() as Map<String, dynamic>;
                final patientName =
                    patientData['name'].toString().toLowerCase();
                final patientEmail =
                    patientData['email'].toString().toLowerCase();

                return patientName.contains(_searchQuery) ||
                    patientEmail.contains(_searchQuery);
              }).toList();

        return filteredPatients.isEmpty
            ? Center(
                child: Text(
                  'No patients match your search',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: filteredPatients.length,
                itemBuilder: (context, index) {
                  final patientData =
                      filteredPatients[index].data() as Map<String, dynamic>;
                  final patientId = filteredPatients[index].id;
                  final patientName = patientData['name'] ?? 'Unknown';
                  final patientEmail = patientData['email'] ?? 'No email';
                  final lastActivity = patientData['lastActivity'] != null
                      ? (patientData['lastActivity'] as Timestamp).toDate()
                      : null;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        vertical: 6.0, horizontal: 4.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          patientName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(patientName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientEmail,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (lastActivity != null)
                            Text(
                              _formatDate(lastActivity),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          const SizedBox(height: 4),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PatientDetailScreen(
                              patientId: patientId,
                              patientName: patientName,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
      },
    );
  }

  Widget _buildActivePlansTab(AuthService authService) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('rehabilitation_plans')
          .where('therapistId', isEqualTo: authService.currentUser!.uid)
          .where('status', isEqualTo: 'active')
          .orderBy('lastUpdated', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading plans: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No active plans found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final plans = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final planData = plans[index].data() as Map<String, dynamic>;
            final planId = plans[index].id;
            final planTitle = planData['title'] ?? 'Unnamed Plan';
            final patientId = planData['userId'] ?? '';
            final lastUpdated =
                (planData['lastUpdated'] as Timestamp?)?.toDate() ??
                    DateTime.now();

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(patientId)
                  .get(),
              builder: (context, userSnapshot) {
                String patientName = 'Unknown Patient';
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  patientName = userData?['name'] ?? 'Unknown Patient';
                }

                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 6.0, horizontal: 4.0),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.healing,
                        color: Colors.blue,
                      ),
                    ),
                    title: Text(planTitle),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Patient: $patientName'),
                        Text(
                          'Last updated: ${_formatDate(lastUpdated)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PatientDetailScreen(
                            patientId: patientId,
                            patientName: patientName,
                            initialTabIndex: 1, // Plans tab
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRecentActivityTab(AuthService authService) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('progress_logs')
          .where('therapistId', isEqualTo: authService.currentUser!.uid)
          .orderBy('date', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading activity: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No recent activity',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final activities = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activityData =
                activities[index].data() as Map<String, dynamic>;
            final activityType = activityData['type'] ?? 'unknown';
            final patientId = activityData['userId'] ?? '';
            final date = (activityData['date'] as Timestamp?)?.toDate() ??
                DateTime.now();

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(patientId)
                  .get(),
              builder: (context, userSnapshot) {
                String patientName = 'Unknown Patient';
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  patientName = userData?['name'] ?? 'Unknown Patient';
                }

                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 4.0, horizontal: 4.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          _getActivityColor(activityType).withOpacity(0.1),
                      child: Icon(
                        _getActivityIcon(activityType),
                        color: _getActivityColor(activityType),
                        size: 20,
                      ),
                    ),
                    title: Text(_getActivityTitle(activityType, patientName)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getActivityDescription(
                            activityType, activityData)),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateWithTime(date),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () {
                      if (activityData['planId'] != null) {
                        _navigateToPlanDetails(context, activityData['planId'],
                            patientId, patientName);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PatientDetailScreen(
                              patientId: patientId,
                              patientName: patientName,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _navigateToPlanDetails(BuildContext context, String planId,
      String patientId, String patientName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(
          patientId: patientId,
          patientName: patientName,
          initialTabIndex: 1, // Plans tab
        ),
      ),
    );
  }

  Color _getActivityColor(String activityType) {
    switch (activityType) {
      case 'progress_update':
        return Colors.green;
      case 'plan_created':
        return Colors.blue;
      case 'plan_updated':
        return Colors.orange;
      case 'message':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(String activityType) {
    switch (activityType) {
      case 'progress_update':
        return Icons.trending_up;
      case 'plan_created':
        return Icons.add_circle_outline;
      case 'plan_updated':
        return Icons.edit;
      case 'message':
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }

  String _getActivityTitle(String activityType, String patientName) {
    switch (activityType) {
      case 'progress_update':
        return '$patientName logged progress';
      case 'plan_created':
        return 'New plan created for $patientName';
      case 'plan_updated':
        return 'Plan updated for $patientName';
      case 'message':
        return 'Message from $patientName';
      default:
        return 'Activity from $patientName';
    }
  }

  String _getActivityDescription(
      String activityType, Map<String, dynamic> data) {
    switch (activityType) {
      case 'progress_update':
        final adherence = data['adherencePercentage'] ?? 0;
        return 'Adherence: $adherence%';
      case 'plan_created':
        return data['planTitle'] ?? 'New rehabilitation plan';
      case 'plan_updated':
        return data['updateDescription'] ?? 'Plan details were updated';
      case 'message':
        return data['messagePreview'] ?? 'New message received';
      default:
        return 'Activity details';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  String _formatDateWithTime(DateTime date) {
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Patients'),
              leading: const Icon(Icons.people),
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(0);
              },
            ),
            ListTile(
              title: const Text('Active Plans'),
              leading: const Icon(Icons.assignment),
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(1);
              },
            ),
            ListTile(
              title: const Text('Recent Activity'),
              leading: const Icon(Icons.history),
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(2);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
