import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniway_mobile/core/services/location_fix.dart';
import 'package:uniway_mobile/core/services/location_snapshot.dart';
import 'package:uniway_mobile/presentation/widgets/location_status_chip.dart';

LocationSnapshot snapshot({
  double accuracyMeters = 8,
  LocationQuality quality = LocationQuality.good,
  bool isStale = false,
  LocationUnavailableReason? unavailableReason,
}) {
  return LocationSnapshot(
    latitude: 26.8435,
    longitude: 75.5645,
    accuracyMeters: accuracyMeters,
    quality: quality,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    isStale: isStale,
    unavailableReason: unavailableReason,
  );
}

Widget host(
  ValueNotifier<LocationSnapshot?> listenable, [
  LocationUnavailableReason? reason,
]) {
  return MaterialApp(
    home: Scaffold(
      body: LocationStatusChip(listenable, reason: reason),
    ),
  );
}

void main() {
  testWidgets('shows a locating state before the first fix', (tester) async {
    final listenable = ValueNotifier<LocationSnapshot?>(null);

    await tester.pumpWidget(host(listenable));

    expect(find.text('Locating…'), findsOneWidget);
  });

  testWidgets('shows a good GPS state with the rounded accuracy', (tester) async {
    final listenable = ValueNotifier<LocationSnapshot?>(null);

    await tester.pumpWidget(host(listenable));
    listenable.value = snapshot(accuracyMeters: 8.4);
    await tester.pump();

    expect(find.text('GPS good · ±8 m'), findsOneWidget);
  });

  testWidgets('shows a fair GPS state', (tester) async {
    final listenable = ValueNotifier<LocationSnapshot?>(null);

    await tester.pumpWidget(host(listenable));
    listenable.value = snapshot(accuracyMeters: 25, quality: LocationQuality.fair);
    await tester.pump();

    expect(find.text('GPS fair · ±25 m'), findsOneWidget);
  });

  testWidgets('shows a weak GPS state with the approximate hint', (tester) async {
    final listenable = ValueNotifier<LocationSnapshot?>(null);

    await tester.pumpWidget(host(listenable));
    listenable.value = snapshot(accuracyMeters: 60, quality: LocationQuality.poor);
    await tester.pump();

    expect(find.text('Weak GPS · ±60 m (location approximate)'), findsOneWidget);
  });

  testWidgets('shows the lost state for a lost quality', (tester) async {
    final listenable = ValueNotifier<LocationSnapshot?>(null);

    await tester.pumpWidget(host(listenable));
    listenable.value = snapshot(quality: LocationQuality.lost);
    await tester.pump();

    expect(
      find.text('Signal lost — showing last known position'),
      findsOneWidget,
    );
  });

  testWidgets('shows the lost state for a stale snapshot', (tester) async {
    final listenable = ValueNotifier<LocationSnapshot?>(null);

    await tester.pumpWidget(host(listenable));
    listenable.value = snapshot(isStale: true);
    await tester.pump();

    expect(
      find.text('Signal lost — showing last known position'),
      findsOneWidget,
    );
  });

  testWidgets('shows a dedicated message when the service is off', (tester) async {
    final listenable = ValueNotifier<LocationSnapshot?>(null);

    await tester.pumpWidget(
      host(listenable, LocationUnavailableReason.serviceDisabled),
    );

    expect(find.text('Location is off'), findsOneWidget);
  });

  testWidgets('shows a dedicated message when permission is denied', (tester) async {
    final listenable = ValueNotifier<LocationSnapshot?>(null);

    await tester.pumpWidget(
      host(listenable, LocationUnavailableReason.permissionDenied),
    );

    expect(find.text('Location permission needed'), findsOneWidget);
  });

  testWidgets('shows a dedicated message for a permanent denial', (tester) async {
    final listenable = ValueNotifier<LocationSnapshot?>(null);

    await tester.pumpWidget(
      host(listenable, LocationUnavailableReason.permissionDeniedForever),
    );

    expect(find.text('Enable location in Settings'), findsOneWidget);
  });

  testWidgets('exposes a full sentence label in a live region', (tester) async {
    final handle = tester.ensureSemantics();
    final listenable = ValueNotifier<LocationSnapshot?>(null);

    await tester.pumpWidget(host(listenable));
    listenable.value = snapshot(accuracyMeters: 8);
    await tester.pump();

    final node = tester.getSemantics(
      find.bySemanticsLabel(
        'GPS signal is good. Your position is accurate to within 8 metres.',
      ),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);

    handle.dispose();
  });

  testWidgets('a snapshot update rebuilds only the chip', (tester) async {
    final listenable = ValueNotifier<LocationSnapshot?>(null);
    var siblingBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LocationStatusChip(listenable),
              Builder(
                builder: (context) {
                  siblingBuilds++;
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(siblingBuilds, 1);
    expect(find.text('Locating…'), findsOneWidget);

    listenable.value = snapshot(accuracyMeters: 8);
    await tester.pump();

    expect(siblingBuilds, 1);
    expect(find.text('GPS good · ±8 m'), findsOneWidget);
  });
}
