import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/farm_provider.dart';
import '../services/app_localization_service.dart';
import '../services/app_route_observer.dart';
import '../models/farm_model.dart';
import '../themes/app_visuals.dart';
import '../utils/app_number_input_formatter.dart';
import '../utils/validation_utils.dart';
import '../widgets/focus_tooltip.dart';

class AddFarmScreen extends StatefulWidget {
  final String? farmID;

  const AddFarmScreen({super.key, this.farmID});

  @override
  State<AddFarmScreen> createState() => _AddFarmScreenState();
}

class _AddFarmScreenState extends State<AddFarmScreen> with RouteAware {
  static const _scaffoldBodyTextColor = AppVisuals.textForest;
  static const _scaffoldFieldTextColor = AppVisuals.textForest;
  static const _scaffoldFieldFillColor = AppVisuals.cloudGlass;
  static const _dropdownMenuColor = AppVisuals.surfaceGreen;
  static const _dropdownMenuTextColor = AppVisuals.softWhite;
  static final _numberInputFormatter = AppNumberInputFormatter();

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  final TextEditingController _ratoonController =
      TextEditingController(text: '0');

  // Controllers keep field values stable across validation and edit mode.
  final Map<String, TextEditingController> _controllers = {
    'name': TextEditingController(),
    'area': TextEditingController(),
    'city': TextEditingController(),
    'province': TextEditingController(),
    'owner': TextEditingController(),
  };

  final Map<String, FocusNode> _focusNodes = {
    'type': FocusNode(),
    'name': FocusNode(),
    'area': FocusNode(),
    'city': FocusNode(),
    'province': FocusNode(),
    'owner': FocusNode(),
    'ratoon': FocusNode(),
    'save': FocusNode(),
  };

  final Map<String, String?> _errorTexts = {
    'name': null,
    'area': null,
    'city': null,
    'province': null,
    'owner': null,
  };

  String? _selectedType;
  final List<String> _farmTypes = ['Sugarcane', 'Rice', 'Corn'];
  DateTime _selectedDate = DateTime.now();
  bool _isInit = true;
  bool _isRouteObserverSubscribed = false;
  AppAudioProvider? _appAudio;
  AppSettingsProvider? _appSettings;

  @override
  void didChangeDependencies() {
    _appAudio ??= Provider.of<AppAudioProvider>(context, listen: false);
    _appSettings ??= Provider.of<AppSettingsProvider>(context, listen: false);
    if (!_isRouteObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute<dynamic>) {
        appRouteObserver.subscribe(this, route);
        _isRouteObserverSubscribed = true;
      }
    }
    if (_isInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {});
      if (widget.farmID != null) {
        final farm = Provider.of<FarmProvider>(context, listen: false)
            .farms
            .firstWhere((f) => f.id == widget.farmID);
        _controllers['name']!.text = farm.name;
        _selectedType = _farmTypes.contains(farm.type) ? farm.type : null;
        _controllers['area']!.text = farm.area.toString();
        _controllers['city']!.text = farm.city;
        _controllers['province']!.text = farm.province;
        _controllers['owner']!.text = farm.owner;
        _selectedDate = farm.date;
        _ratoonController.text = farm.ratoonCount.toString();
      }
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _stopScreenOpenAudioIfNeeded() async {
    final appAudio = _appAudio;
    final appSettings = _appSettings;
    if (appAudio == null || appSettings == null) {
      return;
    }
    await appAudio.stopScreenOpenSound(
      screenKey: 'add_farm',
      style: appSettings.audioSoundStyle,
    );
  }

