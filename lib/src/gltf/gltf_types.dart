import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../diagnostics.dart';
import '../json_values.dart';
import '../parser.dart';
import 'accessor_reader.dart';
import 'gltf_animation_types.dart';
import 'gltf_camera_types.dart';
import 'gltf_material_types.dart';
import 'gltf_mesh_types.dart';
import 'gltf_resource_types.dart';
import 'gltf_scene_types.dart';

/// Resolves non-`data:` glTF URIs to bytes.
typedef GltfUriResolver = Uint8List? Function(String uri);

/// Parsed glTF 2.0 asset data needed by VRM runtimes.
final class GltfAsset {
  /// Creates the value from parsed data. Only flvtterm calls this.
  @internal
  GltfAsset.internal({
    required Map<String, Object?> json,
    required this.binaryChunk,
    required Map<String, Object?> extensions,
    required Object? extras,
    required this.hasUriResolver,
    required Map<String, String> uriResolverFailures,
    required List<String> extensionsUsed,
    required List<String> extensionsRequired,
    required List<GltfBuffer> buffers,
    required List<GltfBufferView> bufferViews,
    required List<GltfCamera> cameras,
    required this.scene,
    required List<GltfScene> scenes,
    required List<GltfNode> nodes,
    required List<GltfMesh> meshes,
    required List<GltfMaterial> materials,
    required List<GltfSkin> skins,
    required List<GltfAccessor> accessors,
    required List<GltfTexture> textures,
    required List<GltfImage> images,
    required List<GltfSampler> samplers,
    required List<GltfAnimation> animations,
  }) : json = immutableJsonValue(json) as Map<String, Object?>,
       extras = immutableJsonValue(extras),
       extensions = immutableJsonValue(extensions) as Map<String, Object?>,
       uriResolverFailures = Map.unmodifiable(uriResolverFailures),
       extensionsUsed = List.unmodifiable(extensionsUsed),
       extensionsRequired = List.unmodifiable(extensionsRequired),
       buffers = List.unmodifiable(buffers),
       bufferViews = List.unmodifiable(bufferViews),
       cameras = List.unmodifiable(cameras),
       scenes = List.unmodifiable(scenes),
       nodes = List.unmodifiable(nodes),
       meshes = List.unmodifiable(meshes),
       materials = List.unmodifiable(materials),
       skins = List.unmodifiable(skins),
       accessors = List.unmodifiable(accessors),
       textures = List.unmodifiable(textures),
       images = List.unmodifiable(images),
       samplers = List.unmodifiable(samplers),
       animations = List.unmodifiable(animations);

  /// Raw glTF JSON root object.
  final Map<String, Object?> json;

  /// GLB BIN chunk bytes, if the source was a GLB with a BIN chunk.
  ///
  /// This is the asset's one unmodifiable copy of the chunk; later changes to
  /// the bytes passed to the parser do not reach it.
  final Uint8List? binaryChunk;

  /// Root glTF extensions, preserved.
  final Map<String, Object?> extensions;

  /// Root glTF extras, preserved.
  final Object? extras;

  /// Raw root `asset` object.
  Map<String, Object?> get asset => jsonObject(json['asset']);

  /// Root `asset.version`.
  String? get assetVersion => jsonString(asset['version']);

  /// Root `asset.minVersion`.
  String? get assetMinVersion => jsonString(asset['minVersion']);

  /// Root `asset.generator`.
  String? get assetGenerator => jsonString(asset['generator']);

  /// Root `asset.copyright`.
  String? get assetCopyright => jsonString(asset['copyright']);

  /// Root `asset.extensions`, preserved.
  Map<String, Object?> get assetExtensions => jsonObject(asset['extensions']);

  /// Root `asset.extras`, preserved.
  Object? get assetExtras => immutableJsonValue(asset['extras']);

  /// Whether the parser was given a resolver for external URIs.
  @internal
  final bool hasUriResolver;

  /// Why the resolver failed, for each URI it could not load, by JSON path.
  @internal
  final Map<String, String> uriResolverFailures;

