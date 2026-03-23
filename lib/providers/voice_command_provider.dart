import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../screens/ftracker_splash_screen.dart';
import '../screens/frm_logistics.dart';
import '../screens/frm_main.dart';
import '../screens/profit_calculator_screen.dart';
import '../screens/scr_msoft.dart';
import '../screens/scr_weather.dart';
import '../screens/scr_workers.dart';
import '../services/voice_command_interpreter.dart';
import 'app_settings_provider.dart';
import 'navigation_provider.dart';

class VoiceCommandProvider extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isInitialized = false;
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _lastCommand = '';
  String _transcript = '';
  String _statusMessage = 'Tap the microphone to start listening.';
  String? _preferredLocaleId;

  String get lastCommand => _lastCommand;
  String get transcript => _transcript;
  String get statusMessage => _statusMessage;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get speechAvailable => _speechAvailable;

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    _attachTtsHandlers();

    try {
      _speechAvailable = await _speech.initialize(
        onError: _handleSpeechError,
        onStatus: _handleSpeechStatus,
        debugLogging: false,
      );
      if (_speechAvailable) {
        final locales = await _speech.locales();
        _preferredLocaleId = _pickPreferredLocale(locales);
        _statusMessage = 'Voice assistant ready.';
      } else {
        _statusMessage = 'Speech recognition is not available on this device.';
      }
    } catch (_) {
      _speechAvailable = false;
      _statusMessage = 'Unable to initialize voice recognition.';
    }

    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.46);
      await _tts.setPitch(1.0);
      
      // Load and apply normalized volume from app settings
      final prefs = await SharedPreferences.getInstance();
      final volume = prefs.getDouble('app_settings.audio_sounds_volume') ?? 0.75;
      await _tts.setVolume(volume);
      
      await _tts.setLanguage('en-US');
    } catch (_) {
      _statusMessage =
          'Voice recognition is ready, but spoken responses are unavailable.';
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> requestCommand(
    BuildContext context, {
    String hint = 'Tell me what to do',
    Future<void> Function(String command)? onRecognized,
    bool speakResponse = true,
  }) async {
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    if (!appSettings.voiceAssistantEnabled) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Voice assistant is disabled in settings.'),
          ),
        );
      return;
    }

    await ensureInitialized();
    clearDraft(notify: false);
    final rootContext = context;
    final effectiveSpeakResponse =
        speakResponse && appSettings.voiceResponsesEnabled;

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _VoiceCommandSheet(
        executionContext: rootContext,
        hint: hint,
        onRecognized: onRecognized,
        speakResponse: effectiveSpeakResponse,
      ),
    ).whenComplete(() async {
      await stopListening();
    });
  }

  Future<void> startListening() async {
    await ensureInitialized();
    if (!_speechAvailable) {
      _statusMessage = 'Speech recognition is not available on this device.';
      notifyListeners();
      return;
    }

    if (_isSpeaking) {
      await stopSpeaking();
    }

    _transcript = '';
    _statusMessage = 'Listening...';
    notifyListeners();

    await _speech.listen(
      onResult: _handleSpeechResult,
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
      localeId: _preferredLocaleId,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  Future<void> stopListening() async {
    if (!_speech.isListening) {
      if (_isListening) {
        _isListening = false;
        notifyListeners();
      }
      return;
    }

    await _speech.stop();
    _isListening = false;
    if (_transcript.trim().isEmpty) {
      _statusMessage = 'No speech captured yet.';
    } else {
      _statusMessage = 'Review the command and press run.';
    }
    notifyListeners();
  }

  Future<void> submitCommand(
    String command,
    BuildContext context, {
    Future<void> Function(String command)? onRecognized,
    bool speakResponse = true,
  }) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty) {
      _statusMessage = 'No command detected.';
      notifyListeners();
      return;
    }

    _lastCommand = trimmed;
    _transcript = trimmed;
    _statusMessage = 'Processing command...';
    notifyListeners();

    await stopListening();
    if (!context.mounted) return;

    if (onRecognized != null) {
      await onRecognized(trimmed);
      return;
    }

    await execute(trimmed, context, speakResponse: speakResponse);
  }

  Future<void> execute(
    String command,
    BuildContext context, {
    bool speakResponse = true,
  }) async {
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final intent = VoiceCommandInterpreter.interpret(command);
    final response = await _performIntent(intent, context);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response)),
    );

    _statusMessage = response;
    notifyListeners();

    if (speakResponse && appSettings.voiceResponsesEnabled) {
      await speak(response);
    }
  }

  Future<void> speak(String message) async {
    if (message.trim().isEmpty) return;
    await ensureInitialized();
    try {
      if (_speech.isListening) {
        await stopListening();
      }
      await _tts.stop();
      
      // Ensure volume is normalized to current platform settings
      final prefs = await SharedPreferences.getInstance();
      final volume = prefs.getDouble('app_settings.audio_sounds_volume') ?? 0.75;
      await _tts.setVolume(volume);
      
      await _tts.speak(message);
    } catch (_) {
      _statusMessage = 'Unable to speak on this device.';
      notifyListeners();
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _isSpeaking = false;
    notifyListeners();
  }

  void updateDraft(String value) {
    _transcript = value;
    notifyListeners();
  }

  void clearDraft({bool notify = true}) {
    _transcript = '';
    _statusMessage = 'Tap the microphone to start listening.';
    if (notify) {
      notifyListeners();
    }
  }

  Future<String> _performIntent(
    VoiceCommandIntent intent,
    BuildContext context,
  ) async {
    switch (intent.action) {
      case VoiceCommandAction.openHub:
        if (context.findAncestorWidgetOfExactType<ScrMSoft>() == null) {
          unawaited(Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScrMSoft()),
          ));
        }
        return 'Opening the RCAMARii hub.';
      case VoiceCommandAction.openFarm:
        await _openMainTab(context, 0);
        return 'Opening your farm dashboard.';
      case VoiceCommandAction.openActivities:
        await _openMainTab(context, 1);
        return 'Opening activities and ledger.';
      case VoiceCommandAction.openSupplies:
        await _openMainTab(context, 2);
        return 'Opening supplies and inventory.';
      case VoiceCommandAction.openKnowledge:
        await _openMainTab(context, 3);
        return 'Opening the knowledge library.';
      case VoiceCommandAction.openWeather:
        if (context.findAncestorWidgetOfExactType<ScrWeather>() == null) {
          unawaited(Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScrWeather()),
          ));
        }
        return 'Opening the weather forecast.';
      case VoiceCommandAction.openLogistics:
        if (context.findAncestorWidgetOfExactType<FrmLogistics>() == null) {
          unawaited(Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FrmLogistics()),
          ));
        }
        return 'Opening logistics.';
      case VoiceCommandAction.openWorkers:
        if (context.findAncestorWidgetOfExactType<ScrWorkers>() == null) {
          unawaited(Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScrWorkers()),
          ));
        }
        return 'Opening worker management.';
      case VoiceCommandAction.openTracker:
        if (context.findAncestorWidgetOfExactType<FtrackerSplashScreen>() ==
            null) {
          unawaited(Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FtrackerSplashScreen()),
          ));
        }
        return 'Opening the financial tracker.';
      case VoiceCommandAction.openProfitCalculator:
        if (context.findAncestorWidgetOfExactType<ProfitCalculatorScreen>() ==
            null) {
          unawaited(Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ProfitCalculatorScreen(),
            ),
          ));
        }
        return 'Opening the profit calculator.';
      case VoiceCommandAction.goBack:
        final popped = await Navigator.of(context).maybePop();
        return popped ? 'Going back.' : 'There is no previous screen to open.';
      case VoiceCommandAction.help:
        return VoiceCommandInterpreter.helpMessage;
      case VoiceCommandAction.stopSpeaking:
        await stopSpeaking();
        return 'Voice playback stopped.';
      case VoiceCommandAction.unknown:
        return 'I heard "$_lastCommand", but I do not have an action for it yet.';
    }
  }

  Future<void> _openMainTab(BuildContext context, int tabIndex) async {
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);
    navigationProvider.changeTab(tabIndex);

    if (context.findAncestorWidgetOfExactType<FrmMain>() == null) {
      unawaited(Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FrmMain(initialTab: tabIndex)),
      ));
    }
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    _transcript = result.recognizedWords.trim();
    _lastCommand = _transcript;
    _statusMessage = result.finalResult ? 'Command captured.' : 'Listening...';
    notifyListeners();
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    _isListening = false;
    _statusMessage = 'Voice error: ${error.errorMsg}';
    notifyListeners();
  }

  void _handleSpeechStatus(String status) {
    _isListening = status == 'listening';
    if (!_isListening && _transcript.trim().isNotEmpty) {
      _statusMessage = 'Review the command and press run.';
    }
    notifyListeners();
  }

  String? _pickPreferredLocale(List<LocaleName> locales) {
    const candidates = ['en_PH', 'en-US', 'en_US', 'fil_PH'];
    for (final candidate in candidates) {
      for (final locale in locales) {
        if (locale.localeId == candidate) {
          return locale.localeId;
        }
      }
    }
    if (locales.isEmpty) return null;
    return locales.first.localeId;
  }

  void _attachTtsHandlers() {
    _tts.setStartHandler(() {
      _isSpeaking = true;
      notifyListeners();
    });
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });
    _tts.setErrorHandler((_) {
      _isSpeaking = false;
      _statusMessage = 'Voice output is unavailable.';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    unawaited(_speech.stop());
    unawaited(_tts.stop());
    super.dispose();
  }
}

