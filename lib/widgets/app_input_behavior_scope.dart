import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppInputBehaviorScope extends StatelessWidget {
  const AppInputBehaviorScope({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _handleKeyEvent,
      child: child,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter ||
        HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    final focusNode = FocusManager.instance.primaryFocus;
    final context = focusNode?.context;
    if (context == null) {
      return KeyEventResult.ignored;
    }

    final focusedWidget = context.widget;
    if (focusedWidget is! EditableText) {
      return KeyEventResult.ignored;
    }

    if ((focusedWidget.maxLines ?? 1) > 1) {
      return KeyEventResult.ignored;
    }

    FocusScope.of(context).nextFocus();
    return KeyEventResult.handled;
  }
}
