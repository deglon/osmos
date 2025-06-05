import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../mode_screen.dart';
import '../home_screen.dart'; // For RecentWorkoutsCard

class WellnessHomeDashboard extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback? onNavigateToModes;
  const WellnessHomeDashboard({
    Key? key,
    required this.profile,
    this.onNavigateToModes,
  }) : super(key: key);

  @override
  State<WellnessHomeDashboard> createState() => _WellnessHomeDashboardState();
}

class _WellnessHomeDashboardState extends State<WellnessHomeDashboard> {
  List<String> _tips = [];
  bool _loadingTips = true;
  String? _tipsError;

  String? _wellnessGoal;
  bool _savingGoal = false;
  int _currentTipIndex = 0;
  PageController? _tipsPageController;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _wellnessGoal = widget.profile.wellnessGoal;
    _tipsPageController = PageController(viewportFraction: 0.88);
    _fetchUserName();
    _fetchTips();
  }

  @override
  void dispose() {
    _tipsPageController?.dispose();
    super.dispose();
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

  Future<void> _fetchTips() async {
    setState(() {
      _loadingTips = true;
      _tipsError = null;
    });
    try {
      final tips = await getWellnessTipsFromAI();
      setState(() {
        _tips = tips;
        _loadingTips = false;
        _currentTipIndex = 0;
      });
    } catch (e) {
      setState(() {
        _tipsError = 'Could not load tips.';
        _loadingTips = false;
      });
    }
  }

  Future<List<String>> getWellnessTipsFromAI() async {
    const apiKey = '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';
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    final systemPrompt =
        "You are a wellness coach. Generate 5 short, actionable, and motivational wellness or fitness tips for today. Reply ONLY with a JSON array of strings, no extra text.";
    final body = jsonEncode({
      "model": "llama3-8b-8192",
      "messages": [
        {"role": "system", "content": systemPrompt},
      ],
      "max_tokens": 256,
      "temperature": 0.7,
    });
    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      // Parse the JSON array from the AI's response
      final tips = jsonDecode(content) as List<dynamic>;
      return tips.map((e) => e.toString()).toList();
    } else {
      throw Exception('Failed to fetch tips: \\${response.statusCode}');
    }
  }

  void _showTipDetail(String tip) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tips_and_updates,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    tip,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _saveWellnessGoal(String goal) async {
    setState(() => _savingGoal = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'wellnessGoal': goal,
      }, SetOptions(merge: true));
      setState(() {
        _wellnessGoal = goal;
        _savingGoal = false;
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wellness goal updated!')));
    } catch (e) {
      setState(() => _savingGoal = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showEditGoalDialog() {
    final controller = TextEditingController(text: _wellnessGoal ?? '');
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Set Your Wellness Goal'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Your goal (e.g. Lose 5kg, 10,000 steps/day, etc.)',
              ),
            ),
            actions: [
              TextButton(
                onPressed: _savingGoal ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed:
                    _savingGoal
                        ? null
                        : () {
                          if (controller.text.trim().isNotEmpty) {
                            _saveWellnessGoal(controller.text.trim());
                          }
                        },
                child:
                    _savingGoal
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showLogWorkoutDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => _LogWorkoutDialog());
  }

  void _showLogMealDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => _LogMealDialog());
  }

  void _showLogMeditationDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => _LogMeditationDialog());
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fitness Hub Header
          Text(
            "Fitness Hub",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.left,
          ),
          if (_userName != null && _userName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(
                'Hello $_userName!',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            "Let's make today a great day for your wellness journey.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),

          // Modes Card
          Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: ListTile(
              leading: Icon(
                Icons.explore,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
              title: const Text('Modes'),
              subtitle: const Text('Tap to explore your current mode'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onNavigateToModes,
            ),
          ),

          // Mood Check-in Card (functional)
          _MoodCheckInCard(),
          const SizedBox(height: 18),

          // Food Tracker Card (last 3 food logs)
          _FoodLogsCard(),
          const SizedBox(height: 18),
          const RecentWorkoutsCard(),
          const SizedBox(height: 18),

          // Wellness Goal Tracker
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _showEditGoalDialog,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Your Wellness Goal',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.edit,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _wellnessGoal ?? 'Not set',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 0.4,
                      minHeight: 8,
                    ), // Placeholder progress
                    const SizedBox(height: 8),
                    Text(
                      'Tap to edit your goal. Keep going! Small steps add up.',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Quick Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _WellnessQuickAction(
                icon: Icons.fitness_center,
                label: 'Log Workout',
                onTap: () => _showLogWorkoutDialog(context),
              ),
              _WellnessQuickAction(
                icon: Icons.restaurant,
                label: 'Log Meal',
                onTap: () => _showLogMealDialog(context),
              ),
              _WellnessQuickAction(
                icon: Icons.self_improvement,
                label: 'Log Meditation',
                onTap: () => _showLogMeditationDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // AI Tips Carousel
          if (_loadingTips) const Center(child: CircularProgressIndicator()),
          if (_tipsError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _tipsError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (!_loadingTips && _tips.isNotEmpty)
            SizedBox(
              height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
                    itemCount: _tips.length,
                    controller: _tipsPageController,
                    onPageChanged: (i) => setState(() => _currentTipIndex = i),
                    itemBuilder:
                        (context, i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: GestureDetector(
                            onTap: () => _showTipDetail(_tips[i]),
                            child: Card(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.09),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(18.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.tips_and_updates,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _tips[i],
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodyLarge,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                  ),
                  // Left arrow
                  if (_currentTipIndex > 0)
                    Positioned(
                      left: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 28),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () {
                          final newIndex = (_currentTipIndex - 1).clamp(
                            0,
                            _tips.length - 1,
                          );
                          _tipsPageController?.animateToPage(
                            newIndex,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.ease,
                          );
                          setState(() {
                            _currentTipIndex = newIndex;
                          });
                        },
                      ),
                    ),
                  // Right arrow
                  if (_currentTipIndex < _tips.length - 1)
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 28),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () {
                          final newIndex = (_currentTipIndex + 1).clamp(
                            0,
                            _tips.length - 1,
                          );
                          _tipsPageController?.animateToPage(
                            newIndex,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.ease,
                          );
                          setState(() {
                            _currentTipIndex = newIndex;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),

          // Motivational Tip (legacy, can remove if you want only AI tips)
          // Card(
          //   color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          //   shape: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.circular(16),
          //   ),
          //   child: Padding(
          //     padding: const EdgeInsets.all(16.0),
          //     child: Row(
          //       children: [
          //         Icon(
          //           Icons.lightbulb,
          //           color: Theme.of(context).colorScheme.primary,
          //         ),
          //         const SizedBox(width: 12),
          //         Expanded(
          //           child: Text(
          //             'Remember: Consistency beats intensity. Celebrate every small win!',
          //             style: Theme.of(context).textTheme.bodyMedium,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _MoodCheckInCard extends StatefulWidget {
  @override
  State<_MoodCheckInCard> createState() => _MoodCheckInCardState();
}

class _MoodCheckInCardState extends State<_MoodCheckInCard> {
  String? _selectedMood;
  bool _checkedToday = false;
  bool _isSubmitting = false;
  DateTime _today = DateTime.now();
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
    _checkMoodForToday();
  }

  String _dateKey(DateTime date) =>
      "[1m[31m[1m[31m[1m[31m${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

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
              _checkedToday ? "Mood checked in!" : "How are you feeling today?",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children:
                  _moods.map((mood) {
                    final isSelected = _selectedMood == mood["label"];
                    return GestureDetector(
                      onTap:
                          () =>
                              !_checkedToday && !_isSubmitting
                                  ? _submitMood(mood["label"])
                                  : null,
                      child: Opacity(
                        opacity: _checkedToday && !isSelected ? 0.4 : 1.0,
                        child: Column(
                          children: [
                            Icon(mood["icon"], size: 36, color: mood["color"]),
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

class _WellnessQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _WellnessQuickAction({
    required this.icon,
    required this.label,
    this.onTap,
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

// Dialogs for logging actions
class _LogWorkoutDialog extends StatefulWidget {
  @override
  State<_LogWorkoutDialog> createState() => _LogWorkoutDialogState();
}

class _LogWorkoutDialogState extends State<_LogWorkoutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _typeController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _typeController.dispose();
    _durationController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .add({
            'type': _typeController.text.trim(),
            'duration': _durationController.text.trim(),
            'calories': _caloriesController.text.trim(),
            'timestamp': DateTime.now(),
          });
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Workout logged!')));
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log Workout'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _typeController,
              decoration: const InputDecoration(labelText: 'Type (e.g. Run)'),
              validator: (v) => v == null || v.isEmpty ? 'Enter type' : null,
            ),
            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration (min)'),
              keyboardType: TextInputType.number,
              validator:
                  (v) => v == null || v.isEmpty ? 'Enter duration' : null,
            ),
            TextFormField(
              controller: _caloriesController,
              decoration: const InputDecoration(labelText: 'Calories'),
              keyboardType: TextInputType.number,
              validator:
                  (v) => v == null || v.isEmpty ? 'Enter calories' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveWorkout,
          child:
              _isSaving
                  ? const CircularProgressIndicator()
                  : const Text('Save'),
        ),
      ],
    );
  }
}

class _LogMealDialog extends StatefulWidget {
  @override
  State<_LogMealDialog> createState() => _LogMealDialogState();
}

class _LogMealDialogState extends State<_LogMealDialog> {
  final _formKey = GlobalKey<FormState>();
  final _mealController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _mealController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveMeal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .add({
            'meal': _mealController.text.trim(),
            'amount': _amountController.text.trim(),
            'timestamp': DateTime.now(),
          });
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Meal logged!')));
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log Meal'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _mealController,
              decoration: const InputDecoration(labelText: 'Meal (e.g. Salad)'),
              validator: (v) => v == null || v.isEmpty ? 'Enter meal' : null,
            ),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveMeal,
          child:
              _isSaving
                  ? const CircularProgressIndicator()
                  : const Text('Save'),
        ),
      ],
    );
  }
}

class _LogMeditationDialog extends StatefulWidget {
  @override
  State<_LogMeditationDialog> createState() => _LogMeditationDialogState();
}

class _LogMeditationDialogState extends State<_LogMeditationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveMeditation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meditations')
          .add({
            'duration': _durationController.text.trim(),
            'notes': _notesController.text.trim(),
            'timestamp': DateTime.now(),
          });
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Meditation logged!')));
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log Meditation'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration (min)'),
              keyboardType: TextInputType.number,
              validator:
                  (v) => v == null || v.isEmpty ? 'Enter duration' : null,
            ),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveMeditation,
          child:
              _isSaving
                  ? const CircularProgressIndicator()
                  : const Text('Save'),
        ),
      ],
    );
  }
}

