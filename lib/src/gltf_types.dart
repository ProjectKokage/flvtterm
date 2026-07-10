part of '../flvtterm.dart';

/// Resolves non-`data:` glTF URIs to bytes.
typedef GltfUriResolver = Uint8List? Function(String uri);

/// Parsed glTF 2.0 asset data needed by VRM runtimes.
final class GltfAsset {
  GltfAsset._({
    required Map<String, Object?> json,
    required Uint8List? binaryChunk,
    required Map<String, Object?> extensions,
    required Object? extras,
    required bool hasUriResolver,
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
  }) : json = _immutableJsonValue(json) as Map<String, Object?>,
       extras = _immutableJsonValue(extras),
       binaryChunk = binaryChunk == null
           ? null
           : Uint8List.fromList(binaryChunk).asUnmodifiableView(),
       extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       _hasUriResolver = hasUriResolver,
       _uriResolverFailures = Map.unmodifiable(uriResolverFailures),
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
  final Uint8List? binaryChunk;

  /// Root glTF extensions, preserved.
  final Map<String, Object?> extensions;

  /// Root glTF extras, preserved.
  final Object? extras;

  /// Raw root `asset` object.
  Map<String, Object?> get asset => _object(json['asset']);

  /// Root `asset.version`.
  String? get assetVersion => _string(asset['version']);

  /// Root `asset.minVersion`.
  String? get assetMinVersion => _string(asset['minVersion']);

  /// Root `asset.generator`.
  String? get assetGenerator => _string(asset['generator']);

  /// Root `asset.copyright`.
  String? get assetCopyright => _string(asset['copyright']);

  /// Root `asset.extensions`, preserved.
  Map<String, Object?> get assetExtensions => _object(asset['extensions']);

  /// Root `asset.extras`, preserved.
  Object? get assetExtras => _immutableJsonValue(asset['extras']);

  final bool _hasUriResolver;

  final Map<String, String> _uriResolverFailures;

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

  /// Parses a GLB or JSON glTF 2.0 asset.
  static GltfAsset parse({
    required Uint8List bytes,
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
  }) {
    final result = tryParse(
      bytes: bytes,
      validation: validation,
      uriResolver: uriResolver,
    );
    final asset = result.asset;
    if (asset == null) {
      throw VrmInvalidAssetException('Invalid glTF asset', result.validation);
    }
    return asset;
  }

  /// Parses a GLB or JSON glTF 2.0 asset without throwing for validation
  /// failures.
  static VrmParseResult<GltfAsset> tryParse({
    required Uint8List bytes,
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
  }) => _Parser.parseGltf(bytes, validation, uriResolver: uriResolver);

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
    return _readAccessorNumbers(
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
  Uint8List? readBufferViewBytes(int bufferViewIndex) {
    final view = bufferViews.elementAtOrNull(bufferViewIndex);
    final bytes = _bufferBytes(this, view?.buffer);
    final byteLength = view?.byteLength;
    if (view == null || bytes == null || byteLength == null) return null;
    final start = view.byteOffset;
    final end = start + byteLength;
    if (start < 0 || end > bytes.length) return null;
    return Uint8List.sublistView(bytes, start, end);
  }
}
