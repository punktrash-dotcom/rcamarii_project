import 'package:flutter/material.dart';

class SearchableDropdownFormField<T> extends FormField<T> {
  SearchableDropdownFormField({
    super.key,
    required List<DropdownMenuItem<T>> items,
    super.initialValue,
    required ValueChanged<T?>? onChanged,
    super.onSaved,
    super.validator,
    InputDecoration decoration = const InputDecoration(),
    Widget? hint,
    FocusNode? focusNode,
    bool isExpanded = false,
    super.autovalidateMode = AutovalidateMode.disabled,
  }) : super(
          enabled: onChanged != null,
          builder: (field) {
            final state = field as _SearchableDropdownFormFieldState<T>;
            return state._build(
              items: items,
              decoration: decoration,
              hint: hint,
              focusNode: focusNode,
              onChanged: onChanged,
              isExpanded: isExpanded,
            );
          },
        );

  @override
  FormFieldState<T> createState() => _SearchableDropdownFormFieldState<T>();
}

class _SearchableDropdownFormFieldState<T> extends FormFieldState<T> {
  Widget _build({
    required List<DropdownMenuItem<T>> items,
    required InputDecoration decoration,
    required Widget? hint,
    required FocusNode? focusNode,
    required ValueChanged<T?>? onChanged,
    required bool isExpanded,
  }) {
    final theme = Theme.of(context);
    final selectedItem = _selectedItem(items, value);
    final selectedLabel =
        selectedItem == null ? null : _itemLabel(selectedItem);
    final enabled = onChanged != null;
    final effectiveDecoration = decoration.copyWith(
      errorText: errorText,
      suffixIcon: const Icon(Icons.search_rounded),
    );
    final showHint = value == null;
    final hintStyle =
        effectiveDecoration.hintStyle ?? theme.inputDecorationTheme.hintStyle;
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      color: enabled
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurface.withValues(alpha: 0.45),
    );
    final displayChild = showHint
        ? hint ??
            Text(
              effectiveDecoration.hintText ?? '',
              style: hintStyle,
              overflow: TextOverflow.ellipsis,
            )
        : Text(
            selectedLabel ?? '',
            style: textStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: isExpanded ? 2 : 1,
          );

    return Focus(
      focusNode: focusNode,
      child: InkWell(
        onTap: !enabled || items.isEmpty
            ? null
            : () async {
                focusNode?.requestFocus();
                final selected = await showSearchableDropdownSheet<T>(
                  context,
                  items: items,
                  title: decoration.labelText,
                  currentValue: value,
                );
                if (!mounted || selected == null) {
                  return;
                }
                if (selected != value) {
                  didChange(selected);
                  onChanged(selected);
                }
              },
        borderRadius: BorderRadius.circular(18),
        child: InputDecorator(
          isEmpty: showHint,
          isFocused: focusNode?.hasFocus ?? false,
          decoration: effectiveDecoration,
          child: SizedBox(
            width: double.infinity,
            child: displayChild,
          ),
        ),
      ),
    );
  }
}

class SearchableDropdownButton<T> extends StatelessWidget {
  const SearchableDropdownButton({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.style,
    this.enabled = true,
    this.hintText,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final TextStyle? style;
  final bool enabled;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedItem = _selectedItem(items, value);
    final label =
        selectedItem == null ? hintText ?? '' : _itemLabel(selectedItem);
    final effectiveStyle = style ??
        theme.textTheme.bodyMedium?.copyWith(
          color: enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withValues(alpha: 0.45),
        );

    return InkWell(
      onTap: !enabled || onChanged == null || items.isEmpty
          ? null
          : () async {
              final selected = await showSearchableDropdownSheet<T>(
                context,
                items: items,
                currentValue: value,
              );
              if (!context.mounted || selected == null) return;
              if (selected != value) {
                onChanged?.call(selected);
              }
            },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: effectiveStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.search_rounded,
              size: 18,
              color: enabled
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

Future<T?> showSearchableDropdownSheet<T>(
  BuildContext context, {
  required List<DropdownMenuItem<T>> items,
  String? title,
  T? currentValue,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SearchableDropdownSheet<T>(
      items: items,
      title: title,
      currentValue: currentValue,
    ),
  );
}

class _SearchableDropdownSheet<T> extends StatefulWidget {
  const _SearchableDropdownSheet({
    required this.items,
    required this.title,
    required this.currentValue,
  });

  final List<DropdownMenuItem<T>> items;
  final String? title;
  final T? currentValue;

  @override
  State<_SearchableDropdownSheet<T>> createState() =>
      _SearchableDropdownSheetState<T>();
}

class _SearchableDropdownSheetState<T>
    extends State<_SearchableDropdownSheet<T>> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = widget.items.where((item) {
      if (query.isEmpty) return true;
      return _itemLabel(item).toLowerCase().contains(query);
    }).toList();
    final viewInsets = MediaQuery.of(context).viewInsets;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((widget.title ?? '').trim().isNotEmpty) ...[
                Text(
                  widget.title!,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                stylusHandwritingEnabled: false,
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search options',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Text(
                          'No matching options found.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final selected = item.value == widget.currentValue;
                          final enabled = item.enabled;
                          return ListTile(
                            title: Text(
                              _itemLabel(item),
                              overflow: TextOverflow.ellipsis,
                              style: enabled
                                  ? null
                                  : TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.45),
                                    ),
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.check_rounded,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                            onTap: enabled
                                ? () => Navigator.of(context).pop(item.value)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

DropdownMenuItem<T>? _selectedItem<T>(
  List<DropdownMenuItem<T>> items,
  T? value,
) {
  for (final item in items) {
    if (item.value == value) {
      return item;
    }
  }
  return null;
}

String _itemLabel<T>(DropdownMenuItem<T> item) {
  final child = item.child;
  if (child is Text) {
    return child.data ?? '';
  }
  if (child is RichText) {
    return child.text.toPlainText();
  }
  return item.value?.toString() ?? '';
}
