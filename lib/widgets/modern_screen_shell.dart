import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';
import '../providers/voice_command_provider.dart';
import '../themes/app_visuals.dart';

class ModernScreenShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onVoiceCommand;
  final Widget? actionBadge;
  final bool showVoiceButton;
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
    this.onVoiceCommand,
    this.actionBadge,
    this.showVoiceButton = false,
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
    final appSettings = Provider.of<AppSettingsProvider>(context);

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
                    ? AppVisuals.deepAnthracite.withValues(alpha: 0.94)
                    : AppVisuals.forestEmerald.withValues(alpha: 0.92),
                padding: headerPadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
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
                                color: scheme.secondary.withValues(alpha: 0.24),
                                borderRadius: BorderRadius.circular(999),
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
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (actionBadge != null) actionBadge!,
                          if (showVoiceButton &&
                              appSettings.voiceAssistantEnabled)
                            _buildVoiceAction(context, theme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: headerGap),
              Expanded(
                child: FrostedPanel(
                  radius: 34,
                  padding: bodyPadding,
                  color: scheme.surface.withValues(alpha: isDark ? 0.88 : 0.92),
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

  Widget _buildVoiceAction(BuildContext context, ThemeData theme) {
    final voiceProvider =
        Provider.of<VoiceCommandProvider>(context, listen: false);
    return FilledButton.tonalIcon(
      onPressed: onVoiceCommand ?? () => voiceProvider.requestCommand(context),
      icon: const Icon(Icons.mic, size: 18),
      label: const Text('Voice'),
      style: FilledButton.styleFrom(
        foregroundColor: theme.colorScheme.onSecondary,
        backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.88),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  TextStyle? _buildSubtitleStyle(ThemeData theme) {
    final base = theme.textTheme.bodySmall?.copyWith(
      letterSpacing: 1.2,
      fontWeight: FontWeight.w800,
      color: AppVisuals.warmOffWhite.withValues(alpha: 0.8),
    );
    if (subtitleStyleOverride != null) {
      return base?.merge(subtitleStyleOverride) ?? subtitleStyleOverride;
    }
    return base;
  }

  TextStyle? _buildTitleStyle(ThemeData theme) {
    final base = theme.textTheme.displayMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: AppVisuals.warmOffWhite,
    );
    if (titleStyleOverride != null) {
      return base?.merge(titleStyleOverride) ?? titleStyleOverride;
    }
    return base;
  }
}
