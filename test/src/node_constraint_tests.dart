part of '../flvtterm_test.dart';

Map<String, Object?> _minimalConstraintVrmJson() {
  final json = _minimalVrmJson();
  (json['extensionsUsed']! as List<Object?>).add('VRMC_node_constraint');
  return json;
}

void nodeConstraintTests() {
  test('parses node constraint metadata from glTF nodes', () {
    final json = _minimalConstraintVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[2]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'extras': {
          'tags': ['source'],
        },
        'constraint': {
          'roll': {'source': 1, 'rollAxis': 'Y', 'weight': 0.25},
        },
      },
    };
    final model = VrmModel.parseGlb(_glb(json));
    final constraint = model.gltf.nodes[2].nodeConstraint!;

    expect(constraint.kind, VrmNodeConstraintKind.roll);
    expect(constraint.source, 1);
    expect(constraint.rollAxis, VrmNodeConstraintRollAxis.y);
    expect(constraint.weight, 0.25);
    final rawExtras = constraint.raw['extras']! as Map<String, Object?>;
    final rawTags = rawExtras['tags']! as List<Object?>;
    expect(rawTags, ['source']);
    expect(() => rawExtras['other'] = true, throwsUnsupportedError);
    expect(() => rawTags.add('copy'), throwsUnsupportedError);
    expect(() => constraint.raw['extra'] = true, throwsUnsupportedError);
  });

  test('reports invalid node constraints in permissive mode', () {
    final json = _minimalConstraintVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 2, 'weight': 1.2},
        },
      },
    };
    nodes[2]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 1},
        },
      },
    };
    nodes[3]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '0.9',
        'constraint': {
          'roll': {'source': 3, 'rollAxis': 'Bad'},
          'aim': {'source': 99, 'aimAxis': 'Sideways'},
        },
      },
    };
    nodes[4]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'aim': {'source': 1, 'aimAxis': 'Sideways', 'weight': 'bad'},
        },
      },
    };
    nodes[5]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 'bad'},
        },
      },
    };
    nodes[6]['extensions'] = {'VRMC_node_constraint': 'bad'};
    nodes[7]['extensions'] = {
      'VRMC_node_constraint': {'specVersion': '1.0', 'constraint': 'bad'},
    };
    nodes[8]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {'rotation': 'bad'},
      },
    };
    nodes[9]['extensions'] = {'VRMC_node_constraint': null};

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'constraint.invalidWeight',
        'constraint.cycle',
        'constraint.unsupportedSpecVersion',
        'constraint.invalidKindCount',
        'constraint.selfSource',
        'constraint.invalidSource',
        'constraint.invalidRollAxis',
        'constraint.invalidAimAxis',
        'constraint.invalidExtensionObject',
        'constraint.invalidConstraintObject',
        'constraint.invalidKindObject',
      ]),
    );
    expect(
      result.validation.errors.any(
        (d) => d.code == 'constraint.invalidWeight' && d.gltfNodeIndex == 4,
      ),
      isTrue,
    );

    Iterable<String?> pathsFor(String code) => result.validation.errors
        .where((diagnostic) => diagnostic.code == code)
        .map((diagnostic) => diagnostic.jsonPath);

    expect(
      pathsFor('constraint.invalidWeight'),
      contains(
        r'$.nodes[4].extensions.VRMC_node_constraint.constraint.aim.weight',
      ),
    );
    expect(
      pathsFor('constraint.cycle'),
      contains(r'$.nodes[1].extensions.VRMC_node_constraint.constraint'),
    );
    expect(
      pathsFor('constraint.unsupportedSpecVersion'),
      contains(r'$.nodes[3].extensions.VRMC_node_constraint.specVersion'),
    );
    expect(
      pathsFor('constraint.invalidKindCount'),
      contains(r'$.nodes[3].extensions.VRMC_node_constraint.constraint'),
    );
    expect(
      pathsFor('constraint.selfSource'),
      contains(
        r'$.nodes[3].extensions.VRMC_node_constraint.constraint.roll.source',
      ),
    );
    expect(
      pathsFor('constraint.invalidSource'),
      contains(
        r'$.nodes[5].extensions.VRMC_node_constraint.constraint.rotation.source',
      ),
    );
    expect(
      pathsFor('constraint.invalidRollAxis'),
      contains(
        r'$.nodes[3].extensions.VRMC_node_constraint.constraint.roll.rollAxis',
      ),
    );
    expect(
      pathsFor('constraint.invalidAimAxis'),
      contains(
        r'$.nodes[4].extensions.VRMC_node_constraint.constraint.aim.aimAxis',
      ),
    );
    expect(
      pathsFor('constraint.invalidExtensionObject'),
      containsAll([
        r'$.nodes[6].extensions.VRMC_node_constraint',
        r'$.nodes[9].extensions.VRMC_node_constraint',
      ]),
    );
    expect(
      pathsFor('constraint.invalidConstraintObject'),
      contains(r'$.nodes[7].extensions.VRMC_node_constraint.constraint'),
    );
    expect(
      pathsFor('constraint.invalidKindObject'),
      contains(
        r'$.nodes[8].extensions.VRMC_node_constraint.constraint.rotation',
      ),
    );
  });

  test('reports missing node constraint specVersion', () {
    final json = _minimalConstraintVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[2]['extensions'] = {'VRMC_node_constraint': <String, Object?>{}};

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('constraint.missingSpecVersion'),
    );
    expect(
      result.validation.errors.map((d) => d.code),
      isNot(contains('constraint.unsupportedSpecVersion')),
    );
  });

  test('reports missing node constraint payload', () {
    final json = _minimalConstraintVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[2]['extensions'] = {
      'VRMC_node_constraint': {'specVersion': '1.0'},
    };

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('constraint.missingConstraint'),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      contains(r'$.nodes[2].extensions.VRMC_node_constraint.constraint'),
    );
  });

  test('runtime rotation constraint copies source local rotation', () {
    final json = _minimalConstraintVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[2]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 1, 'weight': 1.0},
        },
      },
    };
    final model = VrmModel.parseGlb(_glb(json));
    final binding = _FakeBinding();
    binding.nodeByGltfIndex(1).localTransform = _testTrs(
      rotation: [0.0, 0.0, math.sin(math.pi / 4), math.cos(math.pi / 4)],
    );

    VrmNodeConstraintController(model).applyTo(binding);

    expect(binding.nodes[2]!.localTransform.storage[0], closeTo(0.0, 0.0001));
    expect(binding.nodes[2]!.localTransform.storage[1], closeTo(1.0, 0.0001));
  });

  test('runtime evaluates source constraints before dependents', () {
    final json = _minimalConstraintVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 2, 'weight': 1.0},
        },
      },
    };
    nodes[2]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 3, 'weight': 1.0},
        },
      },
    };
    final model = VrmModel.parseGlb(_glb(json));
    final binding = _FakeBinding();
    binding.nodeByGltfIndex(3).localTransform = _testTrs(
      rotation: [0.0, 0.0, math.sin(math.pi / 4), math.cos(math.pi / 4)],
    );

    VrmNodeConstraintController(model).applyTo(binding);

    expect(binding.nodes[1]!.localTransform.storage[0], closeTo(0.0, 0.0001));
    expect(binding.nodes[1]!.localTransform.storage[1], closeTo(1.0, 0.0001));
  });

  test('runtime skips invalid multi-kind node constraints', () {
    final json = _minimalConstraintVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[2]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 1, 'weight': 1.0},
          'roll': {'source': 1, 'rollAxis': 'Z', 'weight': 1.0},
        },
      },
    };
    final model = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    ).asset!;
    final binding = _FakeBinding();
    binding.nodeByGltfIndex(1).localTransform = _testTrs(
      rotation: [0.0, 0.0, math.sin(math.pi / 4), math.cos(math.pi / 4)],
    );

    VrmNodeConstraintController(model).applyTo(binding);

    expect(binding.nodes[2], isNull);
  });

  test('runtime skips invalid node constraint weights', () {
    final json = _minimalConstraintVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[2]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 1, 'weight': 1.2},
        },
      },
    };
    nodes[3]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 1, 'weight': 'bad'},
        },
      },
    };
    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );
    final binding = _FakeBinding();
    binding.nodeByGltfIndex(1).localTransform = _testTrs(
      rotation: [0.0, 0.0, math.sin(math.pi / 4), math.cos(math.pi / 4)],
    );

    VrmNodeConstraintController(result.asset!).applyTo(binding);

    expect(
      result.validation.errors
          .where((d) => d.code == 'constraint.invalidWeight')
          .length,
      2,
    );
    expect(binding.nodes[2], isNull);
    expect(binding.nodes[3], isNull);
  });

  test('runtime skips self-source and cyclic node constraints', () {
    final json = _minimalConstraintVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 2, 'weight': 1.0},
        },
      },
    };
    nodes[2]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 1, 'weight': 1.0},
        },
      },
    };
    nodes[3]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 3, 'weight': 1.0},
        },
      },
    };
    final model = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    ).asset!;
    final binding = _FakeBinding();
    binding.nodeByGltfIndex(1);
    binding.nodeByGltfIndex(2);
    binding.nodeByGltfIndex(3);

    VrmNodeConstraintController(model).applyTo(binding);

    expect(
      binding.nodes[1]!.localTransform.storage,
      VrmMatrix4.identity().storage,
    );
    expect(
      binding.nodes[2]!.localTransform.storage,
      VrmMatrix4.identity().storage,
    );
    expect(
      binding.nodes[3]!.localTransform.storage,
      VrmMatrix4.identity().storage,
    );
  });

  test('runtime constraint weight blends from destination rest rotation', () {
    final json = _minimalConstraintVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[2]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 1, 'weight': 0.0},
        },
      },
    };
    final model = VrmModel.parseGlb(_glb(json));
    final binding = _FakeBinding();
    final quarterTurn = [
      0.0,
      0.0,
      math.sin(math.pi / 4),
      math.cos(math.pi / 4),
    ];
    binding.nodeByGltfIndex(1).localTransform = _testTrs(rotation: quarterTurn);
    binding.nodeByGltfIndex(2).localTransform = _testTrs(rotation: quarterTurn);

    VrmNodeConstraintController(model).applyTo(binding);

    expect(binding.nodes[2]!.localTransform.storage[0], closeTo(1.0, 0.0001));
    expect(binding.nodes[2]!.localTransform.storage[1], closeTo(0.0, 0.0001));
  });

  test('runtime aim constraint rotates destination axis toward source', () {
    final json = _minimalConstraintVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[2]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'aim': {'source': 1, 'aimAxis': 'PositiveX', 'weight': 1.0},
        },
      },
    };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();
    binding.nodeByGltfIndex(1);
    binding.nodeByGltfIndex(2);
    binding.nodes[1]!.worldTransform = _testTrs(translation: [0.0, 0.0, 1.0]);
    binding.nodes[2]!.worldTransform = _testTrs();

    runtime.bind(binding);
    runtime.update(0);

    expect(binding.nodes[2]!.localTransform.storage[0], closeTo(0.0, 0.0001));
    expect(binding.nodes[2]!.localTransform.storage[2], closeTo(1.0, 0.0001));
  });

  test('runtime aim constraint accounts for destination parent rotation', () {
    final json = _minimalConstraintVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[2]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'aim': {'source': 3, 'aimAxis': 'PositiveX', 'weight': 1.0},
        },
      },
    };
    final model = VrmModel.parseGlb(_glb(json));
    final binding = _FakeBinding();
    final parentRotation = [
      0.0,
      math.sin(math.pi / 4),
      0.0,
      math.cos(math.pi / 4),
    ];
    binding.nodeByGltfIndex(1);
    binding.nodeByGltfIndex(2);
    binding.nodeByGltfIndex(3);
    binding.nodes[1]!.worldTransform = _testTrs(rotation: parentRotation);
    binding.nodes[2]!.worldTransform = _testTrs(rotation: parentRotation);
    binding.nodes[3]!.worldTransform = _testTrs(translation: [1.0, 0.0, 0.0]);

    VrmNodeConstraintController(model).applyTo(binding);

    expect(binding.nodes[2]!.localTransform.storage[0], closeTo(0.0, 0.0001));
    expect(binding.nodes[2]!.localTransform.storage[2], closeTo(1.0, 0.0001));
  });

  test('runtime roll constraint transfers only configured axis twist', () {
    final json = _minimalConstraintVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[2]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'roll': {'source': 1, 'rollAxis': 'Z', 'weight': 1.0},
        },
      },
    };
    final model = VrmModel.parseGlb(_glb(json));
    final binding = _FakeBinding();
    binding.nodeByGltfIndex(1).localTransform = _testTrs(
      rotation: [0.0, 0.0, math.sin(math.pi / 4), math.cos(math.pi / 4)],
    );

    VrmNodeConstraintController(model).applyTo(binding);

    expect(binding.nodes[2]!.localTransform.storage[0], closeTo(0.0, 0.0001));
    expect(binding.nodes[2]!.localTransform.storage[1], closeTo(1.0, 0.0001));
  });

  test(
    'runtime roll constraint evaluates through destination rest rotation',
    () {
      final json = _minimalConstraintVrmJson();
      final nodes = json['nodes']! as List<Map<String, Object?>>;
      final quarterTurnX = [
        math.sin(math.pi / 4),
        0.0,
        0.0,
        math.cos(math.pi / 4),
      ];
      final quarterTurnY = [
        0.0,
        math.sin(math.pi / 4),
        0.0,
        math.cos(math.pi / 4),
      ];
      nodes[2]
        ..['rotation'] = quarterTurnY
        ..['extensions'] = {
          'VRMC_node_constraint': {
            'specVersion': '1.0',
            'constraint': {
              'roll': {'source': 1, 'rollAxis': 'Z', 'weight': 1.0},
            },
          },
        };
      final model = VrmModel.parseGlb(_glb(json));
      final binding = _FakeBinding();
      binding.nodeByGltfIndex(1).localTransform = _testTrs(
        rotation: quarterTurnX,
      );

      VrmNodeConstraintController(model).applyTo(binding);

      expect(binding.nodes[2]!.localTransform.storage[1], closeTo(1.0, 0.0001));
      expect(binding.nodes[2]!.localTransform.storage[5], closeTo(0.0, 0.0001));
    },
  );
}
