import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medipulse/core/constants/legal_copy.dart';
import 'package:medipulse/core/di/app_controllers.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/shared/widgets/app_components.dart';

class RefillScreen extends ConsumerStatefulWidget {
  const RefillScreen({super.key, required this.medicationId});
  final String medicationId;

  @override
  ConsumerState<RefillScreen> createState() => _RefillScreenState();
}

class _RefillScreenState extends ConsumerState<RefillScreen> {
  final _quantity = TextEditingController();
  final _threshold = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _quantity.dispose();
    _threshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ref.read(medicationRepositoryProvider).getById(widget.medicationId),
      builder: (context, snapshot) {
        final med = snapshot.data;
        if (med == null) {
          return const Scaffold(body: LoadingState());
        }
        if (_quantity.text.isEmpty && med.quantity != null) {
          _quantity.text = med.quantity!.toString();
        }
        if (_threshold.text.isEmpty && med.refillThreshold != null) {
          _threshold.text = med.refillThreshold!.toString();
        }
        final estimate = ref.read(refillCalculatorProvider).estimate(med);
        return Scaffold(
          appBar: AppBar(title: const Text('Supply')),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  estimate.remainingDoses == null
                      ? 'Quantity is not tracked yet.'
                      : 'Approximately ${estimate.remainingDoses} doses remaining.',
                ),
                const SizedBox(height: 16),
                AppTextField(label: 'Current quantity', controller: _quantity, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                AppTextField(label: 'Warn when quantity drops to', controller: _threshold, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                Text(LegalCopy.refillDisclaimer, style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                AppButton(
                  label: _busy ? 'Saving…' : 'Save',
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await ref.read(medicationCoordinatorProvider).saveMedication(
                            med.copyWith(
                              quantity: double.tryParse(_quantity.text),
                              refillThreshold: double.tryParse(_threshold.text),
                            ),
                          );
                          ref.invalidate(homeSnapshotProvider);
                          if (context.mounted) context.pop();
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
