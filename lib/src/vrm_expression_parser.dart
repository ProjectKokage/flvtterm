part of '../flvtterm.dart';

VrmExpressions _parseExpressions(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
) {
  if (value is! Map) {
    sink.error(
      'vrm.invalidExpressionsObject',
      'VRMC_vrm.expressions must be a JSON object.',
      jsonPath: r'$.extensions.VRMC_vrm.expressions',
    );
  }
  final raw = _object(value);
  final preset = <VrmExpressionPreset, VrmExpression>{};
  final custom = <String, VrmExpression>{};

  for (final entry in _expressionGroup(raw, 'preset', sink).entries) {
    final expressionPreset = VrmExpressionPreset.fromSpecName(entry.key);
    if (expressionPreset == null) {
      sink.warning(
        'vrm.unknownPresetExpression',
        'Unknown preset expression "${entry.key}" was ignored.',
        jsonPath: '\$.extensions.VRMC_vrm.expressions.preset.${entry.key}',
      );
      continue;
    }
    final expression = _parseExpression(
      entry.key,
      entry.value,
      gltf,
      sink,
      '\$.extensions.VRMC_vrm.expressions.preset.${entry.key}',
    );
    if (expression != null) preset[expressionPreset] = expression;
  }

  for (final entry in _expressionGroup(raw, 'custom', sink).entries) {
    if (VrmExpressionPreset.fromSpecName(entry.key) != null) {
      sink.error(
        'vrm.customExpressionPresetCollision',
        'Custom expression "${entry.key}" collides with a preset expression.',
        jsonPath: '\$.extensions.VRMC_vrm.expressions.custom.${entry.key}',
      );
      continue;
    }
    final expression = _parseExpression(
      entry.key,
      entry.value,
      gltf,
      sink,
      '\$.extensions.VRMC_vrm.expressions.custom.${entry.key}',
    );
    if (expression != null) custom[entry.key] = expression;
  }

  return VrmExpressions._(
    preset: Map.unmodifiable(preset),
    custom: Map.unmodifiable(custom),
    raw: raw,
  );
}

Map<String, Object?> _expressionGroup(
  Map<String, Object?> raw,
  String field,
  _DiagnosticSink sink,
) {
  if (!raw.containsKey(field)) return const {};
  final value = raw[field];
  if (value is Map) return value.cast<String, Object?>();
  sink.error(
    'vrm.invalidExpressionGroup',
    'VRMC_vrm.expressions.$field must be a JSON object.',
    jsonPath: '\$.extensions.VRMC_vrm.expressions.$field',
  );
  return const {};
}

VrmExpression? _parseExpression(
  String name,
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path,
) {
  if (value is! Map) {
    sink.error(
      'vrm.invalidExpressionObject',
      'Expression "$name" must be a JSON object.',
      jsonPath: path,
    );
    return null;
  }
  final raw = _object(value);
  if (raw.containsKey('isBinary') && _bool(raw['isBinary']) == null) {
    sink.error(
      'vrm.invalidExpressionIsBinary',
      'Expression isBinary must be a boolean.',
      jsonPath: '$path.isBinary',
    );
  }
  for (final field in const [
    'overrideMouth',
    'overrideBlink',
    'overrideLookAt',
  ]) {
    final overrideMode = _string(raw[field]);
    if (raw.containsKey(field) && raw[field] is! String) {
      sink.error(
        'vrm.invalidExpressionOverrideMode',
        'Expression $field must be none, block, or blend.',
        jsonPath: '$path.$field',
      );
    } else if (overrideMode != null &&
        !VrmExpressionOverrideMode.values.any(
          (mode) => mode.specName == overrideMode,
        )) {
      sink.error(
        'vrm.invalidExpressionOverrideMode',
        'Expression $field must be none, block, or blend.',
        jsonPath: '$path.$field',
      );
    }
  }
  final preset = VrmExpressionPreset.fromSpecName(name);
  final disallowMouthOverride =
      preset != null && _lipSyncPresetNames.contains(name);
  final disallowBlinkOverride = switch (preset) {
    VrmExpressionPreset.blink ||
    VrmExpressionPreset.blinkLeft ||
    VrmExpressionPreset.blinkRight => true,
    _ => false,
  };
  final disallowLookAtOverride = switch (preset) {
    VrmExpressionPreset.lookUp ||
    VrmExpressionPreset.lookDown ||
    VrmExpressionPreset.lookLeft ||
    VrmExpressionPreset.lookRight => true,
    _ => false,
  };
  final morphTargetBindItems = _expressionBindList(
    raw,
    'morphTargetBinds',
    sink,
    path,
  );
  final materialColorBindItems = _expressionBindList(
    raw,
    'materialColorBinds',
    sink,
    path,
  );
  final textureTransformBindItems = _expressionBindList(
    raw,
    'textureTransformBinds',
    sink,
    path,
  );

  return VrmExpression._(
    name: name,
    isBinary: _bool(raw['isBinary']) ?? false,
    morphTargetBinds: [
      for (var i = 0; i < morphTargetBindItems.length; i++)
        ?_parseMorphTargetBind(
          morphTargetBindItems[i],
          gltf,
          sink,
          '$path.morphTargetBinds[$i]',
        ),
    ],
    materialColorBinds: [
      for (var i = 0; i < materialColorBindItems.length; i++)
        ?_parseMaterialColorBind(
          materialColorBindItems[i],
          gltf,
          sink,
          '$path.materialColorBinds[$i]',
        ),
    ],
    textureTransformBinds: [
      for (var i = 0; i < textureTransformBindItems.length; i++)
        ?_parseTextureTransformBind(
          textureTransformBindItems[i],
          gltf,
          sink,
          '$path.textureTransformBinds[$i]',
        ),
    ],
    overrideMouth: _parseExpressionOverrideMode(
      raw,
      'overrideMouth',
      sink,
      path,
      disallowSameKind: disallowMouthOverride,
    ),
    overrideBlink: _parseExpressionOverrideMode(
      raw,
      'overrideBlink',
      sink,
      path,
      disallowSameKind: disallowBlinkOverride,
    ),
    overrideLookAt: _parseExpressionOverrideMode(
      raw,
      'overrideLookAt',
      sink,
      path,
      disallowSameKind: disallowLookAtOverride,
    ),
    raw: raw,
  );
}

