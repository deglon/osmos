import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/onboarding_controller.dart';
import '../../models/onboarding_data.dart';
import 'base_onboarding_screen.dart';
import '../../core/theme/app_text_styles.dart'; // Ensure this import is here

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({Key? key}) : super(key: key);

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  final _goalController = TextEditingController();
  final _obstacleController = TextEditingController();

  @override
  void dispose() {
    _goalController.dispose();
    _obstacleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<OnboardingController>(context);

    return BaseOnboardingScreen(
      title: "Your Wellness Journey",
      subtitle: "Let's understand your goals",
      child: Column(
        children: [
          TextField(
            controller: _goalController,
            decoration: const InputDecoration(
              labelText: 'What is your main wellness goal?',
            ),
            style: AppTextStyles.inputText, // Apply text style
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _obstacleController,
            decoration: const InputDecoration(
              labelText: 'What obstacles are you facing?',
            ),
            maxLines: 3,
            style: AppTextStyles.inputText, // Apply text style
          ),
        ],
      ),
      onNext: () async {
        // Save data
        // Note: The OnboardingController needs methods to save these specific fields
        // For now, we'll just complete onboarding and navigate
        await controller.completeOnboarding();
        Navigator.pushReplacementNamed(context, '/home');
      },
    );
  }
}