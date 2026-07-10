part of '../flvtterm.dart';

/// Parsed VRM 1.0 model asset.
final class VrmModel {
  VrmModel._({
    required this.gltf,
    required this.vrm,
    required this.springBone,
    required this.validation,
  });

  /// glTF data for the model.
  final GltfAsset gltf;

  /// VRMC_vrm extension data.
  final VrmExtension vrm;

  /// VRMC_springBone extension data, when present.
  final VrmSpringBone? springBone;

  /// Validation diagnostics from parsing.
  final VrmValidationResult validation;

  /// Resolves a first-person mesh policy, conservatively handling `auto`.
  VrmFirstPersonMeshAnnotationType conservativeFirstPersonTypeForNode(
    int nodeIndex,
  ) {
    final declared = vrm.firstPerson.typeForNode(nodeIndex);
    if (declared != VrmFirstPersonMeshAnnotationType.auto) return declared;
    final headInfluenced = _meshHasHeadInfluence(this, nodeIndex);
    if (headInfluenced == null) return VrmFirstPersonMeshAnnotationType.auto;
    return headInfluenced
        ? VrmFirstPersonMeshAnnotationType.thirdPersonOnly
        : VrmFirstPersonMeshAnnotationType.both;
  }

  /// Resolves first-person policy for one mesh primitive when an adapter can
  /// split or hide primitives independently.
  VrmFirstPersonMeshAnnotationType firstPersonTypeForPrimitive(
    int nodeIndex,
    int primitiveIndex,
  ) {
    final declared = vrm.firstPerson.typeForNode(nodeIndex);
    if (declared != VrmFirstPersonMeshAnnotationType.auto) return declared;
    final headInfluenced = _primitiveHasHeadInfluence(
      this,
      nodeIndex,
      primitiveIndex,
    );
    if (headInfluenced == null) return VrmFirstPersonMeshAnnotationType.auto;
    return headInfluenced
        ? VrmFirstPersonMeshAnnotationType.thirdPersonOnly
        : VrmFirstPersonMeshAnnotationType.both;
  }

  /// Whether first-person `auto` resolves differently for primitives on one
  /// mesh, so whole-mesh visibility is a conservative fallback.
  bool firstPersonNeedsPrimitiveSplit(int nodeIndex) {
    if (vrm.firstPerson.typeForNode(nodeIndex) !=
        VrmFirstPersonMeshAnnotationType.auto) {
      return false;
    }
    final node = gltf.nodes.elementAtOrNull(nodeIndex);
    if (node == null || node.mesh == null) return false;
    final mesh = gltf.meshes.elementAtOrNull(node.mesh!);
    if (mesh == null || mesh.primitives.length < 2) return false;

    final conservative = conservativeFirstPersonTypeForNode(nodeIndex);
    for (var i = 0; i < mesh.primitives.length; i++) {
      final primitiveType = firstPersonTypeForPrimitive(nodeIndex, i);
      if (primitiveType != VrmFirstPersonMeshAnnotationType.auto &&
          primitiveType != conservative) {
        return true;
      }
    }
    return false;
  }

  /// Whether first-person `auto` needs sub-mesh geometry visibility for this
  /// node, either between primitives or between triangles in a primitive.
  bool firstPersonNeedsGeometrySplit(int nodeIndex) {
    if (firstPersonNeedsPrimitiveSplit(nodeIndex)) return true;
    final node = gltf.nodes.elementAtOrNull(nodeIndex);
    if (node == null || node.mesh == null) return false;
    final mesh = gltf.meshes.elementAtOrNull(node.mesh!);
    if (mesh == null) return false;
    for (var i = 0; i < mesh.primitives.length; i++) {
      if (firstPersonNeedsTriangleSplit(nodeIndex, i)) return true;
    }
    return false;
  }

  /// Whether first-person `auto` resolves differently for triangles inside one
  /// primitive, so primitive-level visibility is a conservative fallback.
  bool firstPersonNeedsTriangleSplit(int nodeIndex, int primitiveIndex) {
    if (vrm.firstPerson.typeForNode(nodeIndex) !=
        VrmFirstPersonMeshAnnotationType.auto) {
      return false;
    }
    VrmFirstPersonMeshAnnotationType? first;
    for (final type in firstPersonTriangleTypesForPrimitive(
      nodeIndex,
      primitiveIndex,
    )) {
      if (type == VrmFirstPersonMeshAnnotationType.auto) continue;
      first ??= type;
      if (type != first) return true;
    }
    return false;
  }

