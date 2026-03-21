import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nmd/components/user_supplies_view.dart';
import 'package:nmd/models/supply_model.dart';
import 'package:nmd/providers/data_provider.dart';
import 'package:nmd/providers/supplies_provider.dart';

class _FakeSuppliesProvider extends SuppliesProvider {
  _FakeSuppliesProvider({List<Supply>? items}) : _items = items ?? <Supply>[];

  final List<Supply> _items;

  @override
  List<Supply> get items => _items;

  @override
  Future<void> loadSupplies() async {}
}

void main() {
  testWidgets('user supplies view shows empty state when there are no supplies',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SuppliesProvider>(
            create: (_) => _FakeSuppliesProvider(items: const []),
          ),
          ChangeNotifierProvider<DataProvider>(
            create: (_) => DataProvider(),
          ),
        ],
        child: const MaterialApp(
          home: UserSuppliesView(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No supplies yet'), findsOneWidget);
    expect(
      find.text('Tap "Add New" to start building your stock.'),
      findsOneWidget,
    );
    expect(find.text('Add New'), findsOneWidget);
  });
}