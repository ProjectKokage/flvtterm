part of '../../flvtterm.dart';

void _validateRequiredArray(
  Map<String, Object?> raw,
  String key,
  _DiagnosticSink sink,
  String missingCode,
  String invalidCode,
  String message,
  String jsonPath,
) {
  if (!raw.containsKey(key)) {
    sink.error(missingCode, message, jsonPath: jsonPath);
    return;
  }
  final value = raw[key];
  if (value is! List) {
    sink.error(invalidCode, message, jsonPath: jsonPath);
    return;
  }
  if (value.isEmpty) {
    sink.error(missingCode, message, jsonPath: jsonPath);
  }
}

void _validateNodeHierarchy(GltfAsset gltf, _DiagnosticSink sink) {
  final parents = <int, int>{};
  for (final node in gltf.nodes) {
    final children = <int>{};
    var duplicateChildReported = false;
    for (var childIndex = 0; childIndex < node.children.length; childIndex++) {
      final child = node.children[childIndex];
      final childPath = _nodePath(node.index, '.children[$childIndex]');
      if (child < 0 || child >= gltf.nodes.length) continue;
      if (!children.add(child)) {
        if (!duplicateChildReported) {
          sink.error(
            'gltf.duplicateNodeChild',
            'Node children must not contain duplicate node indices.',
            jsonPath: childPath,
            gltfNodeIndex: node.index,
          );
          duplicateChildReported = true;
        }
        continue;
      }
      final previous = parents[child];
      if (previous == null) {
        parents[child] = node.index;
      } else if (previous != node.index) {
        sink.error(
          'gltf.nodeMultipleParents',
          'glTF nodes must not have more than one parent.',
          jsonPath: childPath,
          gltfNodeIndex: child,
        );
      }
    }
  }

  for (final scene in gltf.scenes) {
    for (var rootIndex = 0; rootIndex < scene.nodes.length; rootIndex++) {
      final root = scene.nodes[rootIndex];
      if (parents.containsKey(root)) {
        sink.error(
          'gltf.sceneRootHasParent',
          'Scene root nodes must not be listed as children of another node.',
          jsonPath: _scenePath(scene.index, '.nodes[$rootIndex]'),
          gltfNodeIndex: root,
        );
      }
    }
  }

  final reported = <int>{};
  for (final node in gltf.nodes) {
    final seen = <int>{};
    var current = node.index;
    var hasCycle = false;
    while (true) {
      if (!seen.add(current)) {
        hasCycle = true;
        break;
      }
      final parent = parents[current];
      if (parent == null) break;
      current = parent;
    }
    if (!hasCycle || !reported.add(current)) continue;
    sink.error(
      'gltf.nodeCycle',
      'glTF node hierarchy must not contain cycles.',
      jsonPath: _nodePath(current, '.children'),
      gltfNodeIndex: current,
    );
  }
}

