import 'package:medipulse/shared/models/entities.dart';

class RefillCalculator {
  RefillEstimate estimate(Medication medication) {
    final quantity = medication.quantity;
    if (quantity == null) {
      return const RefillEstimate(remainingDoses: null, warning: false);
    }
    if (medication.doseAmount <= 0) {
      return const RefillEstimate(remainingDoses: null, warning: false);
    }
    final remaining = (quantity / medication.doseAmount).floor();
    final thresholdDoses = medication.refillThreshold == null
        ? null
        : (medication.refillThreshold! / medication.doseAmount).floor();
    final warning = thresholdDoses != null && remaining <= thresholdDoses;
    return RefillEstimate(remainingDoses: remaining, warning: warning);
  }
}
