import 'package:flutter/services.dart';
import 'package:flvtterm/flvtterm.dart';

/// Loads VRM, VRMA, and generic glTF bytes from a Flutter [AssetBundle].
final class VrmAssetLoader {
  /// Creates a loader using [bundle], or [rootBundle] when omitted.
  VrmAssetLoader([AssetBundle? bundle]) : bundle = bundle ?? rootBundle;

  /// Backing asset bundle.
  final AssetBundle bundle;

  /// Loads raw asset bytes.
  Future<Uint8List> loadBytes(String key) async {
    final data = await bundle.load(key);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// Loads and strictly parses a VRM model asset.
  Future<VrmModel> loadModel(
    String key, {
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
  }) async {
    return VrmModel.parseGlb(
      await loadBytes(key),
      validation: validation,
      uriResolver: uriResolver,
    );
  }

  /// Loads a VRM model asset without throwing for validation failures.
  Future<VrmParseResult<VrmModel>> tryLoadModel(
    String key, {
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
  }) async {
    return VrmModel.tryParseGlb(
      await loadBytes(key),
      validation: validation,
      uriResolver: uriResolver,
    );
  }

  /// Loads and strictly parses a generic glTF or GLB asset.
  Future<GltfAsset> loadGltf(
    String key, {
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
  }) async {
    return GltfAsset.parse(
      bytes: await loadBytes(key),
      validation: validation,
      uriResolver: uriResolver,
    );
  }

  /// Loads a generic glTF or GLB asset without throwing for validation failures.
  Future<VrmParseResult<GltfAsset>> tryLoadGltf(
    String key, {
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
  }) async {
    return GltfAsset.tryParse(
      bytes: await loadBytes(key),
      validation: validation,
      uriResolver: uriResolver,
    );
  }

  /// Loads and strictly parses a VRMA animation asset.
  Future<VrmAnimationAsset> loadAnimation(
    String key, {
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
  }) async {
    return VrmAnimationAsset.parse(
      bytes: await loadBytes(key),
      validation: validation,
      uriResolver: uriResolver,
    );
  }

  /// Loads a VRMA animation asset without throwing for validation failures.
  Future<VrmParseResult<VrmAnimationAsset>> tryLoadAnimation(
    String key, {
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
  }) async {
    return VrmAnimationAsset.tryParse(
      bytes: await loadBytes(key),
      validation: validation,
      uriResolver: uriResolver,
    );
  }
}
