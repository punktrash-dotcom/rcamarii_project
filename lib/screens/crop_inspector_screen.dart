import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/crop_inspector_scan_model.dart';
import '../models/farm_model.dart';
import '../providers/farm_provider.dart';
import '../services/crop_inspector_history_service.dart';
import '../services/crop_inspector_service.dart';
import '../services/crop_inspector_sync_service.dart';
import '../services/sugarcane_asset_service.dart';
import '../themes/app_visuals.dart';

class CropInspectorScreen extends StatefulWidget {
  const CropInspectorScreen({
    super.key,
    this.initialFarm,
  });

  final Farm? initialFarm;

  @override
  State<CropInspectorScreen> createState() => _CropInspectorScreenState();
}

class _CropInspectorScreenState extends State<CropInspectorScreen> {
  final ImagePicker _picker = ImagePicker();
  final CropInspectorHistoryService _history =
      CropInspectorHistoryService.instance;
  final CropInspectorSyncService _syncService =
      CropInspectorSyncService.instance;
  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _ageDaysController = TextEditingController();
  final TextEditingController _backendUrlController = TextEditingController();

  String _selectedCropType = 'Sugarcane';
  XFile? _selectedImage;
  CropInspectorDiagnosis? _diagnosis;
  List<CropInspectorScanRecord> _historyItems = const [];
  bool _historyLoading = true;
  bool _isAnalyzing = false;
  bool _isSyncing = false;
  bool _backendEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialFarm = widget.initialFarm;
    if (initialFarm != null) {
      _applyFarm(initialFarm);
    } else {
      _farmNameController.text = 'General crop scan';
      _ageDaysController.text = '0';
    }
    _loadSettingsAndHistory();
  }

  @override
  void dispose() {
    _farmNameController.dispose();
    _ageDaysController.dispose();
    _backendUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndHistory() async {
    final enabled = await _syncService.isBackendEnabled();
    final url = await _syncService.backendUrl();
    final history = await _history.fetchRecentScans();
    if (!mounted) {
      return;
    }
    setState(() {
      _backendEnabled = enabled;
      _backendUrlController.text = url;
      _historyItems = history;
      _historyLoading = false;
    });
  }

  void _applyFarm(Farm farm) {
    _farmNameController.text = farm.name;
    _selectedCropType = _normalizedCropType(farm.type);
    _ageDaysController.text =
        DateTime.now().difference(farm.date).inDays.clamp(0, 9999).toString();
  }

  String _normalizedCropType(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized.contains('sugar')) {
      return 'Sugarcane';
    }
    if (normalized.contains('rice') || normalized.contains('palay')) {
      return 'Rice';
    }
    if (normalized.contains('corn') || normalized.contains('maize')) {
      return 'Corn';
    }
    return 'Sugarcane';
  }

  int get _currentAgeInDays =>
      int.tryParse(_ageDaysController.text.trim())?.clamp(0, 9999) ?? 0;

  int get _pendingHistoryCount => _historyItems
      .where((item) =>
          item.syncStatus == CropInspectorSyncStatus.pending ||
          item.syncStatus == CropInspectorSyncStatus.failed)
      .length;

  Future<void> _pickAndAnalyze(ImageSource source) async {
    setState(() {
      _error = null;
    });

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2200,
      );
      if (!mounted || image == null) {
        return;
      }

      setState(() {
        _selectedImage = image;
        _diagnosis = null;
        _isAnalyzing = true;
      });

      final diagnosis = await CropInspectorService.diagnose(
        imagePath: image.path,
        cropType: _selectedCropType,
        ageInDays: _currentAgeInDays,
        farmName: _farmNameController.text.trim().isEmpty
            ? 'General crop scan'
            : _farmNameController.text.trim(),
      );

      final initialSyncStatus = await _syncService.canSync()
          ? CropInspectorSyncStatus.pending
          : CropInspectorSyncStatus.localOnly;
      final record = await _history.saveScan(
        diagnosis,
        syncStatus: initialSyncStatus,
      );

      if (await _syncService.canSync()) {
        try {
          await _syncService.syncRecord(record);
        } catch (error) {
          if (record.id != null) {
            await _history.updateSyncState(
              record.id!,
              syncStatus: CropInspectorSyncStatus.failed,
              syncError: error.toString(),
            );
          }
        }
      }

      final history = await _history.fetchRecentScans();
      if (!mounted) {
        return;
      }

      setState(() {
        _diagnosis = diagnosis;
        _historyItems = history;
        _isAnalyzing = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAnalyzing = false;
        _error = 'Unable to inspect the selected image right now.';
      });
    }
  }

  Future<void> _saveSyncSettings() async {
    await _syncService.setBackendEnabled(_backendEnabled);
    await _syncService.setBackendUrl(_backendUrlController.text.trim());
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crop inspector sync settings saved.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _syncPending() async {
    setState(() {
      _isSyncing = true;
      _error = null;
    });
    try {
      final syncedCount = await _syncService.syncPendingRecords();
      final history = await _history.fetchRecentScans();
      if (!mounted) {
        return;
      }
      setState(() {
        _historyItems = history;
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced $syncedCount crop inspector record(s).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSyncing = false;
        _error = 'Unable to sync crop inspector history right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedFarm = context.watch<FarmProvider>().selectedFarm;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Inspector'),
      ),
      body: AppBackdrop(
        isDark: theme.brightness == Brightness.dark,
        backgroundImageAsset: SugarcaneAssetService.healthyAssetForMonth(6),
        backgroundImageOpacity:
            theme.brightness == Brightness.dark ? 0.14 : 0.1,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIntro(theme),
                const SizedBox(height: 16),
                _buildSetup(theme, selectedFarm),
                if (_selectedImage != null) ...[
                  const SizedBox(height: 16),
                  _buildSelectedImage(theme),
                ],
                if (_isAnalyzing) ...[
                  const SizedBox(height: 16),
                  _buildProgress(),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _buildError(theme),
                ],
                if (_diagnosis != null) ...[
                  const SizedBox(height: 16),
                  _buildDiagnosis(theme),
                ],
                const SizedBox(height: 16),
                _buildHistory(theme),
                const SizedBox(height: 16),
                _buildSyncSection(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(ThemeData theme) {
    return FrostedPanel(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'On-Device Crop Inspector',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppVisuals.primaryGold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Inspect a crop image with on-device TensorFlow Lite inference when the local model is installed, store the result in the phone database, and optionally sync records to a backend for dataset growth and future retraining.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppVisuals.textForestMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InspectorBadge(
                label: 'Offline diagnosis',
                color: AppVisuals.brandGreen,
                icon: Icons.offline_bolt_rounded,
              ),
              _InspectorBadge(
                label: 'Local scan history',
                color: AppVisuals.brandBlue,
                icon: Icons.history_rounded,
              ),
              _InspectorBadge(
                label: _backendEnabled ? 'Sync enabled' : 'Sync optional',
                color: AppVisuals.primaryGold,
                icon: Icons.cloud_sync_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetup(ThemeData theme, Farm? selectedFarm) {
    return FrostedPanel(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan Setup',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.primaryGold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (selectedFarm != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.tonalIcon(
                onPressed: () {
                  setState(() {
                    _applyFarm(selectedFarm);
                  });
                },
                icon: const Icon(Icons.agriculture_rounded),
                label: Text('Use selected farm: ${selectedFarm.name}'),
              ),
            ),
          TextField(
            controller: _farmNameController,
            decoration: const InputDecoration(
              labelText: 'Farm name',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedCropType),
            initialValue: _selectedCropType,
            decoration: const InputDecoration(
              labelText: 'Crop type',
            ),
            items: const [
              DropdownMenuItem(
                value: 'Sugarcane',
                child: Text('Sugarcane'),
              ),
              DropdownMenuItem(
                value: 'Rice',
                child: Text('Rice'),
              ),
              DropdownMenuItem(
                value: 'Corn',
                child: Text('Corn'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedCropType = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ageDaysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Crop age in days',
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _isAnalyzing
                    ? null
                    : () => _pickAndAnalyze(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Take picture'),
              ),
              OutlinedButton.icon(
                onPressed: _isAnalyzing
                    ? null
                    : () => _pickAndAnalyze(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Choose photo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedImage(ThemeData theme) {
    return FrostedPanel(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Image',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.primaryGold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: Image.file(
                File(_selectedImage!.path),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return const FrostedPanel(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inspecting crop image...'),
          SizedBox(height: 12),
          LinearProgressIndicator(minHeight: 3),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return FrostedPanel(
      radius: 28,
      child: Text(
        _error!,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.red.shade700,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDiagnosis(ThemeData theme) {
    return _InspectorSection(
      title: 'Diagnosis Result',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InspectorBadge(
                label: _diagnosis!.primaryLabel,
                color: AppVisuals.primaryGold,
                icon: Icons.local_florist_rounded,
              ),
              _InspectorBadge(
                label: '${_diagnosis!.confidenceLabel} confidence',
                color: _diagnosis!.engine == CropInspectorEngine.tflite
                    ? AppVisuals.brandGreen
                    : AppVisuals.brandBlue,
                icon: _diagnosis!.engine == CropInspectorEngine.tflite
                    ? Icons.memory_rounded
                    : Icons.image_search_rounded,
              ),
              _InspectorBadge(
                label: _diagnosis!.engine == CropInspectorEngine.tflite
                    ? 'TFLite offline model'
                    : 'Heuristic fallback',
                color: AppVisuals.surfaceInset,
                icon: Icons.settings_input_component_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _diagnosis!.summary,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppVisuals.textForest,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Top predictions',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppVisuals.textForest,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ..._diagnosis!.predictions.map(
            (prediction) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PredictionTile(prediction: prediction),
            ),
          ),
          if (_diagnosis!.findings.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Findings',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppVisuals.textForest,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            _InspectorBulletList(items: _diagnosis!.findings),
          ],
          if (_diagnosis!.recommendations.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Recommendations',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppVisuals.textForest,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            _InspectorBulletList(items: _diagnosis!.recommendations),
          ],
          if (_diagnosis!.captureTips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Capture Tips',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppVisuals.textForest,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            _InspectorBulletList(items: _diagnosis!.captureTips),
          ],
        ],
      ),
    );
  }

  Widget _buildHistory(ThemeData theme) {
    return _InspectorSection(
      title: 'Scan History',
      trailing: _historyLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              '${_historyItems.length} saved',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppVisuals.textForestMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
      child: _historyItems.isEmpty
          ? Text(
              'No crop inspections have been saved yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
              ),
            )
          : Column(
              children: _historyItems.map((record) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HistoryTile(record: record),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildSyncSection(ThemeData theme) {
    return _InspectorSection(
      title: 'Optional Backend Sync',
      trailing: Text(
        '$_pendingHistoryCount pending',
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppVisuals.textForestMuted,
          fontWeight: FontWeight.w900,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable backend sync'),
            subtitle: const Text(
              'Use this when you have an API ready to collect scan records and images.',
            ),
            value: _backendEnabled,
            onChanged: (value) {
              setState(() {
                _backendEnabled = value;
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _backendUrlController,
            decoration: const InputDecoration(
              labelText: 'Backend URL',
              hintText: 'https://example.com/api/crop-inspector/scans',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonal(
                onPressed: _saveSyncSettings,
                child: const Text('Save settings'),
              ),
              FilledButton.icon(
                onPressed: _isSyncing ? null : _syncPending,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: const Text('Sync pending scans'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FrostedPanel(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppVisuals.primaryGold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InspectorBadge extends StatelessWidget {
  const _InspectorBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

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

class _PredictionTile extends StatelessWidget {
  const _PredictionTile({
    required this.prediction,
  });

  final CropInspectorPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scorePercent = (prediction.score * 100).clamp(0, 100).round();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppVisuals.primaryGold.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  prediction.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppVisuals.textForest,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$scorePercent%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppVisuals.primaryGold,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            prediction.summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorBulletList extends StatelessWidget {
  const _InspectorBulletList({
    required this.items,
  });

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: AppVisuals.primaryGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppVisuals.textForest,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.record,
  });

  final CropInspectorScanRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncLabel = switch (record.syncStatus) {
      CropInspectorSyncStatus.localOnly => 'Local only',
      CropInspectorSyncStatus.pending => 'Pending sync',
      CropInspectorSyncStatus.synced => 'Synced',
      CropInspectorSyncStatus.failed => 'Sync failed',
    };
    final syncColor = switch (record.syncStatus) {
      CropInspectorSyncStatus.localOnly => AppVisuals.brandBlue,
      CropInspectorSyncStatus.pending => AppVisuals.primaryGold,
      CropInspectorSyncStatus.synced => AppVisuals.brandGreen,
      CropInspectorSyncStatus.failed => Colors.red.shade700,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 72,
              height: 72,
              child: File(record.diagnosis.imagePath).existsSync()
                  ? Image.file(
                      File(record.diagnosis.imagePath),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppVisuals.panelSoftAlt,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_rounded),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.diagnosis.primaryLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppVisuals.textForest,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.diagnosis.cropType} • ${record.diagnosis.farmName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.createdAt.toLocal().toString().split('.').first,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
                const SizedBox(height: 8),
                _InspectorBadge(
                  label: syncLabel,
                  color: syncColor,
                  icon: Icons.sync_rounded,
                ),
                if ((record.syncError ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    record.syncError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
