part of '../../flvtterm.dart';

void _validateGltfMaterials(GltfAsset gltf, _DiagnosticSink sink) {
  final rawMaterials = _list(gltf.json['materials']);
  for (final material in gltf.materials) {
    final raw = _object(rawMaterials.elementAtOrNull(material.index));
    final extensions = _object(raw['extensions']);
    _validateMaterialExtensionObject(
      extensions,
      'KHR_materials_emissive_strength',
      sink,
      'gltf.invalidMaterialEmissiveStrengthObject',
      _materialPath(
        material.index,
        '.extensions.KHR_materials_emissive_strength',
      ),
      material.index,
    );
    _validateMaterialExtensionObject(
      extensions,
      'KHR_materials_unlit',
      sink,
      'gltf.invalidMaterialUnlitObject',
      _materialPath(material.index, '.extensions.KHR_materials_unlit'),
      material.index,
    );
    _validateMaterialExtensionObject(
      extensions,
      'VRMC_materials_mtoon',
      sink,
      'mtoon.invalidExtensionObject',
      _mtoonPath(material.index, ''),
      material.index,
    );
    if (raw.containsKey('pbrMetallicRoughness') &&
        raw['pbrMetallicRoughness'] is! Map) {
      sink.error(
        'gltf.invalidMaterialPbrMetallicRoughness',
        'Material pbrMetallicRoughness must be a JSON object.',
        jsonPath: _materialPath(material.index, '.pbrMetallicRoughness'),
        gltfMaterialIndex: material.index,
      );
    }
    final pbr = _object(raw['pbrMetallicRoughness']);
    _validateMaterialColorFactor(
      pbr,
      'baseColorFactor',
      4,
      sink,
      'gltf.invalidMaterialBaseColorFactor',
      'Material baseColorFactor must be an array of 4 numbers in the range 0..1.',
      _materialPath(material.index, '.pbrMetallicRoughness.baseColorFactor'),
      material.index,
    );
    _validateMaterialFactor(
      pbr,
      'metallicFactor',
      sink,
      'gltf.invalidMaterialMetallicFactor',
      'Material metallicFactor must be a number in the range 0..1.',
      material.index,
    );
    _validateMaterialFactor(
      pbr,
      'roughnessFactor',
      sink,
      'gltf.invalidMaterialRoughnessFactor',
      'Material roughnessFactor must be a number in the range 0..1.',
      material.index,
    );
    _validateMaterialColorFactor(
      raw,
      'emissiveFactor',
      3,
      sink,
      'gltf.invalidMaterialEmissiveFactor',
      'Material emissiveFactor must be an array of 3 numbers in the range 0..1.',
      _materialPath(material.index, '.emissiveFactor'),
      material.index,
    );
    final emissiveStrengthExtension = _object(
      extensions['KHR_materials_emissive_strength'],
    );
    if (emissiveStrengthExtension.containsKey('emissiveStrength')) {
      final emissiveStrength = emissiveStrengthExtension['emissiveStrength'];
      if (emissiveStrength is! num || emissiveStrength < 0) {
        sink.error(
          'gltf.invalidMaterialEmissiveStrength',
          'KHR_materials_emissive_strength.emissiveStrength must be a non-negative number.',
          jsonPath: _materialPath(
            material.index,
            '.extensions.KHR_materials_emissive_strength.emissiveStrength',
          ),
          gltfMaterialIndex: material.index,
        );
      }
    }
    if (raw.containsKey('alphaMode')) {
      final alphaMode = raw['alphaMode'];
      if (alphaMode is! String ||
          GltfAlphaMode.fromSpecName(alphaMode) == null) {
        sink.error(
          'gltf.invalidMaterialAlphaMode',
          'Material alphaMode must be OPAQUE, MASK, or BLEND.',
          jsonPath: _materialPath(material.index, '.alphaMode'),
          gltfMaterialIndex: material.index,
        );
      }
    }
    _validateMaterialMinimum(
      raw,
      'alphaCutoff',
      0,
      sink,
      'gltf.invalidMaterialAlphaCutoff',
      'Material alphaCutoff must be a non-negative number.',
      material.index,
    );
    if (raw.containsKey('alphaCutoff') && !raw.containsKey('alphaMode')) {
      sink.error(
        'gltf.materialAlphaCutoffWithoutAlphaMode',
        'Material alphaCutoff must not be defined when alphaMode is omitted.',
        jsonPath: _materialPath(material.index, '.alphaCutoff'),
        gltfMaterialIndex: material.index,
      );
    }
    if (raw.containsKey('doubleSided') && raw['doubleSided'] is! bool) {
      sink.error(
        'gltf.invalidMaterialDoubleSided',
        'Material doubleSided must be a boolean.',
        jsonPath: _materialPath(material.index, '.doubleSided'),
        gltfMaterialIndex: material.index,
      );
    }
    _validateTextureInfoIndex(
      pbr,
      'baseColorTexture',
      sink,
      'gltf.invalidMaterialBaseColorTexture',
      _materialPath(material.index, '.pbrMetallicRoughness.baseColorTexture'),
      material.index,
    );
    _validateTextureInfoIndex(
      pbr,
      'metallicRoughnessTexture',
      sink,
      'gltf.invalidMaterialMetallicRoughnessTexture',
      _materialPath(
        material.index,
        '.pbrMetallicRoughness.metallicRoughnessTexture',
      ),
      material.index,
    );
    _validateTextureInfoIndex(
      raw,
      'normalTexture',
      sink,
      'gltf.invalidMaterialNormalTexture',
      _materialPath(material.index, '.normalTexture'),
      material.index,
    );
    _validateTextureInfoIndex(
      raw,
      'occlusionTexture',
      sink,
      'gltf.invalidMaterialOcclusionTexture',
      _materialPath(material.index, '.occlusionTexture'),
      material.index,
    );
    _validateTextureInfoIndex(
      raw,
      'emissiveTexture',
      sink,
      'gltf.invalidMaterialEmissiveTexture',
      _materialPath(material.index, '.emissiveTexture'),
      material.index,
    );
    _validateTextureInfo(
      material.baseColorTexture,
      pbr['baseColorTexture'],
      gltf,
      sink,
      'gltf.invalidMaterialBaseColorTexture',
      _materialPath(material.index, '.pbrMetallicRoughness.baseColorTexture'),
      material.index,
    );
    _validateTextureInfo(
      material.metallicRoughnessTexture,
      pbr['metallicRoughnessTexture'],
      gltf,
      sink,
      'gltf.invalidMaterialMetallicRoughnessTexture',
      _materialPath(
        material.index,
        '.pbrMetallicRoughness.metallicRoughnessTexture',
      ),
      material.index,
    );
    _validateTextureInfo(
      material.normalTexture,
      raw['normalTexture'],
      gltf,
      sink,
      'gltf.invalidMaterialNormalTexture',
      _materialPath(material.index, '.normalTexture'),
      material.index,
    );
    _validateNormalTextureScale(
      material.normalTexture,
      raw['normalTexture'],
      material.index,
      sink,
    );
    _validateTextureInfo(
      material.occlusionTexture,
      raw['occlusionTexture'],
      gltf,
      sink,
      'gltf.invalidMaterialOcclusionTexture',
      _materialPath(material.index, '.occlusionTexture'),
      material.index,
    );
    _validateTextureInfo(
      material.emissiveTexture,
      raw['emissiveTexture'],
      gltf,
      sink,
      'gltf.invalidMaterialEmissiveTexture',
      _materialPath(material.index, '.emissiveTexture'),
      material.index,
    );
  }
}

