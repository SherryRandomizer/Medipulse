import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:medipulse/core/constants/legal_copy.dart';
import 'package:medipulse/core/di/app_controllers.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/core/errors/app_failure.dart';
import 'package:medipulse/features/subscriptions/domain/premium_features.dart';
import 'package:medipulse/features/scanner/domain/scanner_pipeline.dart';
import 'package:medipulse/features/scanner/domain/heuristic_extractor.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/widgets/app_components.dart';

class AddMedicationScreen extends ConsumerStatefulWidget {
  const AddMedicationScreen({super.key, this.existingId, this.scanOutcome});
  final String? existingId;
  final ScanOutcome? scanOutcome;

  @override
  ConsumerState<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends ConsumerState<AddMedicationScreen> {
  int _step = 0;
  String _method = 'manual';
  final _name = TextEditingController();
  final _generic = TextEditingController();
  final _strength = TextEditingController();
  final _dose = TextEditingController(text: '1');
  final _unit = TextEditingController(text: 'tablet');
  final _food = TextEditingController();
  final _extra = TextEditingController();
  final _quantity = TextEditingController();
  final _threshold = TextEditingController();
  final _doctor = TextEditingController();
  final _notes = TextEditingController();
  MedicationForm _form = MedicationForm.tablet;
  FrequencyType _frequency = FrequencyType.onceDaily;
  List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  int _intervalHours = 8;
  final Set<int> _weekdays = {DateTime.monday};
  int _monthlyDay = 1;
  DateTime _start = DateTime.now();
  DateTime? _end;
  bool _busy = false;
  String? _error;
  Medication? _existing;

  @override
  void initState() {
    super.initState();
    _loadExisting();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyScan());
  }

  Future<void> _loadExisting() async {
    final id = widget.existingId;
    if (id == null) return;
    final med = await ref.read(medicationRepositoryProvider).getById(id);
    if (med == null || !mounted) return;
    setState(() {
      _existing = med;
      _method = 'manual';
      _step = 1;
      _name.text = med.name;
      _generic.text = med.genericName ?? '';
      _strength.text = med.strength ?? '';
      _dose.text = med.doseAmount.toString();
      _unit.text = med.doseUnit;
      _food.text = med.foodInstruction ?? '';
      _extra.text = med.additionalInstructions ?? '';
      _quantity.text = med.quantity?.toString() ?? '';
      _threshold.text = med.refillThreshold?.toString() ?? '';
      _doctor.text = med.doctorName ?? '';
      _notes.text = med.notes ?? '';
      _form = med.form;
      _frequency = med.schedule.frequency;
      _times = med.schedule.timesMinutes
          .map((m) => TimeOfDay(hour: m ~/ 60, minute: m % 60))
          .toList();
      _intervalHours = med.schedule.intervalHours ?? 8;
      _weekdays
        ..clear()
        ..addAll(med.schedule.weekdays ?? {DateTime.monday});
      _monthlyDay = med.schedule.monthlyDay ?? 1;
      _start = med.startDate;
      _end = med.endDate;
    });
  }