void _validateGltfNodes(GltfAsset gltf, _DiagnosticSink sink) {
  final rawNodes = _list(gltf.json['nodes']);
  final animatedNodes = <int>{
    for (final animation in gltf.animations)
      for (final channel in animation.channels)
        if (channel.targetNode != null) channel.targetNode!,
  };
  for (final node in gltf.nodes) {
    final raw = _object(rawNodes.elementAtOrNull(node.index));
    final hasMatrix = raw.containsKey('matrix');
    if (hasMatrix &&
        (raw.containsKey('translation') ||
            raw.containsKey('rotation') ||
            raw.containsKey('scale'))) {
      sink.error(
        'gltf.nodeMatrixWithTrs',
        'Node matrix must not be used with translation, rotation, or scale.',
        jsonPath: _nodePath(node.index, '.matrix'),
        gltfNodeIndex: node.index,
      );
    }
    if (hasMatrix && animatedNodes.contains(node.index)) {
      sink.error(
        'gltf.animatedNodeMatrix',
        'Animated nodes must not define matrix transforms.',
        jsonPath: _nodePath(node.index, '.matrix'),
        gltfNodeIndex: node.index,
      );
    }
    _validateArrayLength(
      raw,
      'matrix',
      16,
      sink,
      'gltf.invalidNodeMatrix',
      node.index,
    );
    _validateNodeMatrixDecomposable(node, sink);
    _validateArrayLength(
      raw,
      'translation',
      3,
      sink,
      'gltf.invalidNodeTranslation',
      node.index,
    );
    _validateArrayLength(
      raw,
      'rotation',
      4,
      sink,
      'gltf.invalidNodeRotation',
      node.index,
    );
    _validateNodeRotationQuaternion(raw, sink, node.index);
    _validateArrayLength(
      raw,
      'scale',
      3,
      sink,
      'gltf.invalidNodeScale',
      node.index,
    );
    for (var childIndex = 0; childIndex < node.children.length; childIndex++) {
      final child = node.children[childIndex];
      _validateIndex(
        child,
        gltf.nodes.length,
        sink,
        'gltf.invalidNodeChild',
        _nodePath(node.index, '.children[$childIndex]'),
      );
    }
    if (raw.containsKey('camera') && raw['camera'] is! int) {
      sink.error(
        'gltf.invalidNodeCamera',
        'Node camera must be an integer.',
        jsonPath: _nodePath(node.index, '.camera'),
        gltfNodeIndex: node.index,
      );
    } else if (node.camera != null) {
      _validateIndex(
        node.camera!,
        gltf.cameras.length,
        sink,
        'gltf.invalidNodeCamera',
        _nodePath(node.index, '.camera'),
      );
    }
    if (raw.containsKey('mesh') && raw['mesh'] is! int) {
      sink.error(
        'gltf.invalidNodeMesh',
        'Node mesh must be an integer.',
        jsonPath: _nodePath(node.index, '.mesh'),
        gltfNodeIndex: node.index,
      );
    } else if (node.mesh != null) {
      _validateIndex(
        node.mesh!,
        gltf.meshes.length,
        sink,
        'gltf.invalidNodeMesh',
        _nodePath(node.index, '.mesh'),
      );
    }
    if (raw.containsKey('weights')) {
      if (_hasInvalidNumberList(raw['weights'])) {
        sink.error(
          'gltf.invalidNodeWeights',
          'Node weights must be a non-empty array of numbers.',
          jsonPath: _nodePath(node.index, '.weights'),
          gltfNodeIndex: node.index,
        );
      } else if (node.mesh == null) {
        sink.error(
          'gltf.nodeWeightsWithoutMesh',
          'Node weights must not be defined without a mesh.',
          jsonPath: _nodePath(node.index, '.weights'),
          gltfNodeIndex: node.index,
        );
      } else {
        final mesh = gltf.meshes.elementAtOrNull(node.mesh!);
        final targetCount = mesh == null || mesh.primitives.isEmpty
            ? 0
            : mesh.primitives.first.targets.length;
        if (mesh != null && node.weights.length != targetCount) {
          sink.error(
            'gltf.invalidNodeWeights',
            'Node weights length must match the number of mesh morph targets.',
            jsonPath: _nodePath(node.index, '.weights'),
            gltfNodeIndex: node.index,
          );
        }
      }
    }
    if (raw.containsKey('skin') && raw['skin'] is! int) {
      sink.error(
        'gltf.invalidNodeSkin',
        'Node skin must be an integer.',
        jsonPath: _nodePath(node.index, '.skin'),
        gltfNodeIndex: node.index,
      );
    } else if (node.skin != null) {
      _validateIndex(
        node.skin!,
        gltf.skins.length,
        sink,
        'gltf.invalidNodeSkin',
        _nodePath(node.index, '.skin'),
      );
      _validateSkinnedNode(node, gltf, sink);
    }
  }
}

void _validateArrayLength(
  Map<String, Object?> raw,
  String key,
  int expectedLength,
  _DiagnosticSink sink,
  String code,
  int nodeIndex,
) {
  if (!raw.containsKey(key)) return;
  final values = _list(raw[key]);
  if (values.length == expectedLength &&
      values.every((value) => value is num)) {
    return;
  }
  sink.error(
    code,
    'Node $key must be an array of $expectedLength numbers.',
    jsonPath: _nodePath(nodeIndex, '.$key'),
    gltfNodeIndex: nodeIndex,
  );
}

