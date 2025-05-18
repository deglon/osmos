import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/onboarding_controller.dart';
import '../../models/onboarding_data.dart';
import 'base_onboarding_screen.dart';
import '../../core/theme/app_text_styles.dart'; // Ensure this import is here

class EmotionScreen extends StatelessWidget {
  const EmotionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<OnboardingController>(context);

    return BaseOnboardingScreen(
      title: "How are you feeling?",
      subtitle: "Let's start by understanding your current state",
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: EmotionalState.values.map((emotion) {
          return ElevatedButton(
            onPressed: () async {
              await controller.setEmotionalState(emotion);
              Navigator.pushNamed(context, '/onboarding/role');
            },
            child: Text(
              emotion.toString().split('.').last,
              style: AppTextStyles.buttonText, // This should now be accessible
            ),
          );
        }).toList(),
      ),
    );
  }
}