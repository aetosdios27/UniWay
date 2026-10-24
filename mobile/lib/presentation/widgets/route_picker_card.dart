import 'package:flutter/material.dart';
import '../../data/models/destination.dart';
import '../controllers/routing_controller.dart';
import '../search/destination_search_sheet.dart';
import '../theme/uniway_theme.dart';

class RoutePickerCard extends StatelessWidget {
  final RoutingController controller;
  final ValueChanged<Destination>? onDestinationFocused;

  static const yourLocation = Destination(
    id: 'YOUR_LOCATION',
    routingNodeId: 'GPS',
    name: 'Your Location',
    category: 'gps',
    latitude: 0,
    longitude: 0,
  );

  const RoutePickerCard({
    super.key,
    required this.controller,
    this.onDestinationFocused,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = UniWayColors.of(context);
    final hasRoute = controller.currentRoute != null;

    final canSwap = controller.origin != null &&
        controller.destination != null &&
        controller.origin!.id != controller.destination!.id;

    final isSameLocation = controller.origin != null &&
        controller.destination != null &&
        controller.origin!.id == controller.destination!.id;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildFromField(context),
                      const SizedBox(height: 10),
                      _buildToField(context),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.swap_vert, size: 22),
                  tooltip: 'Swap locations',
                  onPressed: canSwap ? controller.swap : null,
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            if (isSameLocation)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Start and destination must be different',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.warning,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (hasRoute) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.successContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.success.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_walk, size: 18, color: colors.onSuccessContainer),
                    const SizedBox(width: 6),
                    Text(
                      '${controller.currentRoute!.formattedDistance} • ${controller.currentRoute!.formattedDuration}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSuccessContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: (controller.isLoading || controller.isLocating)
                  ? Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            controller.isLocating ? 'Acquiring GPS...' : 'Routing...',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  : hasRoute
                      ? FilledButton.tonalIcon(
                          onPressed: controller.clearRoute,
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Clear'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: controller.canGo ? controller.fetchRoute : null,
                          icon: const Icon(Icons.directions_walk, size: 18),
                          label: const Text('Navigate'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String? get _blockedText {
    if (controller.isLoadingDestinations) return 'Loading destinations…';
    return controller.destinationsError;
  }

  Widget _buildFromField(BuildContext context) {
    final isGps = controller.isGpsOrigin;
    final origin = controller.origin;
    final selectedFrom = isGps || origin == null ? yourLocation : origin;
    final blocked = _blockedText;
    final theme = Theme.of(context);
    final colors = UniWayColors.of(context);

    return _pickerField(
      label: 'From',
      icon: Icon(
        isGps ? Icons.my_location : Icons.place_outlined,
        color: isGps ? colors.you : theme.colorScheme.primary,
        size: 20,
      ),
      text: blocked ?? selectedFrom.name,
      muted: blocked != null,
      onTap: blocked == null ? () => _pickFrom(context, selectedFrom) : null,
      theme: theme,
    );
  }

  Widget _buildToField(BuildContext context) {
    final destination = controller.destination;
    final blocked = _blockedText;
    final theme = Theme.of(context);

    return _pickerField(
      label: 'To',
      icon: Icon(Icons.place, color: theme.colorScheme.primary, size: 20),
      text: blocked ?? destination?.name ?? 'Select destination',
      muted: blocked != null || destination == null,
      onTap: blocked == null ? () => _pickTo(context) : null,
      theme: theme,
    );
  }

  Widget _pickerField({
    required String label,
    required Widget icon,
    required String text,
    required bool muted,
    required VoidCallback? onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
          enabled: onTap != null,
        ),
        isEmpty: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: muted ? theme.colorScheme.onSurfaceVariant : null,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.search, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFrom(BuildContext context, Destination current) async {
    final picked = await showDestinationSearchSheet(
      context,
      destinations: controller.destinations,
      title: 'From',
      selected: current,
      extraOption: yourLocation,
    );
    if (picked == null) return;
    if (picked.id == yourLocation.id) {
      controller.setOrigin(null);
    } else {
      controller.setOrigin(picked);
      onDestinationFocused?.call(picked);
    }
  }

  Future<void> _pickTo(BuildContext context) async {
    final picked = await showDestinationSearchSheet(
      context,
      destinations: controller.destinations,
      title: 'To',
      selected: controller.destination,
    );
    if (picked == null) return;
    controller.setDestination(picked);
    onDestinationFocused?.call(picked);
  }
}
