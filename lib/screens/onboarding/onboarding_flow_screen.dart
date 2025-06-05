import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/onboarding_controller.dart';

class OnboardingFlowScreen extends StatelessWidget {
  const OnboardingFlowScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingController>(
      builder: (context, controller, _) {
        try {
          final step = controller.currentStepData;
          final totalSteps = controller.totalProgressSteps;
          final currentStep = controller.currentProgressStep;
          switch (step['type']) {
            case 'static':
              return _WelcomeStep(
                step: step,
                onNext: controller.nextStep,
                currentStep: currentStep,
                totalSteps: totalSteps,
              );
            case 'single-select':
              return _SingleSelectStep(
                step: step,
                onSelect: controller.saveAndNext,
                currentStep: currentStep,
                totalSteps: totalSteps,
              );
            case 'confirmation':
              return _ConfirmationStep(
                step: step,
                onConfirm: () async {
                  await controller.completeOnboarding();
                  Navigator.pushReplacementNamed(context, '/home');
                },
              );
            default:
              return const Scaffold(body: Center(child: Text('Unknown step')));
          }
        } catch (e, stack) {
          return Scaffold(
            body: Center(
              child: Text(
                'An error occurred in onboarding: $e',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
      },
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  final Map<String, dynamic> step;
  final VoidCallback onNext;
  final int currentStep;
  final int totalSteps;
  const _WelcomeStep({
    required this.step,
    required this.onNext,
    required this.currentStep,
    required this.totalSteps,
  });
  @override
  Widget build(BuildContext context) {
    final firstName =
        Provider.of<OnboardingController>(context, listen: false).firstName;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: currentStep / totalSteps,
              backgroundColor: Colors.grey[200],
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 32),
            const Spacer(),
            Text(
              step['title'].replaceAll('{{firstName}}', firstName ?? ''),
              style: Theme.of(context).textTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              step['subtitle'],
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: onNext,
              child: const Text('Get Started'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleSelectStep extends StatelessWidget {
  final Map<String, dynamic> step;
  final Function(String) onSelect;
  final int currentStep;
  final int totalSteps;
  const _SingleSelectStep({
    required this.step,
    required this.onSelect,
    required this.currentStep,
    required this.totalSteps,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: currentStep / totalSteps,
              backgroundColor: Colors.grey[200],
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 32),
            const Spacer(),
            Text(
              step['question'],
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ...List.generate(step['options'].length, (i) {
              final option =
                  step['options'][i] is String
                      ? step['options'][i]
                      : step['options'][i]['label'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton(
                  onPressed: () => onSelect(option),
                  child: Text(option),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 18),
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationStep extends StatelessWidget {
  final Map<String, dynamic> step;
  final Future<void> Function() onConfirm;
  const _ConfirmationStep({required this.step, required this.onConfirm});
  @override
  Widget build(BuildContext context) {
    final firstName =
        Provider.of<OnboardingController>(context, listen: false).firstName;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              step['title'].replaceAll('{{firstName}}', firstName ?? ''),
              style: Theme.of(context).textTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              step['message'].replaceAll('{{firstName}}', firstName ?? ''),
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () async {
                await onConfirm();
                // Navigation handled in onConfirm
              },
              child: const Text('Go to Dashboard'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
