import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uniway_mobile/core/utils/geo_distance.dart';
import 'package:uniway_mobile/presentation/map/route_start_connector.dart';

class RecordingMapController extends Fake implements MapLibreMapController {
  final List<Line> addedLines = [];
  final List<Line> updatedLines = [];
  final List<Line> removedLines = [];

  @override
  Future<Line> addLine(LineOptions options, [Map<String, dynamic>? data]) async {
    final line = Line('line_${addedLines.length}', options, data);
    addedLines.add(line);
    return line;
  }

  @override
  Future<void> updateLine(Line line, LineOptions changes) async {
    updatedLines.add(line);
  }

  @override
  Future<void> removeLine(Line line) async {
    removedLines.add(line);
  }
}

void main() {
  const user = LatLng(26.8435, 75.5645);

  LatLng offsetNorth(double meters) {
    return LatLng(user.latitude + meters / 111195.0, user.longitude);
  }

  group('shouldDrawStartConnector', () {
    test('is false when the route start is within three metres', () {
      final near = offsetNorth(2);

      expect(
        haversineMeters(
          user.latitude,
          user.longitude,
          near.latitude,
          near.longitude,
        ),
        closeTo(2, 0.05),
      );
      expect(shouldDrawStartConnector(user, near), isFalse);
    });

    test('is false for an identical position', () {
      expect(shouldDrawStartConnector(user, user), isFalse);
    });

    test('is true when the route start is further than three metres', () {
      final far = offsetNorth(12);

      expect(
        haversineMeters(
          user.latitude,
          user.longitude,
          far.latitude,
          far.longitude,
        ),
        closeTo(12, 0.1),
      );
      expect(shouldDrawStartConnector(user, far), isTrue);
    });
  });

  group('RouteStartConnector', () {
    test('reuses a single line and updates its geometry', () async {
      final map = RecordingMapController();
      final connector = RouteStartConnector();

      await connector.update(map, user, offsetNorth(12));
      await connector.update(map, user, offsetNorth(20));

      expect(map.addedLines.length, 1);
      expect(map.updatedLines.length, 1);
      expect(map.removedLines, isEmpty);
    });

    test('removes the line when the positions are close enough', () async {
      final map = RecordingMapController();
      final connector = RouteStartConnector();

      await connector.update(map, user, offsetNorth(12));
      await connector.update(map, user, offsetNorth(1));

      expect(map.addedLines.length, 1);
      expect(map.removedLines.length, 1);
    });

    test('does not draw a line when the positions are close enough', () async {
      final map = RecordingMapController();
      final connector = RouteStartConnector();

      await connector.update(map, user, offsetNorth(1));

      expect(map.addedLines, isEmpty);
      expect(map.removedLines, isEmpty);
    });
  });
}
