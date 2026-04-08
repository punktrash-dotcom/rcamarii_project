import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/worker_model.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../services/app_route_observer.dart';
import '../providers/worker_provider.dart';
import '../themes/app_visuals.dart';
import '../utils/validation_utils.dart';

class ScrWorkers extends StatefulWidget {
  const ScrWorkers({super.key});

  @override
  State<ScrWorkers> createState() => _ScrWorkersState();
}

class _ScrWorkersState extends State<ScrWorkers> with RouteAware {
  bool _playedScreenOpenAudio = false;
  bool _isRouteObserverSubscribed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeScreen());
    });
  }

  Future<void> _initializeScreen() async {
    try {
      await Provider.of<WorkerProvider>(context, listen: false).loadWorkers();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load workers: $error')),
      );
    }
    await _playScreenOpenAudioIfNeeded();
  }

  Future<void> _playScreenOpenAudioIfNeeded() async {
    if (!mounted || _playedScreenOpenAudio) {
      return;
    }
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    _playedScreenOpenAudio = true;
    await context.read<AppAudioProvider>().playScreenOpenSound(
          screenKey: 'employees',
          style: appSettings.audioSoundStyle,
          enabled: appSettings.audioSoundsEnabled,
        );
  }

  Future<void> _stopScreenOpenAudioIfNeeded() async {
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    await context.read<AppAudioProvider>().stopScreenOpenSound(
          screenKey: 'employees',
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
    final workerProvider = Provider.of<WorkerProvider>(context);
    final workers = workerProvider.workers;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Employees Data',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: scheme.onPrimary,
            fontFamily: 'Georgia',
          ),
        ),
        backgroundColor: scheme.primary.withValues(alpha: isDark ? 0.92 : 0.94),
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppBackdrop(
        isDark: isDark,
        backgroundImageAsset: 'lib/assets/images/background.png',
        backgroundImageOpacity: isDark ? 0.26 : 0.38,
        imageScrimColor: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : AppVisuals.softWhite.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              FrostedPanel(
                radius: 24,
                color: scheme.surface.withValues(alpha: isDark ? 0.58 : 0.62),
                child: ElevatedButton.icon(
                  onPressed: () => _showAddEditScreen(),
                  icon: const Icon(Icons.person_add_rounded),
                  label: const Text(
                    'ADD NEW EMPLOYEE',
                    style: TextStyle(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FrostedPanel(
                  radius: 28,
                  padding: const EdgeInsets.all(12),
                  color: scheme.surface.withValues(alpha: isDark ? 0.58 : 0.62),
                  child: workers.isEmpty
                      ? Center(
                          child: Text(
                            'No employees found.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          itemCount: workers.length,
                          itemBuilder: (ctx, i) {
                            final worker = workers[i];
                            return Card(
                              color: scheme.surface.withValues(
                                alpha: isDark ? 0.6 : 0.64,
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                                side: BorderSide(
                                  color: scheme.outline.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        radius: 24,
                                        backgroundColor:
                                            scheme.primary.withValues(
                                          alpha: isDark ? 0.24 : 0.12,
                                        ),
                                        child: Text(
                                          worker.id.toString(),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        worker.name,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: scheme.onSurface,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Position: ${worker.position}\n'
                                          'Cellphone: ${worker.cellphoneNumber}\n'
                                          'Address: ${worker.address}\n'
                                          'Note: ${worker.note ?? '-'}',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Divider(
                                        height: 1,
                                        color: scheme.outline
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton.icon(
                                            onPressed: () => _showAddEditScreen(
                                                worker: worker),
                                            icon: const Icon(
                                              Icons.edit_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'EDIT',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: scheme.primary,
                                              backgroundColor:
                                                  scheme.primary.withValues(
                                                alpha: isDark ? 0.18 : 0.1,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: TextButton.icon(
                                            onPressed: () =>
                                                _deleteWorker(worker.id!),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'DELETE',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: scheme.error,
                                              backgroundColor:
                                                  scheme.error.withValues(
                                                alpha: isDark ? 0.18 : 0.1,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteWorker(int id) async {
    final workerProvider = Provider.of<WorkerProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Removal',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Are you sure you want to remove this employee from the records?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'REMOVE',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await workerProvider.deleteWorker(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee Deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddEditScreen({Worker? worker}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => FrmAddEditWorker(worker: worker),
      ),
    );
  }
}

class FrmAddEditWorker extends StatefulWidget {
  final Worker? worker;
  final String? initialName;

  const FrmAddEditWorker({super.key, this.worker, this.initialName});

  @override
  State<FrmAddEditWorker> createState() => _FrmAddEditWorkerState();
}

class _FrmAddEditWorkerState extends State<FrmAddEditWorker> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final List<String> _fields = [
    'Name',
    'Position',
    'Cellphone Number',
    'Address',
    'Note',
  ];

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      var initialValue = '';
      if (widget.worker != null) {
        switch (field) {
          case 'Name':
            initialValue = widget.worker!.name;
            break;
          case 'Position':
            initialValue = widget.worker!.position;
            break;
          case 'Cellphone Number':
            initialValue = widget.worker!.cellphoneNumber;
            break;
          case 'Address':
            initialValue = widget.worker!.address;
            break;
          case 'Note':
            initialValue = widget.worker!.note ?? '';
            break;
        }
      } else if (field == 'Name') {
        initialValue = widget.initialName ?? '';
      }
      _controllers[field] = TextEditingController(text: initialValue);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final newWorker = Worker(
        id: widget.worker?.id,
        name: _controllers['Name']!.text,
        position: _controllers['Position']!.text,
        cellphoneNumber: _controllers['Cellphone Number']!.text,
        address: _controllers['Address']!.text,
        note: _controllers['Note']!.text.trim().isNotEmpty
            ? _controllers['Note']!.text.trim()
            : null,
      );

      final provider = Provider.of<WorkerProvider>(context, listen: false);
      if (widget.worker == null) {
        await provider.addWorker(newWorker);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee added.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await provider.updateWorker(newWorker);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database Updated'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Incorrect Input',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.redAccent,
            ),
          ),
          content: const Text(
            'Please ensure all required fields are filled correctly.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          widget.worker == null ? 'Register Employee' : 'Modify Record',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: scheme.onPrimary,
          ),
        ),
        backgroundColor: scheme.primary.withValues(alpha: isDark ? 0.92 : 0.94),
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onPrimary,
        centerTitle: true,
      ),
      body: AppBackdrop(
        isDark: isDark,
        backgroundImageAsset: 'lib/assets/images/background.png',
        backgroundImageOpacity: isDark ? 0.18 : 0.28,
        imageScrimColor: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : AppVisuals.softWhite.withValues(alpha: 0.08),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: FrostedPanel(
            radius: 28,
            color: scheme.surface.withValues(alpha: isDark ? 0.6 : 0.64),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._fields.map((field) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                              fontSize: 12,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            stylusHandwritingEnabled: false,
                            controller: _controllers[field],
                            maxLines: field == 'Note' ? 3 : 1,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: "Enter employee's $field",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.54),
                            ),
                            validator: field == 'Note'
                                ? null
                                : (value) => ValidationUtils.checkData(
                                      value: value,
                                      fieldName: field,
                                    ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _save,
                          icon: Icon(
                            widget.worker == null
                                ? Icons.save_rounded
                                : Icons.update_rounded,
                          ),
                          label: Text(
                            widget.worker == null
                                ? 'SAVE RECORD'
                                : 'UPDATE RECORD',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 24,
                          ),
                          side: BorderSide(color: scheme.error),
                          foregroundColor: scheme.error,
                        ),
                        child: const Text('CANCEL'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
