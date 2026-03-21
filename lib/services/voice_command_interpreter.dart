enum VoiceCommandAction {
  openHub,
  openFarm,
  openActivities,
  openSupplies,
  openKnowledge,
  openWeather,
  openLogistics,
  openWorkers,
  openTracker,
  openProfitCalculator,
  goBack,
  help,
  stopSpeaking,
  unknown,
}

class VoiceCommandIntent {
  final VoiceCommandAction action;
  final String rawCommand;

  const VoiceCommandIntent({
    required this.action,
    required this.rawCommand,
  });
}

class VoiceCommandInterpreter {
  static const List<String> sampleCommands = [
    'Open farm',
    'Open activities',
    'Open supplies',
    'Open knowledge',
    'Open logistics',
    'Open profit calculator',
    'Open weather',
    'Go back',
  ];

  static const String helpMessage =
      'Try saying: open farm, open activities, open supplies, open knowledge, '
      'open logistics, open tracker, open profit calculator, open weather, or go back.';

  static VoiceCommandIntent interpret(String input) {
    final normalized = _normalize(input);

    if (normalized.isEmpty) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.unknown,
        rawCommand: input,
      );
    }

    if (_containsAny(normalized, const [
      'stop talking',
      'stop speaking',
      'be quiet',
      'quiet',
      'tahimik',
    ])) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.stopSpeaking,
        rawCommand: input,
      );
    }

    if (_containsAny(normalized, const [
      'help',
      'commands',
      'what can you do',
      'tulong',
    ])) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.help,
        rawCommand: input,
      );
    }

    if (_containsAny(normalized, const ['go back', 'back', 'bumalik'])) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.goBack,
        rawCommand: input,
      );
    }

    if (_containsAny(normalized, const ['weather', 'forecast', 'panahon'])) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.openWeather,
        rawCommand: input,
      );
    }

    if (_containsAny(normalized, const [
      'profit',
      'calculator',
      'roi',
      'tube',
      'tubo',
    ])) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.openProfitCalculator,
        rawCommand: input,
      );
    }

    if (_containsAny(normalized, const [
      'finance',
      'tracker',
      'wallet',
      'financial',
      'expenses',
    ])) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.openTracker,
        rawCommand: input,
      );
    }

    if (_containsAny(normalized, const [
      'logistics',
      'delivery',
      'deliveries',
      'truck',
    ])) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.openLogistics,
        rawCommand: input,
      );
    }

    if (_containsAny(normalized, const [
      'worker',
      'workers',
      'crew',
      'labor',
      'tauhan',
    ])) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.openWorkers,
        rawCommand: input,
      );
    }

    if (_containsAny(normalized, const [
      'knowledge',
      'library',
      'guide',
      'qa',
      'question',
      'answer',
      'kaalaman',
    ])) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.openKnowledge,
        rawCommand: input,
      );
    }

    if (_containsAny(normalized, const [
      'supplies',
      'supply',
      'inventory',
      'asset',
      'assets',
      'stock',
    ])) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.openSupplies,
        rawCommand: input,
      );
    }

    if (_containsAny(normalized, const [
      'activities',
      'activity',
      'ledger',
      'tasks',
      'task',
      'trabaho',
      'gawain',
    ])) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.openActivities,
        rawCommand: input,
      );
    }

    if (_containsAny(normalized, const [
      'farm',
      'farms',
      'estate',
      'bukid',
    ])) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.openFarm,
        rawCommand: input,
      );
    }

    if (_containsAny(normalized, const [
      'home',
      'hub',
      'dashboard',
      'copilot',
      'main',
    ])) {
      return VoiceCommandIntent(
        action: VoiceCommandAction.openHub,
        rawCommand: input,
      );
    }

    return VoiceCommandIntent(
      action: VoiceCommandAction.unknown,
      rawCommand: input,
    );
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _containsAny(String normalized, List<String> phrases) {
    return phrases.any(normalized.contains);
  }
}