class _VoiceCommandSheet extends StatefulWidget {
  final BuildContext executionContext;
  final String hint;
  final Future<void> Function(String command)? onRecognized;
  final bool speakResponse;

  const _VoiceCommandSheet({
    required this.executionContext,
    required this.hint,
    required this.onRecognized,
    required this.speakResponse,
  });

  @override
  State<_VoiceCommandSheet> createState() => _VoiceCommandSheetState();
}

class _VoiceCommandSheetState extends State<_VoiceCommandSheet> {
  late final TextEditingController _controller;
  bool _manualOverride = false;

  @override
  void initState() {
    super.initState();
    final voice = Provider.of<VoiceCommandProvider>(context, listen: false);
    _controller = TextEditingController(text: voice.transcript);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Consumer<VoiceCommandProvider>(
        builder: (context, voice, _) {
          if (!_manualOverride && _controller.text != voice.transcript) {
            _controller.value = TextEditingValue(
              text: voice.transcript,
              selection: TextSelection.collapsed(
                offset: voice.transcript.length,
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice Assistant',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      voice.isListening
                          ? Icons.graphic_eq
                          : Icons.record_voice_over,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        voice.statusMessage,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                stylusHandwritingEnabled: false,
                controller: _controller,
                maxLines: 3,
                minLines: 2,
                decoration: InputDecoration(
                  labelText: 'Recognized command',
                  hintText: widget.hint,
                ),
                onChanged: (_) => _manualOverride = true,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: voice.isListening
                        ? voice.stopListening
                        : voice.startListening,
                    icon: Icon(
                      voice.isListening ? Icons.stop_circle : Icons.mic_rounded,
                    ),
                    label: Text(voice.isListening ? 'Stop' : 'Listen'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _manualOverride = false;
                        _controller.clear();
                      });
                      voice.clearDraft();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear'),
                  ),
                  OutlinedButton.icon(
                    onPressed: voice.isSpeaking
                        ? voice.stopSpeaking
                        : () => voice.speak(
                              VoiceCommandInterpreter.helpMessage,
                            ),
                    icon: Icon(
                      voice.isSpeaking ? Icons.stop_rounded : Icons.volume_up,
                    ),
                    label: Text(voice.isSpeaking ? 'Mute' : 'Test voice'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Try these commands',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: VoiceCommandInterpreter.sampleCommands
                    .map(
                      (sample) => ActionChip(
                        label: Text(sample),
                        onPressed: () {
                          setState(() {
                            _manualOverride = true;
                            _controller.text = sample;
                            _controller.selection = TextSelection.collapsed(
                              offset: _controller.text.length,
                            );
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final command = _controller.text.trim();
                    await voice.submitCommand(
                      command,
                      widget.executionContext,
                      onRecognized: widget.onRecognized,
                      speakResponse: widget.speakResponse,
                    );
                    if (!context.mounted) return;
                    if (command.isNotEmpty) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Run voice command'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
