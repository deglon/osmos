import 'package:flutter/material.dart';
import 'package:osmos/screens/ask_osmos/vocal_chatbot_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:osmos/services/user_profile_service.dart';
import 'package:osmos/widgets/modern_text_field.dart';
import 'package:intl/intl.dart';
import 'mode_screen.dart'; // Import your new ModeScreen
import 'package:osmos/widgets/mode_card_widget.dart';
import 'package:osmos/widgets/custom_map_widget.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/user_profile.dart';
import 'home/patient_home_dashboard.dart';
import 'home/wellness_home_dashboard.dart';
import 'home/caregiver_home_dashboard.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cupertino_icons/cupertino_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import your chatbot and other screens as needed
// import 'package:osmos/screens/ask_osmos/vocal_chatbot_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Ensure profile is fetched when HomeScreen loads
    Provider.of<UserProfileProvider>(context, listen: false).fetchUserProfile();
  }

  void _onFabPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VocalChatbotScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = Provider.of<UserProfileProvider>(context).profile;

    debugPrint(
      '[HomeScreen] userProfile: ' + (userProfile?.toString() ?? 'null'),
    );
    debugPrint('[HomeScreen] userType: ' + (userProfile?.userType ?? 'null'));

    if (userProfile == null) {
      // Still loading profile
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Home tab: dashboard based on user type
    Widget homeTab;
    switch (userProfile.userType) {
      case 'Patient':
        homeTab = PatientHomeDashboard(profile: userProfile);
        break;
      case 'Wellness':
        homeTab = WellnessHomeDashboard(
          profile: userProfile,
          onNavigateToModes: () {
            setState(() {
              _currentIndex = 1; // Switch to Modes tab
            });
          },
        );
        break;
      case 'Caregiver':
        homeTab = CaregiverHomeDashboard(profile: userProfile);
        break;
      default:
        homeTab = Center(
          child: Text(
            'Unknown user type: "${userProfile.userType}"\nProfile: ${userProfile.toString()}',
            style: const TextStyle(color: Colors.red, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        );
    }

    final List<Widget> _tabs = [
      homeTab, // Home
      const ModeScreen(), // Modes
      const VocalChatbotScreen(), // Osmos (center tab)
      StatsTabContent(userType: userProfile.userType), // Stats
      const ProfileTabContent(), // Profile
    ];

    final List<IconData> _navIcons = [
      Icons.home,
      Icons.explore,
      Icons.auto_awesome, // Use a star/sparkles icon for Osmos
      Icons.show_chart,
      Icons.person,
    ];
    final List<String> _navLabels = [
      'Home',
      'Modes',
      'Osmos',
      'Stats',
      'Profile',
    ];

    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4, top: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_tabs.length, (i) {
            final selected = _currentIndex == i;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _currentIndex = i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _navIcons[i],
                        size: 24,
                        color:
                            selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[500],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _navLabels[i],
                        style: TextStyle(
                          color:
                              selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[600],
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class HomeTabContent extends StatefulWidget {
  const HomeTabContent({Key? key}) : super(key: key);

  @override
  State<HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent> {
  String? _selectedMood;
  bool _isSubmitting = false;
  bool _checkedToday = false;
  DateTime _today = DateTime.now();
  String _userName = '';

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

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _checkMoodForToday();
  }

  Future<void> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    final data = doc.data();
    if (data != null && data['firstName'] != null) {
      setState(() {
        _userName = data['firstName'];
      });
    }
  }

  Future<void> _checkMoodForToday() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    final moods = doc.data()?['moodCheckins'] ?? {};
    final todayKey = _dateKey(_today);
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
      final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final todayKey = _dateKey(_today);
      await doc.set({
        'moodCheckins': {todayKey: mood},
      }, SetOptions(merge: true));
    }
    setState(() {
      _selectedMood = mood;
      _checkedToday = true;
      _isSubmitting = false;
    });
  }

  // Add this method to fetch reminders as a stream
  Stream<QuerySnapshot<Map<String, dynamic>>> _remindersStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('reminders')
        .orderBy('dateTime')
        .snapshots();
  }

  // Add this method to show the Add Reminder dialog
  void _showAddReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => AddReminderDialog(onSaved: _onReminderAdded),
    );
  }

  // Callback after adding a reminder
  void _onReminderAdded() {
    setState(() {}); // Refresh the list
  }

  // Add this method to mark a reminder as done
  Future<void> _markReminderDone(String reminderId, bool done) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('reminders')
        .doc(reminderId)
        .update({'done': done});
  }

  @override
  Widget build(BuildContext context) {
    final reminders = [
      "Take Metformin at 9:00 AM",
      "Doctor's appointment at 2:00 PM",
    ];
    final activities = [
      "Logged blood sugar (110 mg/dL)",
      "Completed morning walk",
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModeCardWidget(),
          // Greeting
          Text(
            _userName.isNotEmpty
                ? "Good morning, $_userName!"
                : "Good morning!",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Here's to a healthy day!",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),

          // Mood Check-in Card
          _MoodCheckInCard(
            moods: _moods,
            selectedMood: _selectedMood,
            checkedToday: _checkedToday,
            isSubmitting: _isSubmitting,
            onMoodSelected: _submitMood,
          ),
          const SizedBox(height: 18),

          // Ask Osmos button
          ElevatedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text("Ask Osmos"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: const TextStyle(fontSize: 18),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              // TODO: Navigate to chatbot screen
            },
          ),
          const SizedBox(height: 24),

          // Quick Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _QuickAction(
                icon: Icons.healing,
                label: "Log Symptom",
                onTap: () {},
              ),
              _QuickAction(
                icon: Icons.medication,
                label: "Add Med",
                onTap: () {},
              ),
              _QuickAction(icon: Icons.mood, label: "Track Mood", onTap: () {}),
              _QuickAction(icon: Icons.alarm, label: "Reminder", onTap: () {}),
            ],
          ),
          const SizedBox(height: 32),

          // Reminders
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Reminders",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: _showAddReminderDialog,
                child: const Text("Add New"),
              ),
            ],
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _remindersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    "No reminders yet.",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              final reminders = snapshot.data!.docs;
              return Column(
                children:
                    reminders.map((doc) {
                      final data = doc.data();
                      final dateTime = (data['dateTime'] as Timestamp).toDate();
                      final done = data['done'] ?? false;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: Icon(
                            data['type'] == 'Medication'
                                ? Icons.medication
                                : data['type'] == 'Appointment'
                                ? Icons.event
                                : Icons.notifications_active_outlined,
                            color:
                                done
                                    ? Colors.grey
                                    : Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            data['title'] ?? '',
                            style: TextStyle(
                              decoration:
                                  done
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat(
                                  'MMM d, yyyy – h:mm a',
                                ).format(dateTime),
                              ),
                              if (data['notes'] != null &&
                                  data['notes'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    data['notes'],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Checkbox(
                            value: done,
                            onChanged:
                                (val) =>
                                    _markReminderDone(doc.id, val ?? false),
                            activeColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    }).toList(),
              );
            },
          ),
          const SizedBox(height: 32),

          // Recent Activity
          Text(
            "Recent Activity",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          ...activities.map(
            (activity) => Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text(activity),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodCheckInCard extends StatefulWidget {
  final List<Map<String, dynamic>> moods;
  final String? selectedMood;
  final bool checkedToday;
  final bool isSubmitting;
  final Function(String) onMoodSelected;
  const _MoodCheckInCard({
    required this.moods,
    required this.selectedMood,
    required this.checkedToday,
    required this.isSubmitting,
    required this.onMoodSelected,
    Key? key,
  }) : super(key: key);
  @override
  State<_MoodCheckInCard> createState() => _MoodCheckInCardState();
}

class _MoodCheckInCardState extends State<_MoodCheckInCard>
    with SingleTickerProviderStateMixin {
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
      end: 1.25,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onMoodTap(String mood) {
    if (widget.checkedToday || widget.isSubmitting) return;
    _controller.forward(from: 0);
    widget.onMoodSelected(mood);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF6F8F7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.checkedToday
                  ? "Mood checked in!"
                  : "How are you feeling today?",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children:
                  widget.moods.map((mood) {
                    final isSelected = widget.selectedMood == mood["label"];
                    return GestureDetector(
                      onTap: () => _onMoodTap(mood["label"]),
                      child: AnimatedScale(
                        scale: isSelected ? _scaleAnim.value : 1.0,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.elasticOut,
                        child: Opacity(
                          opacity:
                              widget.checkedToday && !isSelected ? 0.4 : 1.0,
                          child: Column(
                            children: [
                              Icon(
                                mood["icon"],
                                size: 36,
                                color: mood["color"],
                              ),
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.green[400],
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
            if (widget.checkedToday)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(
                  "Thank you for checking in!",
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsPlaceholderScreen extends StatelessWidget {
  const _StatsPlaceholderScreen();
  @override
  Widget build(BuildContext context) {
    return const StatsTabContent();
  }
}

class StatsTabContent extends StatefulWidget {
  final String? userType;
  const StatsTabContent({Key? key, this.userType}) : super(key: key);

  @override
  State<StatsTabContent> createState() => _StatsTabContentState();
}

class _StatsTabContentState extends State<StatsTabContent> {
  Map<String, dynamic> _moodData = {};
  bool _loading = true;

  // Aggregated stats
  int _calories = 0;
  int _carbs = 0;
  int _protein = 0;
  int _fat = 0;

  // Weekly stats
  List<DateTime> _weekDays = [];
  List<int> _dailyCalories = [];
  int _weekTotalCalories = 0;
  int _weekTotalCarbs = 0;
  int _weekTotalProtein = 0;
  int _weekTotalFat = 0;

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  List<_FoodLogEntry> _recentMeals = [];

  @override
  void initState() {
    super.initState();
    _fetchStatsAndMood();
  }

  Future<void> _fetchStatsAndMood() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    final data = doc.data();
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Fetch food_logs
    final foodLogsSnap =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('food_logs')
            .where('dateTime', isGreaterThanOrEqualTo: startOfDay)
            .where('dateTime', isLessThan: endOfDay)
            .get();
    // Fetch meals
    final mealsSnap =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meals')
            .where('dateTime', isGreaterThanOrEqualTo: startOfDay)
            .where('dateTime', isLessThan: endOfDay)
            .get();

    int calories = 0, carbs = 0, protein = 0, fat = 0;
    for (final doc in foodLogsSnap.docs) {
      final d = doc.data();
      calories += _toInt(d['calories']);
      carbs += _toInt(d['carbs']);
      protein += _toInt(d['protein']);
      fat += _toInt(d['fat']);
    }
    for (final doc in mealsSnap.docs) {
      final d = doc.data();
      calories += _toInt(d['calories']);
      carbs += _toInt(d['carbs']);
      protein += _toInt(d['protein']);
      fat += _toInt(d['fat']);
    }

    // --- Weekly stats ---
    List<DateTime> weekDays = List.generate(
      7,
      (i) => today.subtract(Duration(days: 6 - i)),
    );
    List<int> dailyCalories = [];
    int weekTotalCalories = 0,
        weekTotalCarbs = 0,
        weekTotalProtein = 0,
        weekTotalFat = 0;
    for (final day in weekDays) {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      final foodLogs =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('food_logs')
              .where('dateTime', isGreaterThanOrEqualTo: start)
              .where('dateTime', isLessThan: end)
              .get();
      final meals =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('meals')
              .where('dateTime', isGreaterThanOrEqualTo: start)
              .where('dateTime', isLessThan: end)
              .get();
      int dayCalories = 0, dayCarbs = 0, dayProtein = 0, dayFat = 0;
      for (final doc in foodLogs.docs) {
        final d = doc.data();
        dayCalories += _toInt(d['calories']);
        dayCarbs += _toInt(d['carbs']);
        dayProtein += _toInt(d['protein']);
        dayFat += _toInt(d['fat']);
      }
      for (final doc in meals.docs) {
        final d = doc.data();
        dayCalories += _toInt(d['calories']);
        dayCarbs += _toInt(d['carbs']);
        dayProtein += _toInt(d['protein']);
        dayFat += _toInt(d['fat']);
      }
      dailyCalories.add(dayCalories);
      weekTotalCalories += dayCalories;
      weekTotalCarbs += dayCarbs;
      weekTotalProtein += dayProtein;
      weekTotalFat += dayFat;
    }

    // --- Recent Meals ---
    final recentMeals = <_FoodLogEntry>[];
    final foodLogsRecent =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('food_logs')
            .orderBy('dateTime', descending: true)
            .limit(3)
            .get();
    final mealsRecent =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meals')
            .orderBy('dateTime', descending: true)
            .limit(3)
            .get();
    for (final doc in foodLogsRecent.docs) {
      final d = doc.data();
      recentMeals.add(
        _FoodLogEntry(
          name:
              d['foodName'] ??
              (d['foods'] is List && d['foods'].isNotEmpty
                  ? d['foods'][0]
                  : 'Food'),
          amount: d['amount'] ?? '',
          timestamp: (d['dateTime'] as Timestamp?)?.toDate(),
        ),
      );
    }
    for (final doc in mealsRecent.docs) {
      final d = doc.data();
      recentMeals.add(
        _FoodLogEntry(
          name: d['meal'] ?? 'Meal',
          amount: d['amount'] ?? '',
          timestamp: (d['dateTime'] as Timestamp?)?.toDate(),
        ),
      );
    }
    recentMeals.removeWhere((e) => e.timestamp == null);
    recentMeals.sort((a, b) => b.timestamp!.compareTo(a.timestamp!));
    final last3 = recentMeals.take(3).toList();

    setState(() {
      _moodData = data?['moodCheckins'] ?? {};
      _calories = calories;
      _carbs = carbs;
      _protein = protein;
      _fat = fat;
      _weekDays = weekDays;
      _dailyCalories = dailyCalories;
      _weekTotalCalories = weekTotalCalories;
      _weekTotalCarbs = weekTotalCarbs;
      _weekTotalProtein = weekTotalProtein;
      _weekTotalFat = weekTotalFat;
      _recentMeals = last3;
      _loading = false;
    });
  }

  void _showPlusDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Osmos Plus Feature'),
            content: const Text(
              'This feature is only available for Osmos Plus users. Upgrade your subscription to get the best of Osmos!',
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isWellness = widget.userType == 'Wellness';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats & Trends'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isWellness) ...[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.restaurant, color: Colors.deepOrange),
                          SizedBox(width: 8),
                          Text(
                            "Food Stats (Today)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _StatTile(
                            label: 'Calories',
                            value: _calories,
                            unit: 'kcal',
                            icon: Icons.local_fire_department,
                            color: Colors.orange,
                          ),
                          _StatTile(
                            label: 'Carbs',
                            value: _carbs,
                            unit: 'g',
                            icon: Icons.bubble_chart,
                            color: Colors.purple,
                          ),
                          _StatTile(
                            label: 'Protein',
                            value: _protein,
                            unit: 'g',
                            icon: Icons.fitness_center,
                            color: Colors.red,
                          ),
                          _StatTile(
                            label: 'Fat',
                            value: _fat,
                            unit: 'g',
                            icon: Icons.opacity,
                            color: Colors.brown,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.pie_chart, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            "Macros Breakdown",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                color: Colors.purple,
                                value: _carbs * 4,
                                title: '${_carbs}g',
                                radius: 38,
                                titleStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              PieChartSectionData(
                                color: Colors.red,
                                value: _protein * 4,
                                title: '${_protein}g',
                                radius: 38,
                                titleStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              PieChartSectionData(
                                color: Colors.brown,
                                value: _fat * 9,
                                title: '${_fat}g',
                                radius: 38,
                                titleStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            sectionsSpace: 2,
                            centerSpaceRadius: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 18,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.purple,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Carbs: $_carbs g',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Protein: $_protein g',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.brown,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Fat: $_fat g',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.bar_chart, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            "Calories (Last 7 Days)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 180,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY:
                                (_dailyCalories.reduce(
                                          (a, b) => a > b ? a : b,
                                        ) +
                                        100)
                                    .toDouble(),
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    int idx = value.toInt();
                                    if (idx < 0 || idx >= _weekDays.length)
                                      return const SizedBox.shrink();
                                    final day = _weekDays[idx];
                                    return Text(
                                      DateFormat('E').format(day),
                                      style: const TextStyle(fontSize: 12),
                                    );
                                  },
                                  reservedSize: 28,
                                ),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: List.generate(_dailyCalories.length, (
                              i,
                            ) {
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: _dailyCalories[i].toDouble(),
                                    color: Colors.green,
                                    width: 18,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.fastfood, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            "Recent Meals",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_recentMeals.isEmpty)
                        const Text('No recent meals logged.'),
                      ..._recentMeals.map((entry) {
                        final date = entry.timestamp;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.fastfood, color: Colors.orange[300]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${entry.name}${entry.amount.isNotEmpty ? ' (${entry.amount})' : ''}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              if (date != null)
                                Text(
                                  '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
            // --- Existing Mood Distribution Card ---
            _MoodDistributionCard(),
            const SizedBox(height: 32),
            const Text(
              'Other trends coming soon!',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodLogEntry {
  final String name;
  final String amount;
  final DateTime? timestamp;
  _FoodLogEntry({
    required this.name,
    required this.amount,
    required this.timestamp,
  });
}

// --- Stat Tile Widget ---
class _StatTile extends StatelessWidget {
  final String label;
  final dynamic value;
  final String unit;
  final IconData icon;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 15,
            ),
          ),
          Text(
            '${value ?? '--'}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          if (unit.isNotEmpty)
            Text(
              ' $unit',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
        ],
      ),
    );
  }
}

class _AppointmentsPlaceholderScreen extends StatelessWidget {
  const _AppointmentsPlaceholderScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Appointments\n(Coming soon!)',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FoodPlaceholderScreen extends StatelessWidget {
  const _FoodPlaceholderScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Food Tracker\n(Coming soon!)',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class ProfileTabContent extends StatefulWidget {
  const ProfileTabContent({Key? key}) : super(key: key);

  @override
  State<ProfileTabContent> createState() => _ProfileTabContentState();
}

class _ProfileTabContentState extends State<ProfileTabContent> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedGender;
  int? _selectedAge;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final data = await UserProfileService().getCurrentUserProfile();
      if (data != null) {
        _firstNameController.text = data['firstName'] ?? '';
        _lastNameController.text = data['lastName'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _selectedAge =
            data['age'] is int
                ? data['age']
                : int.tryParse(data['age']?.toString() ?? '');
        _selectedGender = data['gender'] ?? null;
      }
    } catch (e) {
      _errorMessage = 'Failed to load profile.';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await UserProfileService().updateUserProfile({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'age': _selectedAge,
        'gender': _selectedGender,
      });
      setState(() {
        _successMessage = 'Profile updated successfully!';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update profile.';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      backgroundColor: const Color(0xFF00B77D),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white,
                  child: Text(
                    (_firstNameController.text.isNotEmpty
                            ? _firstNameController.text[0]
                            : 'U')
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 36,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ModernTextField(
                  controller: _firstNameController,
                  label: 'First Name',
                  icon: Icons.person,
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Enter first name'
                              : null,
                ),
                const SizedBox(height: 16),
                ModernTextField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  icon: Icons.person,
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Enter last name'
                              : null,
                ),
                const SizedBox(height: 16),
                ModernTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator:
                      (value) =>
                          value == null || value.isEmpty ? 'Enter email' : null,
                ),
                const SizedBox(height: 16),
                ModernTextField(
                  controller: _phoneController,
                  label: 'Phone',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator:
                      (value) =>
                          value == null || value.isEmpty ? 'Enter phone' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedAge,
                  decoration: InputDecoration(
                    labelText: 'Age',
                    prefixIcon: const Icon(Icons.cake, color: Colors.white),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    labelStyle: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 18,
                    ),
                  ),
                  dropdownColor: const Color(0xFF00B77D),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items:
                      List.generate(91, (i) => 10 + i)
                          .map(
                            (age) => DropdownMenuItem<int>(
                              value: age,
                              child: Text(
                                age.toString(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _selectedAge = value),
                  validator: (value) => value == null ? 'Select age' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: const Icon(Icons.wc, color: Colors.white),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    labelStyle: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 18,
                    ),
                  ),
                  dropdownColor: const Color(0xFF00B77D),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items:
                      [
                            'Male',
                            'Female',
                            'Non-binary',
                            'Prefer not to say',
                            'Other',
                          ]
                          .map(
                            (gender) => DropdownMenuItem<String>(
                              value: gender,
                              child: Text(
                                gender,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _selectedGender = value),
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Select gender'
                              : null,
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_successMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(color: Colors.green, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF00B77D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      elevation: 2,
                    ),
                    child:
                        _isSaving
                            ? const CircularProgressIndicator(
                              color: Color(0xFF00B77D),
                            )
                            : const Text('Save'),
                  ),
                ),
                // Log Out button
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white, width: 2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () async {
                      // Sign out from FirebaseAuth
                      await FirebaseAuth.instance.signOut();
                      // Clear isLoggedIn from SharedPreferences
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isLoggedIn', false);
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/',
                          (route) => false,
                        );
                      }
                    },
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

final Map<String, dynamic> withingsMockData = {
  'dateRange': 'April 8–14, 2024',
  'steps': 48200,
  'stepsGoal': 42000,
  'distanceKm': 34.2,
  'elevationMeters': 210,
  'workouts': [
    {
      'type': 'Run',
      'distanceKm': 5.2,
      'durationMin': 32,
      'calories': 410,
      'date': '2024-04-10',
    },
    {
      'type': 'Walk',
      'distanceKm': 3.1,
      'durationMin': 40,
      'calories': 180,
      'date': '2024-04-12',
    },
  ],
  'heartRate': {
    'resting': 62,
    'average': 78,
    'max': 142,
    'min': 58,
    'night': 60,
    'day': 80,
  },
  'sleep': {
    'totalHours': 48.5,
    'avgPerNight': 6.9,
    'deep': 12.2,
    'light': 28.1,
    'rem': 8.2,
  },
  'source': 'Withings Steel HR (April 8–14, 2024, demo data)',
};

class AddReminderDialog extends StatefulWidget {
  final VoidCallback onSaved;
  const AddReminderDialog({required this.onSaved, Key? key}) : super(key: key);

  @override
  State<AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<AddReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _placeController = TextEditingController();
  String _type = 'Other';
  DateTime? _selectedDateTime;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate() || _selectedDateTime == null) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isSaving = false;
        _errorMessage = "You must be logged in to add reminders.";
      });
      return;
    }
    try {
      final doc =
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('reminders')
              .doc();
      final reminderData = {
        'title': _titleController.text.trim(),
        'dateTime': _selectedDateTime,
        'type': _type,
        'notes': _notesController.text.trim(),
        'done': false,
      };
      if (_type == 'Appointment') {
        reminderData['place'] = _placeController.text.trim();
      }
      await doc.set(reminderData);
      setState(() => _isSaving = false);
      widget.onSaved();
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = "Failed to save reminder: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add Reminder',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(CupertinoIcons.textformat),
                  ),
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Enter a title'
                              : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(CupertinoIcons.list_bullet),
                  ),
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
                  onChanged: (val) => setState(() => _type = val ?? 'Other'),
                ),
                if (_type == 'Appointment') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _placeController,
                    decoration: InputDecoration(
                      labelText: 'Place',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    validator: (value) {
                      if (_type == 'Appointment' &&
                          (value == null || value.isEmpty)) {
                        return 'Enter a place for the appointment';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(CupertinoIcons.pencil),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedDateTime == null
                            ? 'No date/time selected'
                            : DateFormat(
                              'MMM d, yyyy – h:mm a',
                            ).format(_selectedDateTime!),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickDateTime,
                      child: const Text('Pick Date & Time'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveReminder,
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

// Copied from patient_home_dashboard.dart for use in home_screen.dart
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

// Add this after the Recent Meals card or in a logical spot in your dashboard widget tree
class RecentWorkoutsCard extends StatelessWidget {
  const RecentWorkoutsCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Implementation of the widget
    return Container(); // Placeholder return, actual implementation needed
  }
}
