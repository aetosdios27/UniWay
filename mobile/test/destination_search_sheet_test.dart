import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/models/phase0_destinations.dart';
import 'package:uniway_mobile/presentation/search/destination_search_sheet.dart';

const _yourLocation = Destination(
  id: 'YOUR_LOCATION',
  routingNodeId: 'GPS',
  name: 'Your Location',
  category: 'gps',
  latitude: 0,
  longitude: 0,
);

final _library = Phase0Destinations.all.firstWhere((d) => d.name == 'Central Library');

void main() {
  late Destination? picked;

  Future<void> openSheet(
    WidgetTester tester, {
    Destination? selected,
    Destination? extraOption,
  }) async {
    picked = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showDestinationSearchSheet(
                    context,
                    destinations: Phase0Destinations.all,
                    title: 'To',
                    selected: selected,
                    extraOption: extraOption,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> typeQuery(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 150));
  }

  group('showDestinationSearchSheet', () {
    testWidgets('typing filters results only after the 150 ms debounce', (tester) async {
      await openSheet(tester);

      await tester.enterText(find.byType(TextField), 'lhc');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Central Library'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Central Library'), findsNothing);
      expect(find.text('Lecture Hall Complex (LHC)'), findsOneWidget);
    });

    testWidgets('shows an explicit empty state with the query', (tester) async {
      await openSheet(tester);

      await typeQuery(tester, 'swimming');

      expect(find.text('No matching destinations for "swimming"'), findsOneWidget);
    });

    testWidgets('clear button restores the full list immediately', (tester) async {
      await openSheet(tester);
      await typeQuery(tester, 'lhc');
      expect(find.text('Central Library'), findsNothing);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();

      expect(find.text('Central Library'), findsOneWidget);
      expect(find.byTooltip('Clear search'), findsNothing);
    });

    testWidgets('tapping a result closes the sheet with that destination', (tester) async {
      await openSheet(tester);
      await typeQuery(tester, 'central');

      await tester.tap(find.text('Central Library'));
      await tester.pumpAndSettle();

      expect(picked, _library);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('marks the selected destination with a check', (tester) async {
      await openSheet(tester, selected: _library);

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.bySemanticsLabel('Central Library'), findsOneWidget);
    });

    testWidgets('pins the extra option for a blank query and hides it for a non-matching one', (tester) async {
      await openSheet(tester, extraOption: _yourLocation);
      expect(find.text('Your Location'), findsOneWidget);

      await typeQuery(tester, 'library');
      expect(find.text('Your Location'), findsNothing);
      expect(find.text('Central Library'), findsOneWidget);
    });

    testWidgets('a query matching the extra option pins it above an empty results list', (tester) async {
      await openSheet(tester, extraOption: _yourLocation);

      await typeQuery(tester, 'your');

      expect(find.text('Your Location'), findsOneWidget);
      expect(find.textContaining('No matching destinations'), findsNothing);
    });

    testWidgets('tapping the pinned extra option returns it', (tester) async {
      await openSheet(tester, extraOption: _yourLocation);

      await tester.tap(find.text('Your Location'));
      await tester.pumpAndSettle();

      expect(picked, _yourLocation);
    });
  });
}
