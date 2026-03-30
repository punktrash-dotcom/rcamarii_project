import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/farm_model.dart';
import '../models/schedule_alert_model.dart';
import '../providers/activity_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/guideline_language_provider.dart';
import '../providers/supplies_provider.dart';
import '../providers/voice_command_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/weather_provider.dart';
import '../services/app_defaults_service.dart';
import '../services/app_localization_service.dart';
import '../services/app_properties_store.dart';
import '../services/farm_operations_service.dart';
import '../services/farming_advice_service.dart';
import '../services/guideline_localization_service.dart';
import '../services/rice_knowledge_service.dart';
import '../services/sugarcane_knowledge_service.dart';
import '../themes/app_visuals.dart';
import 'exit_screen.dart';
import 'farm_report_dashboard_screen.dart';
import 'frm_main.dart';
import 'help_screen.dart';
import 'profit_calculator_screen.dart';
import 'scr_tracker.dart';
import 'scr_workers.dart';
import 'settings_screen.dart';

/// Official logo used for app branding.
const String _kOfficialLogoAsset = 'lib/assets/images/logo2.png';

class ScrMSoft extends StatefulWidget {
  const ScrMSoft({super.key});

  @override
  State<ScrMSoft> createState() => _ScrMSoftState();
}

class _ScrMSoftState extends State<ScrMSoft> {
  final TextEditingController _aiController = TextEditingController();
  final ScrollController _chatController = ScrollController();
  final List<_AiMessage> _messages = [];
  final AppPropertiesStore _store = AppPropertiesStore.instance;

  bool _autopilotEnabled = true;
  bool _isAiThinking = false;
  _AiTopic _lastTopic = _AiTopic.summary;

