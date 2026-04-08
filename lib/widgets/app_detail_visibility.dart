import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';

class AppDetailVisibility extends StatelessWidget {
  const AppDetailVisibility({
    super.key,
    required this.child,
    this.preserveSpace = false,
  });

  final Widget child;
  final bool preserveSpace;

  @override
  Widget build(BuildContext context) {
    final showDetails = context.select<AppSettingsProvider, bool>(
      (settings) => settings.showDetailedDescriptions,
    );
    if (showDetails) {
      return child;
    }
    return preserveSpace ? const SizedBox.shrink() : const SizedBox.shrink();
  }
}
