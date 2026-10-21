import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/location_fix.dart';
import '../../core/services/location_snapshot.dart';

class LocationStatus {
  final String label;
  final String semanticsLabel;
  final Color color;
  final IconData icon;

  const LocationStatus({
    required this.label,
    required this.semanticsLabel,
    required this.color,
    required this.icon,
  });
}

/// Resolves the chip content for the current snapshot and failure reason.
LocationStatus resolveLocationStatus(
  LocationSnapshot? snapshot,
  LocationUnavailableReason? reason,
) {
  final effectiveReason = snapshot?.unavailableReason ?? reason;

  switch (effectiveReason) {
    case LocationUnavailableReason.serviceDisabled:
      return const LocationStatus(
        label: 'Location is off',
        semanticsLabel: 'Location is turned off on this device.',
        color: Color(0xFF64748B),
        icon: Icons.location_disabled,
      );
    case LocationUnavailableReason.permissionDenied:
      return const LocationStatus(
        label: 'Location permission needed',
        semanticsLabel: 'Location permission is needed to show your position.',
        color: Color(0xFFD97706),
        icon: Icons.lock_outline,
      );
    case LocationUnavailableReason.permissionDeniedForever:
      return const LocationStatus(
        label: 'Enable location in Settings',
        semanticsLabel: 'Enable location in Settings to show your position.',
        color: Color(0xFFDC2626),
        icon: Icons.settings,
      );
    case LocationUnavailableReason.signalLost:
      return const LocationStatus(
        label: 'Signal lost — showing last known position',
        semanticsLabel: 'GPS signal lost. Showing the last known position.',
        color: Color(0xFF9CA3AF),
        icon: Icons.location_off,
      );
    case null:
      break;
  }

  if (snapshot == null) {
    return const LocationStatus(
      label: 'Locating…',
      semanticsLabel: 'Locating your position.',
      color: Color(0xFF64748B),
      icon: Icons.my_location,
    );
  }

  if (snapshot.isStale || snapshot.quality == LocationQuality.lost) {
    return const LocationStatus(
      label: 'Signal lost — showing last known position',
      semanticsLabel: 'GPS signal lost. Showing the last known position.',
      color: Color(0xFF9CA3AF),
      icon: Icons.location_off,
    );
  }

  final meters = snapshot.accuracyMeters.round();
  switch (snapshot.quality) {
    case LocationQuality.good:
      return LocationStatus(
        label: 'GPS good · ±$meters m',
        semanticsLabel:
            'GPS signal is good. Your position is accurate to within $meters metres.',
        color: const Color(0xFF2563EB),
        icon: Icons.gps_fixed,
      );
    case LocationQuality.fair:
      return LocationStatus(
        label: 'GPS fair · ±$meters m',
        semanticsLabel:
            'GPS signal is fair. Your position is accurate to within $meters metres.',
        color: const Color(0xFFF59E0B),
        icon: Icons.gps_not_fixed,
      );
    case LocationQuality.poor:
      return LocationStatus(
        label: 'Weak GPS · ±$meters m (location approximate)',
        semanticsLabel:
            'GPS signal is weak. Your position is accurate to within $meters metres and may be approximate.',
        color: const Color(0xFFF97316),
        icon: Icons.warning_amber_rounded,
      );
    case LocationQuality.lost:
      return const LocationStatus(
        label: 'Signal lost — showing last known position',
        semanticsLabel: 'GPS signal lost. Showing the last known position.',
        color: Color(0xFF9CA3AF),
        icon: Icons.location_off,
      );
  }
}

class LocationStatusChip extends StatelessWidget {
  final ValueListenable<LocationSnapshot?> listenable;
  final LocationUnavailableReason? reason;

  const LocationStatusChip(
    this.listenable, {
    super.key,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LocationSnapshot?>(
      valueListenable: listenable,
      builder: (context, snapshot, _) {
        final status = resolveLocationStatus(snapshot, reason);
        return Semantics(
          container: true,
          liveRegion: true,
          label: status.semanticsLabel,
          child: ExcludeSemantics(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: status.color.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(status.icon, size: 16, color: status.color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      status.label,
                      style: TextStyle(
                        color: status.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