  @override
  void initState() {
    super.initState();
    final language =
        Provider.of<GuidelineLanguageProvider>(context, listen: false)
            .selectedLanguage;
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final userName = appSettings.userName.trim();
    final greetingPrefix = userName.isEmpty
        ? 'RCAMARii is online.'
        : 'RCAMARii is online, $userName.';
    _messages.add(
      _AiMessage(
        role: 'assistant',
        text: AppLocalizationService.format(
          language,
          '$greetingPrefix I can read your farm status, deliveries, crew activity, supply pressure, weather, and crop timing. Ask me like a real assistant.',
        ),
        sentAt: DateTime.now(),
      ),
    );
    _loadSavedPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapProviders());
  }

  @override
  void dispose() {
    _aiController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPreferences() async {
    final savedAutopilot = await _store.getBool(
      AppDefaultsService.hubAutopilotEnabledKey,
    );
    if (!mounted || savedAutopilot == null) {
      return;
    }
    setState(() {
      _autopilotEnabled = savedAutopilot;
    });
  }

  Future<void> _setAutopilotEnabled(bool value) async {
    if (_autopilotEnabled == value) {
      return;
    }
    setState(() {
      _autopilotEnabled = value;
    });
    await _store.setBool(AppDefaultsService.hubAutopilotEnabledKey, value);
  }

  Future<void> _bootstrapProviders() async {
    final farm = Provider.of<FarmProvider>(context, listen: false);
    final activity = Provider.of<ActivityProvider>(context, listen: false);
    final equipment = Provider.of<EquipmentProvider>(context, listen: false);
    final supplies = Provider.of<SuppliesProvider>(context, listen: false);
    final deliveries = Provider.of<DeliveryProvider>(context, listen: false);
    final weather = Provider.of<WeatherProvider>(context, listen: false);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);

    await Future.wait([
      farm.refreshFarms(),
      activity.loadActivities(),
      equipment.loadEquipment(),
      supplies.loadSupplies(),
      deliveries.loadDeliveries(),
    ]);

    final selectedFarm =
        farm.selectedFarm ?? (farm.farms.isNotEmpty ? farm.farms.first : null);
    final location = selectedFarm != null
        ? '${selectedFarm.city}, ${selectedFarm.province}'
        : 'Metro Manila';
    if (appSettings.weatherAutoRefresh) {
      await weather.getWeather(location);
    }
  }

  Future<void> _postAiCommand(String raw, {bool speakResult = false}) async {
    final prompt = raw.trim();
    if (prompt.isEmpty || _isAiThinking) return;

    setState(() {
      _messages.add(
        _AiMessage(
          role: 'user',
          text: prompt,
          sentAt: DateTime.now(),
        ),
      );
      _aiController.clear();
      _isAiThinking = true;
    });
    _scrollToBottom();

    final snapshot = _buildAiSnapshot();
    final response = _generateAiResponse(prompt, snapshot);
    final responseDelay = Duration(
      milliseconds: (650 +
              (prompt.length.clamp(0, 80) * 9) +
              (response.length.clamp(0, 160) * 2))
          .clamp(850, 1900),
    );

    await Future.delayed(responseDelay);
    if (!mounted) return;

    setState(() {
      _messages.add(
        _AiMessage(
          role: 'assistant',
          text: response,
          sentAt: DateTime.now(),
        ),
      );
      _isAiThinking = false;
    });
    _scrollToBottom();
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    if (speakResult && appSettings.voiceResponsesEnabled) {
      Provider.of<VoiceCommandProvider>(context, listen: false).speak(response);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatController.hasClients) return;
      _chatController.animateTo(
        _chatController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  _AiSnapshot _buildAiSnapshot() {
    final farmProvider = Provider.of<FarmProvider>(context, listen: false);
    final activityProvider =
        Provider.of<ActivityProvider>(context, listen: false);
    final equipmentProvider =
        Provider.of<EquipmentProvider>(context, listen: false);
    final suppliesProvider =
        Provider.of<SuppliesProvider>(context, listen: false);
    final deliveryProvider =
        Provider.of<DeliveryProvider>(context, listen: false);
    final weatherProvider =
        Provider.of<WeatherProvider>(context, listen: false);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final language =
        Provider.of<GuidelineLanguageProvider>(context, listen: false)
            .selectedLanguage;

    final selectedFarm = farmProvider.selectedFarm;
    final cropAge = selectedFarm == null
        ? null
        : DateTime.now().difference(selectedFarm.date).inDays.clamp(0, 9999);
    final latestActivity = activityProvider.activities.isEmpty
        ? null
        : (activityProvider.activities.toList()
              ..sort((left, right) => right.date.compareTo(left.date)))
            .first;
    final timelines =
        farmProvider.farms.map(_HarvestTimelineEntry.fromFarm).toList()
          ..sort(
            (left, right) => left.daysToHarvest.compareTo(right.daysToHarvest),
          );
    final alerts = _buildContextualAlerts(selectedFarm, cropAge, language);

    return _AiSnapshot(
      userName: appSettings.userName.trim(),
      selectedFarm: selectedFarm,
      cropAge: cropAge,
      totalFarms: farmProvider.farms.length,
      totalActivities: activityProvider.activities.length,
      totalEquipment: equipmentProvider.items.length,
      totalSupplies: suppliesProvider.items.length,
      totalDeliveries: deliveryProvider.deliveries.length,
      pendingSugarcaneLoads: deliveryProvider.sugarcaneDeliveries.length,
      weather: weatherProvider.weatherData,
      weatherLoading: weatherProvider.isLoading,
      latestActivityName: latestActivity?.name,
      latestActivityFarm: latestActivity?.farm,
      latestActivityDate: latestActivity?.date,
      growthStage: selectedFarm == null || cropAge == null
          ? null
          : FarmOperationsService.growthStage(selectedFarm.type, cropAge),
      targetHarvest: selectedFarm == null
          ? null
          : FarmOperationsService.expectedHarvestDate(selectedFarm),
      alerts: alerts,
      nextHarvest: timelines.isEmpty ? null : timelines.first,
    );
  }

  String _generateAiResponse(String prompt, _AiSnapshot snapshot) {
    final lower = prompt.toLowerCase();
    final topic = _resolveTopic(lower);
    _lastTopic = topic;

    switch (topic) {
      case _AiTopic.greeting:
        return _buildGreetingResponse(snapshot);
      case _AiTopic.help:
        return _buildHelpResponse(snapshot);
      case _AiTopic.identity:
        return _buildIdentityResponse(snapshot);
      case _AiTopic.weather:
        return _buildWeatherResponse(snapshot);
      case _AiTopic.deliveries:
        return _buildDeliveryResponse(snapshot);
      case _AiTopic.inventory:
        return _buildInventoryResponse(snapshot);
      case _AiTopic.profit:
        return _buildProfitResponse(snapshot);
      case _AiTopic.farm:
        return _buildFarmResponse(snapshot);
      case _AiTopic.activities:
        return _buildActivityResponse(snapshot);
      case _AiTopic.alerts:
        return _buildAlertResponse(snapshot);
      case _AiTopic.harvest:
        return _buildHarvestResponse(snapshot);
      case _AiTopic.sugarcaneKnowledge:
        return _buildKnowledgeResponse(
          snapshot,
          SugarcaneKnowledgeService.answer(lower),
          cropName: 'sugarcane',
        );
      case _AiTopic.riceKnowledge:
        return _buildKnowledgeResponse(
          snapshot,
          RiceKnowledgeService.answer(lower),
          cropName: 'rice',
        );
      case _AiTopic.thanks:
        return _buildThanksResponse(snapshot);
      case _AiTopic.summary:
        return _buildSummaryResponse(snapshot);
      case _AiTopic.general:
        return _buildFallbackResponse(snapshot);
    }
  }

  _AiTopic _resolveTopic(String prompt) {
    if (SugarcaneKnowledgeService.isRelevant(prompt)) {
      return _AiTopic.sugarcaneKnowledge;
    }
    if (RiceKnowledgeService.isRelevant(prompt)) {
      return _AiTopic.riceKnowledge;
    }
    if (_containsAny(prompt, ['hello', 'hi', 'hey', 'good morning'])) {
      return _AiTopic.greeting;
    }
    if (_containsAny(prompt, ['thank', 'thanks', 'salamat'])) {
      return _AiTopic.thanks;
    }
    if (_containsAny(prompt, [
      'who are you',
      'what are you',
      'what can you do',
    ])) {
      return _AiTopic.identity;
    }
    if (_containsAny(prompt, ['help', 'guide', 'how do i use'])) {
      return _AiTopic.help;
    }
    if (_containsAny(prompt, ['weather', 'forecast', 'rain', 'wind'])) {
      return _AiTopic.weather;
    }
    if (_containsAny(
        prompt, ['delivery', 'deliveries', 'logistics', 'truck'])) {
      return _AiTopic.deliveries;
    }
    if (_containsAny(prompt, [
      'supply',
      'supplies',
      'inventory',
      'stock',
      'equipment',
      'buy',
    ])) {
      return _AiTopic.inventory;
    }
    if (_containsAny(
        prompt, ['profit', 'income', 'expense', 'roi', 'finance'])) {
      return _AiTopic.profit;
    }
    if (_containsAny(prompt, ['worker', 'crew', 'activity', 'labor', 'job'])) {
      return _AiTopic.activities;
    }
    if (_containsAny(prompt, [
      'alert',
      'fertilizer',
      'herbicide',
      'pesticide',
      'foliar',
      'timing',
    ])) {
      return _AiTopic.alerts;
    }
    if (_containsAny(prompt, [
      'harvest',
      'stage',
      'crop age',
      'maturity',
      'ready',
    ])) {
      return _AiTopic.harvest;
    }
    if (_containsAny(prompt, ['farm', 'field', 'estate', 'land'])) {
      return _AiTopic.farm;
    }
    if (_containsAny(prompt, [
      'summary',
      'status',
      'dashboard',
      'overview',
      'what is going on',
      'what should i do next',
    ])) {
      return _AiTopic.summary;
    }
    if (_containsAny(prompt, ['more', 'what else', 'and then', 'continue'])) {
      return _lastTopic;
    }
    return _AiTopic.general;
  }

  bool _containsAny(String prompt, List<String> phrases) {
    for (final phrase in phrases) {
      if (phrase.contains(' ')) {
        if (prompt.contains(phrase)) {
          return true;
        }
        continue;
      }
      if (RegExp(r'\b' + RegExp.escape(phrase) + r'\b').hasMatch(prompt)) {
        return true;
      }
    }
    return false;
  }

  String _buildGreetingResponse(_AiSnapshot snapshot) {
    final name = snapshot.userName.isEmpty ? '' : ' ${snapshot.userName}';
    return _joinResponseLines([
      'I am here$name. ${_autopilotEnabled ? 'Autopilot mode is active, so I will answer with a stronger recommendation bias.' : 'Manual mode is active, so I will keep the reply more neutral and leave the choice to you.'}',
      snapshot.selectedFarm == null
          ? 'I do not have an active farm selected yet.'
          : 'I am currently anchored to ${snapshot.selectedFarm!.name}, ${snapshot.selectedFarm!.type}, ${snapshot.cropAge ?? 0} days old.',
      'Ask for weather, crop timing, deliveries, supplies, workers, profit, or a full farm summary.',
    ]);
  }

  String _buildHelpResponse(_AiSnapshot snapshot) {
    return _joinResponseLines([
      'I can work like a local farm copilot inside this dashboard.',
      '- "Give me a farm summary"',
      '- "Is the weather risky today?"',
      '- "What should I watch for before harvest?"',
      '- "How are deliveries and crew activity looking?"',
      '- "What needs restocking?"',
      _nextActionLine(snapshot, _AiTopic.summary),
    ]);
  }

  String _buildIdentityResponse(_AiSnapshot snapshot) {
    return _joinResponseLines([
      'I am RCAMARii\'s built-in farm copilot. I am still local to the app, but I now answer from the live dashboard context instead of fixed one-line scripts.',
      'That means I can read the selected farm, crop age, alerts, weather, deliveries, supplies, equipment, and recent activity before I answer.',
      _nextActionLine(snapshot, _AiTopic.summary),
    ]);
  }

  String _buildWeatherResponse(_AiSnapshot snapshot) {
    final weather = snapshot.weather;
    if (snapshot.weatherLoading && weather == null) {
      return 'I am still waiting for the weather feed to finish loading. Ask again in a moment and I will turn it into an operational brief.';
    }
    if (weather == null) {
      return 'Weather data is not ready yet. If the active farm is set, I can pull a better brief after the weather service refresh completes.';
    }
    final pressureNote = weather.cloudiness >= 70 || weather.humidity >= 85
        ? 'Expect wet-field pressure.'
        : 'Field conditions look steadier.';
    return _joinResponseLines([
      'Current weather reads ${weather.description}, ${weather.temp.toStringAsFixed(0)} C, feels like ${weather.feelsLike.toStringAsFixed(0)} C, humidity ${weather.humidity}%, and wind ${weather.windSpeed.toStringAsFixed(1)} m/s.',
      pressureNote,
      _nextActionLine(snapshot, _AiTopic.weather),
    ]);
  }

  String _buildDeliveryResponse(_AiSnapshot snapshot) {
    final pendingLine = snapshot.pendingSugarcaneLoads == 0
        ? 'There are no pending sugarcane loads waiting in the queue.'
        : '${snapshot.pendingSugarcaneLoads} sugarcane load${snapshot.pendingSugarcaneLoads == 1 ? ' is' : 's are'} ready for review.';
    return _joinResponseLines([
      'I can see ${snapshot.totalDeliveries} recorded deliver${snapshot.totalDeliveries == 1 ? 'y' : 'ies'} across the logistics side.',
      pendingLine,
      _nextActionLine(snapshot, _AiTopic.deliveries),
    ]);
  }

  String _buildInventoryResponse(_AiSnapshot snapshot) {
    final stockLine = snapshot.totalSupplies == 0
        ? 'No supply records are loaded yet.'
        : '${snapshot.totalSupplies} supply record${snapshot.totalSupplies == 1 ? ' is' : 's are'} active.';
    return _joinResponseLines([
      '$stockLine Equipment count is ${snapshot.totalEquipment}.',
      snapshot.totalSupplies == 0
          ? 'Start by adding your first supply stock record so I can warn about pressure points.'
          : 'If you want, I can help you decide whether the next concern is stock, field timing, or crew execution.',
      _nextActionLine(snapshot, _AiTopic.inventory),
    ]);
  }

  String _buildProfitResponse(_AiSnapshot snapshot) {
    return _joinResponseLines([
      snapshot.totalDeliveries == 0
          ? 'The profit side is still thin because there are no delivery records to work from yet.'
          : 'The profit tools are ready. I would use the latest delivery records as the strongest base for a quick estimate.',
      snapshot.pendingSugarcaneLoads > 0
          ? 'You also have ${snapshot.pendingSugarcaneLoads} pending load${snapshot.pendingSugarcaneLoads == 1 ? '' : 's'} that could affect the next profit view.'
          : 'No pending sugarcane loads are sitting unreviewed right now.',
      _nextActionLine(snapshot, _AiTopic.profit),
    ]);
  }

  String _buildFarmResponse(_AiSnapshot snapshot) {
    final farm = snapshot.selectedFarm;
    if (farm == null) {
      return 'No active farm is selected yet. Open the estate workspace and pick a farm first, then I can talk about crop age, stage, and harvest timing with real context.';
    }
    return _joinResponseLines([
      'Active farm is ${farm.name}, a ${farm.type} block in ${farm.city}, ${farm.province}.',
      'Crop age is ${snapshot.cropAge ?? 0} days${snapshot.growthStage == null ? '' : ' and the current stage reads ${snapshot.growthStage}'}.',
      snapshot.targetHarvest == null
          ? ''
          : 'Target harvest is ${DateFormat('MMM d, y').format(snapshot.targetHarvest!)}.',
      _nextActionLine(snapshot, _AiTopic.farm),
    ]);
  }

  String _buildActivityResponse(_AiSnapshot snapshot) {
    return _joinResponseLines([
      'I can see ${snapshot.totalActivities} activity record${snapshot.totalActivities == 1 ? '' : 's'} in the workspace.',
      snapshot.latestActivityName == null
          ? 'No recent crew activity is available yet.'
          : 'Most recent item is ${snapshot.latestActivityName} on ${snapshot.latestActivityFarm ?? 'the selected farm'} from ${DateFormat('MMM d').format(snapshot.latestActivityDate!)}.',
      _nextActionLine(snapshot, _AiTopic.activities),
    ]);
  }

  String _buildAlertResponse(_AiSnapshot snapshot) {
    if (snapshot.selectedFarm == null) {
      return 'I need an active farm before I can turn crop-age alerts into a useful timing brief.';
    }
    if (snapshot.alerts.isEmpty) {
      return _joinResponseLines([
        'There is no immediate crop-age action window firing right now for ${snapshot.selectedFarm!.name}.',
        'That usually means the field is between action windows rather than missing data.',
        _nextActionLine(snapshot, _AiTopic.alerts),
      ]);
    }
    final topAlerts = snapshot.alerts.take(2).map((alert) => alert.title).join(
          ' and ',
        );
    return _joinResponseLines([
      'Top timing signal for ${snapshot.selectedFarm!.name}: $topAlerts.',
      'I found ${snapshot.alerts.length} current or near-current crop alerts tied to the selected farm.',
      _nextActionLine(snapshot, _AiTopic.alerts),
    ]);
  }

  String _buildHarvestResponse(_AiSnapshot snapshot) {
    final farm = snapshot.selectedFarm;
    if (farm != null && snapshot.targetHarvest != null) {
      final daysToHarvest = snapshot.targetHarvest!
          .difference(DateTime.now())
          .inDays
          .clamp(0, 9999);
      return _joinResponseLines([
        '${farm.name} is tracking toward harvest on ${DateFormat('MMM d, y').format(snapshot.targetHarvest!)}.',
        'That is about $daysToHarvest day${daysToHarvest == 1 ? '' : 's'} out${snapshot.growthStage == null ? '' : ', with stage ${snapshot.growthStage}'}.',
        _nextActionLine(snapshot, _AiTopic.harvest),
      ]);
    }
    if (snapshot.nextHarvest != null) {
      return _joinResponseLines([
        'The next harvest target in the workspace is ${snapshot.nextHarvest!.farm.name}.',
        snapshot.nextHarvest!.daysToHarvest < 0
            ? 'It is already due for harvest review.'
            : 'It is ${snapshot.nextHarvest!.daysToHarvest} days away based on the current timeline.',
        _nextActionLine(snapshot, _AiTopic.harvest),
      ]);
    }
    return 'I do not have enough farm timeline data yet to give a harvest read. Add or select a farm first.';
  }

  String _buildKnowledgeResponse(
    _AiSnapshot snapshot,
    String answer, {
    required String cropName,
  }) {
    return _joinResponseLines([
      'Here is the $cropName guidance read:',
      answer,
      _nextActionLine(snapshot, _AiTopic.alerts),
    ]);
  }

  String _buildThanksResponse(_AiSnapshot snapshot) {
    return _joinResponseLines([
      'Any time.',
      _nextActionLine(snapshot, _lastTopic),
    ]);
  }

  String _buildSummaryResponse(_AiSnapshot snapshot) {
    final selectedFarm = snapshot.selectedFarm;
    return _joinResponseLines([
      selectedFarm == null
          ? 'Here is the current dashboard picture.'
          : 'Here is the current picture around ${selectedFarm.name}.',
      '- Farms: ${snapshot.totalFarms}',
      '- Activities: ${snapshot.totalActivities}',
      '- Supplies: ${snapshot.totalSupplies}',
      '- Deliveries: ${snapshot.totalDeliveries}',
      '- Equipment: ${snapshot.totalEquipment}',
      if (selectedFarm != null)
        '- Stage: ${snapshot.growthStage ?? 'not yet computed'} at ${snapshot.cropAge ?? 0} days',
      if (snapshot.weather != null)
        '- Weather: ${snapshot.weather!.description}, ${snapshot.weather!.temp.toStringAsFixed(0)} C',
      _nextActionLine(snapshot, _AiTopic.summary),
    ]);
  }

  String _buildFallbackResponse(_AiSnapshot snapshot) {
    final opener = _pickVariant(
      [
        'I can work with that, but I need a slightly clearer direction.',
        'I did not miss the dashboard context, but I am missing the target of your question.',
        'I can answer that better if you point me at one area of the farm operation.',
      ],
      _messages.length,
    );
    return _joinResponseLines([
      opener,
      'Try weather, harvest timing, deliveries, supplies, workers, or a full summary.',
      _nextActionLine(snapshot, _AiTopic.summary),
    ]);
  }

  String _nextActionLine(_AiSnapshot snapshot, _AiTopic topic) {
    switch (topic) {
      case _AiTopic.weather:
        return snapshot.selectedFarm == null
            ? 'Next move: select a farm so I can tie the weather signal to crop stage.'
            : 'Next move: ask me if the weather is safe for fieldwork on ${snapshot.selectedFarm!.name}.';
      case _AiTopic.deliveries:
        return 'Next move: open Logistics if you want to check loads, trucking flow, or delivery gaps.';
      case _AiTopic.inventory:
        return 'Next move: review Supplies if you want to catch the next restock point before it slows field work.';
      case _AiTopic.profit:
        return 'Next move: open Profit Tools if you want a rough return estimate from current delivery data.';
      case _AiTopic.activities:
        return 'Next move: open the activity workspace if you want to inspect labor, worker assignment, or job progress.';
      case _AiTopic.alerts:
        return 'Next move: ask me for the top field alerts if you want the timing narrowed to immediate priorities.';
      case _AiTopic.harvest:
        return 'Next move: ask me which farm is closest to harvest if you want the board prioritized.';
      case _AiTopic.farm:
        return 'Next move: ask for a farm summary if you want weather, stage, and alerts merged into one read.';
      case _AiTopic.summary:
      case _AiTopic.general:
      case _AiTopic.greeting:
      case _AiTopic.help:
      case _AiTopic.identity:
      case _AiTopic.thanks:
      case _AiTopic.sugarcaneKnowledge:
      case _AiTopic.riceKnowledge:
        return snapshot.selectedFarm == null
            ? 'Next move: select a farm or ask for a weather, delivery, or inventory brief.'
            : 'Next move: ask me about ${snapshot.selectedFarm!.name} specifically and I will narrow the answer.';
    }
  }

  String _pickVariant(List<String> options, int seed) {
    if (options.isEmpty) {
      return '';
    }
    return options[seed % options.length];
  }

  String _joinResponseLines(List<String> lines) {
    return lines.where((line) => line.trim().isNotEmpty).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final farmProvider = Provider.of<FarmProvider>(context);
    final activityProvider = Provider.of<ActivityProvider>(context);
    final suppliesProvider = Provider.of<SuppliesProvider>(context);
    final deliveryProvider = Provider.of<DeliveryProvider>(context);
    final language =
        Provider.of<GuidelineLanguageProvider>(context).selectedLanguage;

    final selectedFarm = farmProvider.selectedFarm;
    final cropAge = selectedFarm == null
        ? null
        : DateTime.now().difference(selectedFarm.date).inDays.clamp(0, 9999);
    final contextualAlerts = _buildContextualAlerts(
      selectedFarm,
      cropAge,
      language,
    );
    final harvestTimelines = farmProvider.farms
        .map(_HarvestTimelineEntry.fromFarm)
        .toList()
      ..sort(
          (left, right) => left.daysToHarvest.compareTo(right.daysToHarvest));
    final bottomInset = mediaQuery.viewInsets.bottom;
    final isDarkMode = Provider.of<ThemeProvider>(context).darkTheme;

    return Scaffold(
      body: AppBackdrop(
        isDark: isDarkMode,
        backgroundImageAsset: 'lib/assets/images/background.png',
        backgroundImageOpacity: isDarkMode ? 0.24 : 0.38,
        imageScrimColor: isDarkMode
            ? Colors.black.withValues(alpha: 0.2)
            : AppVisuals.softWhite.withValues(alpha: 0.08),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(theme),
                const SizedBox(height: 24),
                _buildActionDeck(theme),
                const SizedBox(height: 24),
                _buildOperationalAlerts(
                  theme: theme,
                  selectedFarm: selectedFarm,
                  cropAge: cropAge,
                  alerts: contextualAlerts,
                ),
                const SizedBox(height: 24),
                _buildHarvestTargets(
                  theme: theme,
                  timelines: harvestTimelines,
                ),
                const SizedBox(height: 24),
                _buildTodayBoard(
                  theme: theme,
                  selectedFarm: selectedFarm,
                  cropAge: cropAge,
                  activityProvider: activityProvider,
                  suppliesProvider: suppliesProvider,
                  deliveryProvider: deliveryProvider,
                ),
                const SizedBox(height: 24),
                _buildCopilotConsole(theme, embedded: true),
                const SizedBox(height: 32),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => _openExitScreen(context),
                    icon:
                        const Icon(Icons.power_settings_new_rounded, size: 18),
                    label: Text(context.tr('Exit RCAMARii')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final welcomeName =
        appSettings.userName.isEmpty ? 'Ramari' : appSettings.userName;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppVisuals.primaryGold.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: AppVisuals.primaryGold.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                _kOfficialLogoAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: AppVisuals.primaryGold.withValues(alpha: 0.2),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.eco_rounded,
                    color: AppVisuals.deepGreen,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RCAMARii',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppVisuals.primaryGold,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    fontSize: 22,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome, $welcomeName',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppVisuals.textForestMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.help_outline_rounded,
            onTap: () => _openHelp(context),
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.person_outline_rounded,
            onTap: () => _openSettings(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAiInput(ThemeData theme, AppSettingsProvider appSettings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppVisuals.cloudGlass.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppVisuals.textForest.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _aiController,
              onSubmitted: (value) => _postAiCommand(value),
              style: const TextStyle(
                color: AppVisuals.textForest,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: context.tr('Ask your farm assistant...'),
                hintStyle: TextStyle(
                  color: AppVisuals.textForestMuted.withValues(alpha: 0.78),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (appSettings.voiceAssistantEnabled)
            IconButton(
              onPressed: _isAiThinking
                  ? null
                  : () => Provider.of<VoiceCommandProvider>(
                        context,
                        listen: false,
                      ).requestCommand(context),
              icon: const Icon(Icons.mic_rounded,
                  color: AppVisuals.textForest, size: 20),
            ),
          GestureDetector(
            onTap:
                _isAiThinking ? null : () => _postAiCommand(_aiController.text),
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppVisuals.panelSoft.withValues(alpha: 0.46),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppVisuals.textForest.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _isAiThinking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppVisuals.textForest,
                        ),
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded,
                      color: AppVisuals.textForest, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts(ThemeData theme) {
    final snapshot = _buildAiSnapshot();
    final prompts = <String>[
      if (snapshot.selectedFarm != null)
        'How is ${snapshot.selectedFarm!.name} doing?',
      'Give me a dashboard summary',
      'Any crop alerts I should know?',
      'How does the weather look?',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: prompts
          .map(
            (prompt) => ActionChip(
              onPressed: _isAiThinking ? null : () => _postAiCommand(prompt),
              backgroundColor: AppVisuals.panelSoft.withValues(alpha: 0.46),
              side: BorderSide(
                color: AppVisuals.textForest.withValues(alpha: 0.14),
              ),
              label: Text(
                prompt,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppVisuals.textForest,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAutopilotToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppVisuals.primaryGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('Autopilot'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppVisuals.primaryGold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 20,
            width: 36,
            child: Switch(
              value: _autopilotEnabled,
              onChanged: _setAutopilotEnabled,
              activeThumbColor: AppVisuals.primaryGold,
              activeTrackColor: AppVisuals.primaryGold.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopilotConsole(ThemeData theme, {bool embedded = false}) {
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final compactLayout = constraints.maxWidth < 320 || textScale > 1.15;
        final messages = Container(
          decoration: BoxDecoration(
            color: AppVisuals.cloudGlass.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppVisuals.textForest.withValues(alpha: 0.08),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ListView.builder(
              controller: _chatController,
              padding: const EdgeInsets.all(16),
              itemCount: 1 + _messages.length + (_isAiThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildQuickPrompts(theme),
                  );
                }
                final messageIndex = index - 1;
                if (_isAiThinking && messageIndex == _messages.length) {
                  return const _AiTypingBubble();
                }
                final message = _messages[messageIndex];
                return _AiChatBubble(
                  theme: theme,
                  message: message,
                  timestamp: DateFormat('h:mm a').format(message.sentAt),
                );
              },
            ),
          ),
        );
        final header = compactLayout
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Conversation Feed'),
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: AppVisuals.primaryGold),
                  ),
                  const SizedBox(height: 12),
                  _buildAutopilotToggle(theme),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Conversation Feed'),
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(color: AppVisuals.primaryGold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildAutopilotToggle(theme),
                ],
              );

        if (compactLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 12),
              SizedBox(
                height: embedded ? 280 : 320,
                child: messages,
              ),
              const SizedBox(height: 12),
              _buildAiInput(theme, appSettings),
            ],
          );
        }

        return SizedBox(
          height: embedded ? 430 : 470,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              Expanded(child: messages),
              const SizedBox(height: 12),
              _buildAiInput(theme, appSettings),
            ],
          ),
        );
      },
    );

    if (embedded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppVisuals.brandWhite.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: AppVisuals.textForest.withValues(alpha: 0.08),
          ),
        ),
        child: content,
      );
    }

    return FrostedPanel(
      radius: 36,
      child: content,
    );
  }

  Widget _buildActionDeck(ThemeData theme) {
    final actions = [
      _ActionItem(
        title: context.tr('Estate'),
        subtitle: context.tr('Open farms'),
        colors: const [
          AppVisuals.brandWhite,
          AppVisuals.fieldMist,
          AppVisuals.skyMist,
        ],
        accentColor: AppVisuals.brandRed,
        onTap: () => _openFrmMain(context),
      ),
      _ActionItem(
        title: context.tr('Finance'),
        subtitle: context.tr('Tracker'),
        colors: const [
          AppVisuals.brandWhite,
          Color(0xFFF0F8F8),
          Color(0xFFDDECEE),
        ],
        accentColor: AppVisuals.brandBlue,
        onTap: () => _openFtracker(context),
      ),
      _ActionItem(
        title: 'Profit Tools',
        subtitle: 'Final or Trial',
        colors: const [
          AppVisuals.brandWhite,
          Color(0xFFFAF9EC),
          Color(0xFFF4E7B3),
        ],
        accentColor: AppVisuals.lightGold,
        onTap: () => _openProfitEstimator(context),
      ),
      _ActionItem(
        title: context.tr('Reports'),
        subtitle: context.tr('Dashboard'),
        colors: const [
          AppVisuals.brandWhite,
          Color(0xFFF1F8F2),
          Color(0xFFE1F0DE),
        ],
        accentColor: AppVisuals.brandGreen,
        onTap: () => _openReports(context),
      ),
      _ActionItem(
        title: 'Employees',
        subtitle: context.tr('Crew panel'),
        colors: const [
          AppVisuals.brandWhite,
          Color(0xFFF8FAED),
          Color(0xFFE8F2D9),
        ],
        accentColor: AppVisuals.brandGreen,
        onTap: () => _openWorkers(context),
      ),
    ];

    return FrostedPanel(
      radius: 36,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Action Deck'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppVisuals.primaryGold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        'Fast routes into the farm workspace, tuned for daily operations.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppVisuals.textForestMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppVisuals.brandBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppVisuals.brandBlue.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  '${actions.length} routes',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppVisuals.textForest,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columnCount = constraints.maxWidth < 220 ? 1 : 2;
              final rows = <Widget>[];

              for (var start = 0; start < actions.length; start += columnCount) {
                final rowChildren = <Widget>[];

                for (var offset = 0; offset < columnCount; offset++) {
                  final index = start + offset;
                  rowChildren.add(
                    Expanded(
                      child: index < actions.length
                          ? actions[index]
                          : const SizedBox.shrink(),
                    ),
                  );

                  if (offset < columnCount - 1) {
                    rowChildren.add(const SizedBox(width: 16));
                  }
                }

                rows.add(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rowChildren,
                  ),
                );

                if (start + columnCount < actions.length) {
                  rows.add(const SizedBox(height: 16));
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: rows,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTodayBoard({
    required ThemeData theme,
    required dynamic selectedFarm,
    required int? cropAge,
    required ActivityProvider activityProvider,
    required SuppliesProvider suppliesProvider,
    required DeliveryProvider deliveryProvider,
  }) {
    return FrostedPanel(
      radius: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Recent Activity'),
            style: theme.textTheme.headlineMedium
                ?.copyWith(color: AppVisuals.primaryGold),
          ),
          const SizedBox(height: 20),
          if (activityProvider.activities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  context.tr('No recent activity recorded.'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activityProvider.activities.take(4).length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final activity = activityProvider.activities[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppVisuals.panelSoft.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppVisuals.primaryGold.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history_rounded,
                            size: 18, color: AppVisuals.primaryGold),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.name,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: AppVisuals.textForest),
                            ),
                            Text(
                              activity.farm,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppVisuals.textForest
                                      .withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('MMM d').format(activity.date),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppVisuals.primaryGold),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  List<ScheduleAlert> _buildContextualAlerts(
    Farm? selectedFarm,
    int? cropAge,
    GuidelineLanguage language,
  ) {
    if (selectedFarm == null || cropAge == null) {
      return [];
    }

    final alerts = [
      ...FarmingAdviceService.getAdviceForCrop(selectedFarm.type, cropAge),
      ...FarmOperationsService.inputAlertsForCrop(selectedFarm.type, cropAge),
    ].map((alert) {
      return GuidelineLocalizationService.translateAlert(alert, language);
    }).toList();

    final deduped = <ScheduleAlert>[];
    for (final alert in alerts) {
      final exists = deduped.any(
        (entry) =>
            entry.title == alert.title &&
            entry.startDay == alert.startDay &&
            entry.endDay == alert.endDay,
      );
      if (!exists) {
        deduped.add(alert);
      }
    }

    deduped.sort(
      (left, right) => _alertDistance(left, cropAge)
          .compareTo(_alertDistance(right, cropAge)),
    );
    return deduped.take(4).toList();
  }

  int _alertDistance(ScheduleAlert alert, int cropAge) {
    if (cropAge >= alert.startDay && cropAge <= alert.endDay) {
      return 0;
    }
    if (cropAge < alert.startDay) {
      return alert.startDay - cropAge;
    }
    return cropAge - alert.endDay + 45;
  }

  Widget _buildOperationalAlerts({
    required ThemeData theme,
    required Farm? selectedFarm,
    required int? cropAge,
    required List<ScheduleAlert> alerts,
  }) {
    return FrostedPanel(
      radius: 36,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crop Action Alerts',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppVisuals.primaryGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedFarm == null
                ? 'Select a farm to surface fertilizer, herbicide, pesticide, foliar, and harvest-prep timing.'
                : 'Stage-based windows for ${selectedFarm.name}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
          const SizedBox(height: 18),
          if (alerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppVisuals.panelSoft.withValues(alpha: 0.44),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                'No immediate crop-age action window is active yet.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            ...alerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HubAlertTile(
                  theme: theme,
                  alert: alert,
                  cropAge: cropAge,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHarvestTargets({
    required ThemeData theme,
    required List<_HarvestTimelineEntry> timelines,
  }) {
    return FrostedPanel(
      radius: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target Harvest Board',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppVisuals.primaryGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quick view of expected harvest timing for each crop and field.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
          const SizedBox(height: 18),
          if (timelines.isEmpty)
            Text(
              'No farms available yet.',
              style: theme.textTheme.bodyMedium,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: timelines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final timeline = timelines[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppVisuals.panelSoft.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppVisuals.brandGreen.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              timeline.farm.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppVisuals.textForest,
                              ),
                            ),
                          ),
                          Text(
                            timeline.daysToHarvest >= 0
                                ? '${timeline.daysToHarvest} d'
                                : 'Harvest due',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppVisuals.primaryGold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${timeline.farm.type}  |  ${timeline.stage}  |  ${timeline.farm.area.toStringAsFixed(1)} ha',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppVisuals.textForestMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: timeline.progress.clamp(0.0, 1.0),
                          minHeight: 8,
                          color: AppVisuals.brandGreen,
                          backgroundColor:
                              AppVisuals.brandGreen.withValues(alpha: 0.12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Age ${timeline.ageInDays} days',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppVisuals.textForestMuted,
                            ),
                          ),
                          Text(
                            'Target ${DateFormat('MMM d, y').format(timeline.targetHarvest)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppVisuals.textForestMuted,
                            ),
                          ),
                          Text(
                            'Yield ${timeline.projectedYield.toStringAsFixed(1)} t',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppVisuals.textForestMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openHelp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpScreen()),
    );
  }

  void _openFrmMain(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FrmMain()));
  }

  void _openWorkers(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ScrWorkers()));
  }

  void _openFtracker(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScrTracker()),
    );
  }

  void _openProfitEstimator(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ProfitCalculatorScreen()));
  }

  void _openReports(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FarmReportDashboardScreen()),
    );
  }

  void _openExitScreen(BuildContext context) {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const ExitScreen()));
  }
}

