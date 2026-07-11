part of '../../flvtterm.dart';

void _applyOverrideGroup(
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

  final blendEffect = _clamp01(blend);
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

VrmVector4 _baseMaterialColorForModel(
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

VrmVector4 _materialColorTarget(
  String type,
  VrmVector4 base,
  VrmVector4 target,
) {
  if (type == 'color') return target;
  return VrmVector4(target.x, target.y, target.z, base.w);
}

_TextureTransformAccum _baseTextureTransform(GltfMaterial material) {
  final transform = _firstTextureTransform(material);
  return _TextureTransformAccum(
    scale: transform?.scale ?? VrmVector2.one,
    offset: transform?.offset ?? VrmVector2.zero,
  );
}

_TextureTransformAccum _baseTextureTransformForModel(
  VrmModel model,
  int materialIndex,
) {
  final legacy = model
      .vrm0MaterialPropertyForGltfIndex(materialIndex)
      ?.vectorProperties['_MainTex'];
  if (legacy != null && legacy.length >= 4) {
    final scale = VrmVector2(legacy[0], legacy[1]);
    return _TextureTransformAccum(
      scale: scale,
      offset: VrmVector2(legacy[2], 1 - legacy[3] - scale.y),
    );
  }
  final material = model.gltf.materials.elementAtOrNull(materialIndex);
  return material == null
      ? _TextureTransformAccum(scale: VrmVector2.one, offset: VrmVector2.zero)
      : _baseTextureTransform(material);
}

GltfTextureTransform? _firstTextureTransform(GltfMaterial material) {
  for (final texture in [
    material.baseColorTexture,
    material.metallicRoughnessTexture,
    material.normalTexture,
    material.occlusionTexture,
    material.emissiveTexture,
    material.mtoon?.shadeMultiplyTexture,
    material.mtoon?.shadingShiftTexture,
    material.mtoon?.matcapTexture,
    material.mtoon?.rimMultiplyTexture,
    material.mtoon?.outlineWidthMultiplyTexture,
    material.mtoon?.uvAnimationMaskTexture,
  ]) {
    final transform = texture?.textureTransform;
    if (transform != null) return transform;
  }
  return null;
}
