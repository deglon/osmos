import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfile? _profile;
  UserProfile? get profile => _profile;

  Future<void> fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[UserProfileProvider] No user logged in.');
      _profile = null;
      notifyListeners();
      return;
    }
    try {
      debugPrint('[UserProfileProvider] Fetching user profile for ${user.uid}');
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        final data = doc.data()!;
        debugPrint('[UserProfileProvider] User doc found: $data');
        // If userType is missing, set a default
        if (data['userType'] == null) {
          debugPrint(
            '[UserProfileProvider] userType missing, setting to "Patient"',
          );
          data['userType'] = 'Patient';
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'userType': 'Patient'}, SetOptions(merge: true));
        }
        _profile = UserProfile.fromMap(data);
      } else {
        debugPrint(
          '[UserProfileProvider] User doc missing, creating default profile.',
        );
        // Create a default profile
        final defaultData = {'userType': 'Patient'};
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(defaultData);
        _profile = UserProfile.fromMap(defaultData);
      }
      notifyListeners();
    } catch (e, stack) {
      debugPrint(
        '[UserProfileProvider] Error fetching user profile: $e\n$stack',
      );
      // Set a default profile so the app can proceed
      _profile = UserProfile(userType: 'Patient');
      notifyListeners();
    }
  }
}