String _materialPath(int materialIndex, String suffix) =>
    '\$.materials[$materialIndex]$suffix';

void _validateMaterialExtensionObject(
  Map<String, Object?> extensions,
  String key,
  _DiagnosticSink sink,
  String code,
  String jsonPath,
  int materialIndex,
) {
  if (!extensions.containsKey(key) || extensions[key] is Map) return;
  sink.error(
    code,
    '$key must be a JSON object.',
    jsonPath: jsonPath,
    gltfMaterialIndex: materialIndex,
  );
}

void _validateMaterialColorFactor(
  Map<String, Object?> raw,
  String key,
  int expectedLength,
  _DiagnosticSink sink,
  String code,
  String message,
  String jsonPath,
  int materialIndex,
) {
  if (!raw.containsKey(key)) return;
  final values = _list(raw[key]);
  if (values.length == expectedLength &&
      values.every((value) => value is num && value >= 0 && value <= 1)) {
    return;
  }
  sink.error(
    code,
    message,
    jsonPath: jsonPath,
    gltfMaterialIndex: materialIndex,
  );
}

void _validateMaterialFactor(
  Map<String, Object?> raw,
  String key,
  _DiagnosticSink sink,
  String code,
  String message,
  int materialIndex,
) {
  if (!raw.containsKey(key)) return;
  final value = raw[key];
  if (value is num && value >= 0 && value <= 1) return;
  sink.error(
    code,
    message,
    jsonPath: _materialPath(materialIndex, '.pbrMetallicRoughness.$key'),
    gltfMaterialIndex: materialIndex,
  );
}

