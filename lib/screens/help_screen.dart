import 'package:flutter/material.dart';

import '../services/app_localization_service.dart';
import '../themes/app_visuals.dart';
import '../widgets/modern_screen_shell.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ModernScreenShell(
        title: context.tr('How to use RCAMARii'),
        subtitle: context.tr('Help Center'),
        actionBadge: FilledButton.tonalIcon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(context.tr('Back')),
          style: FilledButton.styleFrom(
            foregroundColor: scheme.onSecondaryContainer,
            backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.92),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        bodyPadding: EdgeInsets.zero,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(context),
              const SizedBox(height: 14),
              _buildQuickStart(context),
              const SizedBox(height: 14),
              _buildModuleGuide(context),
              const SizedBox(height: 14),
              _buildTips(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            AppVisuals.deepGreen.withValues(alpha: 0.96),
            AppVisuals.surfaceGreen.withValues(alpha: 0.92),
            AppVisuals.primaryGold.withValues(alpha: 0.76),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppVisuals.surfaceGreen.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppVisuals.warmOffWhite.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppVisuals.warmOffWhite.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              context.tr('FIELD GUIDE'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppVisuals.warmOffWhite,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(
              'RCAMARii is easiest to use when you move from farm setup, to daily records, to inventory, then to decisions.',
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppVisuals.warmOffWhite,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Use the hub for shortcuts, the field workspace for detailed records, and the library when you need field guidance.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppVisuals.warmOffWhite.withValues(alpha: 0.86),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(label: context.tr('Estate')),
              _HeroChip(label: context.tr('Ledger')),
              _HeroChip(label: context.tr('Assets')),
              _HeroChip(label: context.tr('Library')),
              _HeroChip(label: context.tr('Finance')),
              _HeroChip(label: context.tr('Reports')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStart(BuildContext context) {
    final steps = [
      _HelpStep(
        number: '1',
        title: context.tr('Set up or select a farm'),
        body: context.tr(
          'Open Estate first, add your farm details, then select the active farm so crop-age guidance and weather context become specific.',
        ),
      ),
      _HelpStep(
        number: '2',
        title: context.tr('Record what happened today'),
        body: context.tr(
          'Use Ledger for job orders and activity costs. Use Logistics and Finance when deliveries or money movement need to be tracked.',
        ),
      ),
      _HelpStep(
        number: '3',
        title: context.tr('Review assets before buying'),
        body: context.tr(
          'Open Assets to check supplies and equipment so replenishment decisions come from current stock instead of memory.',
        ),
      ),
      _HelpStep(
        number: '4',
        title: context.tr('Use the library before acting'),
        body: context.tr(
          'Open Library for handbooks, question banks, and crop guidance when you need a field answer before scheduling labor or inputs.',
        ),
      ),
    ];

    return _SectionCard(
      title: context.tr('Quick Start'),
      subtitle: context.tr(
        'A simple operating order for new users and returning crews.',
      ),
      child: Column(
        children: steps
            .map(
              (step) => Padding(
                padding: EdgeInsets.only(bottom: step == steps.last ? 0 : 12),
                child: _StepTile(step: step),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildModuleGuide(BuildContext context) {
    final modules = [
      _ModuleGuideItem(
        icon: Icons.eco_rounded,
        title: context.tr('Estate'),
        body: context.tr(
          'Farm profiles, selected field context, and the main workspace tabs for operations.',
        ),
        accent: AppVisuals.brandRed,
      ),
      _ModuleGuideItem(
        icon: Icons.analytics_rounded,
        title: context.tr('Ledger'),
        body: context.tr(
          'Job orders, worker activity, and the operating record of what was done in the field.',
        ),
        accent: AppVisuals.brandBlue,
      ),
      _ModuleGuideItem(
        icon: Icons.inventory_2_rounded,
        title: context.tr('Assets'),
        body: context.tr(
          'Supplies and equipment records used to monitor stock, tools, and replenishment pressure.',
        ),
        accent: AppVisuals.brandGreen,
      ),
      _ModuleGuideItem(
        icon: Icons.auto_stories_rounded,
        title: context.tr('Library'),
        body: context.tr(
          'Handbooks, guided Q&A, and reference material for sugarcane and rice decisions.',
        ),
        accent: AppVisuals.primaryGold,
      ),
      _ModuleGuideItem(
        icon: Icons.local_shipping_rounded,
        title: context.tr('Logistics'),
        body: context.tr(
          'Delivery records and transport-related workflows connected to harvest and profit review.',
        ),
        accent: AppVisuals.accentChartBlue,
      ),
      _ModuleGuideItem(
        icon: Icons.account_balance_wallet_rounded,
        title: context.tr('Finance'),
        body: context.tr(
          'Tracker plus trial profit tools for simulations and estimates. Use Harvest Board for official harvest calculation and recording.',
        ),
        accent: AppVisuals.lightGold,
      ),
    ];

    return _SectionCard(
      title: context.tr('Module Guide'),
      subtitle: context.tr(
        'Use this map when you know what you need to do, but not where to open it.',
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final tileWidth =
              wide ? (constraints.maxWidth - 12) / 2 : double.infinity;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: modules
                .map(
                  (module) => SizedBox(
                    width: tileWidth,
                    child: _ModuleTile(item: module),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildTips(BuildContext context) {
    final tips = [
      context.tr(
        'Use the refresh button inside the field workspace if records look outdated after a long session.',
      ),
      context.tr(
        'Use the search button in the field workspace header to find farms, activities, supplies, or equipment faster.',
      ),
      context.tr(
        'Change language, launch screen, backups, and restore tools from Settings.',
      ),
      context.tr(
        'Open Reports after logging activities and deliveries so the dashboard has enough data to summarize.',
      ),
    ];

    return _SectionCard(
      title: context.tr('Practical Tips'),
      subtitle: context.tr(
        'These habits make the app easier to trust in daily operations.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tips
            .map(
              (tip) => Padding(
                padding: EdgeInsets.only(bottom: tip == tips.last ? 0 : 10),
                child: _TipRow(text: tip),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.surface.withValues(alpha: 0.98),
            scheme.surfaceContainerHighest.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final _HelpStep step;

  const _StepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              step.number,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
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
                  step.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.55,
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

class _ModuleTile extends StatelessWidget {
  final _ModuleGuideItem item;

  const _ModuleTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: item.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppVisuals.textForest,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppVisuals.textForestMuted,
                    height: 1.55,
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

class _TipRow extends StatelessWidget {
  final String text;

  const _TipRow({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 7),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppVisuals.primaryGold,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppVisuals.textForestMuted,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppVisuals.warmOffWhite.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppVisuals.warmOffWhite.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppVisuals.warmOffWhite,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _HelpStep {
  final String number;
  final String title;
  final String body;

  const _HelpStep({
    required this.number,
    required this.title,
    required this.body,
  });
}

class _ModuleGuideItem {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  const _ModuleGuideItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });
}