VrmExpressionOverrideMode _parseExpressionOverrideMode(
  Map<String, Object?> raw,
  String field,
  _DiagnosticSink sink,
  String path, {
  required bool disallowSameKind,
}) {
  final mode = VrmExpressionOverrideMode.fromSpecName(_string(raw[field]));
  if (disallowSameKind && mode != VrmExpressionOverrideMode.none) {
    sink.error(
      'vrm.invalidExpressionOverrideKind',
      'Procedural preset expressions cannot override expressions of the same kind.',
      jsonPath: '$path.$field',
    );
    return VrmExpressionOverrideMode.none;
  }
  return mode;
}

List<Object?> _expressionBindList(
  Map<String, Object?> raw,
  String field,
  _DiagnosticSink sink,
  String path,
) {
  if (!raw.containsKey(field)) return const [];
  final value = raw[field];
  if (value is List && value.isNotEmpty) return value.cast<Object?>();
  sink.error(
    'vrm.invalidExpressionBindList',
    'Expression $field must be a non-empty array when present.',
    jsonPath: '$path.$field',
  );
  return const [];
}

VrmMorphTargetBind? _parseMorphTargetBind(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path,
) {
  if (value is! Map) {
    sink.error(
      'vrm.invalidMorphTargetBindObject',
      'Morph target bind must be a JSON object.',
      jsonPath: path,
    );
  }
  final raw = _object(value);
  final nodeValue = raw['node'];
  final indexValue = raw['index'];
  final node = _int(nodeValue);
  final index = _int(indexValue);
  final weight = _double(raw['weight']);
  if (!raw.containsKey('node') ||
      !raw.containsKey('index') ||
      !raw.containsKey('weight')) {
    sink.error(
      'vrm.invalidMorphTargetBind',
      'Morph target bind requires node, index, and weight.',
      jsonPath: path,
    );
    return null;
  }
  if (node == null || index == null) {
    sink.error(
      'vrm.invalidMorphTargetBind',
      'Morph target bind node and index must be integers.',
      jsonPath: path,
    );
    return null;
  }
  if (weight == null) {
    sink.error(
      'vrm.invalidMorphTargetWeight',
      'Morph target bind weight must be a number.',
      jsonPath: '$path.weight',
    );
    return null;
  }
  _validateIndex(
    node,
    gltf.nodes.length,
    sink,
    'vrm.invalidMorphTargetNode',
    '$path.node',
  );
  if (weight < 0 || weight > 1) {
    sink.error(
      'vrm.invalidMorphTargetWeight',
      'Morph target bind weight must be in [0, 1].',
      jsonPath: '$path.weight',
    );
  }
  var valid = node >= 0 && node < gltf.nodes.length;
  final gltfNode = gltf.nodes.elementAtOrNull(node);
  final meshIndex = gltfNode?.mesh;
  final mesh = meshIndex == null
      ? null
      : gltf.meshes.elementAtOrNull(meshIndex);
  if (gltfNode != null && meshIndex == null) {
    valid = false;
    sink.error(
      'vrm.invalidMorphTargetMesh',
      'Morph target bind node must reference a mesh.',
      jsonPath: '$path.node',
      gltfNodeIndex: node,
    );
  } else if (mesh != null &&
      (index < 0 || mesh.primitives.any((p) => index >= p.targets.length))) {
    valid = false;
    sink.error(
      'vrm.invalidMorphTargetIndex',
      'Morph target bind index is outside the mesh target range.',
      jsonPath: '$path.index',
      gltfNodeIndex: node,
    );
  }
  if (!valid) return null;
  return VrmMorphTargetBind(
    node: node,
    index: index,
    weight: _clamp01(weight),
    raw: raw,
  );
}

