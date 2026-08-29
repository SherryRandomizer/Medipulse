class PendingDoseActionCodec {
  static String encode({required String actionId, required String doseId}) {
    return '$actionId|$doseId';
  }

  static ({String actionId, String doseId})? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final index = raw.indexOf('|');
    if (index <= 0 || index == raw.length - 1) return null;
    return (actionId: raw.substring(0, index), doseId: raw.substring(index + 1));
  }
}
