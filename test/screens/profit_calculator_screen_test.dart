import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/models/ftracker_model.dart';
import 'package:nmd/models/sugarcane_profit_model.dart';
import 'package:nmd/providers/app_settings_provider.dart';
import 'package:nmd/providers/sugarcane_profit_provider.dart';
import 'package:nmd/screens/profit_calculator_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const peso = '\u20B1';
const lastTransactionKey = 'profit_calculator_last_transaction_v1';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpCalculator(
    WidgetTester tester, {
    SugarcaneProfitProvider? profitProvider,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettingsProvider>(
            create: (_) => AppSettingsProvider(),
          ),
          if (profitProvider != null)
            ChangeNotifierProvider<SugarcaneProfitProvider>.value(
              value: profitProvider,
            ),
        ],
        child: const MaterialApp(
          home: ProfitCalculatorScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterValue(
    WidgetTester tester,
    String key,
    String value,
  ) async {
    await tester.enterText(find.byKey(ValueKey(key)), value);
    await tester.pump();
  }

  String netProfitText(WidgetTester tester) {
    return tester
            .widget<Text>(
              find.byKey(const ValueKey('profitCalculator.netProfit')),
            )
            .data ??
        '';
  }

  String metricText(WidgetTester tester, String key) {
    return tester.widget<Text>(find.byKey(ValueKey(key))).data ?? '';
  }

  testWidgets(
      'saving a profit record scrolls to the top, stores the entry, creates FTracker revenue, clears fields, and keeps the computation visible',
      (tester) async {
    final profitProvider = _FakeSugarcaneProfitProvider();
    await pumpCalculator(tester, profitProvider: profitProvider);

    await enterValue(tester, 'profitCalculator.netTonsCane', '125');
    await enterValue(tester, 'profitCalculator.lkgPerTc', '2');
    await enterValue(tester, 'profitCalculator.planterShare', '70');
    await enterValue(tester, 'profitCalculator.sugarPricePerLkg', '50');
    await enterValue(tester, 'profitCalculator.molassesKg', '20');
    await enterValue(tester, 'profitCalculator.molassesPricePerKg', '5');
    await enterValue(tester, 'profitCalculator.productionCosts', '1000');

    expect(netProfitText(tester), '${peso}7,850.00');

    final scrollView =
        find.byKey(const ValueKey('profitCalculator.scrollView'));
    await tester.drag(scrollView, const Offset(0, -900));
    await tester.pumpAndSettle();

    final scrollController =
        tester.widget<SingleChildScrollView>(scrollView).controller!;
    expect(scrollController.offset, greaterThan(0));

    await tester.ensureVisible(
      find.byKey(const ValueKey('profitCalculator.saveProfitRecord')),
    );
    await tester.tap(
      find.byKey(const ValueKey('profitCalculator.saveProfitRecord')),
    );
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(lastTransactionKey);
    expect(savedJson, isNotNull);

    expect(profitProvider.savedRecord, isNotNull);
    expect(profitProvider.savedTrackerRecord, isNotNull);
    expect(profitProvider.savedRecord!.totalRevenue, 8850);
    expect(profitProvider.savedRecord!.netProfit, 7850);
    expect(profitProvider.savedTrackerRecord!.type, 'Income');
    expect(profitProvider.savedTrackerRecord!.category, 'Farm');
    expect(
      profitProvider.savedTrackerRecord!.name,
      'Sugarcane | Standalone profit record',
    );
    expect(profitProvider.savedTrackerRecord!.amount, 8850);

    final netTonsField = tester.widget<TextField>(
      find.byKey(const ValueKey('profitCalculator.netTonsCane')),
    );
    final lkgField = tester.widget<TextField>(
      find.byKey(const ValueKey('profitCalculator.lkgPerTc')),
    );

    expect(netTonsField.controller?.text, isEmpty);
    expect(lkgField.controller?.text, isEmpty);
    expect(netTonsField.decoration?.hintText, '125');
    expect(lkgField.decoration?.hintText, '2');
    expect(scrollController.offset, 0);
    expect(netProfitText(tester), '${peso}7,850.00');
    expect(
      metricText(tester, 'profitCalculator.totalRevenue'),
      '${peso}8,850.00',
    );
  });

  testWidgets('renders redesigned calculator and updates live net profit',
      (tester) async {
    await pumpCalculator(tester);

    expect(find.text('Profit Calculator'), findsOneWidget);
    expect(find.text('Projected Net Profit'), findsOneWidget);
    expect(find.text('Trial / Manual'), findsNothing);
    expect(netProfitText(tester), '${peso}0.00');
    expect(
      tester.widget<Text>(find.text('Profit Calculator')).style?.color,
      Colors.white,
    );

    await enterValue(tester, 'profitCalculator.netTonsCane', '100');
    await enterValue(tester, 'profitCalculator.lkgPerTc', '1.9');
    await enterValue(tester, 'profitCalculator.planterShare', '70');
    await enterValue(tester, 'profitCalculator.sugarPricePerLkg', '50');
    await enterValue(tester, 'profitCalculator.productionCosts', '1000');

    expect(netProfitText(tester), '${peso}5,650.00');
    expect(
      metricText(tester, 'profitCalculator.totalRevenue'),
      '${peso}6,650.00',
    );
  });

  testWidgets('parses commas and keeps optional molasses fields at zero',
      (tester) async {
    await pumpCalculator(tester);

    await enterValue(tester, 'profitCalculator.netTonsCane', '1,000');
    await enterValue(tester, 'profitCalculator.lkgPerTc', '2');
    await enterValue(tester, 'profitCalculator.planterShare', '50');
    await enterValue(tester, 'profitCalculator.sugarPricePerLkg', '40');
    await enterValue(tester, 'profitCalculator.productionCosts', '5,000');

    expect(netProfitText(tester), '${peso}35,000.00');
    expect(
      metricText(tester, 'profitCalculator.totalRevenue'),
      '${peso}40,000.00',
    );
    expect(
      metricText(tester, 'profitCalculator.molassesProceeds'),
      '${peso}0.00',
    );
  });

  testWidgets('shows loss state and clear all resets fields', (tester) async {
    await pumpCalculator(tester);

    await enterValue(tester, 'profitCalculator.netTonsCane', '100');
    await enterValue(tester, 'profitCalculator.lkgPerTc', '1.9');
    await enterValue(tester, 'profitCalculator.planterShare', '70');
    await enterValue(tester, 'profitCalculator.sugarPricePerLkg', '50');
    await enterValue(tester, 'profitCalculator.productionCosts', '10000');

    expect(netProfitText(tester), '-${peso}3,350.00');
    expect(find.text('Loss Position'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const ValueKey('profitCalculator.clearAll')),
    );
    await tester.tap(find.byKey(const ValueKey('profitCalculator.clearAll')));
    await tester.pumpAndSettle();

    final netTonsField = tester.widget<TextField>(
      find.byKey(const ValueKey('profitCalculator.netTonsCane')),
    );

    expect(netProfitText(tester), '${peso}0.00');
    expect(netTonsField.controller?.text, isEmpty);
  });

  testWidgets('stores details on demand and lets the user update loaded fields',
      (tester) async {
    await pumpCalculator(tester);

    await enterValue(tester, 'profitCalculator.netTonsCane', '125');
    await enterValue(tester, 'profitCalculator.lkgPerTc', '2');
    await enterValue(tester, 'profitCalculator.planterShare', '70');
    await enterValue(tester, 'profitCalculator.sugarPricePerLkg', '50');
    await enterValue(tester, 'profitCalculator.molassesKg', '20');
    await enterValue(tester, 'profitCalculator.molassesPricePerKg', '5');
    await enterValue(tester, 'profitCalculator.productionCosts', '1000');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(lastTransactionKey), isNull);

    await tester.ensureVisible(
      find.byKey(const ValueKey('profitCalculator.storeEntry')),
    );
    await tester.tap(find.byKey(const ValueKey('profitCalculator.storeEntry')));
    await tester.pumpAndSettle();

    expect(prefs.getString(lastTransactionKey), isNotNull);

    await pumpCalculator(tester);

    expect(
      find.byKey(const ValueKey('profitCalculator.loadStoredEntry')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('profitCalculator.clearAll')),
    );
    await tester.tap(find.byKey(const ValueKey('profitCalculator.clearAll')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profitCalculator.netTonsCane.useSavedHint')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('profitCalculator.netTonsCane.useSavedHint')),
    );
    await tester.pump();

    final hintedNetTonsField = tester.widget<TextField>(
      find.byKey(const ValueKey('profitCalculator.netTonsCane')),
    );

    expect(hintedNetTonsField.controller?.text, '125');

    await tester.ensureVisible(
      find.byKey(const ValueKey('profitCalculator.loadStoredEntry')),
    );
    await tester.tap(
      find.byKey(const ValueKey('profitCalculator.loadStoredEntry')),
    );
    await tester.pumpAndSettle();

    final netTonsField = tester.widget<TextField>(
      find.byKey(const ValueKey('profitCalculator.netTonsCane')),
    );
    final molassesField = tester.widget<TextField>(
      find.byKey(const ValueKey('profitCalculator.molassesKg')),
    );

    expect(netTonsField.controller?.text, '125');
    expect(molassesField.controller?.text, '20');
    expect(netProfitText(tester), '${peso}7,850.00');

    await enterValue(tester, 'profitCalculator.productionCosts', '2000');

    expect(netProfitText(tester), '${peso}6,850.00');
  });
}

class _FakeSugarcaneProfitProvider extends SugarcaneProfitProvider {
  SugarcaneProfit? savedRecord;
  Ftracker? savedTrackerRecord;

  @override
  Future<void> loadProfitRecords() async {}

  @override
  Future<int> saveProfitRecord(
    SugarcaneProfit record, {
    Ftracker? trackerRecord,
  }) async {
    savedRecord = record;
    savedTrackerRecord = trackerRecord;
    return 1;
  }
}