class _AiMessage {
  final String role;
  final String text;
  final DateTime sentAt;

  _AiMessage({
    required this.role,
    required this.text,
    required this.sentAt,
  });
}

class _AiChatBubble extends StatelessWidget {
  const _AiChatBubble({
    required this.theme,
    required this.message,
    required this.timestamp,
  });

  final ThemeData theme;
  final _AiMessage message;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final bubbleColor = isUser
        ? AppVisuals.primaryGold.withValues(alpha: 0.62)
        : AppVisuals.panelSoft.withValues(alpha: 0.46);
    final textColor = isUser ? AppVisuals.deepGreen : AppVisuals.textForest;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppVisuals.primaryGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppVisuals.primaryGold,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    isUser ? 'You' : 'RCAMARii Copilot',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppVisuals.textForestMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(20).copyWith(
                      bottomRight:
                          isUser ? Radius.zero : const Radius.circular(20),
                      bottomLeft:
                          isUser ? const Radius.circular(20) : Radius.zero,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    timestamp,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppVisuals.textForestMuted.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiTypingBubble extends StatelessWidget {
  const _AiTypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppVisuals.primaryGold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppVisuals.primaryGold,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppVisuals.panelSoft.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomLeft: Radius.zero,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(delay: 0),
                SizedBox(width: 4),
                _TypingDot(delay: 160),
                SizedBox(width: 4),
                _TypingDot(delay: 320),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot({required this.delay});

  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.35, end: 1),
      duration: Duration(milliseconds: 700 + delay),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppVisuals.primaryGold,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }
}

