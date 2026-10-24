import "package:flutter/material.dart";
import "../controllers/routing_controller.dart";

class DebugPanel extends StatefulWidget {
  final RoutingController controller;

  const DebugPanel({
    super.key,
    required this.controller,
  });

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);

    return Card(
      elevation: 6,
      shadowColor: theme.colorScheme.shadow,
      color: Colors.grey.shade900.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Icon(
                    Icons.bug_report,
                    size: 16,
                    color: Colors.amber.shade400,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Phase 0 Debug HUD",
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _buildStatusChip(c),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              Divider(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                height: 16,
              ),
              _buildDebugRow("Origin", c.origin?.name ?? "None"),
              _buildDebugRow("Origin Node/Room", c.origin?.roomId ?? "-"),
              _buildDebugRow("Destination", c.destination?.name ?? "None"),
              _buildDebugRow("Destination Node/Room", c.destination?.roomId ?? "-"),
              _buildDebugRow(
                "Calculated Distance",
                c.currentRoute != null
                    ? "${c.currentRoute!.distanceMeters.toStringAsFixed(2)} m"
                    : "N/A",
              ),
              _buildDebugRow(
                "Waypoints",
                c.currentRoute != null
                    ? "${c.currentRoute!.points.length} nodes"
                    : "N/A",
              ),
              _buildDebugRow(
                "HTTP Status",
                c.statusCode != null ? "${c.statusCode}" : (c.isLoading ? "In flight" : "-"),
              ),
              _buildDebugRow(
                "API Latency",
                c.latencyMs != null ? "${c.latencyMs} ms" : "-",
              ),
              if (c.errorMessage != null)
                _buildDebugRow("Error", c.errorMessage!, isError: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(RoutingController c) {
    Color bg = Colors.grey.shade700;
    String label = "IDLE";

    if (c.isLoading) {
      bg = Colors.blue.shade700;
      label = "ROUTING...";
    } else if (c.errorMessage != null) {
      bg = Colors.red.shade700;
      label = "ERROR";
    } else if (c.currentRoute != null) {
      bg = Colors.green.shade700;
      label = "ROUTE OK (${c.currentRoute!.formattedDistance})";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
                fontFamily: "monospace",
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isError ? Colors.red.shade300 : Colors.white,
                fontSize: 11,
                fontFamily: "monospace",
                fontWeight: isError ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