void _validateMaterialMinimum(
  Map<String, Object?> raw,
  String key,
  double minimum,
  _DiagnosticSink sink,
  String code,
  String message,
  int materialIndex,
) {
  if (!raw.containsKey(key)) return;
  final value = raw[key];
  if (value is num && value >= minimum) return;
  sink.error(
    code,
    message,
    jsonPath: _materialPath(materialIndex, '.$key'),
    gltfMaterialIndex: materialIndex,
  );
}

void _validateTextureInfoIndex(
  Map<String, Object?> rawParent,
  String key,
  _DiagnosticSink sink,
  String code,
  String jsonPath,
  int materialIndex,
) {
  if (!rawParent.containsKey(key)) return;
  if (rawParent[key] is! Map) {
    sink.error(
      code,
      'Texture info $key must be a JSON object.',
      jsonPath: jsonPath,
      gltfMaterialIndex: materialIndex,
    );
    return;
  }
  final raw = _object(rawParent[key]);
  if (raw['index'] is int) return;
  sink.error(
    code,
    'Texture info $key must specify an integer index.',
    jsonPath: jsonPath,
    gltfMaterialIndex: materialIndex,
  );
}

void _validateNormalTextureScale(
  VrmTextureInfo? texture,
  Object? rawValue,
  int materialIndex,
  _DiagnosticSink sink,
) {
  final raw = texture?.raw ?? _object(rawValue);
  if (!raw.containsKey('scale')) return;
  if (raw['scale'] is num) return;
  sink.error(
    'gltf.invalidNormalTextureScale',
    'Normal texture scale must be a number.',
    jsonPath: _materialPath(materialIndex, '.normalTexture.scale'),
    gltfMaterialIndex: materialIndex,
  );
}