  @override
  void dispose() {
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    unawaited(_stopScreenOpenAudioIfNeeded());
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _ratoonController.dispose();
    for (var node in _focusNodes.values) {
      node.dispose();
    }
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

  void _requestFieldFocus(String key) {
    final targetNode = _focusNodes[key];
    if (targetNode == null || !mounted) return;
    FocusScope.of(context).requestFocus(targetNode);
  }

  /// Implementation of logical CHECKDATA
  bool _runCheckData() {
    bool hasError = false;
    setState(() {
      // Reset errors
      _errorTexts.updateAll((key, value) => null);

      if (_selectedType == null) {
        _showChip('Please select a Crop Type');
        _requestFieldFocus('type');
        hasError = true;
      }

      if (!hasError && _selectedType == 'Sugarcane') {
        final ratoonText = _ratoonController.text.trim();
        if (ratoonText.isEmpty) {
          _ratoonController.text = '0';
        } else if (int.tryParse(ratoonText) == null) {
          _showChip('Ratoon count must be a whole number');
          _requestFieldFocus('ratoon');
          hasError = true;
        }
      }

      if (!hasError) {
        // Validate fields sequentially to mimic setfocus back on error
        for (var key in _controllers.keys) {
          String fieldName = key.toUpperCase();
          bool isNumeric = key == 'area';

          final fieldValue = isNumeric
              ? _controllers[key]!.text.replaceAll(',', '')
              : _controllers[key]!.text;
          String? error = ValidationUtils.checkData(
              value: fieldValue, fieldName: fieldName, isNumeric: isNumeric);

          if (error != null) {
            _errorTexts[key] = 'Wrong format';
            _requestFieldFocus(key);
            hasError = true;
            _showChip('Wrong format');
            break;
          } else {
            // Standardize entry to Title Case format if not numeric
            if (!isNumeric) {
              _controllers[key]!.text =
                  ValidationUtils.toTitleCase(_controllers[key]!.text);
            }
          }
        }
      }
    });

    return !hasError;
  }

  void _showChip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _saveFarm() async {
    if (_isSaving) return;
    if (!_runCheckData()) return;

    setState(() => _isSaving = true);

    final farmData = Farm(
      id: widget.farmID,
      name: _controllers['name']!.text,
      type: _selectedType!,
      area: double.tryParse(_controllers['area']!.text.replaceAll(',', '')) ??
          0.0,
      city: _controllers['city']!.text,
      province: _controllers['province']!.text,
      date: _selectedDate,
      owner: _controllers['owner']!.text,
      ratoonCount: _selectedType == 'Sugarcane'
          ? int.tryParse(_ratoonController.text.trim()) ?? 0
          : 0,
      seasonNumber: widget.farmID == null
          ? 1
          : Provider.of<FarmProvider>(context, listen: false)
              .farms
              .firstWhere((f) => f.id == widget.farmID)
              .seasonNumber,
    );

    try {
      final provider = Provider.of<FarmProvider>(context, listen: false);
      final messenger = ScaffoldMessenger.of(context);

      if (widget.farmID == null) {
        await provider.addFarm(farmData);
        if (mounted) {
          Navigator.of(context).pop();
          messenger.showSnackBar(const SnackBar(
              content: Text('Farm added successfully'),
              backgroundColor: AppVisuals.primaryGold,
              behavior: SnackBarBehavior.floating));
        }
      } else {
        await provider.updateFarm(farmData);
        if (mounted) {
          Navigator.of(context).pop();
          messenger.showSnackBar(const SnackBar(
              content: Text('Farm updated successfully'),
              backgroundColor: AppVisuals.primaryGold,
              behavior: SnackBarBehavior.floating));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showChip('Error saving farm: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditMode = widget.farmID != null;
    final bodyTheme = theme.copyWith(
      canvasColor: AppVisuals.cloudGlass,
      cardColor: AppVisuals.cloudGlass,
      colorScheme: theme.colorScheme.copyWith(
        surface: AppVisuals.cloudGlass,
        onSurface: _scaffoldFieldTextColor,
        onSurfaceVariant: _scaffoldBodyTextColor.withValues(alpha: 0.78),
        outline: _scaffoldBodyTextColor.withValues(alpha: 0.18),
      ),
      textTheme: theme.textTheme.apply(
        bodyColor: _scaffoldBodyTextColor,
        displayColor: _scaffoldBodyTextColor,
      ),
      iconTheme: theme.iconTheme.copyWith(color: _scaffoldBodyTextColor),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        fillColor: _scaffoldFieldFillColor,
        labelStyle: TextStyle(
          color: _scaffoldBodyTextColor.withValues(alpha: 0.78),
        ),
        floatingLabelStyle: const TextStyle(
          color: _scaffoldBodyTextColor,
        ),
        hintStyle: TextStyle(
          color: _scaffoldBodyTextColor.withValues(alpha: 0.56),
        ),
        prefixStyle: const TextStyle(color: _scaffoldFieldTextColor),
        suffixStyle: TextStyle(
          color: _scaffoldFieldTextColor.withValues(alpha: 0.8),
        ),
      ),
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
        backgroundColor: AppVisuals.glass(AppVisuals.cloudGlass, alpha: 0.74),
        surfaceTintColor: Colors.transparent,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          isEditMode ? 'MODIFY ESTATE' : 'REGISTER ESTATE',
          style: const TextStyle(
              fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2),
        ),
        centerTitle: true,
      ),
      body: Theme(
        data: bodyTheme,
        child: AppBackdrop(
          isDark: false,
          child: Stack(
            children: [
              Container(
                color: AppVisuals.cloudGlass.withValues(alpha: 0.72),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. CROP TYPE (Dropdown at the absolute top)
                        _buildRow(
                          label: 'TYPE',
                          child: DropdownButtonFormField<String>(
                            focusNode: _focusNodes['type'],
                            initialValue: _selectedType,
                            decoration: const InputDecoration(isDense: true),
                            dropdownColor: _dropdownMenuColor,
                            iconEnabledColor: _scaffoldBodyTextColor,
                            selectedItemBuilder: (context) {
                              return _farmTypes
                                  .map(
                                    (type) => Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        context.tr(type),
                                        style: const TextStyle(
                                          color: _scaffoldFieldTextColor,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList();
                            },
                            items: _farmTypes
                                .map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                        context.tr(type),
                                        style: const TextStyle(
                                          color: _dropdownMenuTextColor,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedType = val;
                                if (val != 'Sugarcane') {
                                  _ratoonController.text = '0';
                                }
                              });
                              _requestFieldFocus('name');
                            },
                          ),
                        ),

                        // 2. DATE PLANTED
                        _buildRow(
                          label: 'DATE',
                          child: InkWell(
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: _dropdownMenuColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _scaffoldFieldTextColor.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    DateFormat('yyyy-MM-dd')
                                        .format(_selectedDate),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: _dropdownMenuTextColor,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.calendar_month_rounded,
                                      size: 18, color: _dropdownMenuTextColor),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 3. TEXT FIELDS
                        _buildTextFieldRow('Farm Name', 'name',
                            nextFieldKey: 'area'),
                        _buildTextFieldRow('Area (Ha)', 'area',
                            isNumeric: true, nextFieldKey: 'city'),
                        if (_selectedType == 'Sugarcane')
                          _buildRow(
                            label: 'RATOON',
                            child: TextFormField(
                              controller: _ratoonController,
                              focusNode: _focusNodes['ratoon'],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Existing ratoon count',
                                isDense: true,
                              ),
                              onFieldSubmitted: (_) =>
                                  _requestFieldFocus('city'),
                            ),
                          ),
                        _buildTextFieldRow('City', 'city',
                            nextFieldKey: 'province'),
                        _buildTextFieldRow('Province', 'province',
                            nextFieldKey: 'owner'),
                        _buildTextFieldRow('Owner', 'owner',
                            nextFieldKey: 'save'),

                        const SizedBox(height: 40),
                        _buildActionButtons(isEditMode),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isSaving)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppVisuals.primaryGold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow({required String label, required Widget child}) {
    final labelWidget = Text(label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: _scaffoldBodyTextColor,
        ));

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: labelWidget,
                ),
                child,
              ],
            );
          }

          return Row(
            children: [
              SizedBox(width: 120, child: labelWidget),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(bool isEditMode) {
    final primaryButton = OutlinedButton.icon(
      focusNode: _focusNodes['save'],
      onPressed: _isSaving ? null : _saveFarm,
      icon: Icon(isEditMode ? Icons.update_rounded : Icons.add_rounded),
      label: Text(isEditMode ? 'UPDATE' : 'ADD'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _scaffoldBodyTextColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
    final cancelButton = OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent)),
      child: const Text('CANCEL'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primaryButton,
              const SizedBox(height: 12),
              cancelButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: primaryButton),
            const SizedBox(width: 16),
            cancelButton,
          ],
        );
      },
    );
  }

  Widget _buildTextFieldRow(
    String label,
    String key, {
    bool isNumeric = false,
    String? nextFieldKey,
  }) {
    return _buildRow(
      label: label.toUpperCase(),
      child: FocusTooltip(
        message: 'Enter $label.',
        child: TextFormField(
          stylusHandwritingEnabled: false,
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          style: const TextStyle(color: _scaffoldFieldTextColor),
          cursorColor: _scaffoldFieldTextColor,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters:
              isNumeric ? <TextInputFormatter>[_numberInputFormatter] : null,
          textInputAction: nextFieldKey == null || nextFieldKey == 'save'
              ? TextInputAction.done
              : TextInputAction.next,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            errorText: _errorTexts[key],
          ),
          onChanged: (_) {
            if (_errorTexts[key] != null && mounted) {
              setState(() => _errorTexts[key] = null);
            }
          },
          onFieldSubmitted: (value) {
            final sanitizedValue =
                isNumeric ? value.replaceAll(',', '') : value;
            final error = ValidationUtils.checkData(
              value: sanitizedValue,
              fieldName: label,
              isNumeric: isNumeric,
            );
            if (error == null) {
              setState(() {
                _errorTexts[key] = null;
                if (!isNumeric) {
                  _controllers[key]!.text = ValidationUtils.toTitleCase(value);
                }
              });
              if (nextFieldKey != null) {
                _requestFieldFocus(nextFieldKey);
              } else {
                _saveFarm();
              }
              return;
            }

            setState(() => _errorTexts[key] = 'Wrong format');
            _requestFieldFocus(key);
          },
        ),
      ),
    );
  }

  void _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() => _selectedDate = pickedDate);
    }
  }
}
