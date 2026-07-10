import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' as scene;
import 'package:flvtterm/flvtterm.dart';

import 'flutter_scene_vrm_binding.dart';

/// Parsed VRM model, imported Flutter Scene root, and runtime binding.
final class FlutterSceneVrmAsset {
  FlutterSceneVrmAsset._({
    required this.model,
    required this.rootNode,
    required this.binding,
  });

  /// Parsed renderer-neutral VRM model.
  final VrmModel model;

  /// Flutter Scene root imported from the same GLB bytes.
  final scene.Node rootNode;

  /// Binding from the parsed model to [rootNode].
  final FlutterSceneVrmBinding binding;

  /// Loads a VRM GLB from bytes into both flvtterm core and Flutter Scene.
  static Future<FlutterSceneVrmAsset> fromGlbBytes(
    Uint8List bytes, {
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
    FlutterSceneVrmBindingOptions? bindingOptions,
  }) async {
    final model = VrmModel.parseGlb(
      bytes,
      validation: validation,
      uriResolver: uriResolver,
    );
    final rootNode = await scene.Node.fromGlbBytes(bytes);
    return FlutterSceneVrmAsset._(
      model: model,
      rootNode: rootNode,
      binding: FlutterSceneVrmBinding.fromRootNode(
        rootNode,
        model: model,
        options: bindingOptions,
      ),
    );
  }

  /// Loads a VRM GLB asset into both flvtterm core and Flutter Scene.
  static Future<FlutterSceneVrmAsset> fromGlbAsset(
    String assetPath, {
    AssetBundle? bundle,
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
    FlutterSceneVrmBindingOptions? bindingOptions,
  }) async {
    final data = await (bundle ?? rootBundle).load(assetPath);
    return fromGlbBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      validation: validation,
      uriResolver: uriResolver,
      bindingOptions: bindingOptions,
    );
  }
}
