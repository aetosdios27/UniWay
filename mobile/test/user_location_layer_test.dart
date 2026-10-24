import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uniway_mobile/core/services/location_fix.dart';
import 'package:uniway_mobile/core/services/location_snapshot.dart';
import 'package:uniway_mobile/core/utils/geo_distance.dart';
import 'package:uniway_mobile/data/models/campus_route.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/repositories/routing_repository.dart';
import 'package:uniway_mobile/presentation/controllers/routing_controller.dart';
import 'package:uniway_mobile/presentation/map/user_location_layer.dart';
import 'package:uniway_mobile/presentation/screens/map_screen.dart';
import 'package:uniway_mobile/presentation/widgets/location_status_chip.dart';

class RecordingUserLocationSink implements UserLocationMapSink {
  final List<Map<String, dynamic>> sourceUpdates = [];
  final Set<String> layerIds = {};
  int addSourceCalls = 0;
  int removeLayersCalls = 0;
  Completer<void>? updateGate;

  RecordingUserLocationSink({this.updateGate});

  @override
  Future<void> addSource(String sourceId) async {
    addSourceCalls++;
  }

  @override
  Future<void> setSource(String sourceId, Map<String, dynamic> geojson) async {
    sourceUpdates.add(geojson);
    final gate = updateGate;
    if (gate != null && sourceUpdates.length == 1) {
      await gate.future;
    }
  }

  @override
  Future<void> addLayers(String sourceId) async {
    layerIds.addAll(const [
      userLocationAccuracyFillLayerId,
      userLocationAccuracyOutlineLayerId,
      userLocationAccuracyLostLayerId,
      userLocationDotLayerId,
    ]);
  }

  @override
  Future<void> removeLayers() async {
    removeLayersCalls++;
    layerIds.clear();
  }
}

LocationSnapshot snapshotAt(
  double latitude,
  double longitude, {
  double accuracyMeters = 8,
  LocationQuality quality = LocationQuality.good,
  bool isStale = false,
  LocationUnavailableReason? unavailableReason,
}) {
  return LocationSnapshot(
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: accuracyMeters,
    quality: quality,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    isStale: isStale,
    unavailableReason: unavailableReason,
  );
}

double metersBetween(LatLng a, LatLng b) =>
    haversineMeters(a.latitude, a.longitude, b.latitude, b.longitude);

double distanceToSegment(LatLng point, LatLng a, LatLng b) {
  final ax = a.longitude;
  final ay = a.latitude;
  final bx = b.longitude;
  final by = b.latitude;
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) return metersBetween(point, a);
  final t = (((point.longitude - ax) * dx + (point.latitude - ay) * dy) /
          lengthSquared)
      .clamp(0.0, 1.0);
  final projection = LatLng(ay + t * dy, ax + t * dx);
  return metersBetween(point, projection);
}

class RecordingMapLibreController extends Fake implements MapLibreMapController {
  final List<String> addedSources = [];
  final List<String> addedLayers = [];
  final List<String> removedLayers = [];

  @override
  Future<void> removeSource(String sourceId) async {}

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) async {
    addedSources.add(sourceId);
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {}

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
  }) async {
    addedLayers.add(layerId);
  }

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
  }) async {
    addedLayers.add(layerId);
  }

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
  }) async {
    addedLayers.add(layerId);
  }

  @override
  Future<void> removeLayer(String layerId) async {
    removedLayers.add(layerId);
  }
}

class EmptyRoutingRepo implements RoutingRepository {
  @override
  Future<DestinationsResult> getDestinations({required String campusId}) async {
    return const DestinationsResult(destinations: [], statusCode: 200);
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
        distanceMeters: 0,
        points: [],
        rawCoordinates: [],
        rawFeature: {},
      ),
      statusCode: 200,
      latencyMs: 1,
    );
  }

  @override
  void dispose() {}
}

