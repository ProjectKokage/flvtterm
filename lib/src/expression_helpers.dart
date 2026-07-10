part of '../flvtterm.dart';

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
