import 'package:flutter/material.dart';

class FocusTooltip extends StatefulWidget {
  const FocusTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  State<FocusTooltip> createState() => _FocusTooltipState();
}

class _FocusTooltipState extends State<FocusTooltip> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  void _handleFocusChange(bool hasFocus) {
    if (!hasFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _tooltipKey.currentState?.ensureTooltipVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _handleFocusChange,
      child: Tooltip(
        key: _tooltipKey,
        message: widget.message,
        triggerMode: TooltipTriggerMode.manual,
        waitDuration: Duration.zero,
        showDuration: const Duration(seconds: 4),
        child: widget.child,
      ),
    );
  }
}
