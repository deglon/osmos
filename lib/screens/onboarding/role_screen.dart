import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/onboarding_controller.dart';
import '../../models/onboarding_data.dart';
import 'base_onboarding_screen.dart';
import '../../core/theme/app_text_styles.dart'; // Ensure this import is here

class RoleScreen extends StatelessWidget {
  const RoleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<OnboardingController>(context);

    return BaseOnboardingScreen(
      title: "What brings you to Osmos?",
      subtitle: "Choose your primary focus",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons full width
        children: UserRole.values.map((role) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton(
              onPressed: () async {
                await controller.setUserRole(role);
                _navigateBasedOnRole(context, role);
              },
              style: ElevatedButton.styleFrom(
                 padding: const EdgeInsets.symmetric(vertical: 16), // Add padding
              ),
              child: Text(
                _getRoleDescription(role),
                style: AppTextStyles.buttonText,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return "Manage a health condition";
      case UserRole.wellness:
        return "Improve my wellness";
      case UserRole.caregiver:
        return "Support someone else";
    }
  }

  void _navigateBasedOnRole(BuildContext context, UserRole role) {
    switch (role) {
      case UserRole.patient:
        Navigator.pushNamed(context, '/onboarding/patient');
        break;
      case UserRole.wellness:
        Navigator.pushNamed(context, '/onboarding/wellness');
        break;
      case UserRole.caregiver:
        Navigator.pushNamed(context, '/onboarding/caregiver');
        break;
    }
  }
}