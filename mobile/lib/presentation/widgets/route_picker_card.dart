import 'package:flutter/material.dart';
import '../../data/models/destination.dart';
import '../controllers/routing_controller.dart';

class RoutePickerCard extends StatelessWidget {
  final RoutingController controller;

  const RoutePickerCard({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destinations = controller.destinations;
    final hasRoute = controller.currentRoute != null;

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.isLoadingDestinations) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Loading campus destinations...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else if (controller.destinationsError != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        controller.destinationsError!,
                        style: TextStyle(fontSize: 11, color: Colors.red.shade800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: controller.loadDestinations,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Retry', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildDestinationDropdown(
                        context: context,
                        label: 'From (Origin)',
                        icon: Icons.my_location,
                        iconColor: Colors.blue,
                        value: controller.origin,
                        items: destinations,
                        onChanged: controller.setOrigin,
                      ),
                      const SizedBox(height: 12),
                      _buildDestinationDropdown(
                        context: context,
                        label: 'To (Destination)',
                        icon: Icons.location_on,
                        iconColor: Colors.red,
                        value: controller.destination,
                        items: destinations,
                        onChanged: controller.setDestination,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.swap_vert),
                  tooltip: 'Swap From & To',
                  onPressed: controller.canGo ? controller.swap : null,
                ),
              ],
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
              width: double.infinity,
              height: 48,
              child: controller.isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : hasRoute
                      ? FilledButton.tonalIcon(
                          onPressed: controller.clearRoute,
                          icon: const Icon(Icons.close),
                          label: const Text('Clear Route'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: controller.canGo ? controller.fetchRoute : null,
                          icon: const Icon(Icons.directions_walk),
                          label: const Text('Go'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationDropdown({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Destination? value,
    required List<Destination> items,
    required ValueChanged<Destination?> onChanged,
  }) {
    final effectiveValue = items.contains(value) ? value : null;

    return DropdownButtonFormField<Destination>(
      initialValue: effectiveValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: iconColor, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      isExpanded: true,
      hint: Text(
        items.isEmpty ? 'No destinations' : 'Select $label',
        style: const TextStyle(fontSize: 14),
      ),
      items: items.map((dest) {
        return DropdownMenuItem<Destination>(
          value: dest,
          child: Text(
            dest.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList(),
      onChanged: items.isEmpty ? null : onChanged,
    );
  }
}
