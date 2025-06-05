import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Fetch current user's profile data
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  // Update current user's profile data
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }
}
