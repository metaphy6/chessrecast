// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures
import 'dart:io';
// No dart:convert needed

final dartFiles = <File>[];

void main(List<String> args) {
  final root = Directory('lib');
  if (!root.existsSync()) {
    print('No lib directory found.');
    exit(0);
  }

  _collectDartFiles(root);

  final warnings = <String>[];

  for (final f in dartFiles) {
    final text = f.readAsStringSync();
    // final lines = const LineSplitter().convert(text);

    // Find patterns like: final foo = Get.find<Type>();
    // Match only untyped 'final var = Get.find<Type>();' - skip typed declarations (likely fields)
    final regex = RegExp(
      r"\bfinal\s+([A-Za-z0-9_]+)\s*=\s*Get\.find<([A-Za-z0-9_]+)>\s*\(\s*\)\s*;?",
    );

    for (final match in regex.allMatches(text)) {
      final varName = match.group(1)!;
      final typeName = match.group(2)!;
      final matches = RegExp('\\b$varName\\b').allMatches(text).length;
      // Debug
      // print('DEBUG: ${f.path} var=$varName occurrences=$matches');
      if (matches <= 1) {
        // single-use find usage detected
        warnings.add(
          '${f.path}: Single-use Get.find <$typeName> assigned to \$varName; consider inlining.',
        );
      }
    }
  }

  if (warnings.isNotEmpty) {
    print('Detected ${warnings.length} single-use Get.find assignments:');
    for (final w in warnings) print('- $w');
    exit(2);
  }

  print('No single-use Get.find assignments found.');
}

void _collectDartFiles(Directory dir) {
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      dartFiles.add(entity);
    }
  }
}