void _validateNodeMatrixDecomposable(GltfNode node, _DiagnosticSink sink) {
  final matrix = node.matrix;
  if (matrix == null) return;
  final m = matrix.storage;
  final affine =
      _nearlyZero(m[3]) &&
      _nearlyZero(m[7]) &&
      _nearlyZero(m[11]) &&
      (m[15] - 1).abs() <= 1e-5;
  final hasShear =
      !_nearlyZero(m[0] * m[4] + m[1] * m[5] + m[2] * m[6]) ||
      !_nearlyZero(m[0] * m[8] + m[1] * m[9] + m[2] * m[10]) ||
      !_nearlyZero(m[4] * m[8] + m[5] * m[9] + m[6] * m[10]);
  if (affine && !hasShear) return;
  sink.error(
    'gltf.invalidNodeMatrixDecomposition',
    'Node matrix must be decomposable to translation, rotation, and scale.',
    jsonPath: _nodePath(node.index, '.matrix'),
    gltfNodeIndex: node.index,
  );
}

bool _nearlyZero(double value) => value.abs() <= 1e-5;

void _validateNodeRotationQuaternion(
  Map<String, Object?> raw,
  _DiagnosticSink sink,
  int nodeIndex,
) {
  if (!raw.containsKey('rotation')) return;
  final values = _list(raw['rotation']);
  if (values.length != 4 || values.any((value) => value is! num)) return;
  final lengthSquared = values.cast<num>().fold<double>(
    0,
    (sum, value) => sum + value.toDouble() * value.toDouble(),
  );
  if ((lengthSquared - 1).abs() <= 1e-4) return;
  sink.error(
    'gltf.invalidNodeRotationQuaternion',
    'Node rotation quaternion must be normalized.',
    jsonPath: _nodePath(nodeIndex, '.rotation'),
    gltfNodeIndex: nodeIndex,
  );
}

String _nodePath(int nodeIndex, String suffix) => '\$.nodes[$nodeIndex]$suffix';

void _validateAnimationSamplerAccessors(
  GltfAsset gltf,
  GltfAnimationSampler sampler,
  _DiagnosticSink sink,
  String samplerPath,
) {
  final input = sampler.input == null
      ? null
      : gltf.accessors.elementAtOrNull(sampler.input!);
  if (input != null &&
      (input.type != 'SCALAR' ||
          input.componentType != 5126 ||
          input.normalized)) {
    sink.error(
      'gltf.invalidAnimationInputAccessor',
      'Animation sampler input accessor must be SCALAR float.',
      jsonPath: '$samplerPath.input',
    );
  }
  if (input != null && (input.minimum == null || input.maximum == null)) {
    sink.error(
      'gltf.missingAnimationInputAccessorBounds',
      'Animation sampler input accessors must define min and max bounds.',
      jsonPath: '$samplerPath.input',
    );
  }
  if (input != null &&
      sampler.interpolation == 'CUBICSPLINE' &&
      input.count == 1) {
    sink.error(
      'gltf.invalidAnimationCubicSplineKeyframes',
      'CUBICSPLINE animation samplers must have at least two keyframes.',
      jsonPath: '$samplerPath.input',
    );
  }
  final inputValues = sampler.input == null
      ? null
      : _readAccessorNumbers(gltf, sampler.input!, requireFloat: true);
  if (inputValues != null &&
      (inputValues.isNotEmpty && inputValues.first < 0 ||
          !_isStrictlyIncreasing(inputValues))) {
    sink.error(
      'gltf.invalidAnimationInputTimes',
      'Animation sampler input times must be non-negative and strictly increasing.',
      jsonPath: '$samplerPath.input',
    );
  }
}

