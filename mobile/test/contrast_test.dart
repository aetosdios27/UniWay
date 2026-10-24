import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:maplibre_gl/maplibre_gl.dart";
import "package:uniway_mobile/core/services/location_fix.dart";
import "package:uniway_mobile/core/services/location_snapshot.dart";
import "package:uniway_mobile/data/models/campus_route.dart";
import "package:uniway_mobile/data/models/destination.dart";
import "package:uniway_mobile/data/models/user.dart";
import "package:uniway_mobile/presentation/controllers/auth_controller.dart";
import "package:uniway_mobile/presentation/controllers/routing_controller.dart";
import "package:uniway_mobile/presentation/search/destination_search_sheet.dart";
import "package:uniway_mobile/presentation/theme/uniway_theme.dart";
import "package:uniway_mobile/presentation/widgets/location_status_chip.dart";
import "package:uniway_mobile/presentation/widgets/profile_badge.dart";
import "package:uniway_mobile/presentation/widgets/route_picker_card.dart";
import "package:uniway_mobile/presentation/widgets/route_start_notice.dart";
import "package:uniway_mobile/presentation/widgets/route_status_banner.dart";
import "support/contrast.dart";
import "support/fake_auth_repository.dart";

class FakeRoutingController extends ChangeNotifier implements RoutingController {
  @override
  CampusRoute? currentRoute;

  @override
  String? errorMessage;

  @override
  bool isRouteStartApproximate = false;

  @override
  Destination? origin;

  @override
  Destination? destination;

  @override
  bool isGpsOrigin = true;

  @override
  bool isLoading = false;

  @override
  bool isLocating = false;

  @override
  bool canGo = true;

  @override
  bool isLoadingDestinations = false;

  @override
  String? destinationsError;

  @override
  List<Destination> destinations = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LocationSnapshot makeSnapshot({
  double accuracyMeters = 8.0,
  LocationQuality quality = LocationQuality.good,
  bool isStale = false,
  LocationUnavailableReason? unavailableReason,
}) {
  return LocationSnapshot(
    latitude: 26.8435,
    longitude: 75.5645,
    accuracyMeters: accuracyMeters,
    quality: quality,
    timestamp: DateTime.now(),
    isStale: isStale,
    unavailableReason: unavailableReason,
  );
}

const mockRoute = CampusRoute(
  distanceMeters: 320.0,
  points: [LatLng(26.8438, 75.5652), LatLng(26.8445, 75.5660)],
  rawCoordinates: [
    [75.5652, 26.8438],
    [75.5660, 26.8445],
  ],
  rawFeature: {},
);

const testDestination = Destination(
  id: "DEST_1",
  routingNodeId: "NODE_1",
  name: "Central Library",
  category: "study",
  latitude: 26.8445,
  longitude: 75.5660,
);

void main() {
  final themes = <String, ThemeData Function()>{
    "Light": UniWayTheme.light,
    "Dark": UniWayTheme.dark,
  };

  for (final themeEntry in themes.entries) {
    final themeName = themeEntry.key;
    final getTheme = themeEntry.value;

    group("Contrast ratios under $themeName theme", () {
      group("LocationStatusChip contrast pairs >= 4.5:1", () {
        final cases = <String, (LocationSnapshot?, LocationUnavailableReason?)>{
          "null fix / locating": (null, null),
          "good GPS": (makeSnapshot(accuracyMeters: 8, quality: LocationQuality.good), null),
          "fair GPS": (makeSnapshot(accuracyMeters: 22, quality: LocationQuality.fair), null),
          "poor / weak GPS": (makeSnapshot(accuracyMeters: 55, quality: LocationQuality.poor), null),
          "lost GPS": (makeSnapshot(quality: LocationQuality.lost), null),
          "stale snapshot": (makeSnapshot(isStale: true), null),
          "service off": (null, LocationUnavailableReason.serviceDisabled),
          "permission denied": (null, LocationUnavailableReason.permissionDenied),
          "permission permanently denied": (null, LocationUnavailableReason.permissionDeniedForever),
          "signal lost reason": (null, LocationUnavailableReason.signalLost),
        };

        for (final entry in cases.entries) {
          testWidgets("renders readable text for ${entry.key}", (tester) async {
            final theme = getTheme();
            final snapshot = entry.value.$1;
            final reason = entry.value.$2;
            final listenable = ValueNotifier<LocationSnapshot?>(snapshot);

            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Scaffold(
                  body: LocationStatusChip(listenable, reason: reason),
                ),
              ),
            );

            final chipContainer = tester.widget<Container>(
              find.descendant(
                of: find.byType(LocationStatusChip),
                matching: find.byType(Container),
              ).first,
            );
            final boxDecoration = chipContainer.decoration as BoxDecoration;
            final bg = boxDecoration.color ?? theme.colorScheme.surface;

            final chipText = tester.widget<Text>(
              find.descendant(
                of: find.byType(LocationStatusChip),
                matching: find.byType(Text),
              ).first,
            );
            final fg = chipText.style?.color ?? theme.colorScheme.onSurface;

            final ratio = contrastRatio(fg, bg);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason: "Contrast for ${entry.key} ($fg on $bg) was $ratio:1, expected >= 4.5:1",
            );
          });
        }
      });

      testWidgets("RoutePickerCard route-found pill contrast >= 4.5:1", (tester) async {
        final theme = getTheme();
        final controller = FakeRoutingController()..currentRoute = mockRoute;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: RoutePickerCard(controller: controller),
            ),
          ),
        );

