import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:medipulse/shared/models/entities.dart';

class LocalDatabase {
  LocalDatabase({Database? override}) : _override = override;

  final Database? _override;
  Database? _db;

  Future<Database> get database async {
    if (_override != null) return _override;
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'medipulse.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE,
  password_hash TEXT,
  password_salt TEXT,
  display_name TEXT NOT NULL,
  date_of_birth TEXT,
  photo_path TEXT,
  time_zone TEXT NOT NULL,
  preferred_language TEXT NOT NULL,
  email_verified INTEGER NOT NULL,
  is_guest INTEGER NOT NULL,
  large_text INTEGER NOT NULL,
  high_contrast INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
)
''');
        await db.execute('''
CREATE TABLE notification_preferences (
  user_id TEXT PRIMARY KEY,
  enabled INTEGER NOT NULL,
  sound_enabled INTEGER NOT NULL,
  vibration_enabled INTEGER NOT NULL,
  snooze_minutes TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
        await db.execute('''
CREATE TABLE medications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  generic_name TEXT,
  strength TEXT,
  form TEXT NOT NULL,
  dose_amount REAL NOT NULL,
  dose_unit TEXT NOT NULL,
  food_instruction TEXT,
  additional_instructions TEXT,
  quantity REAL,
  refill_threshold REAL,
  doctor_name TEXT,
  notes TEXT,
  start_date TEXT NOT NULL,
  end_date TEXT,
  time_zone TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
)
''');
        await db.execute('''
CREATE TABLE medication_schedules (
  id TEXT PRIMARY KEY,
  medication_id TEXT NOT NULL UNIQUE,
  frequency TEXT NOT NULL,
  times_json TEXT NOT NULL,
  interval_hours INTEGER,
  weekdays_json TEXT,
  monthly_day INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
        await db.execute('''
CREATE TABLE medication_doses (
  id TEXT PRIMARY KEY,
  medication_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  scheduled_at TEXT NOT NULL,
  remind_at TEXT NOT NULL,
  status TEXT NOT NULL,
  snooze_count INTEGER NOT NULL,
  acted_at TEXT,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(medication_id, scheduled_at)
)
''');
        await db.execute(
          'CREATE INDEX idx_doses_user_time ON medication_doses(user_id, remind_at)',
        );
        await db.execute('''
CREATE TABLE app_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
      },
    );
    return _db!;
  }

  Future<void> upsertUser(UserProfile user, {String? passwordHash, String? passwordSalt}) async {
    final db = await database;
    await db.insert('users', {
      'id': user.id,
      'email': user.email,
      'password_hash': passwordHash,
      'password_salt': passwordSalt,
      'display_name': user.displayName,
      'date_of_birth': user.dateOfBirth?.toIso8601String(),
      'photo_path': user.photoPath,
      'time_zone': user.timeZone,
      'preferred_language': user.preferredLanguage,
      'email_verified': user.emailVerified ? 1 : 0,
      'is_guest': user.isGuest ? 1 : 0,
      'large_text': user.largeText ? 1 : 0,
      'high_contrast': user.highContrast ? 1 : 0,
      'created_at': user.createdAt.toIso8601String(),
      'updated_at': user.updatedAt.toIso8601String(),
      'deleted_at': user.deletedAt?.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>?> userAuthRow(String email) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'email = ? AND deleted_at IS NULL',
      whereArgs: [email.toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<UserProfile?> userById(String id) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _userFrom(rows.first);
  }

  Future<void> deleteUserCascade(String userId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('medication_doses', where: 'user_id = ?', whereArgs: [userId]);
      final meds = await txn.query(
        'medications',
        columns: ['id'],
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      for (final med in meds) {
        await txn.delete(
          'medication_schedules',
          where: 'medication_id = ?',
          whereArgs: [med['id']],
        );
      }
      await txn.delete('medications', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('notification_preferences', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('users', where: 'id = ?', whereArgs: [userId]);
    });
  }

  Future<void> upsertNotificationPreference(NotificationPreference prefs) async {
    final db = await database;
    await db.insert('notification_preferences', {
      'user_id': prefs.userId,
      'enabled': prefs.enabled ? 1 : 0,
      'sound_enabled': prefs.soundEnabled ? 1 : 0,
      'vibration_enabled': prefs.vibrationEnabled ? 1 : 0,
      'snooze_minutes': jsonEncode(prefs.snoozeMinutes),
      'updated_at': prefs.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<NotificationPreference?> notificationPreference(String userId) async {
    final db = await database;
    final rows = await db.query(
      'notification_preferences',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return NotificationPreference(
      userId: userId,
      enabled: row['enabled'] == 1,
      soundEnabled: row['sound_enabled'] == 1,
      vibrationEnabled: row['vibration_enabled'] == 1,
      snoozeMinutes: (jsonDecode(row['snooze_minutes']! as String) as List)
          .map((e) => e as int)
          .toList(),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }

  Future<void> upsertMedication(Medication medication) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('medications', {
        'id': medication.id,
        'user_id': medication.userId,
        'name': medication.name,
        'generic_name': medication.genericName,
        'strength': medication.strength,
        'form': medication.form.name,
        'dose_amount': medication.doseAmount,
        'dose_unit': medication.doseUnit,
        'food_instruction': medication.foodInstruction,
        'additional_instructions': medication.additionalInstructions,
        'quantity': medication.quantity,
        'refill_threshold': medication.refillThreshold,
        'doctor_name': medication.doctorName,
        'notes': medication.notes,
        'start_date': medication.startDate.toIso8601String(),
        'end_date': medication.endDate?.toIso8601String(),
        'time_zone': medication.timeZone,
        'status': medication.status.name,
        'created_at': medication.createdAt.toIso8601String(),
        'updated_at': medication.updatedAt.toIso8601String(),
        'deleted_at': medication.deletedAt?.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final s = medication.schedule;
      await txn.insert('medication_schedules', {
        'id': s.id,
        'medication_id': medication.id,
        'frequency': s.frequency.name,
        'times_json': jsonEncode(s.timesMinutes),
        'interval_hours': s.intervalHours,
        'weekdays_json': s.weekdays == null ? null : jsonEncode(s.weekdays),
        'monthly_day': s.monthlyDay,
        'created_at': s.createdAt.toIso8601String(),
        'updated_at': s.updatedAt.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Medication>> medicationsForUser(
    String userId, {
    bool includeArchived = false,
  }) async {
    final db = await database;
    final where = includeArchived
        ? 'user_id = ? AND deleted_at IS NULL'
        : 'user_id = ? AND deleted_at IS NULL AND status != ?';
    final args = includeArchived ? [userId] : [userId, MedicationStatus.archived.name];
    final rows = await db.query('medications', where: where, whereArgs: args, orderBy: 'name COLLATE NOCASE');
    final result = <Medication>[];
    for (final row in rows) {
      final med = await _medicationFrom(row);
      if (med != null) result.add(med);
    }
    return result;
  }

  Future<Medication?> medicationById(String id) async {
    final db = await database;
    final rows = await db.query('medications', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _medicationFrom(rows.first);
  }

  Future<int> activeMedicationCount(String userId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM medications WHERE user_id = ? AND deleted_at IS NULL AND status = ?',
      [userId, MedicationStatus.active.name],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> replacePendingDoses(String medicationId, List<MedicationDose> doses) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'medication_doses',
        where: 'medication_id = ? AND status IN (?, ?)',
        whereArgs: [medicationId, DoseStatus.pending.name, DoseStatus.snoozed.name],
      );
      for (final dose in doses) {
        await txn.insert('medication_doses', _doseMap(dose), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> upsertDose(MedicationDose dose) async {
    final db = await database;
    await db.insert(
      'medication_doses',
      _doseMap(dose),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MedicationDose?> doseById(String id) async {
    final db = await database;
    final rows = await db.query('medication_doses', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _doseFrom(rows.first);
  }

  Future<List<MedicationDose>> dosesForUser(
    String userId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    final where = StringBuffer('user_id = ?');
    final args = <Object>[userId];
    if (from != null) {
      where.write(' AND scheduled_at >= ?');
      args.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      where.write(' AND scheduled_at <= ?');
      args.add(to.toUtc().toIso8601String());
    }
    final rows = await db.query(
      'medication_doses',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'scheduled_at ASC',
    );
    return rows.map(_doseFrom).toList();
  }

  Future<List<MedicationDose>> pendingDoses(String userId) async {
    final db = await database;
    final rows = await db.query(
      'medication_doses',
      where: 'user_id = ? AND status IN (?, ?)',
      whereArgs: [userId, DoseStatus.pending.name, DoseStatus.snoozed.name],
      orderBy: 'remind_at ASC',
    );
    return rows.map(_doseFrom).toList();
  }

  Future<void> setState(String key, String value) async {
    final db = await database;
    await db.insert('app_state', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getState(String key) async {
    final db = await database;
    final rows = await db.query('app_state', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<String> exportUserJson(String userId) async {
    final user = await userById(userId);
    final meds = await medicationsForUser(userId, includeArchived: true);
    final doses = await dosesForUser(userId);
    return jsonEncode({
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'disclaimer': 'This export is for the account holder. It is not medical advice.',
      'user': {
        'id': user?.id,
        'email': user?.email,
        'displayName': user?.displayName,
        'timeZone': user?.timeZone,
        'language': user?.preferredLanguage,
      },
      'medications': meds
          .map(
            (m) => {
              'id': m.id,
              'name': m.name,
              'genericName': m.genericName,
              'strength': m.strength,
              'form': m.form.name,
              'doseAmount': m.doseAmount,
              'doseUnit': m.doseUnit,
              'status': m.status.name,
            },
          )
          .toList(),
      'doses': doses
          .map(
            (d) => {
              'id': d.id,
              'medicationId': d.medicationId,
              'scheduledAt': d.scheduledAt.toIso8601String(),
              'status': d.status.name,
            },
          )
          .toList(),
    });
  }

  Map<String, Object?> _doseMap(MedicationDose dose) => {
    'id': dose.id,
    'medication_id': dose.medicationId,
    'user_id': dose.userId,
    'scheduled_at': dose.scheduledAt.toUtc().toIso8601String(),
    'remind_at': dose.remindAt.toUtc().toIso8601String(),
    'status': dose.status.name,
    'snooze_count': dose.snoozeCount,
    'acted_at': dose.actedAt?.toUtc().toIso8601String(),
    'notes': dose.notes,
    'created_at': dose.createdAt.toUtc().toIso8601String(),
    'updated_at': dose.updatedAt.toUtc().toIso8601String(),
  };

  MedicationDose _doseFrom(Map<String, Object?> row) {
    return MedicationDose(
      id: row['id']! as String,
      medicationId: row['medication_id']! as String,
      userId: row['user_id']! as String,
      scheduledAt: DateTime.parse(row['scheduled_at']! as String).toUtc(),
      remindAt: DateTime.parse(row['remind_at']! as String).toUtc(),
      status: DoseStatus.values.byName(row['status']! as String),
      snoozeCount: row['snooze_count']! as int,
      actedAt: row['acted_at'] == null
          ? null
          : DateTime.parse(row['acted_at']! as String).toUtc(),
      notes: row['notes'] as String?,
      createdAt: DateTime.parse(row['created_at']! as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
    );
  }

  UserProfile _userFrom(Map<String, Object?> row) {
    return UserProfile(
      id: row['id']! as String,
      email: (row['email'] as String?) ?? '',
      displayName: row['display_name']! as String,
      dateOfBirth: row['date_of_birth'] == null
          ? null
          : DateTime.parse(row['date_of_birth']! as String),
      photoPath: row['photo_path'] as String?,
      timeZone: row['time_zone']! as String,
      preferredLanguage: row['preferred_language']! as String,
      emailVerified: row['email_verified'] == 1,
      isGuest: row['is_guest'] == 1,
      largeText: row['large_text'] == 1,
      highContrast: row['high_contrast'] == 1,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.parse(row['deleted_at']! as String),
    );
  }

  Future<Medication?> _medicationFrom(Map<String, Object?> row) async {
    final db = await database;
    final schedules = await db.query(
      'medication_schedules',
      where: 'medication_id = ?',
      whereArgs: [row['id']],
      limit: 1,
    );
    if (schedules.isEmpty) return null;
    final s = schedules.first;
    final weekdaysRaw = s['weekdays_json'] as String?;
    return Medication(
      id: row['id']! as String,
      userId: row['user_id']! as String,
      name: row['name']! as String,
      genericName: row['generic_name'] as String?,
      strength: row['strength'] as String?,
      form: MedicationForm.values.byName(row['form']! as String),
      doseAmount: (row['dose_amount']! as num).toDouble(),
      doseUnit: row['dose_unit']! as String,
      foodInstruction: row['food_instruction'] as String?,
      additionalInstructions: row['additional_instructions'] as String?,
      quantity: (row['quantity'] as num?)?.toDouble(),
      refillThreshold: (row['refill_threshold'] as num?)?.toDouble(),
      doctorName: row['doctor_name'] as String?,
      notes: row['notes'] as String?,
      startDate: DateTime.parse(row['start_date']! as String),
      endDate: row['end_date'] == null ? null : DateTime.parse(row['end_date']! as String),
      timeZone: row['time_zone']! as String,
      status: MedicationStatus.values.byName(row['status']! as String),
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.parse(row['deleted_at']! as String),
      schedule: MedicationSchedule(
        id: s['id']! as String,
        medicationId: s['medication_id']! as String,
        frequency: FrequencyType.values.byName(s['frequency']! as String),
        timesMinutes: (jsonDecode(s['times_json']! as String) as List).map((e) => e as int).toList(),
        intervalHours: s['interval_hours'] as int?,
        weekdays: weekdaysRaw == null
            ? null
            : (jsonDecode(weekdaysRaw) as List).map((e) => e as int).toList(),
        monthlyDay: s['monthly_day'] as int?,
        createdAt: DateTime.parse(s['created_at']! as String),
        updatedAt: DateTime.parse(s['updated_at']! as String),
      ),
    );
  }
}
