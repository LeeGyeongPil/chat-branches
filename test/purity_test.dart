import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tree core has no flutter imports', () {
    final files = <File>[
      File('lib/tree.dart'),
      ...Directory('lib/src/tree')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
    ];
    expect(files.length, greaterThan(3));
    for (final f in files) {
      final imports = f
          .readAsLinesSync()
          .where((l) => l.startsWith('import') || l.startsWith('export'));
      for (final line in imports) {
        expect(line, isNot(contains('package:flutter')), reason: f.path);
        expect(line, isNot(contains('flutter_ai_toolkit')), reason: f.path);
      }
    }
  });
}
