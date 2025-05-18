import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/onboarding_data.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingData _data = OnboardingData();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  OnboardingData get data => _data;

  Future<void> setEmotionalState(EmotionalState state) async {
    _data = OnboardingData(
      emotionalState: state,
      userRole: _data.userRole,
      primaryCondition: _data.primaryCondition,
      mainChallenge: _data.mainChallenge,
      wellnessGoal: _data.wellnessGoal,
      wellnessObstacle: _data.wellnessObstacle,
      careRole: _data.careRole,
      careNeeds: _data.careNeeds,
    );
    notifyListeners();
    await _saveToFirestore();
  }

  Future<void> setUserRole(UserRole role) async {
    _data = OnboardingData(
      emotionalState: _data.emotionalState,
      userRole: role,
      primaryCondition: _data.primaryCondition,
      mainChallenge: _data.mainChallenge,
      wellnessGoal: _data.wellnessGoal,
      wellnessObstacle: _data.wellnessObstacle,
      careRole: _data.careRole,
      careNeeds: _data.careNeeds,
    );
    notifyListeners();
    await _saveToFirestore();
  }

  Future<void> completeOnboarding() async {
    _data = OnboardingData(
      emotionalState: _data.emotionalState,
      userRole: _data.userRole,
      primaryCondition: _data.primaryCondition,
      mainChallenge: _data.mainChallenge,
      wellnessGoal: _data.wellnessGoal,
      wellnessObstacle: _data.wellnessObstacle,
      careRole: _data.careRole,
      careNeeds: _data.careNeeds,
      isComplete: true,
    );
    await _saveToFirestore();
    notifyListeners();
  }

  Future<void> _saveToFirestore() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(_data.toJson(), SetOptions(merge: true));
    }
  }
}