import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniway_mobile/data/models/campus_route.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/models/user.dart';
import 'package:uniway_mobile/data/repositories/routing_repository.dart';
import 'package:uniway_mobile/presentation/controllers/auth_controller.dart';
import 'package:uniway_mobile/presentation/controllers/routing_controller.dart';
import 'package:uniway_mobile/presentation/screens/map_screen.dart';

import 'support/fake_auth_repository.dart';

class StubRoutingRepository implements RoutingRepository {
  final List<Destination> destinations;

  StubRoutingRepository(this.destinations);

  @override
  Future<DestinationsResult> getDestinations({required String campusId}) async {
    return DestinationsResult(destinations: destinations, statusCode: 200);
  }

  @override
  Future<MapPoisResult> getMapPois({
    required String campusId,
    String? category,
  }) async {
    return const MapPoisResult(pois: [], statusCode: 200);
  }

  @override
  Future<RoutingResult> getRoute({
    required String campusId,
    Destination? origin,
    double? fromLng,
    double? fromLat,
    required Destination destination,
    bool accessible = false,
  }) async {
    return const RoutingResult(
      route: CampusRoute(
        distanceMeters: 100,
        points: [LatLng(26.8, 75.5), LatLng(26.9, 75.6)],
        rawCoordinates: [],
        rawFeature: {},
      ),
      statusCode: 200,
      latencyMs: 10,
    );
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<(Widget, RoutingController)> buildScreen(AuthController authController) async {
    final routingController = RoutingController(
      repository: StubRoutingRepository(const [
        Destination(
          id: 'D1',
          routingNodeId: 'NODE_1',
          name: 'Dome',
          category: 'academic',
          latitude: 26.84,
          longitude: 75.56,
        ),
      ]),
    );
    await routingController.loadDestinations();

    final screen = MaterialApp(
      home: MapScreen(
        controller: routingController,
        authController: authController,
        mapBuilder: (context, onMapCreated, onStyleLoaded) => const ColoredBox(color: Colors.grey),
      ),
    );

    return (screen, routingController);
  }

  group('Map-first guest flow', () {
    testWidgets('first-time users see a dismissible auth sheet over the map', (tester) async {
      final authController = AuthController(repository: FakeAuthRepository());
      final (screen, routingController) = await buildScreen(authController);

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      expect(find.text('Sign in to UniWay'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(find.text('UniWay'), findsOneWidget);

      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to UniWay'), findsNothing);
      expect(find.text('Continue as Guest'), findsNothing);
      expect(authController.isGuest, true);
      expect(authController.isAuthenticated, false);
      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.text('Guest'), findsOneWidget);

      authController.dispose();
      routingController.dispose();
    });

    testWidgets('returning guests are not prompted again', (tester) async {
      final authController = AuthController(
        repository: FakeAuthRepository()..mockGuest = true,
      );
      final (screen, routingController) = await buildScreen(authController);

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      expect(find.text('Sign in to UniWay'), findsNothing);
      expect(find.text('Guest'), findsOneWidget);

      authController.dispose();
      routingController.dispose();
    });

    testWidgets('signed-in users are not prompted', (tester) async {
      final authController = AuthController(
        repository: FakeAuthRepository()
          ..mockToken = 'valid-jwt'
          ..mockUser = const User(
            id: 'u-1',
            email: 'alice@example.com',
            name: 'Alice Smith',
            authProvider: 'email',
          ),
      );
      final (screen, routingController) = await buildScreen(authController);

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      expect(find.text('Sign in to UniWay'), findsNothing);
      expect(find.text('Alice'), findsOneWidget);

      authController.dispose();
      routingController.dispose();
    });

    testWidgets('the profile badge opens the profile sheet while browsing as a guest', (tester) async {
      final authController = AuthController(repository: FakeAuthRepository());
      await authController.continueAsGuest();
      final (screen, routingController) = await buildScreen(authController);

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guest'));
      await tester.pumpAndSettle();

      expect(find.text('Guest User'), findsOneWidget);
      expect(find.text('Sign In or Register'), findsOneWidget);
      expect(find.text('UniWay'), findsOneWidget);

      authController.dispose();
      routingController.dispose();
    });
  });
}
