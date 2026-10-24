import 'package:flutter/material.dart';

import '../controllers/routing_controller.dart';
import '../theme/uniway_theme.dart';

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

    final colors = UniWayColors.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.warningContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.warning, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.alt_route, size: 18, color: colors.onWarningContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Starting from the nearest walking path to your approximate location.',
              style: TextStyle(
                color: colors.onWarningContainer,
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
