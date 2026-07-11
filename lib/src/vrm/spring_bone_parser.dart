part of '../../flvtterm.dart';

VrmSpringBone? _parseSpringBone(
  Map<String, Object?> gltfJson,
  _DiagnosticSink sink,
) {
  final extensions = _object(gltfJson['extensions']);
  if (!extensions.containsKey('VRMC_springBone')) return null;
  final extensionValue = extensions['VRMC_springBone'];
  if (extensionValue is! Map) {
    sink.error(
      'springBone.invalidExtensionObject',
      'Root extensions.VRMC_springBone must be a JSON object.',
      jsonPath: r'$.extensions.VRMC_springBone',
    );
    return null;
  }
  final raw = _object(extensionValue);
  return VrmSpringBone._(
    sourceVersion: VrmSourceVersion.vrm1,
    specVersion: _string(raw['specVersion']),
    colliders: [
      for (var i = 0; i < _list(raw['colliders']).length; i++)
        _parseSpringBoneCollider(i, _list(raw['colliders'])[i], sink),
    ],
    colliderGroups: [
      for (var i = 0; i < _list(raw['colliderGroups']).length; i++)
        _parseSpringBoneColliderGroup(i, _list(raw['colliderGroups'])[i], sink),
    ],
    springs: [
      for (var i = 0; i < _list(raw['springs']).length; i++)
        _parseSpringBoneSpring(i, _list(raw['springs'])[i], sink),
    ],
    raw: raw,
  );
}

VrmSpringBoneCollider _parseSpringBoneCollider(
  int index,
  Object? value,
  _DiagnosticSink sink,
) {
  _validateSpringBoneObject(
    value,
    sink,
    'springBone.invalidColliderObject',
    'SpringBone collider entries must be JSON objects.',
    '\$.extensions.VRMC_springBone.colliders[$index]',
  );
  final raw = _object(value);
  return VrmSpringBoneCollider._(
    index: index,
    node: _int(raw['node']),
    shape: _parseSpringBoneColliderShape(index, raw['shape'], sink),
    raw: raw,
  );
}

VrmSpringBoneColliderShape _parseSpringBoneColliderShape(
  int colliderIndex,
  Object? value,
  _DiagnosticSink sink,
) {
  final path = '\$.extensions.VRMC_springBone.colliders[$colliderIndex].shape';
  _validateSpringBoneObject(
    value,
    sink,
    'springBone.invalidColliderShapeObject',
    'SpringBone collider shape must be a JSON object.',
    path,
  );
  final raw = _object(value);
  final declaredTypes = [
    if (raw.containsKey('sphere')) VrmSpringBoneColliderShapeType.sphere,
    if (raw.containsKey('capsule')) VrmSpringBoneColliderShapeType.capsule,
  ];
  final type = declaredTypes.isEmpty ? null : declaredTypes.first;
  if (type != null) {
    _validateSpringBoneObject(
      raw[type.specName],
      sink,
      'springBone.invalidColliderShapeValueObject',
      'SpringBone collider ${type.specName} shape must be a JSON object.',
      '$path.${type.specName}',
    );
  }
  final shape = switch (type) {
    VrmSpringBoneColliderShapeType.sphere => _object(raw['sphere']),
    VrmSpringBoneColliderShapeType.capsule => _object(raw['capsule']),
    null => const <String, Object?>{},
  };
  return VrmSpringBoneColliderShape._(
    type: type,
    declaredShapeCount: declaredTypes.length,
    offset: _doubleList(shape['offset'], 3, const [0, 0, 0]),
    radius: _double(shape['radius']) ?? 0,
    tail: type == VrmSpringBoneColliderShapeType.capsule
        ? _doubleList(shape['tail'], 3, const [0, 0, 0])
        : null,
    raw: raw,
  );
}

VrmSpringBoneColliderGroup _parseSpringBoneColliderGroup(
  int index,
  Object? value,
  _DiagnosticSink sink,
) {
  _validateSpringBoneObject(
    value,
    sink,
    'springBone.invalidColliderGroupObject',
    'SpringBone collider group entries must be JSON objects.',
    '\$.extensions.VRMC_springBone.colliderGroups[$index]',
  );
  final raw = _object(value);
  return VrmSpringBoneColliderGroup._(
    index: index,
    name: _string(raw['name']),
    colliders: _intList(raw['colliders']),
    raw: raw,
  );
}

