import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/core/errors/app_failure.dart';
import 'package:medipulse/core/theme/app_colors.dart';
import 'package:medipulse/features/scanner/domain/extraction_models.dart';
import 'package:medipulse/features/scanner/domain/scanner_contracts.dart';
import 'package:medipulse/features/scanner/domain/scanner_pipeline.dart';
import 'package:medipulse/shared/widgets/app_components.dart';

class ScanCaptureScreen extends ConsumerStatefulWidget {
  const ScanCaptureScreen({super.key, required this.kind});
  final ScanKind kind;

  @override
  ConsumerState<ScanCaptureScreen> createState() => _ScanCaptureScreenState();
}

class _ScanCaptureScreenState extends ConsumerState<ScanCaptureScreen> {
  final _typed = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _imagePath;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _error = null;
    });
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 2000);
    if (file == null) return;
    setState(() => _imagePath = file.path);
  }

  Future<void> _process() async {
    if (_imagePath == null && _typed.text.trim().isEmpty) {
      setState(() => _error = 'Take a photo, choose a photo, or type the text from the label.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await ref.read(scannerPipelineProvider).process(
        imagePath: _imagePath ?? '',
        kind: widget.kind,
        typedText: _typed.text.trim().isEmpty ? null : _typed.text,
      );
      if (!mounted) return;
      context.push('/scan/review', extra: outcome);
    } catch (error) {
      setState(() {
        _error = error is AppFailure
            ? error.message
            : 'We could not process that. Try another photo or type the text you see.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prescription = widget.kind == ScanKind.prescription;
    return Scaffold(
      appBar: AppBar(title: Text(prescription ? 'Scan prescription' : 'Scan package')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            prescription ? ScannerContracts.verificationCopy : ScannerContracts.packageUncertainty,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(ScannerContracts.noSilentSave, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          AppButton(
            label: 'Take photo',
            icon: Icons.photo_camera_outlined,
            onPressed: _busy ? null : () => _pick(ImageSource.camera),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from gallery'),
          ),
          if (_imagePath != null) ...[
            const SizedBox(height: 12),
            Text('Photo selected. It is used only to read text on this device.', style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 20),
          AppTextField(
            label: 'Or type the text you see',
            controller: _typed,
            maxLines: 5,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.missed, fontSize: 16)),
          ],
          const SizedBox(height: 20),
          AppButton(label: _busy ? 'Reading…' : 'Extract details', onPressed: _busy ? null : _process),
        ],
      ),
    );
  }
}

class ScanReviewScreen extends StatelessWidget {
  const ScanReviewScreen({super.key, required this.outcome});
  final ScanOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final prescription = outcome.prescription;
    final package = outcome.package;
    return Scaffold(
      appBar: AppBar(title: const Text('Review extracted details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: AppColors.snoozedSoft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                outcome.kind == ScanKind.prescription
                    ? ScannerContracts.verificationCopy
                    : ScannerContracts.packageUncertainty,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (prescription != null) ...[
            _field('Medicine name', prescription.medicineName),
            _field('Strength', prescription.strength),
            _field('Dose', prescription.dose),
            _field('Frequency', prescription.frequency),
            _field('Times', prescription.times),
            _field('Duration', prescription.durationDays),
            _field('Food instructions', prescription.foodInstruction),
            Text('Overall confidence: ${(prescription.overallConfidence * 100).round()}%'),
          ],
          if (package != null) ...[
            _field('Medicine name', package.medicineName),
            _field('Strength', package.strength),
            _field('Manufacturer', package.manufacturer),
            _field('Form', package.form),
            _field('Expiry date', package.expiryDate),
            _field('Batch number', package.batchNumber),
            Text('Overall confidence: ${(package.overallConfidence * 100).round()}%'),
          ],
          const SizedBox(height: 16),
          Text('Detected text (for your check only):', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(outcome.ocrText.isEmpty ? 'None' : outcome.ocrText, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          AppButton(
            label: 'Use these details',
            onPressed: () => context.push('/medications/add', extra: outcome),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Scan again'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, ExtractedField field) {
    final review = field.needsReview;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: review ? AppColors.snoozedSoft : AppColors.takenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              review
                  ? '${field.value ?? 'Not found'}  ·  Needs review'
                  : field.value ?? 'Not found',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