  void _applyScan() {
    final scan = widget.scanOutcome;
    if (scan == null) return;
    final extractor = HeuristicExtractor();
    final rx = scan.prescription;
    final pack = scan.package;
    setState(() {
      _method = 'manual';
      _step = 1;
      if (rx != null) {
        if (rx.medicineName.value != null) _name.text = rx.medicineName.value!;
        if (rx.strength.value != null) _strength.text = rx.strength.value!;
        if (rx.foodInstruction.value != null) _food.text = rx.foodInstruction.value!;
        if (rx.additionalInstructions.value != null) _extra.text = rx.additionalInstructions.value!;
        final dose = rx.dose.value;
        if (dose != null) {
          final amount = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(dose);
          if (amount != null) _dose.text = amount.group(1)!;
          final unit = RegExp(r'(tablet|capsule|ml|puff|drop)s?').firstMatch(dose.toLowerCase());
          if (unit != null) _unit.text = unit.group(1)!;
        }
        final freq = extractor.frequencyType(rx.frequency.value);
        if (freq != null) _frequency = freq;
        final parsedTimes = _parseTimes(rx.times.value);
        if (parsedTimes.isNotEmpty) _times = parsedTimes;
        final duration = int.tryParse(RegExp(r'\d+').firstMatch(rx.durationDays.value ?? '')?.group(0) ?? '');
        if (duration != null) {
          _end = DateTime(_start.year, _start.month, _start.day).add(Duration(days: duration));
        }
      }
      if (pack != null) {
        if (pack.medicineName.value != null) _name.text = pack.medicineName.value!;
        if (pack.strength.value != null) _strength.text = pack.strength.value!;
        final formLabel = pack.form.value?.toLowerCase();
        if (formLabel != null) {
          for (final form in MedicationForm.values) {
            if (form.label.toLowerCase() == formLabel || form.name == formLabel) {
              _form = form;
            }
          }
        }
        final extras = [
          if (pack.manufacturer.value != null) 'Manufacturer: ${pack.manufacturer.value}',
          if (pack.expiryDate.value != null) 'Expiry on package: ${pack.expiryDate.value}',
          if (pack.batchNumber.value != null) 'Batch: ${pack.batchNumber.value}',
        ];
        if (extras.isNotEmpty) {
          _notes.text = extras.join('\n');
        }
      }
    });
  }

