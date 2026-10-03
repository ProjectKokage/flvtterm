import 'package:meta/meta.dart';

import '../json_values.dart';
import '../math_types.dart';
import 'gltf_material_types.dart';

@internal
List<GltfMaterial> parseMaterials(Object? value) {
  final list = jsonList(value);
  return [for (var i = 0; i < list.length; i++) _parseMaterial(i, list[i])];
}

GltfMaterial _parseMaterial(int index, Object? value) {
  final raw = jsonObject(value);
  final pbr = jsonObject(raw['pbrMetallicRoughness']);
  final extensions = jsonObject(raw['extensions']);
  return GltfMaterial.internal(
    index: index,
    name: jsonString(raw['name']),
    baseColorFactor: jsonVector4(pbr['baseColorFactor'], VrmVector4.white),
    baseColorTexture: _parseTextureInfo(pbr['baseColorTexture']),
    metallicFactor: jsonDouble(pbr['metallicFactor']) ?? 1,
    roughnessFactor: jsonDouble(pbr['roughnessFactor']) ?? 1,
    metallicRoughnessTexture: _parseTextureInfo(
      pbr['metallicRoughnessTexture'],
    ),
    pbrMetallicRoughnessExtensions: jsonObject(pbr['extensions']),
    pbrMetallicRoughnessExtras: pbr['extras'],
    normalTexture: _parseTextureInfo(raw['normalTexture'], defaultScale: 1),
    occlusionTexture: _parseTextureInfo(
      raw['occlusionTexture'],
      defaultStrength: 1,
    ),
    emissiveFactor: jsonVector3As4(
      raw['emissiveFactor'],
      const VrmVector4(0, 0, 0, 1),
    ),
    emissiveTexture: _parseTextureInfo(raw['emissiveTexture']),
    emissiveStrength: _parseEmissiveStrength(extensions),
    alphaMode:
        GltfAlphaMode.fromSpecName(jsonString(raw['alphaMode'])) ??
        GltfAlphaMode.opaque,
    alphaCutoff: jsonDouble(raw['alphaCutoff']) ?? 0.5,
    doubleSided: jsonBool(raw['doubleSided']) ?? false,
    unlit: extensions['KHR_materials_unlit'] is Map,
    mtoon: _parseMToonMaterial(extensions['VRMC_materials_mtoon']),
    extensions: extensions,
    extras: raw['extras'],
  );
}

double _parseEmissiveStrength(Object? extensions) {
  final raw = jsonObject(
    jsonObject(extensions)['KHR_materials_emissive_strength'],
  );
  return jsonDouble(raw['emissiveStrength']) ?? 1;
}

VrmMToonMaterial? _parseMToonMaterial(Object? value) {
  if (value == null || value is! Map) return null;
  final raw = jsonObject(value);
  const black = VrmVector4(0, 0, 0, 1);
  return VrmMToonMaterial.internal(
    specVersion: jsonString(raw['specVersion']),
    transparentWithZWrite: jsonBool(raw['transparentWithZWrite']) ?? false,
    renderQueueOffsetNumber: jsonInt(raw['renderQueueOffsetNumber']) ?? 0,
    shadeColorFactor: jsonVector3As4(raw['shadeColorFactor'], black),
    shadeMultiplyTexture: _parseTextureInfo(raw['shadeMultiplyTexture']),
    shadingShiftFactor: jsonDouble(raw['shadingShiftFactor']) ?? 0,
    shadingShiftTexture: _parseTextureInfo(
      raw['shadingShiftTexture'],
      defaultScale: 1,
    ),
    shadingToonyFactor: jsonDouble(raw['shadingToonyFactor']) ?? 0.9,
    giEqualizationFactor: jsonDouble(raw['giEqualizationFactor']) ?? 0.9,
    matcapFactor: jsonVector3As4(raw['matcapFactor'], VrmVector4.white),
    matcapTexture: _parseTextureInfo(raw['matcapTexture']),
    parametricRimColorFactor: jsonVector3As4(
      raw['parametricRimColorFactor'],
      black,
    ),
    rimMultiplyTexture: _parseTextureInfo(raw['rimMultiplyTexture']),
    rimLightingMixFactor: jsonDouble(raw['rimLightingMixFactor']) ?? 1,
    parametricRimFresnelPowerFactor:
        jsonDouble(raw['parametricRimFresnelPowerFactor']) ?? 5,
    parametricRimLiftFactor: jsonDouble(raw['parametricRimLiftFactor']) ?? 0,
    outlineWidthMode:
        VrmMToonOutlineWidthMode.fromSpecName(
          jsonString(raw['outlineWidthMode']),
        ) ??
        VrmMToonOutlineWidthMode.none,
    outlineWidthFactor: jsonDouble(raw['outlineWidthFactor']) ?? 0,
    outlineWidthMultiplyTexture: _parseTextureInfo(
      raw['outlineWidthMultiplyTexture'],
    ),
    outlineColorFactor: jsonVector3As4(raw['outlineColorFactor'], black),
    outlineLightingMixFactor: jsonDouble(raw['outlineLightingMixFactor']) ?? 1,
    uvAnimationMaskTexture: _parseTextureInfo(raw['uvAnimationMaskTexture']),
    uvAnimationScrollXSpeedFactor:
        jsonDouble(raw['uvAnimationScrollXSpeedFactor']) ?? 0,
    uvAnimationScrollYSpeedFactor:
        jsonDouble(raw['uvAnimationScrollYSpeedFactor']) ?? 0,
    uvAnimationRotationSpeedFactor:
        jsonDouble(raw['uvAnimationRotationSpeedFactor']) ?? 0,
    extensions: jsonObject(raw['extensions']),
    extras: raw['extras'],
    raw: raw,
  );
}

VrmTextureInfo? _parseTextureInfo(
  Object? value, {
  double? defaultScale,
  double? defaultStrength,
}) {
  final raw = jsonObject(value);
  final index = jsonInt(raw['index']);
  if (raw.isEmpty || index == null) return null;
  return VrmTextureInfo.internal(
    index: index,
    texCoord: jsonInt(raw['texCoord']) ?? 0,
    scale: jsonDouble(raw['scale']) ?? defaultScale,
    strength: jsonDouble(raw['strength']) ?? defaultStrength,
    textureTransform: _parseTextureTransform(
      jsonObject(raw['extensions'])['KHR_texture_transform'],
    ),
    raw: raw,
  );
}

GltfTextureTransform? _parseTextureTransform(Object? value) {
  final raw = jsonObject(value);
  if (raw.isEmpty) return null;
  return GltfTextureTransform.internal(
    offset: jsonVector2(raw['offset'], VrmVector2.zero),
    rotation: jsonDouble(raw['rotation']) ?? 0,
    scale: jsonVector2(raw['scale'], VrmVector2.one),
    texCoord: jsonInt(raw['texCoord']),
    raw: raw,
  );
}