void main() {
  group('accuracyCirclePolygon', () {
    const center = LatLng(26.8435, 75.5645);

    test('keeps the radius within 1% for 5, 30 and 100 metres', () {
      for (final meters in [5.0, 30.0, 100.0]) {
        final polygon = accuracyCirclePolygon(center, meters);

        for (final point in polygon) {
          expect(
            metersBetween(center, point),
            closeTo(meters, meters * 0.01),
            reason: 'vertex distance for $meters m',
          );
        }
      }
    });

    test('inscribed edge distance stays within 1% of the radius', () {
      for (final meters in [5.0, 30.0, 100.0]) {
        final polygon = accuracyCirclePolygon(center, meters);
        var smallest = double.infinity;

        for (var i = 0; i < polygon.length - 1; i++) {
          final distance =
              distanceToSegment(center, polygon[i], polygon[i + 1]);
          if (distance < smallest) smallest = distance;
        }

        expect(smallest, closeTo(meters, meters * 0.01));
      }
    });

    test('returns 48 distinct vertices plus a closing point', () {
      final polygon = accuracyCirclePolygon(center, 30);

      expect(polygon.length, userLocationAccuracyVertexCount + 1);
      expect({
        for (final point in polygon) '${point.latitude},${point.longitude}',
      }, hasLength(userLocationAccuracyVertexCount));
      expect(polygon.first.latitude, polygon.last.latitude);
      expect(polygon.first.longitude, polygon.last.longitude);
    });

    test('spaces every segment, including the closing edge, evenly', () {
      final polygon = accuracyCirclePolygon(center, 30);
      const vertices = userLocationAccuracyVertexCount;
      const step = 2 * math.pi / vertices;

      // Direction of each vertex in a local metric frame; the generator places
      // vertex i at angle i * step, so consecutive deltas must all be equal.
      const metersPerDegree = 6371000.0 * math.pi / 180.0;
      final cosLat = math.cos(center.latitude * math.pi / 180.0);
      final angles = [
        for (final point in polygon.take(vertices))
          math.atan2(
            (point.longitude - center.longitude) * metersPerDegree * cosLat,
            (point.latitude - center.latitude) * metersPerDegree,
          ),
      ];
      for (var i = 0; i < angles.length; i++) {
        var delta = angles[(i + 1) % angles.length] - angles[i];
        if (delta < 0) delta += 2 * math.pi;
        expect(delta, closeTo(step, 1e-6), reason: 'angular step at vertex $i');
      }

      // Equal angles mean equal chord lengths, so the closing edge (from the
      // last distinct vertex back to the first) must match the others.
      final chords = [
        for (var i = 0; i < polygon.length - 1; i++)
          metersBetween(polygon[i], polygon[i + 1]),
      ];
      expect(chords, hasLength(vertices));
      for (final chord in chords) {
        expect(chord, closeTo(chords.first, 1e-3));
      }
      expect(chords.first, greaterThan(0));
    });

    test('degrades to the center for a non positive radius', () {
      final polygon = accuracyCirclePolygon(center, 0);

      expect(polygon.length, 2);
      expect(polygon.first.latitude, center.latitude);
      expect(polygon.first.longitude, center.longitude);
    });
  });

  group('buildUserLocationGeoJson', () {
    test('contains one accuracy polygon and one point with the quality', () {
      final geoJson = buildUserLocationGeoJson(
        snapshotAt(26.8435, 75.5645, quality: LocationQuality.fair),
      );

      final features = geoJson['features'] as List;
      expect(features.length, 2);

      final polygon = features.first as Map<String, dynamic>;
      expect(polygon['geometry']['type'], 'Polygon');
      expect(polygon['properties']['quality'], 'fair');

      final point = features.last as Map<String, dynamic>;
      expect(point['geometry']['type'], 'Point');
      final coordinates = point['geometry']['coordinates'] as List;
      expect(coordinates[0], closeTo(75.5645, 1e-9));
      expect(coordinates[1], closeTo(26.8435, 1e-9));
      expect(point['properties']['quality'], 'fair');
    });

    test('marks a stale snapshot as lost', () {
      final geoJson = buildUserLocationGeoJson(
        snapshotAt(26.8435, 75.5645, isStale: true),
      );

      final features = geoJson['features'] as List;
      final point = features.last as Map<String, dynamic>;
      expect(point['properties']['quality'], 'lost');
      expect(point['properties']['stale'], isTrue);
    });

    test('omits the accuracy polygon without a usable radius', () {
      final geoJson = buildUserLocationGeoJson(
        snapshotAt(26.8435, 75.5645, accuracyMeters: 0),
      );

      final features = geoJson['features'] as List;
      expect(features.length, 1);
      expect((features.first as Map<String, dynamic>)['geometry']['type'],
          'Point');
    });
  });

  group('UserLocationLayer', () {
    test('attach creates the source and the layers', () async {
      final sink = RecordingUserLocationSink();
      final layer = UserLocationLayer(sink: sink);

      await layer.attach();

      expect(sink.addSourceCalls, 1);
      expect(sink.layerIds.length, 4);
      expect(layer.isAttached, isTrue);
    });

    test('attach and detach are idempotent', () async {
      final sink = RecordingUserLocationSink();
      final layer = UserLocationLayer(sink: sink);

      await layer.attach();
      await layer.attach();
      expect(sink.layerIds.length, 4);

      await layer.detach();
      await layer.detach();
      expect(sink.layerIds, isEmpty);
      expect(layer.isAttached, isFalse);
    });

    test('coalesces rapid snapshots into a single follow up update', () async {
      final gate = Completer<void>();
      final sink = RecordingUserLocationSink(updateGate: gate);
      final layer = UserLocationLayer(sink: sink);
      await layer.attach();

      final pending = <Future<void>>[];
      for (var i = 0; i < 10; i++) {
        pending.add(layer.update(snapshotAt(26.8400 + i * 0.0001, 75.5600)));
      }

      expect(sink.sourceUpdates.length, 1);

      gate.complete();
      await pending.last;

      expect(sink.sourceUpdates.length, 2);

      final features =
          sink.sourceUpdates.last['features'] as List;
      final point = features.last as Map<String, dynamic>;
      expect(point['geometry']['coordinates'][1], closeTo(26.8409, 1e-9));
    });

    test('a single snapshot produces exactly one source update', () async {
      final sink = RecordingUserLocationSink();
      final layer = UserLocationLayer(sink: sink);
      await layer.attach();

      await layer.update(snapshotAt(26.8435, 75.5645));

      expect(sink.sourceUpdates.length, 1);
    });

    test('a snapshot queued before attach is rendered on attach', () async {
      final sink = RecordingUserLocationSink();
      final layer = UserLocationLayer(sink: sink);

      final pending = layer.update(snapshotAt(26.8435, 75.5645));
      expect(sink.sourceUpdates, isEmpty);

      await layer.attach();
      await pending;

      expect(sink.sourceUpdates.length, 1);
    });

    test('is inert after dispose', () async {
      final sink = RecordingUserLocationSink();
      final layer = UserLocationLayer(sink: sink);

      await layer.attach();
      layer.dispose();

      await layer.update(snapshotAt(26.8435, 75.5645));
      await layer.attach();

      expect(sink.sourceUpdates, isEmpty);
      expect(sink.addSourceCalls, 1);
    });
  });

  group('MapScreen wiring', () {
    testWidgets('attaches the user location layer on style load', (tester) async {
      final map = RecordingMapLibreController();
      final controller = RoutingController(repository: EmptyRoutingRepo());

      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            controller: controller,
            mapBuilder: (context, onMapCreated, onStyleLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onMapCreated(map);
                onStyleLoaded();
              });
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(map.addedSources, contains(userLocationSourceId));
      expect(map.addedLayers, contains(userLocationAccuracyFillLayerId));
      expect(map.addedLayers, contains(userLocationDotLayerId));
      expect(find.byType(LocationStatusChip), findsOneWidget);
      expect(find.text('Locating…'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });
}
