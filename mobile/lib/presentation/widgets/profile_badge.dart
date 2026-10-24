import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import 'profile_sheet.dart';

class ProfileBadge extends StatelessWidget {
  final AuthController authController;

  const ProfileBadge({super.key, required this.authController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: authController,
      builder: (context, _) {
        final isAuthenticated = authController.isAuthenticated;
        final user = authController.user;
        final displayName = isAuthenticated
            ? (user?.name.split(' ').first ?? 'User')
            : 'Guest';
        final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

        return Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => ProfileSheet.show(context, authController: authController),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 44,
              padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
              decoration: ShapeDecoration(
                color: theme.colorScheme.surface,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: isAuthenticated
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: isAuthenticated
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                    child: Text(
                      initial,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
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