void _validateTextureInfo(
  VrmTextureInfo? info,
  Object? rawValue,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String code,
  String jsonPath,
  int materialIndex,
) {
  if (info != null) {
    _validateIndex(
      info.index,
      gltf.textures.length,
      sink,
      code,
      jsonPath,
      gltfMaterialIndex: materialIndex,
    );
  }
  final raw = info?.raw ?? _object(rawValue);
  if (raw.isEmpty) return;
  if (raw.containsKey('texCoord')) {
    final texCoord = raw['texCoord'];
    if (texCoord is! int || texCoord < 0) {
      sink.error(
        'gltf.invalidTextureTexCoord',
        'Texture texCoord must be a non-negative integer.',
        jsonPath: '$jsonPath.texCoord',
        gltfMaterialIndex: materialIndex,
      );
    }
  }
  if (raw.containsKey('strength')) {
    final strength = raw['strength'];
    if (strength is! num || strength < 0 || strength > 1) {
      sink.error(
        'gltf.invalidTextureStrength',
        'Texture strength must be a number in the range 0..1.',
        jsonPath: '$jsonPath.strength',
        gltfMaterialIndex: materialIndex,
      );
    }
  }
  final extensions = _object(raw['extensions']);
  final transformValue = extensions['KHR_texture_transform'];
  if (extensions.containsKey('KHR_texture_transform') &&
      transformValue is! Map) {
    sink.error(
      'gltf.invalidTextureTransformObject',
      'KHR_texture_transform must be a JSON object.',
      jsonPath: '$jsonPath.extensions.KHR_texture_transform',
      gltfMaterialIndex: materialIndex,
    );
  }
  final transform = _object(transformValue);
  final transformPath = '$jsonPath.extensions.KHR_texture_transform';
  if (transform.containsKey('offset')) {
    _validateTextureTransformVector2(
      transform['offset'],
      sink,
      'gltf.invalidTextureTransformOffset',
      'KHR_texture_transform offset must contain two numbers.',
      '$transformPath.offset',
      materialIndex,
    );
  }
  if (transform.containsKey('scale')) {
    _validateTextureTransformVector2(
      transform['scale'],
      sink,
      'gltf.invalidTextureTransformScale',
      'KHR_texture_transform scale must contain two numbers.',
      '$transformPath.scale',
      materialIndex,
    );
  }
  if (transform.containsKey('rotation') && transform['rotation'] is! num) {
    sink.error(
      'gltf.invalidTextureTransformRotation',
      'KHR_texture_transform rotation must be a number.',
      jsonPath: '$transformPath.rotation',
      gltfMaterialIndex: materialIndex,
    );
  }
  if (transform.containsKey('texCoord')) {
    final texCoord = transform['texCoord'];
    if (texCoord is! int || texCoord < 0) {
      sink.error(
        'gltf.invalidTextureTransformTexCoord',
        'KHR_texture_transform texCoord must be a non-negative integer.',
        jsonPath: '$transformPath.texCoord',
        gltfMaterialIndex: materialIndex,
      );
    }
  }
}

void _validateTextureTransformVector2(
  Object? value,
  _DiagnosticSink sink,
  String code,
  String message,
  String jsonPath,
  int materialIndex,
) {
  final values = _list(value);
  if (values.length == 2 && values.every((value) => value is num)) return;
  sink.error(
    code,
    message,
    jsonPath: jsonPath,
    gltfMaterialIndex: materialIndex,
  );
}

