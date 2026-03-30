import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/knowledge_qa_model.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/guideline_language_provider.dart';
import '../services/app_defaults_service.dart';
import '../services/app_localization_service.dart';
import '../services/app_properties_store.dart';
import '../services/guideline_localization_service.dart';
import '../services/app_route_observer.dart';
import '../services/knowledge_qa_service.dart';
import '../themes/app_visuals.dart';
import 'pdf_handbook_viewer_screen.dart';

class TabKnowledge extends StatefulWidget {
  const TabKnowledge({super.key});

  @override
  State<TabKnowledge> createState() => _TabKnowledgeState();
}

class _TabKnowledgeState extends State<TabKnowledge> with RouteAware {
  static const _seriousKnowledgeAudioAssetPath = 'lib/assets/audio/ganda.mp3';
  static const _funnyKnowledgeAudioAssetPath = 'lib/assets/audio/lethergo.mp3';

  final KnowledgeQaService _qaService = KnowledgeQaService();
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _expandedQaIds = <int>{};
  final AppPropertiesStore _store = AppPropertiesStore.instance;

  late Future<List<KnowledgeQaItem>> _qaFuture;
  bool _playedKnowledgeAudio = false;
  bool _isRouteObserverSubscribed = false;
  String? _selectedCategory;

  AppAudioProvider? _appAudio;
  AppSettingsProvider? _appSettings;

