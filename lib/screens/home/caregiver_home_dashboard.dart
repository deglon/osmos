import 'package:flutter/material.dart';
import '../../models/user_profile.dart';

class CaregiverHomeDashboard extends StatelessWidget {
  final UserProfile profile;
  const CaregiverHomeDashboard({Key? key, required this.profile})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome, Caregiver!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text('Supporting: ${profile.careRole ?? "Not set"}'),
            Text('Needs: ${profile.careNeeds ?? "Not set"}'),
            const SizedBox(height: 32),
            const Text('Caregiver-specific widgets go here.'),
          ],
        ),
      ),
    );
  }
}
