import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flvtterm_flutter_scene_viewer/main.dart' as viewer;

void main() {
  test('viewer entrypoint is available', () {
    expect(viewer.main, isA<Function>());
  });

  test('viewer surfaces adapter capability warnings', () {
    final source = File('lib/src/viewer_screen.dart').readAsStringSync();

    expect(source, contains('capabilityWarnings'));
    expect(source, contains('Adapter warnings'));
  });
}
