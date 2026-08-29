import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:medipulse/core/constants/legal_copy.dart';
import 'package:medipulse/shared/models/entities.dart';

class ReportPdfBuilder {
  Future<Uint8List> build({
    required String patientName,
    required DateTime from,
    required DateTime to,
    required List<Medication> medications,
    required AdherenceSummary summary,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text('MediPulse adherence report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Patient: ${patientName.isEmpty ? 'Not provided' : patientName}'),
          pw.Text(
            'Period: ${from.toIso8601String().split('T').first} to ${to.toIso8601String().split('T').first}',
          ),
          pw.SizedBox(height: 12),
          pw.Text('Medication list', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          if (medications.isEmpty) pw.Text('No medications in this period.'),
          for (final med in medications)
            pw.Bullet(text: '${med.name}${med.strength == null ? '' : ' (${med.strength})'} — ${med.doseLabel}'),
          pw.SizedBox(height: 12),
          pw.Text('Scheduled doses: ${summary.scheduled}'),
          pw.Text('Taken: ${summary.taken}'),
          pw.Text('Missed: ${summary.missed}'),
          pw.Text('Skipped: ${summary.skipped}'),
          pw.Text('Adherence: ${summary.completed == 0 ? 'n/a' : '${summary.percentage.round()}%'}'),
          pw.SizedBox(height: 16),
          pw.Text(LegalCopy.reportDisclaimer, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(LegalCopy.medicalDisclaimer, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
    return doc.save();
  }
}
