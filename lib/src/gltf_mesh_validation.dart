part of '../flvtterm.dart';

void _validateGltfMeshes(GltfAsset gltf, _DiagnosticSink sink) {
  final rawMeshes = _list(gltf.json['meshes']);
  for (final mesh in gltf.meshes) {
    final meshPath = _meshPath(mesh.index);
    final rawMesh = _object(rawMeshes.elementAtOrNull(mesh.index));
    _validateRequiredArray(
      rawMesh,
      'primitives',
      sink,
      'gltf.missingMeshPrimitives',
      'gltf.invalidMeshPrimitives',
      'Mesh primitives must be a non-empty array.',
      '$meshPath.primitives',
    );
    final rawPrimitives = _list(rawMesh['primitives']);
    final targetCount = mesh.primitives.isEmpty
        ? 0
        : mesh.primitives.first.targets.length;
    if (rawMesh.containsKey('weights') &&
        _hasInvalidNumberList(rawMesh['weights'])) {
      sink.error(
        'gltf.invalidMeshWeights',
        'Mesh weights must be a non-empty array of numbers.',
        jsonPath: '$meshPath.weights',
      );
    } else if (mesh.weights.isNotEmpty && mesh.weights.length != targetCount) {
      sink.error(
        'gltf.invalidMeshWeights',
        'Mesh weights length must match the number of morph targets.',
        jsonPath: '$meshPath.weights',
      );
    }
    _validateMeshTargetNames(rawMesh, targetCount, sink, meshPath);
    for (
      var primitiveIndex = 0;
      primitiveIndex < mesh.primitives.length;
      primitiveIndex++
    ) {
      final primitivePath = _primitivePath(mesh.index, primitiveIndex);
      final primitive = mesh.primitives[primitiveIndex];
      final rawPrimitive = _object(
        rawPrimitives.elementAtOrNull(primitiveIndex),
      );
      if (primitive.targets.length != targetCount) {
        sink.error(
          'gltf.mismatchedPrimitiveTargetCount',
          'All primitives in a mesh must have the same morph target count.',
          jsonPath: '$primitivePath.targets',
        );
      }
      if (rawPrimitive.containsKey('mode') && rawPrimitive['mode'] is! int) {
        sink.error(
          'gltf.invalidPrimitiveMode',
          'Mesh primitive mode must be an integer.',
          jsonPath: '$primitivePath.mode',
        );
      } else if (primitive.mode < 0 || primitive.mode > 6) {
        sink.error(
          'gltf.invalidPrimitiveMode',
          'Mesh primitive mode must be a glTF draw mode enum value.',
          jsonPath: '$primitivePath.mode',
        );
      }
      if (rawPrimitive.containsKey('material') &&
          rawPrimitive['material'] is! int) {
        sink.error(
          'gltf.invalidPrimitiveMaterial',
          'Mesh primitive material must be an integer.',
          jsonPath: '$primitivePath.material',
        );
      } else if (primitive.material != null) {
        _validateIndex(
          primitive.material!,
          gltf.materials.length,
          sink,
          'gltf.invalidPrimitiveMaterial',
          '$primitivePath.material',
        );
        final material = gltf.materials.elementAtOrNull(primitive.material!);
        if (material != null) {
          _validatePrimitiveMaterialTexCoords(
            primitive,
            material,
            sink,
            '$primitivePath.attributes',
          );
        }
      }
      GltfAccessor? indicesAccessor;
      if (rawPrimitive.containsKey('indices') &&
          rawPrimitive['indices'] is! int) {
        sink.error(
          'gltf.invalidPrimitiveIndices',
          'Mesh primitive indices must be an integer.',
          jsonPath: '$primitivePath.indices',
        );
      } else if (primitive.indices != null) {
        _validateIndex(
          primitive.indices!,
          gltf.accessors.length,
          sink,
          'gltf.invalidPrimitiveIndices',
          '$primitivePath.indices',
        );
        indicesAccessor = gltf.accessors.elementAtOrNull(primitive.indices!);
        if (indicesAccessor != null &&
            (indicesAccessor.type != 'SCALAR' ||
                (indicesAccessor.componentType != 5121 &&
                    indicesAccessor.componentType != 5123 &&
                    indicesAccessor.componentType != 5125))) {
          sink.error(
            'gltf.invalidPrimitiveIndicesAccessor',
            'Primitive indices accessor must be SCALAR with an unsigned integer component type.',
            jsonPath: '$primitivePath.indices',
          );
        }
        _validateAccessorBufferViewTarget(
          gltf,
          primitive.indices!,
          _gltfElementArrayBufferTarget,
          sink,
          'gltf.invalidPrimitiveIndicesBufferViewTarget',
          'Primitive indices accessor bufferView target must be ELEMENT_ARRAY_BUFFER when target is defined.',
          '$primitivePath.indices',
        );
      }
      final indexCount = indicesAccessor?.count;
      if (indexCount != null &&
          !_isValidPrimitiveTopologyCount(primitive.mode, indexCount)) {
        sink.error(
          'gltf.invalidPrimitiveIndexCount',
          'Primitive index accessor count does not match the draw mode topology.',
          jsonPath: '$primitivePath.indices',
        );
      }
      if (rawPrimitive.containsKey('attributes')) {
        _validatePrimitiveIndexMapAt(
          rawPrimitive['attributes'],
          sink,
          'gltf.invalidPrimitiveAttribute',
          'Primitive attributes must map semantics to integer accessor indices.',
          '$primitivePath.attributes',
        );
      } else {
        sink.error(
          'gltf.missingPrimitiveAttributes',
          'Mesh primitive attributes are required.',
          jsonPath: '$primitivePath.attributes',
        );
      }
      _validatePrimitiveAttributeSemantics(
        primitive.attributes,
        sink,
        '$primitivePath.attributes',
      );
      int? attributeCount;
      var reportedAttributeCountMismatch = false;
      for (final entry in primitive.attributes.entries) {
        final accessor = entry.value;
        _validateIndex(
          accessor,
          gltf.accessors.length,
          sink,
          'gltf.invalidPrimitiveAttribute',
          '$primitivePath.attributes.${entry.key}',
        );
        _validateAccessorBufferViewTarget(
          gltf,
          accessor,
          _gltfArrayBufferTarget,
          sink,
          'gltf.invalidPrimitiveAttributeBufferViewTarget',
          'Primitive attribute accessor bufferView target must be ARRAY_BUFFER when target is defined.',
          '$primitivePath.attributes.${entry.key}',
        );
        final attributeAccessor = gltf.accessors.elementAtOrNull(accessor);
        if (attributeAccessor != null &&
            !_isValidPrimitiveAttributeAccessor(entry.key, attributeAccessor)) {
          sink.error(
            'gltf.invalidPrimitiveAttributeAccessor',
            'Primitive attribute accessor shape does not match its semantic.',
            jsonPath: '$primitivePath.attributes.${entry.key}',
          );
        }
        if (entry.key == 'TANGENT') {
          _validateTangentHandedness(
            accessor,
            gltf,
            sink,
            '$primitivePath.attributes.${entry.key}',
          );
        }
        if (entry.key == 'COLOR_0') {
          _validateColor0Range(
            accessor,
            gltf,
            sink,
            '$primitivePath.attributes.${entry.key}',
          );
        }
        if (_isIndexedSemantic(entry.key, 'WEIGHTS_')) {
          _validateSkinWeightValues(
            accessor,
            gltf,
            sink,
            '$primitivePath.attributes.${entry.key}',
          );
        }
        final count = attributeAccessor?.count;
        if (count == null) continue;
        attributeCount ??= count;
        if (!reportedAttributeCountMismatch && attributeCount != count) {
          sink.error(
            'gltf.mismatchedPrimitiveAttributeCount',
            'All primitive attribute accessors must have the same count.',
            jsonPath: '$primitivePath.attributes',
          );
          reportedAttributeCountMismatch = true;
        }
      }
      if (primitive.indices != null && attributeCount != null) {
        _validatePrimitiveIndexValues(
          primitive.indices!,
          primitive.mode,
          attributeCount,
          gltf,
          sink,
          '$primitivePath.indices',
        );
      } else if (primitive.indices == null &&
          attributeCount != null &&
          !_isValidPrimitiveTopologyCount(primitive.mode, attributeCount)) {
        sink.error(
          'gltf.invalidPrimitiveVertexCount',
          'Primitive vertex attribute count does not match the draw mode topology.',
          jsonPath: '$primitivePath.attributes',
        );
      }
      final position = primitive.attributes['POSITION'];
      final positionAccessor = position == null
          ? null
          : gltf.accessors.elementAtOrNull(position);
      if (positionAccessor != null &&
          (positionAccessor.minimum == null ||
              positionAccessor.maximum == null)) {
        sink.error(
          'gltf.missingPositionAccessorBounds',
          'POSITION accessors must define min and max bounds.',
          jsonPath: '$primitivePath.attributes.POSITION',
        );
      }
      if (rawPrimitive.containsKey('targets') &&
          (rawPrimitive['targets'] is! List ||
              _list(rawPrimitive['targets']).isEmpty)) {
        sink.error(
          'gltf.invalidPrimitiveTargets',
          'Primitive targets must be a non-empty array when present.',
          jsonPath: '$primitivePath.targets',
        );
      }
      final rawTargets = _list(rawPrimitive['targets']);
      for (
        var targetIndex = 0;
        targetIndex < primitive.targets.length;
        targetIndex++
      ) {
        final target = primitive.targets[targetIndex];
        _validatePrimitiveIndexMapAt(
          rawTargets.elementAtOrNull(targetIndex),
          sink,
          'gltf.invalidPrimitiveTarget',
          'Primitive morph targets must map semantics to integer accessor indices.',
          '$primitivePath.targets[$targetIndex]',
        );
        _validateMorphTargetAttributeSemantics(
          target,
          sink,
          '$primitivePath.targets[$targetIndex]',
        );
        for (final entry in target.entries) {
          final accessor = entry.value;
          _validateIndex(
            accessor,
            gltf.accessors.length,
            sink,
            'gltf.invalidPrimitiveTarget',
            '$primitivePath.targets[$targetIndex].${entry.key}',
          );
          _validateAccessorBufferViewTarget(
            gltf,
            accessor,
            _gltfArrayBufferTarget,
            sink,
            'gltf.invalidPrimitiveTargetBufferViewTarget',
            'Morph target accessor bufferView target must be ARRAY_BUFFER when target is defined.',
            '$primitivePath.targets[$targetIndex].${entry.key}',
          );
          final targetAccessor = gltf.accessors.elementAtOrNull(accessor);
          if (targetAccessor != null &&
              !_isValidMorphTargetAttributeAccessor(
                entry.key,
                targetAccessor,
              )) {
            sink.error(
              'gltf.invalidPrimitiveTargetAccessor',
              'Morph target accessor shape does not match its semantic.',
              jsonPath: '$primitivePath.targets[$targetIndex].${entry.key}',
            );
          }
          if (entry.key == 'POSITION' &&
              targetAccessor != null &&
              (targetAccessor.minimum == null ||
                  targetAccessor.maximum == null)) {
            sink.error(
              'gltf.missingMorphTargetPositionAccessorBounds',
              'Morph target POSITION accessors must define min and max bounds.',
              jsonPath: '$primitivePath.targets[$targetIndex].POSITION',
            );
          }
          final baseAccessorIndex = primitive.attributes[entry.key];
          if (baseAccessorIndex == null) {
            sink.error(
              'gltf.missingPrimitiveMorphTargetBase',
              'Morph target attributes must also exist as primitive base attributes.',
              jsonPath: '$primitivePath.targets[$targetIndex].${entry.key}',
            );
            continue;
          }
          final baseCount = gltf.accessors
              .elementAtOrNull(baseAccessorIndex)
              ?.count;
          final targetCount = gltf.accessors.elementAtOrNull(accessor)?.count;
          if (baseCount != null &&
              targetCount != null &&
              baseCount != targetCount) {
            sink.error(
              'gltf.mismatchedPrimitiveMorphTargetCount',
              'Morph target accessor count must match the base attribute accessor count.',
              jsonPath: '$primitivePath.targets[$targetIndex].${entry.key}',
            );
          }
        }
      }
    }
  }
}

