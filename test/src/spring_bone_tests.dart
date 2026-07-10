part of '../flvtterm_test.dart';

void springBoneTests() {
  test('parses SpringBone metadata from the root extension', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'extras': {
        'tags': ['source'],
      },
      'colliders': [
        {
          'node': 2,
          'shape': {
            'sphere': {
              'offset': [0.0, 0.1, 0.2],
              'radius': 0.3,
            },
          },
        },
        {
          'node': 2,
          'shape': {
            'capsule': {
              'offset': [0.0, 0.0, 0.0],
              'radius': 0.2,
              'tail': [0.0, 1.0, 0.0],
            },
          },
        },
      ],
      'colliderGroups': [
        {
          'name': 'head',
          'colliders': [0, 1],
        },
      ],
      'springs': [
        {
          'name': 'hair',
          'center': 0,
          'joints': [
            {
              'node': 1,
              'hitRadius': 0.01,
              'stiffness': 0.8,
              'gravityPower': 0.2,
              'gravityDir': [0.0, -1.0, 0.0],
              'dragForce': 0.4,
            },
            {'node': 2},
          ],
          'colliderGroups': [0],
        },
      ],
    };

    final model = VrmModel.parseGlb(_glb(json));
    final springBone = model.springBone!;

    expect(springBone.specVersion, '1.0');
    final rawExtras = springBone.raw['extras']! as Map<String, Object?>;
    final rawTags = rawExtras['tags']! as List<Object?>;
    expect(rawTags, ['source']);
    expect(() => rawExtras['other'] = true, throwsUnsupportedError);
    expect(() => rawTags.add('copy'), throwsUnsupportedError);
    expect(springBone.colliders.length, 2);
    expect(
      springBone.colliders.first.shape.type,
      VrmSpringBoneColliderShapeType.sphere,
    );
    expect(springBone.colliders.last.shape.tail, [0.0, 1.0, 0.0]);
    expect(springBone.colliderGroups.single.colliders, [0, 1]);
    expect(springBone.springs.single.center, 0);
    expect(springBone.springs.single.joints.first.dragForce, 0.4);
    expect(
      () => springBone.colliders.add(springBone.colliders.first),
      throwsUnsupportedError,
    );
    expect(() => springBone.raw['extra'] = true, throwsUnsupportedError);
    expect(
      () => springBone.colliders.first.shape.offset.add(1.0),
      throwsUnsupportedError,
    );
    expect(
      () => springBone.colliders.last.shape.tail!.add(2.0),
      throwsUnsupportedError,
    );
    expect(
      () => springBone.colliderGroups.single.colliders.add(2),
      throwsUnsupportedError,
    );
    expect(
      () => springBone.springs.single.joints.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => springBone.springs.single.colliderGroups.add(1),
      throwsUnsupportedError,
    );
    expect(
      () => springBone.springs.single.joints.first.gravityDir.add(1.0),
      throwsUnsupportedError,
    );
  });

  test('reports invalid SpringBone metadata in permissive mode', () {
    final json = _minimalVrmJson();
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '0.9',
      'colliders': [
        {
          'shape': {
            'sphere': {'radius': -1.0},
            'capsule': <String, Object?>{},
          },
        },
        {
          'node': 'bad',
          'shape': {
            'sphere': {'radius': 0.1},
          },
        },
        {
          'node': 2,
          'shape': {
            'capsule': {
              'offset': [0.0, 'bad', 0.0],
              'radius': 0.1,
              'tail': [0.0],
            },
          },
        },
      ],
      'colliderGroups': [
        {
          'colliders': [4, 'bad'],
        },
      ],
      'springs': [
        {
          'center': 4,
          'joints': [
            {
              'node': 2,
              'hitRadius': -0.1,
              'dragForce': 2.0,
              'gravityDir': [0.0],
            },
            {'node': 1},
          ],
          'colliderGroups': [3, 'bad'],
        },
        {
          'center': 2,
          'joints': [
            {'node': 2},
            {'node': 'bad'},
          ],
        },
        {
          'center': 'bad',
          'joints': [
            {'node': 3},
          ],
        },
      ],
    };

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'springBone.unsupportedSpecVersion',
        'springBone.colliderMissingNode',
        'springBone.invalidColliderShape',
        'springBone.invalidColliderNode',
        'springBone.invalidColliderRadius',
        'springBone.invalidColliderOffset',
        'springBone.invalidColliderTail',
        'springBone.invalidColliderGroupCollider',
        'springBone.invalidSpringColliderGroup',
        'springBone.invalidCenter',
        'springBone.invalidJointOrder',
        'springBone.invalidJointNode',
        'springBone.invalidJointParameters',
        'springBone.invalidGravityDir',
        'springBone.duplicateJoint',
      ]),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'springBone.invalidColliderGroupCollider')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'springBone.invalidSpringColliderGroup')
          .length,
      2,
    );

    Iterable<String?> pathsFor(String code) => result.validation.errors
        .where((diagnostic) => diagnostic.code == code)
        .map((diagnostic) => diagnostic.jsonPath);

    expect(
      pathsFor('springBone.colliderMissingNode'),
      contains(r'$.extensions.VRMC_springBone.colliders[0].node'),
    );
    expect(
      pathsFor('springBone.invalidColliderShape'),
      contains(r'$.extensions.VRMC_springBone.colliders[0].shape'),
    );
    expect(
      pathsFor('springBone.invalidColliderRadius'),
      contains(
        r'$.extensions.VRMC_springBone.colliders[0].shape.sphere.radius',
      ),
    );
    expect(
      pathsFor('springBone.invalidColliderOffset'),
      contains(
        r'$.extensions.VRMC_springBone.colliders[2].shape.capsule.offset',
      ),
    );
    expect(
      pathsFor('springBone.invalidColliderTail'),
      contains(r'$.extensions.VRMC_springBone.colliders[2].shape.capsule.tail'),
    );
    expect(
      pathsFor('springBone.invalidColliderGroupCollider'),
      contains(r'$.extensions.VRMC_springBone.colliderGroups[0].colliders'),
    );
    expect(
      pathsFor('springBone.invalidSpringColliderGroup'),
      contains(r'$.extensions.VRMC_springBone.springs[0].colliderGroups'),
    );
    expect(
      pathsFor('springBone.invalidCenter'),
      contains(r'$.extensions.VRMC_springBone.springs[2].center'),
    );
    expect(
      pathsFor('springBone.invalidJointOrder'),
      contains(r'$.extensions.VRMC_springBone.springs[0].joints[1].node'),
    );
    expect(
      pathsFor('springBone.invalidJointNode'),
      contains(r'$.extensions.VRMC_springBone.springs[1].joints[1].node'),
    );
    expect(
      pathsFor('springBone.invalidJointParameters'),
      contains(r'$.extensions.VRMC_springBone.springs[0].joints[0]'),
    );
    expect(
      pathsFor('springBone.invalidGravityDir'),
      contains(r'$.extensions.VRMC_springBone.springs[0].joints[0].gravityDir'),
    );
    expect(
      pathsFor('springBone.duplicateJoint'),
      contains(r'$.extensions.VRMC_springBone.springs[1].joints[0].node'),
    );
  });

  test('reports missing SpringBone specVersion', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    json['extensions'] = Map<String, Object?>.from(json['extensions']! as Map)
      ..['VRMC_springBone'] = <String, Object?>{};

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('springBone.missingSpecVersion'),
    );
    expect(
      result.validation.errors.map((d) => d.code),
      isNot(contains('springBone.unsupportedSpecVersion')),
    );
  });

  test('reports malformed SpringBone root extension object', () {
    for (final value in ['bad', null]) {
      final json = _minimalVrmJson();
      json['extensions'] = Map<String, Object?>.from(json['extensions']! as Map)
        ..['VRMC_springBone'] = value;

      final result = VrmModel.tryParseGlb(
        _glb(json),
        validation: VrmValidationMode.permissive,
      );

      expect(result.asset, isNotNull);
      expect(
        result.validation.errors.map((d) => d.code),
        contains('springBone.invalidExtensionObject'),
      );
    }
  });

  test('reports malformed SpringBone root collection arrays', () {
    final json = _minimalVrmJson();
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'colliders': 'bad',
      'colliderGroups': {'bad': true},
      'springs': 1,
    };

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'springBone.invalidColliders',
        'springBone.invalidColliderGroups',
        'springBone.invalidSprings',
      ]),
    );
  });

  test('reports empty declared SpringBone root collection arrays', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'colliders': <Object?>[],
      'colliderGroups': <Object?>[],
      'springs': <Object?>[],
    };
    final bytes = _glb(json);

    final permissive = VrmModel.tryParseGlb(
      bytes,
      validation: VrmValidationMode.permissive,
    );
    final strict = VrmModel.tryParseGlb(bytes);

    expect(permissive.asset, isNotNull);
    expect(strict.asset, isNull);
    expect(
      permissive.validation.errors.map((d) => d.code),
      containsAll([
        'springBone.emptyColliders',
        'springBone.emptyColliderGroups',
        'springBone.emptySprings',
      ]),
    );
    expect(
      permissive.validation.errors.map((d) => d.jsonPath),
      containsAll([
        r'$.extensions.VRMC_springBone.colliders',
        r'$.extensions.VRMC_springBone.colliderGroups',
        r'$.extensions.VRMC_springBone.springs',
      ]),
    );
  });

  test('reports malformed SpringBone collection item objects', () {
    final json = _minimalVrmJson();
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'colliders': [null],
      'colliderGroups': [null],
      'springs': [
        {
          'joints': [null],
        },
        null,
      ],
    };

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'springBone.invalidColliderObject',
        'springBone.invalidColliderGroupObject',
        'springBone.invalidSpringObject',
        'springBone.invalidJointObject',
      ]),
    );
  });

  test('reports malformed SpringBone optional names', () {
    final json = _minimalVrmJson();
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'colliders': [
        {
          'node': 0,
          'shape': {
            'sphere': {'radius': 0},
          },
        },
      ],
      'colliderGroups': [
        {
          'name': 1,
          'colliders': [0],
        },
      ],
      'springs': [
        {
          'name': ['bad'],
          'joints': [
            {'node': 0},
          ],
        },
      ],
    };

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'springBone.invalidColliderGroupName',
        'springBone.invalidSpringName',
      ]),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      containsAll([
        r'$.extensions.VRMC_springBone.colliderGroups[0].name',
        r'$.extensions.VRMC_springBone.springs[0].name',
      ]),
    );
  });

  test('reports malformed SpringBone collider shape objects', () {
    final json = _minimalVrmJson();
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'colliders': [
        {'node': 1, 'shape': null},
        {
          'node': 2,
          'shape': {'sphere': null},
        },
      ],
    };

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'springBone.invalidColliderShapeObject',
        'springBone.invalidColliderShapeValueObject',
      ]),
    );
  });

  test('reports malformed SpringBone spring arrays', () {
    final json = _minimalVrmJson();
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {'joints': 'bad', 'colliderGroups': <Object?>[]},
      ],
    };

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'springBone.invalidSpringJoints',
        'springBone.invalidSpringColliderGroup',
      ]),
    );
  });

  test('reports malformed SpringBone scalar numeric fields', () {
    final json = _minimalVrmJson();
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'colliders': [
        {
          'node': 1,
          'shape': {
            'sphere': {'radius': 'bad'},
          },
        },
      ],
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'hitRadius': 'bad',
              'stiffness': 'bad',
              'gravityPower': 'bad',
              'dragForce': 'bad',
            },
          ],
        },
      ],
    };

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'springBone.invalidColliderRadius',
        'springBone.invalidJointParameters',
      ]),
    );
  });

  test('runtime SpringBone applies deterministic joint rotation', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [1.0, 0.0, 0.0],
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(1.0);

    expect(
      binding.nodes[1]!.localTransform.storage[4],
      closeTo(math.sqrt1_2, 0.0001),
    );
    expect(
      binding.nodes[1]!.localTransform.storage[5],
      closeTo(math.sqrt1_2, 0.0001),
    );
    final afterStep = binding.nodes[1]!.localTransform;

    runtime.update(0.0);

    expect(
      binding.nodes[1]!.localTransform.storage[4],
      closeTo(afterStep.storage[4], 0.0001),
    );
    expect(
      binding.nodes[1]!.localTransform.storage[5],
      closeTo(afterStep.storage[5], 0.0001),
    );
  });

  test('runtime SpringBone evaluates separate chains root to descendant', () {
    VrmRuntime runtime({required bool childFirst}) {
      final json = _minimalVrmJson()
        ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
      final nodes = json['nodes']! as List<Map<String, Object?>>;
      nodes[1]['translation'] = [0.0, 0.0, 0.0];
      for (final node in [9, 10, 11]) {
        nodes[node]['translation'] = [0.0, 1.0, 0.0];
      }
      final parentSpring = {
        'joints': [
          {
            'node': 1,
            'stiffness': 0.0,
            'gravityPower': 1.0,
            'gravityDir': [1.0, 0.0, 0.0],
            'dragForce': 1.0,
          },
          {'node': 9},
        ],
      };
      final childSpring = {
        'joints': [
          {'node': 10, 'stiffness': 1.0, 'gravityPower': 0.0, 'dragForce': 1.0},
          {'node': 11},
        ],
      };
      (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
        'specVersion': '1.0',
        'springs': childFirst
            ? [childSpring, parentSpring]
            : [parentSpring, childSpring],
      };
      return VrmRuntime(VrmModel.parseGlb(_glb(json)));
    }

    final ordered = runtime(childFirst: false);
    final reversed = runtime(childFirst: true);
    final orderedBinding = _FakeBinding();
    final reversedBinding = _FakeBinding();
    ordered.bind(orderedBinding);
    reversed.bind(reversedBinding);

    ordered.update(1.0);
    reversed.update(1.0);

    final orderedChild = orderedBinding.nodes[10]!.localTransform.storage;
    final reversedChild = reversedBinding.nodes[10]!.localTransform.storage;
    expect(orderedChild[0], lessThan(0.99));
    for (var index = 0; index < orderedChild.length; index++) {
      expect(
        reversedChild[index],
        closeTo(orderedChild[index], 0.000001),
        reason: 'matrix component $index depends on spring declaration order',
      );
    }
  });

  test('runtime SpringBone stiffness follows animated parent rotation', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'stiffness': 1.0,
              'gravityPower': 0.0,
              'dragForce': 1.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(0.0);
    runtime.motion.play(
      VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(rotation: [0.0, 0.0, math.sqrt1_2, math.sqrt1_2]),
        },
      ),
    );
    runtime.update(1.0);

    final transform = binding.nodes[1]!.localTransform.storage;
    expect(transform[0], closeTo(math.sqrt1_2, 0.0001));
    expect(transform[1], closeTo(-math.sqrt1_2, 0.0001));
    expect(transform[4], closeTo(math.sqrt1_2, 0.0001));
    expect(transform[5], closeTo(math.sqrt1_2, 0.0001));
  });

  test('runtime SpringBone solves output rotation in joint local space', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]
      ..['translation'] = [0.0, 0.0, 0.0]
      ..['rotation'] = [math.sqrt1_2, 0.0, 0.0, math.sqrt1_2];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [1.0, 0.0, 0.0],
              'dragForce': 1.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(1.0);

    final transform = binding.nodes[1]!.localTransform.storage;
    expect(transform[0], closeTo(math.sqrt1_2, 0.0001));
    expect(transform[1], closeTo(0.0, 0.0001));
    expect(transform[2], closeTo(-math.sqrt1_2, 0.0001));
    expect(transform[4], closeTo(math.sqrt1_2, 0.0001));
    expect(transform[5], closeTo(0.0, 0.0001));
    expect(transform[6], closeTo(math.sqrt1_2, 0.0001));
    expect(transform[8], closeTo(0.0, 0.0001));
    expect(transform[9], closeTo(-1.0, 0.0001));
    expect(transform[10], closeTo(0.0, 0.0001));
  });

  test('SpringBone caches node bindings and resets when binding changes', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [1.0, 0.0, 0.0],
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final controller = VrmSpringBoneController(VrmModel.parseGlb(_glb(json)));
    final firstBinding = _FakeBinding();
    final secondBinding = _FakeBinding();

    controller.applyTo(firstBinding, 1.0);
    final initializedLookups = firstBinding.nodeLookups;
    controller.applyTo(firstBinding, 0.0);
    expect(firstBinding.nodeLookups, initializedLookups);

    controller.applyTo(secondBinding, 0.0);

    expect(secondBinding.nodeLookups, greaterThan(0));
    expect(secondBinding.nodes[1]!.localTransform.storage[4], 0.0);
    expect(secondBinding.nodes[1]!.localTransform.storage[5], 1.0);
  });

  test('runtime SpringBone can reset after teleport', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [1.0, 0.0, 0.0],
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(1.0);
    expect(binding.nodes[1]!.localTransform.storage[4], greaterThan(0.0));

    runtime.resetSpringBones();
    runtime.update(0.0);

    expect(binding.nodes[1]!.localTransform.storage[4], 0.0);
    expect(binding.nodes[1]!.localTransform.storage[5], 1.0);
  });

  test('runtime skips unsupported SpringBone spec versions', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '0.9',
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [1.0, 0.0, 0.0],
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final model = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    ).asset!;
    final runtime = VrmRuntime(model);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(1.0);

    expect(binding.nodes[1]!.localTransform.storage[4], 0.0);
    expect(binding.nodes[1]!.localTransform.storage[5], 1.0);
  });

  test('runtime skips invalid SpringBone joint order', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'joints': [
            {
              'node': 2,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [1.0, 0.0, 0.0],
              'dragForce': 0.0,
            },
            {'node': 1},
          ],
        },
      ],
    };
    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );
    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(1.0);

    expect(
      result.validation.errors.map((d) => d.code),
      contains('springBone.invalidJointOrder'),
    );
    expect(binding.nodes[2]!.localTransform.storage[4], 0.0);
    expect(binding.nodes[2]!.localTransform.storage[5], 1.0);
  });

  test('runtime skips invalid SpringBone center', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'center': 2,
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [1.0, 0.0, 0.0],
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );
    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(1.0);

    expect(
      result.validation.errors.map((d) => d.code),
      contains('springBone.invalidCenter'),
    );
    expect(binding.nodes[1]!.localTransform.storage[4], 0.0);
    expect(binding.nodes[1]!.localTransform.storage[5], 1.0);
  });

  test('runtime skips SpringBone center used by another chain', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[3]['translation'] = [0.0, 0.0, 0.0];
    nodes[4]['translation'] = [0.0, 1.0, 0.0];
    nodes[5]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'center': 3,
          'joints': [
            {
              'node': 4,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [1.0, 0.0, 0.0],
              'dragForce': 0.0,
            },
            {'node': 5},
          ],
        },
        {
          'joints': [
            {'node': 3},
            {'node': 4},
          ],
        },
      ],
    };
    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );
    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(1.0);

    expect(
      result.validation.errors.map((d) => d.code),
      contains('springBone.invalidCenter'),
    );
    expect(binding.nodes[4]!.localTransform.storage[4], 0.0);
    expect(binding.nodes[4]!.localTransform.storage[5], 1.0);
  });

  test('runtime skips invalid SpringBone joint parameters', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'hitRadius': -0.1,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [1.0, 'bad', 0.0],
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );
    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(1.0);

    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'springBone.invalidJointParameters',
        'springBone.invalidGravityDir',
      ]),
    );
    expect(binding.nodes[1]!.localTransform.storage[4], 0.0);
    expect(binding.nodes[1]!.localTransform.storage[5], 1.0);
  });

  test('runtime skips duplicate SpringBone joints', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [1.0, 0.0, 0.0],
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
        },
        {
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [0.0, 0.0, 1.0],
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );
    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(1.0);

    expect(
      result.validation.errors.map((d) => d.code),
      contains('springBone.duplicateJoint'),
    );
    expect(binding.nodes[1]!.localTransform.storage[4], 0.0);
    expect(binding.nodes[1]!.localTransform.storage[5], 1.0);
  });

  test('runtime SpringBone preserves matrix-form rest rotation', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]
      ..remove('translation')
      ..remove('rotation')
      ..remove('scale')
      ..['matrix'] = [
        0.0,
        1.0,
        0.0,
        0.0,
        -1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
      ];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 0.0,
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(0);

    expect(binding.nodes[1]!.localTransform.storage[0], closeTo(0.0, 0.0001));
    expect(binding.nodes[1]!.localTransform.storage[1], closeTo(1.0, 0.0001));
    expect(binding.nodes[1]!.localTransform.storage[4], closeTo(-1.0, 0.0001));
    expect(binding.nodes[1]!.localTransform.storage[5], closeTo(0.0, 0.0001));
  });

  test('fixed-step SpringBone preserves pose and drops backlog', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [1.0, 0.0, 0.0],
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.springBones.fixedTimeStepSeconds = 0.5;
    runtime.springBones.maxSubSteps = 1;
    runtime.update(0.5);

    expect(binding.nodes[1]!.localTransform.storage[4], lessThan(math.sqrt1_2));
    expect(binding.nodes[1]!.localTransform.storage[4], greaterThan(0.4));
    final firstStep = binding.nodes[1]!.localTransform;

    runtime.update(0.1);

    for (var index = 0; index < firstStep.storage.length; index++) {
      expect(
        binding.nodes[1]!.localTransform.storage[index],
        closeTo(firstStep.storage[index], 0.000001),
        reason: 'spring pose changed between fixed substeps at $index',
      );
    }

    runtime.update(0.9);
    final cappedStep = binding.nodes[1]!.localTransform;
    runtime.update(0.0);

    for (var index = 0; index < cappedStep.storage.length; index++) {
      expect(
        binding.nodes[1]!.localTransform.storage[index],
        closeTo(cappedStep.storage[index], 0.000001),
        reason: 'capped fixed-step backlog remained at $index',
      );
    }
  });

  test('runtime SpringBone fixed timestep ignores non-finite delta', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [1.0, 0.0, 0.0],
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.springBones.fixedTimeStepSeconds = 0.5;
    runtime.update(double.nan);
    runtime.update(0.5);

    expect(binding.nodes[1]!.localTransform.storage[4], greaterThan(0.4));
  });

  test('runtime SpringBone evaluates inertia relative to center node', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'center': 0,
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 0.0,
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.play(
      VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(translation: [10.0, 0.0, 0.0]),
        },
      ),
    );
    runtime.update(1.0);

    expect(binding.nodes[1]!.localTransform.storage[0], closeTo(1.0, 0.0001));
    expect(binding.nodes[1]!.localTransform.storage[4], closeTo(0.0, 0.0001));
    expect(binding.nodes[1]!.localTransform.storage[5], closeTo(1.0, 0.0001));
  });

  test(
    'runtime SpringBone evaluates world gravity in rotated center space',
    () {
      final json = _minimalVrmJson()
        ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
      final nodes = json['nodes']! as List<Map<String, Object?>>;
      nodes[1]['translation'] = [0.0, 0.0, 0.0];
      nodes[2]['translation'] = [0.0, 1.0, 0.0];
      (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
        'specVersion': '1.0',
        'springs': [
          {
            'center': 0,
            'joints': [
              {
                'node': 1,
                'stiffness': 0.0,
                'gravityPower': 1.0,
                'gravityDir': [0.0, 1.0, 0.0],
                'dragForce': 1.0,
              },
              {'node': 2},
            ],
          },
        ],
      };
      final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
      final binding = _FakeBinding();

      runtime.bind(binding);
      runtime.update(0.0);
      runtime.motion.play(
        VrmProgrammaticPose(
          nodePoses: {
            0: GltfNodePose(rotation: [0.0, 0.0, math.sqrt1_2, math.sqrt1_2]),
          },
        ),
      );
      runtime.update(1.0);

      final transform = binding.nodes[1]!.localTransform.storage;
      expect(transform[0], closeTo(math.sqrt1_2, 0.0001));
      expect(transform[1], closeTo(-math.sqrt1_2, 0.0001));
      expect(transform[4], closeTo(math.sqrt1_2, 0.0001));
      expect(transform[5], closeTo(math.sqrt1_2, 0.0001));
    },
  );

  test('SpringBone accounts for model-root translation', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 0.0,
              'dragForce': 1.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final controller = VrmSpringBoneController(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    controller.applyTo(binding, 0.0);
    binding.modelRootMotionTransform = _testTrs(
      translation: const [1.0, 0.0, 0.0],
    );
    controller.applyTo(binding, 0.0);

    final transform = binding.nodes[1]!.localTransform.storage;
    expect(transform[0], closeTo(math.sqrt1_2, 0.0001));
    expect(transform[1], closeTo(math.sqrt1_2, 0.0001));
    expect(transform[4], closeTo(-math.sqrt1_2, 0.0001));
    expect(transform[5], closeTo(math.sqrt1_2, 0.0001));
  });

  test('SpringBone evaluates gravity through model-root center rotation', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'springs': [
        {
          'center': 0,
          'joints': [
            {
              'node': 1,
              'stiffness': 0.0,
              'gravityPower': 1.0,
              'gravityDir': [0.0, 1.0, 0.0],
              'dragForce': 1.0,
            },
            {'node': 2},
          ],
        },
      ],
    };
    final controller = VrmSpringBoneController(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    controller.applyTo(binding, 0.0);
    binding.modelRootMotionTransform = _testTrs(
      rotation: [0.0, 0.0, math.sqrt1_2, math.sqrt1_2],
    );
    controller.applyTo(binding, 1.0);

    final transform = binding.nodes[1]!.localTransform.storage;
    expect(transform[0], closeTo(math.sqrt1_2, 0.0001));
    expect(transform[1], closeTo(-math.sqrt1_2, 0.0001));
    expect(transform[4], closeTo(math.sqrt1_2, 0.0001));
    expect(transform[5], closeTo(math.sqrt1_2, 0.0001));
  });

  test('runtime SpringBone sphere and capsule colliders push tail out', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    nodes.add({
      'name': 'capsuleCollider',
      'translation': [0.4, 1.0, 0.0],
    });
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'colliders': [
        {
          'node': 15,
          'shape': {
            'sphere': {
              'offset': [0.0, 0.0, 0.0],
              'radius': 0.5,
            },
          },
        },
        {
          'node': 15,
          'shape': {
            'capsule': {
              'offset': [0.0, -0.5, 0.0],
              'tail': [0.0, 0.5, 0.0],
              'radius': 0.6,
            },
          },
        },
      ],
      'colliderGroups': [
        {
          'colliders': [0, 1],
        },
      ],
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'hitRadius': 0.0,
              'stiffness': 0.0,
              'gravityPower': 0.0,
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
          'colliderGroups': [0],
        },
      ],
    };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(0.0);

    expect(binding.nodes[1]!.localTransform.storage[4], lessThan(0.0));
  });

  test('runtime SpringBone transforms collider local offsets', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    nodes.add({
      'name': 'rotatedCollider',
      'rotation': [0.0, 0.0, math.sin(math.pi / 4), math.cos(math.pi / 4)],
    });
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'colliders': [
        {
          'node': 15,
          'shape': {
            'sphere': {
              'offset': [0.8, 0.2, 0.0],
              'radius': 0.5,
            },
          },
        },
      ],
      'colliderGroups': [
        {
          'colliders': [0],
        },
      ],
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'hitRadius': 0.0,
              'stiffness': 0.0,
              'gravityPower': 0.0,
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
          'colliderGroups': [0],
        },
      ],
    };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(0.0);

    expect(binding.nodes[1]!.localTransform.storage[4], greaterThan(0.05));
  });

  test('runtime SpringBone follows animated collider ancestors', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    nodes[3]['children'] = [4, 15];
    nodes.add({
      'name': 'nestedCollider',
      'translation': [0.4, 1.0, 0.0],
    });
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'colliders': [
        {
          'node': 15,
          'shape': {
            'sphere': {
              'offset': [0.0, 0.0, 0.0],
              'radius': 0.5,
            },
          },
        },
      ],
      'colliderGroups': [
        {
          'colliders': [0],
        },
      ],
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'hitRadius': 0.0,
              'stiffness': 0.0,
              'gravityPower': 0.0,
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
          'colliderGroups': [0],
        },
      ],
    };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(0.0);
    expect(binding.nodes[1]!.localTransform.storage[4], lessThan(0.0));

    runtime.resetSpringBones();
    runtime.motion.play(
      VrmProgrammaticPose(
        nodePoses: {
          3: GltfNodePose(translation: [10.0, 0.0, 0.0]),
        },
      ),
    );
    runtime.update(0.0);

    expect(binding.nodes[1]!.localTransform.storage[4], closeTo(0.0, 0.0001));
    expect(binding.nodes[1]!.localTransform.storage[5], closeTo(1.0, 0.0001));
  });

  test('runtime skips invalid SpringBone colliders', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = ['VRMC_vrm', 'VRMC_springBone'];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    (json['extensions']! as Map<String, Object?>)['VRMC_springBone'] = {
      'specVersion': '1.0',
      'colliders': [
        {
          'node': 2,
          'shape': {
            'capsule': {
              'offset': [0.4, 0.0, 0.0],
              'radius': 0.6,
              'tail': [0.0, 'bad', 0.0],
            },
          },
        },
      ],
      'colliderGroups': [
        {
          'colliders': [0],
        },
      ],
      'springs': [
        {
          'joints': [
            {
              'node': 1,
              'hitRadius': 0.0,
              'stiffness': 0.0,
              'gravityPower': 0.0,
              'dragForce': 0.0,
            },
            {'node': 2},
          ],
          'colliderGroups': [0],
        },
      ],
    };
    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );
    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(0.0);

    expect(
      result.validation.errors.map((d) => d.code),
      contains('springBone.invalidColliderTail'),
    );
    expect(binding.nodes[1]!.localTransform.storage[4], 0.0);
    expect(binding.nodes[1]!.localTransform.storage[5], 1.0);
  });
}