void _validateMToonMaterials(GltfAsset gltf, _DiagnosticSink sink) {
  for (final material in gltf.materials) {
    final mtoon = material.mtoon;
    if (mtoon == null) continue;
    final mtoonPath = _mtoonPath(material.index, '');
    if (!mtoon.raw.containsKey('specVersion')) {
      sink.error(
        'mtoon.missingSpecVersion',
        'VRMC_materials_mtoon.specVersion is required.',
        jsonPath: '$mtoonPath.specVersion',
        gltfMaterialIndex: material.index,
      );
    } else if (mtoon.specVersion != '1.0') {
      sink.error(
        'mtoon.unsupportedSpecVersion',
        'VRMC_materials_mtoon.specVersion must be "1.0".',
        jsonPath: '$mtoonPath.specVersion',
        gltfMaterialIndex: material.index,
      );
    }
    if (mtoon.raw.containsKey('renderQueueOffsetNumber') &&
        mtoon.raw['renderQueueOffsetNumber'] is! int) {
      sink.error(
        'mtoon.invalidRenderQueueOffsetType',
        'renderQueueOffsetNumber must be an integer.',
        jsonPath: '$mtoonPath.renderQueueOffsetNumber',
        gltfMaterialIndex: material.index,
      );
    }
    if (!_isValidMToonRenderQueueOffset(material, mtoon)) {
      sink.error(
        'mtoon.invalidRenderQueueOffset',
        'renderQueueOffsetNumber must match alphaMode and transparentWithZWrite.',
        jsonPath: '$mtoonPath.renderQueueOffsetNumber',
        gltfMaterialIndex: material.index,
      );
    }
    if (mtoon.raw.containsKey('transparentWithZWrite') &&
        mtoon.raw['transparentWithZWrite'] is! bool) {
      sink.error(
        'mtoon.invalidTransparentWithZWrite',
        'transparentWithZWrite must be a boolean.',
        jsonPath: '$mtoonPath.transparentWithZWrite',
        gltfMaterialIndex: material.index,
      );
    }
    final rawOutlineWidthMode = mtoon.raw['outlineWidthMode'];
    if (mtoon.raw.containsKey('outlineWidthMode') &&
        (rawOutlineWidthMode is! String ||
            VrmMToonOutlineWidthMode.fromSpecName(rawOutlineWidthMode) ==
                null)) {
      sink.error(
        'mtoon.invalidOutlineWidthMode',
        'outlineWidthMode "$rawOutlineWidthMode" is not supported.',
        jsonPath: '$mtoonPath.outlineWidthMode',
        gltfMaterialIndex: material.index,
      );
    }
    _validateMToonFactor(
      mtoon,
      'shadingToonyFactor',
      0,
      1,
      material.index,
      sink,
    );
    _validateMToonFactor(
      mtoon,
      'giEqualizationFactor',
      0,
      1,
      material.index,
      sink,
    );
    _validateMToonFactor(
      mtoon,
      'rimLightingMixFactor',
      0,
      1,
      material.index,
      sink,
    );
    _validateMToonFactor(
      mtoon,
      'parametricRimFresnelPowerFactor',
      0,
      null,
      material.index,
      sink,
    );
    _validateMToonFactor(
      mtoon,
      'outlineWidthFactor',
      0,
      null,
      material.index,
      sink,
    );
    _validateMToonFactor(
      mtoon,
      'outlineLightingMixFactor',
      0,
      1,
      material.index,
      sink,
    );
    for (final key in [
      'shadingShiftFactor',
      'parametricRimLiftFactor',
      'uvAnimationScrollXSpeedFactor',
      'uvAnimationScrollYSpeedFactor',
      'uvAnimationRotationSpeedFactor',
    ]) {
      _validateMToonNumber(mtoon, key, material.index, sink);
    }
    for (final key in [
      'shadeColorFactor',
      'matcapFactor',
      'parametricRimColorFactor',
      'outlineColorFactor',
    ]) {
      _validateMToonColorFactor(mtoon, key, material.index, sink);
    }
    _validateMToonTextureScale(
      mtoon.shadingShiftTexture,
      mtoon.raw['shadingShiftTexture'],
      'shadingShiftTexture',
      material.index,
      sink,
    );
    for (final key in _mtoonTextureKeys) {
      _validateTextureInfoIndex(
        mtoon.raw,
        key,
        sink,
        'mtoon.invalidTexture',
        _mtoonPath(material.index, '.$key'),
        material.index,
      );
    }
    for (final entry in _mtoonTextureEntries(mtoon)) {
      _validateTextureInfo(
        entry.texture,
        mtoon.raw[entry.key],
        gltf,
        sink,
        'mtoon.invalidTexture',
        _mtoonPath(material.index, '.${entry.key}'),
        material.index,
      );
    }
  }
}

const _mtoonTextureKeys = [
  'shadeMultiplyTexture',
  'shadingShiftTexture',
  'matcapTexture',
  'rimMultiplyTexture',
  'outlineWidthMultiplyTexture',
  'uvAnimationMaskTexture',
];

String _mtoonPath(int materialIndex, String suffix) =>
    _materialPath(materialIndex, '.extensions.VRMC_materials_mtoon$suffix');

