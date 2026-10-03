import 'package:meta/meta.dart';

import '../gltf/animation_math.dart';
import '../gltf/gltf_material_types.dart';
import '../math_types.dart';
import '../safe_list_index.dart';
import '../vrm/vrm_assets.dart';
import '../vrm/vrm_enums.dart';
import '../vrm/vrm_types.dart';
import 'scene_binding.dart';

@internal
void applyOverrideGroup(
  Map<String, VrmExpression> definitions,
  Map<String, double> output,
  Iterable<String> targetNames,
  VrmExpressionOverrideMode Function(VrmExpression expression) modeOf,
) {
  var blocked = false;
  var blend = 0.0;

  for (final entry in definitions.entries) {
    final value = output[entry.key] ?? 0;
    if (value == 0) continue;
    switch (modeOf(entry.value)) {
      case VrmExpressionOverrideMode.none:
        break;
      case VrmExpressionOverrideMode.block:
        blocked = true;
      case VrmExpressionOverrideMode.blend:
        blend += value;
    }
  }

  final blendEffect = clamp01(blend);
  for (final name in targetNames) {
    final expression = definitions[name];
    if (expression == null) continue;
    if (blocked || (expression.isBinary && blendEffect > 0)) {
      output[name] = 0;
    } else if (blendEffect > 0) {
      output[name] = (output[name] ?? 0) * (1 - blendEffect);
    }
  }
}

VrmVector4 _baseMaterialColor(GltfMaterial material, String type) {
  return switch (type) {
    'color' => material.baseColorFactor,
    'emissionColor' => material.emissiveFactor,
    'shadeColor' => material.mtoon?.shadeColorFactor ?? VrmVector4.zero,
    'matcapColor' => material.mtoon?.matcapFactor ?? VrmVector4.zero,
    'rimColor' => material.mtoon?.parametricRimColorFactor ?? VrmVector4.zero,
    'outlineColor' => material.mtoon?.outlineColorFactor ?? VrmVector4.zero,
    _ => VrmVector4.zero,
  };
}

@internal
VrmVector4 baseMaterialColorForModel(
  VrmModel model,
  int materialIndex,
  String type,
) {
  final legacy = model.vrm0MaterialPropertyForGltfIndex(materialIndex);
  final legacyKey = switch (type) {
    'color' => '_Color',
    'emissionColor' => '_EmissionColor',
    'shadeColor' => '_ShadeColor',
    'matcapColor' => '_MatCapColor',
    'rimColor' => '_RimColor',
    'outlineColor' => '_OutlineColor',
    _ => null,
  };
  final values = legacyKey == null ? null : legacy?.vectorProperties[legacyKey];
  if (values != null && values.length >= 3) {
    return VrmVector4(
      values[0],
      values[1],
      values[2],
      values.length >= 4 ? values[3] : 1,
    );
  }
  final material = model.gltf.materials.elementAtOrNull(materialIndex);
  return material == null
      ? VrmVector4.zero
      : _baseMaterialColor(material, type);
}

@internal
VrmVector4 materialColorTarget(
  String type,
  VrmVector4 base,
  VrmVector4 target,
) {
  if (type == 'color') return target;
  return VrmVector4(target.x, target.y, target.z, base.w);
}

@internal
TextureTransformAccum baseTextureTransform(GltfMaterial material) {
  final transforms = _baseTextureTransforms(material);
  if (transforms.isEmpty) return TextureTransformAccum();
  final first = transforms.values.first;
  return TextureTransformAccum(scale: first.scale, offset: first.offset);
}