String _meshPath(int meshIndex) => '\$.meshes[$meshIndex]';

String _primitivePath(int meshIndex, int primitiveIndex) =>
    '${_meshPath(meshIndex)}.primitives[$primitiveIndex]';

void _validateMeshTargetNames(
  Map<String, Object?> rawMesh,
  int targetCount,
  _DiagnosticSink sink,
  String meshPath,
) {
  final extras = rawMesh['extras'];
  if (extras is! Map || !extras.containsKey('targetNames')) return;
  final targetNames = extras['targetNames'];
  final invalid =
      targetNames is! List ||
      targetNames.length != targetCount ||
      targetNames.any((name) => name is! String);
  if (!invalid) return;
  sink.warning(
    'gltf.invalidMeshTargetNames',
    'mesh.extras.targetNames should contain one string per morph target.',
    jsonPath: '$meshPath.extras.targetNames',
  );
}

void _validatePrimitiveIndexValues(
  int accessorIndex,
  int mode,
  int attributeCount,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String jsonPath,
) {
  final accessor = gltf.accessors.elementAtOrNull(accessorIndex);
  final values = _readAccessorNumbers(
    gltf,
    accessorIndex,
    applyNormalization: false,
  );
  if (values == null) return;
  if (values.any((value) => value >= attributeCount)) {
    sink.error(
      'gltf.primitiveIndexOutOfRange',
      'Primitive index values must be less than the primitive attribute count.',
      jsonPath: jsonPath,
    );
  }
  final restartValue = _primitiveRestartValue(accessor?.componentType);
  if (restartValue != null && values.any((value) => value == restartValue)) {
    sink.error(
      'gltf.primitiveIndexUsesRestartValue',
      'Primitive index accessors must not contain the component type maximum value.',
      jsonPath: jsonPath,
    );
  }
  if (_hasDegenerateIndexedPrimitive(mode, values)) {
    sink.warning(
      'gltf.degeneratePrimitive',
      'Indexed line and triangle primitives should not reuse a vertex within one topology primitive.',
      jsonPath: jsonPath,
    );
  }
}