        final walkIcon = find.byIcon(Icons.directions_walk);
        final pillContainer = tester.widget<Container>(
          find.ancestor(of: walkIcon, matching: find.byType(Container)).first,
        );
        final boxDecoration = pillContainer.decoration as BoxDecoration;
        final bg = boxDecoration.color!;

        final pillText = tester.widget<Text>(
          find.descendant(
            of: find.ancestor(of: walkIcon, matching: find.byType(Container)).first,
            matching: find.byType(Text),
          ).first,
        );
        final fg = pillText.style?.color ?? theme.colorScheme.onSurface;

        final ratio = contrastRatio(fg, bg);
        expect(ratio, greaterThanOrEqualTo(4.5));
      });

      testWidgets("RouteStatusBanner error text and Retry button contrast >= 4.5:1", (tester) async {
        final theme = getTheme();
        final controller = FakeRoutingController()..errorMessage = "Route calculation failed";

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: RouteStatusBanner(controller: controller),
            ),
          ),
        );

        final bannerContainer = tester.widget<Container>(
          find.descendant(
            of: find.byType(RouteStatusBanner),
            matching: find.byType(Container),
          ).first,
        );
        final boxDecoration = bannerContainer.decoration as BoxDecoration;
        final bg = boxDecoration.color!;

        final errorText = tester.widget<Text>(find.text("Route calculation failed"));
        final errorFg = errorText.style?.color ?? theme.colorScheme.onSurface;
        expect(contrastRatio(errorFg, bg), greaterThanOrEqualTo(4.5));

        final retryText = tester.widget<Text>(find.text("Retry"));
        final retryFg = retryText.style?.color ?? theme.colorScheme.onSurface;
        expect(contrastRatio(retryFg, bg), greaterThanOrEqualTo(4.5));
      });

      testWidgets("RouteStartNotice notice text contrast >= 4.5:1", (tester) async {
        final theme = getTheme();
        final controller = FakeRoutingController()
          ..currentRoute = mockRoute
          ..isRouteStartApproximate = true;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: RouteStartNotice(controller: controller),
            ),
          ),
        );

        final noticeContainer = tester.widget<Container>(
          find.descendant(
            of: find.byType(RouteStartNotice),
            matching: find.byType(Container),
          ).first,
        );
        final boxDecoration = noticeContainer.decoration as BoxDecoration;
        final bg = boxDecoration.color!;

        final noticeText = tester.widget<Text>(
          find.descendant(
            of: find.byType(RouteStartNotice),
            matching: find.byType(Text),
          ).first,
        );
        final fg = noticeText.style?.color ?? theme.colorScheme.onSurface;

        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(4.5));
      });

      testWidgets("ProfileBadge guest and signed-in label contrast >= 4.5:1", (tester) async {
        final theme = getTheme();
        final repo = FakeAuthRepository()..mockGuest = true;
        final authController = AuthController(repository: repo);
        await authController.initialize();

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: ProfileBadge(authController: authController),
            ),
          ),
        );

        final badgeContainer = tester.widget<Container>(
          find.descendant(
            of: find.byType(ProfileBadge),
            matching: find.byType(Container),
          ).first,
        );
        final shapeDecoration = badgeContainer.decoration as ShapeDecoration;
        final bg = shapeDecoration.color ?? theme.colorScheme.surface;

        final guestText = tester.widget<Text>(find.text("Guest"));
        final fg = guestText.style?.color ?? theme.colorScheme.onSurface;
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(4.5));

        // Signed-in user
        repo
          ..mockToken = "token-user"
          ..mockUser = const User(
            id: "u-1",
            email: "bob@example.com",
            name: "Bob Vance",
            authProvider: "email",
          );
        await authController.initialize();
        await tester.pumpAndSettle();

        final userText = tester.widget<Text>(find.text("Bob"));
        final userFg = userText.style?.color ?? theme.colorScheme.onSurface;
        expect(contrastRatio(userFg, bg), greaterThanOrEqualTo(4.5));
      });

      testWidgets("search sheet tile title and category contrast >= 4.5:1", (tester) async {
        final theme = getTheme();

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDestinationSearchSheet(
                    context,
                    destinations: [testDestination],
                    title: "Select",
                  ),
                  child: const Text("Open"),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text("Open"));
        await tester.pumpAndSettle();

        final tile = find.widgetWithText(ListTile, "Central Library");
        expect(tile, findsOneWidget);

        final sheetSurface = theme.colorScheme.surface;
        final titleText = tester.widget<Text>(find.text("Central Library"));
        final titleFg = titleText.style?.color ?? theme.colorScheme.onSurface;
        expect(contrastRatio(titleFg, sheetSurface), greaterThanOrEqualTo(4.5));

        final categoryText = tester.widget<Text>(find.text("study"));
        final categoryFg = categoryText.style?.color ?? theme.colorScheme.onSurfaceVariant;
        expect(contrastRatio(categoryFg, sheetSurface), greaterThanOrEqualTo(4.5));
      });
    });
  }
}