@internal
Map<VrmMaterialTextureSlot, TextureTransformAccum>
baseTextureTransformsForModel(VrmModel model, int materialIndex) {
  final result = <VrmMaterialTextureSlot, TextureTransformAccum>{};
  final legacy = model
      .vrm0MaterialPropertyForGltfIndex(materialIndex)
      ?.vectorProperties['_MainTex'];
  if (legacy != null && legacy.length >= 4) {
    final scale = VrmVector2(legacy[0], legacy[1]);
    result[VrmMaterialTextureSlot.baseColor] = TextureTransformAccum(
      scale: scale,
      offset: VrmVector2(legacy[2], 1 - legacy[3] - scale.y),
    );
  } else if (model.isVrm0) {
    // Legacy material-value binds target Unity's conceptual _MainTex even when
    // the glTF fallback omits a base-color texture reference.
    result[VrmMaterialTextureSlot.baseColor] = TextureTransformAccum();
  }
  final material = model.gltf.materials.elementAtOrNull(materialIndex);
  if (material == null) return result;
  for (final entry in _baseTextureTransforms(material).entries) {
    result.putIfAbsent(entry.key, () => entry.value);
  }
  return result;
}

Map<VrmMaterialTextureSlot, TextureTransformAccum> _baseTextureTransforms(
  GltfMaterial material,
) {
  final result = <VrmMaterialTextureSlot, TextureTransformAccum>{};
  for (final entry in _uvAccessedMaterialTextures(material)) {
    final transform = entry.texture.textureTransform;
    result[entry.slot] = TextureTransformAccum(
      scale: transform?.scale ?? VrmVector2.one,
      offset: transform?.offset ?? VrmVector2.zero,
    );
  }
  return result;
}

Iterable<({VrmMaterialTextureSlot slot, VrmTextureInfo texture})>
_uvAccessedMaterialTextures(GltfMaterial material) sync* {
  final textures = <({VrmMaterialTextureSlot slot, VrmTextureInfo? texture})>[
    (
      slot: VrmMaterialTextureSlot.baseColor,
      texture: material.baseColorTexture,
    ),
    (
      slot: VrmMaterialTextureSlot.metallicRoughness,
      texture: material.metallicRoughnessTexture,
    ),
    (slot: VrmMaterialTextureSlot.normal, texture: material.normalTexture),
    (
      slot: VrmMaterialTextureSlot.occlusion,
      texture: material.occlusionTexture,
    ),
    (slot: VrmMaterialTextureSlot.emissive, texture: material.emissiveTexture),
    (
      slot: VrmMaterialTextureSlot.mtoonShadeMultiply,
      texture: material.mtoon?.shadeMultiplyTexture,
    ),
    (
      slot: VrmMaterialTextureSlot.mtoonShadingShift,
      texture: material.mtoon?.shadingShiftTexture,
    ),
    (
      slot: VrmMaterialTextureSlot.mtoonRimMultiply,
      texture: material.mtoon?.rimMultiplyTexture,
    ),
    (
      slot: VrmMaterialTextureSlot.mtoonOutlineWidthMultiply,
      texture: material.mtoon?.outlineWidthMultiplyTexture,
    ),
    (
      slot: VrmMaterialTextureSlot.mtoonUvAnimationMask,
      texture: material.mtoon?.uvAnimationMaskTexture,
    ),
  ];
  for (final entry in textures) {
    final texture = entry.texture;
    if (texture != null) yield (slot: entry.slot, texture: texture);
  }
}

@internal
void setTextureTransforms(
  VrmMaterialBinding binding,
  Map<VrmMaterialTextureSlot, TextureTransformAccum> transforms,
) {
  if (transforms.isEmpty) return;
  if (binding is VrmPerTextureMaterialBinding) {
    for (final entry in transforms.entries) {
      binding.setTextureTransformForTexture(
        entry.key,
        scale: entry.value.scale,
        offset: entry.value.offset,
      );
    }
    return;
  }
  final transform = transforms.values.first;
  binding.setTextureTransform(scale: transform.scale, offset: transform.offset);
}

@internal
final class TextureTransformAccum {
  TextureTransformAccum({
    this.scale = VrmVector2.one,
    this.offset = VrmVector2.zero,
  });

  VrmVector2 scale;
  VrmVector2 offset;
}
