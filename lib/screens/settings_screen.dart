import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/guideline_language_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import '../services/app_localization_service.dart';
import '../services/app_route_observer.dart';
import '../services/guideline_localization_service.dart';
import '../widgets/searchable_dropdown.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'manage_categories_screen.dart';
import 'restore_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with RouteAware {
  static const _seriousAudioPreviewAssetPath = 'lib/assets/audio/sunshine.mp3';
  static const _funnyAudioPreviewAssetPath = 'lib/assets/audio/anak.mp3';
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
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: scheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('Settings'),
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(profileProvider, isDark),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                context.tr('These preferences apply across RCAMARii.'),
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionLabel(context.tr('APP PREFERENCES')),
            const SizedBox(height: 8),
            _buildSettingsGroup(
              [
                _buildLanguageSelector(
                  context,
                  languageProvider,
                  isDark,
                ),
                _buildDropdownTile<LaunchDestination>(
                  icon: Icons.rocket_launch_rounded,
                  iconColor: Colors.lightBlue,
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
                _buildSettingsTile(
                  icon: Icons.folder_open,
                  iconColor: Colors.orange,
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
                  iconColor: Colors.amber.shade700,
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
                  iconColor: Colors.purple,
                  title: context.tr('Dark Mode'),
                  value: themeProvider.darkTheme,
                  isDark: isDark,
                  onChanged: (value) => themeProvider.darkTheme = value,
                ),
                _buildSwitchTile(
                  icon: Icons.motion_photos_off_rounded,
                  iconColor: Colors.teal,
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
                  iconColor: Colors.redAccent,
                  title: context.tr('Voice Assistant'),
                  value: appSettings.voiceAssistantEnabled,
                  isDark: isDark,
                  onChanged: (value) =>
                      appSettings.setVoiceAssistantEnabled(value),
                ),
                _buildSwitchTile(
                  icon: Icons.volume_up_rounded,
                  iconColor: Colors.green,
                  title: context.tr('Spoken Responses'),
                  value: appSettings.voiceResponsesEnabled,
                  isDark: isDark,
                  onChanged: appSettings.voiceAssistantEnabled
                      ? (value) => appSettings.setVoiceResponsesEnabled(value)
                      : null,
                ),
                _buildSwitchTile(
                  icon: Icons.music_note_rounded,
                  iconColor: Colors.orangeAccent,
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
                  iconColor: Colors.lightBlueAccent,
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
                  iconColor: Colors.blue,
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
                  iconColor: Colors.green,
                  title: context.tr('Restore Data'),
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RestoreScreen(),
                    ),
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
                  icon: Icons.info_outline_rounded,
                  iconColor: Colors.teal,
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
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.grey,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildProfileCard(ProfileProvider profile, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.deepPurple,
            backgroundImage: profile.imagePath != null
                ? FileImage(File(profile.imagePath!))
                : null,
            child: profile.imagePath == null
                ? const Icon(Icons.person, color: Colors.white, size: 30)
                : null,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.userName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Text(
                'premium_user',
                style: TextStyle(color: Colors.deepPurple, fontSize: 14),
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
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        );
      }
      items.add(children[i]);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: items),
    );
  }

  Widget _buildLanguageSelector(
    BuildContext context,
    GuidelineLanguageProvider languageProvider,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.language_rounded, color: Colors.blueAccent),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  context.tr('Language'),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
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
                onSelected: (_) => languageProvider.setLanguage(language),
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
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: SearchableDropdownButton<T>(
              value: value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
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
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.deepPurple,
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
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            if (trailing != null) trailing,
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
    final enabled = appSettings.audioSoundsEnabled;
    final textColor = enabled
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.white38 : Colors.black38);

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
