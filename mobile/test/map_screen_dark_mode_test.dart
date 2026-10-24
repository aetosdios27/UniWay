
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uniway_mobile/core/constants/map_constants.dart';
import 'package:uniway_mobile/data/models/campus_route.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/repositories/routing_repository.dart';
import 'package:uniway_mobile/presentation/controllers/routing_controller.dart';
import 'package:uniway_mobile/presentation/map/map_palette.dart';
import 'package:uniway_mobile/presentation/screens/map_screen.dart';
import 'package:uniway_mobile/presentation/theme/uniway_theme.dart';

class DarkModeFakeMapController extends Fake implements MapLibreMapController {
  final List<LineOptions> addedLines = [];
  final List<Line> lineHandles = [];
  final List<Line> removedLines = [];
  bool disallowRemoveOnStale = false;
  final Set<String> staleHandleIds = {};

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {}

  @override
  Future<void> removeSource(String sourceId) async {}

  @override
  Future<void> removeLayer(String layerId) async {}

  @override
  Future<void> addImage(String name, Uint8List bytes, [bool sdf = false]) async {}

  @override
  Future<List> getLayerIds() async => [];

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {}

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {}

  @override
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson) async {}

  @override
  Future<void> addFillLayer(
    String sourceId,
    String layerId,
    FillLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {}

  @override
  Future<void> addFillExtrusionLayer(
    String sourceId,
    String layerId,
    FillExtrusionLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {}

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    CircleLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {}

  @override
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    LineLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {}

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {}

  @override
  Future<Line> addLine(LineOptions options, [Map<String, dynamic>? data]) async {
    addedLines.add(options);
    final handle = Line('line_${lineHandles.length}', options, data);
    lineHandles.add(handle);
    return handle;
  }

  @override
  Future<void> updateLine(Line line, LineOptions changes) async {}

  @override
  Future<void> removeLine(Line line) async {
    if (disallowRemoveOnStale && staleHandleIds.contains(line.id)) {
      throw StateError('Attempted to call removeLine on dead handle: ${line.id}');
    }
    removedLines.add(line);
  }

  @override
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) async {
    return true;
  }
}

class FakeRoutingRepo implements RoutingRepository {
  final CampusRoute route;

  FakeRoutingRepo({required this.route});

  @override
  Future<DestinationsResult> getDestinations({required String campusId}) async {
    return const DestinationsResult(destinations: [], statusCode: 200);
  }

  @override
  Future<MapPoisResult> getMapPois({required String campusId, String? category}) async {
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
    return RoutingResult(route: route, statusCode: 200, latencyMs: 10);
  }

  @override
  void dispose() {}
}

