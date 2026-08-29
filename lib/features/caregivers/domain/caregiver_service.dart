import 'package:clock/clock.dart';
import 'package:medipulse/core/errors/app_failure.dart';
import 'package:medipulse/core/storage/local_database.dart';
import 'package:medipulse/features/adherence/domain/adherence_calculator.dart';
import 'package:medipulse/features/caregivers/domain/caregiver_access_policy.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';
import 'package:uuid/uuid.dart';

class CaregiverAlertSink {
  CaregiverAlertSink({
    required LocalDatabase database,
    required NotificationService notifications,
  }) : _db = database,
       _notifications = notifications;

  final LocalDatabase _db;
  final NotificationService _notifications;
  final _uuid = const Uuid();

  Future<List<Caregiver>> list(String ownerId) => _db.caregiversFor(ownerId);

  Future<List<FamilyProfile>> family(String ownerId) => _db.familyProfilesFor(ownerId);

  Future<Caregiver> invite({
    required String ownerUserId,
    required String displayName,
    required CaregiverRelation relation,
  }) async {
    final now = clock.now().toUtc();
    final caregiver = Caregiver(
      id: _uuid.v4(),
      ownerUserId: ownerUserId,
      displayName: displayName.trim(),
      relation: relation,
      status: CaregiverPermissionStatus.pending,
      shareAdherence: false,
      inviteCode: _uuid.v4().substring(0, 8).toUpperCase(),
      createdAt: now,
      updatedAt: now,
    );
    await _db.upsertCaregiver(caregiver);
    return caregiver;
  }

  Future<void> setSharing(
    Caregiver caregiver, {
    required bool share,
    required CaregiverPermissionStatus status,
    bool? sharePercent,
  }) {
    return _db.upsertCaregiver(
      caregiver.copyWith(
        shareAdherence: share,
        shareAdherencePercent: sharePercent,
        status: status,
        updatedAt: clock.now().toUtc(),
      ),
    );
  }

  Future<Caregiver> acceptInvite({
    required String code,
    required String caregiverUserId,
  }) async {
    final found = await _db.caregiverByInviteCode(code);
    if (found == null) {
      throw const NotFoundFailure('That invite code was not found.');
    }
    if (found.caregiverUserId != null && found.caregiverUserId != caregiverUserId) {
      throw const ValidationFailure('This invite is already linked to another account.');
    }
    final updated = found.copyWith(
      caregiverUserId: caregiverUserId,
      status: CaregiverPermissionStatus.accepted,
      updatedAt: clock.now().toUtc(),
    );
    await _db.upsertCaregiver(updated);
    return updated;
  }

  Future<List<Caregiver>> linkedAsCaregiver(String userId) => _db.caregiversLinkedTo(userId);

  Future<SharedAdherenceSnapshot?> sharedPercentFor({
    required String ownerUserId,
    required String viewerUserId,
  }) async {
    final links = await _db.caregiversLinkedTo(viewerUserId);
    final allowed = links.where(
      (c) => c.ownerUserId == ownerUserId && CaregiverAccessPolicy.canViewAdherencePercent(c),
    );
    if (allowed.isEmpty) return null;
    final now = clock.now().toUtc();
    final from = now.subtract(const Duration(days: 7));
    final doses = await _db.dosesForUser(ownerUserId, from: from, to: now);
    final summary = AdherenceCalculator().summarize(doses);
    return SharedAdherenceSnapshot(
      percentage: summary.percentage,
      completedDoses: summary.completed,
    );
  }

  Future<void> remove(String id) => _db.deleteCaregiver(id);

  Future<FamilyProfile> addFamily({
    required String ownerUserId,
    required String displayName,
    required CaregiverRelation relation,
  }) async {
    final now = clock.now().toUtc();
    final profile = FamilyProfile(
      id: _uuid.v4(),
      ownerUserId: ownerUserId,
      displayName: displayName.trim(),
      relation: relation,
      createdAt: now,
      updatedAt: now,
    );
    await _db.upsertFamilyProfile(profile);
    return profile;
  }

  Future<void> removeFamily(String id) => _db.deleteFamilyProfile(id);

  Future<void> onMissedDose({
    required String ownerUserId,
    required String ownerFirstName,
    required DateTime scheduledAt,
  }) async {
    final caregivers = await _db.caregiversFor(ownerUserId);
    final allowed = caregivers.where(CaregiverAccessPolicy.canReceiveAdherenceAlert);
    if (allowed.isEmpty) return;
    await _notifications.showImmediate(
      title: 'Adherence alert',
      body: CaregiverAccessPolicy.missedAlertBody(
        firstName: ownerFirstName,
        scheduledAt: scheduledAt,
      ),
    );
  }
}
