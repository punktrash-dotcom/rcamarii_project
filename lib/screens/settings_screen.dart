import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/guideline_language_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import '../services/factory_reset_service.dart';
import '../services/app_localization_service.dart';
import '../services/app_route_observer.dart';
import '../services/guideline_localization_service.dart';
import '../themes/app_visuals.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/user_access_dialogs.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'help_screen.dart';
import 'manage_categories_screen.dart';
import 'restore_screen.dart';
import 'splash_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with RouteAware {
  static const _seriousAudioPreviewAssetPath =
      'lib/assets/audio/serious_settings.mp3';
  static const _funnyAudioPreviewAssetPath =
      'lib/assets/audio/funny_settings.mp3';
  static const _englishLanguagePreviewAssetPath =
      'lib/assets/audio/english.mp3';
  static const _tagalogLanguagePreviewAssetPath =
      'lib/assets/audio/tagalog.mp3';
  static const _visayanLanguagePreviewAssetPath =
      'lib/assets/audio/visayan.mp3';
  int _audioPreviewRequestId = 0;
  bool _playedScreenOpenAudio = false;
  bool _isRouteObserverSubscribed = false;

  AppSettingsProvider? _appSettings;
  AppAudioProvider? _appAudio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playScreenOpenAudioIfNeeded();
    });
  }

  Future<void> _playScreenOpenAudioIfNeeded() async {
    if (!mounted || _playedScreenOpenAudio) {
      return;
    }
    final appSettings = _appSettings;
    final appAudio = _appAudio;
    if (appSettings == null || appAudio == null) {
      return;
    }
    _playedScreenOpenAudio = true;
    await appAudio.playScreenOpenSound(
      screenKey: 'settings',
      style: appSettings.audioSoundStyle,
      enabled: appSettings.audioSoundsEnabled,
    );
  }

  Future<void> _playAudioPreview(
    AppSettingsProvider appSettings, {
    required int requestId,
  }) async {
    if (!mounted || requestId != _audioPreviewRequestId) {
      return;
    }

    await context.read<AppAudioProvider>().playForStyle(
          style: appSettings.audioSoundStyle,
          seriousAssetPath: _seriousAudioPreviewAssetPath,
          funnyAssetPath: _funnyAudioPreviewAssetPath,
          enabled: appSettings.audioSoundsEnabled,
        );
  }

  String _languagePreviewAssetPath(GuidelineLanguage language) {
    switch (language) {
      case GuidelineLanguage.english:
        return _englishLanguagePreviewAssetPath;
      case GuidelineLanguage.tagalog:
        return _tagalogLanguagePreviewAssetPath;
      case GuidelineLanguage.visayan:
        return _visayanLanguagePreviewAssetPath;
    }
  }

  Future<void> _handleLanguageChanged(
    GuidelineLanguageProvider languageProvider,
    AppSettingsProvider appSettings,
    GuidelineLanguage language,
  ) async {
    await languageProvider.setLanguage(language);
    if (!mounted || !appSettings.audioSoundsEnabled) {
      return;
    }

    final requestId = ++_audioPreviewRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || requestId != _audioPreviewRequestId) {
        return;
      }
      unawaited(
        context.read<AppAudioProvider>().playAsset(
              assetPath: _languagePreviewAssetPath(language),
              enabled: appSettings.audioSoundsEnabled,
            ),
      );
    });
  }

  Future<void> _stopScreenAudioIfNeeded() async {
    final appSettings = _appSettings;
    final appAudio = _appAudio;
    if (appSettings == null || appAudio == null) {
      return;
    }
    await appAudio.stopScreenOpenSound(
      screenKey: 'settings',
      style: appSettings.audioSoundStyle,
    );
    await appAudio.stopForStyle(
      style: appSettings.audioSoundStyle,
      seriousAssetPath: _seriousAudioPreviewAssetPath,
      funnyAssetPath: _funnyAudioPreviewAssetPath,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _appSettings ??= Provider.of<AppSettingsProvider>(context, listen: false);
    _appAudio ??= Provider.of<AppAudioProvider>(context, listen: false);

    if (!_isRouteObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute<dynamic>) {
        appRouteObserver.subscribe(this, route);
        _isRouteObserverSubscribed = true;
      }
    }
  }

  void _scheduleAudioPreview(AppSettingsProvider appSettings) {
    final requestId = ++_audioPreviewRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !appSettings.audioSoundsEnabled) {
        return;
      }
      unawaited(
        _playAudioPreview(
          appSettings,
          requestId: requestId,
        ),
      );
    });
  }

  Future<void> _handleAudioSoundsChanged(
    AppSettingsProvider appSettings,
    bool value,
  ) async {
    final appAudio = _appAudio;
    await appSettings.setAudioSoundsEnabled(value);
    _audioPreviewRequestId++;
    if (!value) {
      if (appAudio != null) {
        unawaited(appAudio.stop());
      }
      return;
    }
    _scheduleAudioPreview(appSettings);
  }

  Future<void> _handleAudioSoundStyleChanged(
    AppSettingsProvider appSettings,
    AudioSoundStyle value,
  ) async {
    await appSettings.setAudioSoundStyle(value);
    if (appSettings.audioSoundsEnabled) {
      _scheduleAudioPreview(appSettings);
    }
  }

  Future<void> _editAccountAccess(AppSettingsProvider appSettings) async {
    if (appSettings.hasAppPassword) {
      final verified = await showPasswordVerificationDialog(
        context,
        expectedPassword: appSettings.appPassword,
        title: 'Verify password',
        message:
            'Enter your password to edit username and startup lock settings.',
      );
      if (!mounted || !verified) return;
    }

    final result = await showUserAccessEditDialog(
      context,
      initialName: appSettings.userName,
      initialAppLockEnabled: appSettings.appLockEnabled,
      initialPassword: appSettings.appPassword,
    );
    if (!mounted || result == null) return;

    await appSettings.updateUserAccess(
      userName: result.userName,
      appLockEnabled: result.appLockEnabled,
      password: result.password,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account access updated.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleStartupPasswordChanged(
    AppSettingsProvider appSettings,
    bool value,
  ) async {
    if (value) {
      if (!appSettings.hasAppPassword) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Set a password first before enabling startup lock.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _editAccountAccess(appSettings);
        return;
      }
      await appSettings.setAppLockEnabled(true);
    } else {
      await appSettings.setAppLockEnabled(false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Startup password enabled.' : 'Startup password disabled.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetToFactorySettings({
    required AppSettingsProvider appSettings,
    required ThemeProvider themeProvider,
    required GuidelineLanguageProvider languageProvider,
    required ProfileProvider profileProvider,
  }) async {
    final shouldReset = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Reset App?'),
            content: const Text(
              'Do you want to reset the app to factory settings? This will remove your saved data, account access settings, and app preferences.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Reset'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldReset || !mounted) {
      return;
    }

    await FactoryResetService.resetAppToFactorySettings();
    await Future.wait([
      appSettings.reload(),
      themeProvider.reload(),
      languageProvider.reload(),
      profileProvider.reload(),
    ]);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _audioPreviewRequestId++;
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    unawaited(_stopScreenAudioIfNeeded());
    super.dispose();
  }

  @override
  void didPushNext() {
    unawaited(_stopScreenAudioIfNeeded());
  }

  @override
  void didPop() {
    unawaited(_stopScreenAudioIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final languageProvider = Provider.of<GuidelineLanguageProvider>(context);
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final isDark = themeProvider.darkTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: scheme.onPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('Settings'),
          style: TextStyle(
            color: scheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: scheme.primary.withValues(alpha: 0.94),
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: AppBackdrop(
        isDark: isDark,
        backgroundImageAsset: 'lib/assets/images/background.png',
        backgroundImageOpacity: isDark ? 0.26 : 0.38,
        imageScrimColor: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : AppVisuals.softWhite.withValues(alpha: 0.08),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileCard(
                profileProvider: profileProvider,
                appSettings: appSettings,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: scheme.outline.withValues(alpha: 0.35)),
                  boxShadow: AppVisuals.neoShadows(scheme),
                ),
                child: Text(
                  appSettings.userName.isEmpty
                      ? context.tr('These preferences apply across RCAMARii.')
                      : 'These preferences apply across ${appSettings.userName}\'s RCAMARii workspace.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionLabel(context.tr('Workspace Controls')),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: scheme.outline.withValues(alpha: 0.35)),
                  boxShadow: AppVisuals.neoShadows(scheme),
                ),
                child: Text(
                  context.tr(
                    'Choose the preferred language for supply guidance before opening the field modules.',
                  ),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildSettingsGroup(
                [
                  _buildLanguageSelector(
                    context,
                    languageProvider,
                    appSettings,
                    isDark,
                  ),
                  _buildDropdownTile<LaunchDestination>(
                    icon: Icons.rocket_launch_rounded,
                    iconColor: AppVisuals.accentChartBlue,
                    title: context.tr('Launch Screen'),
                    value: appSettings.launchDestination,
                    isDark: isDark,
                    items: LaunchDestination.values
                        .map(
                          (destination) => DropdownMenuItem(
                            value: destination,
                            child: Text(context.tr(destination.label)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        appSettings.setLaunchDestination(value);
                      }
                    },
                  ),
                ],
                isDark,
              ),
              const SizedBox(height: 24),
              _buildSectionLabel(context.tr('APP PREFERENCES')),
              const SizedBox(height: 8),
              _buildSettingsGroup(
                [
                  _buildSettingsTile(
                    icon: Icons.folder_open,
                    iconColor: AppVisuals.primaryGoldDim,
                    title: context.tr('Manage Categories'),
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageCategoriesScreen(),
                      ),
                    ),
                  ),
                ],
                isDark,
              ),
              const SizedBox(height: 24),
              _buildSectionLabel(context.tr('FINANCE')),
              const SizedBox(height: 8),
              _buildSettingsGroup(
                [
                  _buildDropdownTile<AppCurrency>(
                    icon: Icons.payments_rounded,
                    iconColor: AppVisuals.primaryGold,
                    title: context.tr('Currency'),
                    value: appSettings.currency,
                    isDark: isDark,
                    items: AppCurrency.values
                        .map(
                          (currency) => DropdownMenuItem(
                            value: currency,
                            child: Text(
                              '${currency.symbol} ${context.tr(currency.label)}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        appSettings.setCurrency(value);
                      }
                    },
                  ),
                ],
                isDark,
              ),
              const SizedBox(height: 24),
              _buildSectionLabel(context.tr('APPEARANCE')),
              const SizedBox(height: 8),
              _buildSettingsGroup(
                [
                  _buildSwitchTile(
                    icon: Icons.dark_mode_outlined,
                    iconColor: AppVisuals.primaryGoldDim,
                    title: context.tr('Dark Mode'),
                    value: themeProvider.darkTheme,
                    isDark: isDark,
                    onChanged: (value) => themeProvider.darkTheme = value,
                  ),
                  _buildSwitchTile(
                    icon: Icons.motion_photos_off_rounded,
                    iconColor: AppVisuals.mintAccent,
                    title: context.tr('Reduced Motion'),
                    value: appSettings.reducedMotion,
                    isDark: isDark,
                    onChanged: (value) => appSettings.setReducedMotion(value),
                  ),
                ],
                isDark,
              ),
              const SizedBox(height: 24),
              _buildSectionLabel(context.tr('VOICE & ASSISTANCE')),
              const SizedBox(height: 8),
              _buildSettingsGroup(
                [
                  _buildSwitchTile(
                    icon: Icons.mic_rounded,
                    iconColor: scheme.error,
                    title: context.tr('Voice Assistant'),
                    value: appSettings.voiceAssistantEnabled,
                    isDark: isDark,
                    onChanged: (value) =>
                        appSettings.setVoiceAssistantEnabled(value),
                  ),
                  _buildSwitchTile(
                    icon: Icons.volume_up_rounded,
                    iconColor: AppVisuals.growthGreen,
                    title: context.tr('Spoken Responses'),
                    value: appSettings.voiceResponsesEnabled,
                    isDark: isDark,
                    onChanged: appSettings.voiceAssistantEnabled
                        ? (value) => appSettings.setVoiceResponsesEnabled(value)
                        : null,
                  ),
                  _buildSwitchTile(
                    icon: Icons.music_note_rounded,
                    iconColor: AppVisuals.primaryGold,
                    title: context.tr('Audio Sounds'),
                    value: appSettings.audioSoundsEnabled,
                    isDark: isDark,
                    onChanged: (value) =>
                        _handleAudioSoundsChanged(appSettings, value),
                  ),
                  _buildAudioStyleTile(
                    context: context,
                    appSettings: appSettings,
                    isDark: isDark,
                  ),
                  _buildVolumeTile(
                    context: context,
                    appSettings: appSettings,
                    isDark: isDark,
                  ),
                ],
                isDark,
              ),
              const SizedBox(height: 24),
              _buildSectionLabel(context.tr('WEATHER')),
              const SizedBox(height: 8),
              _buildSettingsGroup(
                [
                  _buildSwitchTile(
                    icon: Icons.cloud_sync_rounded,
                    iconColor: AppVisuals.accentChartBlue,
                    title: context.tr('Auto Refresh Weather'),
                    value: appSettings.weatherAutoRefresh,
                    isDark: isDark,
                    onChanged: (value) =>
                        appSettings.setWeatherAutoRefresh(value),
                  ),
                ],
                isDark,
              ),
              const SizedBox(height: 24),
              _buildSectionLabel(context.tr('DATA MANAGEMENT')),
              const SizedBox(height: 8),
              _buildSettingsGroup(
                [
                  _buildSettingsTile(
                    icon: Icons.download,
                    iconColor: AppVisuals.accentChartBlue,
                    title: context.tr('Backup Data'),
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BackupScreen(),
                      ),
                    ),
                  ),
                  _buildSettingsTile(
                    icon: Icons.upload,
                    iconColor: AppVisuals.growthGreen,
                    title: context.tr('Restore Data'),
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RestoreScreen(),
                      ),
                    ),
                  ),
                  _buildSettingsTile(
                    icon: Icons.restart_alt_rounded,
                    iconColor: scheme.error,
                    title: context.tr('Reset to Factory Settings'),
                    isDark: isDark,
                    onTap: () => _resetToFactorySettings(
                      appSettings: appSettings,
                      themeProvider: themeProvider,
                      languageProvider: languageProvider,
                      profileProvider: profileProvider,
                    ),
                  ),
                ],
                isDark,
              ),
              const SizedBox(height: 24),
              _buildSectionLabel(context.tr('ABOUT')),
              const SizedBox(height: 8),
              _buildSettingsGroup(
                [
                  _buildSettingsTile(
                    icon: Icons.help_outline_rounded,
                    iconColor: AppVisuals.accentChartBlue,
                    title: context.tr('Help Center'),
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpScreen(),
                      ),
                    ),
                  ),
                  _buildSettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppVisuals.mintAccent,
                    title: context.tr('About RCAMARii'),
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutScreen(),
                      ),
                    ),
                  ),
                ],
                isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Text(
          text,
          style: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            fontSize: 12,
          ),
        );
      },
    );
  }

  Widget _buildProfileCard({
    required ProfileProvider profileProvider,
    required AppSettingsProvider appSettings,
    required bool isDark,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final displayName = appSettings.userName.isNotEmpty
        ? appSettings.userName
        : profileProvider.userName;
    final accessLabel = appSettings.appLockEnabled
        ? 'Startup password enabled'
        : 'Startup password disabled';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
        boxShadow: AppVisuals.neoShadows(scheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Account Access',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                  color: scheme.primary,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _editAccountAccess(appSettings),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: scheme.primary.withValues(alpha: 0.22),
                backgroundImage: profileProvider.imagePath != null
                    ? FileImage(File(profileProvider.imagePath!))
                    : null,
                child: profileProvider.imagePath == null
                    ? Icon(Icons.person, color: scheme.primary, size: 30)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      accessLabel,
                      style: TextStyle(
                        color: scheme.secondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(
            height: 1,
            color: scheme.outline.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: scheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Require password on startup',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appSettings.hasAppPassword
                          ? 'Ask for your saved password before opening the dashboard.'
                          : 'Set a password in Edit to turn startup lock on.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: appSettings.appLockEnabled,
                onChanged: (value) =>
                    _handleStartupPasswordChanged(appSettings, value),
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return scheme.primary;
                  }
                  return scheme.onSurfaceVariant;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return scheme.primary.withValues(alpha: 0.4);
                  }
                  return scheme.outline.withValues(alpha: 0.45);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children, bool isDark) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(
          Divider(
            height: 1,
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
          ),
        );
      }
      items.add(children[i]);
    }

    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
        boxShadow: AppVisuals.neoShadows(scheme),
      ),
      child: Column(children: items),
    );
  }

  Widget _buildLanguageSelector(
    BuildContext context,
    GuidelineLanguageProvider languageProvider,
    AppSettingsProvider appSettings,
    bool isDark,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.language_rounded, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  context.tr('Language'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: GuidelineLanguage.values.map((language) {
              final selected = languageProvider.selectedLanguage == language;
              return ChoiceChip(
                label: Text(
                  GuidelineLocalizationService.languageLabel(language),
                ),
                selected: selected,
                onSelected: (isSelected) {
                  if (!isSelected) {
                    return;
                  }
                  _handleLanguageChanged(
                    languageProvider,
                    appSettings,
                    language,
                  );
                },
                showCheckmark: false,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile<T>({
    required IconData icon,
    required Color iconColor,
    required String title,
    required T value,
    required bool isDark,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: SearchableDropdownButton<T>(
              value: value,
              style: TextStyle(
                color: scheme.onSurface,
              ),
              items: items,
              hintText: title,
              enabled: true,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required bool isDark,
    required ValueChanged<bool>? onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return scheme.primary;
              }
              return scheme.onSurfaceVariant;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return scheme.primary.withValues(alpha: 0.4);
              }
              return scheme.outline.withValues(alpha: 0.45);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeTile({
    required BuildContext context,
    required AppSettingsProvider appSettings,
    required bool isDark,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = appSettings.audioSoundsEnabled ||
        (appSettings.voiceAssistantEnabled &&
            appSettings.voiceResponsesEnabled);

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.volume_down_rounded,
                    size: 20, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('Sound Level Normalization'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                  ),
                ),
                Text(
                  '${(appSettings.audioSoundsVolume * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppVisuals.primaryGold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: AppVisuals.primaryGold,
                inactiveTrackColor:
                    AppVisuals.primaryGold.withValues(alpha: 0.1),
                thumbColor: AppVisuals.primaryGold,
              ),
              child: Slider(
                value: appSettings.audioSoundsVolume,
                onChanged: enabled
                    ? (value) => appSettings.setAudioSoundsVolume(value)
                    : null,
                min: 0.1,
                max: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioStyleTile({
    required BuildContext context,
    required AppSettingsProvider appSettings,
    required bool isDark,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = appSettings.audioSoundsEnabled;
    final textColor =
        enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.38);

    Widget buildOption(AudioSoundStyle style) {
      return Expanded(
        child: InkWell(
          onTap: enabled
              ? () => _handleAudioSoundStyleChanged(appSettings, style)
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Radio<AudioSoundStyle>(value: style),
              Flexible(
                child: Text(
                  context.tr(style.label),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Sound Style'),
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          RadioGroup<AudioSoundStyle>(
            groupValue: appSettings.audioSoundStyle,
            onChanged: (value) {
              if (!enabled || value == null) {
                return;
              }
              _handleAudioSoundStyleChanged(appSettings, value);
            },
            child: Row(
              children: [
                buildOption(AudioSoundStyle.serious),
                buildOption(AudioSoundStyle.funny),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