bool _isValidMToonRenderQueueOffset(
  GltfMaterial material,
  VrmMToonMaterial mtoon,
) {
  final offset = mtoon.renderQueueOffsetNumber;
  return switch (material.alphaMode) {
    GltfAlphaMode.opaque || GltfAlphaMode.mask => offset == 0,
    GltfAlphaMode.blend =>
      mtoon.transparentWithZWrite
          ? offset >= 0 && offset <= 9
          : offset >= -9 && offset <= 0,
  };
}

void _validateMToonNumber(
  VrmMToonMaterial mtoon,
  String key,
  int materialIndex,
  _DiagnosticSink sink,
) {
  if (!mtoon.raw.containsKey(key)) return;
  if (mtoon.raw[key] is num) return;
  sink.error(
    'mtoon.invalidNumber',
    '$key must be a number.',
    jsonPath: _mtoonPath(materialIndex, '.$key'),
    gltfMaterialIndex: materialIndex,
  );
}

void _validateMToonFactor(
  VrmMToonMaterial mtoon,
  String key,
  double min,
  double? max,
  int materialIndex,
  _DiagnosticSink sink,
) {
  if (!mtoon.raw.containsKey(key)) return;
  final value = mtoon.raw[key];
  if (value is num && value >= min && (max == null || value <= max)) return;
  sink.error(
    'mtoon.invalidFactor',
    max == null
        ? '$key must be at least $min.'
        : '$key must be between $min and $max.',
    jsonPath: _mtoonPath(materialIndex, '.$key'),
    gltfMaterialIndex: materialIndex,
  );
}

void _validateMToonColorFactor(
  VrmMToonMaterial mtoon,
  String key,
  int materialIndex,
  _DiagnosticSink sink,
) {
  if (!mtoon.raw.containsKey(key)) return;
  final values = _list(mtoon.raw[key]);
  if (values.length == 3 &&
      values.every((value) => value is num && value >= 0 && value <= 1)) {
    return;
  }
  sink.error(
    'mtoon.invalidColorFactor',
    '$key must contain three numbers in [0, 1].',
    jsonPath: _mtoonPath(materialIndex, '.$key'),
    gltfMaterialIndex: materialIndex,
  );
}

void _validateMToonTextureScale(
  VrmTextureInfo? texture,
  Object? rawValue,
  String key,
  int materialIndex,
  _DiagnosticSink sink,
) {
  final raw = texture?.raw ?? _object(rawValue);
  if (!raw.containsKey('scale')) return;
  if (raw['scale'] is num) return;
  sink.error(
    'mtoon.invalidTextureScale',
    '$key scale must be a number.',
    jsonPath: _mtoonPath(materialIndex, '.$key.scale'),
    gltfMaterialIndex: materialIndex,
  );
}

Iterable<({String key, VrmTextureInfo? texture})> _mtoonTextureEntries(
  VrmMToonMaterial mtoon,
) sync* {
  final textures = [
    (key: 'shadeMultiplyTexture', texture: mtoon.shadeMultiplyTexture),
    (key: 'shadingShiftTexture', texture: mtoon.shadingShiftTexture),
    (key: 'matcapTexture', texture: mtoon.matcapTexture),
    (key: 'rimMultiplyTexture', texture: mtoon.rimMultiplyTexture),
    (
      key: 'outlineWidthMultiplyTexture',
      texture: mtoon.outlineWidthMultiplyTexture,
    ),
    (key: 'uvAnimationMaskTexture', texture: mtoon.uvAnimationMaskTexture),
  ];
  for (final entry in textures) {
    yield entry;
  }
}

Iterable<({String key, VrmTextureInfo texture})> _mtoonUvTextures(
  VrmMToonMaterial mtoon,
) sync* {
  for (final entry in _mtoonTextureEntries(mtoon)) {
    if (entry.key == 'matcapTexture') continue;
    final texture = entry.texture;
    if (texture != null) yield (key: entry.key, texture: texture);
  }
}
