# flvtterm_flutter_scene

Renders [flvtterm](https://pub.dev/packages/flvtterm) VRM avatars with
[Flutter Scene](https://pub.dev/packages/flutter_scene). flvtterm parses the
VRM and runs its humanoid, expressions, LookAt, spring bones and constraints;
this package imports the model into a Flutter Scene node and applies each
runtime frame to it.

## Install

```sh
flutter pub add flvtterm flvtterm_flutter_scene flutter_scene:0.24.3
```

The adapter pins Flutter Scene to exactly 0.24.3, because its reusable morph
buffers and corrected material bindings use Flutter Scene internals. Flutter
Scene's [getting-started guide](https://fscene.dev/getting-started/) covers
the Flutter version and platform setup it needs.

## Use

```dart
import 'package:flvtterm/flvtterm.dart';
import 'package:flvtterm_flutter_scene/vrm_flutter_scene.dart';

final bytes = await rootBundle.load('assets/avatar.vrm').then(
  (data) => data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
);
final asset = await FlutterSceneVrmAsset.fromGlbBytes(bytes);
myScene.add(asset.rootNode); // myScene is your Flutter Scene `Scene`.
final runtime = VrmRuntime(asset.model)..bind(asset.binding);

// Once per frame:
runtime.update(deltaSeconds);
```

`FlutterSceneVrmAsset` returns the parsed model, the imported root node and
the binding. Pass `jointPaletteCapacity` when the renderer animates a bounded
joint palette: a skin that lists more joints is replaced, per mesh node, by
the joints that mesh weights.

What the adapter applies, what it reports through
`binding.capabilityWarnings`, and its limits (MToon draws with a PBR/unlit
fallback) are in the
[flvtterm README](https://github.com/ProjectKokage/flvtterm#flutter).

## License

GPL-3.0, like flvtterm. See [LICENSE](LICENSE).
