class UserProfile {
  final String userType;
  final String? primaryCondition;
  final String? mainChallenge;
  final String? wellnessGoal;
  final String? wellnessObstacle;
  final String? careRole;
  final String? careNeeds;

  UserProfile({
    required this.userType,
    this.primaryCondition,
    this.mainChallenge,
    this.wellnessGoal,
    this.wellnessObstacle,
    this.careRole,
    this.careNeeds,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      userType: data['userType'] ?? '',
      primaryCondition: data['primaryCondition'],
      mainChallenge: data['mainChallenge'],
      wellnessGoal: data['wellnessGoal'],
      wellnessObstacle: data['wellnessObstacle'],
      careRole: data['careRole'],
      careNeeds: data['careNeeds'],
    );
  }
}