void main() {
  const sampleRoute = CampusRoute(
    distanceMeters: 120,
    points: [
      LatLng(26.8435, 75.5645),
      LatLng(26.8440, 75.5650),
      LatLng(26.8445, 75.5655),
    ],
    rawCoordinates: [],
    rawFeature: {},
  );

  group('MapScreen Dark Mode Tests', () {
    testWidgets('initial dark theme requests dark style and configures light status bar icons', (tester) async {
      String? requestedStyle;
      final fakeController = DarkModeFakeMapController();

      await tester.pumpWidget(
        MaterialApp(
          theme: UniWayTheme.light(),
          darkTheme: UniWayTheme.dark(),
          themeMode: ThemeMode.dark,
          home: MapScreen(
            mapBuilder: (context, onMapCreated, onStyleLoaded, [style]) {
              requestedStyle = style;
              onMapCreated(fakeController);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      expect(requestedStyle, MapConstants.darkStyleAsset);

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(region.value, SystemUiOverlayStyle.light);
    });

    testWidgets('initial light theme requests liberty style and dark status bar icons', (tester) async {
      String? requestedStyle;
      final fakeController = DarkModeFakeMapController();

      await tester.pumpWidget(
        MaterialApp(
          theme: UniWayTheme.light(),
          darkTheme: UniWayTheme.dark(),
          themeMode: ThemeMode.light,
          home: MapScreen(
            mapBuilder: (context, onMapCreated, onStyleLoaded, [style]) {
              requestedStyle = style;
              onMapCreated(fakeController);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      expect(requestedStyle, MapConstants.openFreeMapLibertyStyle);

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(region.value, SystemUiOverlayStyle.dark);
    });

    testWidgets('switching ThemeMode light->dark changes style, resets stale handles, redraws route on next onStyleLoaded, and disposes cleanly', (tester) async {
      final fakeController = DarkModeFakeMapController();
      final routingRepo = FakeRoutingRepo(route: sampleRoute);
      final routingController = RoutingController(repository: routingRepo);
      final modeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

      String? activeStyle;
      void Function()? triggerStyleLoaded;

      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: modeNotifier,
          builder: (context, mode, _) {
            return MaterialApp(
              themeAnimationDuration: Duration.zero,
              theme: UniWayTheme.light(),
              darkTheme: UniWayTheme.dark(),
              themeMode: mode,
              home: MapScreen(
                controller: routingController,
                mapBuilder: (context, onMapCreated, onStyleLoaded, [style]) {
                  activeStyle = style;
                  triggerStyleLoaded = onStyleLoaded;
                  onMapCreated(fakeController);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      );
      await tester.pump();

      expect(activeStyle, MapConstants.openFreeMapLibertyStyle);

      // Trigger initial style loaded callback
      triggerStyleLoaded!();
      await tester.pump();

      // Trigger route calculation to draw initial route in light mode
      const testOrigin = Destination(
        id: 'D0',
        routingNodeId: 'NODE_0',
        name: 'Gate',
        category: 'gate',
        latitude: 26.8430,
        longitude: 75.5640,
      );
      const testDest = Destination(
        id: 'D1',
        routingNodeId: 'NODE_1',
        name: 'Dome',
        category: 'academic',
        latitude: 26.8445,
        longitude: 75.5655,
      );
      routingController.setOrigin(testOrigin);
      routingController.setDestination(testDest);
      await routingController.fetchRoute();
      await tester.pump();
      await tester.pump();

      // Route drawn with light palette: casing #1E40AF, line #2563EB
      expect(fakeController.addedLines.length, greaterThanOrEqualTo(2));
      final initialActive = fakeController.addedLines.sublist(fakeController.addedLines.length - 2);
      expect(initialActive[0].lineColor, MapPalette.light.routeCasing);
      expect(initialActive[1].lineColor, MapPalette.light.routeLine);

      // Mark the current handles as stale and configure fake controller to throw if removeLine is called on them
      fakeController.staleHandleIds.addAll(fakeController.lineHandles.map((l) => l.id));
      fakeController.disallowRemoveOnStale = true;
      fakeController.addedLines.clear();
      fakeController.removedLines.clear();

      // Switch theme mode to dark at runtime
      modeNotifier.value = ThemeMode.dark;
      await tester.pump();

      // Style string updated to dark style asset
      expect(activeStyle, MapConstants.darkStyleAsset);

      // No dead handles removed!
      expect(fakeController.removedLines, isEmpty);

      // Clear added lines tracker to inspect subsequent route drawing
      fakeController.addedLines.clear();

      // Now native map finishes loading the dark style and invokes onStyleLoaded
      triggerStyleLoaded!();
      await tester.pump();

      // Active route redrawn with dark palette colours: casing #0A1226, line #7DB2FF
            expect(fakeController.addedLines.length, 2);
      expect(fakeController.addedLines[0].lineColor, MapPalette.dark.routeCasing);
      expect(fakeController.addedLines[1].lineColor, MapPalette.dark.routeLine);

      // Verify clean disposal
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);

      routingController.dispose();
      modeNotifier.dispose();
    });

    testWidgets('guard against style switch race when redraw is in flight', (tester) async {
      final fakeController = DarkModeFakeMapController();
      final routingRepo = FakeRoutingRepo(route: sampleRoute);
      final routingController = RoutingController(repository: routingRepo);
      final modeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

      void Function()? triggerStyleLoaded;

      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: modeNotifier,
          builder: (context, mode, _) {
            return MaterialApp(
              themeAnimationDuration: Duration.zero,
              theme: UniWayTheme.light(),
              darkTheme: UniWayTheme.dark(),
              themeMode: mode,
              home: MapScreen(
                controller: routingController,
                mapBuilder: (context, onMapCreated, onStyleLoaded, [style]) {
                  triggerStyleLoaded = onStyleLoaded;
                  onMapCreated(fakeController);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      );
      await tester.pump();

      triggerStyleLoaded!();
      await tester.pump();

      // Rapidly switch theme twice while pumping
      modeNotifier.value = ThemeMode.dark;
      await tester.pump();
      modeNotifier.value = ThemeMode.light;
      await tester.pump();

      triggerStyleLoaded!();
      await tester.pump();

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      routingController.dispose();
      modeNotifier.dispose();
    });
  });
}
