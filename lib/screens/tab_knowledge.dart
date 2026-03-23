import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/knowledge_qa_model.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/guideline_language_provider.dart';
import '../services/app_localization_service.dart';
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

  late Future<List<KnowledgeQaItem>> _qaFuture;
  bool _playedKnowledgeAudio = false;
  bool _isRouteObserverSubscribed = false;

  AppAudioProvider? _appAudio;
  AppSettingsProvider? _appSettings;

  @override
  void initState() {
    super.initState();
    _qaFuture = _qaService.loadQaItems();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _playKnowledgeAudio());
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
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FutureBuilder<List<KnowledgeQaItem>>(
        future: _qaFuture,
        builder: (context, snapshot) {
          final qaItems = snapshot.data ?? [];
          final filteredQa = _filterQaItems(qaItems);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroSection(theme),
              const SizedBox(height: 20),
              _buildReferenceCards(theme),
              const SizedBox(height: 20),
              Expanded(
                child: FrostedPanel(
                  radius: 32,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchInput(theme),
                      const SizedBox(height: 12),
                      Expanded(
                        child: snapshot.connectionState ==
                                ConnectionState.waiting
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: scheme.primary,
                                ),
                              )
                            : _buildQaList(theme, filteredQa),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          colors: [
            scheme.surfaceContainerHighest.withValues(alpha: 0.95),
            scheme.surfaceContainerHighest.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Knowledge Studio'),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: scheme.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('Browse the handbook deck and open practical answers.'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              color: scheme.primary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceCards(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _ReferenceCard(
            title: 'Sugarcane',
            subtitle: 'Handbook',
            icon: Icons.bakery_dining_rounded,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfHandbookViewerScreen(assetPath: 'lib/assets/handbooks/sugarcane.pdf', title: 'Sugarcane Handbook'))),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ReferenceCard(
            title: 'Rice',
            subtitle: 'Handbook',
            icon: Icons.grass_rounded,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfHandbookViewerScreen(assetPath: 'lib/assets/handbooks/rice.pdf', title: 'Rice Handbook'))),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchInput(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: context.tr('Search Q&A...'),
          hintStyle:
              TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
          prefixIcon:
              Icon(Icons.search_rounded, color: scheme.primary, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildQaList(ThemeData theme, List<KnowledgeQaItem> items) {
    final scheme = theme.colorScheme;
    if (items.isEmpty) {
      return Center(
        child: Text(
          context.tr('No results found.'),
          style: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.8)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isExpanded = _expandedQaIds.contains(index);

        return GestureDetector(
          onTap: () => setState(() => isExpanded ? _expandedQaIds.remove(index) : _expandedQaIds.add(index)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isExpanded
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.9)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isExpanded
                    ? scheme.primary.withValues(alpha: 0.35)
                    : scheme.outline.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.question,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: scheme.primary,
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  Divider(
                    color: scheme.outline.withValues(alpha: 0.35),
                    thickness: 0.5,
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.answer,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<KnowledgeQaItem> _filterQaItems(List<KnowledgeQaItem> items) {
    final query = _searchController.text.toLowerCase();
    return items.where((item) {
      final languageProvider = Provider.of<GuidelineLanguageProvider>(context, listen: false);
      final isFil = languageProvider.selectedLanguage == GuidelineLanguage.tagalog || 
                   languageProvider.selectedLanguage == GuidelineLanguage.visayan;
      final currentLangCode = isFil ? 'fil' : 'en';
      
      final matchesLang = item.lang == currentLangCode;
      final matchesQuery = item.question.toLowerCase().contains(query) || item.answer.toLowerCase().contains(query);
      return matchesLang && matchesQuery;
    }).toList();
  }
}

class _ReferenceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _ReferenceCard({required this.title, required this.subtitle, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary, size: 24),
            const SizedBox(height: 12),
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
