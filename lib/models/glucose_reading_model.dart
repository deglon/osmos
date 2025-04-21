class GlucoseReading {
  final String id;
  final String patientId;
  final double value;
  final DateTime timestamp;
  final String notes;

  GlucoseReading({
    required this.id,
    required this.patientId,
    required this.value,
    required this.timestamp,
    this.notes = '',
  });

  factory GlucoseReading.fromJson(Map<String, dynamic> json) {
    return GlucoseReading(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      value: (json['value'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
    };
  }
}