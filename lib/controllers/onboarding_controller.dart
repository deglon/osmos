import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingController extends ChangeNotifier {
  final List<Map<String, dynamic>> _steps = [
    {
      'id': 'welcome',
      'type': 'static',
      'title': "Welcome, {{firstName}}!",
      'subtitle': "Let's get to know you so we can tailor Osmos to your needs.",
      'next': 'emotion',
    },
    {
      'id': 'emotion',
      'type': 'single-select',
      'question': 'How are you feeling about your health ?',
      'options': [
        'Tired',
        'Hopeful',
        'Anxious',
        'Confused',
        'Frustrated',
        'Motivated',
      ],
      'saveAs': 'userEmotion',
      'next': 'role',
    },
    {
      'id': 'role',
      'type': 'single-select',
      'question': 'What brings you to Osmos?',
      'options': [
        {'label': 'Manage a health condition', 'value': 'Patient'},
        {'label': 'Improve my wellness', 'value': 'Wellness'},
        {'label': 'Support someone else', 'value': 'Caregiver'},
      ],
      'saveAs': 'userType',
      'nextByValue': {
        'Patient': 'patient_condition',
        'Wellness': 'wellness_goal',
        'Caregiver': 'care_role',
      },
    },
    // Patient path
    {
      'id': 'patient_condition',
      'type': 'single-select',
      'question': 'Which condition are you managing?',
      'options': [
        'Diabetes (Type 1)',
        'Diabetes (Type 2)',
        'Hypertension',
        'Chronic Pain',
        'Other',
      ],
      'saveAs': 'primaryCondition',
      'next': 'patient_challenge',
    },
    {
      'id': 'patient_challenge',
      'type': 'single-select',
      'question': "What's your biggest challenge right now?",
      'options': [
        'Managing symptoms',
        'Remembering medication',
        'Staying consistent',
        'Understanding patterns',
      ],
      'saveAs': 'mainChallenge',
      'next': 'confirm',
    },
    // Wellness path
    {
      'id': 'wellness_goal',
      'type': 'single-select',
      'question': 'What do you want to focus on first?',
      'options': ['Better sleep', 'Nutrition', 'Fitness', 'Stress'],
      'saveAs': 'wellnessGoal',
      'next': 'wellness_obstacle',
    },
    {
      'id': 'wellness_obstacle',
      'type': 'single-select',
      'question': "What's been getting in the way?",
      'options': ['Motivation', 'Time', 'Clarity / information', 'Other'],
      'saveAs': 'wellnessObstacle',
      'next': 'confirm',
    },
    // Caregiver path
    {
      'id': 'care_role',
      'type': 'single-select',
      'question': 'Who are you supporting?',
      'options': ['Parent', 'Partner', 'Child', 'Other'],
      'saveAs': 'careRole',
      'next': 'care_needs',
    },
    {
      'id': 'care_needs',
      'type': 'single-select',
      'question': 'What kind of help do you need?',
      'options': [
        'Reminders',
        'Health tracking',
        'Communication with professionals',
        'Care coordination',
      ],
      'saveAs': 'careNeeds',
      'next': 'confirm',
    },
    // Confirmation
    {
      'id': 'confirm',
      'type': 'confirmation',
      'title': "You're all set!",
      'message': "Thanks, {{firstName}}. Osmos is now tailored to your needs.",
    },
  ];

  int _currentStepIndex = 0;
  final Map<String, dynamic> _answers = {};

  String? get firstName {
    // Try to get from Firebase user displayName, fallback to empty string
    final user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        user.displayName != null &&
        user.displayName!.isNotEmpty) {
      return user.displayName!.split(' ').first;
    }
    return null;
  }

  Map<String, dynamic> get currentStepData => _steps[_currentStepIndex];

  void nextStep() {
    final step = _steps[_currentStepIndex];
    String? nextId = step['next'];
    if (nextId == null && step['type'] == 'confirmation') return;
    _goToStepById(nextId);
  }

  void saveAndNext(String value) {
    final step = _steps[_currentStepIndex];
    final saveAs = step['saveAs'];
    if (saveAs != null) {
      // For role, save value not label
      if (step['id'] == 'role') {
        final selected = step['options']
            .cast<Map<String, dynamic>>()
            .firstWhere(
              (o) => o['label'] == value,
              orElse: () => <String, dynamic>{},
            );
        _answers[saveAs] = selected != null ? selected['value'] : value;
      } else {
        _answers[saveAs] = value;
      }
    }
    // Branching logic
    String? nextId;
    if (step['nextByValue'] != null) {
      final branchValue = _answers[saveAs];
      nextId = step['nextByValue'][branchValue];
    } else {
      nextId = step['next'];
    }
    _goToStepById(nextId);
  }

  void _goToStepById(String? id) {
    if (id == null) return;
    final idx = _steps.indexWhere((s) => s['id'] == id);
    if (idx != -1) {
      _currentStepIndex = idx;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final data = {..._answers, 'onboardingComplete': true};
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
    // Navigate to dashboard/home
    notifyListeners();
  }

  int get totalProgressSteps {
    // Exclude confirmation step
    return _steps.where((s) => s['type'] != 'confirmation').length;
  }

  int get currentProgressStep {
    // 1-based index, excluding confirmation step
    int count = 0;
    for (int i = 0; i <= _currentStepIndex; i++) {
      if (_steps[i]['type'] != 'confirmation') {
        count++;
      }
    }
    return count;
  }

  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = doc.data();
      if (data != null) {
        final userType = data['userType'];
        final emotion = data['userEmotion'];
      }
    }
  }
}