bool _hasDegenerateIndexedPrimitive(int mode, List<double> indices) {
  bool same(double a, double b) => a == b;

  switch (mode) {
    case 1:
      for (var i = 0; i + 1 < indices.length; i += 2) {
        if (same(indices[i], indices[i + 1])) return true;
      }
    case 2:
      for (var i = 0; i + 1 < indices.length; i++) {
        if (same(indices[i], indices[i + 1])) return true;
      }
      return indices.length > 2 && same(indices.first, indices.last);
    case 3:
      for (var i = 0; i + 1 < indices.length; i++) {
        if (same(indices[i], indices[i + 1])) return true;
      }
    case 4:
      for (var i = 0; i + 2 < indices.length; i += 3) {
        if (same(indices[i], indices[i + 1]) ||
            same(indices[i], indices[i + 2]) ||
            same(indices[i + 1], indices[i + 2])) {
          return true;
        }
      }
    case 5:
      for (var i = 0; i + 2 < indices.length; i++) {
        if (same(indices[i], indices[i + 1]) ||
            same(indices[i], indices[i + 2]) ||
            same(indices[i + 1], indices[i + 2])) {
          return true;
        }
      }
    case 6:
      for (var i = 1; i + 1 < indices.length; i++) {
        if (same(indices.first, indices[i]) ||
            same(indices.first, indices[i + 1]) ||
            same(indices[i], indices[i + 1])) {
          return true;
        }
      }
  }
  return false;
}

