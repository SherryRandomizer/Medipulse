import 'package:medipulse/features/scanner/domain/extraction_models.dart';
import 'package:medipulse/shared/models/entities.dart';

/// Pulls structured fields from OCR text only. Does not use a medicine database.
class HeuristicExtractor {
  PrescriptionExtraction extractPrescription(String raw) {
    final text = raw.replaceAll('\r', '\n');
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final lower = text.toLowerCase();

    final strength = _field(_match(lower, RegExp(r'(\d+(?:\.\d+)?\s?(mg|mcg|g|ml|iu))\b')), 0.82);
    final dose = _field(_match(lower, RegExp(r'(\d+(?:\.\d+)?\s?(tablet|tablets|capsule|capsules|puff|puffs|ml|drop|drops))\b')), 0.8);
    final frequency = _frequency(lower);
    final times = _times(lower, frequency.value);
    final duration = _field(_match(lower, RegExp(r'(\d+)\s*(day|days|week|weeks)')), 0.72);
    final food = _food(lower);
    final extra = _field(_instructionLine(lines), 0.55);
    final name = _medicineName(lines, lower);

    final fields = [name, strength, dose, frequency, times, duration, food];
    final scores = fields.map((f) => f.confidence).where((c) => c > 0).toList();
    final overall = scores.isEmpty ? 0.2 : scores.reduce((a, b) => a + b) / scores.length;

    return PrescriptionExtraction(
      medicineName: name,
      strength: strength,
      dose: dose,
      frequency: frequency,
      times: times,
      durationDays: duration,
      foodInstruction: food,
      additionalInstructions: extra,
      overallConfidence: overall.clamp(0, 0.95),
      sourceText: raw,
    );
  }

  PackageExtraction extractPackage(String raw) {
    final text = raw.replaceAll('\r', '\n');
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final lower = text.toLowerCase();
    final name = _medicineName(lines, lower);
    final strength = _field(_match(lower, RegExp(r'(\d+(?:\.\d+)?\s?(mg|mcg|g|ml|iu))\b')), 0.8);
    final manufacturer = _field(_manufacturer(lines), 0.7);
    final form = _field(_form(lower), 0.75);
    final expiry = _field(_match(text, RegExp(r'(?:exp(?:iry)?|best before)[^\d]{0,8}(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})', caseSensitive: false)), 0.78);
    final batch = _field(_match(text, RegExp(r'(?:batch|lot|b\.?no\.?)[^\w]{0,6}([A-Za-z0-9\-]{3,})', caseSensitive: false)), 0.74);
    final scores = [name, strength, manufacturer, form, expiry, batch].map((f) => f.confidence);
    final overall = scores.reduce((a, b) => a + b) / 6;
    return PackageExtraction(
      medicineName: name,
      strength: strength,
      manufacturer: manufacturer,
      form: form,
      expiryDate: expiry,
      batchNumber: batch,
      overallConfidence: overall.clamp(0, 0.85),
      sourceText: raw,
    );
  }

  FrequencyType? frequencyType(String? label) {
    final value = label?.toLowerCase() ?? '';
    if (value.contains('as needed') || value.contains('prn')) return FrequencyType.asNeeded;
    if (value.contains('four times')) return FrequencyType.fourTimesDaily;
    if (value.contains('three times')) return FrequencyType.threeTimesDaily;
    if (value.contains('twice') || value.contains('two times')) return FrequencyType.twiceDaily;
    if (value.contains('once')) return FrequencyType.onceDaily;
    if (value.contains('every') && value.contains('hour')) return FrequencyType.everyXHours;
    if (value.contains('week')) return FrequencyType.weekly;
    if (value.contains('month')) return FrequencyType.monthly;
    return null;
  }

