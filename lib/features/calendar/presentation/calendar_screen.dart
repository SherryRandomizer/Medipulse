import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:medipulse/core/di/app_controllers.dart';
import 'package:medipulse/core/theme/app_colors.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/widgets/app_components.dart';
import 'package:medipulse/shared/widgets/medication_widgets.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final day = DateTime(_selected.year, _selected.month, _selected.day);
    final items = ref.watch(calendarDosesProvider(day));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'Calendar', subtitle: 'Choose a day to see scheduled, taken, missed, and skipped doses.'),
            TableCalendar<void>(
              firstDay: DateTime.utc(2020),
              lastDay: DateTime.utc(2035),
              focusedDay: _focused,
              selectedDayPredicate: (d) => isSameDay(d, _selected),
              calendarFormat: CalendarFormat.month,
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selected = selected;
                  _focused = focused;
                });
              },
            ),
            Expanded(
              child: items.when(
                loading: () => const LoadingState(),
                error: (_, _) => const ErrorState(message: 'Could not load that day.'),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.event_available,
                      title: 'Nothing scheduled',
                      message: 'No medication doses for this date.',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      for (final item in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            child: ListTile(
                              title: Text(item.medication.name),
                              subtitle: Text(item.medication.doseLabel),
                              trailing: MedicationStatusBadge(
                                status: item.dose.status == DoseStatus.snoozed
                                    ? DoseStatus.snoozed
                                    : item.dose.status,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
