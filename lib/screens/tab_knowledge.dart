import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/farm_model.dart';
import '../models/knowledge_qa_model.dart';
import '../models/schedule_alert_model.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/guideline_language_provider.dart';
import '../services/app_localization_service.dart';
import '../services/app_route_observer.dart';
import '../services/farming_advice_service.dart';
import '../services/guideline_localization_service.dart';
import '../services/knowledge_qa_service.dart';
import '../widgets/modern_screen_shell.dart';
import 'pdf_handbook_viewer_screen.dart';
import 'webview_screen.dart';

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

  late Future<List<KnowledgeQaItem>> _qaFuture;
  String _selectedLanguage = 'en';
  String _selectedCategory = 'All';
  bool _playedKnowledgeAudio = false;
  bool _isRouteObserverSubscribed = false;

  @override
  void initState() {
    super.initState();
    _qaFuture = _qaService.loadQaItems();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _playKnowledgeAudio());
  }

  @override
  void dispose() {
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    unawaited(_stopKnowledgeAudioIfNeeded());
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _playKnowledgeAudio() async {
    if (!mounted || _playedKnowledgeAudio) {
      return;
    }

    _playedKnowledgeAudio = true;
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    await context.read<AppAudioProvider>().playForStyle(
          style: selectedGlobalAudioSoundStyle,
          seriousAssetPath: _seriousKnowledgeAudioAssetPath,
          funnyAssetPath: _funnyKnowledgeAudioAssetPath,
          enabled: appSettings.audioSoundsEnabled,
        );
  }

  Future<void> _stopKnowledgeAudioIfNeeded() async {
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    await context.read<AppAudioProvider>().stopForStyle(
          style: appSettings.audioSoundStyle,
          seriousAssetPath: _seriousKnowledgeAudioAssetPath,
          funnyAssetPath: _funnyKnowledgeAudioAssetPath,
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRouteObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute<dynamic>) {
        appRouteObserver.subscribe(this, route);
        _isRouteObserverSubscribed = true;
      }
    }
  }

  @override
  void didPushNext() {
    unawaited(_stopKnowledgeAudioIfNeeded());
  }

  @override
  void didPop() {
    unawaited(_stopKnowledgeAudioIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preferredLanguage = _qaLanguageFor(
      context.watch<GuidelineLanguageProvider>().selectedLanguage,
    );
    if (_selectedLanguage != preferredLanguage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedLanguage = preferredLanguage);
      });
    }
    final farmProvider = Provider.of<FarmProvider>(context);
    final farm = farmProvider.selectedFarm;
    final farmAgeInDays =
        farm == null ? null : DateTime.now().difference(farm.date).inDays;
    final normalizedFarmAge =
        farmAgeInDays == null || farmAgeInDays < 0 ? 0 : farmAgeInDays;
    final relevantAdvice = farm == null
        ? const <ScheduleAlert>[]
        : FarmingAdviceService.getAdviceForCrop(
            farm.type,
            normalizedFarmAge,
          );

    return ModernScreenShell(
      title: context.tr('Knowledge Studio'),
      subtitle: context.tr('Knowledge'),
      titleStyleOverride: const TextStyle(color: Colors.white),
      subtitleStyleOverride: const TextStyle(color: Colors.white),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FutureBuilder<List<KnowledgeQaItem>>(
            future: _qaFuture,
            builder: (context, snapshot) {
              final qaItems = snapshot.data ?? const <KnowledgeQaItem>[];
              final filteredQa = _filterQaItems(qaItems);
              final availableCategories = _availableCategories(qaItems);
              final references = _buildReferenceAssets(farm);
              final smartTip = farm == null
                  ? null
                  : _smartTipForFarm(
                      farm: farm,
                      ageInDays: normalizedFarmAge,
                      advice: relevantAdvice,
                      qaItems: qaItems,
                      references: references,
                    );

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeroSection(
                        theme: theme,
                        farm: farm,
                        references: references,
                        qaItems: qaItems,
                      ),
                      if (farm != null && smartTip != null) ...[
                        const SizedBox(height: 18),
                        _buildFarmFocusSection(
                          theme: theme,
                          farm: farm,
                          ageInDays: normalizedFarmAge,
                          smartTip: smartTip,
                        ),
                      ],
                      const SizedBox(height: 18),
                      _buildReferenceSection(
                        theme: theme,
                        references: references,
                      ),
                      const SizedBox(height: 18),
                      if (farm != null && relevantAdvice.isNotEmpty) ...[
                        _buildAdvisorySection(
                          theme: theme,
                          farm: farm,
                          ageInDays: normalizedFarmAge,
                          advice: relevantAdvice,
                        ),
                        const SizedBox(height: 18),
                      ],
                      _buildQaSection(
                        theme: theme,
                        allItems: qaItems,
                        filteredItems: filteredQa,
                        categories: availableCategories,
                        isLoading:
                            snapshot.connectionState == ConnectionState.waiting,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeroSection({
    required ThemeData theme,
    required Farm? farm,
    required List<_KnowledgeReferenceAsset> references,
    required List<KnowledgeQaItem> qaItems,
  }) {
    final matchingReferences = farm == null
        ? references.length
        : references.where((ref) => ref.matchesCrop(farm.type)).length;
    final localizedQuestions =
        qaItems.where((item) => item.lang == _selectedLanguage).length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.92),
            theme.colorScheme.secondary.withValues(alpha: 0.88),
            const Color(0xFF0B1521),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farm == null
                          ? 'Bundled field knowledge for rice and sugarcane.'
                          : 'Focused learning for ${farm.name} and the next field decisions.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      farm == null
                          ? 'Browse the handbook deck, filter Q&A by language, and open practical answers without leaving the app.'
                          : '${farm.type} is active on this farm, so the handbook cards and farm advisories stay centered on that crop first.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildHeroMetric(
                label: 'Active Crop',
                value: farm?.type ?? 'No farm selected',
                icon: Icons.eco_rounded,
              ),
              _buildHeroMetric(
                label: 'Reference Deck',
                value:
                    "$matchingReferences match${matchingReferences == 1 ? '' : 'es'}",
                icon: Icons.library_books_rounded,
              ),
              _buildHeroMetric(
                label: 'Q&A in View',
                value:
                    '$localizedQuestions ${_languageLabel(_selectedLanguage)} items',
                icon: Icons.quiz_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmFocusSection({
    required ThemeData theme,
    required Farm farm,
    required int ageInDays,
    required String smartTip,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final twoColumns = maxWidth > 760;
        final spacing = 12.0;
        final cardWidth = twoColumns ? (maxWidth - spacing) / 2 : maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildFocusCard(
                theme: theme,
                eyebrow: 'SMART TIP',
                title: "RCAMARii's Tips for ${farm.type}",
                subtitle: 'This follows the active farm type and crop stage.',
                body: smartTip,
                icon: Icons.bolt_rounded,
                accent: theme.colorScheme.tertiary,
                forceDarkText: true,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSearchCard(
                theme: theme,
                farm: farm,
                ageInDays: ageInDays,
                accent: theme.colorScheme.secondary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFocusCard({
    required ThemeData theme,
    required String eyebrow,
    required String title,
    required String subtitle,
    required String body,
    required IconData icon,
    required Color accent,
    bool forceDarkText = false,
  }) {
    final titleColor =
        forceDarkText ? Colors.black87 : theme.colorScheme.onSurface;
    final subtitleColor = forceDarkText
        ? Colors.black54
        : theme.colorScheme.onSurface.withValues(alpha: 0.58);
    final bodyColor = forceDarkText
        ? Colors.black87
        : theme.colorScheme.onSurface.withValues(alpha: 0.74);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: forceDarkText
            ? const Color(0xFFFFF7E1)
            : theme.colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: accent,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              color: subtitleColor,
              height: 1.4,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              color: bodyColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard({
    required ThemeData theme,
    required Farm farm,
    required int ageInDays,
    required Color accent,
  }) {
    final query = _googleQueryForFarm(farm, ageInDays);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.14),
                ),
                child: Icon(Icons.travel_explore_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GOOGLE SEARCH',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: accent,
                      ),
                    ),
                    Text(
                      '${farm.type} at day $ageInDays',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Open a targeted Google search built from the active farm type and the crop age.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              height: 1.4,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            query,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _openFarmGoogleSearch(farm, ageInDays),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Search on Google'),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceSection({
    required ThemeData theme,
    required List<_KnowledgeReferenceAsset> references,
  }) {
    return _buildSectionCard(
      theme: theme,
      eyebrow: 'REFERENCE DECK',
      title: 'Bundled handbooks',
      subtitle:
          'The knowledge tab now centers on the three bundled handbook assets you requested.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width;
          final columns = maxWidth > 980
              ? 3
              : maxWidth > 640
                  ? 2
                  : 1;
          final spacing = 12.0;
          final width = (maxWidth - (columns - 1) * spacing) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: references
                .map(
                  (reference) => SizedBox(
                    width: width,
                    child: _buildReferenceCard(theme, reference),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildReferenceCard(
      ThemeData theme, _KnowledgeReferenceAsset reference) {
    return InkWell(
      onTap: () => _showReferenceSheet(reference),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              reference.accent.withValues(alpha: 0.2),
              theme.colorScheme.surface.withValues(alpha: 0.98),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: reference.accent.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: reference.accent.withValues(alpha: 0.16),
                  ),
                  child: Icon(reference.icon, color: reference.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reference.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              reference.summary,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            ...reference.highlights.take(3).map(
                  (highlight) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: reference.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            highlight,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.72),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openHandbook(reference),
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('See coverage'),
            ),
          ],
        ),
      ),
    );
  }

  void _openHandbook(_KnowledgeReferenceAsset reference) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfHandbookViewerScreen(
          title: reference.title,
          assetPath: reference.assetPath,
        ),
      ),
    );
  }

  Widget _buildAdvisorySection({
    required ThemeData theme,
    required Farm farm,
    required int ageInDays,
    required List<ScheduleAlert> advice,
  }) {
    return _buildSectionCard(
      theme: theme,
      eyebrow: 'LIVE ADVISORY',
      title: 'Current farm context',
      subtitle:
          '${farm.name} is $ageInDays days from planting, so these reminders stay close to the crop stage.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: advice
            .map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: item.color.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.color.withValues(alpha: 0.18),
                      ),
                      child: Icon(item.icon, color: item.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.message,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildQaSection({
    required ThemeData theme,
    required List<KnowledgeQaItem> allItems,
    required List<KnowledgeQaItem> filteredItems,
    required List<String> categories,
    required bool isLoading,
  }) {
    return _buildSectionCard(
      theme: theme,
      eyebrow: 'Q&A LAB',
      title: 'Ask, tap, and learn',
      subtitle:
          'Filter by language and category, then tap a card to reveal the answer and practical details.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchField(theme),
          const SizedBox(height: 14),
          _buildFilterLabel(theme, 'Language'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLanguageChip(theme, 'en', 'English'),
              _buildLanguageChip(theme, 'tl', 'Tagalog'),
              _buildLanguageChip(theme, 'hil', 'Hiligaynon'),
            ],
          ),
          const SizedBox(height: 14),
          _buildFilterLabel(theme, 'Category'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map((category) => _buildCategoryChip(theme, category))
                .toList(),
          ),
          const SizedBox(height: 18),
          if (isLoading && allItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredItems.isEmpty)
            _buildEmptyQaState(theme)
          else
            ...filteredItems.map((item) => _buildQaCard(theme, item)),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      stylusHandwritingEnabled: false,
      controller: _searchController,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: 'Search question, answer, or tags',
        filled: true,
        fillColor:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      ),
    );
  }

  Widget _buildFilterLabel(ThemeData theme, String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
      ),
    );
  }

  Widget _buildLanguageChip(ThemeData theme, String code, String label) {
    final selected = _selectedLanguage == code;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _selectedLanguage = code;
        _selectedCategory = 'All';
        _expandedQaIds.clear();
      }),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: selected ? Colors.white : theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildCategoryChip(ThemeData theme, String category) {
    final selected = _selectedCategory == category;
    return ChoiceChip(
      label: Text(category),
      selected: selected,
      onSelected: (_) => setState(() {
        _selectedCategory = category;
        _expandedQaIds.clear();
      }),
      selectedColor: theme.colorScheme.secondary,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: selected ? Colors.white : theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildEmptyQaState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'No Q&A matches this filter yet. Try another language, reset the category, or clear the search.',
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildQaCard(ThemeData theme, KnowledgeQaItem item) {
    final expanded = _expandedQaIds.contains(item.id);
    final icon = KnowledgeQaService.iconFromCodepoint(item.iconCodepoint);
    final accent = _categoryColor(theme, item.category);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: expanded
            ? accent.withValues(alpha: 0.12)
            : theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: expanded
              ? accent.withValues(alpha: 0.28)
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        onTap: () => setState(() {
          if (expanded) {
            _expandedQaIds.remove(item.id);
          } else {
            _expandedQaIds.add(item.id);
          }
        }),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.14),
                    ),
                    child: Icon(icon, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPill(
                              theme: theme,
                              label: item.category,
                              accent: accent,
                            ),
                            _buildPill(
                              theme: theme,
                              label: item.topic,
                              accent: theme.colorScheme.secondary,
                            ),
                            _buildPill(
                              theme: theme,
                              label: _languageLabel(item.lang),
                              accent: theme.colorScheme.tertiary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.question,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                            fontSize: 15,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          item.answer,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.76),
                            height: 1.55,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: item.tags
                            .split(',')
                            .map((tag) => tag.trim())
                            .where((tag) => tag.isNotEmpty)
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPill({
    required ThemeData theme,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required String eyebrow,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  void _showReferenceSheet(_KnowledgeReferenceAsset reference) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: reference.accent.withValues(alpha: 0.14),
                      ),
                      child: Icon(reference.icon, color: reference.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        reference.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  reference.summary,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  reference.assetPath,
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                ...reference.highlights.map(
                  (highlight) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 16, color: reference.accent),
                        const SizedBox(width: 8),
                        Expanded(child: Text(highlight)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFarmGoogleSearch(Farm farm, int ageInDays) {
    final query = _googleQueryForFarm(farm, ageInDays);
    final url = 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(url: url),
      ),
    );
  }

  String _googleQueryForFarm(Farm farm, int ageInDays) {
    return '${farm.type} farming advice Philippines $ageInDays days after planting';
  }

  List<KnowledgeQaItem> _filterQaItems(List<KnowledgeQaItem> items) {
    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      final matchesLanguage = item.lang == _selectedLanguage;
      final matchesCategory =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      final haystack =
          '${item.topic} ${item.question} ${item.answer} ${item.tags}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesLanguage && matchesCategory && matchesQuery;
    }).toList();
  }

  List<String> _availableCategories(List<KnowledgeQaItem> items) {
    final categories = items
        .where((item) => item.lang == _selectedLanguage)
        .map((item) => item.category)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...categories];
  }

  String _smartTipForFarm({
    required Farm farm,
    required int ageInDays,
    required List<ScheduleAlert> advice,
    required List<KnowledgeQaItem> qaItems,
    required List<_KnowledgeReferenceAsset> references,
  }) {
    if (advice.isNotEmpty) {
      final current = advice.first;
      return '${current.title}: ${current.message}';
    }

    final normalizedType = farm.type.toLowerCase();
    for (final item in qaItems) {
      if (item.lang != _selectedLanguage) {
        continue;
      }

      final searchable =
          '${item.topic} ${item.tags} ${item.question}'.toLowerCase();
      if ((normalizedType.contains('sugar') &&
              (searchable.contains('soil') ||
                  searchable.contains('water') ||
                  searchable.contains('fertilizer') ||
                  searchable.contains('abono') ||
                  searchable.contains('herbicide') ||
                  searchable.contains('pesticide'))) ||
          (normalizedType.contains('rice') &&
              (searchable.contains('water') ||
                  searchable.contains('seedling') ||
                  searchable.contains('fertilizer'))) ||
          (normalizedType.contains('corn') &&
              (searchable.contains('fertilizer') ||
                  searchable.contains('weed') ||
                  searchable.contains('pest')))) {
        return item.answer;
      }
    }

    for (final reference in references) {
      if (reference.matchesCrop(farm.type)) {
        return reference.summary;
      }
    }

    return '${farm.type} is active on this farm. Use the reference deck and the live Q&A cards below to review the next field decision for day $ageInDays.';
  }

  List<_KnowledgeReferenceAsset> _buildReferenceAssets(Farm? farm) {
    final references = <_KnowledgeReferenceAsset>[
      const _KnowledgeReferenceAsset(
        title: 'Advanced Sugarcane Farming Handbook',
        assetPath: 'lib/assets/advanced_sugarcane_farming_handbook.pdf',
        crop: 'Sugarcane',
        summary:
            'A practical sugarcane guide covering land preparation, fertilizer timing, weed and pest control, ratooning, irrigation, and yield improvement.',
        icon: Icons.auto_stories_rounded,
        accent: Color(0xFF3D7A2B),
        highlights: [
          'Land preparation, planting methods, and recommended row spacing.',
          'Per-hectare fertilizer program plus foliar timing.',
          'Weed, pest, disease, irrigation, and ratoon management.',
        ],
      ),
      const _KnowledgeReferenceAsset(
        title: 'All Rice Handbook',
        assetPath: 'lib/assets/all_rice.pdf',
        crop: 'Rice',
        summary:
            'The rice reference file for variety, field preparation, crop care, and practical farm operations.',
        icon: Icons.grass_rounded,
        accent: Color(0xFF1E88E5),
        highlights: [
          'Rice production guidance from field setup through harvest.',
          'Reference material for crop care and stage-based management.',
          'Useful when the selected farm is focused on palay or rice.',
        ],
      ),
      const _KnowledgeReferenceAsset(
        title: 'All Sugarcane Handbook',
        assetPath: 'lib/assets/all_sugarcane.pdf',
        crop: 'Sugarcane',
        summary:
            'An additional sugarcane reference deck that complements the advanced handbook with broad production coverage.',
        icon: Icons.menu_book_rounded,
        accent: Color(0xFF8E5B2B),
        highlights: [
          'Sugarcane crop coverage from establishment to harvest.',
          'Companion reference for broader production review.',
          'Useful for comparing core field practices with advanced notes.',
        ],
      ),
    ];

    if (farm == null) {
      return references;
    }

    final normalizedCrop = farm.type.toLowerCase();
    references.sort((left, right) {
      final leftMatch = left.matchesCrop(normalizedCrop) ? 1 : 0;
      final rightMatch = right.matchesCrop(normalizedCrop) ? 1 : 0;
      return rightMatch.compareTo(leftMatch);
    });
    return references;
  }

  String _languageLabel(String lang) {
    switch (lang) {
      case 'tl':
        return 'Tagalog';
      case 'hil':
        return 'Hiligaynon';
      default:
        return 'English';
    }
  }

  String _qaLanguageFor(GuidelineLanguage language) {
    switch (language) {
      case GuidelineLanguage.tagalog:
        return 'tl';
      case GuidelineLanguage.visayan:
        return 'hil';
      case GuidelineLanguage.english:
        return 'en';
    }
  }

  Color _categoryColor(ThemeData theme, String category) {
    switch (category) {
      case 'Soil':
        return const Color(0xFF8D6E63);
      case 'Water':
        return const Color(0xFF1E88E5);
      case 'Chemicals':
        return const Color(0xFF26A69A);
      case 'Planting':
        return const Color(0xFF43A047);
      case 'Harvest':
        return const Color(0xFFF9A825);
      default:
        return theme.colorScheme.secondary;
    }
  }
}

class _KnowledgeReferenceAsset {
  final String title;
  final String assetPath;
  final String crop;
  final String summary;
  final IconData icon;
  final Color accent;
  final List<String> highlights;

  const _KnowledgeReferenceAsset({
    required this.title,
    required this.assetPath,
    required this.crop,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.highlights,
  });

  bool matchesCrop(String cropType) {
    final normalized = cropType.toLowerCase();
    return normalized.contains(crop.toLowerCase());
  }
}
