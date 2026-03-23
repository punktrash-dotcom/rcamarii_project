import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/activity_provider.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/guideline_language_provider.dart';
import '../providers/supplies_provider.dart';
import '../providers/voice_command_provider.dart';
import '../providers/theme_provider.dart';
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

/// Brand mark in the main hub top bar (`lib/assets/icons/iconic.png`).
const String _kIconicPngAsset = 'lib/assets/icons/iconic.png';

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
    final isDarkMode = Provider.of<ThemeProvider>(context).darkTheme;

    return Scaffold(
      body: AppBackdrop(
        isDark: isDarkMode,
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(theme, weather),
                const SizedBox(height: 24),
                _buildHeroPanel(
                  theme: theme,
                  selectedFarm: selectedFarm,
                  cropAge: cropAge,
                  deliveryProvider: deliveryProvider,
                ),
                const SizedBox(height: 24),
                _buildStatStrip(
                  theme: theme,
                  farmCount: farmProvider.farms.length,
                  activityCount: activityProvider.activities.length,
                  supplyCount: suppliesProvider.items.length,
                  deliveryCount: deliveryProvider.deliveries.length,
                ),
                const SizedBox(height: 24),
                _buildWorkspaceControls(theme),
                const SizedBox(height: 24),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _buildCopilotConsole(theme),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _buildActionDeck(theme),
                            const SizedBox(height: 24),
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
                  const SizedBox(height: 24),
                  _buildActionDeck(theme),
                  const SizedBox(height: 24),
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
                const SizedBox(height: 24),
                _buildTodayBoard(
                  theme: theme,
                  selectedFarm: selectedFarm,
                  cropAge: cropAge,
                  activityProvider: activityProvider,
                  suppliesProvider: suppliesProvider,
                  deliveryProvider: deliveryProvider,
                ),
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

  Widget _buildTopBar(ThemeData theme, dynamic weather) {
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
            child: Image.asset(
              _kIconicPngAsset,
              fit: BoxFit.cover,
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RAMARI',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppVisuals.primaryGold,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'FARM & FINANCE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppVisuals.lightGold.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppVisuals.textForest.withValues(alpha: 0.3),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (weather != null)
            _TopPill(
              icon: Icons.wb_sunny_rounded,
              label: '${weather.temp.toStringAsFixed(0)}°',
            ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () {},
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

  Widget _buildWorkspaceControls(ThemeData theme) {
    final scheme = theme.colorScheme;
    final languageProvider = Provider.of<GuidelineLanguageProvider>(context);
    final audioProvider = Provider.of<AppAudioProvider>(context, listen: false);
    final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);

    return FrostedPanel(
      radius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Workspace Controls'),
                      style: theme.textTheme.headlineMedium?.copyWith(color: AppVisuals.primaryGold),
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
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: GuidelineLanguage.values.map((language) {
              final selected = languageProvider.selectedLanguage == language;
              return ChoiceChip(
                label: Text(
                  GuidelineLocalizationService.languageLabel(language),
                ),
                selected: selected,
                onSelected: (_) async {
                  if (selected) return;
                  await languageProvider.setLanguage(language);
                  if (appSettings.audioSoundsEnabled) {
                    final String assetPath = switch (language) {
                      GuidelineLanguage.english => 'lib/assets/audio/english.mp3',
                      GuidelineLanguage.tagalog => 'lib/assets/audio/tagalog.mp3',
                      GuidelineLanguage.visayan => 'lib/assets/audio/visayan.mp3',
                    };
                    await audioProvider.playAsset(
                      assetPath: assetPath,
                      enabled: true,
                    );
                  }
                },
                showCheckmark: false,
                selectedColor: AppVisuals.primaryGold,
                backgroundColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                side: BorderSide(
                  color: selected
                      ? AppVisuals.primaryGold
                      : scheme.outline.withValues(alpha: 0.2),
                ),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: selected ? AppVisuals.deepGreen : AppVisuals.textForest,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: () => _openSettings(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppVisuals.primaryGold.withValues(alpha: 0.1),
                foregroundColor: AppVisuals.primaryGold,
              ),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: Text(context.tr('Settings')),
            ),
          ),
        ],
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
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE8F2EE),
            const Color(0xFFD8E8E0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppVisuals.primaryGold.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
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
                      context.tr('DASHBOARD'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppVisuals.primaryGold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedFarm == null
                          ? context.tr('Welcome to Ramari')
                          : selectedFarm.name,
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: AppVisuals.textForest,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppVisuals.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppVisuals.primaryGold.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppVisuals.primaryGold,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildAiInput(theme, appSettings),
        ],
      ),
    );
  }

  Widget _buildAiInput(ThemeData theme, AppSettingsProvider appSettings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppVisuals.textForest.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _aiController,
              onSubmitted: (value) => _postAiCommand(value),
              style: const TextStyle(color: AppVisuals.textForest, fontSize: 14),
              decoration: InputDecoration(
                hintText: context.tr('Ask your farm assistant...'),
                hintStyle: TextStyle(
                  color: AppVisuals.textForestMuted.withValues(alpha: 0.55),
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
              onPressed: () => Provider.of<VoiceCommandProvider>(
                context,
                listen: false,
              ).requestCommand(context),
              icon: const Icon(Icons.mic_rounded, color: AppVisuals.primaryGold, size: 20),
            ),
          GestureDetector(
            onTap: () => _postAiCommand(_aiController.text),
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppVisuals.primaryGold,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppVisuals.primaryGold.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: AppVisuals.deepGreen, size: 18),
            ),
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
      spacing: 16,
      runSpacing: 16,
      children: stats
          .map(
            (stat) => FrostedPanel(
              radius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppVisuals.primaryGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(stat.icon,
                        size: 20, color: AppVisuals.primaryGold),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.label.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppVisuals.primaryGold.withValues(alpha: 0.6),
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        stat.value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppVisuals.textForest,
                          fontWeight: FontWeight.w900,
                        ),
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
    return FrostedPanel(
      radius: 36,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Conversation Feed'),
                  style: theme.textTheme.headlineMedium?.copyWith(color: AppVisuals.primaryGold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppVisuals.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      context.tr('Autopilot'),
                      style: theme.textTheme.labelSmall?.copyWith(color: AppVisuals.primaryGold, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 20,
                      width: 36,
                      child: Switch(
                        value: _autopilotEnabled,
                        onChanged: (value) => setState(() => _autopilotEnabled = value),
                        activeThumbColor: AppVisuals.primaryGold,
                        activeTrackColor: AppVisuals.primaryGold.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF5F2),
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
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message.role == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? AppVisuals.primaryGold
                            : const Color(0xFFE5EFE8),
                        borderRadius: BorderRadius.circular(20).copyWith(
                          bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                          bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        message.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isUser
                              ? AppVisuals.deepGreen
                              : AppVisuals.textForest,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionDeck(ThemeData theme) {
    final g = AppVisuals.actionDeckGradients;
    final actions = [
      _ActionItem(
        title: context.tr('Estate'),
        subtitle: context.tr('Open farms'),
        icon: Icons.eco_rounded,
        colors: g[0],
        onTap: () => _openFrmMain(context),
      ),
      _ActionItem(
        title: context.tr('Logistics'),
        subtitle: context.tr('Deliveries'),
        icon: Icons.local_shipping_rounded,
        colors: g[1],
        onTap: () => _openLogistics(context),
      ),
      _ActionItem(
        title: context.tr('Workers'),
        subtitle: context.tr('Crew panel'),
        icon: Icons.people_alt_rounded,
        colors: g[2],
        onTap: () => _openWorkers(context),
      ),
      _ActionItem(
        title: context.tr('Finance'),
        subtitle: context.tr('Tracker'),
        icon: Icons.account_balance_wallet_rounded,
        colors: g[3],
        onTap: () => _openFtracker(context),
      ),
      _ActionItem(
        title: 'SugarCalc',
        subtitle: context.tr('Estimate ROI'),
        icon: Icons.calculate_rounded,
        colors: g[4],
        onTap: () => _openProfitEstimator(context),
      ),
      _ActionItem(
        title: context.tr('Reports'),
        subtitle: context.tr('Charts'),
        icon: Icons.assessment_rounded,
        colors: g[5],
        onTap: () => _openReports(context),
      ),
    ];

    return FrostedPanel(
      radius: 36,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Action Deck'),
            style: theme.textTheme.headlineMedium?.copyWith(color: AppVisuals.primaryGold),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
            ),
            itemBuilder: (context, index) => actions[index],
          ),
        ],
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
    return FrostedPanel(
      radius: 36,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Live Overview'),
            style: theme.textTheme.headlineMedium?.copyWith(color: AppVisuals.primaryGold),
          ),
          const SizedBox(height: 20),
          _OverviewRow(
            label: context.tr('Active Farm'),
            value: selectedFarm?.name ?? context.tr('None'),
            icon: Icons.location_on_rounded,
          ),
          const Divider(height: 24, thickness: 0.5, color: AppVisuals.mutedGold),
          _OverviewRow(
            label: context.tr('Crop Age'),
            value: cropAge != null ? context.tr('{days} Days', {'days': '$cropAge'}) : '--',
            icon: Icons.calendar_today_rounded,
          ),
          const Divider(height: 24, thickness: 0.5, color: AppVisuals.mutedGold),
          _OverviewRow(
            label: context.tr('Weather'),
            value: weather?.description ?? context.tr('N/A'),
            icon: Icons.cloud_rounded,
          ),
          const Divider(height: 24, thickness: 0.5, color: AppVisuals.mutedGold),
          _OverviewRow(
            label: context.tr('Assets'),
            value: context.tr('{count} items', {'count': '$equipmentCount'}),
            icon: Icons.precision_manufacturing_rounded,
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
            style: theme.textTheme.headlineMedium?.copyWith(color: AppVisuals.primaryGold),
          ),
          const SizedBox(height: 20),
          if (activityProvider.activities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  context.tr('No recent activity recorded.'),
                  style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
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
                    color: const Color(0xFFE8F2EE),
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
                        child: const Icon(Icons.history_rounded, size: 18, color: AppVisuals.primaryGold),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.name,
                              style: theme.textTheme.titleMedium?.copyWith(color: AppVisuals.textForest),
                            ),
                            Text(
                              activity.farm,
                              style: theme.textTheme.bodySmall?.copyWith(color: AppVisuals.textForest.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('MMM d').format(activity.date),
                        style: theme.textTheme.labelSmall?.copyWith(color: AppVisuals.primaryGold),
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openFrmMain(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FrmMain()));
  }

  void _openLogistics(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FrmLogistics()));
  }

  void _openWorkers(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ScrWorkers()));
  }

  void _openFtracker(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FtrackerSplashScreen()));
  }

  void _openProfitEstimator(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfitCalculatorScreen()));
  }

  void _openReports(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChartsScreen()));
  }

  void _openExitScreen(BuildContext context) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ExitScreen()));
  }
}

class _AiMessage {
  final String role;
  final String text;
  _AiMessage({required this.role, required this.text});
}

class _HeroStat {
  final String label;
  final String value;
  final IconData icon;
  _HeroStat(this.label, this.value, this.icon);
}

class _TopPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TopPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppVisuals.primaryGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppVisuals.primaryGold.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppVisuals.primaryGold),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppVisuals.primaryGold,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
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
          color: AppVisuals.textForest.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: AppVisuals.textForest.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, size: 20, color: AppVisuals.textForest.withValues(alpha: 0.7)),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppVisuals.textForest, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppVisuals.textForest,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: AppVisuals.textForestMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _OverviewRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppVisuals.primaryGold.withValues(alpha: 0.7)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
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