  /// Root `extensionsUsed` names.
  final List<String> extensionsUsed;

  /// Root `extensionsRequired` names.
  final List<String> extensionsRequired;

  /// glTF buffers, preserving indices.
  final List<GltfBuffer> buffers;

  /// glTF bufferViews, preserving indices.
  final List<GltfBufferView> bufferViews;

  /// glTF cameras, preserving indices.
  final List<GltfCamera> cameras;

  /// Default scene index, if any.
  final int? scene;

  /// glTF scenes, preserving indices.
  final List<GltfScene> scenes;

  /// glTF nodes, preserving indices.
  final List<GltfNode> nodes;

  /// glTF meshes, preserving indices.
  final List<GltfMesh> meshes;

  /// glTF materials, preserving indices.
  final List<GltfMaterial> materials;

  /// glTF skins, preserving indices.
  final List<GltfSkin> skins;

  /// glTF accessors, preserving indices.
  final List<GltfAccessor> accessors;

  /// glTF textures, preserving indices.
  final List<GltfTexture> textures;

  /// glTF images, preserving indices.
  final List<GltfImage> images;

  /// glTF texture samplers, preserving indices.
  final List<GltfSampler> samplers;

  /// glTF animations, preserving indices.
  final List<GltfAnimation> animations;

  /// Decoded animation accessor values, kept per asset.
  ///
  /// Animation accessors are immutable after parsing. Evaluators memoize their
  /// bounded decoded values here so separate runtime layers over the same asset
  /// do not decode the same buffer data again.
  @internal
  final Map<(int, bool, bool), List<double>?> animationAccessorCache = {};

  /// Parses a GLB or JSON glTF 2.0 asset.
  ///
  /// With [adoptBytes], the asset keeps views of [bytes] instead of copying
  /// the GLB's BIN chunk. The caller hands the bytes over and must not change
  /// them afterwards: a later change would reach the parsed asset without
  /// validation. It has no effect on a JSON glTF, which has no BIN chunk.
  static GltfAsset parse({
    required Uint8List bytes,
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
    bool adoptBytes = false,
  }) {
    final result = tryParse(
      bytes: bytes,
      validation: validation,
      uriResolver: uriResolver,
      adoptBytes: adoptBytes,
    );
    final asset = result.asset;
    if (asset == null) {
      throw VrmInvalidAssetException('Invalid glTF asset', result.validation);
    }
    return asset;
  }

  /// Parses a GLB or JSON glTF 2.0 asset without throwing for validation
  /// failures.
  ///
  /// With [adoptBytes], the asset keeps views of [bytes] instead of copying
  /// the GLB's BIN chunk. The caller hands the bytes over and must not change
  /// them afterwards: a later change would reach the parsed asset without
  /// validation. It has no effect on a JSON glTF, which has no BIN chunk.
  static VrmParseResult<GltfAsset> tryParse({
    required Uint8List bytes,
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
    bool adoptBytes = false,
  }) => AssetParser.parseGltf(
    bytes,
    validation,
    uriResolver: uriResolver,
    adoptBytes: adoptBytes,
  );

  /// Reads numeric accessor component values.
  ///
  /// Returns `null` when the accessor index or backing buffer data is invalid.
  /// Integer components are returned as doubles. Normalized integer accessors
  /// are converted to normalized floating-point values unless
  /// [applyNormalization] is false.
  List<double>? readAccessorNumbers(
    int accessorIndex, {
    bool requireFloat = false,
    bool applyNormalization = true,
  }) {
    return readGltfAccessorNumbers(
      this,
      accessorIndex,
      requireFloat: requireFloat,
      applyNormalization: applyNormalization,
    );
  }

  /// Reads raw bytes for a bufferView.
  ///
  /// Returns `null` when the bufferView index or backing buffer data is
  /// invalid.
  Uint8List? readBufferViewBytes(int bufferViewIndex) =>
      gltfBufferViewBytes(buffers, bufferViews, bufferViewIndex);
}