void _validateTangentHandedness(
  int accessorIndex,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String jsonPath,
) {
  final values = _readAccessorNumbers(gltf, accessorIndex, requireFloat: true);
  if (values == null) return;
  for (var i = 3; i < values.length; i += 4) {
    if (values[i] == 1.0 || values[i] == -1.0) continue;
    sink.error(
      'gltf.invalidTangentHandedness',
      'TANGENT accessor W components must be 1.0 or -1.0.',
      jsonPath: jsonPath,
    );
    return;
  }
}

void _validateColor0Range(
  int accessorIndex,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String jsonPath,
) {
  final values = _readAccessorNumbers(gltf, accessorIndex);
  if (values == null) return;
  for (final value in values) {
    if (value >= 0 && value <= 1) continue;
    sink.error(
      'gltf.invalidColorAccessorValue',
      'COLOR_0 accessor values must be in [0, 1].',
      jsonPath: jsonPath,
    );
    return;
  }
}

void _validateSkinWeightValues(
  int accessorIndex,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String jsonPath,
) {
  final accessor = gltf.accessors.elementAtOrNull(accessorIndex);
  if (accessor == null) return;
  final values = _readAccessorNumbers(
    gltf,
    accessorIndex,
    applyNormalization: false,
  );
  if (values == null) return;
  if (values.any((value) => value < 0)) {
    sink.error(
      'gltf.invalidSkinWeightValue',
      'Skin weight values must not be negative.',
      jsonPath: jsonPath,
    );
    return;
  }
  final componentCount = accessor.componentCount;
  if (componentCount == null) return;
  if (accessor.componentType == 5126) {
    _validateFloatSkinWeightSums(values, componentCount, sink, jsonPath);
    return;
  }
  final expected = switch (accessor.componentType) {
    5121 when accessor.normalized => 255,
    5123 when accessor.normalized => 65535,
    _ => null,
  };
  if (expected == null) return;
  for (var i = 0; i < values.length; i += componentCount) {
    var sum = 0.0;
    for (var j = 0; j < componentCount && i + j < values.length; j++) {
      sum += values[i + j];
    }
    if (sum == expected) continue;
    sink.error(
      'gltf.invalidSkinWeightSum',
      'Normalized integer skin weights must sum to their component maximum before normalization.',
      jsonPath: jsonPath,
    );
    return;
  }
}

