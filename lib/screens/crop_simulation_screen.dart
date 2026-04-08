import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/farm_model.dart';
import '../models/schedule_alert_model.dart';
import '../models/supply_model.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/supplies_provider.dart';
import '../services/crop_simulation_service.dart';
import '../services/farm_operations_service.dart';
import '../services/soil_reference_service.dart';
import '../services/sugarcane_asset_service.dart';
import 'crop_photo_assessment_screen.dart';
import 'frm_add_sup_screen.dart';
import '../themes/app_visuals.dart';

enum _SugarcanePreviewTab { growth, deficiency, diseases, pests, weather }

enum _CropMonitoringMode { simulated, live }

enum _SugarcaneDetailMode { showDetails, lessDetails }

enum _SugarcaneCompactOverlay {
  references,
  fertilizer,
  utilities,
  official,
  season,
  harvest,
}

class CropSimulationScreen extends StatefulWidget {
  const CropSimulationScreen({
    super.key,
    required this.farm,
  });

  final Farm farm;

  @override
  State<CropSimulationScreen> createState() => _CropSimulationScreenState();
}

class _CropSimulationScreenState extends State<CropSimulationScreen> {
  late CropSimulationState _state;
  late Future<SoilReferenceLookupResult> _soilReferenceFuture;
  int _selectedGrowthImageIndex = 0;
  int _selectedScenarioImageIndex = 0;
  _SugarcanePreviewTab _selectedPreviewTab = _SugarcanePreviewTab.growth;
  _CropMonitoringMode _selectedMonitoringMode = _CropMonitoringMode.simulated;
  _SugarcaneDetailMode _detailMode = _SugarcaneDetailMode.showDetails;
  _SugarcaneCompactOverlay? _compactOverlay;
  bool _compactDropActive = false;
  bool _showSelectedReferenceVisual = false;
  double _fastTrackDays = 30;
  _CropApplicationEffect? _activeApplicationEffect;
  Timer? _applicationEffectTimer;
  int _applicationEffectRunId = 0;

  @override
  void initState() {
    super.initState();
    _state = CropSimulationService.initialState(widget.farm);
    _soilReferenceFuture = SoilReferenceService.lookupForFarm(widget.farm);
  }

  @override
  void dispose() {
    _applicationEffectTimer?.cancel();
    super.dispose();
  }

  List<ScheduleAlert> get _alerts =>
      CropSimulationService.recommendations(_state).take(3).toList();

  List<CropFertilizerRecommendation> get _fertilizers =>
      CropSimulationService.fertilizerRecommendations(_state);

  bool get _isSugarcaneCrop =>
      widget.farm.type.toLowerCase().trim().contains('sugar');

  bool get _showSugarcaneDetails =>
      _detailMode == _SugarcaneDetailMode.showDetails;

  int get _actualCropAgeDays {
    final liveAge = DateTime.now().difference(widget.farm.date).inDays;
    return liveAge < 0 ? 0 : liveAge;
  }

  void _setState(CropSimulationState nextState) {
    setState(() {
      _state = nextState;
    });
  }

