import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/ftracker_model.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/ftracker_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/voice_command_provider.dart';
import '../services/app_localization_service.dart';
import '../services/app_route_observer.dart';
import '../themes/custom_themes.dart';
import 'scr_new_transaction.dart';
import 'charts_screen.dart';

class ScrTracker extends StatefulWidget {
  const ScrTracker({super.key});

  @override
  State<ScrTracker> createState() => _ScrTrackerState();
}

class _ScrTrackerState extends State<ScrTracker> with RouteAware {
  int _selectedIndex = 0;
  bool _playedScreenOpenAudio = false;
  bool _isRouteObserverSubscribed = false;

  @override
  void initState() {
    super.initState();
    // Fixed: Use addPostFrameCallback to avoid calling notifyListeners during build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<FtrackerProvider>(context, listen: false)
            .loadFtrackerRecords();
        _playScreenOpenAudioIfNeeded();
      }
    });
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex && index != 2) return;

    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      if (index == 1) {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const ChartsScreen()));
      } else if (index == 2) {
        // Return to Operational Hub
        Navigator.of(context).pop();
      } else {
        setState(() {
          _selectedIndex = index;
        });
      }
    });
  }

  void _showEditProfileDialog() {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final nameController =
        TextEditingController(text: profileProvider.userName);
    String? tempImagePath = profileProvider.imagePath;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = themeProvider.darkTheme;
            return AlertDialog(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              title: Text(context.tr('Edit Profile'),
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        FilePickerResult? result = await FilePicker.platform
                            .pickFiles(type: FileType.image);
                        if (result != null) {
                          setDialogState(() {
                            tempImagePath = result.files.single.path;
                          });
                        }
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.deepPurple,
                        backgroundImage: tempImagePath != null
                            ? FileImage(File(tempImagePath!))
                            : null,
                        child: tempImagePath == null
                            ? const Icon(Icons.camera_alt,
                                color: Colors.white, size: 30)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      stylusHandwritingEnabled: false,
                      controller: nameController,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: context.tr('Wallet Name'),
                        labelStyle: TextStyle(
                            color: isDark ? Colors.grey : Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Cancel'),
                      style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    profileProvider.updateProfile(
                        nameController.text, tempImagePath);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple),
                  child: Text(
                    context.tr('Save'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _playScreenOpenAudioIfNeeded() async {
    if (!mounted || _playedScreenOpenAudio) {
      return;
    }
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    _playedScreenOpenAudio = true;
    await context.read<AppAudioProvider>().playScreenOpenSound(
          screenKey: 'ftracker',
          style: appSettings.audioSoundStyle,
          enabled: appSettings.audioSoundsEnabled,
        );
  }

  Future<void> _stopScreenOpenAudioIfNeeded() async {
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    await context.read<AppAudioProvider>().stopScreenOpenSound(
          screenKey: 'ftracker',
          style: appSettings.audioSoundStyle,
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
  void dispose() {
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    unawaited(_stopScreenOpenAudioIfNeeded());
    super.dispose();
  }

  @override
  void didPushNext() {
    unawaited(_stopScreenOpenAudioIfNeeded());
  }

  @override
  void didPop() {
    unawaited(_stopScreenOpenAudioIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final trackerTheme = CustomThemes.tracker(baseTheme);
    return Theme(
      data: trackerTheme,
      child: Builder(builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final appSettings = Provider.of<AppSettingsProvider>(context);
        final legacyCurrencyFormat =
            NumberFormat.currency(locale: 'en_PH', symbol: '₱');
        assert(legacyCurrencyFormat.currencySymbol.isNotEmpty);
        final currencyFormat = appSettings.currencyFormat;
        final profileProvider = Provider.of<ProfileProvider>(context);
        final voiceProvider =
            Provider.of<VoiceCommandProvider>(context, listen: false);

        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            toolbarHeight: 80,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: colorScheme.onSurface, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: context.tr('Back to Hub'),
            ),
            title: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: colorScheme.primary,
                  backgroundImage: profileProvider.imagePath != null
                      ? FileImage(File(profileProvider.imagePath!))
                      : null,
                  child: profileProvider.imagePath == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('Good Afternoon,'),
                          style: TextStyle(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 14)),
                      Text(profileProvider.userName,
                          style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (appSettings.voiceAssistantEnabled)
                IconButton(
                  onPressed: () => voiceProvider.requestCommand(context),
                  icon: Icon(Icons.mic, color: colorScheme.onSurface),
                  tooltip: context.tr('Voice command'),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: GestureDetector(
                  onTap: _showEditProfileDialog,
                  child: Icon(Icons.edit_note,
                      color: colorScheme.onSurface, size: 30),
                ),
              ),
            ],
          ),
          body: Consumer<FtrackerProvider>(
            builder: (context, ftrackerProvider, child) {
              if (ftrackerProvider.isLoading &&
                  ftrackerProvider.records.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final sortedRecords = List.of(ftrackerProvider.records);
              sortedRecords.sort((a, b) {
                final dateComparison = b.date.compareTo(a.date);
                if (dateComparison != 0) return dateComparison;
                final bId = b.transid ?? 0;
                final aId = a.transid ?? 0;
                return bId.compareTo(aId);
              });
              final totalRevenue = sortedRecords
                  .where(_isIncomeRecord)
                  .fold(0.0, (sum, item) => sum + item.amount);
              final totalExpenses = sortedRecords
                  .where(_isExpenseRecord)
                  .fold(0.0, (sum, item) => sum + item.amount);
              final totalBalance = totalRevenue - totalExpenses;
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBalanceCard(totalBalance, totalRevenue,
                              totalExpenses, currencyFormat, colorScheme),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(context.tr('Recent Transactions'),
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface)),
                              IconButton(
                                icon: Icon(Icons.refresh,
                                    color: colorScheme.onSurface),
                                onPressed: () {
                                  Provider.of<FtrackerProvider>(context,
                                          listen: false)
                                      .loadFtrackerRecords();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final record = sortedRecords[index];
                        return _buildTransactionTile(
                            record,
                            _isExpenseRecord(record),
                            currencyFormat,
                            colorScheme);
                      },
                      childCount: min(sortedRecords.length, 10),
                    ),
                  ),
                ],
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ScrNewTransaction())),
            child: const Icon(Icons.add),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: Container(
            height: 70,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10)
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _buildBottomNavItem(
                    icon: Icons.home,
                    label: context.tr('Home'),
                    index: 0,
                    scheme: colorScheme),
                _buildBottomNavItem(
                    icon: Icons.analytics,
                    label: context.tr('Analytics'),
                    index: 1,
                    scheme: colorScheme),
                const SizedBox(width: 40),
                _buildBottomNavItem(
                    icon: Icons.hub_rounded,
                    label: context.tr('Hub'),
                    index: 2,
                    scheme: colorScheme),
              ],
            ),
          ),
        );
      }),
    );
  }

  bool _isIncomeRecord(Ftracker record) {
    final normalizedType = record.type.toLowerCase().trim();
    return normalizedType.contains('income') ||
        normalizedType.contains('revenue');
  }

  bool _isExpenseRecord(Ftracker record) {
    final normalizedType = record.type.toLowerCase().trim();
    return normalizedType.contains('expens');
  }

  Widget _buildBalanceCard(double balance, double income, double expense,
      NumberFormat format, ColorScheme colors) {
    return FractionallySizedBox(
      widthFactor: 1,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              colors.primary.withValues(alpha: 0.0),
              colors.primary.withValues(alpha: 0.0)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
                color: colors.primary.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(context.tr('Total Balance'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            Builder(builder: (context) {
              final balanceText = format.format(balance);
              final displayBalance = balanceText.endsWith('.00')
                  ? balanceText.substring(0, balanceText.length - 3)
                  : balanceText;
              return Text(displayBalance,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold));
            }),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildTrendBadge(context.tr('Income'),
                    _formatCurrency(format, income), Colors.greenAccent),
                _buildTrendBadge(context.tr('Expenses'),
                    _formatCurrency(format, expense), Colors.redAccent),
                _buildTrendBadge(context.tr('Net'),
                    _formatCurrency(format, balance), Colors.white70,
                    highlight: false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendBadge(String label, String amount, Color bgColor,
      {bool highlight = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? bgColor.withValues(alpha: 0.35)
            : bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: highlight ? bgColor.withValues(alpha: 0.6) : Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: highlight ? Colors.white70 : Colors.white60,
                  fontSize: 10)),
          Text(amount,
              style: TextStyle(
                  color: highlight ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(
      dynamic record, bool isExpense, NumberFormat format, ColorScheme colors) {
    final accent = isExpense ? Colors.redAccent : Colors.greenAccent;
    const tileTextColor = Colors.tealAccent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.25),
              accent.withValues(alpha: 0.1),
              colors.surface.withValues(alpha: 0.95)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8))
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: tileTextColor.withValues(alpha: 0.2),
            child: const Icon(Icons.category, color: tileTextColor),
          ),
          title: Text(record.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: tileTextColor)),
          subtitle: Text(
              '${record.category} | ${DateFormat('MMM dd, yyyy').format(record.date)}',
              style: TextStyle(
                  color: tileTextColor.withValues(alpha: 0.8), fontSize: 12)),
          trailing: Text(
            (isExpense ? '- ' : '+ ') + format.format(record.amount),
            style: TextStyle(
                color: isExpense ? Colors.redAccent : Colors.greenAccent,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(NumberFormat format, double value) {
    final formatted = format.format(value);
    final dotIndex = formatted.lastIndexOf('.');
    if (dotIndex == -1) return formatted;
    final integerPart = formatted.substring(0, dotIndex);
    final decimalPart = formatted.substring(dotIndex + 1);
    final trimmedDecimal = decimalPart.replaceFirst(RegExp(r'0+$'), '');
    if (trimmedDecimal.isEmpty) return integerPart;
    return '$integerPart.$trimmedDecimal';
  }

  Widget _buildBottomNavItem(
      {required IconData icon,
      required String label,
      required int index,
      required ColorScheme scheme}) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected
                    ? scheme.secondary
                    : scheme.onSurface.withValues(alpha: 0.6),
                size: 24),
            Text(label,
                style: TextStyle(
                    color: isSelected
                        ? scheme.secondary
                        : scheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
