import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';

class BaseOnboardingScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onNext;
  final bool showNextButton;
  final String nextButtonText;

  const BaseOnboardingScreen({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onNext,
    this.showNextButton = true,
    this.nextButtonText = "Next",
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.heading1),
              const SizedBox(height: 8),
              Text(subtitle, style: AppTextStyles.bodyLarge),
              const SizedBox(height: 32),
              Expanded(child: child),
              if (showNextButton)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(nextButtonText, style: AppTextStyles.buttonText),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}