enum _AiTopic {
  greeting,
  help,
  identity,
  summary,
  weather,
  deliveries,
  inventory,
  profit,
  farm,
  activities,
  alerts,
  harvest,
  sugarcaneKnowledge,
  riceKnowledge,
  thanks,
  general,
}

class _AiSnapshot {
  const _AiSnapshot({
    required this.userName,
    required this.selectedFarm,
    required this.cropAge,
    required this.totalFarms,
    required this.totalActivities,
    required this.totalEquipment,
    required this.totalSupplies,
    required this.totalDeliveries,
    required this.pendingSugarcaneLoads,
    required this.weather,
    required this.weatherLoading,
    required this.latestActivityName,
    required this.latestActivityFarm,
    required this.latestActivityDate,
    required this.growthStage,
    required this.targetHarvest,
    required this.alerts,
    required this.nextHarvest,
  });

  final String userName;
  final Farm? selectedFarm;
  final int? cropAge;
  final int totalFarms;
  final int totalActivities;
  final int totalEquipment;
  final int totalSupplies;
  final int totalDeliveries;
  final int pendingSugarcaneLoads;
  final Weather? weather;
  final bool weatherLoading;
  final String? latestActivityName;
  final String? latestActivityFarm;
  final DateTime? latestActivityDate;
  final String? growthStage;
  final DateTime? targetHarvest;
  final List<ScheduleAlert> alerts;
  final _HarvestTimelineEntry? nextHarvest;
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppVisuals.lightGold.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppVisuals.lightGold.withValues(alpha: 0.45),
          ),
        ),
        child: Icon(icon, size: 20, color: AppVisuals.lightGold),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final Color accentColor;
  final VoidCallback onTap;

  const _ActionItem({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final translucentColors =
        colors.map((color) => color.withValues(alpha: 0.68)).toList();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: translucentColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: accentColor.withValues(alpha: 0.14),
              blurRadius: 18,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppVisuals.textForest,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppVisuals.textForestMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _OverviewRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _OverviewRow(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: 18, color: AppVisuals.primaryGold.withValues(alpha: 0.7)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppVisuals.primaryGold,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _HubAlertTile extends StatelessWidget {
  const _HubAlertTile({
    required this.theme,
    required this.alert,
    required this.cropAge,
  });

  final ThemeData theme;
  final ScheduleAlert alert;
  final int? cropAge;

  @override
  Widget build(BuildContext context) {
    final age = cropAge ?? -1;
    final isActive = age >= alert.startDay && age <= alert.endDay;
    final ahead = alert.startDay - age;
    final status = isActive
        ? 'Now'
        : ahead > 0
            ? 'In $ahead d'
            : 'Review';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: alert.color.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: alert.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(alert.icon, color: alert.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppVisuals.textForest,
                        ),
                      ),
                    ),
                    Text(
                      status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: alert.color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  alert.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HarvestTimelineEntry {
  const _HarvestTimelineEntry({
    required this.farm,
    required this.ageInDays,
    required this.stage,
    required this.targetHarvest,
    required this.projectedYield,
    required this.progress,
    required this.daysToHarvest,
  });

  final Farm farm;
  final int ageInDays;
  final String stage;
  final DateTime targetHarvest;
  final double projectedYield;
  final double progress;
  final int daysToHarvest;

  factory _HarvestTimelineEntry.fromFarm(Farm farm) {
    final ageInDays = FarmOperationsService.cropAgeInDays(farm.date);
    return _HarvestTimelineEntry(
      farm: farm,
      ageInDays: ageInDays,
      stage: FarmOperationsService.growthStage(farm.type, ageInDays),
      targetHarvest: FarmOperationsService.expectedHarvestDate(farm),
      projectedYield: FarmOperationsService.projectedYieldTons(farm),
      progress: FarmOperationsService.harvestProgress(farm.type, ageInDays),
      daysToHarvest: FarmOperationsService.daysUntilHarvest(farm),
    );
  }
}
