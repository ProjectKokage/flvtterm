part of '../flvtterm_test.dart';

void runtimeTests() {
  test('runtime unbind detaches scene binding', () {
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.update(0);
    runtime.unbind();
    runtime.update(1 / 60);

    expect(binding.began, 1);
    expect(binding.committed, 1);
  });

  test('runtime commits frame when update throws', () {
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _ThrowingBinding();

    runtime.bind(binding);

    expect(() => runtime.update(0), throwsStateError);
    expect(binding.began, 1);
    expect(binding.committed, 1);
  });

  test('runtime applies frame work in documented order', () {
    final model = VrmModel.tryParseGlb(
      _glb(
        _minimalVrmJson(
          meshes: const [
            {
              'primitives': [
                {
                  'attributes': {'POSITION': 0},
                  'targets': [
                    {'POSITION': 0},
                  ],
                },
              ],
              'weights': [0.2],
            },
          ],
          nodeMesh: const {2: 0},
          firstPerson: const {
            'meshAnnotations': [
              {'node': 2, 'type': 'firstPersonOnly'},
            ],
          },
          expressions: const {
            'preset': {
              'happy': {
                'morphTargetBinds': [
                  {'node': 2, 'index': 0, 'weight': 0.7},
                ],
              },
            },
          },
        ),
      ),
      validation: VrmValidationMode.permissive,
    ).asset!;
    final binding = _OrderBinding();
    final runtime = VrmRuntime(model)
      ..expressions.setPreset(VrmExpressionPreset.happy, 1);

    runtime.bind(binding);
    runtime.update(1 / 60);

    expect(binding.events.first, 'begin');
    expect(binding.events.last, 'commit');
    expect(
      binding.events.indexOf('node:0'),
      greaterThan(binding.events.indexOf('begin')),
    );
    expect(
      binding.events.indexOf('morph:2:0:0:0.2'),
      lessThan(binding.events.indexOf('morph:2:0:0:0.7')),
    );
    expect(
      binding.events.indexOf('morph:2:0:0:0.7'),
      lessThan(binding.events.indexOf('visible:2:false')),
    );
    expect(
      binding.events.indexOf('visible:2:false'),
      lessThan(binding.events.indexOf('commit')),
    );
  });

  test('runtime applies node constraints before spring bones', () {
    final json = _minimalVrmJson()
      ..['extensionsUsed'] = [
        'VRMC_vrm',
        'VRMC_node_constraint',
        'VRMC_springBone',
      ];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[1]['translation'] = [0.0, 0.0, 0.0];
    nodes[2]['translation'] = [0.0, 1.0, 0.0];
    nodes[2]['extensions'] = {
      'VRMC_node_constraint': {
        'specVersion': '1.0',
        'constraint': {
          'rotation': {'source': 3, 'weight': 1.0},
        },
      },
    };
    final sourceRotation = [
      0.0,
      0.0,
      math.sin(math.pi / 4),
      math.cos(math.pi / 4),
    ];
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
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)))
      ..motion.play(
        VrmProgrammaticPose(
          nodePoses: {3: GltfNodePose(rotation: sourceRotation)},
        ),
      );
    final binding = _ConstraintSpringOrderBinding();

    runtime.bind(binding);
    runtime.update(1);

    expect(binding.events, containsAllInOrder(['constraint', 'spring']));
  });
}

final class _ThrowingBinding implements VrmSceneBinding {
  var began = 0;
  var committed = 0;

  @override
  void beginFrame() {
    began++;
  }

  @override
  void commitFrame() {
    committed++;
  }

  @override
  VrmMaterialBinding materialByGltfIndex(int materialIndex) => _FakeMaterial();

  @override
  VrmMeshBinding? meshByNodeIndex(int nodeIndex) => null;

  @override
  VrmNodeBinding nodeByGltfIndex(int nodeIndex) => _ThrowingNode();
}

final class _ThrowingNode implements VrmNodeBinding {
  @override
  String? get debugName => 'throwing';

  @override
  VrmMatrix4 get localTransform => VrmMatrix4.identity();

  @override
  set localTransform(VrmMatrix4 value) {
    throw StateError('node write failed');
  }

  @override
  VrmMatrix4 get worldTransform => VrmMatrix4.identity();
}

final class _OrderBinding implements VrmSceneBinding {
  final events = <String>[];
  final _nodes = <int, _OrderNode>{};
  final _meshes = <int, _OrderMesh>{};

  @override
  void beginFrame() {
    events.add('begin');
  }

  @override
  void commitFrame() {
    events.add('commit');
  }

  @override
  VrmMaterialBinding materialByGltfIndex(int materialIndex) => _FakeMaterial();

  @override
  VrmMeshBinding? meshByNodeIndex(int nodeIndex) =>
      _meshes.putIfAbsent(nodeIndex, () => _OrderMesh(nodeIndex, events));

  @override
  VrmNodeBinding nodeByGltfIndex(int nodeIndex) =>
      _nodes.putIfAbsent(nodeIndex, () => _OrderNode(nodeIndex, events));
}

final class _OrderNode implements VrmNodeBinding {
  _OrderNode(this.index, this.events);

  final int index;
  final List<String> events;
  VrmMatrix4 _localTransform = VrmMatrix4.identity();

  @override
  String? get debugName => 'node$index';

  @override
  VrmMatrix4 get localTransform => _localTransform;

  @override
  set localTransform(VrmMatrix4 value) {
    events.add('node:$index');
    _localTransform = value;
  }

  @override
  VrmMatrix4 get worldTransform => _localTransform;
}

final class _OrderMesh implements VrmMeshBinding {
  _OrderMesh(this.nodeIndex, this.events);

  final int nodeIndex;
  final List<String> events;

  @override
  void setMorphWeight({
    required int primitiveIndex,
    required int morphIndex,
    required double weight,
  }) {
    events.add('morph:$nodeIndex:$primitiveIndex:$morphIndex:$weight');
  }

  @override
  void setVisible(bool visible) {
    events.add('visible:$nodeIndex:$visible');
  }
}

final class _ConstraintSpringOrderBinding implements VrmSceneBinding {
  final events = <String>[];
  final _nodes = <int, _ConstraintSpringOrderNode>{};

  @override
  void beginFrame() {}

  @override
  void commitFrame() {}

  @override
  VrmMaterialBinding materialByGltfIndex(int materialIndex) => _FakeMaterial();

  @override
  VrmMeshBinding? meshByNodeIndex(int nodeIndex) => null;

  @override
  VrmNodeBinding nodeByGltfIndex(int nodeIndex) => _nodes.putIfAbsent(
    nodeIndex,
    () => _ConstraintSpringOrderNode(nodeIndex, events),
  );
}

final class _ConstraintSpringOrderNode implements VrmNodeBinding {
  _ConstraintSpringOrderNode(this.index, this.events);

  final int index;
  final List<String> events;
  VrmMatrix4 _localTransform = VrmMatrix4.identity();

  @override
  String? get debugName => 'node$index';

  @override
  VrmMatrix4 get localTransform => _localTransform;

  @override
  set localTransform(VrmMatrix4 value) {
    if (index == 2 &&
        _closeToZero(value.storage[0]) &&
        _closeToOne(value.storage[1])) {
      events.add('constraint');
    }
    if (index == 1 && value.storage[4] > 0.5 && value.storage[5] > 0.5) {
      events.add('spring');
    }
    _localTransform = value;
  }

  @override
  VrmMatrix4 get worldTransform => _localTransform;
}

bool _closeToZero(double value) => value.abs() < 0.0001;

bool _closeToOne(double value) => (value - 1).abs() < 0.0001;
