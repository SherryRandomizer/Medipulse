import 'package:shared_preferences/shared_preferences.dart';
import 'package:medipulse/core/notifications/pending_dose_action.dart';

class PendingDoseActionStore {
  static const key = 'pending_dose_action';

  Future<void> save({required String actionId, required String doseId}) async {
    if (actionId.isEmpty || doseId.isEmpty || actionId == 'open') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      PendingDoseActionCodec.encode(actionId: actionId, doseId: doseId),
    );
  }

  Future<({String actionId, String doseId})?> take() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    await prefs.remove(key);
    return PendingDoseActionCodec.decode(raw);
  }
}
