part of '../../flvtterm.dart';

/// Parsed VRM 0.x or VRM 1.0 model asset.
final class VrmModel {
  VrmModel._({
    required this.gltf,
    required this.vrm,
    required this.vrm0,
    required this.springBone,
    required this.validation,
  }) : sourceToRuntimeTransform = vrm.sourceVersion == VrmSourceVersion.vrm0
           ? _vrm0SourceToRuntimeTransform
           : VrmMatrix4.identity();

  /// glTF data for the model.
  final GltfAsset gltf;

  /// Runtime-facing extension data normalized from the source version.
  final VrmExtension vrm;

  /// Typed legacy extension data for a VRM 0.x asset.
  ///
  /// This remains null for VRM 1.0. Use it for legacy metadata, Unity
  /// material properties, or other fields that cannot be represented
  /// losslessly by the normalized runtime-facing [vrm] view.
  final Vrm0Extension? vrm0;

  /// Source specification family.
  VrmSourceVersion get sourceVersion => vrm.sourceVersion;

  /// Whether this model was loaded from a legacy VRM 0.x extension.
  bool get isVrm0 => sourceVersion == VrmSourceVersion.vrm0;

  /// Whether this model was loaded from a VRM 1.0 extension.
  bool get isVrm1 => sourceVersion == VrmSourceVersion.vrm1;

  /// Transform from the source model convention to the runtime convention.
  ///
  /// Runtime model space always faces +Z. VRM 0.x source glTF faces -Z, so its
  /// transform is a 180-degree Y rotation. VRM 1.0 uses identity.
  final VrmMatrix4 sourceToRuntimeTransform;

  /// Returns the legacy material-property entry aligned with [materialIndex].
  Vrm0MaterialProperty? vrm0MaterialPropertyForGltfIndex(int materialIndex) {
    if (materialIndex < 0) return null;
    return vrm0?.materialProperties.elementAtOrNull(materialIndex);
  }

  /// Selects the preferred renderer path for one material across VRM versions.
  GltfMaterialRenderMode preferredRenderModeForMaterial(
    int materialIndex, {
    bool supportsMToon = true,
  }) {
    final material = gltf.materials.elementAtOrNull(materialIndex);
    if (material == null) return GltfMaterialRenderMode.pbr;
    final legacyShader = vrm0MaterialPropertyForGltfIndex(
      materialIndex,
    )?.shader;
    if (_vrm0ShaderUsesMToon(legacyShader)) {
      if (supportsMToon) return GltfMaterialRenderMode.mtoon;
      return material.unlit
          ? GltfMaterialRenderMode.unlit
          : GltfMaterialRenderMode.pbr;
    }
    if (_vrm0ShaderIsUnlit(legacyShader)) {
      return GltfMaterialRenderMode.unlit;
    }
    return material.preferredRenderMode(supportsMToon: supportsMToon);
  }

  /// Returns a capability warning when legacy MToon must use glTF fallback.
  VrmDiagnostic? vrm0MtoonFallbackWarning(
    int materialIndex, {
    bool supportsMToon = false,
  }) {
    final property = vrm0MaterialPropertyForGltfIndex(materialIndex);
    if (property == null ||
        !_vrm0ShaderUsesMToon(property.shader) ||
        supportsMToon) {
      return null;
    }
    final fallback = preferredRenderModeForMaterial(
      materialIndex,
      supportsMToon: false,
    );
    return VrmDiagnostic(
      severity: const VrmWarning(),
      code: 'vrm0.mtoonFallback',
      message:
          'Renderer does not support legacy ${property.shader} for material $materialIndex; use ${fallback.specName} fallback.',
      jsonPath: '\$.extensions.VRM.materialProperties[$materialIndex]',
      gltfMaterialIndex: materialIndex,
    );
  }

  /// Normalized SpringBone data, when present in either VRM version.
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

  /// Parses a VRM 0.x or VRM 1.0 GLB.
  ///
  /// Throws in strict mode when version-specific validation fails.
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

  /// Parses either VRM version without throwing for asset validation failures.
  static VrmParseResult<VrmModel> tryParseGlb(
    Uint8List bytes, {
    VrmValidationMode validation = VrmValidationMode.strict,
    GltfUriResolver? uriResolver,
  }) => _Parser.parseVrmGlb(bytes, validation, uriResolver: uriResolver);
}

final _vrm0SourceToRuntimeTransform = VrmMatrix4(const [
  -1,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  -1,
  0,
  0,
  0,
  0,
  1,
]);

bool _vrm0ShaderUsesMToon(String? shader) =>
    shader == 'VRM/MToon' || shader == 'VRM/UnlitTransparentZWrite';

bool _vrm0ShaderIsUnlit(String? shader) =>
    shader == 'UniGLTF/UniUnlit' ||
    shader == 'VRM/UnlitTexture' ||
    shader == 'VRM/UnlitCutout' ||
    shader == 'VRM/UnlitTransparent' ||
    shader == 'Unlit/Color' ||
    shader == 'Unlit/Texture' ||
    shader == 'Unlit/Transparent' ||
    shader == 'Unlit/Transparent Cutout';

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

  /// Optional LookAt animation node index.
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
