import 'package:flutter/material.dart';

import '../themes/app_visuals.dart';
import '../utils/app_layout_utils.dart';

class ModernScreenShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? actionBadge;
  final EdgeInsetsGeometry outerPadding;
  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry bodyPadding;
  final double headerGap;
  final double titleGap;
  final Widget? headerTopContent;
  final double headerTopContentGap;

  const ModernScreenShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionBadge,
    this.subtitleStyleOverride,
    this.titleStyleOverride,
    this.outerPadding = const EdgeInsets.fromLTRB(16, 14, 16, 12),
    this.headerPadding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
    this.bodyPadding = const EdgeInsets.symmetric(vertical: 10),
    this.headerGap = 14,
    this.titleGap = 14,
    this.headerTopContent,
    this.headerTopContentGap = 12,
  });

  final TextStyle? titleStyleOverride;
  final TextStyle? subtitleStyleOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    return AppBackdrop(
      isDark: isDark,
      child: SafeArea(
        child: Padding(
          padding: outerPadding,
          child: Column(
            children: [
              FrostedPanel(
                radius: 30,
                color: isDark
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.92)
                    : AppVisuals.cloudGlass.withValues(alpha: 0.9),
                padding: headerPadding,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final shouldStack = AppLayoutUtils.shouldStackHeader(
                          context,
                          widthBreakpoint: 560,
                          scaleBreakpoint: 1.08,
                        ) ||
                        constraints.maxWidth < 520;
                    final headerActions = <Widget>[
                      if (actionBadge != null) actionBadge!,
                    ];

                    if (shouldStack) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderText(theme, scheme),
                          if (headerActions.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: headerActions,
                            ),
                          ],
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildHeaderText(theme, scheme),
                        ),
                        if (headerActions.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Flexible(
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: headerActions,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: headerGap),
              Expanded(
                child: FrostedPanel(
                  radius: 34,
                  padding: bodyPadding,
                  color: isDark
                      ? scheme.surface.withValues(alpha: 0.78)
                      : AppVisuals.cloudGlass.withValues(alpha: 0.84),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderText(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (headerTopContent != null) ...[
          headerTopContent!,
          SizedBox(height: headerTopContentGap),
        ],
        if (subtitle.trim().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              subtitle.toUpperCase(),
              style: _buildSubtitleStyle(theme),
            ),
          ),
          SizedBox(height: titleGap),
        ],
        Text(
          title,
          style: _buildTitleStyle(theme),
        ),
      ],
    );
  }

  TextStyle? _buildSubtitleStyle(ThemeData theme) {
    final base = theme.textTheme.bodySmall?.copyWith(
      letterSpacing: 1.2,
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onPrimary.withValues(alpha: 0.84),
    );
    if (subtitleStyleOverride != null) {
      return base?.merge(subtitleStyleOverride) ?? subtitleStyleOverride;
    }
    return base;
  }

  TextStyle? _buildTitleStyle(ThemeData theme) {
    final base = theme.textTheme.displayMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: theme.colorScheme.onSurface,
    );
    if (titleStyleOverride != null) {
      return base?.merge(titleStyleOverride) ?? titleStyleOverride;
    }
    return base;
  }
}
