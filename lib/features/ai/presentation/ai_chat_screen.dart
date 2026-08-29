import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/features/ai/domain/ai_safety_policy.dart';
import 'package:medipulse/features/ai/domain/schedule_assistant.dart';
import 'package:medipulse/features/subscriptions/domain/premium_features.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/widgets/app_components.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _input = TextEditingController();
  final _messages = <AssistantReply>[
    const AssistantReply(
      text: 'I am MediPulse AI. I only use your saved reminder schedule. I cannot diagnose, prescribe, or change doses.',
      fromStoredSchedule: true,
      refusedMedicalAdvice: false,
    ),
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _input.text.trim();
    if (question.isEmpty) return;
    final user = await ref.read(sessionControllerProvider.future);
    if (user == null) return;
    final sub = await ref.read(subscriptionServiceProvider).current(user.id);
    if (!PremiumFeatures.canUseAssistant(sub)) {
      if (mounted) context.push('/paywall', extra: 'MediPulse AI');
      return;
    }
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final doses = ref.read(doseRepositoryProvider);
    final meds = {
      for (final m in await ref.read(medicationRepositoryProvider).list(user.id, includeArchived: true)) m.id: m,
    };
    Future<List<TimelineItem>> day(DateTime day) async {
      final from = DateTime(day.year, day.month, day.day).toUtc();
      final to = from.add(const Duration(days: 1));
      final list = await doses.forUser(user.id, from: from, to: to);
      return [
        for (final d in list)
          if (meds.containsKey(d.medicationId)) TimelineItem(dose: d, medication: meds[d.medicationId]!),
      ];
    }

    final reply = ScheduleAssistant().answer(
      question: question,
      today: await day(startToday),
      yesterday: await day(startToday.subtract(const Duration(days: 1))),
      tomorrow: await day(startToday.add(const Duration(days: 1))),
      now: now.toUtc(),
    );
    setState(() {
      _messages.add(reply);
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MediPulse AI')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(AiSafetyPolicy.outOfScope, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${message.fromStoredSchedule ? 'Saved schedule\n' : ''}${message.text}',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: AppTextField(label: 'Ask about your schedule', controller: _input)),
                IconButton(onPressed: _send, icon: const Icon(Icons.send), tooltip: 'Send'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
