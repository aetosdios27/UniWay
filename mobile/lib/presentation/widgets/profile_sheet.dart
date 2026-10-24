import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../controllers/theme_controller.dart';
import 'auth_modal.dart';

class ProfileSheet extends StatelessWidget {
  final AuthController authController;

  const ProfileSheet({super.key, required this.authController});

  static Future<void> show(BuildContext context, {required AuthController authController}) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfileSheet(authController: authController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeController = ThemeScope.maybeOf(context);
    final user = authController.user;
    final isAuthenticated = authController.isAuthenticated;
    final displayName = isAuthenticated ? (user?.name ?? "UniWay User") : "Guest User";
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(
                    initial,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAuthenticated
                            ? (user?.email ?? "")
                            : "Sign in to save favorite places and report hazards",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
            const SizedBox(height: 10),
            if (themeController != null) ...[
              Text(
                "Appearance",
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: "Appearance mode",
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto),
                      label: Text("System"),
                      tooltip: "System appearance",
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text("Light"),
                      tooltip: "Light appearance",
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text("Dark"),
                      tooltip: "Dark appearance",
                    ),
                  ],
                  selected: {themeController.mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selected) {
                    if (selected.isNotEmpty) {
                      themeController.setMode(selected.first);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
              const SizedBox(height: 10),
            ],
            if (isAuthenticated) ...[
              _FeatureTile(
                icon: Icons.bookmark_outline,
                title: "Saved Places",
                subtitle: "Locations you navigate to often",
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Favorites are coming in Phase 2"),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _FeatureTile(
                icon: Icons.report_problem_outlined,
                title: "Report Hazard",
                subtitle: "Blocked paths, repairs, accessibility barriers",
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Hazard reporting is coming in Phase 3"),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await authController.logout();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.logout),
                label: const Text("Sign Out"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                    color: theme.colorScheme.error.withValues(alpha: 0.5),
                  ),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  AuthModal.show(context, authController: authController);
                },
                icon: const Icon(Icons.login),
                label: const Text("Sign In or Register"),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Keep browsing as guest"),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        child: Icon(icon, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
