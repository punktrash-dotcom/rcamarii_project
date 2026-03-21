import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/activity_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/guideline_language_provider.dart';
import '../providers/supplies_provider.dart';
import '../providers/voice_command_provider.dart';
import '../providers/weather_provider.dart';
import '../services/app_localization_service.dart';
import '../services/guideline_localization_service.dart';
import '../services/rice_knowledge_service.dart';
import '../services/sugarcane_knowledge_service.dart';
import '../themes/app_visuals.dart';
import 'charts_screen.dart';
import 'exit_screen.dart';
import 'ftracker_splash_screen.dart';
import 'frm_logistics.dart';
import 'frm_main.dart';
import 'profit_calculator_screen.dart';
import 'scr_workers.dart';
import 'settings_screen.dart';

class ScrMSoft extends StatefulWidget {
  const ScrMSoft({super.key});

  @override
  State<ScrMSoft> createState() => _ScrMSoftState();
}

class _ScrMSoftState extends State<ScrMSoft> {
  final TextEditingController _aiController = TextEditingController();
  final ScrollController _chatController = ScrollController();
  final List<_AiMessage> _messages = [];

  bool _autopilotEnabled = true;
  double _autopilotSensitivity = 0.66;

  @override
  void initState() {
    super.initState();
    final language =
        Provider.of<GuidelineLanguageProvider>(context, listen: false)
            .selectedLanguage;
    _messages.add(
      _AiMessage(
        role: 'assistant',
        text: AppLocalizationService.format(
          language,
          'RCAMARii is online. Ask for farm status, delivery impact, supply guidance, or weather context.',
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapProviders());
  }

  @override
  void dispose() {
    _aiController.dispose();
    _chatController.dispose();
    super.dispose();
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

  void _postAiCommand(String raw, {bool speakResult = false}) {
    final prompt = raw.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _messages.add(_AiMessage(role: 'user', text: prompt));
      _aiController.clear();
    });
    _scrollToBottom();

    final response = _generateAiResponse(prompt);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() {
        _messages.add(_AiMessage(role: 'assistant', text: response));
      });
      _scrollToBottom();
      final appSettings =
          Provider.of<AppSettingsProvider>(context, listen: false);
      if (speakResult && appSettings.voiceResponsesEnabled) {
        Provider.of<VoiceCommandProvider>(context, listen: false)
            .speak(response);
      }
    });
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

  String _generateAiResponse(String prompt) {
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

    final lower = prompt.toLowerCase();
    final selectedFarm = farmProvider.selectedFarm;
    final totalFarms = farmProvider.farms.length;
    final totalActivities = activityProvider.activities.length;
    final totalEquipment = equipmentProvider.items.length;
    final totalSupplies = suppliesProvider.items.length;
    final totalDeliveries = deliveryProvider.deliveries.length;
    final weather = weatherProvider.weatherData;
    final workingMode = _autopilotEnabled ? 'Autopilot' : 'Manual';

    if (SugarcaneKnowledgeService.isRelevant(lower)) {
      return 'RCAMARii ($workingMode): ${SugarcaneKnowledgeService.answer(lower)}';
    }
    if (RiceKnowledgeService.isRelevant(lower)) {
      return 'RCAMARii ($workingMode): ${RiceKnowledgeService.answer(lower)}';
    }

    if (lower.contains('weather') ||
        lower.contains('forecast') ||
        lower.contains('rain')) {
      if (weather == null) {
        return 'Weather data is still loading. Try again in a moment.';
      }
      return '$workingMode weather brief: ${weather.description}, ${weather.temp.toStringAsFixed(0)} degrees, humidity ${weather.humidity} percent.';
    }

    if (lower.contains('delivery') || lower.contains('logistics')) {
      return '$workingMode sees $totalDeliveries recorded deliveries. ${deliveryProvider.sugarcaneDeliveries.isEmpty ? 'No sugarcane delivery is waiting in the queue.' : 'Sugarcane delivery records are ready for profit review.'}';
    }

    if (lower.contains('buy') ||
        lower.contains('supply') ||
        lower.contains('inventory')) {
      return '$workingMode inventory brief: $totalSupplies supply records and $totalEquipment equipment records are active. ${totalSupplies == 0 ? 'Start by adding your first supply stock record.' : 'Open Supplies to review what needs replenishment next.'}';
    }

    if (lower.contains('profit') ||
        lower.contains('income') ||
        lower.contains('roi')) {
      return 'Profit view is ready. ${deliveryProvider.sugarcaneDeliveries.isEmpty ? 'Add or update a sugarcane delivery first.' : 'Use the latest sugarcane delivery to estimate gross and net return.'}';
    }

    if (lower.contains('farm') ||
        lower.contains('estate') ||
        lower.contains('field')) {
      if (selectedFarm == null) {
        return 'No active farm is selected yet. Add a farm or pick one from the estate dashboard.';
      }
      final age = DateTime.now().difference(selectedFarm.date).inDays;
      return '$workingMode focus is ${selectedFarm.name}, a ${selectedFarm.type} farm in ${selectedFarm.city}. Crop age is ${age < 0 ? 0 : age} days.';
    }

    if (lower.contains('activity') ||
        lower.contains('crew') ||
        lower.contains('worker')) {
      return '$workingMode sees $totalActivities logged activity records. Use Activities to review labor cost, worker assignment, and job progress.';
    }

    return 'RCAMARii summary: $totalFarms farms, $totalActivities activities, $totalSupplies supplies, $totalDeliveries deliveries, and $totalEquipment equipment records. ${selectedFarm != null ? 'Active farm: ${selectedFarm.name}.' : 'Select a farm to make the guidance more specific.'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final farmProvider = Provider.of<FarmProvider>(context);
    final activityProvider = Provider.of<ActivityProvider>(context);
    final suppliesProvider = Provider.of<SuppliesProvider>(context);
    final equipmentProvider = Provider.of<EquipmentProvider>(context);
    final deliveryProvider = Provider.of<DeliveryProvider>(context);
    final weatherProvider = Provider.of<WeatherProvider>(context);

    final selectedFarm = farmProvider.selectedFarm;
    final cropAge = selectedFarm == null
        ? null
        : DateTime.now().difference(selectedFarm.date).inDays.clamp(0, 9999);
    final weather = weatherProvider.weatherData;
    final screenWidth = mediaQuery.size.width;
    final isWide = screenWidth >= 1100;
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Scaffold(
      body: AppBackdrop(
        isDark: true,
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(18, 16, 18, 28 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(theme, weather),
                const SizedBox(height: 18),
                _buildWorkspaceControls(theme),
                const SizedBox(height: 16),
                _buildHeroPanel(
                  theme: theme,
                  selectedFarm: selectedFarm,
                  cropAge: cropAge,
                  deliveryProvider: deliveryProvider,
                ),
                const SizedBox(height: 16),
                _buildStatStrip(
                  theme: theme,
                  farmCount: farmProvider.farms.length,
                  activityCount: activityProvider.activities.length,
                  supplyCount: suppliesProvider.items.length,
                  deliveryCount: deliveryProvider.deliveries.length,
                ),
                const SizedBox(height: 16),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _buildCopilotConsole(theme),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _buildActionDeck(theme),
                            const SizedBox(height: 16),
                            _buildLiveOverview(
                              theme: theme,
                              selectedFarm: selectedFarm,
                              cropAge: cropAge,
                              weather: weather,
                              equipmentCount: equipmentProvider.items.length,
                              pendingSugarcaneCount:
                                  deliveryProvider.sugarcaneDeliveries.length,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildCopilotConsole(theme),
                  const SizedBox(height: 16),
                  _buildActionDeck(theme),
                  const SizedBox(height: 16),
                  _buildLiveOverview(
                    theme: theme,
                    selectedFarm: selectedFarm,
                    cropAge: cropAge,
                    weather: weather,
                    equipmentCount: equipmentProvider.items.length,
                    pendingSugarcaneCount:
                        deliveryProvider.sugarcaneDeliveries.length,
                  ),
                ],
                const SizedBox(height: 16),
                _buildTodayBoard(
                  theme: theme,
                  selectedFarm: selectedFarm,
                  cropAge: cropAge,
                  activityProvider: activityProvider,
                  suppliesProvider: suppliesProvider,
                  deliveryProvider: deliveryProvider,
                ),
                const SizedBox(height: 18),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => _openExitScreen(context),
                    icon:
                        const Icon(Icons.power_settings_new_rounded, size: 16),
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

  Widget _buildTopBar(ThemeData theme, dynamic weather) {
    final voiceProvider =
        Provider.of<VoiceCommandProvider>(context, listen: false);
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final statusPills = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _TopPill(
          icon: Icons.wb_cloudy_outlined,
          label: weather == null
              ? context.tr('Weather offline')
              : '${weather.temp.toStringAsFixed(0)} deg  ${weather.description}',
        ),
        if (appSettings.voiceAssistantEnabled)
          FilledButton.tonalIcon(
            onPressed: () => voiceProvider.requestCommand(context),
            icon: const Icon(Icons.mic_none_rounded),
            label: Text(context.tr('Voice')),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RCAMARii Copilot',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 12),
              statusPills,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RCAMARii Copilot',
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Align(
                alignment: Alignment.topRight,
                child: statusPills,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWorkspaceControls(ThemeData theme) {
    final scheme = theme.colorScheme;
    final languageProvider = Provider.of<GuidelineLanguageProvider>(context);

    return FrostedPanel(
      radius: 28,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 640;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked) ...[
                Text(
                  context.tr('Workspace Controls'),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Choose the preferred language for supply guidance before opening the field modules.',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => _openSettings(context),
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: Text(context.tr('Settings')),
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Workspace Controls'),
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr(
                              'Choose the preferred language for supply guidance before opening the field modules.',
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _openSettings(context),
                      icon: const Icon(Icons.settings_rounded, size: 18),
                      label: Text(context.tr('Settings')),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: GuidelineLanguage.values.map((language) {
                  final selected =
                      languageProvider.selectedLanguage == language;
                  return ChoiceChip(
                    label: Text(
                      GuidelineLocalizationService.languageLabel(language),
                    ),
                    selected: selected,
                    onSelected: (_) => languageProvider.setLanguage(language),
                    showCheckmark: false,
                    selectedColor: scheme.primary,
                    backgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.92),
                    side: BorderSide(
                      color: selected
                          ? scheme.primary
                          : scheme.outline.withValues(alpha: 0.45),
                    ),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? scheme.onPrimary : scheme.onSurface,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroPanel({
    required ThemeData theme,
    required dynamic selectedFarm,
    required int? cropAge,
    required DeliveryProvider deliveryProvider,
  }) {
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final suggestions = [
      context.tr('What does my active farm need this week?'),
      context.tr('What should I buy next?'),
      context.tr('Summarize my deliveries'),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF163425),
            Color(0xFF30563B),
            Color(0xFF7DAA5C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AppVisuals.softGlow(AppVisuals.forestEmerald),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 720;
              final heroCopy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedFarm == null
                        ? context.tr('Your farm command center is ready.')
                        : context.tr(
                            "Today's focus is {farm}.",
                            {'farm': selectedFarm.name},
                          ),
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    selectedFarm == null
                        ? context.tr(
                            'Add a farm, connect a delivery, or ask RCAMARii what to do next.',
                          )
                        : context.tr(
                            '{crop} is active, {days} days from planting, with {deliveries} sugarcane deliveries in the current queue.',
                            {
                              'crop': selectedFarm.type,
                              'days': '${cropAge ?? 0}',
                              'deliveries':
                                  '${deliveryProvider.sugarcaneDeliveries.length}',
                            },
                          ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              );
              final heroIcon = Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white.withValues(alpha: 0.14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heroCopy,
                    const SizedBox(height: 14),
                    heroIcon,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heroCopy),
                  const SizedBox(width: 18),
                  heroIcon,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: suggestions
                .map(
                  (prompt) => GestureDetector(
                    onTap: () => _postAiCommand(prompt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        prompt,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 620;
              final input = TextField(
                stylusHandwritingEnabled: false,
                controller: _aiController,
                onSubmitted: (value) => _postAiCommand(value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: context.tr('Ask RCAMARii for a field brief...'),
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              );
              final sendButton = ElevatedButton(
                onPressed: () => _postAiCommand(_aiController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppVisuals.forestEmerald,
                  minimumSize: const Size(58, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Icon(Icons.arrow_forward_rounded),
              );
              final voiceButton = appSettings.voiceAssistantEnabled
                  ? FilledButton.tonal(
                      onPressed: () => Provider.of<VoiceCommandProvider>(
                        context,
                        listen: false,
                      ).requestCommand(
                        context,
                        hint: context.trRead('Ask RCAMARii'),
                        speakResponse: false,
                        onRecognized: (command) async {
                          _postAiCommand(command, speakResult: true);
                        },
                      ),
                      style: FilledButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        minimumSize: const Size(54, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Icon(Icons.mic_rounded),
                    )
                  : null;

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    input,
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (voiceButton != null) ...[
                          voiceButton,
                          const SizedBox(width: 10),
                        ],
                        sendButton,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: input),
                  if (voiceButton != null) ...[
                    const SizedBox(width: 10),
                    voiceButton,
                  ],
                  const SizedBox(width: 10),
                  sendButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatStrip({
    required ThemeData theme,
    required int farmCount,
    required int activityCount,
    required int supplyCount,
    required int deliveryCount,
  }) {
    final stats = [
      _HeroStat(context.tr('Farms'), farmCount.toString(), Icons.eco_rounded),
      _HeroStat(context.tr('Activities'), activityCount.toString(),
          Icons.work_history_rounded),
      _HeroStat(context.tr('Supplies'), supplyCount.toString(),
          Icons.inventory_2_rounded),
      _HeroStat(context.tr('Deliveries'), deliveryCount.toString(),
          Icons.local_shipping_rounded),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats
          .map(
            (stat) => FrostedPanel(
              radius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.12),
                    child: Icon(stat.icon,
                        size: 18, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        stat.value,
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCopilotConsole(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return FrostedPanel(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 560;
              final autopilotChip = Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('Autopilot'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: _autopilotEnabled,
                        onChanged: (value) =>
                            setState(() => _autopilotEnabled = value),
                        activeThumbColor: AppVisuals.forestEmerald,
                      ),
                    ),
                  ],
                ),
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Conversation Feed'),
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    autopilotChip,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Conversation Feed'),
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  autopilotChip,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Use typed or voice prompts. RCAMARii answers from your current farm context and existing knowledge logic.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0E1711) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.45),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: ListView.builder(
                controller: _chatController,
                padding: const EdgeInsets.all(14),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message.role == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          message.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isUser
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                            fontWeight:
                                isUser ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                context.tr('Sensitivity'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Slider(
                  value: _autopilotSensitivity,
                  onChanged: (value) =>
                      setState(() => _autopilotSensitivity = value),
                  min: 0.2,
                  max: 0.95,
                  divisions: 15,
                  activeColor: theme.colorScheme.primary,
                ),
              ),
              Text(
                '${(_autopilotSensitivity * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionDeck(ThemeData theme) {
    final actions = [
      _ActionItem(
        title: context.tr('Estate'),
        subtitle: context.tr('Open farms'),
        icon: Icons.eco_rounded,
        colors: const [Color(0xFF355D3B), Color(0xFF8ABF63)],
        onTap: () => _openFrmMain(context),
      ),
      _ActionItem(
        title: context.tr('Logistics'),
        subtitle: context.tr('Deliveries'),
        icon: Icons.local_shipping_rounded,
        colors: const [Color(0xFF6B3E2A), Color(0xFFD8A057)],
        onTap: () => _openLogistics(context),
      ),
      _ActionItem(
        title: context.tr('Workers'),
        subtitle: context.tr('Crew panel'),
        icon: Icons.people_alt_rounded,
        colors: const [Color(0xFF30495B), Color(0xFF7FB6D1)],
        onTap: () => _openWorkers(context),
      ),
      _ActionItem(
        title: context.tr('Finance'),
        subtitle: context.tr('Tracker'),
        icon: Icons.account_balance_wallet_rounded,
        colors: const [Color(0xFF50342D), Color(0xFFD67E58)],
        onTap: () => _openFtracker(context),
      ),
      _ActionItem(
        title: 'SugarCalc',
        subtitle: context.tr('Estimate ROI'),
        icon: Icons.calculate_rounded,
        colors: const [Color(0xFF244A33), Color(0xFF6AB17B)],
        onTap: () => _openProfitEstimator(context),
      ),
      _ActionItem(
        title: context.tr('Reports'),
        subtitle: context.tr('Charts'),
        icon: Icons.assessment_rounded,
        colors: const [Color(0xFF3F3863), Color(0xFF9B90D4)],
        onTap: () => _openReports(context),
      ),
    ];

    return FrostedPanel(
      radius: 30,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth < 520 ? 1 : 2;
          final itemHeight = crossAxisCount == 1 ? 124.0 : 140.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Action Deck'),
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Jump into core modules without losing the copilot context.',
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: itemHeight,
                ),
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return InkWell(
                    onTap: action.onTap,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: action.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: AppVisuals.softGlow(action.colors.last),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(action.icon, color: Colors.white, size: 22),
                          const SizedBox(height: 18),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    action.subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.78,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLiveOverview({
    required ThemeData theme,
    required dynamic selectedFarm,
    required int? cropAge,
    required dynamic weather,
    required int equipmentCount,
    required int pendingSugarcaneCount,
  }) {
    final items = <_InsightCard>[
      _InsightCard(
        title: selectedFarm == null
            ? context.tr('No active farm')
            : selectedFarm.name,
        message: selectedFarm == null
            ? context.tr('Select a farm to make RCAMARii specific.')
            : '${selectedFarm.type} • ${cropAge ?? 0} days • ${selectedFarm.area.toStringAsFixed(1)} ha',
        icon: Icons.eco_rounded,
      ),
      _InsightCard(
        title: weather == null
            ? context.tr('Weather pending')
            : context.tr('Weather brief'),
        message: weather == null
            ? context.tr('Forecast sync will appear here.')
            : '${weather.description} • ${weather.temp.toStringAsFixed(0)} deg • humidity ${weather.humidity}%',
        icon: Icons.cloud_outlined,
      ),
      _InsightCard(
        title: context.tr('Equipment readiness'),
        message: context.tr(
          '{count} equipment records available for review.',
          {'count': '$equipmentCount'},
        ),
        icon: Icons.precision_manufacturing_rounded,
      ),
      _InsightCard(
        title: context.tr('Sugarcane queue'),
        message: context.tr(
          '{count} delivery records are ready for profit work.',
          {'count': '$pendingSugarcaneCount'},
        ),
        icon: Icons.local_shipping_rounded,
      ),
    ];

    return FrostedPanel(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Live Overview'),
              style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.12),
                      child: Icon(item.icon,
                          size: 18, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(item.message, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    final activitiesThisWeek = activityProvider.activities
        .where(
            (activity) => DateTime.now().difference(activity.date).inDays <= 7)
        .length;
    final boardItems = [
      _TodayItem(
        title: context.tr('Field focus'),
        detail: selectedFarm == null
            ? context.tr('Choose a farm to unlock crop-stage guidance.')
            : context.tr(
                '{farm} is {days} days from planting.',
                {
                  'farm': selectedFarm.name,
                  'days': '${cropAge ?? 0}',
                },
              ),
        icon: Icons.crop_free_rounded,
      ),
      _TodayItem(
        title: context.tr('Activity pulse'),
        detail: context.tr(
          '{count} activity records were logged in the last 7 days.',
          {'count': '$activitiesThisWeek'},
        ),
        icon: Icons.timeline_rounded,
      ),
      _TodayItem(
        title: context.tr('Inventory posture'),
        detail: context.tr(
          '{count} supply entries are available for review.',
          {'count': '${suppliesProvider.items.length}'},
        ),
        icon: Icons.inventory_rounded,
      ),
      _TodayItem(
        title: context.tr('Delivery posture'),
        detail: context.tr(
          '{count} deliveries are recorded across the app.',
          {'count': '${deliveryProvider.deliveries.length}'},
        ),
        icon: Icons.route_rounded,
      ),
    ];

    return FrostedPanel(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Today Board'),
              style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'A fast operational summary driven by your existing farm records.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 700
                      ? 2
                      : 1;
              const spacing = 12.0;
              final itemWidth = crossAxisCount == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - (spacing * (crossAxisCount - 1))) /
                      crossAxisCount;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: boardItems.map((item) {
                  return SizedBox(
                    width: itemWidth,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                            child: Icon(item.icon,
                                size: 18, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(height: 18),
                          Text(item.title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(item.detail, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openFrmMain(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FrmMain()));
  }

  void _openLogistics(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FrmLogistics()));
  }

  void _openWorkers(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ScrWorkers()));
  }

  void _openFtracker(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FtrackerSplashScreen()));
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openProfitEstimator(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfitCalculatorScreen()),
    );
  }

  void _openReports(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ChartsScreen()));
  }

  void _openExitScreen(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ExitScreen()));
  }
}

class _AiMessage {
  final String role;
  final String text;

  const _AiMessage({
    required this.role,
    required this.text,
  });
}

class _ActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });
}

class _HeroStat {
  final String label;
  final String value;
  final IconData icon;

  const _HeroStat(this.label, this.value, this.icon);
}

class _InsightCard {
  final String title;
  final String message;
  final IconData icon;

  const _InsightCard({
    required this.title,
    required this.message,
    required this.icon,
  });
}

class _TodayItem {
  final String title;
  final String detail;
  final IconData icon;

  const _TodayItem({
    required this.title,
    required this.detail,
    required this.icon,
  });
}

class _TopPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TopPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.92)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