VrmMaterialColorBind? _parseMaterialColorBind(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path,
) {
  if (value is! Map) {
    sink.error(
      'vrm.invalidMaterialColorBindObject',
      'Material color bind must be a JSON object.',
      jsonPath: path,
    );
  }
  final raw = _object(value);
  final materialValue = raw['material'];
  final material = _int(materialValue);
  final type = _string(raw['type']);
  if (!raw.containsKey('material') ||
      type == null ||
      !raw.containsKey('targetValue')) {
    sink.error(
      'vrm.invalidMaterialColorBind',
      'Material color bind requires material, type, and targetValue.',
      jsonPath: path,
    );
    return null;
  }
  if (material == null) {
    sink.error(
      'vrm.invalidMaterialColorMaterial',
      'Material color bind material must be an integer.',
      jsonPath: '$path.material',
    );
    return null;
  }
  var valid = material >= 0 && material < gltf.materials.length;
  if (!_materialColorBindTypes.contains(type)) {
    valid = false;
    sink.error(
      'vrm.invalidMaterialColorType',
      'Material color bind type is not a VRM 1.0 material color bind type.',
      jsonPath: '$path.type',
    );
  }
  if (_doubleList(raw['targetValue'], 4, const []).length != 4) {
    valid = false;
    sink.error(
      'vrm.invalidMaterialColorTargetValue',
      'Material color bind targetValue must contain four numbers.',
      jsonPath: '$path.targetValue',
    );
  }
  _validateIndex(
    material,
    gltf.materials.length,
    sink,
    'vrm.invalidMaterialColorMaterial',
    '$path.material',
  );
  if (!valid) return null;
  return VrmMaterialColorBind(
    material: material,
    type: type,
    targetValue: _vector4(raw['targetValue'], VrmVector4.zero),
    raw: raw,
  );
}

const _materialColorBindTypes = {
  'color',
  'emissionColor',
  'shadeColor',
  'matcapColor',
  'rimColor',
  'outlineColor',
};

VrmTextureTransformBind? _parseTextureTransformBind(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path,
) {
  if (value is! Map) {
    sink.error(
      'vrm.invalidTextureTransformBindObject',
      'Texture transform bind must be a JSON object.',
      jsonPath: path,
    );
  }
  final raw = _object(value);
  final materialValue = raw['material'];
  final material = _int(materialValue);
  if (!raw.containsKey('material')) {
    sink.error(
      'vrm.invalidTextureTransformBind',
      'Texture transform bind requires material.',
      jsonPath: path,
    );
    return null;
  }
  if (material == null) {
    sink.error(
      'vrm.invalidTextureTransformMaterial',
      'Texture transform bind material must be an integer.',
      jsonPath: '$path.material',
    );
    return null;
  }
  _validateIndex(
    material,
    gltf.materials.length,
    sink,
    'vrm.invalidTextureTransformMaterial',
    '$path.material',
  );
  var valid = material >= 0 && material < gltf.materials.length;
  if (raw.containsKey('scale') &&
      _doubleList(raw['scale'], 2, const []).length != 2) {
    valid = false;
    sink.error(
      'vrm.invalidTextureTransformScale',
      'Texture transform bind scale must contain two numbers.',
      jsonPath: '$path.scale',
    );
  }
  if (raw.containsKey('offset') &&
      _doubleList(raw['offset'], 2, const []).length != 2) {
    valid = false;
    sink.error(
      'vrm.invalidTextureTransformOffset',
      'Texture transform bind offset must contain two numbers.',
      jsonPath: '$path.offset',
    );
  }
  if (!valid) return null;
  return VrmTextureTransformBind(
    material: material,
    scale: _vector2(raw['scale'], VrmVector2.one),
    offset: _vector2(raw['offset'], VrmVector2.zero),
    raw: raw,
  );
}
