part of '../../flvtterm.dart';

/// glTF alpha coverage mode.
enum GltfAlphaMode {
  /// Fully opaque rendering.
  opaque('OPAQUE'),

  /// Alpha cutoff mask rendering.
  mask('MASK'),

  /// Alpha blended rendering.
  blend('BLEND');

  const GltfAlphaMode(this.specName);

  /// Raw glTF spec name.
  final String specName;

  /// Converts a raw glTF alpha mode name to an enum value.
  static GltfAlphaMode? fromSpecName(String? name) {
    for (final value in values) {
      if (value.specName == name) return value;
    }
    return null;
  }
}

/// Renderer path selected for a glTF material.
enum GltfMaterialRenderMode {
  /// glTF metallic-roughness material.
  pbr('pbr'),

  /// `KHR_materials_unlit` fallback.
  unlit('unlit'),

  /// Native `VRMC_materials_mtoon` material.
  mtoon('mtoon');

  const GltfMaterialRenderMode(this.specName);

  /// Stable lowercase name.
  final String specName;
}

/// Parsed glTF material.
final class GltfMaterial {
  GltfMaterial._({
    required this.index,
    required this.name,
    required this.baseColorFactor,
    required this.baseColorTexture,
    required this.metallicFactor,
    required this.roughnessFactor,
    required this.metallicRoughnessTexture,
    required Map<String, Object?> pbrMetallicRoughnessExtensions,
    required Object? pbrMetallicRoughnessExtras,
    required this.normalTexture,
    required this.occlusionTexture,
    required this.emissiveFactor,
    required this.emissiveTexture,
    required this.emissiveStrength,
    required this.alphaMode,
    required this.alphaCutoff,
    required this.doubleSided,
    required this.unlit,
    required this.mtoon,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : pbrMetallicRoughnessExtensions =
           _immutableJsonValue(pbrMetallicRoughnessExtensions)
               as Map<String, Object?>,
       pbrMetallicRoughnessExtras = _immutableJsonValue(
         pbrMetallicRoughnessExtras,
       ),
       extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// glTF material index.
  final int index;

  /// Optional material name.
  final String? name;

  /// PBR base color factor.
  final VrmVector4 baseColorFactor;

  /// PBR base color texture.
  final VrmTextureInfo? baseColorTexture;

  /// PBR metallic factor.
  final double metallicFactor;

  /// PBR roughness factor.
  final double roughnessFactor;

  /// PBR metallic-roughness texture.
  final VrmTextureInfo? metallicRoughnessTexture;

  /// `pbrMetallicRoughness.extensions`, preserved.
  final Map<String, Object?> pbrMetallicRoughnessExtensions;

  /// `pbrMetallicRoughness.extras`, preserved.
  final Object? pbrMetallicRoughnessExtras;

  /// Normal texture.
  final VrmTextureInfo? normalTexture;

  /// Occlusion texture.
  final VrmTextureInfo? occlusionTexture;

  /// Emissive factor stored as RGB with alpha 1.
  final VrmVector4 emissiveFactor;

  /// Emissive texture.
  final VrmTextureInfo? emissiveTexture;

  /// `KHR_materials_emissive_strength` multiplier.
  final double emissiveStrength;

  /// Alpha coverage mode.
  final GltfAlphaMode alphaMode;

  /// Alpha cutoff threshold used by [GltfAlphaMode.mask].
  final double alphaCutoff;

  /// Whether both material sides should be rendered.
  final bool doubleSided;

  /// Whether `KHR_materials_unlit` is present.
  final bool unlit;

  /// VRMC_materials_mtoon metadata, when present.
  final VrmMToonMaterial? mtoon;

  /// Material extensions, preserved.
  final Map<String, Object?> extensions;

  /// Material extras, preserved.
  final Object? extras;

  /// Preferred renderer path, falling back from MToon when unsupported.
  GltfMaterialRenderMode preferredRenderMode({bool supportsMToon = true}) {
    if (mtoon != null && supportsMToon) return GltfMaterialRenderMode.mtoon;
    if (unlit) return GltfMaterialRenderMode.unlit;
    return GltfMaterialRenderMode.pbr;
  }

  /// Capability warning when a renderer has to fall back from MToon.
  VrmDiagnostic? mtoonFallbackWarning({bool supportsMToon = false}) {
    if (mtoon == null || supportsMToon) return null;
    final fallback = preferredRenderMode(supportsMToon: false);
    return VrmDiagnostic(
      severity: const VrmWarning(),
      code: 'mtoon.fallback',
      message:
          'Renderer does not support native MToon for material $index; use ${fallback.specName} fallback.',
      jsonPath: '\$.materials[$index].extensions.VRMC_materials_mtoon',
      gltfMaterialIndex: index,
    );
  }
}

/// Parsed MToon outline width mode.
enum VrmMToonOutlineWidthMode {
  /// No outline.
  none('none'),

  /// Outline width is in world-space meters.
  worldCoordinates('worldCoordinates'),

  /// Outline width is a ratio of screen height.
  screenCoordinates('screenCoordinates');

  const VrmMToonOutlineWidthMode(this.specName);

  /// Raw VRMC_materials_mtoon spec name.
  final String specName;

  /// Looks up an outline width mode by raw spec name.
  static VrmMToonOutlineWidthMode? fromSpecName(String? name) {
    for (final value in values) {
      if (value.specName == name) return value;
    }
    return null;
  }
}

/// Texture reference used by VRM extension metadata.
final class VrmTextureInfo {
  VrmTextureInfo._({
    required this.index,
    required this.texCoord,
    required this.scale,
    required this.strength,
    required this.textureTransform,
    required Map<String, Object?> raw,
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// glTF texture index.
  final int index;

  /// TEXCOORD set index.
  final int texCoord;

  /// Optional scalar texture contribution used by some extension texture infos.
  final double? scale;

  /// Optional occlusion strength.
  final double? strength;

  /// Optional `KHR_texture_transform` metadata.
  final GltfTextureTransform? textureTransform;

  /// Raw texture info object, preserved.
  final Map<String, Object?> raw;
}

/// Parsed `KHR_texture_transform` textureInfo extension.
final class GltfTextureTransform {
  GltfTextureTransform._({
    required this.offset,
    required this.rotation,
    required this.scale,
    required this.texCoord,
    required Map<String, Object?> raw,
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// UV offset.
  final VrmVector2 offset;

  /// UV rotation in radians.
  final double rotation;

  /// UV scale.
  final VrmVector2 scale;

  /// Optional transformed TEXCOORD override.
  final int? texCoord;

  /// Raw texture transform object, preserved.
  final Map<String, Object?> raw;
}

/// Parsed `VRMC_materials_mtoon` material extension.
final class VrmMToonMaterial {
  VrmMToonMaterial._({
    required this.specVersion,
    required this.transparentWithZWrite,
    required this.renderQueueOffsetNumber,
    required this.shadeColorFactor,
    required this.shadeMultiplyTexture,
    required this.shadingShiftFactor,
    required this.shadingShiftTexture,
    required this.shadingToonyFactor,
    required this.giEqualizationFactor,
    required this.matcapFactor,
    required this.matcapTexture,
    required this.parametricRimColorFactor,
    required this.rimMultiplyTexture,
    required this.rimLightingMixFactor,
    required this.parametricRimFresnelPowerFactor,
    required this.parametricRimLiftFactor,
    required this.outlineWidthMode,
    required this.outlineWidthFactor,
    required this.outlineWidthMultiplyTexture,
    required this.outlineColorFactor,
    required this.outlineLightingMixFactor,
    required this.uvAnimationMaskTexture,
    required this.uvAnimationScrollXSpeedFactor,
    required this.uvAnimationScrollYSpeedFactor,
    required this.uvAnimationRotationSpeedFactor,
    required Map<String, Object?> extensions,
    required Object? extras,
    required Map<String, Object?> raw,
  }) : extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// VRMC_materials_mtoon spec version.
  final String? specVersion;

  /// Whether depth write is requested for blended alpha.
  final bool transparentWithZWrite;

  /// Render queue offset.
  final int renderQueueOffsetNumber;

  /// Shade color factor.
  final VrmVector4 shadeColorFactor;

  /// Shade multiply texture.
  final VrmTextureInfo? shadeMultiplyTexture;

  /// Shading boundary shift.
  final double shadingShiftFactor;

  /// Shading shift texture.
  final VrmTextureInfo? shadingShiftTexture;

  /// Shading feather/toony factor.
  final double shadingToonyFactor;

  /// Global illumination equalization factor.
  final double giEqualizationFactor;

  /// MatCap color factor.
  final VrmVector4 matcapFactor;

  /// MatCap texture.
  final VrmTextureInfo? matcapTexture;

  /// Parametric rim color.
  final VrmVector4 parametricRimColorFactor;

  /// Rim multiply texture.
  final VrmTextureInfo? rimMultiplyTexture;

  /// Rim lighting mix factor.
  final double rimLightingMixFactor;

  /// Parametric rim fresnel power.
  final double parametricRimFresnelPowerFactor;

  /// Parametric rim lift.
  final double parametricRimLiftFactor;

  /// Outline width mode.
  final VrmMToonOutlineWidthMode outlineWidthMode;

  /// Outline width factor.
  final double outlineWidthFactor;

  /// Outline width multiply texture.
  final VrmTextureInfo? outlineWidthMultiplyTexture;

  /// Outline color factor.
  final VrmVector4 outlineColorFactor;

  /// Outline lighting mix factor.
  final double outlineLightingMixFactor;

  /// UV animation mask texture.
  final VrmTextureInfo? uvAnimationMaskTexture;

  /// UV scroll speed in the X direction.
  final double uvAnimationScrollXSpeedFactor;

  /// UV scroll speed in the Y direction.
  final double uvAnimationScrollYSpeedFactor;

  /// UV rotation speed in radians per second.
  final double uvAnimationRotationSpeedFactor;

  /// MToon extension extensions, preserved.
  final Map<String, Object?> extensions;

  /// MToon extension extras, preserved.
  final Object? extras;

  /// Raw MToon object, preserved.
  final Map<String, Object?> raw;
}
