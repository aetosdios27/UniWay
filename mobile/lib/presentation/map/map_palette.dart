import 'package:flutter/material.dart';

/// Central palette of colors used across UniWay's custom map layers and annotations.
///
/// Keeps visual styles consistent between light and dark themes and guarantees
/// contrast ratios for overlays and labels.
class MapPalette {
  final Brightness brightness;

  // Supplementary layers
  final String buildingFill;
  final String buildingOutline;
  final String buildingOutlineLowZoom;
  final String buildingExtrusion;
  final String buildingLabelText;
  final String buildingLabelHalo;

  // Destination layers
  final String destinationLabelText;
  final String destinationLabelHalo;
  final String destinationCircleFill;
  final String destinationCircleStroke;
  final String destinationOriginRing;
  final String destinationDestinationRing;

  // POI layers
  final String poiLabelText;
  final String poiLabelHalo;
  final String poiFallbackCircle;
  final String poiFallbackCircleStroke;

  // User location layer
  final String userLocationGood;
  final String userLocationFair;
  final String userLocationPoor;
  final String userLocationLost;
  final String userLocationDotRing;

  // Route start connector
  final String connectorColor;
  final double connectorOpacity;

  // Active route line & casing
  final String routeLine;
  final double routeLineOpacity;
  final String routeCasing;
  final double routeCasingOpacity;

  const MapPalette({
    required this.brightness,
    required this.buildingFill,
    required this.buildingOutline,
    required this.buildingOutlineLowZoom,
    required this.buildingExtrusion,
    required this.buildingLabelText,
    required this.buildingLabelHalo,
    required this.destinationLabelText,
    required this.destinationLabelHalo,
    required this.destinationCircleFill,
    required this.destinationCircleStroke,
    required this.destinationOriginRing,
    required this.destinationDestinationRing,
    required this.poiLabelText,
    required this.poiLabelHalo,
    required this.poiFallbackCircle,
    required this.poiFallbackCircleStroke,
    required this.userLocationGood,
    required this.userLocationFair,
    required this.userLocationPoor,
    required this.userLocationLost,
    required this.userLocationDotRing,
    required this.connectorColor,
    required this.connectorOpacity,
    required this.routeLine,
    required this.routeLineOpacity,
    required this.routeCasing,
    required this.routeCasingOpacity,
  });

  static const light = MapPalette(
    brightness: Brightness.light,
    buildingFill: 'hsl(35,8%,85%)',
    buildingOutline: 'hsl(35,6%,79%)',
    buildingOutlineLowZoom: 'hsla(35,6%,79%,0.32)',
    buildingExtrusion: 'hsl(35,8%,85%)',
    buildingLabelText: '#666666',
    buildingLabelHalo: '#ffffff',
    destinationLabelText: '#1E293B',
    destinationLabelHalo: '#FFFFFF',
    destinationCircleFill: '#2563EB',
    destinationCircleStroke: '#FFFFFF',
    destinationOriginRing: '#16A34A',
    destinationDestinationRing: '#DC2626',
    poiLabelText: '#334155',
    poiLabelHalo: '#FFFFFF',
    poiFallbackCircle: '#64748B',
    poiFallbackCircleStroke: '#FFFFFF',
    userLocationGood: '#2563EB',
    userLocationFair: '#F59E0B',
    userLocationPoor: '#F97316',
    userLocationLost: '#9CA3AF',
    userLocationDotRing: '#FFFFFF',
    connectorColor: '#64748B',
    connectorOpacity: 0.45,
    routeLine: '#2563EB',
    routeLineOpacity: 0.95,
    routeCasing: '#1E40AF',
    routeCasingOpacity: 0.5,
  );

  static const dark = MapPalette(
    brightness: Brightness.dark,
    buildingFill: '#1B2432',
    buildingOutline: '#2A3548',
    buildingOutlineLowZoom: 'hsla(218, 29%, 16%, 0.4)',
    buildingExtrusion: '#202A3B',
    buildingLabelText: '#9AA7BD',
    buildingLabelHalo: '#0E1420',
    destinationLabelText: '#E7ECF5',
    destinationLabelHalo: '#0E1420',
    destinationCircleFill: '#5B9DFF',
    destinationCircleStroke: '#FFFFFF',
    destinationOriginRing: '#4ADE80',
    destinationDestinationRing: '#F87171',
    poiLabelText: '#C5CEDC',
    poiLabelHalo: '#0E1420',
    poiFallbackCircle: '#9AA7BD',
    poiFallbackCircleStroke: '#FFFFFF',
    userLocationGood: '#5B9DFF',
    userLocationFair: '#FBBF24',
    userLocationPoor: '#FB923C',
    userLocationLost: '#9AA7BD',
    userLocationDotRing: '#FFFFFF',
    connectorColor: '#9AA7BD',
    connectorOpacity: 0.60,
    routeLine: '#7DB2FF',
    routeLineOpacity: 0.95,
    routeCasing: '#0A1226',
    routeCasingOpacity: 0.5,
  );

  static MapPalette forBrightness(Brightness brightness) {
    switch (brightness) {
      case Brightness.light:
        return light;
      case Brightness.dark:
        return dark;
    }
  }
}