  List<TimeOfDay> _parseTimes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final result = <TimeOfDay>[];
    for (final part in raw.split(',')) {
      final cleaned = part.trim().toLowerCase().replaceAll('.', ':');
      final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(am|pm)?$').firstMatch(cleaned);
      if (match == null) continue;
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3);
      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;
      result.add(TimeOfDay(hour: hour, minute: minute));
    }
    return result;
  }

  @override
  void dispose() {
    _name.dispose();
    _generic.dispose();
    _strength.dispose();
    _dose.dispose();
    _unit.dispose();
    _food.dispose();
    _extra.dispose();
    _quantity.dispose();
    _threshold.dispose();
    _doctor.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<int> get _minutes => [
    for (final t in _times) t.hour * 60 + t.minute,
  ];

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(sessionControllerProvider.future);
      if (user == null) throw const AuthFailure('Sign in or continue as a guest first.');
      final tz = await FlutterTimezone.getLocalTimezone();
      final now = DateTime.now().toUtc();
      final id = _existing?.id ?? const Uuid().v4();
      final schedule = MedicationSchedule(
        id: _existing?.schedule.id ?? const Uuid().v4(),
        medicationId: id,
        frequency: _frequency,
        timesMinutes: _minutes,
        intervalHours: _frequency == FrequencyType.everyXHours ? _intervalHours : null,
        weekdays: (_frequency == FrequencyType.specificDays || _frequency == FrequencyType.weekly)
            ? _weekdays.toList()
            : null,
        monthlyDay: _frequency == FrequencyType.monthly ? _monthlyDay : null,
        createdAt: _existing?.schedule.createdAt ?? now,
        updatedAt: now,
      );
      final medication = Medication(
        id: id,
        userId: user.id,
        name: _name.text,
        genericName: _generic.text.trim().isEmpty ? null : _generic.text.trim(),
        strength: _strength.text.trim().isEmpty ? null : _strength.text.trim(),
        form: _form,
        doseAmount: double.tryParse(_dose.text) ?? 0,
        doseUnit: _unit.text.trim().isEmpty ? _form.label.toLowerCase() : _unit.text.trim(),
        schedule: schedule,
        foodInstruction: _food.text.trim().isEmpty ? null : _food.text.trim(),
        additionalInstructions: _extra.text.trim().isEmpty ? null : _extra.text.trim(),
        quantity: double.tryParse(_quantity.text),
        refillThreshold: double.tryParse(_threshold.text),
        doctorName: _doctor.text.trim().isEmpty ? null : _doctor.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        startDate: _start,
        endDate: _end,
        timeZone: tz,
        status: MedicationStatus.active,
        createdAt: _existing?.createdAt ?? now,
        updatedAt: now,
      );
      await ref.read(medicationCoordinatorProvider).saveMedication(medication);
      ref.invalidate(homeSnapshotProvider);
      ref.invalidate(medicationsListProvider);
      if (mounted) context.go('/home');
    } catch (error) {
      setState(() {
        _error = error is AppFailure ? error.message : 'We could not save that medication.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(context: context, initialTime: _times[index]);
    if (picked != null) setState(() => _times[index] = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existingId == null ? 'Add medication' : 'Edit medication')),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / 5),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16)),
                    const SizedBox(height: 12),
                  ],
                  if (_step == 0) _methodStep(),
                  if (_step == 1) _detailsStep(),
                  if (_step == 2) _scheduleStep(),
                  if (_step == 3) _moreStep(),
                  if (_step == 4) _reviewStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => setState(() => _step--),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      expanded: false,
                      label: _step == 4 ? (_busy ? 'Saving…' : 'Save') : 'Next',
                      onPressed: _busy
                          ? null
                          : () async {
                              if (_step == 0 && (_method == 'prescription' || _method == 'package')) {
                                final user = await ref.read(sessionControllerProvider.future);
                                final sub = user == null
                                    ? null
                                    : await ref.read(subscriptionServiceProvider).current(user.id);
                                if (!context.mounted) return;
                                if (sub == null || !PremiumFeatures.canScan(sub)) {
                                  context.push('/paywall', extra: 'Scanning');
                                  return;
                                }
                                context.push(
                                  _method == 'prescription' ? '/scan/prescription' : '/scan/package',
                                );
                                return;
                              }
                              if (_step == 0 && _method == 'catalog') {
                                await ref.read(analyticsServiceProvider).logEvent('catalog_opened');
                                if (!context.mounted) return;
                                final name = await context.push<String>('/catalog');
                                if (name != null && name.trim().isNotEmpty) {
                                  _name.text = name.trim();
                                }
                                setState(() => _step = 1);
                                return;
                              }
                              if (_step == 4) {
                                _save();
                              } else {
                                setState(() => _step++);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How do you want to add this medicine?', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _choice('manual', 'Enter manually', 'Fastest. Type the name, dose, and times.'),
        _choice('prescription', 'Scan prescription', 'You must confirm every field. Nothing is saved automatically.'),
        _choice('package', 'Scan medicine / package', 'Identification from a photo is never medically certain.'),
        _choice('catalog', 'Licensed catalog', 'Uses a licensed provider only. This build will not invent names or interactions.'),
        const SizedBox(height: 12),
        Text(LegalCopy.aiSafety, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _choice(String value, String title, String subtitle) {
    final selected = _method == value;
    return Card(
      child: ListTile(
        onTap: () => setState(() => _method = value),
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _detailsStep() {
    return Column(
      children: [
        AppTextField(label: 'Medicine name', controller: _name),
        const SizedBox(height: 12),
        AppTextField(label: 'Generic name (optional)', controller: _generic),
        const SizedBox(height: 12),
        AppTextField(label: 'Strength (for example 500 mg)', controller: _strength),
        const SizedBox(height: 12),
        DropdownButtonFormField<MedicationForm>(
          // ignore: deprecated_member_use
          value: _form,
          decoration: const InputDecoration(labelText: 'Dosage form'),
          items: [
            for (final form in MedicationForm.values)
              DropdownMenuItem(value: form, child: Text(form.label)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _form = value);
          },
        ),
        const SizedBox(height: 12),
        AppTextField(label: 'Dose amount', controller: _dose, keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        AppTextField(label: 'Unit (tablet, ml, puff…)', controller: _unit),
      ],
    );
  }

  Widget _scheduleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<FrequencyType>(
          // ignore: deprecated_member_use
          value: _frequency,
          decoration: const InputDecoration(labelText: 'How often?'),
          items: [
            for (final item in FrequencyType.values)
              DropdownMenuItem(value: item, child: Text(item.label)),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _frequency = value;
              _times = switch (value) {
                FrequencyType.onceDaily => [const TimeOfDay(hour: 8, minute: 0)],
                FrequencyType.twiceDaily => [
                  const TimeOfDay(hour: 8, minute: 0),
                  const TimeOfDay(hour: 20, minute: 0),
                ],
                FrequencyType.threeTimesDaily => [
                  const TimeOfDay(hour: 8, minute: 0),
                  const TimeOfDay(hour: 14, minute: 0),
                  const TimeOfDay(hour: 20, minute: 0),
                ],
                FrequencyType.fourTimesDaily => [
                  const TimeOfDay(hour: 8, minute: 0),
                  const TimeOfDay(hour: 12, minute: 0),
                  const TimeOfDay(hour: 16, minute: 0),
                  const TimeOfDay(hour: 20, minute: 0),
                ],
                _ => _times.isEmpty ? [const TimeOfDay(hour: 8, minute: 0)] : _times,
              };
            });
          },
        ),
        if (_frequency == FrequencyType.everyXHours) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            // ignore: deprecated_member_use
            value: _intervalHours,
            decoration: const InputDecoration(labelText: 'Every how many hours?'),
            items: [4, 6, 8, 12]
                .map((h) => DropdownMenuItem(value: h, child: Text('Every $h hours')))
                .toList(),
            onChanged: (v) => setState(() => _intervalHours = v ?? 8),
          ),
        ],
        if (_frequency == FrequencyType.specificDays || _frequency == FrequencyType.weekly) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final day in [1, 2, 3, 4, 5, 6, 7])
                FilterChip(
                  label: Text(const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1]),
                  selected: _weekdays.contains(day),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _weekdays.add(day);
                      } else if (_weekdays.length > 1) {
                        _weekdays.remove(day);
                      }
                    });
                  },
                ),
            ],
          ),
        ],
        if (_frequency == FrequencyType.monthly) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            // ignore: deprecated_member_use
            value: _monthlyDay,
            decoration: const InputDecoration(labelText: 'Day of month'),
            items: [
              for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d')),
            ],
            onChanged: (v) => setState(() => _monthlyDay = v ?? 1),
          ),
        ],
        if (_frequency != FrequencyType.asNeeded) ...[
          const SizedBox(height: 16),
          Text('Times', style: Theme.of(context).textTheme.titleMedium),
          for (var i = 0; i < _times.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_times[i].format(context), style: const TextStyle(fontSize: 20)),
              trailing: const Icon(Icons.schedule),
              onTap: () => _pickTime(i),
            ),
          if (_frequency == FrequencyType.customTimes)
            TextButton(
              onPressed: () => setState(() => _times.add(const TimeOfDay(hour: 12, minute: 0))),
              child: const Text('Add another time'),
            ),
        ],
      ],
    );
  }

  Widget _moreStep() {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Start date'),
          subtitle: Text(_start.toLocal().toString().split(' ').first),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _start,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => _start = picked);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('End date (optional)'),
          subtitle: Text(_end == null ? 'No end date' : _end!.toLocal().toString().split(' ').first),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _end ?? _start,
              firstDate: _start,
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => _end = picked);
          },
        ),
        AppTextField(label: 'Food instruction (after breakfast…)', controller: _food),
        const SizedBox(height: 12),
        AppTextField(label: 'Additional instructions', controller: _extra, maxLines: 3),
        const SizedBox(height: 12),
        AppTextField(label: 'Quantity on hand', controller: _quantity, keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        AppTextField(label: 'Refill threshold', controller: _threshold, keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        AppTextField(label: 'Doctor name (optional)', controller: _doctor),
        const SizedBox(height: 12),
        AppTextField(label: 'Notes', controller: _notes, maxLines: 3),
      ],
    );
  }

  Widget _reviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review and save', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(_name.text.isEmpty ? 'Unnamed medicine' : _name.text, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('${_dose.text} ${_unit.text} · ${_form.label}'),
        Text(_frequency.label),
        if (_times.isNotEmpty) Text(_times.map((t) => t.format(context)).join(', ')),
        const SizedBox(height: 16),
        Text(LegalCopy.medicalDisclaimer, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
