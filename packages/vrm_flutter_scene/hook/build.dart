import 'dart:isolate';

import 'package:flutter_gpu_shaders/build.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (config, output) async {
    final flutterSceneLibrary = await Isolate.resolvePackageUri(
      Uri.parse('package:flutter_scene/scene.dart'),
    );
    if (flutterSceneLibrary == null) {
      throw StateError('Could not resolve the pinned flutter_scene package.');
    }
    await buildShaderBundleJson(
      buildInput: config,
      buildOutput: output,
      manifestFileName: 'shaders/vrm_materials.shaderbundle.json',
      includeDirectories: [flutterSceneLibrary.resolve('../shaders/')],
    );
  });
}