  Future<void> _triggerApplicationEffect(_CropInteractionKind kind) async {
    final effect = _applicationEffectForKind(kind);
    if (effect == null || !mounted) {
      return;
    }

    _applicationEffectTimer?.cancel();
    setState(() {
      _activeApplicationEffect = effect;
      _applicationEffectRunId++;
    });

    final settings = context.read<AppSettingsProvider>();
    final audio = context.read<AppAudioProvider?>();
    unawaited(
      audio?.playAsset(
            assetPath: effect.audioAssetPath,
            enabled: settings.audioSoundsEnabled,
          ) ??
          Future<void>.value(),
    );

    _applicationEffectTimer = Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeApplicationEffect = null;
      });
    });
  }

  CropSimulationState? _resolvedPrimaryStateForAction(
    _CropInteractionAction action,
  ) {
    final fertilizer = action.fertilizer;
    return switch (action.kind) {
      _CropInteractionKind.irrigate => CropSimulationService.irrigate(_state),
      _CropInteractionKind.weedControl =>
        CropSimulationService.weedControl(_state),
      _CropInteractionKind.pestControl =>
        CropSimulationService.pestControl(_state),
      _CropInteractionKind.ripener =>
        CropSimulationService.applyRipener(_state),
      _CropInteractionKind.fertilizer when fertilizer != null =>
        CropSimulationService.applyFertilizer(_state, fertilizer),
      _CropInteractionKind.fertilizer => null,
    };
  }

  void _applyPrimaryInteractionAction(_CropInteractionAction action) {
    final nextState = _resolvedPrimaryStateForAction(action);
    if (nextState == null) {
      return;
    }
    unawaited(_triggerApplicationEffect(action.kind));
    _setState(nextState);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Provider.of<ThemeProvider>(context).darkTheme;

    if (_isSugarcaneCrop) {
      return _buildSugarcanePreviewScaffold(theme, isDarkMode);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.farm.name} Simulator'),
      ),
      body: AppBackdrop(
        isDark: isDarkMode,
        backgroundImageAsset: _heroImageAssetForCrop(widget.farm.type),
        backgroundImageOpacity: isDarkMode ? 0.14 : 0.2,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(theme),
                const SizedBox(height: 16),
                _buildMonthlyGrowthGallery(theme),
                const SizedBox(height: 16),
                _buildStressScenarioGallery(theme),
                const SizedBox(height: 16),
                _buildSoilAndTechnique(theme),
                const SizedBox(height: 16),
                _buildSeasonControls(theme),
                const SizedBox(height: 16),
                _buildRecommendationBoard(theme),
                const SizedBox(height: 16),
                _buildHarvestAndLog(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSugarcanePreviewScaffold(
    ThemeData theme,
    bool isDarkMode,
  ) {
    if (!_showSugarcaneDetails) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text('${widget.farm.name} Simulator'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: AppBackdrop(
          isDark: isDarkMode,
          backgroundImageAsset: _currentMonitoringVisual().assetPath,
          backgroundImageOpacity: 0.22,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 96, 16, 20),
              child: _buildSugarcaneCompactWorkspace(theme),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${widget.farm.name} Simulator'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AppBackdrop(
        isDark: isDarkMode,
        backgroundImageAsset: _heroImageAssetForCrop(widget.farm.type),
        backgroundImageOpacity: 0.34,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 96, 16, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSugarcaneViewModeCard(theme),
                    const SizedBox(height: 12),
                    _buildSugarcanePreviewHero(theme),
                    const SizedBox(height: 12),
                    _buildSugarcanePreviewSection(
                      theme: theme,
                      title: 'Crop Monitoring',
                      child: _buildMonitoringModeSelector(
                        theme,
                        dark: false,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSugarcanePreviewSection(
                      theme: theme,
                      title: 'Reference Categories',
                      child: _buildSugarcanePreviewTabBar(theme),
                    ),
                    const SizedBox(height: 12),
                    _buildSugarcanePreviewGallery(theme),
                    const SizedBox(height: 12),
                    _buildSugarcanePreviewWhatToDo(theme),
                    const SizedBox(height: 12),
                    _buildSugarcanePreviewFertilizerGuide(theme),
                    const SizedBox(height: 12),
                    _buildSugarcanePreviewQuickActions(theme),
                    const SizedBox(height: 12),
                    _buildSugarcanePreviewAdvancedControls(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSugarcaneViewModeCard(ThemeData theme) {
    return _buildSugarcanePreviewSection(
      theme: theme,
      title: 'Details',
      child: _buildSugarcaneDetailSwitch(theme, dark: false),
    );
  }

  Widget _buildSugarcaneDetailSwitch(
    ThemeData theme, {
    required bool dark,
  }) {
    final labelColor = dark ? Colors.white : const Color(0xFF312618);
    final valueColor =
        dark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFF4E8C9);
    final borderColor =
        dark ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFDBCDA8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: valueColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Details',
            style: theme.textTheme.labelLarge?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: _showSugarcaneDetails,
            onChanged: (value) {
              setState(() {
                _detailMode = value
                    ? _SugarcaneDetailMode.showDetails
                    : _SugarcaneDetailMode.lessDetails;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSugarcaneCompactWorkspace(ThemeData theme) {
    return Stack(
      children: [
        Positioned.fill(
          child: _buildSugarcaneCompactCropCanvas(theme),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 64,
          child: _buildSugarcaneCompactTopBar(theme),
        ),
        Positioned(
          top: 98,
          right: 0,
          bottom: 176,
          child: _buildSugarcaneCompactSideRail(theme),
        ),
        if (_compactOverlay != null)
          Positioned(
            left: 0,
            right: 64,
            bottom: 184,
            child: _buildSugarcaneCompactOverlay(theme),
          ),
        Positioned(
          left: 0,
          right: 64,
          bottom: 0,
          child: _buildSugarcaneCompactAdvancedDock(theme),
        ),
      ],
    );
  }

  Widget _buildSugarcaneCompactTopBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildSugarcaneDetailSwitch(theme, dark: true),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Live',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Switch(
                      value:
                          _selectedMonitoringMode == _CropMonitoringMode.live,
                      onChanged: (value) {
                        setState(() {
                          _selectedMonitoringMode = value
                              ? _CropMonitoringMode.live
                              : _CropMonitoringMode.simulated;
                          _showSelectedReferenceVisual = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSugarcaneCompactCropCanvas(ThemeData theme) {
    final visual = _currentMonitoringVisual();

    return DragTarget<_CropInteractionAction>(
      onWillAcceptWithDetails: (details) {
        setState(() {
          _compactDropActive = details.data.enabled;
        });
        return details.data.enabled;
      },
      onLeave: (_) {
        if (_compactDropActive) {
          setState(() {
            _compactDropActive = false;
          });
        }
      },
      onAcceptWithDetails: (details) {
        setState(() {
          _compactDropActive = false;
        });
        _applyCompactAction(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isTargeted = _compactDropActive || candidateData.isNotEmpty;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isTargeted
                  ? AppVisuals.primaryGold.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.12),
              width: isTargeted ? 2.4 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                visual.assetPath,
                fit: BoxFit.cover,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.28),
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.58),
                    ],
                  ),
                ),
              ),
              if (isTargeted)
                Positioned.fill(
                  child: Container(
                    color: AppVisuals.primaryGold.withValues(alpha: 0.18),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.66),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        'Drop input on the crop to apply it',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        visual.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_activeApplicationEffect != null)
                Positioned.fill(
                  child: _CropApplicationOverlay(
                    key: ValueKey('compact-effect-$_applicationEffectRunId'),
                    effect: _activeApplicationEffect!,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSugarcaneCompactSideRail(ThemeData theme) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _CompactSideIconButton(
              icon: Icons.timeline_rounded,
              tooltip: 'Growth references',
              isSelected:
                  _compactOverlay == _SugarcaneCompactOverlay.references &&
                      _selectedPreviewTab == _SugarcanePreviewTab.growth,
              onTap: () => _toggleCompactReferenceTab(
                _SugarcanePreviewTab.growth,
              ),
            ),
            _CompactSideIconButton(
              icon: Icons.science_rounded,
              tooltip: 'Deficiency references',
              isSelected:
                  _compactOverlay == _SugarcaneCompactOverlay.references &&
                      _selectedPreviewTab == _SugarcanePreviewTab.deficiency,
              onTap: () => _toggleCompactReferenceTab(
                _SugarcanePreviewTab.deficiency,
              ),
            ),
            _CompactSideIconButton(
              icon: Icons.coronavirus_rounded,
              tooltip: 'Disease references',
              isSelected:
                  _compactOverlay == _SugarcaneCompactOverlay.references &&
                      _selectedPreviewTab == _SugarcanePreviewTab.diseases,
              onTap: () => _toggleCompactReferenceTab(
                _SugarcanePreviewTab.diseases,
              ),
            ),
            _CompactSideIconButton(
              icon: Icons.pest_control_rounded,
              tooltip: 'Pest references',
              isSelected:
                  _compactOverlay == _SugarcaneCompactOverlay.references &&
                      _selectedPreviewTab == _SugarcanePreviewTab.pests,
              onTap: () => _toggleCompactReferenceTab(
                _SugarcanePreviewTab.pests,
              ),
            ),
            _CompactSideIconButton(
              icon: Icons.cloud_rounded,
              tooltip: 'Weather references',
              isSelected:
                  _compactOverlay == _SugarcaneCompactOverlay.references &&
                      _selectedPreviewTab == _SugarcanePreviewTab.weather,
              onTap: () => _toggleCompactReferenceTab(
                _SugarcanePreviewTab.weather,
              ),
            ),
            const SizedBox(height: 6),
            Divider(color: Colors.white.withValues(alpha: 0.14), height: 16),
            _CompactSideIconButton(
              icon: Icons.compost_rounded,
              tooltip: 'Fertilizer guide',
              isSelected:
                  _compactOverlay == _SugarcaneCompactOverlay.fertilizer,
              onTap: () => _toggleCompactOverlay(
                _SugarcaneCompactOverlay.fertilizer,
              ),
            ),
            _CompactSideIconButton(
              icon: Icons.tune_rounded,
              tooltip: 'Utility actions',
              isSelected: _compactOverlay == _SugarcaneCompactOverlay.utilities,
              onTap: () => _toggleCompactOverlay(
                _SugarcaneCompactOverlay.utilities,
              ),
            ),
            _CompactSideIconButton(
              icon: Icons.public_rounded,
              tooltip: 'BSWM official reference',
              isSelected: _compactOverlay == _SugarcaneCompactOverlay.official,
              onTap: () => _toggleCompactOverlay(
                _SugarcaneCompactOverlay.official,
              ),
            ),
            _CompactSideIconButton(
              icon: Icons.fast_forward_rounded,
              tooltip: 'Simulate season',
              isSelected: _compactOverlay == _SugarcaneCompactOverlay.season,
              onTap: () => _toggleCompactOverlay(
                _SugarcaneCompactOverlay.season,
              ),
            ),
            _CompactSideIconButton(
              icon: Icons.agriculture_rounded,
              tooltip: 'Harvest',
              isSelected: _compactOverlay == _SugarcaneCompactOverlay.harvest,
              onTap: () => _toggleCompactOverlay(
                _SugarcaneCompactOverlay.harvest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSugarcaneCompactOverlay(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: switch (_compactOverlay) {
        _SugarcaneCompactOverlay.references =>
          _buildCompactReferenceOverlay(theme),
        _SugarcaneCompactOverlay.fertilizer =>
          _buildCompactFertilizerOverlay(theme),
        _SugarcaneCompactOverlay.utilities =>
          _buildCompactUtilityOverlay(theme),
        _SugarcaneCompactOverlay.official =>
          _buildCompactOfficialOverlay(theme),
        _SugarcaneCompactOverlay.season => _buildCompactSeasonOverlay(theme),
        _SugarcaneCompactOverlay.harvest => _buildCompactHarvestOverlay(theme),
        null => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildSugarcaneCompactAdvancedDock(ThemeData theme) {
    final actionButtons = _compactUtilityActions();
    final nutrientButtons = _compactNutrientActions();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...nutrientButtons.map((action) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _CompactActionBubble(
                    action: action,
                    onApply: _applyCompactAction,
                  ),
                )),
            Container(
              width: 1,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: Colors.white.withValues(alpha: 0.14),
            ),
            ...actionButtons.map((action) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _CompactActionBubble(
                    action: action,
                    onApply: _applyCompactAction,
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _toggleCompactOverlay(_SugarcaneCompactOverlay overlay) {
    setState(() {
      final nextOverlay = _compactOverlay == overlay ? null : overlay;
      if (_compactOverlay == _SugarcaneCompactOverlay.references &&
          nextOverlay != _SugarcaneCompactOverlay.references) {
        _showSelectedReferenceVisual = false;
      }
      _compactOverlay = nextOverlay;
    });
  }

  void _toggleCompactReferenceTab(_SugarcanePreviewTab tab) {
    setState(() {
      if (_compactOverlay == _SugarcaneCompactOverlay.references &&
          _selectedPreviewTab == tab) {
        _compactOverlay = null;
        _showSelectedReferenceVisual = false;
      } else {
        _selectedPreviewTab = tab;
        _compactOverlay = _SugarcaneCompactOverlay.references;
      }
    });
  }

  List<_CropInteractionAction> _compactUtilityActions() {
    return [
      _CropInteractionAction(
        label: 'Irrigate',
        subtitle: 'Lift soil moisture',
        icon: Icons.water_drop_rounded,
        color: AppVisuals.brandBlue,
        kind: _CropInteractionKind.irrigate,
        enabled: _state.canAdvance,
      ),
      _CropInteractionAction(
        label: 'Weed',
        subtitle: 'Clean the field',
        icon: Icons.grass_rounded,
        color: Colors.green.shade700,
        kind: _CropInteractionKind.weedControl,
        enabled: _state.canAdvance,
      ),
      _CropInteractionAction(
        label: 'Pest',
        subtitle: 'Control pressure',
        icon: Icons.pest_control_rounded,
        color: Colors.red.shade600,
        kind: _CropInteractionKind.pestControl,
        enabled: _state.canAdvance,
      ),
      _CropInteractionAction(
        label: 'Ripener',
        subtitle: 'Push maturity',
        icon: Icons.bolt_rounded,
        color: Colors.amber.shade800,
        kind: _CropInteractionKind.ripener,
        enabled: _state.canAdvance && _state.day >= 180,
      ),
    ];
  }

  List<_CropInteractionAction> _compactNutrientActions() {
    CropFertilizerRecommendation byLabel(
      String label,
      CropFertilizerRecommendation fallback,
    ) {
      for (final fertilizer in _fertilizers) {
        if (fertilizer.label == label) {
          return fertilizer;
        }
      }
      return fallback;
    }

    final nitrogen = byLabel(
      'Urea boost',
      const CropFertilizerRecommendation(
        label: 'Urea boost',
        formula: '46-0-0',
        reason: 'Raise Nitrogen quickly.',
        nitrogenDelta: 18,
        phosphorusDelta: 0,
        potassiumDelta: 0,
        color: Colors.green,
      ),
    );
    final phosphorus = byLabel(
      'Root starter',
      const CropFertilizerRecommendation(
        label: 'Root starter',
        formula: '18-46-0',
        reason: 'Raise Phosphorus support.',
        nitrogenDelta: 6,
        phosphorusDelta: 16,
        potassiumDelta: 0,
        color: Colors.orange,
      ),
    );
    final potassium = byLabel(
      'Potash support',
      const CropFertilizerRecommendation(
        label: 'Potash support',
        formula: '0-0-60',
        reason: 'Raise Potassium support.',
        nitrogenDelta: 0,
        phosphorusDelta: 0,
        potassiumDelta: 18,
        color: Colors.deepOrange,
      ),
    );
    final balanced = byLabel(
      'Balanced complete',
      const CropFertilizerRecommendation(
        label: 'Balanced complete',
        formula: '14-14-14',
        reason: 'Balanced NPK correction.',
        nitrogenDelta: 10,
        phosphorusDelta: 10,
        potassiumDelta: 10,
        color: Colors.teal,
      ),
    );

    return [
      _CropInteractionAction(
        label: 'Nitrogen',
        subtitle: nitrogen.formula,
        icon: Icons.eco_rounded,
        color: Colors.green.shade700,
        kind: _CropInteractionKind.fertilizer,
        enabled: _state.canAdvance,
        fertilizer: nitrogen,
      ),
      _CropInteractionAction(
        label: 'Phosphorus',
        subtitle: phosphorus.formula,
        icon: Icons.forest_rounded,
        color: Colors.orange.shade700,
        kind: _CropInteractionKind.fertilizer,
        enabled: _state.canAdvance,
        fertilizer: phosphorus,
      ),
      _CropInteractionAction(
        label: 'Potassium',
        subtitle: potassium.formula,
        icon: Icons.bolt_rounded,
        color: Colors.deepOrange.shade600,
        kind: _CropInteractionKind.fertilizer,
        enabled: _state.canAdvance,
        fertilizer: potassium,
      ),
      _CropInteractionAction(
        label: 'All NPK',
        subtitle: balanced.formula,
        icon: Icons.all_inclusive_rounded,
        color: Colors.teal.shade600,
        kind: _CropInteractionKind.fertilizer,
        enabled: _state.canAdvance,
        fertilizer: balanced,
      ),
    ];
  }

  void _applyCompactAction(_CropInteractionAction action) {
    _applyPrimaryInteractionAction(action);
  }

  void _applyFastTrack() {
    if (!_state.canAdvance || _fastTrackDays <= 0) {
      return;
    }
    _setState(
      CropSimulationService.advance(
        _state,
        days: _fastTrackDays.round(),
      ),
    );
  }

  Widget _buildCompactReferenceOverlay(ThemeData theme) {
    final images = _imagesForSugarcanePreviewTab(_selectedPreviewTab);
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }
    final selectedIndex =
        _selectedIndexForSugarcanePreviewTab(_selectedPreviewTab, images);
    final selectedImage = images[selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _titleForSugarcanePreviewTab(_selectedPreviewTab),
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          selectedImage.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          selectedImage.subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: images.asMap().entries.map((entry) {
                final index = entry.key;
                final image = entry.value;
                final isSelected = index == selectedIndex;
                return Padding(
                  padding: EdgeInsets.only(
                      right: index == images.length - 1 ? 0 : 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _selectSugarcanePreviewImage(image),
                    child: Container(
                      width: 112,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppVisuals.primaryGold.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? AppVisuals.primaryGold
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                image.assetPath,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            image.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactFertilizerOverlay(ThemeData theme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fertilizer Guide',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ..._fertilizers.take(4).map((fertilizer) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: fertilizer.color.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.spa_rounded, color: fertilizer.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${fertilizer.label} (${fertilizer.formula})',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fertilizer.reason,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _state.canAdvance
                          ? () => _applyPrimaryInteractionAction(
                                _CropInteractionAction(
                                  label: fertilizer.label,
                                  subtitle: fertilizer.formula,
                                  icon: Icons.spa_rounded,
                                  color: fertilizer.color,
                                  kind: _CropInteractionKind.fertilizer,
                                  enabled: true,
                                  fertilizer: fertilizer,
                                ),
                              )
                          : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactUtilityOverlay(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _state.harvested || !_state.planted
              ? () => _setState(CropSimulationService.plant(_state))
              : null,
          icon: const Icon(Icons.agriculture_rounded),
          label: Text(
            _state.planted && !_state.harvested
                ? 'Season active'
                : 'Plant crop',
          ),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              _setState(CropSimulationService.syncToLiveAge(_state)),
          icon: const Icon(Icons.sync_rounded),
          label: Text('Load live age ($_actualCropAgeDays d)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _openCropPhotoAssessment,
          icon: const Icon(Icons.photo_camera_back_rounded),
          label: const Text('Assess actual crop'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactOfficialOverlay(ThemeData theme) {
    return FutureBuilder<SoilReferenceLookupResult>(
      future: _soilReferenceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Official BSWM map lookup is unavailable right now.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          );
        }

        return _OfficialSoilReferenceCard(
          reference: snapshot.data!,
          onOpenLink: _openOfficialReference,
        );
      },
    );
  }

  Widget _buildCompactSeasonOverlay(ThemeData theme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Simulate The Season',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Fast track crop growth and adjust field weather from this panel.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Fast track: +${_fastTrackDays.round()} days',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppVisuals.primaryGold,
                thumbColor: AppVisuals.primaryGold,
              ),
              child: Slider(
                min: 0,
                max: 180,
                value: _fastTrackDays,
                onChanged: (value) {
                  setState(() {
                    _fastTrackDays = value;
                  });
                },
              ),
            ),
            FilledButton.icon(
              onPressed: _state.canAdvance ? _applyFastTrack : null,
              icon: const Icon(Icons.fast_forward_rounded),
              label: const Text('Apply fast track'),
            ),
            const SizedBox(height: 10),
            _SliderTile(
              label: 'Temperature',
              value: _state.environment.temperatureC,
              min: 22,
              max: 38,
              valueLabel:
                  '${_state.environment.temperatureC.toStringAsFixed(0)} C',
              color: Colors.amber.shade700,
              onChanged: (value) => _setState(
                CropSimulationService.updateEnvironment(
                  _state,
                  temperatureC: value,
                ),
              ),
            ),
            _SliderTile(
              label: 'Humidity',
              value: _state.environment.humidity.toDouble(),
              min: 40,
              max: 95,
              valueLabel: '${_state.environment.humidity}%',
              color: AppVisuals.brandBlue,
              onChanged: (value) => _setState(
                CropSimulationService.updateEnvironment(
                  _state,
                  humidity: value.round(),
                ),
              ),
            ),
            _SliderTile(
              label: 'Weekly rain',
              value: _state.environment.weeklyRainfallMm,
              min: 0,
              max: 140,
              valueLabel:
                  '${_state.environment.weeklyRainfallMm.toStringAsFixed(0)} mm',
              color: AppVisuals.brandGreen,
              onChanged: (value) => _setState(
                CropSimulationService.updateEnvironment(
                  _state,
                  weeklyRainfallMm: value,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHarvestOverlay(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Harvest Output',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _state.harvestReadinessLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSugarcanePreviewPill(
              label:
                  'Yield ${(_state.harvestedYieldTons ?? _state.projectedYieldTons).toStringAsFixed(1)} t',
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
            ),
            _buildSugarcanePreviewPill(
              label: 'Maturity ${_state.maturityPercent.toStringAsFixed(0)}%',
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
            ),
            _buildSugarcanePreviewPill(
              label: 'Canopy ${_state.canopyCover.toStringAsFixed(0)}%',
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _state.canHarvest
                  ? () => _setState(CropSimulationService.harvest(_state))
                  : null,
              icon: Icon(
                _state.isHarvestWindow
                    ? Icons.agriculture_rounded
                    : Icons.warning_amber_rounded,
              ),
              label: Text(
                _state.isHarvestWindow ? 'Harvest now' : 'Early harvest',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _setState(CropSimulationService.restart(_state)),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Restart season'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSugarcanePreviewHero(ThemeData theme) {
    final referenceVisual = _selectedReferenceVisual();
    final heroVisual = referenceVisual ?? _currentMonitoringVisual();
    final isReferencePreview = referenceVisual != null;
    final selectedAgeDays = _selectedMonitoringMode == _CropMonitoringMode.live
        ? _actualCropAgeDays
        : _state.day;
    final month = SugarcaneAssetService.monthForAge(selectedAgeDays);
    final progress = (month / 12).clamp(0.0, 1.0);
    final monitoringLabel = _selectedMonitoringMode == _CropMonitoringMode.live
        ? 'Live crop monitoring'
        : 'Simulated crop monitoring';
    final monitorDetail = _selectedMonitoringMode == _CropMonitoringMode.live
        ? 'Based on planted date ${DateFormat('MMM d, y').format(widget.farm.date)}'
        : 'Based on the current simulator state';

    return Container(
      height: 344,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            heroVisual.assetPath,
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.08),
                  const Color(0xFF261E13).withValues(alpha: 0.86),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            top: 18,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.farm.name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isReferencePreview
                        ? 'Reference loaded'
                        : 'Day $selectedAgeDays',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF312718).withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReferencePreview ? 'Reference preview' : monitoringLabel,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (isReferencePreview) ...[
                    Text(
                      '${heroVisual.title} - Reference image loaded from ${_titleForSugarcanePreviewTab(_selectedPreviewTab).toLowerCase()}.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSugarcanePreviewPill(
                          label: _titleForSugarcanePreviewTab(
                            _selectedPreviewTab,
                          ),
                          backgroundColor: const Color(0xFFE2D4A8),
                          foregroundColor: const Color(0xFF3A2E1C),
                        ),
                        _buildSugarcanePreviewPill(
                          label: 'Reference image',
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          foregroundColor: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showSelectedReferenceVisual = false;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('Show crop monitoring'),
                    ),
                  ] else ...[
                    Text(
                      '${heroVisual.title} · $monitorDetail',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMonitoringModeSelector(theme, dark: true),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSugarcanePreviewPill(
                          label: _selectedMonitoringMode ==
                                  _CropMonitoringMode.live
                              ? 'Live crop'
                              : 'Simulated crop',
                          backgroundColor: const Color(0xFFE2D4A8),
                          foregroundColor: const Color(0xFF3A2E1C),
                        ),
                        _buildSugarcanePreviewPill(
                          label: _selectedMonitoringMode ==
                                  _CropMonitoringMode.live
                              ? '$selectedAgeDays days old'
                              : _state.growthStage,
                          backgroundColor: const Color(0xFF4A5A29),
                          foregroundColor: Colors.white,
                        ),
                        _buildSugarcanePreviewPill(
                          label: 'Month $month of 12',
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          foregroundColor: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 9,
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF95B446),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSugarcanePreviewTabBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7DAB8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2C261D).withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: _SugarcanePreviewTab.values.map((tab) {
          final isSelected = tab == _selectedPreviewTab;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPreviewTab = tab;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _labelForSugarcanePreviewTab(tab),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? const Color(0xFF33281A)
                        : const Color(0xFF6A5840),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSugarcanePreviewGallery(ThemeData theme) {
    final images = _imagesForSugarcanePreviewTab(_selectedPreviewTab);
    final selectedIndex =
        _selectedIndexForSugarcanePreviewTab(_selectedPreviewTab, images);
    final selectedImage = images[selectedIndex];

    return _buildSugarcanePreviewSection(
      theme: theme,
      title: _titleForSugarcanePreviewTab(_selectedPreviewTab),
      trailing: TextButton.icon(
        onPressed: () => _openReferenceViewer(
          title: _titleForSugarcanePreviewTab(_selectedPreviewTab),
          images: images,
          initialIndex: selectedIndex,
        ),
        icon: const Icon(Icons.open_in_full_rounded, size: 16),
        label: const Text('Open'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 244,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  selectedImage.assetPath,
                  fit: BoxFit.cover,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.08),
                        const Color(0xFF251C12).withValues(alpha: 0.76),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (selectedImage.isActive)
                        _buildSugarcanePreviewPill(
                          label: 'Current match',
                          backgroundColor: const Color(0xFF8FA63E),
                          foregroundColor: Colors.white,
                        ),
                      _buildSugarcanePreviewPill(
                        label: '${selectedIndex + 1}/${images.length}',
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        foregroundColor: Colors.white,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedImage.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedImage.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final image = images[index];
                final isSelected = index == selectedIndex;
                return GestureDetector(
                  onTap: () => _selectSugarcanePreviewImage(image),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 132,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE6D8AE)
                          : const Color(0xFFF6ECCE),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF8FA63E)
                            : const Color(0xFFDBCDA8),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  image.assetPath,
                                  fit: BoxFit.cover,
                                ),
                                if (image.isActive)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF8FA63E),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          image.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF34291B),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSugarcanePreviewWhatToDo(ThemeData theme) {
    final items = _sugarcanePreviewTodoItems();
    return _buildSugarcanePreviewSection(
      theme: theme,
      title: 'What to do now',
      child: Column(
        children: items.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F3E0),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: item.color.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, size: 16, color: item.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF312618),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6D5A3F),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_activeApplicationEffect != null)
                  Positioned.fill(
                    child: _CropApplicationOverlay(
                      key: ValueKey('hero-effect-$_applicationEffectRunId'),
                      effect: _activeApplicationEffect!,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSugarcanePreviewFertilizerGuide(ThemeData theme) {
    return _buildSugarcanePreviewSection(
      theme: theme,
      title: 'Fertilizer Guide',
      trailing: Text(
        'Optional',
        style: theme.textTheme.labelSmall?.copyWith(
          color: const Color(0xFF8F7A58),
          fontWeight: FontWeight.w900,
        ),
      ),
      child: Column(
        children: [
          if (_fertilizers.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No fertilizer change is needed right now. Keep monitoring the crop and soil balance.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6D5A3F),
                ),
              ),
            ),
          ..._fertilizers.take(3).map((fertilizer) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: fertilizer.color.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: fertilizer.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${fertilizer.label} (${fertilizer.formula})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF312618),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fertilizer.reason,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6D5A3F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _state.canAdvance
                        ? () => _applyPrimaryInteractionAction(
                              _CropInteractionAction(
                                label: fertilizer.label,
                                subtitle: fertilizer.formula,
                                icon: Icons.science_rounded,
                                color: fertilizer.color,
                                kind: _CropInteractionKind.fertilizer,
                                enabled: true,
                                fertilizer: fertilizer,
                              ),
                            )
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: fertilizer.color.withValues(alpha: 0.14),
                      foregroundColor: fertilizer.color,
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Guide only. Final rates should still follow soil test results, local advice, and crop stage.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF8F7A58),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSugarcanePreviewQuickActions(ThemeData theme) {
    return _buildSugarcanePreviewSection(
      theme: theme,
      title: 'Quick actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _state.harvested || !_state.planted
                    ? () => _setState(CropSimulationService.plant(_state))
                    : null,
                icon: const Icon(Icons.agriculture_rounded),
                label: Text(
                  _state.planted && !_state.harvested
                      ? 'Season active'
                      : 'Plant crop',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _setState(CropSimulationService.syncToLiveAge(_state)),
                icon: const Icon(Icons.sync_rounded),
                label: Text('Load live age ($_actualCropAgeDays d)'),
              ),
              for (final days in const [7, 30, 90])
                OutlinedButton(
                  onPressed: _state.canAdvance
                      ? () => _setState(
                            CropSimulationService.advance(_state, days: days),
                          )
                      : null,
                  child: Text('+$days days'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                label: 'Irrigate',
                icon: Icons.water_drop_rounded,
                color: AppVisuals.brandBlue,
                enabled: _state.canAdvance,
                onTap: () => _applyPrimaryInteractionAction(
                  _CropInteractionAction(
                    label: 'Irrigate',
                    subtitle: 'Boost soil moisture.',
                    icon: Icons.water_drop_rounded,
                    color: AppVisuals.brandBlue,
                    kind: _CropInteractionKind.irrigate,
                    enabled: _state.canAdvance,
                  ),
                ),
              ),
              _ActionButton(
                label: 'Weed control',
                icon: Icons.grass_rounded,
                color: Colors.green.shade700,
                enabled: _state.canAdvance,
                onTap: () => _applyPrimaryInteractionAction(
                  _CropInteractionAction(
                    label: 'Weed control',
                    subtitle: 'Suppress weed pressure.',
                    icon: Icons.grass_rounded,
                    color: Colors.green.shade700,
                    kind: _CropInteractionKind.weedControl,
                    enabled: _state.canAdvance,
                  ),
                ),
              ),
              _ActionButton(
                label: 'Pest control',
                icon: Icons.pest_control_rounded,
                color: Colors.red.shade600,
                enabled: _state.canAdvance,
                onTap: () => _applyPrimaryInteractionAction(
                  _CropInteractionAction(
                    label: 'Pest control',
                    subtitle: 'Reduce pest pressure.',
                    icon: Icons.pest_control_rounded,
                    color: Colors.red.shade600,
                    kind: _CropInteractionKind.pestControl,
                    enabled: _state.canAdvance,
                  ),
                ),
              ),
              _ActionButton(
                label: 'Ripener',
                icon: Icons.bolt_rounded,
                color: Colors.amber.shade800,
                enabled: _state.canAdvance && _state.day >= 180,
                onTap: () => _applyPrimaryInteractionAction(
                  _CropInteractionAction(
                    label: 'Ripener',
                    subtitle: 'Support late maturity.',
                    icon: Icons.bolt_rounded,
                    color: Colors.amber.shade800,
                    kind: _CropInteractionKind.ripener,
                    enabled: _state.canAdvance && _state.day >= 180,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _openCropPhotoAssessment,
                icon: const Icon(Icons.photo_camera_back_rounded),
                label: const Text('Assess actual crop'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSugarcanePreviewAdvancedControls(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF2C261D).withValues(alpha: 0.08),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          title: Text(
            'Advanced simulator controls',
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF312618),
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            'Adjust soil, field environment, and harvest details.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6D5A3F),
            ),
          ),
          children: [
            _buildSoilAndTechnique(theme),
            const SizedBox(height: 12),
            _buildSeasonControls(theme),
            const SizedBox(height: 12),
            _buildHarvestAndLog(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSugarcanePreviewSection({
    required ThemeData theme,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF2C261D).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF312618),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildMonitoringModeSelector(
    ThemeData theme, {
    required bool dark,
  }) {
    final selectedColor =
        dark ? const Color(0xFFE2D4A8) : const Color(0xFFDCC78E);
    final unselectedColor =
        dark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF4E8C9);
    final selectedTextColor =
        dark ? const Color(0xFF322718) : const Color(0xFF312618);
    final unselectedTextColor =
        dark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF6D5A3F);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _CropMonitoringMode.values.map((mode) {
        final isSelected = mode == _selectedMonitoringMode;
        return ChoiceChip(
          label: Text(
            mode == _CropMonitoringMode.live ? 'Live crop' : 'Simulated crop',
          ),
          selected: isSelected,
          showCheckmark: false,
          backgroundColor: unselectedColor,
          selectedColor: selectedColor,
          side: BorderSide(
            color: isSelected
                ? (dark ? Colors.white : const Color(0xFF8F7A58))
                : (dark
                    ? Colors.white.withValues(alpha: 0.16)
                    : const Color(0xFFDBCDA8)),
          ),
          labelStyle: theme.textTheme.labelMedium?.copyWith(
            color: isSelected ? selectedTextColor : unselectedTextColor,
            fontWeight: FontWeight.w900,
          ),
          onSelected: (_) {
            setState(() {
              _selectedMonitoringMode = mode;
              _showSelectedReferenceVisual = false;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildSugarcanePreviewPill({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }

  String _labelForSugarcanePreviewTab(_SugarcanePreviewTab tab) {
    return switch (tab) {
      _SugarcanePreviewTab.growth => 'Growth',
      _SugarcanePreviewTab.deficiency => 'Deficiency',
      _SugarcanePreviewTab.diseases => 'Diseases',
      _SugarcanePreviewTab.pests => 'Pests',
      _SugarcanePreviewTab.weather => 'Weather',
    };
  }

  String _titleForSugarcanePreviewTab(_SugarcanePreviewTab tab) {
    return switch (tab) {
      _SugarcanePreviewTab.growth => 'Growth references',
      _SugarcanePreviewTab.deficiency => 'Deficiency references',
      _SugarcanePreviewTab.diseases => 'Disease references',
      _SugarcanePreviewTab.pests => 'Pest references',
      _SugarcanePreviewTab.weather => 'Weather references',
    };
  }

  List<_SimulationReferenceImage> _imagesForSugarcanePreviewTab(
    _SugarcanePreviewTab tab,
  ) {
    if (tab == _SugarcanePreviewTab.growth) {
      return _growthGalleryImages();
    }

    return _scenarioGalleryImages()
        .where((image) => image.previewTab == tab)
        .toList(growable: false);
  }

  int _selectedIndexForSugarcanePreviewTab(
    _SugarcanePreviewTab tab,
    List<_SimulationReferenceImage> images,
  ) {
    if (images.isEmpty) {
      return 0;
    }

    if (tab == _SugarcanePreviewTab.growth) {
      return _selectedGrowthImageIndex.clamp(0, images.length - 1).toInt();
    }

    final allImages = _scenarioGalleryImages();
    final selectedScenario =
        allImages[_selectedScenarioImageIndex.clamp(0, allImages.length - 1)];
    final localIndex = images.indexWhere(
      (image) => image.assetPath == selectedScenario.assetPath,
    );
    return localIndex >= 0 ? localIndex : 0;
  }

  void _selectSugarcanePreviewImage(_SimulationReferenceImage image) {
    setState(() {
      if (_selectedPreviewTab == _SugarcanePreviewTab.growth) {
        _selectedGrowthImageIndex = _growthGalleryImages().indexWhere(
          (candidate) => candidate.assetPath == image.assetPath,
        );
      } else {
        _selectedScenarioImageIndex = _scenarioGalleryImages().indexWhere(
          (candidate) => candidate.assetPath == image.assetPath,
        );
      }
      _showSelectedReferenceVisual = true;
    });
  }

  List<_SugarcanePreviewTodoItem> _sugarcanePreviewTodoItems() {
    final items = <_SugarcanePreviewTodoItem>[];

    for (final alert in _alerts) {
      items.add(
        _SugarcanePreviewTodoItem(
          title: alert.title,
          detail: alert.message,
          icon: alert.icon,
          color: alert.color,
        ),
      );
    }

    if (_state.soilMoisture < 45) {
      items.add(
        const _SugarcanePreviewTodoItem(
          title: 'Monitor soil moisture',
          detail:
              'Current moisture is low enough to slow tillering and stalk fill.',
          icon: Icons.water_drop_rounded,
          color: AppVisuals.brandBlue,
        ),
      );
    }

    if (_state.pestPressure >= 28) {
      items.add(
        _SugarcanePreviewTodoItem(
          title: 'Scout for pest activity',
          detail:
              'Inspect leaves and stalks before visible damage spreads further.',
          icon: Icons.pest_control_rounded,
          color: Colors.red.shade600,
        ),
      );
    }

    if (_state.nitrogen < 35 ||
        _state.phosphorus < 35 ||
        _state.potassium < 38) {
      items.add(
        _SugarcanePreviewTodoItem(
          title: 'Review the fertilizer guide',
          detail:
              'The simulator is reading a nutrient imbalance for this stage.',
          icon: Icons.science_rounded,
          color: Colors.amber.shade800,
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        const _SugarcanePreviewTodoItem(
          title: 'Keep the crop on track',
          detail:
              'Stand density, moisture, and pest pressure are currently stable.',
          icon: Icons.check_circle_rounded,
          color: AppVisuals.brandGreen,
        ),
      );
    }

    return items.take(4).toList(growable: false);
  }

  Widget _buildMonthlyGrowthGallery(ThemeData theme) {
    final images = _growthGalleryImages();
    final selectedIndex =
        _selectedGrowthImageIndex.clamp(0, images.length - 1).toInt();
    return _buildReferenceGallery(
      theme: theme,
      title: 'Monthly Growth Images',
      description: _isSugarcaneCrop
          ? 'Your arranged sugarcane growth references now drive this gallery. The image preview is large, and the full-screen viewer keeps controls outside the image area.'
          : 'Month-by-month visual references tied to the crop timeline.',
      images: images,
      selectedIndex: selectedIndex,
      onSelect: (index) {
        setState(() {
          _selectedGrowthImageIndex = index;
        });
      },
      onOpenViewer: () => _openReferenceViewer(
        title: 'Growth References',
        images: images,
        initialIndex: selectedIndex,
      ),
    );
  }

  Widget _buildStressScenarioGallery(ThemeData theme) {
    final images = _scenarioGalleryImages();
    final selectedIndex =
        _selectedScenarioImageIndex.clamp(0, images.length - 1).toInt();
    return _buildReferenceGallery(
      theme: theme,
      title: 'Scenario Images',
      description: _isSugarcaneCrop
          ? 'Deficiency, disease, pest, and weather references now use the arranged sugarcane folders directly.'
          : 'Visual references for nutrient deficiency and weather stress. These are image states, not fixed diagnoses.',
      images: images,
      selectedIndex: selectedIndex,
      onSelect: (index) {
        setState(() {
          _selectedScenarioImageIndex = index;
        });
      },
      onOpenViewer: () => _openReferenceViewer(
        title: 'Issue References',
        images: images,
        initialIndex: selectedIndex,
      ),
    );
  }

  Widget _buildHero(ThemeData theme) {
    final heroVisual = _currentMonitoringVisual();
    final isLiveMonitoring =
        _selectedMonitoringMode == _CropMonitoringMode.live;

    return FrostedPanel(
      radius: 36,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 12,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Soil-Driven Crop Simulation',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppVisuals.primaryGold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start from soil NPK, choose a planting technique, then fast-forward the season and apply management decisions.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppVisuals.textForestMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    label: widget.farm.type,
                    icon: Icons.eco_rounded,
                    color: AppVisuals.brandGreen,
                  ),
                  _InfoChip(
                    label: _state.growthStage,
                    icon: Icons.timeline_rounded,
                    color: AppVisuals.brandBlue,
                  ),
                  _InfoChip(
                    label: CropSimulationService.healthBand(_state.plantHealth),
                    icon: Icons.favorite_rounded,
                    color: _healthColor(_state.plantHealth),
                  ),
                  _buildMonitoringModeSelector(theme, dark: false),
                  FilledButton.tonalIcon(
                    onPressed: _openCropPhotoAssessment,
                    icon: const Icon(Icons.photo_camera_back_rounded),
                    label: const Text('Assess actual crop'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _CropPhotoPanel(
            state: _state,
            imageAsset: heroVisual.assetPath,
            headline: heroVisual.title,
            detail: heroVisual.subtitle,
            effect: _activeApplicationEffect,
            effectRunId: _applicationEffectRunId,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _HeroDatum(
                label: 'Technique',
                value: _state.technique.label,
              ),
              _HeroDatum(
                label: isLiveMonitoring ? 'Planting date' : 'Simulated date',
                value: DateFormat('MMM d, y').format(
                  isLiveMonitoring ? widget.farm.date : _state.simulatedDate,
                ),
              ),
              _HeroDatum(
                label: 'Reference age',
                value: isLiveMonitoring
                    ? '$_actualCropAgeDays live days'
                    : _state.planted
                        ? 'Day ${_state.day}'
                        : 'Pre-planting',
              ),
              _HeroDatum(
                label: 'Projected yield',
                value: '${_state.projectedYieldTons.toStringAsFixed(1)} t',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Switch between live crop monitoring and simulated monitoring to compare the planted field age against the current simulator response.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _heroImageAssetForCrop(String cropType) {
    final normalized = cropType.toLowerCase();
    if (normalized.contains('sugar')) {
      return FarmOperationsService.cropBackdropAssetForAge(
          cropType, _state.day);
    }
    if (normalized.contains('rice') || normalized.contains('palay')) {
      return 'lib/assets/images/usda_rice.jpg';
    }
    if (normalized.contains('corn') || normalized.contains('maize')) {
      return 'lib/assets/images/usda_corn.jpg';
    }
    return SugarcaneAssetService.healthyAssetForMonth(8);
  }

  String _liveCropImageAsset() {
    return FarmOperationsService.cropBackdropAssetForAge(
      widget.farm.type,
      _actualCropAgeDays,
    );
  }

  Widget _buildSoilAndTechnique(ThemeData theme) {
    final techniques =
        CropSimulationService.techniquesForCrop(widget.farm.type);
    return FrostedPanel(
      radius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Soil NPK And Planting Technique',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.primaryGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set the soil condition first. Recommendations and crop form will react to these numbers.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<SoilReferenceLookupResult>(
            future: _soilReferenceFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppVisuals.panelSoft.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Official BSWM map lookup is unavailable right now. You can still enter soil-test values manually.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppVisuals.textForestMuted,
                    ),
                  ),
                );
              }

              final reference = snapshot.data!;
              return _OfficialSoilReferenceCard(
                reference: reference,
                onOpenLink: _openOfficialReference,
              );
            },
          ),
          const SizedBox(height: 14),
          _SliderTile(
            label: 'Nitrogen',
            value: _state.nitrogen,
            valueLabel:
                '${_state.nitrogen.toStringAsFixed(0)} (${CropSimulationService.npkBand(_state.nitrogen)})',
            color: Colors.green.shade700,
            onChanged: (value) => _setState(
              CropSimulationService.updateSoilNpk(_state, nitrogen: value),
            ),
          ),
          _SliderTile(
            label: 'Phosphorus',
            value: _state.phosphorus,
            valueLabel:
                '${_state.phosphorus.toStringAsFixed(0)} (${CropSimulationService.npkBand(_state.phosphorus)})',
            color: Colors.orange.shade700,
            onChanged: (value) => _setState(
              CropSimulationService.updateSoilNpk(_state, phosphorus: value),
            ),
          ),
          _SliderTile(
            label: 'Potassium',
            value: _state.potassium,
            valueLabel:
                '${_state.potassium.toStringAsFixed(0)} (${CropSimulationService.npkBand(_state.potassium)})',
            color: Colors.deepOrange.shade600,
            onChanged: (value) => _setState(
              CropSimulationService.updateSoilNpk(_state, potassium: value),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: techniques.map((technique) {
              return ChoiceChip(
                label: Text(technique.label),
                selected: _state.techniqueKey == technique.key,
                onSelected: (_) => _setState(
                  CropSimulationService.selectTechnique(_state, technique.key),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            _state.technique.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonControls(ThemeData theme) {
    final actualAge =
        DateTime.now().difference(widget.farm.date).inDays.clamp(0, 9999);
    return FrostedPanel(
      radius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2. Simulate The Season',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.primaryGold,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _state.harvested || !_state.planted
                    ? () => _setState(CropSimulationService.plant(_state))
                    : null,
                icon: const Icon(Icons.agriculture_rounded),
                label: Text(_state.planted && !_state.harvested
                    ? 'Season active'
                    : 'Plant crop'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _setState(CropSimulationService.syncToLiveAge(_state)),
                icon: const Icon(Icons.sync_rounded),
                label: Text('Load live age ($actualAge d)'),
              ),
              for (final days in const [7, 30, 90])
                OutlinedButton.icon(
                  onPressed: _state.canAdvance
                      ? () => _setState(
                            CropSimulationService.advance(_state, days: days),
                          )
                      : null,
                  icon: Icon(days >= 30
                      ? Icons.fast_forward_rounded
                      : Icons.calendar_view_week_rounded),
                  label: Text('+$days days'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _SliderTile(
            label: 'Temperature',
            value: _state.environment.temperatureC,
            min: 22,
            max: 38,
            valueLabel:
                '${_state.environment.temperatureC.toStringAsFixed(0)}°C',
            color: Colors.amber.shade700,
            onChanged: (value) => _setState(
              CropSimulationService.updateEnvironment(
                _state,
                temperatureC: value,
              ),
            ),
          ),
          _SliderTile(
            label: 'Humidity',
            value: _state.environment.humidity.toDouble(),
            min: 40,
            max: 95,
            valueLabel: '${_state.environment.humidity}%',
            color: AppVisuals.brandBlue,
            onChanged: (value) => _setState(
              CropSimulationService.updateEnvironment(
                _state,
                humidity: value.round(),
              ),
            ),
          ),
          _SliderTile(
            label: 'Weekly rain',
            value: _state.environment.weeklyRainfallMm,
            min: 0,
            max: 140,
            valueLabel:
                '${_state.environment.weeklyRainfallMm.toStringAsFixed(0)} mm',
            color: AppVisuals.brandGreen,
            onChanged: (value) => _setState(
              CropSimulationService.updateEnvironment(
                _state,
                weeklyRainfallMm: value,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                label: 'Irrigate',
                icon: Icons.water_drop_rounded,
                color: AppVisuals.brandBlue,
                enabled: _state.canAdvance,
                onTap: () => _applyPrimaryInteractionAction(
                  _CropInteractionAction(
                    label: 'Irrigate',
                    subtitle: 'Boost soil moisture.',
                    icon: Icons.water_drop_rounded,
                    color: AppVisuals.brandBlue,
                    kind: _CropInteractionKind.irrigate,
                    enabled: _state.canAdvance,
                  ),
                ),
              ),
              _ActionButton(
                label: 'Weed control',
                icon: Icons.grass_rounded,
                color: Colors.green.shade700,
                enabled: _state.canAdvance,
                onTap: () => _applyPrimaryInteractionAction(
                  _CropInteractionAction(
                    label: 'Weed control',
                    subtitle: 'Suppress weed pressure.',
                    icon: Icons.grass_rounded,
                    color: Colors.green.shade700,
                    kind: _CropInteractionKind.weedControl,
                    enabled: _state.canAdvance,
                  ),
                ),
              ),
              _ActionButton(
                label: 'Pest control',
                icon: Icons.pest_control_rounded,
                color: Colors.red.shade600,
                enabled: _state.canAdvance,
                onTap: () => _applyPrimaryInteractionAction(
                  _CropInteractionAction(
                    label: 'Pest control',
                    subtitle: 'Reduce pest pressure.',
                    icon: Icons.pest_control_rounded,
                    color: Colors.red.shade600,
                    kind: _CropInteractionKind.pestControl,
                    enabled: _state.canAdvance,
                  ),
                ),
              ),
              _ActionButton(
                label: 'Ripener',
                icon: Icons.bolt_rounded,
                color: Colors.amber.shade800,
                enabled: _state.canAdvance && _state.day >= 180,
                onTap: () => _applyPrimaryInteractionAction(
                  _CropInteractionAction(
                    label: 'Ripener',
                    subtitle: 'Support late maturity.',
                    icon: Icons.bolt_rounded,
                    color: Colors.amber.shade800,
                    kind: _CropInteractionKind.ripener,
                    enabled: _state.canAdvance && _state.day >= 180,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationBoard(ThemeData theme) {
    return FrostedPanel(
      radius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3. Fertilizer And Crop Guidance',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.primaryGold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                label: 'N level',
                value: CropSimulationService.npkBand(_state.nitrogen),
                accent: Colors.green.shade700,
              ),
              _MetricCard(
                label: 'P level',
                value: CropSimulationService.npkBand(_state.phosphorus),
                accent: Colors.orange.shade700,
              ),
              _MetricCard(
                label: 'K level',
                value: CropSimulationService.npkBand(_state.potassium),
                accent: Colors.deepOrange.shade600,
              ),
              _MetricCard(
                label: 'Crop health',
                value: CropSimulationService.healthBand(_state.plantHealth),
                accent: _healthColor(_state.plantHealth),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._fertilizers.map((fertilizer) {
            return _FertilizerCard(
              recommendation: fertilizer,
              enabled: _state.canAdvance,
              onApply: () => _applyPrimaryInteractionAction(
                _CropInteractionAction(
                  label: fertilizer.label,
                  subtitle: fertilizer.formula,
                  icon: Icons.science_rounded,
                  color: fertilizer.color,
                  kind: _CropInteractionKind.fertilizer,
                  enabled: _state.canAdvance,
                  fertilizer: fertilizer,
                ),
              ),
            );
          }),
          if (_alerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._alerts.map((alert) => _AlertTile(alert: alert)),
          ],
        ],
      ),
    );
  }

  Widget _buildHarvestAndLog(ThemeData theme) {
    return FrostedPanel(
      radius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '4. Harvest Output',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.primaryGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _state.harvestReadinessLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                label: 'Height',
                value: '${_state.heightScore.toStringAsFixed(0)}%',
                accent: AppVisuals.brandGreen,
              ),
              _MetricCard(
                label: 'Canopy',
                value: '${_state.canopyCover.toStringAsFixed(0)}%',
                accent: AppVisuals.brandBlue,
              ),
              _MetricCard(
                label: 'Maturity',
                value: '${_state.maturityPercent.toStringAsFixed(0)}%',
                accent: AppVisuals.primaryGold,
              ),
              _MetricCard(
                label: 'Yield',
                value:
                    '${(_state.harvestedYieldTons ?? _state.projectedYieldTons).toStringAsFixed(1)} t',
                accent: AppVisuals.primaryGold,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _state.canHarvest
                    ? () => _setState(CropSimulationService.harvest(_state))
                    : null,
                icon: Icon(_state.isHarvestWindow
                    ? Icons.agriculture_rounded
                    : Icons.warning_amber_rounded),
                label: Text(
                    _state.isHarvestWindow ? 'Harvest now' : 'Early harvest'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _setState(CropSimulationService.restart(_state)),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Restart season'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._state.log.map(
            (entry) => _LogTile(entry: entry),
          ),
        ],
      ),
    );
  }

  Color _healthColor(double value) {
    if (value >= 75) {
      return AppVisuals.brandGreen;
    }
    if (value >= 45) {
      return AppVisuals.primaryGold;
    }
    return Colors.red.shade600;
  }

  Future<void> _openOfficialReference(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openReferenceViewer({
    required String title,
    required List<_SimulationReferenceImage> images,
    required int initialIndex,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SimulationImageViewer(
          title: title,
          images: images,
          initialPage: initialIndex,
        ),
      ),
    );
  }

  Future<void> _openCropPhotoAssessment() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CropPhotoAssessmentScreen(
          farmName: widget.farm.name,
          cropType: widget.farm.type,
          ageInDays: _actualCropAgeDays,
        ),
      ),
    );
  }

  _WorkspaceCropVisual _currentMonitoringVisual() {
    final selectedReferenceVisual = _selectedReferenceVisual();
    if (selectedReferenceVisual != null) {
      return selectedReferenceVisual;
    }
    if (_selectedMonitoringMode == _CropMonitoringMode.live) {
      return _liveCropMonitoringVisual();
    }
    return _currentSimulatorHeroVisual();
  }

  _WorkspaceCropVisual? _selectedReferenceVisual() {
    if (!_showSelectedReferenceVisual) {
      return null;
    }

    final images = _imagesForSugarcanePreviewTab(_selectedPreviewTab);
    if (images.isEmpty) {
      return null;
    }

    final selectedIndex =
        _selectedIndexForSugarcanePreviewTab(_selectedPreviewTab, images);
    final image = images[selectedIndex];
    return _WorkspaceCropVisual(
      assetPath: image.assetPath,
      title: image.title,
      subtitle: image.subtitle,
    );
  }

  _WorkspaceCropVisual _liveCropMonitoringVisual() {
    return _WorkspaceCropVisual(
      assetPath: _liveCropImageAsset(),
      title: 'Live crop reference',
      subtitle:
          'Based on the farm planting date of ${DateFormat('MMM d, y').format(widget.farm.date)} with a current field age of $_actualCropAgeDays days.',
    );
  }

  _WorkspaceCropVisual _currentSimulatorHeroVisual() {
    if (_isSugarcaneCrop) {
      return _simulatedCropVisualForState(
        state: _state,
        cropType: widget.farm.type,
        fallbackAsset: _heroImageAssetForCrop(widget.farm.type),
      );
    }

    return _WorkspaceCropVisual(
      assetPath: _heroImageAssetForCrop(widget.farm.type),
      title: 'Live crop reference',
      subtitle:
          'Reference crop photo with simulation overlays for the current field state.',
    );
  }

  Widget _buildReferenceGallery({
    required ThemeData theme,
    required String title,
    required String description,
    required List<_SimulationReferenceImage> images,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
    required VoidCallback onOpenViewer,
  }) {
    final selectedImage = images[selectedIndex];
    final isFirstImage = selectedIndex == 0;
    final isLastImage = selectedIndex == images.length - 1;

    return FrostedPanel(
      radius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.primaryGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onOpenViewer,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.black.withValues(alpha: 0.74),
                border: Border.all(
                  color: selectedImage.isActive
                      ? AppVisuals.primaryGold.withValues(alpha: 0.32)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ReferenceImageRender(
                        image: selectedImage,
                        fit: BoxFit.contain,
                        padding: const EdgeInsets.all(18),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.18),
                              Colors.black.withValues(alpha: 0.74),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (selectedImage.isActive)
                              _GalleryBadge(
                                label: 'Current match',
                                color: AppVisuals.primaryGold,
                              ),
                            _GalleryBadge(
                              label: '${selectedIndex + 1} of ${images.length}',
                              color: AppVisuals.brandBlue,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.56),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.open_in_full_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedImage.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedImage.subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.86),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed:
                    isFirstImage ? null : () => onSelect(selectedIndex - 1),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Previous'),
              ),
              FilledButton.tonalIcon(
                onPressed: onOpenViewer,
                icon: const Icon(Icons.fullscreen_rounded),
                label: const Text('Open full screen'),
              ),
              OutlinedButton.icon(
                onPressed:
                    isLastImage ? null : () => onSelect(selectedIndex + 1),
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Next'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final image = images[index];
                final isSelected = index == selectedIndex;
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onSelect(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 120,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isSelected
                          ? AppVisuals.primaryGold.withValues(alpha: 0.14)
                          : AppVisuals.panelSoft.withValues(alpha: 0.28),
                      border: Border.all(
                        color: isSelected
                            ? AppVisuals.primaryGold.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: Colors.black.withValues(alpha: 0.6),
                            child: _ReferenceImageRender(
                              image: image,
                              fit: BoxFit.contain,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          if (image.isActive)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppVisuals.primaryGold,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_SimulationReferenceImage> _growthGalleryImages() {
    if (_isSugarcaneCrop) {
      final activeMonth =
          SugarcaneAssetService.monthForAge(_state.planted ? _state.day : 0);
      return List<_SimulationReferenceImage>.generate(12, (index) {
        final month = index + 1;
        final referenceDay = ((month - 1) * 30) + 15;
        final stage = FarmOperationsService.growthStage(
          widget.farm.type,
          referenceDay,
        );
        return _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.healthyAssetForMonth(month),
          title: 'Month $month',
          subtitle:
              '$stage reference for sugarcane canopy and stalk development.',
          isActive: month == activeMonth,
          previewTab: _SugarcanePreviewTab.growth,
        );
      });
    }

    final fallbackAsset = _heroImageAssetForCrop(widget.farm.type);
    return _monthlyGrowthStages().map((stage) {
      final isActive = _state.day >= stage.startDay &&
          _state.day <= stage.endDay &&
          _state.planted;
      final progress = ((stage.startDay + stage.endDay) / 2) /
          _state.profile.targetHarvestDays.clamp(1, 9999);
      return _SimulationReferenceImage(
        assetPath: fallbackAsset,
        title: stage.title,
        subtitle: stage.subtitle,
        isActive: isActive,
        previewTab: _SugarcanePreviewTab.growth,
        tintColor: stage.tint,
        tintOpacity: 0.18,
        saturation: (0.72 + progress * 0.35).clamp(0.72, 1.0),
        brightness: (0.84 + progress * 0.2).clamp(0.84, 1.04),
      );
    }).toList();
  }

  List<_SimulationReferenceImage> _scenarioGalleryImages() {
    if (_isSugarcaneCrop) {
      final referenceMonth =
          SugarcaneAssetService.monthForAge(_state.planted ? _state.day : 0);
      return [
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.deficiencyAssetForMonth(
            month: referenceMonth,
            nutrientKey: 'nitrogen',
          ),
          title: 'Nitrogen deficiency',
          subtitle:
              'Pale leaves and weaker vegetative push during active growth.',
          isActive: _state.nitrogen < 35,
          previewTab: _SugarcanePreviewTab.deficiency,
        ),
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.deficiencyAssetForMonth(
            month: referenceMonth,
            nutrientKey: 'phosphorus',
          ),
          title: 'Phosphorus deficiency',
          subtitle:
              'Slow establishment, weak root drive, and poor early vigor.',
          isActive: _state.phosphorus < 35,
          previewTab: _SugarcanePreviewTab.deficiency,
        ),
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.problemAsset(
            'potassium_deficiency',
          ),
          title: 'Potassium deficiency',
          subtitle:
              'Leaf edge stress and reduced tolerance under heavy demand.',
          isActive: _state.potassium < 38,
          previewTab: _SugarcanePreviewTab.deficiency,
        ),
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.problemAsset('grassy_shoot'),
          title: 'Grassy shoot',
          subtitle: 'Disease reference showing dense, abnormal tiller growth.',
          isActive: _state.pestPressure >= 45 && _state.plantHealth < 60,
          previewTab: _SugarcanePreviewTab.diseases,
        ),
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.problemAsset('mosaic_virus'),
          title: 'Mosaic virus',
          subtitle: 'Reference for streaked or mottled leaf symptoms.',
          isActive: _state.pestPressure >= 35 && _state.plantHealth < 62,
          previewTab: _SugarcanePreviewTab.diseases,
        ),
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.problemAsset('red_rot'),
          title: 'Red rot',
          subtitle:
              'Disease reference for stalk discoloration and internal decay.',
          isActive: _state.environment.weeklyRainfallMm >= 90 &&
              _state.plantHealth < 58,
          previewTab: _SugarcanePreviewTab.diseases,
        ),
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.pestDamageAssetForMonth(
            referenceMonth,
          ),
          title: 'Pest damage',
          subtitle:
              'Month-specific pest damage reference for the current cane age.',
          isActive: _state.pestPressure >= 32,
          previewTab: _SugarcanePreviewTab.pests,
        ),
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.problemAsset('aphids'),
          title: 'Aphids',
          subtitle:
              'Sap-feeding pest reference around crowded or stressed foliage.',
          isActive: _state.pestPressure >= 28,
          previewTab: _SugarcanePreviewTab.pests,
        ),
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.problemAsset('shoot_borer'),
          title: 'Shoot borer',
          subtitle: 'Pest reference for damaged shoots in younger cane.',
          isActive: _state.pestPressure >= 40 && _state.day <= 150,
          previewTab: _SugarcanePreviewTab.pests,
        ),
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.problemAsset('stem_borer'),
          title: 'Stem borer',
          subtitle: 'Pest reference for internal stalk damage in later growth.',
          isActive: _state.pestPressure >= 40 && _state.day > 150,
          previewTab: _SugarcanePreviewTab.pests,
        ),
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.problemAsset('drought_stress'),
          title: 'Drought stress',
          subtitle:
              'Weather stress reference for dry soil and reduced moisture.',
          isActive: _state.environment.weeklyRainfallMm <= 12 ||
              _state.soilMoisture < 40,
          previewTab: _SugarcanePreviewTab.weather,
        ),
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.problemAsset('excessive_heat'),
          title: 'Excessive heat',
          subtitle: 'Heat-stress reference for high temperature pressure.',
          isActive: _state.environment.temperatureC >= 35,
          previewTab: _SugarcanePreviewTab.weather,
        ),
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.problemAsset('flood_stress'),
          title: 'Flood stress',
          subtitle: 'Waterlogging reference during extended rainfall periods.',
          isActive: _state.environment.weeklyRainfallMm >= 90 ||
              _state.soilMoisture > 88,
          previewTab: _SugarcanePreviewTab.weather,
        ),
        _SimulationReferenceImage(
          assetPath: SugarcaneAssetService.problemAsset(
            'strong_wind_lodging',
          ),
          title: 'Strong wind lodging',
          subtitle: 'Reference for lodged cane after severe wind events.',
          isActive: _state.canopyCover >= 78 && _state.plantHealth < 70,
          previewTab: _SugarcanePreviewTab.weather,
        ),
      ];
    }

    final fallbackAsset = _heroImageAssetForCrop(widget.farm.type);
    return _stressScenarios().map((scenario) {
      return _SimulationReferenceImage(
        assetPath: fallbackAsset,
        title: scenario.title,
        subtitle: scenario.subtitle,
        isActive: scenario.isActive,
        previewTab: _SugarcanePreviewTab.weather,
        tintColor: scenario.tint,
        tintOpacity: 0.22,
        saturation: scenario.saturation,
        brightness: scenario.brightness,
      );
    }).toList();
  }

  List<_MonthlyGrowthStage> _monthlyGrowthStages() {
    final monthCount = (widget.farm.type.toLowerCase().contains('sugar')
            ? 12
            : ((_state.profile.targetHarvestDays + 29) ~/ 30))
        .clamp(4, 12);
    final stages = <_MonthlyGrowthStage>[];
    for (var month = 1; month <= monthCount; month++) {
      final startDay = (month - 1) * 30;
      final endDay = (month * 30 - 1).clamp(0, _state.profile.maxHarvestDays);
      final midpoint = ((startDay + endDay) / 2).round();
      final label =
          FarmOperationsService.growthStage(widget.farm.type, midpoint);
      final intensity = month / monthCount;
      stages.add(
        _MonthlyGrowthStage(
          title: 'Month $month',
          subtitle: '$label • Day $startDay-$endDay',
          startDay: startDay,
          endDay: endDay,
          tint: Color.lerp(
                Colors.brown.shade700,
                Colors.green.shade700,
                intensity.clamp(0.0, 1.0),
              ) ??
              AppVisuals.brandGreen,
        ),
      );
    }
    return stages;
  }

  List<_ScenarioImageState> _stressScenarios() {
    return [
      _ScenarioImageState(
        title: 'Nitrogen deficiency',
        subtitle: 'Pale canopy and weaker vegetative push.',
        tint: Colors.amber.shade700,
        saturation: 0.55,
        brightness: 0.96,
        isActive: _state.nitrogen < 35,
      ),
      _ScenarioImageState(
        title: 'Phosphorus deficiency',
        subtitle: 'Slow establishment and weak root energy.',
        tint: Colors.deepPurple.shade400,
        saturation: 0.6,
        brightness: 0.92,
        isActive: _state.phosphorus < 35,
      ),
      _ScenarioImageState(
        title: 'Potassium deficiency',
        subtitle: 'Lower stress tolerance and poor fill.',
        tint: Colors.orange.shade800,
        saturation: 0.7,
        brightness: 0.9,
        isActive: _state.potassium < 38,
      ),
      _ScenarioImageState(
        title: 'Too much sunlight',
        subtitle: 'Heat stress risk under strong radiation.',
        tint: Colors.red.shade700,
        saturation: 1.0,
        brightness: 1.08,
        isActive: _state.environment.temperatureC >= 35,
      ),
      _ScenarioImageState(
        title: 'Too much rain',
        subtitle: 'Waterlogging pressure and disease risk.',
        tint: Colors.blue.shade700,
        saturation: 0.75,
        brightness: 0.78,
        isActive: _state.environment.weeklyRainfallMm >= 90 ||
            _state.soilMoisture > 88,
      ),
      _ScenarioImageState(
        title: 'Balanced field',
        subtitle: 'Healthy crop with workable soil and weather.',
        tint: Colors.green.shade700,
        saturation: 1.0,
        brightness: 1.0,
        isActive: _state.plantHealth >= 75 &&
            _state.nitrogen >= 45 &&
            _state.phosphorus >= 40 &&
            _state.potassium >= 45,
      ),
    ];
  }
}

class _CropPhotoPanel extends StatelessWidget {
  const _CropPhotoPanel({
    required this.state,
    required this.imageAsset,
    required this.headline,
    required this.detail,
    this.effect,
    this.effectRunId = 0,
  });

  final CropSimulationState state;
  final String imageAsset;
  final String headline;
  final String detail;
  final _CropApplicationEffect? effect;
  final int effectRunId;

  @override
  Widget build(BuildContext context) {
    final overlayOpacity = (0.54 - state.plantHealth / 260).clamp(0.16, 0.54);
    final foliageTint = Color.lerp(
      Colors.amber.shade700,
      Colors.green.shade700,
      ((state.nitrogen + state.plantHealth) / 200).clamp(0.0, 1.0),
    )!;

    return Container(
      height: 280,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.black.withValues(alpha: 0.82),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.green.shade900.withValues(alpha: 0.58),
                  Colors.black.withValues(alpha: 0.78),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 76),
            child: Image.asset(
              imageAsset,
              fit: BoxFit.contain,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  foliageTint.withValues(alpha: overlayOpacity),
                  Colors.black.withValues(alpha: 0.28),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoChip(
                  label:
                      state.planted ? 'Day ${state.day}' : 'Waiting to plant',
                  icon: Icons.schedule_rounded,
                  color: AppVisuals.softWhite,
                ),
                const SizedBox(height: 8),
                _InfoChip(
                  label:
                      'NPK ${state.nitrogen.toStringAsFixed(0)}-${state.phosphorus.toStringAsFixed(0)}-${state.potassium.toStringAsFixed(0)}',
                  icon: Icons.science_rounded,
                  color: AppVisuals.softWhite,
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialSoilReferenceCard extends StatelessWidget {
  const _OfficialSoilReferenceCard({
    required this.reference,
    required this.onOpenLink,
  });

  final SoilReferenceLookupResult reference;
  final ValueChanged<String> onOpenLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppVisuals.brandBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${reference.sourceLabel}: ${reference.lookupScope}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppVisuals.textForest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            reference.note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
          if (reference.links.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: reference.links.map((link) {
                return OutlinedButton.icon(
                  onPressed: () => onOpenLink(link.detailUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(link.label),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

enum _WorkspaceCropMode { live, simulated }

enum _CropSupplyCategory { fertilizer, herbicide, pesticide }

enum _CropInteractionKind {
  irrigate,
  weedControl,
  pestControl,
  ripener,
  fertilizer,
}

class _CropInteractionAction {
  const _CropInteractionAction({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.kind,
    required this.enabled,
    this.fertilizer,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final _CropInteractionKind kind;
  final bool enabled;
  final CropFertilizerRecommendation? fertilizer;
}

class _CropApplicationEffect {
  const _CropApplicationEffect({
    required this.label,
    required this.imageAssetPath,
    required this.audioAssetPath,
    required this.accentColor,
  });

  final String label;
  final String imageAssetPath;
  final String audioAssetPath;
  final Color accentColor;
}

const _sprayApplicationEffect = _CropApplicationEffect(
  label: 'Applying crop spray',
  imageAssetPath: 'lib/assets/images/effects/crop_application_spray.gif',
  audioAssetPath: 'lib/assets/audio/crop_application_spray.wav',
  accentColor: Color(0xFFB9E4F2),
);

const _fertilizerApplicationEffect = _CropApplicationEffect(
  label: 'Applying fertilizer',
  imageAssetPath: 'lib/assets/images/effects/crop_application_fertilizer.gif',
  audioAssetPath: 'lib/assets/audio/crop_application_fertilizer.wav',
  accentColor: Color(0xFFE4CF93),
);

_CropApplicationEffect? _applicationEffectForKind(_CropInteractionKind kind) {
  return switch (kind) {
    _CropInteractionKind.weedControl ||
    _CropInteractionKind.pestControl ||
    _CropInteractionKind.ripener =>
      _sprayApplicationEffect,
    _CropInteractionKind.fertilizer => _fertilizerApplicationEffect,
    _CropInteractionKind.irrigate => null,
  };
}

class _CropApplicationOverlay extends StatelessWidget {
  const _CropApplicationOverlay({
    super.key,
    required this.effect,
  });

  final _CropApplicationEffect effect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: const Alignment(0.42, 0.12),
            child: Opacity(
              opacity: 0.68,
              child: SizedBox(
                width: 250,
                height: 250,
                child: Image.asset(
                  effect.imageAssetPath,
                  fit: BoxFit.contain,
                  gaplessPlayback: false,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: effect.accentColor.withValues(alpha: 0.58),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                effect.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockFlight {
  const _DockFlight({
    required this.id,
    required this.start,
    required this.end,
    required this.icon,
    required this.color,
    required this.label,
  });

  final int id;
  final Offset start;
  final Offset end;
  final IconData icon;
  final Color color;
  final String label;
}

class _WorkspaceCropVisual {
  const _WorkspaceCropVisual({
    required this.assetPath,
    required this.title,
    required this.subtitle,
  });

  final String assetPath;
  final String title;
  final String subtitle;
}

_WorkspaceCropVisual _simulatedCropVisualForState({
  required CropSimulationState state,
  required String cropType,
  required String fallbackAsset,
}) {
  final normalized = cropType.toLowerCase();
  final month = SugarcaneAssetService.monthForAge(state.day);
  if (!normalized.contains('sugar')) {
    return _WorkspaceCropVisual(
      assetPath: fallbackAsset,
      title: 'Simulated crop reference',
      subtitle:
          'Simulation overlays are active, but this crop does not yet have a dedicated stage image set.',
    );
  }

  if (state.environment.weeklyRainfallMm >= 90 || state.soilMoisture > 88) {
    return _WorkspaceCropVisual(
      assetPath: SugarcaneAssetService.problemAsset('flood_stress'),
      title: 'Simulated flood stress',
      subtitle:
          'The recent rain profile and field moisture are pushing the crop into a waterlogging stress view.',
    );
  }
  if (state.environment.temperatureC >= 35) {
    return _WorkspaceCropVisual(
      assetPath: SugarcaneAssetService.problemAsset('excessive_heat'),
      title: 'Simulated excessive heat',
      subtitle:
          'High field temperature is pushing the crop into a heat-stress view.',
    );
  }
  if (state.environment.weeklyRainfallMm <= 12 || state.soilMoisture < 40) {
    return _WorkspaceCropVisual(
      assetPath: SugarcaneAssetService.problemAsset('drought_stress'),
      title: 'Simulated drought stress',
      subtitle:
          'Dry field conditions are overriding normal growth and showing drought stress.',
    );
  }
  if (state.day >= 75 &&
      (state.pestControlCount == 0 ||
          state.weedControlCount == 0 ||
          state.fertilizationCount == 0) &&
      (state.pestPressure >= 26 ||
          state.weedPressure >= 24 ||
          state.plantHealth < 62)) {
    return _WorkspaceCropVisual(
      assetPath: SugarcaneAssetService.pestDamageAssetForMonth(month),
      title: 'Simulated neglected crop stress',
      subtitle:
          'The crop has aged without enough field work, so the simulator is showing a stressed month-specific cane image.',
    );
  }
  if (state.pestPressure >= 40 && state.day > 150) {
    return _WorkspaceCropVisual(
      assetPath: SugarcaneAssetService.problemAsset('stem_borer'),
      title: 'Simulated stem borer pressure',
      subtitle: 'Later-stage pest pressure is driving the simulated crop view.',
    );
  }
  if (state.pestPressure >= 40) {
    return _WorkspaceCropVisual(
      assetPath: SugarcaneAssetService.problemAsset('shoot_borer'),
      title: 'Simulated shoot borer pressure',
      subtitle: 'Early pest pressure is driving the simulated crop view.',
    );
  }
  if (state.pestPressure >= 28) {
    return _WorkspaceCropVisual(
      assetPath: SugarcaneAssetService.problemAsset('aphids'),
      title: 'Simulated aphid pressure',
      subtitle:
          'The current pest-pressure profile matches the aphid reference.',
    );
  }
  if (state.nitrogen < 35) {
    return _WorkspaceCropVisual(
      assetPath: SugarcaneAssetService.deficiencyAssetForMonth(
        month: month,
        nutrientKey: 'nitrogen',
      ),
      title: 'Simulated Nitrogen deficiency',
      subtitle: 'The current soil balance points to a Nitrogen-limited crop.',
    );
  }
  if (state.phosphorus < 35) {
    return _WorkspaceCropVisual(
      assetPath: SugarcaneAssetService.deficiencyAssetForMonth(
        month: month,
        nutrientKey: 'phosphorus',
      ),
      title: 'Simulated Phosphorus deficiency',
      subtitle: 'The current soil balance points to a Phosphorus-limited crop.',
    );
  }
  if (state.potassium < 38) {
    return _WorkspaceCropVisual(
      assetPath: SugarcaneAssetService.problemAsset('potassium_deficiency'),
      title: 'Simulated Potassium deficiency',
      subtitle: 'The current soil balance points to a Potassium-limited crop.',
    );
  }

  return _WorkspaceCropVisual(
    assetPath: FarmOperationsService.sugarcaneGrowthAssetForAge(state.day),
    title: 'Simulated growth-stage crop',
    subtitle: 'The crop view is following the current sugarcane age and stage.',
  );
}

class _SimulationReferenceImage {
  const _SimulationReferenceImage({
    required this.assetPath,
    required this.title,
    required this.subtitle,
    required this.isActive,
    this.previewTab = _SugarcanePreviewTab.growth,
    this.tintColor,
    this.tintOpacity = 0,
    this.saturation = 1.0,
    this.brightness = 1.0,
  });

  final String assetPath;
  final String title;
  final String subtitle;
  final bool isActive;
  final _SugarcanePreviewTab previewTab;
  final Color? tintColor;
  final double tintOpacity;
  final double saturation;
  final double brightness;
}

class _GalleryBadge extends StatelessWidget {
  const _GalleryBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _ReferenceImageRender extends StatelessWidget {
  const _ReferenceImageRender({
    required this.image,
    required this.fit,
    this.padding = EdgeInsets.zero,
  });

  final _SimulationReferenceImage image;
  final BoxFit fit;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.matrix(
              _imageFilterMatrix(
                saturation: image.saturation,
                brightness: image.brightness,
              ),
            ),
            child: Image.asset(
              image.assetPath,
              fit: fit,
            ),
          ),
          if (image.tintColor != null && image.tintOpacity > 0)
            DecoratedBox(
              decoration: BoxDecoration(
                color: image.tintColor!.withValues(alpha: image.tintOpacity),
              ),
            ),
        ],
      ),
    );
  }
}

class _CropWorkspaceScreen extends StatefulWidget {
  const _CropWorkspaceScreen({
    required this.farmName,
    required this.cropType,
    required this.liveImageAsset,
    required this.initialState,
    required this.initialMode,
  });

  final String farmName;
  final String cropType;
  final String liveImageAsset;
  final CropSimulationState initialState;
  final _WorkspaceCropMode initialMode;

  @override
  State<_CropWorkspaceScreen> createState() => _CropWorkspaceScreenState();
}

class _CropWorkspaceScreenState extends State<_CropWorkspaceScreen> {
  late CropSimulationState _state;
  late _WorkspaceCropMode _cropMode;
  bool _isDropActive = false;
  final GlobalKey _workspaceOverlayKey = GlobalKey();
  final GlobalKey _cropTargetKey = GlobalKey();
  late final Map<_CropSupplyCategory, GlobalKey> _dockButtonKeys = {
    _CropSupplyCategory.fertilizer: GlobalKey(),
    _CropSupplyCategory.herbicide: GlobalKey(),
    _CropSupplyCategory.pesticide: GlobalKey(),
  };
  _DockFlight? _dockFlight;
  bool _dockFlightAtTarget = false;
  _CropApplicationEffect? _activeApplicationEffect;
  Timer? _applicationEffectTimer;
  int _applicationEffectRunId = 0;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _cropMode = widget.initialMode;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _applicationEffectTimer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  List<CropFertilizerRecommendation> get _fertilizers =>
      CropSimulationService.fertilizerRecommendations(_state);

  List<_CropInteractionAction> get _utilityActions => [
        _CropInteractionAction(
          label: 'Irrigate',
          subtitle: 'Boost soil moisture.',
          icon: Icons.water_drop_rounded,
          color: AppVisuals.brandBlue,
          kind: _CropInteractionKind.irrigate,
          enabled: _state.canAdvance,
        ),
        _CropInteractionAction(
          label: 'Herbicide / weed control',
          subtitle: 'Suppress weed pressure.',
          icon: Icons.grass_rounded,
          color: Colors.green.shade700,
          kind: _CropInteractionKind.weedControl,
          enabled: _state.canAdvance,
        ),
        _CropInteractionAction(
          label: 'Pesticide / pest control',
          subtitle: 'Reduce pest pressure.',
          icon: Icons.pest_control_rounded,
          color: Colors.red.shade600,
          kind: _CropInteractionKind.pestControl,
          enabled: _state.canAdvance,
        ),
        _CropInteractionAction(
          label: 'Ripener',
          subtitle: 'Support late maturity.',
          icon: Icons.bolt_rounded,
          color: Colors.amber.shade800,
          kind: _CropInteractionKind.ripener,
          enabled: _state.canAdvance && _state.day >= 180,
        ),
      ];

  List<_CropInteractionAction> get _supplyDockActions => [
        _CropInteractionAction(
          label: 'Fertilizers',
          subtitle: 'Use stocked fertilizer.',
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFF7B8F2A),
          kind: _CropInteractionKind.fertilizer,
          enabled: _state.canAdvance,
        ),
        _CropInteractionAction(
          label: 'Herbicides',
          subtitle: 'Use stocked herbicide.',
          icon: Icons.grass_rounded,
          color: Colors.green.shade700,
          kind: _CropInteractionKind.weedControl,
          enabled: _state.canAdvance,
        ),
        _CropInteractionAction(
          label: 'Pesticides',
          subtitle: 'Use stocked pesticide.',
          icon: Icons.pest_control_rounded,
          color: Colors.red.shade600,
          kind: _CropInteractionKind.pestControl,
          enabled: _state.canAdvance,
        ),
      ];

  _WorkspaceCropVisual get _currentVisual {
    if (_cropMode == _WorkspaceCropMode.live) {
      return _WorkspaceCropVisual(
        assetPath: FarmOperationsService.cropBackdropAssetForAge(
          widget.cropType,
          _state.day,
        ),
        title: 'Live crop reference',
        subtitle:
            'Reference crop photo with the current simulator overlays and metrics.',
      );
    }

    return _simulatedCropVisualForState(
      state: _state,
      cropType: widget.cropType,
      fallbackAsset: widget.liveImageAsset,
    );
  }

  void _setSimulationState(CropSimulationState nextState) {
    setState(() {
      _state = nextState;
    });
  }

  Future<void> _triggerApplicationEffect(_CropInteractionKind kind) async {
    final effect = _applicationEffectForKind(kind);
    if (effect == null || !mounted) {
      return;
    }

    _applicationEffectTimer?.cancel();
    setState(() {
      _activeApplicationEffect = effect;
      _applicationEffectRunId++;
    });

    final settings = context.read<AppSettingsProvider>();
    final audio = context.read<AppAudioProvider?>();
    unawaited(
      audio?.playAsset(
            assetPath: effect.audioAssetPath,
            enabled: settings.audioSoundsEnabled,
          ) ??
          Future<void>.value(),
    );

    _applicationEffectTimer = Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeApplicationEffect = null;
      });
    });
  }

  _CropSupplyCategory? _categoryForAction(_CropInteractionAction action) {
    return switch (action.kind) {
      _CropInteractionKind.fertilizer => _CropSupplyCategory.fertilizer,
      _CropInteractionKind.weedControl => _CropSupplyCategory.herbicide,
      _CropInteractionKind.pestControl => _CropSupplyCategory.pesticide,
      _ => null,
    };
  }

  bool _requiresStockSelection(_CropInteractionAction action) {
    return action.fertilizer == null &&
        _categoryForAction(action) != null &&
        action.enabled;
  }

  Future<void> _handleInteractionAction(
    _CropInteractionAction action, {
    bool triggeredByDrag = false,
  }) async {
    if (!action.enabled) {
      return;
    }

    if (_requiresStockSelection(action)) {
      final category = _categoryForAction(action);
      if (category == null) {
        return;
      }
      final supply = await _pickSupplyForCategory(category);
      if (!mounted || supply == null) {
        return;
      }
      final resolvedAction = _resolvedActionFromSupply(action, supply);
      await _consumeSupplyUnit(supply);
      if (!triggeredByDrag) {
        _playDockFlight(category, resolvedAction);
      }
      _applyResolvedAction(resolvedAction, sourceLabel: supply.name);
      return;
    }

    _applyResolvedAction(action);
  }

  void _applyResolvedAction(
    _CropInteractionAction action, {
    String? sourceLabel,
  }) {
    final fertilizer = action.fertilizer;
    final nextState = switch (action.kind) {
      _CropInteractionKind.irrigate => CropSimulationService.irrigate(_state),
      _CropInteractionKind.weedControl =>
        CropSimulationService.weedControl(_state),
      _CropInteractionKind.pestControl =>
        CropSimulationService.pestControl(_state),
      _CropInteractionKind.ripener =>
        CropSimulationService.applyRipener(_state),
      _CropInteractionKind.fertilizer when fertilizer != null =>
        CropSimulationService.applyFertilizer(_state, fertilizer),
      _CropInteractionKind.fertilizer => _state,
    };

    unawaited(_triggerApplicationEffect(action.kind));
    _setSimulationState(nextState);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${sourceLabel ?? action.label} applied to the crop.'),
        duration: const Duration(milliseconds: 1100),
      ),
    );
  }

  String _supplySearchText(Supply supply) {
    return '${supply.name} ${supply.description}'.toLowerCase();
  }

  List<Supply> _suppliesForCategory(_CropSupplyCategory category) {
    final provider = context.read<SuppliesProvider>();
    final keywords = switch (category) {
      _CropSupplyCategory.fertilizer => [
          'fert',
          'abono',
          'urea',
          'npk',
          'potash',
          'mop',
          'kcl',
          '14-14',
          '16-20',
          '46-0-0',
          '0-0-60',
          'phosphate',
          'ammophos',
        ],
      _CropSupplyCategory.herbicide => [
          'herb',
          'weed',
          'glyph',
          'roundup',
          'atrazine',
          'diuron',
          '2,4-d',
          '2 4 d',
          'sencor',
        ],
      _CropSupplyCategory.pesticide => [
          'pest',
          'insect',
          'fung',
          'aphid',
          'borer',
          'insecticide',
          'fungicide',
          'carbofuran',
          'imidacloprid',
          'malathion',
        ],
    };
    return provider.items.where((supply) {
      if (supply.quantity <= 0) {
        return false;
      }
      final haystack = _supplySearchText(supply);
      return keywords.any(haystack.contains);
    }).toList(growable: false);
  }

  CropFertilizerRecommendation _fertilizerRecommendationFromSupply(
    Supply supply,
  ) {
    final text = _supplySearchText(supply);
    if (text.contains('potash') ||
        text.contains('potassium') ||
        text.contains('0-0-60') ||
        text.contains('mop') ||
        text.contains('kcl')) {
      return const CropFertilizerRecommendation(
        label: 'Potassium support',
        formula: '0-0-60',
        reason: 'Mapped from available stock in supplies.',
        nitrogenDelta: 0,
        phosphorusDelta: 0,
        potassiumDelta: 18,
        color: Colors.orange,
      );
    }
    if (text.contains('phosph') ||
        text.contains('16-20') ||
        text.contains('dap') ||
        text.contains('ammophos')) {
      return const CropFertilizerRecommendation(
        label: 'Phosphorus support',
        formula: '16-20-0',
        reason: 'Mapped from available stock in supplies.',
        nitrogenDelta: 8,
        phosphorusDelta: 14,
        potassiumDelta: 0,
        color: Colors.teal,
      );
    }
    if (text.contains('urea') ||
        text.contains('nitrogen') ||
        text.contains('46-0-0')) {
      return const CropFertilizerRecommendation(
        label: 'Nitrogen support',
        formula: '46-0-0',
        reason: 'Mapped from available stock in supplies.',
        nitrogenDelta: 18,
        phosphorusDelta: 0,
        potassiumDelta: 0,
        color: Colors.lightGreen,
      );
    }
    if (text.contains('14-14') ||
        text.contains('complete') ||
        text.contains('npk')) {
      return const CropFertilizerRecommendation(
        label: 'Balanced NPK support',
        formula: '14-14-14',
        reason: 'Mapped from available stock in supplies.',
        nitrogenDelta: 10,
        phosphorusDelta: 10,
        potassiumDelta: 10,
        color: Colors.green,
      );
    }
    return _fertilizers.isNotEmpty
        ? _fertilizers.first
        : const CropFertilizerRecommendation(
            label: 'Balanced stock fertilizer',
            formula: '14-14-14',
            reason: 'Mapped from available stock in supplies.',
            nitrogenDelta: 10,
            phosphorusDelta: 10,
            potassiumDelta: 10,
            color: Colors.green,
          );
  }

  _CropInteractionAction _resolvedActionFromSupply(
    _CropInteractionAction action,
    Supply supply,
  ) {
    return switch (action.kind) {
      _CropInteractionKind.fertilizer => _CropInteractionAction(
          label: supply.name,
          subtitle: 'Stock fertilizer selected from supplies.',
          icon: Icons.inventory_2_rounded,
          color: action.color,
          kind: action.kind,
          enabled: action.enabled,
          fertilizer: _fertilizerRecommendationFromSupply(supply),
        ),
      _CropInteractionKind.weedControl => _CropInteractionAction(
          label: supply.name,
          subtitle: 'Herbicide selected from supplies.',
          icon: Icons.grass_rounded,
          color: action.color,
          kind: action.kind,
          enabled: action.enabled,
        ),
      _CropInteractionKind.pestControl => _CropInteractionAction(
          label: supply.name,
          subtitle: 'Pesticide selected from supplies.',
          icon: Icons.pest_control_rounded,
          color: action.color,
          kind: action.kind,
          enabled: action.enabled,
        ),
      _ => action,
    };
  }

  Future<void> _consumeSupplyUnit(Supply supply) async {
    if (supply.quantity <= 0) {
      return;
    }
    final provider = context.read<SuppliesProvider>();
    final nextQuantity = math.max(0, supply.quantity - 1);
    final updated = Supply(
      id: supply.id,
      name: supply.name,
      description: supply.description,
      quantity: nextQuantity,
      cost: supply.cost,
      total: nextQuantity * supply.cost,
    );
    await provider.updateSupply(updated);
  }

  Future<bool> _offerSupplyPurchase(_CropSupplyCategory category) async {
    final labels = switch (category) {
      _CropSupplyCategory.fertilizer => (
          title: 'No fertilizer stock found',
          body:
              'No fertilizer supplies are available right now. Do you want to open Add Supplies and purchase fertilizer now?'
        ),
      _CropSupplyCategory.herbicide => (
          title: 'No herbicide stock found',
          body:
              'No herbicide supplies are available right now. Do you want to open Add Supplies and purchase herbicide now?'
        ),
      _CropSupplyCategory.pesticide => (
          title: 'No pesticide stock found',
          body:
              'No pesticide supplies are available right now. Do you want to open Add Supplies and purchase pesticide now?'
        ),
    };
    final shouldOpen = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(labels.title),
            content: Text(labels.body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Purchase now'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldOpen || !mounted) {
      return false;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const FrmAddSupScreen(),
      ),
    );
    if (!mounted) {
      return false;
    }
    await context.read<SuppliesProvider>().loadSupplies();
    return true;
  }

  Future<Supply?> _pickSupplyForCategory(_CropSupplyCategory category) async {
    final parentContext = context;
    await context.read<SuppliesProvider>().loadSupplies();
    var matches = _suppliesForCategory(category);
    if (matches.isEmpty) {
      final purchased = await _offerSupplyPurchase(category);
      if (!purchased || !mounted) {
        return null;
      }
      matches = _suppliesForCategory(category);
      if (matches.isEmpty) {
        return null;
      }
    }
    if (!parentContext.mounted) {
      return null;
    }
    return showModalBottomSheet<Supply>(
      context: parentContext,
      showDragHandle: true,
      builder: (context) {
        final title = switch (category) {
          _CropSupplyCategory.fertilizer => 'Choose fertilizer stock',
          _CropSupplyCategory.herbicide => 'Choose herbicide stock',
          _CropSupplyCategory.pesticide => 'Choose pesticide stock',
        };
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap one stock item to apply one unit to the crop.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final supply = matches[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        tileColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.56),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.16),
                          child: Text(
                            '${supply.quantity}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        title: Text(
                          supply.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          supply.description.isEmpty
                              ? 'Qty ${supply.quantity} available'
                              : '${supply.description}\nQty ${supply.quantity} available',
                        ),
                        isThreeLine: supply.description.isNotEmpty,
                        trailing: const Icon(Icons.north_east_rounded),
                        onTap: () => Navigator.of(context).pop(supply),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _playDockFlight(
    _CropSupplyCategory category,
    _CropInteractionAction action,
  ) {
    final overlayContext = _workspaceOverlayKey.currentContext;
    final sourceContext = _dockButtonKeys[category]?.currentContext;
    final targetContext = _cropTargetKey.currentContext;
    if (overlayContext == null ||
        sourceContext == null ||
        targetContext == null) {
      return;
    }
    final overlayBox = overlayContext.findRenderObject() as RenderBox?;
    final sourceBox = sourceContext.findRenderObject() as RenderBox?;
    final targetBox = targetContext.findRenderObject() as RenderBox?;
    if (overlayBox == null || sourceBox == null || targetBox == null) {
      return;
    }
    final start = sourceBox.localToGlobal(
      sourceBox.size.center(Offset.zero),
      ancestor: overlayBox,
    );
    final end = targetBox.localToGlobal(
      targetBox.size.center(Offset.zero),
      ancestor: overlayBox,
    );
    final id = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      _dockFlight = _DockFlight(
        id: id,
        start: start,
        end: end,
        icon: action.icon,
        color: action.color,
        label: action.label,
      );
      _dockFlightAtTarget = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dockFlight?.id != id) {
        return;
      }
      setState(() {
        _dockFlightAtTarget = true;
      });
    });
    Future<void>.delayed(const Duration(milliseconds: 720)).then((_) {
      if (!mounted || _dockFlight?.id != id) {
        return;
      }
      setState(() {
        _dockFlight = null;
        _dockFlightAtTarget = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        key: _workspaceOverlayKey,
        children: [
          AppBackdrop(
            isDark: theme.brightness == Brightness.dark,
            backgroundImageAsset: FarmOperationsService.cropBackdropAssetForAge(
              widget.cropType,
              _state.day,
            ),
            backgroundImageOpacity:
                theme.brightness == Brightness.dark ? 0.12 : 0.18,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dockHeight = math.min(
                    260.0,
                    math.max(190.0, constraints.maxHeight * 0.36),
                  );
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildWorkspaceHeader(theme),
                        const SizedBox(height: 10),
                        Expanded(child: _buildCropWorkspacePanel(theme)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: dockHeight,
                          child: _buildWorkspaceControls(theme),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (_dockFlight != null) _buildDockFlightOverlay(),
        ],
      ),
    );
  }

  Widget _buildDockFlightOverlay() {
    final flight = _dockFlight!;
    final size = _dockFlightAtTarget ? 24.0 : 62.0;
    return IgnorePointer(
      child: AnimatedPositioned(
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeOutCubic,
        left: (_dockFlightAtTarget ? flight.end.dx : flight.start.dx) -
            (size / 2),
        top: (_dockFlightAtTarget ? flight.end.dy : flight.start.dy) -
            (size / 2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 620),
          opacity: _dockFlightAtTarget ? 0.14 : 1,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 620),
            scale: _dockFlightAtTarget ? 0.4 : 1,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: flight.color.withValues(alpha: 0.94),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: flight.color.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                flight.icon,
                color: Colors.white,
                size: _dockFlightAtTarget ? 12 : 30,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceHeader(ThemeData theme) {
    final isLive = _cropMode == _WorkspaceCropMode.live;
    return FrostedPanel(
      radius: 28,
      padding: const EdgeInsets.all(18),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        spacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(_state),
                icon: const Icon(Icons.close_rounded),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.farmName} Crop Workspace',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppVisuals.textForest,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!isLive) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Keep the crop visible while simulating the season and dropping field inputs directly onto it.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppVisuals.textForestMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Live crop'),
                selected: _cropMode == _WorkspaceCropMode.live,
                onSelected: (_) {
                  setState(() {
                    _cropMode = _WorkspaceCropMode.live;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('Simulated crop'),
                selected: _cropMode == _WorkspaceCropMode.simulated,
                onSelected: (_) {
                  setState(() {
                    _cropMode = _WorkspaceCropMode.simulated;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCropWorkspacePanel(ThemeData theme) {
    final visual = _currentVisual;
    final isLive = _cropMode == _WorkspaceCropMode.live;

    return DragTarget<_CropInteractionAction>(
      onWillAcceptWithDetails: (details) {
        setState(() {
          _isDropActive = details.data.enabled;
        });
        return details.data.enabled;
      },
      onLeave: (_) {
        if (_isDropActive) {
          setState(() {
            _isDropActive = false;
          });
        }
      },
      onAcceptWithDetails: (details) {
        setState(() {
          _isDropActive = false;
        });
        _handleInteractionAction(details.data, triggeredByDrag: true);
      },
      builder: (context, candidateData, rejectedData) {
        final isTargeted = _isDropActive || candidateData.isNotEmpty;

        return Container(
          key: _cropTargetKey,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isTargeted
                  ? AppVisuals.primaryGold.withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.14),
              width: isTargeted ? 2.2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.green.shade900.withValues(alpha: 0.52),
                      Colors.black.withValues(alpha: 0.84),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 124),
                child: Image.asset(
                  visual.assetPath,
                  fit: BoxFit.contain,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.16),
                      Colors.black.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.62),
                    ],
                  ),
                ),
              ),
              if (!isLive)
                Positioned(
                  top: 18,
                  left: 18,
                  right: 18,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _GalleryBadge(
                        label: _cropMode == _WorkspaceCropMode.live
                            ? 'Live crop'
                            : 'Simulated crop',
                        color: AppVisuals.brandBlue,
                      ),
                      _GalleryBadge(
                        label: _state.planted
                            ? 'Day ${_state.day}'
                            : 'Pre-planting',
                        color: AppVisuals.brandGreen,
                      ),
                      _GalleryBadge(
                        label:
                            'NPK ${_state.nitrogen.toStringAsFixed(0)}-${_state.phosphorus.toStringAsFixed(0)}-${_state.potassium.toStringAsFixed(0)}',
                        color: AppVisuals.primaryGold,
                      ),
                    ],
                  ),
                ),
              if (isTargeted)
                Positioned.fill(
                  child: Container(
                    color: AppVisuals.primaryGold.withValues(alpha: 0.18),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.64),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        'Drop here to apply to the crop',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!isLive)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.44),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          visual.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          visual.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            _WorkspaceMetricChip(
                              label: 'Stage',
                              value: _state.growthStage,
                            ),
                            _WorkspaceMetricChip(
                              label: 'Health',
                              value: CropSimulationService.healthBand(
                                _state.plantHealth,
                              ),
                            ),
                            _WorkspaceMetricChip(
                              label: 'Yield',
                              value:
                                  '${_state.projectedYieldTons.toStringAsFixed(1)} t',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (_activeApplicationEffect != null)
                Positioned.fill(
                  child: _CropApplicationOverlay(
                    key: ValueKey('workspace-effect-$_applicationEffectRunId'),
                    effect: _activeApplicationEffect!,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkspaceControls(ThemeData theme) {
    if (_cropMode == _WorkspaceCropMode.live) {
      return FrostedPanel(
        radius: 30,
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(14),
          children: [
            SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: _buildWorkspaceSupplyDockPanel(theme, minimal: true),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 280,
              child: SingleChildScrollView(
                child: _buildWorkspaceUtilityPanel(theme, minimal: true),
              ),
            ),
          ],
        ),
      );
    }

    return FrostedPanel(
      radius: 30,
      color: theme.colorScheme.surface.withValues(alpha: 0.9),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(14),
        children: [
          SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: _buildWorkspaceSeasonPanel(theme),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: _buildWorkspaceSupplyDockPanel(theme),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 280,
            child: SingleChildScrollView(
              child: _buildWorkspaceUtilityPanel(theme),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: _buildWorkspaceFertilizerPanel(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceSeasonPanel(ThemeData theme) {
    final actualAge =
        DateTime.now().difference(_state.plantingDate).inDays.clamp(0, 9999);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Simulate The Season',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.primaryGold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Advance the season while the crop preview stays on screen.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _state.harvested || !_state.planted
                    ? () =>
                        _setSimulationState(CropSimulationService.plant(_state))
                    : null,
                icon: const Icon(Icons.agriculture_rounded),
                label: Text(
                  _state.planted && !_state.harvested
                      ? 'Season active'
                      : 'Plant crop',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _setSimulationState(
                  CropSimulationService.syncToLiveAge(_state),
                ),
                icon: const Icon(Icons.sync_rounded),
                label: Text('Load live age ($actualAge d)'),
              ),
              for (final days in const [7, 30, 90])
                OutlinedButton.icon(
                  onPressed: _state.canAdvance
                      ? () => _setSimulationState(
                            CropSimulationService.advance(_state, days: days),
                          )
                      : null,
                  icon: Icon(
                    days >= 30
                        ? Icons.fast_forward_rounded
                        : Icons.calendar_view_week_rounded,
                  ),
                  label: Text('+$days days'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _SliderTile(
            label: 'Temperature',
            value: _state.environment.temperatureC,
            min: 22,
            max: 38,
            valueLabel:
                '${_state.environment.temperatureC.toStringAsFixed(0)} C',
            color: Colors.amber.shade700,
            onChanged: (value) => _setSimulationState(
              CropSimulationService.updateEnvironment(
                _state,
                temperatureC: value,
              ),
            ),
          ),
          _SliderTile(
            label: 'Humidity',
            value: _state.environment.humidity.toDouble(),
            min: 40,
            max: 95,
            valueLabel: '${_state.environment.humidity}%',
            color: AppVisuals.brandBlue,
            onChanged: (value) => _setSimulationState(
              CropSimulationService.updateEnvironment(
                _state,
                humidity: value.round(),
              ),
            ),
          ),
          _SliderTile(
            label: 'Weekly rain',
            value: _state.environment.weeklyRainfallMm,
            min: 0,
            max: 140,
            valueLabel:
                '${_state.environment.weeklyRainfallMm.toStringAsFixed(0)} mm',
            color: AppVisuals.brandGreen,
            onChanged: (value) => _setSimulationState(
              CropSimulationService.updateEnvironment(
                _state,
                weeklyRainfallMm: value,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceSupplyDockPanel(
    ThemeData theme, {
    bool minimal = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!minimal) ...[
            Text(
              'Supply Dock',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppVisuals.primaryGold,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a button to pick stock from Supplies, or long-press and drag the button onto the crop.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppVisuals.textForestMuted,
              ),
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _supplyDockActions.map((action) {
              final category = _categoryForAction(action);
              return _WorkspaceSupplyDockButton(
                globalKey: category == null ? null : _dockButtonKeys[category],
                action: action,
                onApply: _handleInteractionAction,
              );
            }).toList(),
          ),
          if (!minimal) ...[
            const SizedBox(height: 14),
            Text(
              'If no matching stock exists, RCAMARii can open Add Supplies so you can purchase and record it immediately.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppVisuals.textForestMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkspaceUtilityPanel(
    ThemeData theme, {
    bool minimal = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!minimal) ...[
            Text(
              'Direct Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppVisuals.primaryGold,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'These controls act immediately without opening the supply picker.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppVisuals.textForestMuted,
              ),
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _utilityActions.map((action) {
              return _WorkspaceActionTile(
                action: action,
                onApply: _handleInteractionAction,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceFertilizerPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended Blends',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.primaryGold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The dock uses whatever fertilizer stock you have. These recommendations stay visible here so you know what the simulator wants next.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
          const SizedBox(height: 16),
          ..._fertilizers.map((fertilizer) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WorkspaceActionTile(
                action: _CropInteractionAction(
                  label: fertilizer.label,
                  subtitle: '${fertilizer.formula} • ${fertilizer.reason}',
                  icon: Icons.science_rounded,
                  color: fertilizer.color,
                  kind: _CropInteractionKind.fertilizer,
                  enabled: _state.canAdvance,
                  fertilizer: fertilizer,
                ),
                onApply: _handleInteractionAction,
              ),
            );
          }),
          if (_fertilizers.isEmpty)
            Text(
              'No fertilizer recommendations are available for this state yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppVisuals.textForestMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactSideIconButton extends StatelessWidget {
  const _CompactSideIconButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: tooltip,
        child: IconButton.filledTonal(
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: isSelected
                ? AppVisuals.primaryGold.withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.1),
            foregroundColor:
                isSelected ? const Color(0xFF312618) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.82)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          icon: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _CompactActionBubble extends StatelessWidget {
  const _CompactActionBubble({
    required this.action,
    required this.onApply,
  });

  final _CropInteractionAction action;
  final ValueChanged<_CropInteractionAction> onApply;

  @override
  Widget build(BuildContext context) {
    Widget bubble({double elevation = 0}) {
      return Material(
        color: Colors.transparent,
        elevation: elevation,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: action.enabled ? () => onApply(action) : null,
          child: Ink(
            width: 88,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color:
                  action.color.withValues(alpha: action.enabled ? 0.2 : 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: action.color.withValues(
                  alpha: action.enabled ? 0.42 : 0.14,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!action.enabled) {
      return Opacity(opacity: 0.58, child: bubble());
    }

    return LongPressDraggable<_CropInteractionAction>(
      data: action,
      feedback: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 96),
        child: bubble(elevation: 8),
      ),
      childWhenDragging: Opacity(
        opacity: 0.28,
        child: bubble(),
      ),
      child: bubble(),
    );
  }
}

class _WorkspaceSupplyDockButton extends StatefulWidget {
  const _WorkspaceSupplyDockButton({
    required this.action,
    required this.onApply,
    this.globalKey,
  });

  final GlobalKey? globalKey;
  final _CropInteractionAction action;
  final ValueChanged<_CropInteractionAction> onApply;

  @override
  State<_WorkspaceSupplyDockButton> createState() =>
      _WorkspaceSupplyDockButtonState();
}

class _WorkspaceSupplyDockButtonState
    extends State<_WorkspaceSupplyDockButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Widget button({double elevation = 0}) {
      return AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Material(
          key: widget.globalKey,
          color: Colors.transparent,
          elevation: elevation,
          borderRadius: BorderRadius.circular(26),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: widget.action.enabled
                ? () => widget.onApply(widget.action)
                : null,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            child: Ink(
              width: 122,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.action.color.withValues(
                      alpha: widget.action.enabled ? 0.92 : 0.28,
                    ),
                    widget.action.color.withValues(
                      alpha: widget.action.enabled ? 0.68 : 0.18,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: widget.action.enabled ? 0.26 : 0.1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.action.color.withValues(
                      alpha: widget.action.enabled ? 0.24 : 0.1,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.action.icon,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.action.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.action.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!widget.action.enabled) {
      return Opacity(opacity: 0.72, child: button());
    }

    return LongPressDraggable<_CropInteractionAction>(
      data: widget.action,
      feedback: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 132),
        child: button(elevation: 8),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: button(),
      ),
      child: button(),
    );
  }
}

class _WorkspaceActionTile extends StatelessWidget {
  const _WorkspaceActionTile({
    required this.action,
    required this.onApply,
  });

  final _CropInteractionAction action;
  final ValueChanged<_CropInteractionAction> onApply;

  @override
  Widget build(BuildContext context) {
    Widget tile({double elevation = 0}) {
      return Material(
        color: Colors.transparent,
        elevation: elevation,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: action.enabled ? () => onApply(action) : null,
          child: Ink(
            width: 160,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  action.color.withValues(alpha: action.enabled ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: action.color
                    .withValues(alpha: action.enabled ? 0.34 : 0.14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(action.icon, color: action.color, size: 22),
                const SizedBox(height: 10),
                Text(
                  action.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppVisuals.textForest,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  action.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppVisuals.textForestMuted,
                        height: 1.35,
                      ),
                ),
                if (!action.enabled) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Unavailable now',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: action.color,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (!action.enabled) {
      return Opacity(opacity: 0.72, child: tile());
    }

    return LongPressDraggable<_CropInteractionAction>(
      data: action,
      feedback: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: tile(elevation: 8),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: tile(),
      ),
      child: tile(),
    );
  }
}

class _WorkspaceMetricChip extends StatelessWidget {
  const _WorkspaceMetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _SimulationImageViewer extends StatefulWidget {
  const _SimulationImageViewer({
    required this.title,
    required this.images,
    required this.initialPage,
  });

  final String title;
  final List<_SimulationReferenceImage> images;
  final int initialPage;

  @override
  State<_SimulationImageViewer> createState() => _SimulationImageViewerState();
}

class _SimulationImageViewerState extends State<_SimulationImageViewer> {
  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;
  static const double _zoomStep = 0.5;

  late final PageController _pageController;
  late final List<TransformationController> _transformControllers;
  late final List<double> _scales;
  late int _pageIndex;

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.initialPage.clamp(0, widget.images.length - 1).toInt();
    _pageController = PageController(initialPage: _pageIndex);
    _transformControllers = List<TransformationController>.generate(
      widget.images.length,
      (_) => TransformationController(),
    );
    _scales = List<double>.filled(widget.images.length, _minScale);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _transformControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setScale(double nextScale) {
    final clampedScale = nextScale.clamp(_minScale, _maxScale);
    _transformControllers[_pageIndex].value = Matrix4.identity()
      ..scaleByDouble(clampedScale, clampedScale, 1.0, 1.0);
    setState(() {
      _scales[_pageIndex] = clampedScale;
    });
  }

  void _zoomIn() {
    _setScale(_scales[_pageIndex] + _zoomStep);
  }

  void _zoomOut() {
    _setScale(_scales[_pageIndex] - _zoomStep);
  }

  void _resetZoom() {
    _transformControllers[_pageIndex].value = Matrix4.identity();
    setState(() {
      _scales[_pageIndex] = _minScale;
    });
  }

  void _goToPage(int index) {
    if (index < 0 || index >= widget.images.length) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentImage = widget.images[_pageIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showSideControls = constraints.maxWidth >= 920;

            return Stack(
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.images.length,
                    onPageChanged: (value) {
                      setState(() {
                        _pageIndex = value;
                      });
                    },
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        transformationController: _transformControllers[index],
                        minScale: _minScale,
                        maxScale: _maxScale,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              88,
                              showSideControls ? 132 : 20,
                              showSideControls ? 28 : 140,
                            ),
                            child: _ReferenceImageRender(
                              image: widget.images[index],
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${currentImage.title} • ${_pageIndex + 1}/${widget.images.length}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.76),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: showSideControls ? 148 : 20,
                  bottom: showSideControls ? 24 : 102,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (currentImage.isActive)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _GalleryBadge(
                              label: 'Current match',
                              color: AppVisuals.primaryGold,
                            ),
                          ),
                        Text(
                          currentImage.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentImage.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (showSideControls)
                  Positioned(
                    top: 104,
                    right: 20,
                    bottom: 20,
                    child: _ViewerControlRail(
                      canGoBack: _pageIndex > 0,
                      canGoForward: _pageIndex < widget.images.length - 1,
                      zoomLabel:
                          'Zoom ${_scales[_pageIndex].toStringAsFixed(1)}x',
                      onPrevious: () => _goToPage(_pageIndex - 1),
                      onNext: () => _goToPage(_pageIndex + 1),
                      onZoomOut: _zoomOut,
                      onReset: _resetZoom,
                      onZoomIn: _zoomIn,
                    ),
                  )
                else
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _ViewerBottomDock(
                      canGoBack: _pageIndex > 0,
                      canGoForward: _pageIndex < widget.images.length - 1,
                      zoomLabel:
                          'Zoom ${_scales[_pageIndex].toStringAsFixed(1)}x',
                      onPrevious: () => _goToPage(_pageIndex - 1),
                      onNext: () => _goToPage(_pageIndex + 1),
                      onZoomOut: _zoomOut,
                      onReset: _resetZoom,
                      onZoomIn: _zoomIn,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ViewerControlRail extends StatelessWidget {
  const _ViewerControlRail({
    required this.canGoBack,
    required this.canGoForward,
    required this.zoomLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onZoomOut,
    required this.onReset,
    required this.onZoomIn,
  });

  final bool canGoBack;
  final bool canGoForward;
  final String zoomLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final VoidCallback onZoomIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _ViewerControlButton(
            icon: Icons.chevron_left_rounded,
            onPressed: canGoBack ? onPrevious : null,
          ),
          const SizedBox(height: 10),
          _ViewerControlButton(
            icon: Icons.chevron_right_rounded,
            onPressed: canGoForward ? onNext : null,
          ),
          const SizedBox(height: 18),
          _ViewerControlButton(
            icon: Icons.zoom_out_rounded,
            onPressed: onZoomOut,
          ),
          const SizedBox(height: 10),
          _ViewerControlButton(
            icon: Icons.center_focus_strong_rounded,
            onPressed: onReset,
          ),
          const SizedBox(height: 10),
          _ViewerControlButton(
            icon: Icons.zoom_in_rounded,
            onPressed: onZoomIn,
          ),
          const SizedBox(height: 16),
          Text(
            zoomLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ViewerBottomDock extends StatelessWidget {
  const _ViewerBottomDock({
    required this.canGoBack,
    required this.canGoForward,
    required this.zoomLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onZoomOut,
    required this.onReset,
    required this.onZoomIn,
  });

  final bool canGoBack;
  final bool canGoForward;
  final String zoomLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final VoidCallback onZoomIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            zoomLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _ViewerControlButton(
                icon: Icons.chevron_left_rounded,
                onPressed: canGoBack ? onPrevious : null,
              ),
              _ViewerControlButton(
                icon: Icons.chevron_right_rounded,
                onPressed: canGoForward ? onNext : null,
              ),
              _ViewerControlButton(
                icon: Icons.zoom_out_rounded,
                onPressed: onZoomOut,
              ),
              _ViewerControlButton(
                icon: Icons.center_focus_strong_rounded,
                onPressed: onReset,
              ),
              _ViewerControlButton(
                icon: Icons.zoom_in_rounded,
                onPressed: onZoomIn,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewerControlButton extends StatelessWidget {
  const _ViewerControlButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.32),
      ),
      icon: Icon(icon),
    );
  }
}

class _SugarcanePreviewTodoItem {
  const _SugarcanePreviewTodoItem({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color color;
}

class _MonthlyGrowthStage {
  const _MonthlyGrowthStage({
    required this.title,
    required this.subtitle,
    required this.startDay,
    required this.endDay,
    required this.tint,
  });

  final String title;
  final String subtitle;
  final int startDay;
  final int endDay;
  final Color tint;
}

class _ScenarioImageState {
  const _ScenarioImageState({
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.saturation,
    required this.brightness,
    required this.isActive,
  });

  final String title;
  final String subtitle;
  final Color tint;
  final double saturation;
  final double brightness;
  final bool isActive;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.16),
        foregroundColor: color,
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.color,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
  });

  final String label;
  final double value;
  final String valueLabel;
  final Color color;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppVisuals.textForest,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.14),
            ),
            child: Slider(
              min: min,
              max: max,
              value: value.clamp(min, max),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeroDatum extends StatelessWidget {
  const _HeroDatum({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppVisuals.textForestMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppVisuals.textForest,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FertilizerCard extends StatelessWidget {
  const _FertilizerCard({
    required this.recommendation,
    required this.enabled,
    required this.onApply,
  });

  final CropFertilizerRecommendation recommendation;
  final bool enabled;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: recommendation.color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${recommendation.label} (${recommendation.formula})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppVisuals.textForest,
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: enabled ? onApply : null,
                style: FilledButton.styleFrom(
                  backgroundColor: recommendation.color.withValues(alpha: 0.16),
                  foregroundColor: recommendation.color,
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            recommendation.reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
  });

  final ScheduleAlert alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(alert.icon, color: alert.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppVisuals.textForest,
                  ),
                ),
                const SizedBox(height: 4),
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

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.entry,
  });

  final CropSimulationLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppVisuals.primaryGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${entry.day}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppVisuals.primaryGold,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppVisuals.textForest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.details,
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

List<double> _imageFilterMatrix({
  required double saturation,
  required double brightness,
}) {
  final invSat = 1 - saturation;
  final r = 0.213 * invSat;
  final g = 0.715 * invSat;
  final b = 0.072 * invSat;

  return <double>[
    (r + saturation) * brightness,
    g * brightness,
    b * brightness,
    0,
    0,
    r * brightness,
    (g + saturation) * brightness,
    b * brightness,
    0,
    0,
    r * brightness,
    g * brightness,
    (b + saturation) * brightness,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}
