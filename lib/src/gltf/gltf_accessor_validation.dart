part of '../../flvtterm.dart';

void _validateAccessorBounds(
  GltfAccessor accessor,
  Map<String, Object?> raw,
  _DiagnosticSink sink,
) {
  final invalidMin =
      raw.containsKey('min') && _hasInvalidNumberList(raw['min']);
  final invalidMax =
      raw.containsKey('max') && _hasInvalidNumberList(raw['max']);
  if (invalidMin) {
    sink.error(
      'gltf.invalidAccessorMin',
      'Accessor min must be a non-empty array of numbers.',
      jsonPath: _accessorPath(accessor.index, '.min'),
    );
  }
  if (invalidMax) {
    sink.error(
      'gltf.invalidAccessorMax',
      'Accessor max must be a non-empty array of numbers.',
      jsonPath: _accessorPath(accessor.index, '.max'),
    );
  }
  final componentCount = accessor.componentCount;
  if (componentCount == null || invalidMin || invalidMax) return;
  if (accessor.minimum != null && accessor.minimum!.length != componentCount) {
    sink.error(
      'gltf.invalidAccessorMin',
      'Accessor min must contain one value per accessor component.',
      jsonPath: _accessorPath(accessor.index, '.min'),
    );
  }
  if (accessor.maximum != null && accessor.maximum!.length != componentCount) {
    sink.error(
      'gltf.invalidAccessorMax',
      'Accessor max must contain one value per accessor component.',
      jsonPath: _accessorPath(accessor.index, '.max'),
    );
  }
  if (accessor.minimum == null ||
      accessor.maximum == null ||
      accessor.minimum!.length != componentCount ||
      accessor.maximum!.length != componentCount) {
    return;
  }
  for (var i = 0; i < componentCount; i++) {
    if (accessor.minimum![i] <= accessor.maximum![i]) continue;
    sink.error(
      'gltf.invalidAccessorBounds',
      'Accessor min values must be less than or equal to max values.',
      jsonPath: _accessorPath(accessor.index, '.min'),
    );
    return;
  }
}

void _validateAccessorBoundsMatchData(
  GltfAccessor accessor,
  GltfAsset gltf,
  _DiagnosticSink sink,
) {
  final minimum = accessor.minimum;
  final maximum = accessor.maximum;
  final componentCount = accessor.componentCount;
  if (minimum == null ||
      maximum == null ||
      componentCount == null ||
      minimum.length != componentCount ||
      maximum.length != componentCount ||
      (accessor.bufferView == null && accessor.sparse == null)) {
    return;
  }
  final values = _readAccessorNumbers(
    gltf,
    accessor.index,
    applyNormalization: false,
  );
  if (values == null ||
      values.isEmpty ||
      values.any((value) => !value.isFinite)) {
    return;
  }

  final actualMin = List<double>.filled(componentCount, double.infinity);
  final actualMax = List<double>.filled(
    componentCount,
    double.negativeInfinity,
  );
  for (var i = 0; i < values.length; i++) {
    final component = i % componentCount;
    final value = values[i];
    if (value < actualMin[component]) actualMin[component] = value;
    if (value > actualMax[component]) actualMax[component] = value;
  }
  for (var i = 0; i < componentCount; i++) {
    if (_accessorBoundMatches(minimum[i], actualMin[i])) continue;
    sink.error(
      'gltf.accessorBoundsMismatch',
      'Accessor min and max must match the binary accessor data.',
      jsonPath: _accessorPath(accessor.index, '.min'),
    );
    return;
  }
  for (var i = 0; i < componentCount; i++) {
    if (_accessorBoundMatches(maximum[i], actualMax[i])) continue;
    sink.error(
      'gltf.accessorBoundsMismatch',
      'Accessor min and max must match the binary accessor data.',
      jsonPath: _accessorPath(accessor.index, '.max'),
    );
    return;
  }
}

bool _accessorBoundMatches(double declared, double actual) =>
    (declared - actual).abs() <= 1e-5;