VrmSpringBoneSpring _parseSpringBoneSpring(
  int index,
  Object? value,
  _DiagnosticSink sink,
) {
  _validateSpringBoneObject(
    value,
    sink,
    'springBone.invalidSpringObject',
    'SpringBone spring entries must be JSON objects.',
    '\$.extensions.VRMC_springBone.springs[$index]',
  );
  final raw = _object(value);
  final jointValues = _list(raw['joints']);
  return VrmSpringBoneSpring._(
    index: index,
    name: _string(raw['name']),
    joints: [
      for (var i = 0; i < jointValues.length; i++)
        _parseSpringBoneJoint(index, i, jointValues[i], sink),
    ],
    colliderGroups: _intList(raw['colliderGroups']),
    center: _int(raw['center']),
    legacyTerminalLength: null,
    raw: raw,
  );
}

VrmSpringBoneJoint _parseSpringBoneJoint(
  int springIndex,
  int jointIndex,
  Object? value,
  _DiagnosticSink sink,
) {
  final path =
      '\$.extensions.VRMC_springBone.springs[$springIndex].joints[$jointIndex]';
  _validateSpringBoneObject(
    value,
    sink,
    'springBone.invalidJointObject',
    'SpringBone joint entries must be JSON objects.',
    path,
  );
  final raw = _object(value);
  return VrmSpringBoneJoint._(
    index: jointIndex,
    node: _int(raw['node']),
    hitRadius: _double(raw['hitRadius']) ?? 0,
    stiffness: _double(raw['stiffness']) ?? 1,
    gravityPower: _double(raw['gravityPower']) ?? 0,
    gravityDir: _doubleList(raw['gravityDir'], 3, const [0, -1, 0]),
    dragForce: _double(raw['dragForce']) ?? 0.5,
    raw: raw,
  );
}

Map<String, Object?> _springColliderShapeParameters(
  VrmSpringBoneColliderShape shape,
) {
  return switch (shape.type) {
    VrmSpringBoneColliderShapeType.sphere => _object(shape.raw['sphere']),
    VrmSpringBoneColliderShapeType.capsule => _object(shape.raw['capsule']),
    null => const <String, Object?>{},
  };
}

String _springColliderPath(VrmSpringBoneCollider collider, String suffix) =>
    '\$.extensions.VRMC_springBone.colliders[${collider.index}]$suffix';

String _springColliderShapePath(VrmSpringBoneCollider collider, String suffix) {
  final type = collider.shape.type;
  final typePath = type == null ? '' : '.${type.specName}';
  return _springColliderPath(collider, '.shape$typePath$suffix');
}

String _springColliderGroupPath(
  VrmSpringBoneColliderGroup group,
  String suffix,
) => '\$.extensions.VRMC_springBone.colliderGroups[${group.index}]$suffix';

String _springPath(VrmSpringBoneSpring spring, String suffix) =>
    '\$.extensions.VRMC_springBone.springs[${spring.index}]$suffix';

String _springJointPath(
  VrmSpringBoneSpring spring,
  VrmSpringBoneJoint joint,
  String suffix,
) => _springPath(spring, '.joints[${joint.index}]$suffix');