void _validateAnimationChannelOutputCount(
  GltfAsset gltf,
  GltfAnimationChannel channel,
  GltfAnimationSampler sampler,
  _DiagnosticSink sink,
  String samplerPath,
) {
  final input = sampler.input == null
      ? null
      : gltf.accessors.elementAtOrNull(sampler.input!);
  final output = sampler.output == null
      ? null
      : gltf.accessors.elementAtOrNull(sampler.output!);
  if (output != null) {
    final expectedType = switch (channel.targetPath) {
      'translation' || 'scale' => 'VEC3',
      'rotation' => 'VEC4',
      'weights' => 'SCALAR',
      _ => null,
    };
    if (expectedType != null &&
        (output.type != expectedType ||
            !_isValidAnimationOutputComponent(output, channel.targetPath))) {
      sink.error(
        'gltf.invalidAnimationOutputAccessor',
        'Animation sampler output accessor shape does not match the target path.',
        jsonPath: '$samplerPath.output',
      );
    }
    _validateAnimationFiniteOutput(
      gltf,
      sampler,
      channel.targetPath,
      sink,
      samplerPath,
    );
  }
  final inputCount = input?.count;
  final outputCount = output?.count;
  if (inputCount == null || outputCount == null) return;
  if (channel.targetPath == 'rotation' && output != null) {
    _validateAnimationRotationOutput(gltf, sampler, output, sink, samplerPath);
  }
  final multiplier = sampler.interpolation == 'CUBICSPLINE' ? 3 : 1;
  final targetMultiplier = switch (channel.targetPath) {
    'translation' || 'rotation' || 'scale' => 1,
    'weights' => _animationMorphTargetCount(gltf, channel.targetNode),
    _ => null,
  };
  if (targetMultiplier == null) return;
  final expected = inputCount * multiplier * targetMultiplier;
  if (outputCount != expected) {
    sink.error(
      'gltf.invalidAnimationOutputCount',
      'Animation sampler output count must match input count, target path, and interpolation.',
      jsonPath: '$samplerPath.output',
    );
  }
}

void _validateAnimationFiniteOutput(
  GltfAsset gltf,
  GltfAnimationSampler sampler,
  String? targetPath,
  _DiagnosticSink sink,
  String samplerPath,
) {
  if (!const {'translation', 'scale', 'weights'}.contains(targetPath)) return;
  final outputIndex = sampler.output;
  if (outputIndex == null) return;
  final values = _readAccessorNumbers(gltf, outputIndex);
  if (values == null) return;
  if (values.every((value) => value.isFinite)) return;
  sink.error(
    'gltf.invalidAnimationOutputValue',
    'Animation sampler output values must be finite numbers.',
    jsonPath: '$samplerPath.output',
  );
}

void _validateAnimationRotationOutput(
  GltfAsset gltf,
  GltfAnimationSampler sampler,
  GltfAccessor output,
  _DiagnosticSink sink,
  String samplerPath,
) {
  final outputIndex = sampler.output;
  if (outputIndex == null ||
      output.type != 'VEC4' ||
      !_isValidAnimationOutputComponent(output, 'rotation')) {
    return;
  }
  final values = _readAccessorNumbers(gltf, outputIndex);
  if (values == null) return;
  final stride = sampler.interpolation == 'CUBICSPLINE' ? 12 : 4;
  final valueOffset = sampler.interpolation == 'CUBICSPLINE' ? 4 : 0;
  final tolerance = _animationRotationTolerance(output);
  for (var i = valueOffset; i + 3 < values.length; i += stride) {
    final lengthSquared =
        values[i] * values[i] +
        values[i + 1] * values[i + 1] +
        values[i + 2] * values[i + 2] +
        values[i + 3] * values[i + 3];
    if ((lengthSquared - 1).abs() <= tolerance) continue;
    sink.error(
      'gltf.invalidAnimationRotationQuaternion',
      'Animation rotation output quaternions must be normalized.',
      jsonPath: '$samplerPath.output',
    );
    return;
  }
}

double _animationRotationTolerance(GltfAccessor output) {
  if (!output.normalized) return 1e-4;
  return switch (output.componentType) {
    5120 || 5121 => 0.02,
    5122 || 5123 => 0.0002,
    _ => 1e-4,
  };
}

bool _isValidAnimationOutputComponent(GltfAccessor output, String? targetPath) {
  if (targetPath == 'translation' || targetPath == 'scale') {
    return output.componentType == 5126 && !output.normalized;
  }
  if (targetPath == 'rotation' || targetPath == 'weights') {
    if (output.componentType == 5126) return !output.normalized;
    return output.normalized &&
        const {5120, 5121, 5122, 5123}.contains(output.componentType);
  }
  return false;
}