void _validateAccessorRange(
  GltfAccessor accessor,
  GltfAsset gltf,
  _DiagnosticSink sink, {
  required bool isVertexAttribute,
}) {
  final viewIndex = accessor.bufferView;
  if (viewIndex == null ||
      viewIndex < 0 ||
      viewIndex >= gltf.bufferViews.length) {
    return;
  }
  final componentSize = _componentByteSize(accessor.componentType);
  if (componentSize == null) {
    return;
  }
  final componentCount = accessor.componentCount;
  if (componentCount == null) {
    return;
  }
  final count = accessor.count;
  if (count == null || count <= 0) return;
  final view = gltf.bufferViews[viewIndex];
  final viewLength = view.byteLength;
  if (viewLength == null || viewLength < 0) return;
  final minimumStride = _accessorTightStride(
    accessor.type,
    componentSize,
    componentCount,
  );
  final elementByteLength = _accessorLastElementByteLength(
    accessor.type,
    componentSize,
    componentCount,
  );
  final stride = view.byteStride ?? minimumStride;
  if (accessor.byteOffset >= 0 &&
      view.byteOffset >= 0 &&
      (accessor.byteOffset % componentSize != 0 ||
          (accessor.byteOffset + view.byteOffset) % componentSize != 0)) {
    sink.error(
      'gltf.invalidAccessorAlignment',
      'Accessor byte offsets must align to the accessor component size.',
      jsonPath: _accessorPath(accessor.index, '.byteOffset'),
    );
  }
  if (componentSize < 4 &&
      accessor.byteOffset >= 0 &&
      view.byteOffset >= 0 &&
      _accessorMatrixColumnCount(accessor.type) != null &&
      (accessor.byteOffset + view.byteOffset) % 4 != 0) {
    sink.error(
      'gltf.invalidAccessorAlignment',
      'Matrix accessor columns must start on 4-byte boundaries.',
      jsonPath: _accessorPath(accessor.index, '.byteOffset'),
    );
  }
  if (isVertexAttribute && (accessor.byteOffset % 4 != 0 || stride % 4 != 0)) {
    sink.error(
      'gltf.invalidAccessorAlignment',
      'Vertex attribute accessors must be aligned to 4-byte boundaries.',
      jsonPath: _accessorPath(accessor.index, '.byteOffset'),
    );
  }
  if (stride < minimumStride ||
      stride % componentSize != 0 ||
      (view.byteStride != null &&
          (stride < 4 || stride > 252 || stride % 4 != 0))) {
    sink.error(
      'gltf.invalidBufferViewStride',
      'bufferView.byteStride must fit accessor elements and follow glTF stride limits.',
      jsonPath: '\$.bufferViews[$viewIndex].byteStride',
    );
    return;
  }
  final usedBytes =
      accessor.byteOffset + stride * (count - 1) + elementByteLength;
  if (usedBytes > viewLength) {
    sink.error(
      'gltf.accessorOutOfRange',
      'Accessor range exceeds its bufferView byteLength.',
      jsonPath: _accessorPath(accessor.index, '.bufferView'),
    );
  }
}

void _validateAccessorSparse(
  GltfAccessor accessor,
  GltfAsset gltf,
  _DiagnosticSink sink,
) {
  final sparse = accessor.sparse;
  if (sparse == null) return;
  final count = sparse.count;
  if (count == null ||
      count < 1 ||
      accessor.count == null ||
      count > accessor.count!) {
    sink.error(
      'gltf.invalidSparseAccessor',
      'Sparse accessor count must be between one and accessor.count.',
      jsonPath: _accessorSparsePath(accessor.index, ''),
    );
    return;
  }
  if (sparse.indicesComponentType != 5121 &&
      sparse.indicesComponentType != 5123 &&
      sparse.indicesComponentType != 5125) {
    sink.error(
      'gltf.invalidSparseAccessor',
      'Sparse accessor indices must use unsigned byte, unsigned short, or unsigned int components.',
      jsonPath: _accessorSparsePath(accessor.index, '.indices.componentType'),
    );
  }
  _validateSparseBufferRange(
    gltf,
    sparse.indicesBufferView,
    sparse.indicesByteOffset,
    count,
    1,
    _componentByteSize(sparse.indicesComponentType),
    sink,
    _accessorSparsePath(accessor.index, '.indices'),
  );
  _validateSparseBufferRange(
    gltf,
    sparse.valuesBufferView,
    sparse.valuesByteOffset,
    count,
    accessor.componentCount,
    _componentByteSize(accessor.componentType),
    sink,
    _accessorSparsePath(accessor.index, '.values'),
    accessorType: accessor.type,
  );
  final indices = _readSparseIndices(gltf, sparse, count);
  if (indices != null &&
      (indices.any((index) => index >= accessor.count!) ||
          !_isStrictlyIncreasing(indices))) {
    sink.error(
      'gltf.invalidSparseAccessorIndices',
      'Sparse accessor indices must be strictly increasing and less than accessor.count.',
      jsonPath: _accessorSparsePath(accessor.index, '.indices'),
    );
  }
}