  @override
  void initState() {
    super.initState();
    _qaFuture = _qaService.loadQaItems();
    _searchController.addListener(() => setState(() {}));
    _restoreSavedState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playKnowledgeAudio());
  }

  Future<void> _restoreSavedState() async {
    final savedCategory = (await _store
                .getString(AppDefaultsService.knowledgeSelectedCategoryKey))
            ?.trim() ??
        '';
    if (!mounted || savedCategory.isEmpty) {
      return;
    }
    setState(() {
      _selectedCategory = savedCategory;
    });
  }

  Future<void> _setSelectedCategory(String? value) async {
    setState(() {
      _selectedCategory = value?.trim().isEmpty ?? true ? null : value?.trim();
    });
    await _store.setString(
      AppDefaultsService.knowledgeSelectedCategoryKey,
      _selectedCategory ?? '',
    );
  }

  @override
  void dispose() {
    if (_isRouteObserverSubscribed) appRouteObserver.unsubscribe(this);
    unawaited(_stopKnowledgeAudioIfNeeded());
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _playKnowledgeAudio() async {
    if (!mounted || _playedKnowledgeAudio) return;
    final appSettings = _appSettings;
    final appAudio = _appAudio;
    if (appSettings == null || appAudio == null) return;

    _playedKnowledgeAudio = true;
    await appAudio.playForStyle(
      style: appSettings.audioSoundStyle,
      seriousAssetPath: _seriousKnowledgeAudioAssetPath,
      funnyAssetPath: _funnyKnowledgeAudioAssetPath,
      enabled: appSettings.audioSoundsEnabled,
    );
  }

  Future<void> _stopKnowledgeAudioIfNeeded() async {
    final appSettings = _appSettings;
    final appAudio = _appAudio;
    if (appSettings == null || appAudio == null) return;

    await appAudio.stopForStyle(
      style: appSettings.audioSoundStyle,
      seriousAssetPath: _seriousKnowledgeAudioAssetPath,
      funnyAssetPath: _funnyKnowledgeAudioAssetPath,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appAudio ??= Provider.of<AppAudioProvider>(context, listen: false);
    _appSettings ??= Provider.of<AppSettingsProvider>(context, listen: false);

    if (!_isRouteObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute<dynamic>) {
        appRouteObserver.subscribe(this, route);
        _isRouteObserverSubscribed = true;
      }
    }
  }

  @override
  void didPushNext() => unawaited(_stopKnowledgeAudioIfNeeded());
  @override
  void didPop() => unawaited(_stopKnowledgeAudioIfNeeded());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeLanguage =
        context.watch<GuidelineLanguageProvider>().selectedLanguage;
    final activeLanguageLabel =
        GuidelineLocalizationService.languageLabel(activeLanguage);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: AppVisuals.mainTabBackgroundImageOpacity(
              theme.brightness == Brightness.dark,
            ),
            child: Image.asset(
              'lib/assets/images/images (1).jfif',
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppVisuals.mainTabImageOverlay(
                theme.brightness == Brightness.dark,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FutureBuilder<List<KnowledgeQaItem>>(
            future: _qaFuture,
            builder: (context, snapshot) {
              final allItems = snapshot.data ?? const <KnowledgeQaItem>[];
              final localizedItems =
                  _itemsForLanguage(allItems, activeLanguage);
              final categoryCounts = _buildCategoryCounts(localizedItems);
              final categories = categoryCounts.keys.toList()..sort();

              if (_selectedCategory != null &&
                  !categories.contains(_selectedCategory)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _setSelectedCategory(null);
                  }
                });
              }

              final filteredItems = _filterQaItems(
                localizedItems,
                query: _searchController.text,
              );

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildHeroSection(
                          theme,
                          totalCount: localizedItems.length,
                          filteredCount: filteredItems.length,
                          categoryCount: categories.length,
                          languageLabel: activeLanguageLabel,
                        ),
                        const SizedBox(height: 20),
                        const _SectionHeading(
                          title: 'Learning Tracks',
                          subtitle:
                              'Study by farm discipline so the crew can learn in the same order decisions happen in the field.',
                        ),
                        const SizedBox(height: 14),
                        _buildLearningTracks(theme, categoryCounts),
                        const SizedBox(height: 20),
                        const _SectionHeading(
                          title: 'Field Library',
                          subtitle:
                              'Use handbooks for full reference, then narrow into quick answers from the live question bank below.',
                        ),
                        const SizedBox(height: 14),
                        _buildReferenceCards(theme),
                        const SizedBox(height: 20),
                        _buildSearchPanel(
                          theme,
                          filteredItems.length,
                        ),
                        const SizedBox(height: 20),
                        _SectionHeading(
                          title: 'Question Bank',
                          subtitle:
                              'Tap any card to open the answer, supporting topic, and study tags.',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.24),
                              ),
                            ),
                            child: Text(
                              '${filteredItems.length} entries',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  else if (filteredItems.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState(theme))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 28),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildQaCard(theme, filteredItems[index]),
                          childCount: filteredItems.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection(
    ThemeData theme, {
    required int totalCount,
    required int filteredCount,
    required int categoryCount,
    required String languageLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppVisuals.deepAnthracite,
            Color.alphaBlend(
              AppVisuals.brandBlue.withValues(alpha: 0.14),
              AppVisuals.brandGreen,
            ),
            Color.alphaBlend(
              AppVisuals.brandRed.withValues(alpha: 0.22),
              AppVisuals.surfaceRaised,
            ),
          ],
        ),
        border: Border.all(
          color: AppVisuals.brandBlue.withValues(alpha: 0.2),
          width: 1.1,
        ),
        boxShadow: AppVisuals.shadow3d(theme.colorScheme),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -46,
            right: -22,
            child: Container(
              width: 138,
              height: 138,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppVisuals.brandBlue.withValues(alpha: 0.26),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppVisuals.brandWhite.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppVisuals.brandWhite.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  'FIELD INTELLIGENCE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppVisuals.brandWhite.withValues(alpha: 0.88),
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('Knowledge Studio'),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppVisuals.softWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'A professional learning hub for sugarcane and rice operations. Review handbooks, scan themed study tracks, and pull quick answers before planning, applying inputs, or sending crews to the field.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppVisuals.brandWhite.withValues(alpha: 0.8),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _HeroMetric(
                    icon: Icons.auto_stories_rounded,
                    label: 'Q&A entries',
                    value: '$totalCount',
                  ),
                  _HeroMetric(
                    icon: Icons.tune_rounded,
                    label: 'Filtered',
                    value: '$filteredCount',
                  ),
                  _HeroMetric(
                    icon: Icons.hub_rounded,
                    label: 'Categories',
                    value: '$categoryCount',
                  ),
                  _HeroMetric(
                    icon: Icons.language_rounded,
                    label: 'Language',
                    value: languageLabel,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppVisuals.brandWhite.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppVisuals.brandWhite.withValues(alpha: 0.12),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StudyCue(
                      icon: Icons.landscape_rounded,
                      text:
                          'Start with soil and water conditions before choosing input rates.',
                    ),
                    SizedBox(height: 10),
                    _StudyCue(
                      icon: Icons.agriculture_rounded,
                      text:
                          'Use planting and harvest guidance as an operational checklist, not just reading material.',
                    ),
                    SizedBox(height: 10),
                    _StudyCue(
                      icon: Icons.analytics_rounded,
                      text:
                          'Compare handbook guidance with actual field observations to improve crew decisions.',
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

  Widget _buildLearningTracks(
    ThemeData theme,
    Map<String, int> categoryCounts,
  ) {
    final tracks = <_TrackData>[
      _TrackData(
        title: 'Soil & Land Care',
        category: 'Soil',
        icon: Icons.landscape_rounded,
        accent: AppVisuals.brandBlue,
        description:
            'Prepare the field base first so roots, drainage, and pH support every later input.',
        bullets: const [
          'Assess pH, acidity, and compaction before crop establishment.',
          'Improve structure with residue, organic matter, and drainage work.',
          'Treat land correction as a yield protection step, not a side task.',
        ],
      ),
      _TrackData(
        title: 'Water Scheduling',
        category: 'Water',
        icon: Icons.water_drop_rounded,
        accent: const Color(0xFF74A8C4),
        description:
            'Match irrigation timing to growth stage to prevent stress, weak tillering, and inefficient input use.',
        bullets: const [
          'Watch field moisture by stage instead of watering on habit.',
          'Avoid prolonged standing water where it does not fit the crop stage.',
          'Plan drainage and irrigation together during wet periods.',
        ],
      ),
      _TrackData(
        title: 'Crop Nutrition & Inputs',
        category: 'Chemicals',
        icon: Icons.science_rounded,
        accent: AppVisuals.brandRed,
        description:
            'Apply fertilizer and crop protection based on need, timing, and field diagnosis.',
        bullets: const [
          'Use deficiency signs and soil cues before increasing rates.',
          'Separate nutrient planning from emergency corrective spraying.',
          'Record what was applied and what crop response followed.',
        ],
      ),
      _TrackData(
        title: 'Planting to Harvest',
        category: 'Harvest',
        icon: Icons.agriculture_rounded,
        accent: const Color(0xFFC89A79),
        description:
            'Keep establishment quality and harvest timing aligned with labor, weather, and target output.',
        bullets: const [
          'Protect sett or seed quality and spacing during planting.',
          'Treat field sanitation and stand checks as part of crop maintenance.',
          'Time harvest around maturity, access, and transport readiness.',
        ],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final cardWidth =
            wide ? (constraints.maxWidth - 14) / 2 : double.infinity;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: tracks
              .map(
                (track) => SizedBox(
                  width: cardWidth,
                  child: _LearningTrackCard(
                    data: track,
                    answerCount: categoryCounts[track.category] ?? 0,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildReferenceCards(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final medium = constraints.maxWidth >= 560;
        final cardWidth = wide
            ? (constraints.maxWidth - 28) / 3
            : medium
                ? (constraints.maxWidth - 14) / 2
                : double.infinity;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: cardWidth,
              child: _ReferenceLibraryCard(
                title: 'Sugarcane Handbook',
                subtitle: 'Field production guide',
                icon: Icons.local_florist_rounded,
                accent: AppVisuals.brandRed,
                bullets: const [
                  'Land prep, varieties, and planting materials',
                  'Nutrient timing, ratoon care, and field sanitation',
                  'Harvest readiness and post-cut follow-up',
                ],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PdfHandbookViewerScreen(
                      assetPath: 'lib/assets/handbooks/all_sugarcane.pdf',
                      title: 'Sugarcane Handbook',
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _ReferenceLibraryCard(
                title: 'Rice Handbook',
                subtitle: 'Season-to-season production guide',
                icon: Icons.grass_rounded,
                accent: AppVisuals.brandBlue,
                bullets: const [
                  'Nursery or direct-seeding decisions',
                  'Water control, weed pressure, and nutrition',
                  'Harvest timing, drying, and handling discipline',
                ],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PdfHandbookViewerScreen(
                      assetPath: 'lib/assets/handbooks/all_rice.pdf',
                      title: 'Rice Handbook',
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _ReferenceLibraryCard(
                title: 'Advanced Sugarcane',
                subtitle: 'Bonus reference handbook',
                icon: Icons.menu_book_rounded,
                accent: const Color(0xFFC89A79),
                bullets: const [
                  'Expanded field strategies for sugarcane production',
                  'Useful as a deeper follow-up after the main handbook',
                  'Best for supervisors, planners, and field leads',
                ],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PdfHandbookViewerScreen(
                      assetPath:
                          'lib/assets/handbooks/advanced_sugarcane_farming_handbook.pdf',
                      title: 'Advanced Sugarcane Farming Handbook',
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: const _ReferenceLibraryCard(
                title: 'Study Routine',
                subtitle: 'Recommended workflow',
                icon: Icons.school_rounded,
                accent: Color(0xFFC89A79),
                bullets: [
                  'Read the handbook section before a major field task.',
                  'Use the Q&A bank for fast clarification during operations.',
                  'Brief the crew with the same points you validated in the library.',
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchPanel(
    ThemeData theme,
    int resultCount,
  ) {
    final scheme = theme.colorScheme;

    return FrostedPanel(
      radius: 34,
      padding: const EdgeInsets.all(18),
      color: theme.colorScheme.surface.withValues(alpha: 0.46),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Search Knowledge Bank',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppVisuals.brandBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$resultCount results',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForest,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Search by problem, topic, or answer text to find quick field guidance.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _buildSearchInput(theme),
        ],
      ),
    );
  }

  Widget _buildSearchInput(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: context.tr('Search Q&A...'),
          hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: scheme.primary,
            size: 20,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.close_rounded),
                  color: scheme.onSurfaceVariant,
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final scheme = theme.colorScheme;
    return FrostedPanel(
      radius: 32,
      padding: const EdgeInsets.all(28),
      color: theme.colorScheme.surface.withValues(alpha: 0.46),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppVisuals.brandBlue.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.find_in_page_rounded,
              color: scheme.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('No results found.'),
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a broader term or switch the language selection for more guidance.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildQaCard(ThemeData theme, KnowledgeQaItem item) {
    final scheme = theme.colorScheme;
    final isExpanded = _expandedQaIds.contains(item.id);
    final tags = _tagsFor(item.tags);
    final categoryIcon = item.iconCodepoint != null
        ? KnowledgeQaService.iconFromCodepoint(item.iconCodepoint)
        : (KnowledgeQaService.categoryIcons[item.category] ??
            Icons.auto_stories_rounded);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedQaIds.remove(item.id);
          } else {
            _expandedQaIds.add(item.id);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppVisuals.cloudGlass.withValues(alpha: isExpanded ? 0.96 : 0.9),
              Color.alphaBlend(
                AppVisuals.brandBlue
                    .withValues(alpha: isExpanded ? 0.08 : 0.04),
                AppVisuals.fieldMist,
              ),
            ],
          ),
          border: Border.all(
            color: isExpanded
                ? scheme.primary.withValues(alpha: 0.34)
                : scheme.outline.withValues(alpha: 0.24),
          ),
          boxShadow: AppVisuals.shadow3d(scheme),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppVisuals.brandRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    categoryIcon,
                    color: AppVisuals.brandRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MiniPill(
                            label: item.category,
                            backgroundColor:
                                AppVisuals.brandBlue.withValues(alpha: 0.16),
                            textColor: AppVisuals.textForest,
                          ),
                          if (item.topic.trim().isNotEmpty)
                            _MiniPill(
                              label: item.topic,
                              backgroundColor:
                                  AppVisuals.brandRed.withValues(alpha: 0.1),
                              textColor: AppVisuals.brandRed,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.question,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: scheme.primary,
                  size: 28,
                ),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .map(
                      (tag) => _MiniPill(
                        label: tag,
                        backgroundColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.9),
                        textColor: scheme.onSurfaceVariant,
                      ),
                    )
                    .toList(),
              ),
            ],
            AnimatedCrossFade(
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Divider(
                    color: scheme.outline.withValues(alpha: 0.28),
                    height: 1,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.46),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: scheme.outline.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      item.answer,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppVisuals.textForest,
                        height: 1.65,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<KnowledgeQaItem> _itemsForLanguage(
    List<KnowledgeQaItem> items,
    GuidelineLanguage language,
  ) {
    return items
        .where((item) => _matchesLanguage(item.lang, language))
        .toList();
  }

  List<KnowledgeQaItem> _filterQaItems(
    List<KnowledgeQaItem> items, {
    required String query,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return items.where((item) {
      final matchesCategory =
          _selectedCategory == null || item.category == _selectedCategory;
      final matchesQuery = normalizedQuery.isEmpty ||
          item.question.toLowerCase().contains(normalizedQuery) ||
          item.answer.toLowerCase().contains(normalizedQuery) ||
          item.topic.toLowerCase().contains(normalizedQuery) ||
          item.tags.toLowerCase().contains(normalizedQuery);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  Map<String, int> _buildCategoryCounts(List<KnowledgeQaItem> items) {
    final counts = <String, int>{};
    for (final item in items) {
      counts.update(item.category, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  bool _matchesLanguage(String code, GuidelineLanguage language) {
    switch (language) {
      case GuidelineLanguage.english:
        return code == 'en';
      case GuidelineLanguage.tagalog:
        return code == 'tl';
      case GuidelineLanguage.visayan:
        return code == 'vis' || code == 'hil';
    }
  }

  List<String> _tagsFor(String tags) {
    return tags
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .take(4)
        .toList();
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeading({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppVisuals.brandWhite.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppVisuals.brandWhite.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppVisuals.brandBlue, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppVisuals.softWhite,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppVisuals.brandWhite.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudyCue extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StudyCue({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppVisuals.brandBlue,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.brandWhite.withValues(alpha: 0.78),
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackData {
  final String title;
  final String category;
  final IconData icon;
  final Color accent;
  final String description;
  final List<String> bullets;

  const _TrackData({
    required this.title,
    required this.category,
    required this.icon,
    required this.accent,
    required this.description,
    required this.bullets,
  });
}

class _LearningTrackCard extends StatelessWidget {
  final _TrackData data;
  final int answerCount;

  const _LearningTrackCard({
    required this.data,
    required this.answerCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(18),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.46),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: data.accent.withValues(alpha: 0.16),
                ),
                child: Icon(data.icon, color: data.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _MiniPill(
                label: '$answerCount answers',
                backgroundColor: data.accent.withValues(alpha: 0.12),
                textColor: data.accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppVisuals.textForest,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          ...data.bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: data.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bullet,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppVisuals.textForestMuted,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
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

class _ReferenceLibraryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<String> bullets;
  final VoidCallback? onTap;

  const _ReferenceLibraryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.bullets,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(18),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.46),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: accent.withValues(alpha: 0.14),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppVisuals.textForestMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bullet,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppVisuals.textForest,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: onTap,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open Handbook'),
              style: FilledButton.styleFrom(
                foregroundColor: AppVisuals.textForest,
                backgroundColor: accent.withValues(alpha: 0.16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _MiniPill({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
