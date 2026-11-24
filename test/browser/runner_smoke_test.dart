@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

// No Animora imports, plugins, storage, or network calls. Isolates the runner.
void main() {
  test('Flutter Web runner can execute a minimal assertion', () {
    expect(1 + 1, 2);
  });
}
