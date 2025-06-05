import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';
import '../../services/notification_service.dart';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../../screens/home_screen.dart';
import '../../services/usda_food_service.dart';
import 'dart:convert';

class PatientHomeDashboard extends StatefulWidget {
  final UserProfile profile;
  const PatientHomeDashboard({Key? key, required this.profile})
    : super(key: key);

  @override
  State<PatientHomeDashboard> createState() => _PatientHomeDashboardState();
}

class _PatientHomeDashboardState extends State<PatientHomeDashboard> {
  List<Map<String, dynamic>> _recentSymptoms = [];
  List<Map<String, dynamic>> _recentMeds = [];
  bool _loadingSymptoms = true;
  bool _loadingMeds = true;
  String _reminderFilter = 'All';
  String? _firstName;
  bool _isFilterLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRecentSymptoms();
    _fetchRecentMeds();
    _fetchFirstName();
  }

  Future<void> _fetchFirstName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = doc.data();
      if (data != null && data['firstName'] != null) {
        setState(() {
          _firstName = data['firstName'];
        });
      }
    } catch (e) {
      debugPrint('[PatientHomeDashboard] Error fetching first name: $e');
    }
  }

  Future<void> _fetchRecentSymptoms() async {
    setState(() => _loadingSymptoms = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('symptoms')
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();
    setState(() {
      _recentSymptoms = snapshot.docs.map((doc) => doc.data()).toList();
      _loadingSymptoms = false;
    });
  }

  Future<void> _fetchRecentMeds() async {
    setState(() => _loadingMeds = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('medications')
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();
    setState(() {
      _recentMeds = snapshot.docs.map((doc) => doc.data()).toList();
      _loadingMeds = false;
    });
  }

  Future<void> _showLogSymptomDialog() async {
    final TextEditingController _controller = TextEditingController();
    bool _saving = false;
    String? _error;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Log Symptom'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Describe your symptom',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      _saving
                          ? null
                          : () async {
                            final desc = _controller.text.trim();
                            if (desc.isEmpty) {
                              setDialogState(
                                () => _error = 'Please enter a symptom',
                              );
                              return;
                            }
                            setDialogState(() {
                              _saving = true;
                              _error = null;
                            });
                            final user = FirebaseAuth.instance.currentUser;
                            try {
                              if (user != null) {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .collection('symptoms')
                                    .add({
                                      'description': desc,
                                      'timestamp': DateTime.now(),
                                    });
                              }
                              setDialogState(() => _saving = false);
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Symptom logged!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _fetchRecentSymptoms();
                              }
                            } catch (e) {
                              debugPrint(
                                '[PatientHomeDashboard] Error logging symptom: $e',
                              );
                              setDialogState(() {
                                _saving = false;
                                _error = 'Failed to log symptom.';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                  child:
                      _saving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showLogMedDialog() async {
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _doseController = TextEditingController();
    bool _saving = false;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Log Medication'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Medication name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _doseController,
                    decoration: const InputDecoration(
                      labelText: 'Dose (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      _saving
                          ? null
                          : () async {
                            final name = _nameController.text.trim();
                            final dose = _doseController.text.trim();
                            if (name.isEmpty) return;
                            setDialogState(() => _saving = true);
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('medications')
                                  .add({
                                    'name': name,
                                    'dose': dose,
                                    'timestamp': DateTime.now(),
                                  });
                            }
                            setDialogState(() => _saving = false);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Medication logged!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _fetchRecentMeds();
                            }
                          },
                  child:
                      _saving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _remindersStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    final now = DateTime.now();
    var query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('reminders')
        .where('done', isEqualTo: false)
        .where('dateTime', isGreaterThanOrEqualTo: now)
        .orderBy('dateTime');
    if (_reminderFilter != 'All') {
      print('Filtering reminders by type: $_reminderFilter');
      query = query.where('type', isEqualTo: _reminderFilter);
    } else {
      print('Showing all reminders');
    }
    return query.snapshots();
  }

  Future<void> _markReminderDone(String reminderId, bool done) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('reminders')
        .doc(reminderId)
        .update({'done': done});
    if (done) {
      await NotificationService().cancelNotification(reminderId.hashCode);
    }
  }

  Future<void> _deleteReminder(String reminderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('reminders')
        .doc(reminderId)
        .delete();
    await NotificationService().cancelNotification(reminderId.hashCode);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Health Hub'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Greeting
            Text(
              _firstName != null && _firstName!.isNotEmpty
                  ? "Good morning, $_firstName!"
                  : "Good morning!",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              profile.primaryCondition != null
                  ? "Managing: ${profile.primaryCondition}"
                  : "Welcome to your health dashboard!",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (profile.mainChallenge != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Main challenge: ${profile.mainChallenge}",
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            // Mood Check-in Card pinned under managing diabetes
            const SizedBox(height: 14),
            _MoodCheckInCard(compact: true),
            const SizedBox(height: 18),

            // Quick Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickAction(
                  icon: Icons.healing,
                  label: "Log Symptom",
                  onTap: _showLogSymptomDialog,
                ),
                _QuickAction(
                  icon: Icons.medication,
                  label: "Log Med",
                  onTap: _showLogMedDialog,
                ),
                _QuickAction(
                  icon: Icons.restaurant,
                  label: "Log Food",
                  onTap: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) =>
                              LogFoodDialog(onSaved: () => setState(() {})),
                    );
                  },
                ),
                _QuickAction(
                  icon: Icons.alarm,
                  label: "Reminder",
                  onTap: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AddReminderDialog(
                            onSaved: () {
                              setState(() {});
                            },
                          ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            FoodLogsCard(),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.only(bottom: 18),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      const Icon(Icons.alarm, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      Text(
                        "Reminders",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder:
                                (context) => AddReminderDialog(
                                  onSaved: () {
                                    setState(() {});
                                  },
                                ),
                          );
                        },
                        child: const Text("Add New"),
                      ),
                    ],
                  ),
                  children: [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _remindersStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (!snapshot.hasData ||
                            snapshot.data!.docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              "No reminders yet.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        } else {
                          return Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: DataTable(
                              border: null,
                              dividerThickness: 0,
                              horizontalMargin: 16,
                              columnSpacing: 16,
                              dataRowMinHeight: 48,
                              columns: const [
                                DataColumn(label: Text('Title')),
                                DataColumn(label: Text('Type')),
                                DataColumn(label: Text('Place')),
                                DataColumn(label: Text('Date/Time')),
                                DataColumn(label: Text('Done')),
                                DataColumn(
                                  label: SizedBox(width: 48),
                                ), // For icons, rightmost
                              ],
                              rows:
                                  snapshot.data!.docs.map((doc) {
                                    final data = doc.data();
                                    final dateTime =
                                        (data['dateTime'] as Timestamp)
                                            .toDate();
                                    final done = data['done'] ?? false;
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            child: Text(data['title'] ?? ''),
                                          ),
                                        ),
                                        DataCell(
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            child: Text(data['type'] ?? ''),
                                          ),
                                        ),
                                        DataCell(
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            child:
                                                data['type'] == 'Appointment'
                                                    ? Text(data['place'] ?? '-')
                                                    : const Text('-'),
                                          ),
                                        ),
                                        DataCell(
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            child: Text(
                                              '${dateTime.toLocal().toString().substring(0, 16)}',
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            child: Checkbox(
                                              value: done,
                                              onChanged:
                                                  (val) => _markReminderDone(
                                                    doc.id,
                                                    val ?? false,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    color: Colors.grey,
                                                    size: 18,
                                                  ),
                                                  tooltip: 'Edit',
                                                  padding: EdgeInsets.zero,
                                                  constraints: BoxConstraints(),
                                                  onPressed:
                                                      () =>
                                                          _showEditReminderDialog(
                                                            doc,
                                                          ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.grey,
                                                    size: 18,
                                                  ),
                                                  tooltip: 'Delete',
                                                  padding: EdgeInsets.zero,
                                                  constraints: BoxConstraints(),
                                                  onPressed:
                                                      () => _deleteReminder(
                                                        doc.id,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Medications Section (Card)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.only(bottom: 18),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      const Icon(Icons.medication, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        "Medications",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  children: [
                    if (_loadingMeds)
                      const Center(child: CircularProgressIndicator())
                    else if (_recentMeds.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          "No medications logged.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: DataTable(
                          border: null,
                          dividerThickness: 0,
                          horizontalMargin: 16,
                          columnSpacing: 16,
                          dataRowMinHeight: 48,
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Dose')),
                            DataColumn(label: Text('Date')),
                            DataColumn(
                              label: SizedBox(width: 48),
                            ), // For icons, rightmost
                          ],
                          rows:
                              _recentMeds.asMap().entries.map((entry) {
                                final i = entry.key;
                                final med = entry.value;
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: Text(med['name'] ?? ''),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: Text(med['dose'] ?? ''),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          med['timestamp'] != null
                                              ? (med['timestamp'] is DateTime
                                                  ? (med['timestamp']
                                                          as DateTime)
                                                      .toLocal()
                                                      .toString()
                                                      .substring(0, 16)
                                                  : med['timestamp']
                                                      .toDate()
                                                      .toLocal()
                                                      .toString()
                                                      .substring(0, 16))
                                              : '',
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.grey,
                                                size: 18,
                                              ),
                                              tooltip: 'Edit',
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(),
                                              onPressed:
                                                  () => _showEditMedDialog(i),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.grey,
                                                size: 18,
                                              ),
                                              tooltip: 'Delete',
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(),
                                              onPressed: () => _deleteMed(i),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Symptoms Section (Card)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.only(bottom: 18),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      const Icon(Icons.healing, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        "Symptoms",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  children: [
                    if (_loadingSymptoms)
                      const Center(child: CircularProgressIndicator())
                    else if (_recentSymptoms.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          "No symptoms logged.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: DataTable(
                          border: null,
                          dividerThickness: 0,
                          horizontalMargin: 16,
                          columnSpacing: 16,
                          dataRowMinHeight: 48,
                          columns: const [
                            DataColumn(label: Text('Description')),
                            DataColumn(label: Text('Date')),
                            DataColumn(
                              label: SizedBox(width: 48),
                            ), // For icons, rightmost
                          ],
                          rows:
                              _recentSymptoms.asMap().entries.map((entry) {
                                final i = entry.key;
                                final symptom = entry.value;
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          symptom['description'] ?? '',
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          symptom['timestamp'] != null
                                              ? (symptom['timestamp']
                                                      is DateTime
                                                  ? (symptom['timestamp']
                                                          as DateTime)
                                                      .toLocal()
                                                      .toString()
                                                      .substring(0, 16)
                                                  : symptom['timestamp']
                                                      .toDate()
                                                      .toLocal()
                                                      .toString()
                                                      .substring(0, 16))
                                              : '',
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.grey,
                                                size: 18,
                                              ),
                                              tooltip: 'Edit',
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(),
                                              onPressed:
                                                  () =>
                                                      _showEditSymptomDialog(i),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.grey,
                                                size: 18,
                                              ),
                                              tooltip: 'Delete',
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(),
                                              onPressed:
                                                  () => _deleteSymptom(i),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showEditMedDialog(int index) {
    final med = _recentMeds[index];
    final nameController = TextEditingController(text: med['name']);
    final doseController = TextEditingController(text: med['dose']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Medication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doseController,
                decoration: const InputDecoration(labelText: 'Dose'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final snapshot =
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('medications')
                          .orderBy('timestamp', descending: true)
                          .limit(5)
                          .get();
                  final docId = snapshot.docs[index].id;
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('medications')
                      .doc(docId)
                      .update({
                        'name': nameController.text.trim(),
                        'dose': doseController.text.trim(),
                      });
                  setState(() {
                    _recentMeds[index]['name'] = nameController.text.trim();
                    _recentMeds[index]['dose'] = doseController.text.trim();
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteMed(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('medications')
              .orderBy('timestamp', descending: true)
              .limit(5)
              .get();
      final docId = snapshot.docs[index].id;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medications')
          .doc(docId)
          .delete();
      setState(() {
        _recentMeds.removeAt(index);
      });
    }
  }

  void _showEditSymptomDialog(int index) {
    final symptom = _recentSymptoms[index];
    final descController = TextEditingController(text: symptom['description']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Symptom'),
          content: TextField(
            controller: descController,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final snapshot =
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('symptoms')
                          .orderBy('timestamp', descending: true)
                          .limit(5)
                          .get();
                  final docId = snapshot.docs[index].id;
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('symptoms')
                      .doc(docId)
                      .update({'description': descController.text.trim()});
                  setState(() {
                    _recentSymptoms[index]['description'] =
                        descController.text.trim();
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteSymptom(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('symptoms')
              .orderBy('timestamp', descending: true)
              .limit(5)
              .get();
      final docId = snapshot.docs[index].id;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('symptoms')
          .doc(docId)
          .delete();
      setState(() {
        _recentSymptoms.removeAt(index);
      });
    }
  }

  void _showEditReminderDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final titleController = TextEditingController(text: data['title']);
    final notesController = TextEditingController(text: data['notes']);
    final placeController = TextEditingController(text: data['place']);
    String type = data['type'] ?? 'Other';
    DateTime? selectedDateTime = (data['dateTime'] as Timestamp).toDate();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Appointment',
                      child: Text('Appointment'),
                    ),
                    DropdownMenuItem(
                      value: 'Medication',
                      child: Text('Medication'),
                    ),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (val) => type = val ?? 'Other',
                ),
                if (type == 'Appointment') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: placeController,
                    decoration: const InputDecoration(labelText: 'Place'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedDateTime == null
                            ? 'No date/time selected'
                            : '${selectedDateTime != null ? selectedDateTime!.toLocal().toString().substring(0, 16) : ''}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDateTime ?? now,
                          firstDate: now,
                          lastDate: DateTime(now.year + 5),
                        );
                        if (date == null) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            selectedDateTime ?? now,
                          ),
                        );
                        if (time == null) return;
                        setState(() {
                          selectedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                      child: const Text('Pick Date & Time'),
                    ),
                  ],
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
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('reminders')
                      .doc(doc.id)
                      .update({
                        'title': titleController.text.trim(),
                        'type': type,
                        'place':
                            type == 'Appointment'
                                ? placeController.text.trim()
                                : null,
                        'notes': notesController.text.trim(),
                        'dateTime': selectedDateTime,
                      });
                  setState(() {});
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// Add the mood check-in card widget at the end of the file
class _MoodCheckInCard extends StatefulWidget {
  final bool compact;
  const _MoodCheckInCard({this.compact = false});
  @override
  State<_MoodCheckInCard> createState() => _MoodCheckInCardState();
}

class _MoodCheckInCardState extends State<_MoodCheckInCard>
    with SingleTickerProviderStateMixin {
  String? _selectedMood;
  bool _checkedToday = false;
  bool _isSubmitting = false;
  final List<Map<String, dynamic>> _moods = [
    {
      "icon": Icons.sentiment_very_satisfied,
      "label": "Great",
      "color": Colors.green,
    },
    {
      "icon": Icons.sentiment_satisfied,
      "label": "Good",
      "color": Colors.lightGreen,
    },
    {"icon": Icons.sentiment_neutral, "label": "Okay", "color": Colors.amber},
    {
      "icon": Icons.sentiment_dissatisfied,
      "label": "Low",
      "color": Colors.orange,
    },
    {
      "icon": Icons.sentiment_very_dissatisfied,
      "label": "Bad",
      "color": Colors.red,
    },
  ];

  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.12, // slightly less scale for compactness
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _checkMoodForToday();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkMoodForToday() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final todayKey = _dateKey(DateTime.now());
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    final moods = doc.data()?['moodCheckins'] ?? {};
    if (moods[todayKey] != null) {
      setState(() {
        _checkedToday = true;
        _selectedMood = moods[todayKey];
      });
    }
  }

  String _dateKey(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  Future<void> _submitMood(String mood) async {
    setState(() {
      _isSubmitting = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final todayKey = _dateKey(DateTime.now());
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'moodCheckins': {todayKey: mood},
      }, SetOptions(merge: true));
    }
    setState(() {
      _selectedMood = mood;
      _checkedToday = true;
      _isSubmitting = false;
    });
  }

  void _onMoodTap(String mood) {
    if (_checkedToday || _isSubmitting) return;
    _controller.forward(from: 0);
    _submitMood(mood);
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Why check in your mood?'),
            content: const Text(
              'Mood check-ins help you and your care team spot trends, understand triggers, and improve your well-being over time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.compact ? 2.0 : 4.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.compact ? 14 : 20),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.compact ? 2 : 6,
            sigmaY: widget.compact ? 2 : 6,
          ),
          child: Card(
            elevation: widget.compact ? 1 : 4,
            color: Colors.white.withOpacity(widget.compact ? 0.93 : 0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.compact ? 14 : 20),
              side: BorderSide(
                color: Colors.grey.withOpacity(widget.compact ? 0.13 : 0.18),
                width: widget.compact ? 0.5 : 1.0,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: widget.compact ? 8 : 14,
                horizontal: widget.compact ? 8 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _checkedToday
                              ? "Mood checked in!"
                              : "How are you feeling today?",
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.info_outline,
                          color: Colors.grey,
                          size: 20,
                        ),
                        tooltip: 'Why check in?',
                        onPressed: _showInfoDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children:
                        _moods.map((mood) {
                          final isSelected = _selectedMood == mood["label"];
                          return GestureDetector(
                            onTap: () => _onMoodTap(mood["label"]),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? (mood["color"] as Color).withOpacity(
                                          0.13,
                                        )
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    isSelected
                                        ? Border.all(
                                          color: mood["color"],
                                          width: 2,
                                        )
                                        : null,
                                boxShadow:
                                    isSelected
                                        ? [
                                          BoxShadow(
                                            color: (mood["color"] as Color)
                                                .withOpacity(0.13),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                        : [],
                              ),
                              child: Column(
                                children: [
                                  AnimatedScale(
                                    scale: isSelected ? _scaleAnim.value : 1.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.elasticOut,
                                    child: Icon(
                                      mood["icon"],
                                      size: 32,
                                      color: mood["color"],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mood["label"],
                                    style: TextStyle(
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      color:
                                          isSelected
                                              ? mood["color"]
                                              : Colors.black87,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (isSelected)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1.0),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.green[400],
                                        size: 14,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  if (_checkedToday)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        "Thank you for checking in!",
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
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

// --- Mood Trend Chart ---
class _MoodTrendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.show_chart, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Mood Trend',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MoodTrendChart(),
          ],
        ),
      ),
    );
  }
}

class _MoodTrendChart extends StatefulWidget {
  @override
  State<_MoodTrendChart> createState() => _MoodTrendChartState();
}

class _MoodTrendChartState extends State<_MoodTrendChart> {
  Map<String, dynamic> _moodData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMoodData();
  }

  Future<void> _fetchMoodData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    final data = doc.data();
    setState(() {
      _moodData = data?['moodCheckins'] ?? {};
      _loading = false;
    });
  }

  int _moodValue(String? mood) {
    switch (mood) {
      case 'Great':
        return 5;
      case 'Good':
        return 4;
      case 'Okay':
        return 3;
      case 'Low':
        return 2;
      case 'Bad':
        return 1;
      default:
        return 0;
    }
  }

  String _moodLabel(int value) {
    switch (value) {
      case 5:
        return 'Great';
      case 4:
        return 'Good';
      case 3:
        return 'Okay';
      case 2:
        return 'Low';
      case 1:
        return 'Bad';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final sortedKeys = _moodData.keys.toList()..sort();
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedKeys.length; i++) {
      final mood = _moodData[sortedKeys[i]];
      spots.add(FlSpot(i.toDouble(), _moodValue(mood).toDouble()));
    }
    if (spots.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No mood check-in data yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return SizedBox(
      height: 180,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: max(320, spots.length * 48),
          child: LineChart(
            LineChartData(
              minY: 1,
              maxY: 5,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget:
                        (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            _moodLabel(value.toInt()),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    interval: 1,
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= sortedKeys.length)
                        return const SizedBox.shrink();
                      final date = sortedKeys[idx].substring(5); // MM-DD
                      return Text(date, style: const TextStyle(fontSize: 11));
                    },
                    interval: 1,
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(show: true, horizontalInterval: 1),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 4,
                  dotData: FlDotData(show: true),
                  isStrokeCapRound: true,
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Mood Distribution Pie Chart ---
class _MoodDistributionCard extends StatefulWidget {
  @override
  State<_MoodDistributionCard> createState() => _MoodDistributionCardState();
}

class _MoodDistributionCardState extends State<_MoodDistributionCard> {
  Map<String, dynamic> _moodData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMoodData();
  }

  Future<void> _fetchMoodData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    final data = doc.data();
    setState(() {
      _moodData = data?['moodCheckins'] ?? {};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // Only last 14 days
    final now = DateTime.now();
    final last14 =
        _moodData.entries.where((e) {
          final date = DateTime.tryParse(e.key) ?? now;
          return now.difference(date).inDays <= 14;
        }).toList();
    if (last14.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          height: 180,
          child: Center(
            child: Text(
              'Not enough data for mood distribution.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }
    final moodCounts = <String, int>{};
    for (final e in last14) {
      moodCounts[e.value] = (moodCounts[e.value] ?? 0) + 1;
    }
    final colors = {
      'Great': Colors.green,
      'Good': Colors.lightGreen,
      'Okay': Colors.amber,
      'Low': Colors.orange,
      'Bad': Colors.red,
    };
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.pie_chart, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text(
                  'Mood Distribution (14 days)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: PieChart(
                PieChartData(
                  sections:
                      moodCounts.entries.map((e) {
                        final color = colors[e.key] ?? Colors.grey;
                        final value = e.value.toDouble();
                        final total = last14.length;
                        return PieChartSectionData(
                          color: color,
                          value: value,
                          title:
                              '${((value / total) * 100).toStringAsFixed(0)}%',
                          radius: 38,
                          titleStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        );
                      }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 28,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children:
                  colors.entries
                      .map(
                        (e) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: e.value,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(e.key, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Symptom Frequency Bar Chart Placeholder ---
class _SymptomFrequencyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: Implement real symptom frequency chart
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Symptom frequency chart coming soon!',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

// --- Medication Adherence Chart Placeholder ---
class _MedicationAdherenceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: Implement real medication adherence chart
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Medication adherence chart coming soon!',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

// --- Log Food Dialog ---
class LogFoodDialog extends StatefulWidget {
  final VoidCallback onSaved;
  const LogFoodDialog({required this.onSaved, Key? key}) : super(key: key);

  @override
  State<LogFoodDialog> createState() => _LogFoodDialogState();
}

class _LogFoodDialogState extends State<LogFoodDialog> {
  final _formKey = GlobalKey<FormState>();
  final _foodController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _mealType = 'Breakfast';
  bool _isSearching = false;
  bool _isSaving = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedFood;
  Map<String, dynamic>? _nutrition;

  @override
  void dispose() {
    _foodController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _searchFood() async {
    setState(() {
      _isSearching = true;
      _searchResults = [];
      _selectedFood = null;
      _nutrition = null;
      _errorMessage = null;
    });
    try {
      final results = await USDAFoodService().searchFoods(
        _foodController.text.trim(),
      );
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _fetchNutrition(Map<String, dynamic> food) async {
    setState(() {
      _selectedFood = food;
      _nutrition = null;
      _errorMessage = null;
    });
    try {
      final details = await USDAFoodService().getFoodDetails(food['fdcId']);
      // Calculate nutrition for entered amount (assume grams)
      double amount = double.tryParse(_amountController.text.trim()) ?? 0;
      double factor = 1.0;
      if (details['servingSize'] != null &&
          details['servingSizeUnit'] == 'g' &&
          amount > 0) {
        factor = amount / (details['servingSize'] ?? 100);
      } else if (amount > 0) {
        factor = amount / 100.0;
      }
      setState(() {
        _nutrition = {
          'calories': (details['calories'] ?? 0) * factor,
          'carbs': (details['carbs'] ?? 0) * factor,
          'protein': (details['protein'] ?? 0) * factor,
          'fat': (details['fat'] ?? 0) * factor,
          'description': details['description'],
          'servingSize': details['servingSize'],
          'servingSizeUnit': details['servingSizeUnit'],
        };
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch nutrition: $e';
      });
    }
  }

  Future<void> _saveFoodLog() async {
    if (!_formKey.currentState!.validate() || _nutrition == null) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isSaving = false;
        _errorMessage = "You must be logged in to log food.";
      });
      return;
    }
    try {
      final doc =
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('food_logs')
              .doc();
      await doc.set({
        'foodName': _nutrition!['description'] ?? _foodController.text.trim(),
        'amount': _amountController.text.trim(),
        'mealType': _mealType,
        'notes': _notesController.text.trim(),
        'dateTime': DateTime.now(),
        'calories': _nutrition!['calories'],
        'carbs': _nutrition!['carbs'],
        'protein': _nutrition!['protein'],
        'fat': _nutrition!['fat'],
      });
      setState(() => _isSaving = false);
      widget.onSaved();
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = "Failed to save food log: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final _scrollController = ScrollController();
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Log Food',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _foodController,
                  decoration: const InputDecoration(
                    labelText: 'Food Name',
                    prefixIcon: Icon(Icons.restaurant),
                  ),
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Enter a food name'
                              : null,
                  onFieldSubmitted: (_) => _searchFood(),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (grams)',
                    prefixIcon: Icon(Icons.scale),
                  ),
                  keyboardType: TextInputType.number,
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Enter amount in grams'
                              : null,
                  onChanged: (_) {
                    if (_selectedFood != null) _fetchNutrition(_selectedFood!);
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchFood,
                  child:
                      _isSearching
                          ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Search Food'),
                ),
                if (_searchResults.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const Text('Select a match:'),
                      ..._searchResults
                          .take(5)
                          .map(
                            (food) => ListTile(
                              title: Text(food['description'] ?? ''),
                              subtitle:
                                  food['brandName'] != null
                                      ? Text(food['brandName'])
                                      : null,
                              onTap: () async {
                                await _fetchNutrition(food);
                                // Auto-scroll to nutrition after selection
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );
                                _scrollController.animateTo(
                                  _scrollController.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              },
                              selected:
                                  _selectedFood?['fdcId'] == food['fdcId'],
                              trailing:
                                  _selectedFood?['fdcId'] == food['fdcId']
                                      ? const Icon(
                                        Icons.check,
                                        color: Colors.green,
                                      )
                                      : null,
                            ),
                          ),
                    ],
                  ),
                if (_nutrition != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Calculated Nutrition:'),
                        Text(
                          'Calories: ${_nutrition!['calories']?.toStringAsFixed(1) ?? '-'} kcal',
                        ),
                        Text(
                          'Carbs: ${_nutrition!['carbs']?.toStringAsFixed(1) ?? '-'} g',
                        ),
                        Text(
                          'Protein: ${_nutrition!['protein']?.toStringAsFixed(1) ?? '-'} g',
                        ),
                        Text(
                          'Fat: ${_nutrition!['fat']?.toStringAsFixed(1) ?? '-'} g',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _mealType,
                  decoration: const InputDecoration(
                    labelText: 'Meal Type',
                    prefixIcon: Icon(Icons.fastfood),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Breakfast',
                      child: Text('Breakfast'),
                    ),
                    DropdownMenuItem(value: 'Lunch', child: Text('Lunch')),
                    DropdownMenuItem(value: 'Dinner', child: Text('Dinner')),
                    DropdownMenuItem(value: 'Snack', child: Text('Snack')),
                  ],
                  onChanged:
                      (val) => setState(() => _mealType = val ?? 'Breakfast'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.note_alt),
                  ),
                  maxLines: 2,
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isSaving || _nutrition == null ? null : _saveFoodLog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child:
                        _isSaving
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Food Logs Card ---
class FoodLogsCard extends StatefulWidget {
  @override
  State<FoodLogsCard> createState() => _FoodLogsCardState();
}

class _FoodLogsCardState extends State<FoodLogsCard> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return SizedBox.shrink();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  "Recent Food Logs",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('food_logs')
                      .orderBy('dateTime', descending: true)
                      .limit(3)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      "No food logs yet.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: DataTable(
                    border: null,
                    dividerThickness: 0,
                    horizontalMargin: 8,
                    columnSpacing: 10,
                    dataRowMinHeight: 44,
                    columns: const [
                      DataColumn(label: Text('Food')),
                      DataColumn(label: Text('Amount')),
                      DataColumn(label: Text('Meal')),
                      DataColumn(label: Text('Cal')),
                      DataColumn(label: Text('Carb')),
                      DataColumn(label: Text('Prot')),
                      DataColumn(label: Text('Fat')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: SizedBox(width: 48)),
                    ],
                    rows:
                        docs.map((doc) {
                          final data = doc.data();
                          final date = (data['dateTime'] as Timestamp).toDate();
                          return DataRow(
                            cells: [
                              DataCell(Text(data['foodName'] ?? '')),
                              DataCell(Text(data['amount'] ?? '')),
                              DataCell(Text(data['mealType'] ?? '')),
                              DataCell(
                                Text(
                                  data['calories'] != null
                                      ? data['calories'].toStringAsFixed(0)
                                      : '-',
                                ),
                              ),
                              DataCell(
                                Text(
                                  data['carbs'] != null
                                      ? data['carbs'].toStringAsFixed(0)
                                      : '-',
                                ),
                              ),
                              DataCell(
                                Text(
                                  data['protein'] != null
                                      ? data['protein'].toStringAsFixed(0)
                                      : '-',
                                ),
                              ),
                              DataCell(
                                Text(
                                  data['fat'] != null
                                      ? data['fat'].toStringAsFixed(0)
                                      : '-',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      tooltip: 'Edit',
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(),
                                      onPressed: () => _showEditFoodDialog(doc),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      tooltip: 'Delete',
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(),
                                      onPressed: () => _deleteFoodLog(doc.id),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditFoodDialog(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    showDialog(
      context: context,
      builder:
          (context) =>
              LogFoodDialog(onSaved: () => setState(() {}), key: UniqueKey()),
    );
    // Note: For a real edit, you would pass the data to LogFoodDialog and allow editing.
    // For now, LogFoodDialog only supports adding. To support editing, refactor LogFoodDialog to accept initial data and docId.
  }

  void _deleteFoodLog(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('food_logs')
        .doc(docId)
        .delete();
    setState(() {});
  }
}
