import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  patient,
  wellness,
  caregiver,
}

enum EmotionalState {
  tired,
  hopeful,
  anxious,
  confused,
  frustrated,
  motivated,
}

class OnboardingData {
  final EmotionalState? emotionalState;
  final UserRole? userRole;
  final String? primaryCondition;
  final String? mainChallenge;
  final String? wellnessGoal;
  final String? wellnessObstacle;
  final String? careRole;
  final String? careNeeds;
  final bool isComplete;

  OnboardingData({
    this.emotionalState,
    this.userRole,
    this.primaryCondition,
    this.mainChallenge,
    this.wellnessGoal,
    this.wellnessObstacle,
    this.careRole,
    this.careNeeds,
    this.isComplete = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'emotionalState': emotionalState?.toString(),
      'userRole': userRole?.toString(),
      'primaryCondition': primaryCondition,
      'mainChallenge': mainChallenge,
      'wellnessGoal': wellnessGoal,
      'wellnessObstacle': wellnessObstacle,
      'careRole': careRole,
      'careNeeds': careNeeds,
      'isComplete': isComplete,
    };
  }
}