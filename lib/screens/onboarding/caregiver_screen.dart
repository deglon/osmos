import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/onboarding_controller.dart';
import '../../models/onboarding_data.dart';
import 'base_onboarding_screen.dart';

class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({Key? key}) : super(key: key);

  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  final _roleController = TextEditingController();
  final _needsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<OnboardingController>(context);
    
    return BaseOnboardingScreen(
      title: "Your Caregiving Role",
      subtitle: "Help us understand your caregiving needs",
      child: Column(
        children: [
          TextField(
            controller: _roleController,
            decoration: const InputDecoration(
              labelText: 'What is your caregiving role?',
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _needsController,
            decoration: const InputDecoration(
              labelText: 'What support do you need most?',
            ),
            maxLines: 3,
          ),
        ],
      ),
      onNext: () async {
        await controller.completeOnboarding();
        Navigator.pushReplacementNamed(context, '/home');
      },
    );
  }
}