void _validateAccessorFiniteFloatValues(
  GltfAccessor accessor,
  GltfAsset gltf,
  _DiagnosticSink sink,
) {
  if (accessor.componentType != 5126) return;
  final values = _readAccessorNumbers(
    gltf,
    accessor.index,
    requireFloat: true,
    applyNormalization: false,
  );
  if (values == null || values.every((value) => value.isFinite)) return;
  sink.error(
    'gltf.invalidAccessorFloatValue',
    'FLOAT accessor values must not contain NaN or infinity.',
    jsonPath: _accessorPath(accessor.index, ''),
  );
}

void _validateRawAccessorSparse(
  int accessorIndex,
  Map<String, Object?> raw,
  _DiagnosticSink sink,
) {
  if (!raw.containsKey('sparse')) return;
  final sparseValue = raw['sparse'];
  if (sparseValue is! Map) {
    sink.error(
      'gltf.invalidSparseAccessorType',
      'Sparse accessor fields must use glTF JSON object and integer shapes.',
      jsonPath: _accessorSparsePath(accessorIndex, ''),
    );
    return;
  }
  final sparse = sparseValue.cast<String, Object?>();
  for (final key in const ['count', 'indices', 'values']) {
    if (sparse.containsKey(key)) continue;
    sink.error(
      'gltf.missingSparseAccessorField',
      'Sparse accessor count, indices, and values are required.',
      jsonPath: _accessorSparsePath(accessorIndex, '.$key'),
    );
  }
  _validateSparseInt(
    sparse,
    'count',
    sink,
    _accessorSparsePath(accessorIndex, '.count'),
  );
  final indicesValue = sparse['indices'];
  if (sparse.containsKey('indices') && indicesValue is! Map) {
    sink.error(
      'gltf.invalidSparseAccessorType',
      'Sparse accessor fields must use glTF JSON object and integer shapes.',
      jsonPath: _accessorSparsePath(accessorIndex, '.indices'),
    );
  } else {
    final indices = _object(indicesValue);
    _validateSparseInt(
      indices,
      'bufferView',
      sink,
      _accessorSparsePath(accessorIndex, '.indices.bufferView'),
    );
    _validateSparseInt(
      indices,
      'byteOffset',
      sink,
      _accessorSparsePath(accessorIndex, '.indices.byteOffset'),
    );
    _validateSparseInt(
      indices,
      'componentType',
      sink,
      _accessorSparsePath(accessorIndex, '.indices.componentType'),
    );
  }
  final valuesValue = sparse['values'];
  if (sparse.containsKey('values') && valuesValue is! Map) {
    sink.error(
      'gltf.invalidSparseAccessorType',
      'Sparse accessor fields must use glTF JSON object and integer shapes.',
      jsonPath: _accessorSparsePath(accessorIndex, '.values'),
    );
  } else {
    final values = _object(valuesValue);
    _validateSparseInt(
      values,
      'bufferView',
      sink,
      _accessorSparsePath(accessorIndex, '.values.bufferView'),
    );
    _validateSparseInt(
      values,
      'byteOffset',
      sink,
      _accessorSparsePath(accessorIndex, '.values.byteOffset'),
    );
  }
}

void _validateSparseInt(
  Map<String, Object?> raw,
  String key,
  _DiagnosticSink sink,
  String jsonPath,
) {
  if (!raw.containsKey(key) || raw[key] is int) return;
  sink.error(
    'gltf.invalidSparseAccessorType',
    'Sparse accessor fields must use glTF JSON object and integer shapes.',
    jsonPath: jsonPath,
  );
}

