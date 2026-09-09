import 'package:flutter/material.dart';
import '../../data/models/destination.dart';
import '../controllers/routing_controller.dart';

class RoutePickerCard extends StatelessWidget {
  final RoutingController controller;

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destinations = controller.destinations;
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
                      _buildFromDropdown(context, destinations),
                      const SizedBox(height: 10),
                      _buildToDropdown(context, destinations),
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
                    color: Colors.orange.shade800,
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
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_walk, size: 18, color: Colors.green.shade800),
                    const SizedBox(width: 6),
                    Text(
                      '${controller.currentRoute!.formattedDistance} • ${controller.currentRoute!.formattedDuration}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.green.shade800,
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

  Widget _buildFromDropdown(BuildContext context, List<Destination> destinations) {
    final fromOptions = [
      yourLocation,
      ...destinations,
    ];

    final isGps = controller.isGpsOrigin;
    final selectedFrom = isGps
        ? yourLocation
        : destinations.firstWhere(
            (d) => d.id == controller.origin?.id,
            orElse: () => yourLocation,
          );

    return DropdownButtonFormField<Destination>(
      initialValue: selectedFrom,
      decoration: InputDecoration(
        labelText: 'From',
        prefixIcon: Icon(
          isGps ? Icons.my_location : Icons.place_outlined,
          color: isGps ? Colors.blue.shade700 : Colors.indigo.shade600,
          size: 20,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      isExpanded: true,
      items: fromOptions.map((dest) {
        final isItemGps = dest.id == yourLocation.id;
        return DropdownMenuItem<Destination>(
          value: dest,
          child: Row(
            children: [
              Icon(
                isItemGps ? Icons.my_location : Icons.place_outlined,
                color: isItemGps ? Colors.blue.shade700 : Colors.grey.shade700,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dest.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isItemGps ? FontWeight.w600 : FontWeight.normal,
                    color: isItemGps ? Colors.blue.shade900 : null,
                  ),
                ),
              ),
              if (isItemGps && controller.userLatitude != null)
                Text(
                  'GPS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: (selected) {
        if (selected == null || selected.id == yourLocation.id) {
          controller.setOrigin(null);
        } else {
          controller.setOrigin(selected);
        }
      },
    );
  }

  Widget _buildToDropdown(BuildContext context, List<Destination> destinations) {
    final effectiveValue = destinations.contains(controller.destination)
        ? controller.destination
        : null;

    return DropdownButtonFormField<Destination>(
      initialValue: effectiveValue,
      decoration: InputDecoration(
        labelText: 'To',
        prefixIcon: Icon(Icons.place, color: Colors.blue.shade700, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      isExpanded: true,
      hint: const Text('Select destination', style: TextStyle(fontSize: 14)),
      items: destinations.map((dest) {
        return DropdownMenuItem<Destination>(
          value: dest,
          child: Row(
            children: [
              Icon(Icons.place_outlined, color: Colors.grey.shade700, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dest.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: controller.setDestination,
    );
  }
}