  /// Resolves first-person policy for each triangle in a primitive.
  ///
  /// Returns an empty list when the primitive is not triangle-based or the
  /// triangle data cannot be classified.
  List<VrmFirstPersonMeshAnnotationType> firstPersonTriangleTypesForPrimitive(
    int nodeIndex,
    int primitiveIndex,
  ) {
    final declared = vrm.firstPerson.typeForNode(nodeIndex);
    final headInfluence = _primitiveTriangleHeadInfluence(
      this,
      nodeIndex,
      primitiveIndex,
    );
    if (headInfluence == null) {
      final count = _primitiveTriangleCount(gltf, nodeIndex, primitiveIndex);
      if (declared == VrmFirstPersonMeshAnnotationType.auto || count == null) {
        return const [];
      }
      return List.unmodifiable(List.filled(count, declared));
    }
    if (declared != VrmFirstPersonMeshAnnotationType.auto) {
      return List.unmodifiable(List.filled(headInfluence.length, declared));
    }
    return List.unmodifiable([
      for (final influenced in headInfluence)
        influenced
            ? VrmFirstPersonMeshAnnotationType.thirdPersonOnly
            : VrmFirstPersonMeshAnnotationType.both,
    ]);
  }

  /// Parses a VRM GLB, throwing in strict mode when validation fails.
  static VrmModel parseGlb(
    Uint8List bytes, {
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
  }) {
    final result = tryParseGlb(
      bytes,
      validation: validation,
      uriResolver: uriResolver,
    );
    final asset = result.asset;
    if (asset == null) {
      throw VrmInvalidAssetException('Invalid VRM asset', result.validation);
    }
    return asset;
  }

  /// Parses a VRM GLB without throwing for user asset validation failures.
  static VrmParseResult<VrmModel> tryParseGlb(
    Uint8List bytes, {
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
  }) => _Parser.parseVrmGlb(bytes, validation, uriResolver: uriResolver);
}

/// Parsed VRMC_vrm_animation 1.0 extension.
final class VrmAnimationExtension {
  VrmAnimationExtension._({
    required this.specVersion,
    required this.humanoid,
    required Map<VrmExpressionPreset, int> presetExpressions,
    required Map<String, int> customExpressions,
    required this.lookAt,
    required List<double> offsetFromHeadBone,
    required Map<String, Object?> raw,
  }) : presetExpressions = Map.unmodifiable(presetExpressions),
       customExpressions = Map.unmodifiable(customExpressions),
       offsetFromHeadBone = List.unmodifiable(offsetFromHeadBone),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// VRMC_vrm_animation spec version.
  final String? specVersion;

  /// Humanoid bone mapping in the animation glTF.
  final VrmHumanoid humanoid;

  /// Preset expression node mappings.
  final Map<VrmExpressionPreset, int> presetExpressions;

  /// Custom expression node mappings.
  final Map<String, int> customExpressions;

  /// LookAt animation node index.
  final int? lookAt;

  /// LookAt origin offset from head bone.
  final List<double> offsetFromHeadBone;

  /// Raw extension object, preserved.
  final Map<String, Object?> raw;
}

/// Parsed VRM Animation asset.
final class VrmAnimationAsset {
  VrmAnimationAsset._({
    required this.gltf,
    required this.animation,
    required this.validation,
  });

  /// glTF data for the animation asset.
  final GltfAsset gltf;

  /// VRMC_vrm_animation extension data.
  final VrmAnimationExtension animation;

  /// Validation diagnostics from parsing.
  final VrmValidationResult validation;

  /// The default glTF animation index, when the file contains animations.
  int? get defaultAnimationIndex => gltf.animations.isEmpty ? null : 0;

  /// Parses a VRMA GLB or JSON glTF asset.
  static VrmAnimationAsset parse({
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
      throw VrmInvalidAssetException(
        'Invalid VRM Animation asset',
        result.validation,
      );
    }
    return asset;
  }

  /// Parses a VRMA GLB or JSON glTF asset without throwing for validation
  /// failures.
  static VrmParseResult<VrmAnimationAsset> tryParse({
    required Uint8List bytes,
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
  }) => _Parser.parseVrma(bytes, validation, uriResolver: uriResolver);
}