void _validateFloatSkinWeightSums(
  List<double> values,
  int componentCount,
  _DiagnosticSink sink,
  String jsonPath,
) {
  for (var i = 0; i < values.length; i += componentCount) {
    var sum = 0.0;
    var nonZero = 0;
    for (var j = 0; j < componentCount && i + j < values.length; j++) {
      final value = values[i + j];
      sum += value;
      if (value != 0) nonZero++;
    }
    final tolerance = 2e-7 * math.max(1, nonZero);
    if ((sum - 1).abs() <= tolerance) continue;
    sink.warning(
      'gltf.skinWeightSum',
      'Float skin weights should sum to 1.0 for each vertex.',
      jsonPath: jsonPath,
    );
    return;
  }
}

void _validatePrimitiveMaterialTexCoords(
  GltfMeshPrimitive primitive,
  GltfMaterial material,
  _DiagnosticSink sink,
  String jsonPath,
) {
  final available = _attributeSetIndices(primitive.attributes, 'TEXCOORD_');
  for (final texture in _materialTextures(material)) {
    final texCoord = texture.textureTransform?.texCoord ?? texture.texCoord;
    if (available.contains(texCoord)) continue;
    sink.error(
      'gltf.missingTextureCoordinateAttribute',
      'Primitive material textures must have matching TEXCOORD_n attributes.',
      jsonPath: jsonPath,
      gltfMaterialIndex: material.index,
    );
    return;
  }
}

Iterable<VrmTextureInfo> _materialTextures(GltfMaterial material) sync* {
  for (final texture in [
    material.baseColorTexture,
    material.metallicRoughnessTexture,
    material.normalTexture,
    material.occlusionTexture,
    material.emissiveTexture,
  ]) {
    if (texture != null) yield texture;
  }
  final mtoon = material.mtoon;
  if (mtoon == null) return;
  for (final entry in _mtoonTextures(mtoon)) {
    yield entry.texture;
  }
}

