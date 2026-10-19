import 'package:flutter/material.dart';

import '../controllers/routing_controller.dart';

class RouteStartNotice extends StatelessWidget {
  final RoutingController controller;

  const RouteStartNotice({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.isRouteStartApproximate || controller.currentRoute == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.alt_route, size: 18, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Starting from the nearest walking path to your approximate location.',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