// Food Tracker Card for wellness users
class _FoodLogsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }
    // Fetch both 'meals' and 'food_logs', merge, sort, and show 3 most recent
    final mealsStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meals')
            .orderBy('timestamp', descending: true)
            .limit(3)
            .snapshots();
    final foodLogsStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('food_logs')
            .orderBy('dateTime', descending: true)
            .limit(3)
            .snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: mealsStream,
      builder: (context, mealsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: foodLogsStream,
          builder: (context, foodLogsSnapshot) {
            if (mealsSnapshot.connectionState == ConnectionState.waiting ||
                foodLogsSnapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(18.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final mealsDocs = mealsSnapshot.data?.docs ?? [];
            final foodLogsDocs = foodLogsSnapshot.data?.docs ?? [];
            // Normalize and merge
            final List<_FoodLogEntry> entries = [
              ...mealsDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _FoodLogEntry(
                  name: data['meal'] ?? 'Meal',
                  amount: data['amount'] ?? '',
                  timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
                );
              }),
              ...foodLogsDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _FoodLogEntry(
                  name:
                      data['foodName'] ??
                      (data['foods'] is List && data['foods'].isNotEmpty
                          ? data['foods'][0]
                          : 'Food'),
                  amount: data['amount'] ?? '',
                  timestamp: (data['dateTime'] as Timestamp?)?.toDate(),
                );
              }),
            ];
            entries.removeWhere((e) => e.timestamp == null);
            entries.sort((a, b) => b.timestamp!.compareTo(a.timestamp!));
            final recent = entries.take(3).toList();
            if (recent.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Text(
                    'No recent meals logged yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
                          'Recent Meals',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...recent.map((entry) {
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
            );
          },
        );
      },
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
