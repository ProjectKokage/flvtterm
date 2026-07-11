import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flvtterm_flutter_scene_viewer/src/viewer_widgets.dart';

void main() {
  testWidgets('viewer control forwards slider changes', (tester) async {
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewerControl(
            label: 'Happy',
            value: 0,
            onChanged: (_) => changed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Slider));

    expect(changed, isTrue);
  });
}
