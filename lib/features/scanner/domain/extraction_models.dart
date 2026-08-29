class ExtractedField {
  const ExtractedField({this.value, this.confidence = 0});

  final String? value;
  final double confidence;

  bool get needsReview => confidence < 0.7 || value == null || value!.trim().isEmpty;
}

class PrescriptionExtraction {
  const PrescriptionExtraction({
    required this.medicineName,
    required this.strength,
    required this.dose,
    required this.frequency,
    required this.times,
    required this.durationDays,
    required this.foodInstruction,
    required this.additionalInstructions,
    required this.overallConfidence,
    required this.sourceText,
  });

  final ExtractedField medicineName;
  final ExtractedField strength;
  final ExtractedField dose;
  final ExtractedField frequency;
  final ExtractedField times;
  final ExtractedField durationDays;
  final ExtractedField foodInstruction;
  final ExtractedField additionalInstructions;
  final double overallConfidence;
  final String sourceText;

  Map<String, dynamic> toJson() => {
    'medicineName': medicineName.value,
    'strength': strength.value,
    'dose': dose.value,
    'frequency': frequency.value,
    'times': times.value,
    'durationDays': durationDays.value,
    'foodInstruction': foodInstruction.value,
    'additionalInstructions': additionalInstructions.value,
    'confidence': overallConfidence,
  };
}

class PackageExtraction {
  const PackageExtraction({
    required this.medicineName,
    required this.strength,
    required this.manufacturer,
    required this.form,
    required this.expiryDate,
    required this.batchNumber,
    required this.overallConfidence,
    required this.sourceText,
  });

  final ExtractedField medicineName;
  final ExtractedField strength;
  final ExtractedField manufacturer;
  final ExtractedField form;
  final ExtractedField expiryDate;
  final ExtractedField batchNumber;
  final double overallConfidence;
  final String sourceText;
}

enum ScanKind { prescription, package }
