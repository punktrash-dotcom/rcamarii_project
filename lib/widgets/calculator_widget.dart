import 'package:flutter/material.dart';

import '../themes/app_visuals.dart';

class CalculatorWidget extends StatelessWidget {
  final Function(String) onResultChanged;

  const CalculatorWidget({super.key, required this.onResultChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Calculate dynamic button size based on available space
      final buttonHeight = constraints.maxHeight / 4.5;

      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildButtonRow(['1', '2', '3'], buttonHeight),
          _buildButtonRow(['4', '5', '6'], buttonHeight),
          _buildButtonRow(['7', '8', '9'], buttonHeight),
          SizedBox(
            height: buttonHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildButton('.', buttonHeight),
                _buildButton('0', buttonHeight),
                _buildButtonWithIcon(
                    Icons.backspace_outlined, '<-', buttonHeight),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildButtonRow(List<String> buttons, double height) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: buttons.map((text) => _buildButton(text, height)).toList(),
      ),
    );
  }

  Widget _buildButton(String text, double height) {
    return Expanded(
      child: TextButton(
        onPressed: () => onResultChanged(text),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: Center(
            child: Text(text,
                style: const TextStyle(
                    color: AppVisuals.textForest,
                    fontSize: 24,
                    fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildButtonWithIcon(IconData icon, String value, double height) {
    return Expanded(
      child: TextButton(
        onPressed: () => onResultChanged(value),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: Center(
          child: Icon(icon, color: AppVisuals.textForest, size: 24),
        ),
      ),
    );
  }
}
