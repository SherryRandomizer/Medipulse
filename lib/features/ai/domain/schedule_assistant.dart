import 'package:intl/intl.dart';
import 'package:medipulse/features/ai/domain/ai_safety_policy.dart';
import 'package:medipulse/shared/models/entities.dart';

class AssistantReply {
  const AssistantReply({
    required this.text,
    required this.fromStoredSchedule,
    required this.refusedMedicalAdvice,
  });

  final String text;
  final bool fromStoredSchedule;
  final bool refusedMedicalAdvice;
}

class ScheduleAssistant {
  static final _medical = RegExp(
    r'diagnos|prescribe|prescription change|stop taking|start taking|increase (the )?dose|decrease (the )?dose|change (my )?dose|overdose|side effect|interact|replace (this|my) (medicine|medication)|cure|treat my|what disease',
    caseSensitive: false,
  );

  AssistantReply answer({
    required String question,
    required List<TimelineItem> today,
    required List<TimelineItem> yesterday,
    required List<TimelineItem> tomorrow,
    required DateTime now,
  }) {
    final q = question.trim();
    if (q.isEmpty) {
      return const AssistantReply(
        text: 'Ask about your saved reminder schedule, such as what you take today or when the next dose is.',
        fromStoredSchedule: true,
        refusedMedicalAdvice: false,
      );
    }
    if (_medical.hasMatch(q)) {
      return const AssistantReply(
        text: AiSafetyPolicy.outOfScope,
        fromStoredSchedule: false,
        refusedMedicalAdvice: true,
      );
    }
    final lower = q.toLowerCase();
    if (lower.contains('yesterday') && (lower.contains('miss') || lower.contains('missed'))) {
      final missed = yesterday.where((i) => i.dose.status == DoseStatus.missed).toList();
      return AssistantReply(
        text: _list(
          'From your saved schedule, missed doses yesterday:',
          missed,
          empty: 'From your saved schedule, no missed doses were recorded yesterday.',
        ),
        fromStoredSchedule: true,
        refusedMedicalAdvice: false,
      );
    }
    if (lower.contains('tomorrow')) {
      return AssistantReply(
        text: _list(
          'From your saved schedule, tomorrow:',
          tomorrow,
          empty: 'From your saved schedule, nothing is stored for tomorrow.',
        ),
        fromStoredSchedule: true,
        refusedMedicalAdvice: false,
      );
    }
    if (lower.contains('next')) {
      TimelineItem? next;
      for (final item in today) {
        if ((item.dose.status == DoseStatus.pending || item.dose.status == DoseStatus.snoozed) &&
            !item.dose.remindAt.isBefore(now)) {
          next = item;
          break;
        }
      }
      if (next == null) {
        return const AssistantReply(
          text: 'From your saved schedule, there is no upcoming dose left today.',
          fromStoredSchedule: true,
          refusedMedicalAdvice: false,
        );
      }
      return AssistantReply(
        text:
            'From your saved schedule, your next dose is ${next.medication.name} at ${DateFormat.jm().format(next.dose.remindAt.toLocal())}.',
        fromStoredSchedule: true,
        refusedMedicalAdvice: false,
      );
    }
    if (lower.contains('after dinner') || lower.contains('after supper')) {
      final items = today.where((i) {
        final food = i.medication.foodInstruction?.toLowerCase() ?? '';
        final hour = i.dose.remindAt.toLocal().hour;
        return food.contains('dinner') || food.contains('supper') || hour >= 17;
      }).toList();
      return AssistantReply(
        text: _list(
          'From your saved schedule, evening / after-dinner doses today:',
          items,
          empty: 'From your saved schedule, nothing is marked after dinner today.',
        ),
        fromStoredSchedule: true,
        refusedMedicalAdvice: false,
      );
    }
    if (lower.contains('today') || lower.contains('do i take') || lower.contains('what medicines')) {
      return AssistantReply(
        text: _list(
          'From your saved schedule, today:',
          today,
          empty: 'From your saved schedule, no doses are stored for today.',
        ),
        fromStoredSchedule: true,
        refusedMedicalAdvice: false,
      );
    }
    return const AssistantReply(
      text:
          'I can answer questions about your saved MediPulse schedule (today, next dose, missed yesterday, tomorrow). I cannot diagnose, prescribe, or change a clinician\'s instructions. For those questions, talk with a healthcare professional.',
      fromStoredSchedule: false,
      refusedMedicalAdvice: false,
    );
  }

  String _list(String heading, List<TimelineItem> items, {required String empty}) {
    if (items.isEmpty) return empty;
    final lines = [
      heading,
      for (final item in items)
        '${DateFormat.jm().format(item.dose.remindAt.toLocal())} — ${item.medication.name} (${item.dose.status.name})',
      'This is your stored reminder list, not medical advice.',
    ];
    return lines.join('\n');
  }
}
