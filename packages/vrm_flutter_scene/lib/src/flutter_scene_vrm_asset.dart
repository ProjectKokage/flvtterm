import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' as scene;
import 'package:flvtterm/flvtterm.dart';

import 'flutter_scene_material_corrections.dart';
import 'flutter_scene_resolved_import.dart';
import 'flutter_scene_vrm_binding.dart';

/// Parsed VRM model, imported Flutter Scene root, and runtime binding.
final class FlutterSceneVrmAsset {
  FlutterSceneVrmAsset._({
    required this.model,
    required this.rootNode,
    required this.binding,
    required Set<int> alphaCorrectedMaterialIndices,
    required Set<int> straightAlphaTextureIndices,
  }) : alphaCorrectedMaterialIndices = Set.unmodifiable(
         alphaCorrectedMaterialIndices,
       ),
       straightAlphaTextureIndices = Set.unmodifiable(
         straightAlphaTextureIndices,
       );

  /// Parsed renderer-neutral VRM model.
  final VrmModel model;

  /// Flutter Scene root imported from the same GLB bytes.
  final scene.Node rootNode;

  /// Binding from the parsed model to [rootNode].
  final FlutterSceneVrmBinding binding;

  /// glTF material indices whose alpha mode and sidedness were restored after
  /// Flutter Scene import.
  final Set<int> alphaCorrectedMaterialIndices;

  /// glTF texture indices decoded and uploaded as straight-alpha RGBA.
  final Set<int> straightAlphaTextureIndices;

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
    final rootNode = await importResolvedFlutterSceneGlb(bytes, model);
    final corrections = await correctFlutterSceneMaterials(rootNode, model);
    return FlutterSceneVrmAsset._(
      model: model,
      rootNode: rootNode,
      alphaCorrectedMaterialIndices: corrections.alphaCorrectedMaterialIndices,
      straightAlphaTextureIndices: corrections.straightAlphaTextureIndices,
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
