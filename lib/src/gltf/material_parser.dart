part of '../../flvtterm.dart';

List<GltfMaterial> _parseMaterials(Object? value) {
  final list = _list(value);
  return [for (var i = 0; i < list.length; i++) _parseMaterial(i, list[i])];
}

GltfMaterial _parseMaterial(int index, Object? value) {
  final raw = _object(value);
  final pbr = _object(raw['pbrMetallicRoughness']);
  final extensions = _object(raw['extensions']);
  return GltfMaterial._(
    index: index,
    name: _string(raw['name']),
    baseColorFactor: _vector4(pbr['baseColorFactor'], VrmVector4.white),
    baseColorTexture: _parseTextureInfo(pbr['baseColorTexture']),
    metallicFactor: _double(pbr['metallicFactor']) ?? 1,
    roughnessFactor: _double(pbr['roughnessFactor']) ?? 1,
    metallicRoughnessTexture: _parseTextureInfo(
      pbr['metallicRoughnessTexture'],
    ),
    pbrMetallicRoughnessExtensions: _object(pbr['extensions']),
    pbrMetallicRoughnessExtras: pbr['extras'],
    normalTexture: _parseTextureInfo(raw['normalTexture'], defaultScale: 1),
    occlusionTexture: _parseTextureInfo(
      raw['occlusionTexture'],
      defaultStrength: 1,
    ),
    emissiveFactor: _vector3As4(
      raw['emissiveFactor'],
      const VrmVector4(0, 0, 0, 1),
    ),
    emissiveTexture: _parseTextureInfo(raw['emissiveTexture']),
    emissiveStrength: _parseEmissiveStrength(extensions),
    alphaMode:
        GltfAlphaMode.fromSpecName(_string(raw['alphaMode'])) ??
        GltfAlphaMode.opaque,
    alphaCutoff: _double(raw['alphaCutoff']) ?? 0.5,
    doubleSided: _bool(raw['doubleSided']) ?? false,
    unlit: extensions['KHR_materials_unlit'] is Map,
    mtoon: _parseMToonMaterial(extensions['VRMC_materials_mtoon']),
    extensions: extensions,
    extras: raw['extras'],
  );
}

double _parseEmissiveStrength(Object? extensions) {
  final raw = _object(_object(extensions)['KHR_materials_emissive_strength']);
  return _double(raw['emissiveStrength']) ?? 1;
}

VrmMToonMaterial? _parseMToonMaterial(Object? value) {
  if (value == null || value is! Map) return null;
  final raw = _object(value);
  const black = VrmVector4(0, 0, 0, 1);
  return VrmMToonMaterial._(
    specVersion: _string(raw['specVersion']),
    transparentWithZWrite: _bool(raw['transparentWithZWrite']) ?? false,
    renderQueueOffsetNumber: _int(raw['renderQueueOffsetNumber']) ?? 0,
    shadeColorFactor: _vector3As4(raw['shadeColorFactor'], black),
    shadeMultiplyTexture: _parseTextureInfo(raw['shadeMultiplyTexture']),
    shadingShiftFactor: _double(raw['shadingShiftFactor']) ?? 0,
    shadingShiftTexture: _parseTextureInfo(
      raw['shadingShiftTexture'],
      defaultScale: 1,
    ),
    shadingToonyFactor: _double(raw['shadingToonyFactor']) ?? 0.9,
    giEqualizationFactor: _double(raw['giEqualizationFactor']) ?? 0.9,
    matcapFactor: _vector3As4(raw['matcapFactor'], VrmVector4.white),
    matcapTexture: _parseTextureInfo(raw['matcapTexture']),
    parametricRimColorFactor: _vector3As4(
      raw['parametricRimColorFactor'],
      black,
    ),
    rimMultiplyTexture: _parseTextureInfo(raw['rimMultiplyTexture']),
    rimLightingMixFactor: _double(raw['rimLightingMixFactor']) ?? 1,
    parametricRimFresnelPowerFactor:
        _double(raw['parametricRimFresnelPowerFactor']) ?? 5,
    parametricRimLiftFactor: _double(raw['parametricRimLiftFactor']) ?? 0,
    outlineWidthMode:
        VrmMToonOutlineWidthMode.fromSpecName(
          _string(raw['outlineWidthMode']),
        ) ??
        VrmMToonOutlineWidthMode.none,
    outlineWidthFactor: _double(raw['outlineWidthFactor']) ?? 0,
    outlineWidthMultiplyTexture: _parseTextureInfo(
      raw['outlineWidthMultiplyTexture'],
    ),
    outlineColorFactor: _vector3As4(raw['outlineColorFactor'], black),
    outlineLightingMixFactor: _double(raw['outlineLightingMixFactor']) ?? 1,
    uvAnimationMaskTexture: _parseTextureInfo(raw['uvAnimationMaskTexture']),
    uvAnimationScrollXSpeedFactor:
        _double(raw['uvAnimationScrollXSpeedFactor']) ?? 0,
    uvAnimationScrollYSpeedFactor:
        _double(raw['uvAnimationScrollYSpeedFactor']) ?? 0,
    uvAnimationRotationSpeedFactor:
        _double(raw['uvAnimationRotationSpeedFactor']) ?? 0,
    extensions: _object(raw['extensions']),
    extras: raw['extras'],
    raw: raw,
  );
}

VrmTextureInfo? _parseTextureInfo(
  Object? value, {
  double? defaultScale,
  double? defaultStrength,
}) {
  final raw = _object(value);
  final index = _int(raw['index']);
  if (raw.isEmpty || index == null) return null;
  return VrmTextureInfo._(
    index: index,
    texCoord: _int(raw['texCoord']) ?? 0,
    scale: _double(raw['scale']) ?? defaultScale,
    strength: _double(raw['strength']) ?? defaultStrength,
    textureTransform: _parseTextureTransform(
      _object(raw['extensions'])['KHR_texture_transform'],
    ),
    raw: raw,
  );
}

GltfTextureTransform? _parseTextureTransform(Object? value) {
  final raw = _object(value);
  if (raw.isEmpty) return null;
  return GltfTextureTransform._(
    offset: _vector2(raw['offset'], VrmVector2.zero),
    rotation: _double(raw['rotation']) ?? 0,
    scale: _vector2(raw['scale'], VrmVector2.one),
    texCoord: _int(raw['texCoord']),
    raw: raw,
  );
}