  ExtractedField _frequency(String lower) {
    if (RegExp(r'as needed|when needed|\bprn\b').hasMatch(lower)) {
      return const ExtractedField(value: 'as needed (PRN)', confidence: 0.8);
    }
    if (RegExp(r'four times daily|4 times a day|\bqid\b').hasMatch(lower)) {
      return const ExtractedField(value: 'four times daily', confidence: 0.86);
    }
    if (RegExp(r'three times daily|3 times a day|\btid\b').hasMatch(lower)) {
      return const ExtractedField(value: 'three times daily', confidence: 0.86);
    }
    if (RegExp(r'twice daily|two times a day|\bbid\b').hasMatch(lower)) {
      return const ExtractedField(value: 'twice daily', confidence: 0.86);
    }
    if (RegExp(r'once daily|once a day|\bod\b').hasMatch(lower)) {
      return const ExtractedField(value: 'once daily', confidence: 0.86);
    }
    final every = RegExp(r'every\s+(\d+)\s+hours?').firstMatch(lower);
    if (every != null) {
      return ExtractedField(value: 'every ${every.group(1)} hours', confidence: 0.84);
    }
    return const ExtractedField(confidence: 0.2);
  }

  ExtractedField _times(String lower, String? frequency) {
    final matches = RegExp(r'\b(\d{1,2}[:.]\d{2}\s*(am|pm)?)\b').allMatches(lower).toList();
    if (matches.isNotEmpty) {
      final values = matches.map((m) => m.group(1)!.replaceAll('.', ':')).toList();
      return ExtractedField(value: values.join(', '), confidence: 0.8);
    }
    if (frequency != null && frequency.contains('twice')) {
      return const ExtractedField(value: '08:00, 20:00', confidence: 0.45);
    }
    if (frequency != null && frequency.contains('once')) {
      return const ExtractedField(value: '08:00', confidence: 0.45);
    }
    return const ExtractedField(confidence: 0.2);
  }

  ExtractedField _food(String lower) {
    final after = RegExp(r'after (meals|food|breakfast|lunch|dinner)').firstMatch(lower);
    if (after != null) {
      return ExtractedField(value: after.group(0), confidence: 0.8);
    }
    final before = RegExp(r'before (meals|food|breakfast|lunch|dinner)').firstMatch(lower);
    if (before != null) {
      return ExtractedField(value: before.group(0), confidence: 0.8);
    }
    if (lower.contains('with food') || lower.contains('with meals')) {
      return const ExtractedField(value: 'with food', confidence: 0.78);
    }
    if (lower.contains('empty stomach')) {
      return const ExtractedField(value: 'on an empty stomach', confidence: 0.78);
    }
    return const ExtractedField(confidence: 0.2);
  }

  ExtractedField _medicineName(List<String> lines, String lower) {
    const skip = [
      'hospital',
      'clinic',
      'prescription',
      'rx',
      'doctor',
      'patient',
      'date',
      'age',
      'address',
      'phone',
      'sig',
      'refill',
    ];
    for (final line in lines) {
      final l = line.toLowerCase();
      if (skip.any(l.contains)) continue;
      if (RegExp(r'^\d').hasMatch(line)) continue;
      if (line.length < 3 || line.length > 60) continue;
      if (!RegExp(r'[A-Za-z]').hasMatch(line)) continue;
      return ExtractedField(value: line, confidence: 0.62);
    }
    return const ExtractedField(confidence: 0.15);
  }

  String? _manufacturer(List<String> lines) {
    for (final line in lines) {
      if (RegExp(r'(ltd|inc|pharma|laborator|gmbh|pvt)', caseSensitive: false).hasMatch(line)) {
        return line;
      }
    }
    return null;
  }

  String? _form(String lower) {
    for (final form in MedicationForm.values) {
      if (lower.contains(form.name) || lower.contains(form.label.toLowerCase())) {
        return form.label;
      }
    }
    return null;
  }

  String? _instructionLine(List<String> lines) {
    for (final line in lines) {
      final l = line.toLowerCase();
      if (l.contains('avoid') || l.contains('do not') || l.contains('shake') || l.contains('store')) {
        return line;
      }
    }
    return null;
  }

  ExtractedField _field(String? value, double confidence) {
    if (value == null || value.trim().isEmpty) return const ExtractedField(confidence: 0.15);
    return ExtractedField(value: value.trim(), confidence: confidence);
  }

  String? _match(String source, RegExp pattern) {
    final match = pattern.firstMatch(source);
    if (match == null) return null;
    return match.group(1) ?? match.group(0);
  }
}
