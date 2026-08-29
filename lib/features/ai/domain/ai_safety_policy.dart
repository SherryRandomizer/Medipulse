/// Phase 3: MediPulse AI answers only from stored schedules.
/// It must not diagnose, prescribe, or change doses.
class AiSafetyPolicy {
  static const outOfScope =
      'MediPulse AI can help with your saved reminder schedule. For medical questions, talk with a healthcare professional.';
}