void _validateSparseBufferRange(
  GltfAsset gltf,
  int? viewIndex,
  int byteOffset,
  int count,
  int? componentCount,
  int? componentSize,
  _DiagnosticSink sink,
  String jsonPath, {
  String? accessorType,
}) {
  if (viewIndex == null ||
      viewIndex < 0 ||
      viewIndex >= gltf.bufferViews.length ||
      byteOffset < 0 ||
      componentCount == null ||
      componentSize == null) {
    sink.error(
      'gltf.invalidSparseAccessor',
      'Sparse accessor indices and values must reference valid buffer ranges.',
      jsonPath: jsonPath,
    );
    return;
  }
  final view = gltf.bufferViews[viewIndex];
  final byteLength = view.byteLength;
  if (byteLength == null) return;
  if (view.target != null || view.byteStride != null) {
    sink.error(
      'gltf.invalidSparseAccessorBufferView',
      'Sparse accessor bufferViews must not define target or byteStride.',
      jsonPath: jsonPath,
    );
  }
  if (byteOffset % componentSize != 0) {
    sink.error(
      'gltf.invalidSparseAccessorAlignment',
      'Sparse accessor byteOffset must align to its component size.',
      jsonPath: jsonPath,
    );
  }
  if (_accessorMatrixColumnCount(accessorType) != null &&
      componentSize < 4 &&
      (byteOffset + view.byteOffset) % 4 != 0) {
    sink.error(
      'gltf.invalidSparseAccessorAlignment',
      'Sparse matrix accessor columns must start on 4-byte boundaries.',
      jsonPath: jsonPath,
    );
  }
  final stride = _accessorTightStride(
    accessorType,
    componentSize,
    componentCount,
  );
  final elementByteLength = _accessorLastElementByteLength(
    accessorType,
    componentSize,
    componentCount,
  );
  if (byteOffset + stride * (count - 1) + elementByteLength > byteLength) {
    sink.error(
      'gltf.sparseAccessorOutOfRange',
      'Sparse accessor range exceeds its bufferView byteLength.',
      jsonPath: jsonPath,
    );
  }
}

String _accessorSparsePath(int accessorIndex, String suffix) =>
    _accessorPath(accessorIndex, '.sparse$suffix');

String _accessorPath(int accessorIndex, String suffix) =>
    '\$.accessors[$accessorIndex]$suffix';

void _validateSkinnedNode(GltfNode node, GltfAsset gltf, _DiagnosticSink sink) {
  _validateSkinJointsInNodeScenes(node, gltf, sink);
  final meshIndex = node.mesh;
  if (meshIndex == null) {
    sink.error(
      'gltf.skinnedNodeMissingMesh',
      'A node with skin must also reference a mesh.',
      jsonPath: _nodePath(node.index, '.mesh'),
      gltfNodeIndex: node.index,
    );
    return;
  }
  final mesh = gltf.meshes.elementAtOrNull(meshIndex);
  if (mesh == null) return;
  final skinIndex = node.skin;
  final skin = skinIndex == null ? null : gltf.skins.elementAtOrNull(skinIndex);
  for (
    var primitiveIndex = 0;
    primitiveIndex < mesh.primitives.length;
    primitiveIndex++
  ) {
    final primitive = mesh.primitives[primitiveIndex];
    final primitivePath = _primitivePath(mesh.index, primitiveIndex);
    if (!primitive.attributes.containsKey('JOINTS_0') ||
        !primitive.attributes.containsKey('WEIGHTS_0')) {
      sink.error(
        'gltf.skinnedPrimitiveMissingAttributes',
        'Skinned mesh primitives must contain JOINTS_0 and WEIGHTS_0 attributes.',
        jsonPath: '$primitivePath.attributes',
        gltfNodeIndex: node.index,
      );
    }
    if (skin != null) {
      _validateSkinJointAttributeValues(
        node,
        skin,
        primitive,
        gltf,
        sink,
        primitivePath,
      );
    }
  }
}

void _validateSkinJointAttributeValues(
  GltfNode node,
  GltfSkin skin,
  GltfMeshPrimitive primitive,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String primitivePath,
) {
  final weightedJointsByVertex = <int, Set<int>>{};
  for (final entry in primitive.attributes.entries) {
    if (!_isIndexedSemantic(entry.key, 'JOINTS_')) continue;
    final joints = _readAccessorNumbers(
      gltf,
      entry.value,
      applyNormalization: false,
    );
    if (joints == null) continue;
    if (joints.any((value) => value < 0 || value >= skin.joints.length)) {
      sink.error(
        'gltf.skinJointValueOutOfRange',
        'Skin joint attribute values must be within the skin.joints range.',
        jsonPath: '$primitivePath.attributes.${entry.key}',
        gltfNodeIndex: node.index,
      );
      return;
    }
    final setName = entry.key.substring(7);
    final weightAccessor = primitive.attributes['WEIGHTS_$setName'];
    if (weightAccessor != null) {
      final weights = _readAccessorNumbers(
        gltf,
        weightAccessor,
        applyNormalization: false,
      );
      if (weights == null) continue;
      _validateDuplicateWeightedSkinJoints(
        gltf,
        entry.value,
        joints,
        weightAccessor,
        weights,
        weightedJointsByVertex,
        sink,
        '$primitivePath.attributes.${entry.key}',
      );
      _validateZeroWeightJointValues(
        joints,
        weights,
        sink,
        '$primitivePath.attributes.${entry.key}',
      );
    }
  }
}

