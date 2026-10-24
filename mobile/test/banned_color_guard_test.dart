import "dart:io";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("Banned Color Guard", () {
    final bannedRegex = RegExp(
      r"Colors\.(white|black|grey|green|red|orange|blue|amber)|Color\(0x",
    );

    // Map layers take their colours from MapPalette as hex strings, so no
    // Color literal belongs in lib/presentation/map either.
    //
    // Explicit allow-list. debug_panel.dart is intentionally a dark HUD, and
    // route_status_banner.dart is a solid red banner with white text that is
    // readable on both the light and the dark map, so neither follows the theme.
    const allowList = <String>{
      "debug_panel.dart",
      "route_status_banner.dart",
    };

    final targetDirs = [
      Directory("lib/presentation/widgets"),
      Directory("lib/presentation/search"),
      Directory("lib/presentation/map"),
    ];

    test("no banned light-only color literals exist in swept presentation files", () {
      final violations = <String>[];

      for (final dir in targetDirs) {
        expect(dir.existsSync(), isTrue, reason: "Directory \${dir.path} should exist");
        final files = dir.listSync(recursive: true).whereType<File>().where(
              (file) => file.path.endsWith(".dart"),
            );

        for (final file in files) {
          final fileName = file.uri.pathSegments.last;
          if (allowList.contains(fileName)) continue;

          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (bannedRegex.hasMatch(line)) {
              violations.add("\${file.path}:\${i + 1}: \${line.trim()}");
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: "Found banned light-only color literals in presentation files:\n"
            "\${violations.join('\n')}",
      );
    });
  });
}
