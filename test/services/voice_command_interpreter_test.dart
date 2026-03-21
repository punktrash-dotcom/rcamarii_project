import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/services/voice_command_interpreter.dart';

void main() {
  test('maps navigation commands to the expected sections', () {
    expect(
      VoiceCommandInterpreter.interpret('open farm').action,
      VoiceCommandAction.openFarm,
    );
    expect(
      VoiceCommandInterpreter.interpret('open activities').action,
      VoiceCommandAction.openActivities,
    );
    expect(
      VoiceCommandInterpreter.interpret('open supplies').action,
      VoiceCommandAction.openSupplies,
    );
    expect(
      VoiceCommandInterpreter.interpret('open knowledge').action,
      VoiceCommandAction.openKnowledge,
    );
  });

  test('supports logistics, finance, and assistant control commands', () {
    expect(
      VoiceCommandInterpreter.interpret('open logistics').action,
      VoiceCommandAction.openLogistics,
    );
    expect(
      VoiceCommandInterpreter.interpret('open tracker').action,
      VoiceCommandAction.openTracker,
    );
    expect(
      VoiceCommandInterpreter.interpret('stop talking').action,
      VoiceCommandAction.stopSpeaking,
    );
    expect(
      VoiceCommandInterpreter.interpret('go back').action,
      VoiceCommandAction.goBack,
    );
  });

  test('supports localized keywords and falls back when unknown', () {
    expect(
      VoiceCommandInterpreter.interpret('panahon').action,
      VoiceCommandAction.openWeather,
    );
    expect(
      VoiceCommandInterpreter.interpret('tulong').action,
      VoiceCommandAction.help,
    );
    expect(
      VoiceCommandInterpreter.interpret('do something impossible').action,
      VoiceCommandAction.unknown,
    );
  });
}