int? _animationMorphTargetCount(GltfAsset gltf, int? nodeIndex) {
  if (nodeIndex == null) return null;
  final meshIndex = gltf.nodes.elementAtOrNull(nodeIndex)?.mesh;
  final mesh = meshIndex == null
      ? null
      : gltf.meshes.elementAtOrNull(meshIndex);
  if (mesh == null || mesh.primitives.isEmpty) return null;
  return mesh.primitives.first.targets.length;
}

bool _animationTargetHasMorphTargets(GltfAsset gltf, int nodeIndex) {
  final count = _animationMorphTargetCount(gltf, nodeIndex);
  return count != null && count > 0;
}

bool _isStrictlyIncreasing(List<num> values) {
  for (var i = 0; i < values.length; i++) {
    if (!values[i].isFinite || (i > 0 && values[i] <= values[i - 1])) {
      return false;
    }
  }
  return true;
}

void _validateAccessorBufferViewTarget(
  GltfAsset gltf,
  int accessorIndex,
  int expectedTarget,
  _DiagnosticSink sink,
  String code,
  String message,
  String jsonPath,
) {
  final accessor = gltf.accessors.elementAtOrNull(accessorIndex);
  final viewIndex = accessor?.bufferView;
  if (viewIndex == null ||
      viewIndex < 0 ||
      viewIndex >= gltf.bufferViews.length) {
    return;
  }
  final target = gltf.bufferViews[viewIndex].target;
  if (target == null || target == expectedTarget) return;
  sink.error(code, message, jsonPath: jsonPath);
}

bool _isValidPrimitiveAttributeAccessor(
  String semantic,
  GltfAccessor accessor,
) {
  if (semantic == 'POSITION' || semantic == 'NORMAL') {
    return accessor.type == 'VEC3' && _isFloatAccessor(accessor);
  }
  if (semantic == 'TANGENT') {
    return accessor.type == 'VEC4' && _isFloatAccessor(accessor);
  }
  if (_isIndexedSemantic(semantic, 'TEXCOORD_')) {
    return accessor.type == 'VEC2' && _isFloatOrNormalizedByteShort(accessor);
  }
  if (_isIndexedSemantic(semantic, 'COLOR_')) {
    return (accessor.type == 'VEC3' || accessor.type == 'VEC4') &&
        _isFloatOrNormalizedByteShort(accessor);
  }
  if (_isIndexedSemantic(semantic, 'JOINTS_')) {
    return accessor.type == 'VEC4' &&
        (accessor.componentType == 5121 || accessor.componentType == 5123) &&
        !accessor.normalized;
  }
  if (_isIndexedSemantic(semantic, 'WEIGHTS_')) {
    return accessor.type == 'VEC4' && _isFloatOrNormalizedByteShort(accessor);
  }
  return true;
}

bool _isIndexedSemantic(String semantic, String prefix) {
  if (!semantic.startsWith(prefix)) return false;
  final suffix = semantic.substring(prefix.length);
  return suffix.isNotEmpty &&
      suffix.codeUnits.every((unit) => unit >= 48 && unit <= 57);
}

bool _isFloatAccessor(GltfAccessor accessor) =>
    accessor.componentType == 5126 && !accessor.normalized;

bool _isFloatOrNormalizedByteShort(GltfAccessor accessor) =>
    _isFloatAccessor(accessor) ||
    ((accessor.componentType == 5121 || accessor.componentType == 5123) &&
        accessor.normalized);

bool _isValidMorphTargetAttributeAccessor(
  String semantic,
  GltfAccessor accessor,
) {
  if (semantic == 'POSITION' || semantic == 'NORMAL' || semantic == 'TANGENT') {
    return accessor.type == 'VEC3' &&
        accessor.componentType == 5126 &&
        !accessor.normalized;
  }
  if (_isIndexedSemantic(semantic, 'TEXCOORD_')) {
    return accessor.type == 'VEC2' && _isMorphDeltaAccessor(accessor);
  }
  if (_isIndexedSemantic(semantic, 'COLOR_')) {
    return (accessor.type == 'VEC3' || accessor.type == 'VEC4') &&
        _isMorphDeltaAccessor(accessor);
  }
  return true;
}

bool _isMorphDeltaAccessor(GltfAccessor accessor) {
  if (_isFloatAccessor(accessor)) return true;
  return accessor.normalized &&
      const {5120, 5121, 5122, 5123}.contains(accessor.componentType);
}