void _validateSpringBone(
  GltfAsset gltf,
  VrmSpringBone springBone,
  _DiagnosticSink sink,
) {
  _validateSpringBoneArray(
    springBone,
    sink,
    'colliders',
    'springBone.invalidColliders',
    'VRMC_springBone.colliders must be an array.',
    'springBone.emptyColliders',
    'VRMC_springBone.colliders must contain at least one collider when declared.',
  );
  _validateSpringBoneArray(
    springBone,
    sink,
    'colliderGroups',
    'springBone.invalidColliderGroups',
    'VRMC_springBone.colliderGroups must be an array.',
    'springBone.emptyColliderGroups',
    'VRMC_springBone.colliderGroups must contain at least one collider group when declared.',
  );
  _validateSpringBoneArray(
    springBone,
    sink,
    'springs',
    'springBone.invalidSprings',
    'VRMC_springBone.springs must be an array.',
    'springBone.emptySprings',
    'VRMC_springBone.springs must contain at least one spring when declared.',
  );

  if (!springBone.raw.containsKey('specVersion')) {
    sink.error(
      'springBone.missingSpecVersion',
      'VRMC_springBone.specVersion is required.',
      jsonPath: r'$.extensions.VRMC_springBone.specVersion',
    );
  } else if (springBone.specVersion != '1.0') {
    sink.error(
      'springBone.unsupportedSpecVersion',
      'VRMC_springBone.specVersion must be "1.0".',
      jsonPath: r'$.extensions.VRMC_springBone.specVersion',
    );
  }

  for (final collider in springBone.colliders) {
    final node = collider.node;
    final hasNode = collider.raw.containsKey('node');
    if (hasNode && collider.raw['node'] is! int) {
      sink.error(
        'springBone.invalidColliderNode',
        'SpringBone collider node must be an integer node index.',
        jsonPath: _springColliderPath(collider, '.node'),
      );
    }
    if (node == null && !hasNode) {
      sink.error(
        'springBone.colliderMissingNode',
        'SpringBone collider must specify a node.',
        jsonPath: _springColliderPath(collider, '.node'),
      );
    }
    if (node != null) {
      _validateIndex(
        node,
        gltf.nodes.length,
        sink,
        'springBone.invalidColliderNode',
        _springColliderPath(collider, '.node'),
      );
    }
    if (collider.shape.declaredShapeCount != 1) {
      sink.error(
        'springBone.invalidColliderShape',
        'SpringBone collider shape must declare exactly one of sphere or capsule.',
        jsonPath: _springColliderPath(collider, '.shape'),
      );
    }
    final shapeParameters = _springColliderShapeParameters(collider.shape);
    if ((shapeParameters.containsKey('radius') &&
            shapeParameters['radius'] is! num) ||
        collider.shape.radius < 0) {
      sink.error(
        'springBone.invalidColliderRadius',
        'SpringBone collider radius must be a non-negative number.',
        jsonPath: _springColliderShapePath(collider, '.radius'),
      );
    }
    if (shapeParameters.containsKey('offset') &&
        _hasInvalidNumberListLength(shapeParameters['offset'], 3)) {
      sink.error(
        'springBone.invalidColliderOffset',
        'SpringBone collider offset must contain three numbers.',
        jsonPath: _springColliderShapePath(collider, '.offset'),
      );
    }
    if (collider.shape.type == VrmSpringBoneColliderShapeType.capsule &&
        shapeParameters.containsKey('tail') &&
        _hasInvalidNumberListLength(shapeParameters['tail'], 3)) {
      sink.error(
        'springBone.invalidColliderTail',
        'SpringBone capsule collider tail must contain three numbers.',
        jsonPath: _springColliderShapePath(collider, '.tail'),
      );
    }
  }

  for (final group in springBone.colliderGroups) {
    if (group.raw.containsKey('name') && group.raw['name'] is! String) {
      sink.error(
        'springBone.invalidColliderGroupName',
        'SpringBone collider group name must be a string.',
        jsonPath: _springColliderGroupPath(group, '.name'),
      );
    }
    if (group.raw.containsKey('colliders') &&
        _hasInvalidIntList(group.raw['colliders'])) {
      sink.error(
        'springBone.invalidColliderGroupCollider',
        'SpringBone collider group colliders must be integer indices.',
        jsonPath: _springColliderGroupPath(group, '.colliders'),
      );
    }
    if (group.colliders.isEmpty) {
      sink.error(
        'springBone.colliderGroupMissingColliders',
        'SpringBone collider group must contain collider indices.',
        jsonPath: _springColliderGroupPath(group, '.colliders'),
      );
    }
    for (final collider in group.colliders) {
      _validateIndex(
        collider,
        springBone.colliders.length,
        sink,
        'springBone.invalidColliderGroupCollider',
        _springColliderGroupPath(group, '.colliders'),
      );
    }
  }

  final parents = _nodeParents(gltf);
  final jointOwner = <int, int>{};

  for (final spring in springBone.springs) {
    if (spring.raw.containsKey('name') && spring.raw['name'] is! String) {
      sink.error(
        'springBone.invalidSpringName',
        'SpringBone spring name must be a string.',
        jsonPath: _springPath(spring, '.name'),
      );
    }
    if (spring.raw.containsKey('joints') && spring.raw['joints'] is! List) {
      sink.error(
        'springBone.invalidSpringJoints',
        'SpringBone spring joints must be an array.',
        jsonPath: _springPath(spring, '.joints'),
      );
    }
    if (spring.joints.isEmpty) {
      sink.error(
        'springBone.springMissingJoints',
        'SpringBone spring must contain at least one joint.',
        jsonPath: _springPath(spring, '.joints'),
      );
    }

    if (spring.raw.containsKey('colliderGroups') &&
        (_hasInvalidIntList(spring.raw['colliderGroups']) ||
            _list(spring.raw['colliderGroups']).isEmpty)) {
      sink.error(
        'springBone.invalidSpringColliderGroup',
        'SpringBone spring colliderGroups must be a non-empty array of integer indices.',
        jsonPath: _springPath(spring, '.colliderGroups'),
      );
    }
    for (final group in spring.colliderGroups) {
      _validateIndex(
        group,
        springBone.colliderGroups.length,
        sink,
        'springBone.invalidSpringColliderGroup',
        _springPath(spring, '.colliderGroups'),
      );
    }

    if (spring.raw.containsKey('center') && spring.raw['center'] is! int) {
      sink.error(
        'springBone.invalidCenter',
        'SpringBone center must be an integer node index.',
        jsonPath: _springPath(spring, '.center'),
      );
    }
    if (spring.center != null) {
      _validateIndex(
        spring.center!,
        gltf.nodes.length,
        sink,
        'springBone.invalidCenter',
        _springPath(spring, '.center'),
      );
      final firstNode = spring.joints.isEmpty ? null : spring.joints.first.node;
      if (firstNode != null &&
          spring.center != firstNode &&
          !_isDescendantOf(firstNode, spring.center!, parents)) {
        sink.error(
          'springBone.invalidCenter',
          'SpringBone center must be the first joint or one of its ancestors.',
          jsonPath: _springPath(spring, '.center'),
        );
      }
    }

    for (var i = 0; i < spring.joints.length; i++) {
      final joint = spring.joints[i];
      final node = joint.node;
      final hasNode = joint.raw.containsKey('node');
      if (hasNode && joint.raw['node'] is! int) {
        sink.error(
          'springBone.invalidJointNode',
          'SpringBone joint node must be an integer node index.',
          jsonPath: _springJointPath(spring, joint, '.node'),
        );
      }
      if (node == null && !hasNode) {
        sink.error(
          'springBone.jointMissingNode',
          'SpringBone joint must specify a node.',
          jsonPath: _springJointPath(spring, joint, '.node'),
        );
      }
      if (node == null) continue;
      _validateIndex(
        node,
        gltf.nodes.length,
        sink,
        'springBone.invalidJointNode',
        _springJointPath(spring, joint, '.node'),
      );
      final previousOwner = jointOwner[node];
      if (previousOwner != null) {
        sink.error(
          'springBone.duplicateJoint',
          'SpringBone joint node $node is used by multiple spring chains.',
          jsonPath: _springJointPath(spring, joint, '.node'),
          gltfNodeIndex: node,
        );
      } else {
        jointOwner[node] = spring.index;
      }
      if (i > 0) {
        final previous = spring.joints[i - 1].node;
        if (previous != null && !_isDescendantOf(node, previous, parents)) {
          sink.error(
            'springBone.invalidJointOrder',
            'Each SpringBone joint must be a descendant of the previous joint.',
            jsonPath: _springJointPath(spring, joint, '.node'),
            gltfNodeIndex: node,
          );
        }
      }
      final hasInvalidParameterType = const [
        'hitRadius',
        'stiffness',
        'gravityPower',
        'dragForce',
      ].any((key) => joint.raw.containsKey(key) && joint.raw[key] is! num);
      if (hasInvalidParameterType ||
          joint.hitRadius < 0 ||
          joint.stiffness < 0 ||
          joint.gravityPower < 0 ||
          joint.dragForce < 0 ||
          joint.dragForce > 1) {
        sink.error(
          'springBone.invalidJointParameters',
          'SpringBone joint numeric parameters are outside allowed ranges.',
          jsonPath: _springJointPath(spring, joint, ''),
          gltfNodeIndex: node,
        );
      }
      final rawGravityDir = _list(joint.raw['gravityDir']);
      if (rawGravityDir.isNotEmpty &&
          (rawGravityDir.length != 3 ||
              rawGravityDir.any((value) => value is! num))) {
        sink.error(
          'springBone.invalidGravityDir',
          'SpringBone gravityDir must contain three numbers.',
          jsonPath: _springJointPath(spring, joint, '.gravityDir'),
          gltfNodeIndex: node,
        );
      }
    }
  }

  for (final spring in springBone.springs) {
    final center = spring.center;
    if (center == null) continue;
    for (final otherSpring in springBone.springs) {
      if (otherSpring.index == spring.index) continue;
      for (final joint in otherSpring.joints) {
        final otherNode = joint.node;
        if (otherNode == null) continue;
        if (center == otherNode ||
            _isDescendantOf(center, otherNode, parents)) {
          sink.error(
            'springBone.invalidCenter',
            'SpringBone center must not be a joint, or descendant of a joint, in another spring chain.',
            jsonPath: _springPath(spring, '.center'),
            gltfNodeIndex: center,
          );
        }
      }
    }
  }
}

void _validateSpringBoneArray(
  VrmSpringBone springBone,
  _DiagnosticSink sink,
  String key,
  String invalidCode,
  String invalidMessage,
  String emptyCode,
  String emptyMessage,
) {
  if (!springBone.raw.containsKey(key)) return;
  final path = '\$.extensions.VRMC_springBone.$key';
  final value = springBone.raw[key];
  if (value is! List) {
    sink.error(invalidCode, invalidMessage, jsonPath: path);
  } else if (value.isEmpty) {
    sink.error(emptyCode, emptyMessage, jsonPath: path);
  }
}

void _validateSpringBoneObject(
  Object? value,
  _DiagnosticSink sink,
  String code,
  String message,
  String path,
) {
  if (value is! Map) {
    sink.error(code, message, jsonPath: path);
  }
}