void _validateDuplicateWeightedSkinJoints(
  GltfAsset gltf,
  int jointAccessor,
  List<double> joints,
  int weightAccessor,
  List<double> weights,
  Map<int, Set<int>> weightedJointsByVertex,
  _DiagnosticSink sink,
  String jsonPath,
) {
  final jointComponents = gltf.accessors
      .elementAtOrNull(jointAccessor)
      ?.componentCount;
  final weightComponents = gltf.accessors
      .elementAtOrNull(weightAccessor)
      ?.componentCount;
  if (jointComponents == null || weightComponents == null) return;
  final vertexCount = math.min(
    joints.length ~/ jointComponents,
    weights.length ~/ weightComponents,
  );
  for (var vertex = 0; vertex < vertexCount; vertex++) {
    final seen = weightedJointsByVertex.putIfAbsent(vertex, () => <int>{});
    final components = math.min(jointComponents, weightComponents);
    for (var component = 0; component < components; component++) {
      if (weights[vertex * weightComponents + component] <= 0) continue;
      final joint = joints[vertex * jointComponents + component].round();
      if (seen.add(joint)) continue;
      sink.error(
        'gltf.duplicateSkinJointWeight',
        'Skin joints must not contain duplicate non-zero weights for one vertex.',
        jsonPath: jsonPath,
      );
      return;
    }
  }
}

void _validateZeroWeightJointValues(
  List<double> joints,
  List<double> weights,
  _DiagnosticSink sink,
  String jsonPath,
) {
  final length = math.min(joints.length, weights.length);
  for (var i = 0; i < length; i++) {
    if (weights[i] != 0 || joints[i] == 0) continue;
    sink.warning(
      'gltf.nonzeroUnusedSkinJoint',
      'Skin joint values with zero weight should be zero.',
      jsonPath: jsonPath,
    );
    return;
  }
}

void _validateSkinJointsInNodeScenes(
  GltfNode node,
  GltfAsset gltf,
  _DiagnosticSink sink,
) {
  final skinIndex = node.skin;
  if (skinIndex == null || skinIndex < 0 || skinIndex >= gltf.skins.length) {
    return;
  }
  final skin = gltf.skins[skinIndex];
  for (final scene in gltf.scenes) {
    final sceneNodes = _sceneNodeSet(gltf, scene.nodes);
    if (!sceneNodes.contains(node.index)) continue;
    for (final joint in skin.joints) {
      if (joint < 0 || joint >= gltf.nodes.length) continue;
      if (sceneNodes.contains(joint)) continue;
      sink.error(
        'gltf.skinJointNotInScene',
        'Skin joints must belong to the same scene as the skinned node.',
        jsonPath: '\$.nodes[${node.index}].skin',
        gltfNodeIndex: node.index,
      );
      return;
    }
  }
}

Set<int> _sceneNodeSet(GltfAsset gltf, List<int> roots) {
  final seen = <int>{};
  final stack = [
    for (final root in roots)
      if (root >= 0 && root < gltf.nodes.length) root,
  ];
  while (stack.isNotEmpty) {
    final node = stack.removeLast();
    if (!seen.add(node)) continue;
    for (final child in gltf.nodes[node].children) {
      if (child >= 0 && child < gltf.nodes.length) stack.add(child);
    }
  }
  return seen;
}

void _validatePrimitiveIndexMapAt(
  Object? value,
  _DiagnosticSink sink,
  String code,
  String message,
  String jsonPath,
) {
  if (value is! Map) {
    sink.error(code, message, jsonPath: jsonPath);
    return;
  }
  for (final entry in value.values) {
    if (entry is int) continue;
    sink.error(code, message, jsonPath: jsonPath);
    return;
  }
}

bool _hasInvalidNumberList(Object? value) =>
    value is! List || value.isEmpty || value.any((item) => item is! num);

bool _hasInvalidNumberListLength(Object? value, int length) {
  final list = _list(value);
  return list.length != length || list.any((item) => item is! num);
}

