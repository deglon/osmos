import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/onboarding_controller.dart';
import '../../models/onboarding_data.dart';
import 'base_onboarding_screen.dart';

class PatientScreen extends StatefulWidget {
  const PatientScreen({Key? key}) : super(key: key);

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  final _conditionController = TextEditingController();
  final _challengeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<OnboardingController>(context);
    
    return BaseOnboardingScreen(
      title: "Tell us about your health",
      subtitle: "This helps us personalize your experience",
      child: Column(
        children: [
          TextField(
            controller: _conditionController,
            decoration: const InputDecoration(
              labelText: 'What is your primary health condition?',
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _challengeController,
            decoration: const InputDecoration(
              labelText: 'What is your biggest health challenge?',
            ),
            maxLines: 3,
          ),
        ],
      ),
      onNext: () async {
        // Save data and complete onboarding
        await controller.completeOnboarding();
        Navigator.pushReplacementNamed(context, '/home');
      },
    );
  }
}