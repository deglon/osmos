import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/glucose_reading_model.dart';

class GlucoseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add new glucose reading
  Future<void> addGlucoseReading(GlucoseReading reading) async {
    try {
      await _firestore.collection('glucose_readings').add(reading.toJson());
    } catch (e) {
      throw Exception('Failed to add glucose reading: $e');
    }
  }

  // Get glucose readings for a patient
  Stream<List<GlucoseReading>> getGlucoseReadings(String patientId) {
    return _firestore
        .collection('glucose_readings')
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => GlucoseReading.fromJson({
                    'id': doc.id,
                    ...doc.data(),
                  }))
              .toList();
        });
  }

  // Get readings within a date range
  Stream<List<GlucoseReading>> getReadingsInRange(
    String patientId,
    DateTime start,
    DateTime end,
  ) {
    return _firestore
        .collection('glucose_readings')
        .where('patientId', isEqualTo: patientId)
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .where('timestamp', isLessThanOrEqualTo: end)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => GlucoseReading.fromJson({
                    'id': doc.id,
                    ...doc.data(),
                  }))
              .toList();
        });
  }
}