bool _hasInvalidIntList(Object? value) =>
    value is! List || value.any((item) => item is! int);

bool _hasInvalidSamplerField(
  Map<String, Object?> raw,
  String key,
  Set<int> allowed,
) {
  if (!raw.containsKey(key)) return false;
  final value = raw[key];
  return value is! int || !allowed.contains(value);
}

void _validateSkinInverseBindMatrices(
  GltfSkin skin,
  GltfAsset gltf,
  _DiagnosticSink sink,
) {
  final accessor = gltf.accessors.elementAtOrNull(skin.inverseBindMatrices!);
  if (accessor == null) return;
  if (accessor.componentType != 5126 ||
      accessor.type != 'MAT4' ||
      accessor.count == null ||
      accessor.count! < skin.joints.length) {
    sink.error(
      'gltf.invalidSkinInverseBindMatricesAccessor',
      'Skin inverseBindMatrices must be a float MAT4 accessor with at least one element per joint.',
      jsonPath: _skinPath(skin.index, '.inverseBindMatrices'),
    );
    return;
  }
  final matrices = _readAccessorNumbers(
    gltf,
    accessor.index,
    requireFloat: true,
  );
  if (matrices == null) return;
  for (var matrix = 0; matrix < skin.joints.length; matrix++) {
    final offset = matrix * 16;
    if (offset + 15 >= matrices.length) return;
    if (matrices[offset + 3].abs() > 1e-6 ||
        matrices[offset + 7].abs() > 1e-6 ||
        matrices[offset + 11].abs() > 1e-6 ||
        (matrices[offset + 15] - 1).abs() > 1e-6) {
      sink.error(
        'gltf.invalidSkinInverseBindMatrix',
        'Skin inverse bind matrices must have fourth row [0, 0, 0, 1].',
        jsonPath: _skinPath(skin.index, '.inverseBindMatrices'),
      );
      return;
    }
  }
}

void _validateSkinSkeletonRoot(
  GltfSkin skin,
  GltfAsset gltf,
  _DiagnosticSink sink,
) {
  final skeleton = skin.skeleton;
  if (skeleton == null || skeleton < 0 || skeleton >= gltf.nodes.length) {
    return;
  }
  final parents = _gltfNodeParents(gltf);
  for (final joint in skin.joints) {
    if (joint < 0 || joint >= gltf.nodes.length) continue;
    if (_isSelfOrAncestor(skeleton, joint, parents)) continue;
    sink.error(
      'gltf.invalidSkinSkeletonRoot',
      'Skin skeleton must be the common root of the joint hierarchy or one of its parents.',
      jsonPath: '\$.skins[${skin.index}].skeleton',
    );
    return;
  }
}

void _validateSkinJointCommonRoot(
  GltfSkin skin,
  GltfAsset gltf,
  _DiagnosticSink sink,
) {
  final parents = _gltfNodeParents(gltf);
  Set<int>? commonAncestors;
  for (final joint in skin.joints) {
    if (joint < 0 || joint >= gltf.nodes.length) continue;
    final ancestors = _selfAndAncestors(joint, parents);
    commonAncestors = commonAncestors == null
        ? ancestors
        : commonAncestors.intersection(ancestors);
    if (commonAncestors.isEmpty) {
      sink.error(
        'gltf.skinJointsMissingCommonRoot',
        'Skin joints must have a common root node.',
        jsonPath: '\$.skins[${skin.index}].joints',
      );
      return;
    }
  }
}

Map<int, int> _gltfNodeParents(GltfAsset gltf) {
  final parents = <int, int>{};
  for (final node in gltf.nodes) {
    for (final child in node.children) {
      if (child < 0 || child >= gltf.nodes.length) continue;
      parents.putIfAbsent(child, () => node.index);
    }
  }
  return parents;
}

Set<int> _selfAndAncestors(int node, Map<int, int> parents) {
  final ancestors = <int>{};
  var current = node;
  while (ancestors.add(current)) {
    final parent = parents[current];
    if (parent == null) break;
    current = parent;
  }
  return ancestors;
}

bool _isSelfOrAncestor(int ancestor, int node, Map<int, int> parents) {
  final seen = <int>{};
  var current = node;
  while (seen.add(current)) {
    if (current == ancestor) return true;
    final parent = parents[current];
    if (parent == null) return false;
    current = parent;
  }
  return false;
}
