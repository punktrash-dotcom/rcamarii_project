import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/providers/app_settings_provider.dart';
import 'package:nmd/widgets/modern_screen_shell.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'ModernScreenShell reflows instead of overflowing with large system text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 720),
            textScaler: TextScaler.linear(2),
          ),
          child: ChangeNotifierProvider(
            create: (_) => AppSettingsProvider(),
            child: MaterialApp(
              home: Scaffold(
                body: ModernScreenShell(
                  title: 'Accessibility Header Stress Test',
                  subtitle: 'Large Text',
                  actionBadge: FilledButton.tonalIcon(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Accessibility Header Stress Test'), findsOneWidget);
    },
  );
}
