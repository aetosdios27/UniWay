import 'package:flutter/material.dart';
import '../controllers/routing_controller.dart';

class RouteStatusBanner extends StatelessWidget {
  final RoutingController controller;

  const RouteStatusBanner({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade400, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              controller.errorMessage!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: controller.fetchRoute,
            child: Text(
              'Retry',
              style: TextStyle(
                color: Colors.amber.shade200,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
