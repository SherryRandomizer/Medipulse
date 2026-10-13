import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Maps dose reminders to unique Android/iOS notification integers.
///
/// IDs are allocated sequentially in 1..0x3FFFFFFF so they cannot collide with
/// each other. They are not derived from [String.hashCode].
class ReminderAlarmRegistry {
  ReminderAlarmRegistry({ReminderAlarmStore? store})
    : _store = store ?? SharedPreferencesReminderAlarmStore();

  factory ReminderAlarmRegistry.memory([Map<String, dynamic>? seed]) {
    return ReminderAlarmRegistry(store: MemoryReminderAlarmStore(seed));
  }

  static const maxDoseNotificationId = 0x3FFFFFFF;
  static const immediateIdBase = 0x40000000;

  final ReminderAlarmStore _store;
  final Map<String, Map<String, int>> _byMedication = {};
  int _nextId = 1;
  int _nextImmediateSeq = 1;
  bool _loaded = false;

  static int immediateNotificationId(String title) {
    return immediateIdBase | (title.hashCode & 0x3FFFFFFF);
  }

  static int immediateIdForSequence(int sequence) {
    final seq = sequence < 1 ? 1 : sequence;
    return immediateIdBase | (seq & 0x3FFFFFFF);
  }

  Future<List<String>> medicationIds() async {
    await _ensureLoaded();
    return _byMedication.keys.toList(growable: false);
  }

  Future<int> allocate({required String medicationId, required String doseId}) async {
    await _ensureLoaded();
    final existing = _byMedication[medicationId]?[doseId];
    if (existing != null) return existing;
    if (_nextId > maxDoseNotificationId) {
      _nextId = 1;
    }
    var id = _nextId;
    final used = _usedIds();
    final start = id;
    while (used.contains(id)) {
      id += 1;
      if (id > maxDoseNotificationId) id = 1;
      if (id == start) {
        throw StateError('No free reminder notification IDs');
      }
    }
    _nextId = id + 1;
    _byMedication.putIfAbsent(medicationId, () => {})[doseId] = id;
    await _persist();
    return id;
  }

  Future<int?> releaseDose(String doseId) async {
    await _ensureLoaded();
    MapEntry<String, Map<String, int>>? owner;
    for (final entry in _byMedication.entries) {
      if (entry.value.containsKey(doseId)) {
        owner = entry;
        break;
      }
    }
    if (owner == null) return null;
    final id = owner.value.remove(doseId);
    if (owner.value.isEmpty) {
      _byMedication.remove(owner.key);
    }
    await _persist();
    return id;
  }

  Future<int?> idForDose(String doseId) async {
    await _ensureLoaded();
    for (final doses in _byMedication.values) {
      final id = doses[doseId];
      if (id != null) return id;
    }
    return null;
  }

  Future<List<int>> releaseMedication(String medicationId) async {
    await _ensureLoaded();
    final removed = _byMedication.remove(medicationId);
    if (removed == null || removed.isEmpty) return const [];
    await _persist();
    return removed.values.toList(growable: false);
  }

  Future<List<int>> idsForMedication(String medicationId) async {
    await _ensureLoaded();
    return List<int>.from(_byMedication[medicationId]?.values ?? const []);
  }

  Future<List<String>> doseIdsForMedication(String medicationId) async {
    await _ensureLoaded();
    return List<String>.from(_byMedication[medicationId]?.keys ?? const []);
  }

  /// Unique plugin ID in the immediate range so concurrent alerts can coexist.
  Future<int> allocateImmediate() async {
    await _ensureLoaded();
    if (_nextImmediateSeq < 1) _nextImmediateSeq = 1;
    if (_nextImmediateSeq > maxDoseNotificationId) _nextImmediateSeq = 1;
    final id = immediateIdForSequence(_nextImmediateSeq);
    _nextImmediateSeq += 1;
    await _persist();
    return id;
  }

  Set<int> _usedIds() {
    return {
      for (final doses in _byMedication.values) ...doses.values,
    };
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final data = await _store.read();
    _nextId = _asInt(data['nextId']) ?? 1;
    if (_nextId < 1 || _nextId > maxDoseNotificationId) _nextId = 1;
    _nextImmediateSeq = _asInt(data['nextImmediateSeq']) ?? 1;
    if (_nextImmediateSeq < 1 || _nextImmediateSeq > maxDoseNotificationId) {
      _nextImmediateSeq = 1;
    }
    final raw = data['byMedication'];
    _byMedication.clear();
    var changed = false;
    final used = <int>{};
    if (raw is Map) {
      for (final med in raw.entries) {
        final doses = <String, int>{};
        final value = med.value;
        if (value is Map) {
          for (final dose in value.entries) {
            final doseId = dose.key.toString();
            if (doseId.isEmpty) {
              changed = true;
              continue;
            }
            final id = _asInt(dose.value);
            if (id == null || id < 1 || id > maxDoseNotificationId) {
              changed = true;
              continue;
            }
            if (used.contains(id) || doses.containsKey(doseId)) {
              changed = true;
              continue;
            }
            used.add(id);
            doses[doseId] = id;
          }
        } else {
          changed = true;
        }
        if (doses.isNotEmpty) {
          _byMedication[med.key.toString()] = doses;
        } else {
          changed = true;
        }
      }
    } else if (raw != null) {
      changed = true;
    }
    _loaded = true;
    if (changed) await _persist();
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) {
      if (!value.isFinite || value % 1 != 0) return null;
      return value.toInt();
    }
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _persist() {
    return _store.write({
      'nextId': _nextId,
      'nextImmediateSeq': _nextImmediateSeq,
      'byMedication': {
        for (final med in _byMedication.entries)
          med.key: {for (final dose in med.value.entries) dose.key: dose.value},
      },
    });
  }
}

abstract class ReminderAlarmStore {
  Future<Map<String, dynamic>> read();
  Future<void> write(Map<String, dynamic> data);
}

class MemoryReminderAlarmStore implements ReminderAlarmStore {
  MemoryReminderAlarmStore([Map<String, dynamic>? seed]) : _data = Map<String, dynamic>.from(seed ?? {});

  Map<String, dynamic> _data;

  @override
  Future<Map<String, dynamic>> read() async => Map<String, dynamic>.from(_data);

  @override
  Future<void> write(Map<String, dynamic> data) async {
    _data = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }
}

class SharedPreferencesReminderAlarmStore implements ReminderAlarmStore {
  SharedPreferencesReminderAlarmStore({this.prefsKey = 'medipulse_reminder_alarms_v1'});

  final String prefsKey;

  @override
  Future<Map<String, dynamic>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(data));
  }
}