int? _primitiveRestartValue(int? componentType) {
  return switch (componentType) {
    5121 => 255,
    5123 => 65535,
    5125 => 4294967295,
    _ => null,
  };
}

bool _isValidPrimitiveTopologyCount(int mode, int count) {
  return switch (mode) {
    0 => count > 0,
    1 => count % 2 == 0,
    2 || 3 => count >= 2,
    4 => count % 3 == 0,
    5 || 6 => count >= 3,
    _ => true,
  };
}

void _validatePrimitiveAttributeSemantics(
  Map<String, int> attributes,
  _DiagnosticSink sink,
  String jsonPath,
) {
  for (final prefix in const ['TEXCOORD_', 'COLOR_', 'JOINTS_', 'WEIGHTS_']) {
    final indices = <int>{};
    var invalid = false;
    for (final semantic in attributes.keys) {
      if (!semantic.startsWith(prefix)) continue;
      final index = _attributeSetIndex(semantic, prefix);
      if (index == null) {
        invalid = true;
      } else {
        indices.add(index);
      }
    }
    if (invalid || !_isConsecutiveSet(indices)) {
      sink.error(
        'gltf.invalidPrimitiveAttributeSemantic',
        'Indexed primitive attribute semantics must start at 0, be consecutive, and not use leading zeroes.',
        jsonPath: jsonPath,
      );
    }
  }

  final jointSets = _attributeSetIndices(attributes, 'JOINTS_');
  final weightSets = _attributeSetIndices(attributes, 'WEIGHTS_');
  if (jointSets.length != weightSets.length ||
      !jointSets.containsAll(weightSets) ||
      !weightSets.containsAll(jointSets)) {
    sink.error(
      'gltf.mismatchedSkinAttributeSets',
      'A primitive must have matching JOINTS_n and WEIGHTS_n attribute sets.',
      jsonPath: jsonPath,
    );
  }
  if (attributes.keys.any((semantic) {
    return !_isKnownPrimitiveAttributeSemantic(semantic) &&
        !semantic.startsWith('_');
  })) {
    sink.error(
      'gltf.invalidPrimitiveAttributeSemantic',
      'Application-specific primitive attribute semantics must start with "_".',
      jsonPath: jsonPath,
    );
  }
}

void _validateMorphTargetAttributeSemantics(
  Map<String, int> target,
  _DiagnosticSink sink,
  String jsonPath,
) {
  if (target.keys.any((semantic) {
    return !const {'POSITION', 'NORMAL', 'TANGENT'}.contains(semantic) &&
        _attributeSetIndex(semantic, 'TEXCOORD_') == null &&
        _attributeSetIndex(semantic, 'COLOR_') == null &&
        !semantic.startsWith('_');
  })) {
    sink.error(
      'gltf.invalidPrimitiveTargetSemantic',
      'Application-specific morph target semantics must start with "_".',
      jsonPath: jsonPath,
    );
  }
}

bool _isKnownPrimitiveAttributeSemantic(String semantic) {
  return semantic == 'POSITION' ||
      semantic == 'NORMAL' ||
      semantic == 'TANGENT' ||
      semantic.startsWith('TEXCOORD_') ||
      semantic.startsWith('COLOR_') ||
      semantic.startsWith('JOINTS_') ||
      semantic.startsWith('WEIGHTS_');
}

Set<int> _attributeSetIndices(Map<String, int> attributes, String prefix) {
  return {
    for (final semantic in attributes.keys)
      ?_attributeSetIndex(semantic, prefix),
  };
}

int? _attributeSetIndex(String semantic, String prefix) {
  if (!semantic.startsWith(prefix)) return null;
  final suffix = semantic.substring(prefix.length);
  if (suffix.isEmpty || (suffix.length > 1 && suffix.startsWith('0'))) {
    return null;
  }
  return int.tryParse(suffix);
}

bool _isConsecutiveSet(Set<int> values) {
  for (var i = 0; i < values.length; i++) {
    if (!values.contains(i)) return false;
  }
  return true;
}
