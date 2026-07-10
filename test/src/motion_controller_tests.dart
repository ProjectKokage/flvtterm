part of '../flvtterm_test.dart';

void motionControllerTests() {
  test('runtime motion applies embedded glTF node animation', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.play(0);
    runtime.update(0.5);

    expect(binding.nodes[0]!.localTransform.storage[12], 1.0);
    expect(binding.nodes[0]!.localTransform.storage[13], 0.0);
    expect(runtime.motion.timeSeconds, 0.5);
    expect(runtime.motion.normalizedProgress, 0.5);
    expect(runtime.motion.isPlaying, isTrue);

    runtime.update(1.0);
    expect(runtime.motion.isPlaying, isFalse);
    expect(runtime.motion.timeSeconds, 1.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 2.0);

    runtime.motion.stop();
    runtime.update(0);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
  });

  test('runtime motion accepts Duration start positions', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.play(0, startTime: const Duration(milliseconds: 250));
    runtime.update(0);

    expect(runtime.motion.timeSeconds, 0.25);
    expect(runtime.motion.position, const Duration(milliseconds: 250));
    expect(runtime.motion.duration, const Duration(seconds: 1));
    expect(binding.nodes[0]!.localTransform.storage[12], 1.0);
  });

  test('runtime motion reports missing embedded glTF animations clearly', () {
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));

    expect(
      () => runtime.motion.playEmbeddedGltfAnimation(0),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'VRM model does not contain embedded glTF animations.',
        ),
      ),
    );
  });

  test('runtime motion skips malformed glTF animation output count', () {
    final binary = _floats([
      0.0, 1.0, // input times
      0.0, 0.0, 0.0, // key 0 translation
      2.0, 0.0, 0.0, // key 1 translation
      4.0, 0.0, 0.0, // extra malformed key
    ]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 36],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];

    final result = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );
    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidAnimationOutputCount'),
    );

    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(0);
    runtime.update(0.5);

    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[13], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[14], 0.0);
  });

  test('runtime motion skips invalid glTF animation output accessor', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'SCALAR'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];

    final result = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );
    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidAnimationOutputAccessor'),
    );

    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(0);
    runtime.update(0.5);

    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[13], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[14], 0.0);
  });

  test('runtime motion skips invalid glTF animation input accessor', () {
    final binary = _floats([
      0.0, 1.0, 2.0, 3.0, 4.0, 5.0, // misdeclared input times
      0.0, 0.0, 0.0, // key 0 translation
      2.0, 0.0, 0.0, // key 1 translation
      4.0, 0.0, 0.0, // key 2 translation
      6.0, 0.0, 0.0, // key 3 translation
      8.0, 0.0, 0.0, // key 4 translation
      10.0, 0.0, 0.0, // key 5 translation
    ]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 24],
            [24, 72],
          ],
          accessorTypes: ['VEC3', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];

    final result = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );
    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidAnimationInputAccessor'),
    );
    expect(GltfAnimationEvaluator(result.asset!.gltf).duration(0), 0.0);

    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(0);
    runtime.update(0.5);

    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[13], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[14], 0.0);
  });

  test('runtime motion skips invalid glTF animation interpolation', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1, 'interpolation': 'BOUNCE'},
          ],
        },
      ];

    final result = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );
    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidAnimationInterpolation'),
    );

    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(0);
    runtime.update(0.5);

    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[13], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[14], 0.0);
  });

  test('runtime motion skips invalid glTF animation input times', () {
    final binary = _floats([-1.0, 1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];

    final result = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );
    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidAnimationInputTimes'),
    );
    expect(GltfAnimationEvaluator(result.asset!.gltf).duration(0), 0.0);

    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(0);
    runtime.update(1.0);

    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[13], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[14], 0.0);
  });

  test('runtime motion skips non-finite glTF animation output values', () {
    final binary = Uint8List(32);
    final data = ByteData.sublistView(binary);
    data.setFloat32(0, 0.0, Endian.little);
    data.setFloat32(4, 1.0, Endian.little);
    data.setFloat32(8, 0.0, Endian.little);
    data.setFloat32(12, 0.0, Endian.little);
    data.setFloat32(16, 0.0, Endian.little);
    data.setFloat32(20, double.infinity, Endian.little);
    data.setFloat32(24, 0.0, Endian.little);
    data.setFloat32(28, 0.0, Endian.little);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];

    final result = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );
    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidAnimationOutputValue'),
    );

    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(0);
    runtime.update(1.0);

    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[13], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[14], 0.0);
  });

  test('runtime motion skips animation input accessors without bounds', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    (json['accessors']! as List<Object?>).first as Map<String, Object?>
      ..remove('min')
      ..remove('max');

    final result = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );
    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.missingAnimationInputAccessorBounds'),
    );
    expect(GltfAnimationEvaluator(result.asset!.gltf).duration(0), 0.0);

    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(0);
    runtime.update(0.5);

    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
  });

  test(
    'runtime motion priority keeps lower-priority sources from replacing',
    () {
      final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0]);
      final json = _minimalVrmJson()
        ..addAll(
          _animationStorageJson(
            binary.length,
            [
              [0, 8],
              [8, 24],
            ],
            accessorTypes: ['SCALAR', 'VEC3'],
          ),
        )
        ..['animations'] = [
          {
            'channels': [
              {
                'sampler': 0,
                'target': {'node': 0, 'path': 'translation'},
              },
            ],
            'samplers': [
              {'input': 0, 'output': 1},
            ],
          },
        ];
      final runtime = VrmRuntime(
        VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
      );
      final binding = _FakeBinding();
      final pose = VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(translation: [7.0, 0.0, 0.0]),
        },
      );

      runtime.bind(binding);
      runtime.motion.playEmbeddedGltfAnimation(0, priority: 10);
      runtime.update(0.5);
      expect(binding.nodes[0]!.localTransform.storage[12], 1.0);

      runtime.motion.playProgrammaticPose(pose, priority: 5);
      runtime.update(0);
      expect(binding.nodes[0]!.localTransform.storage[12], 1.0);

      expect(
        () => runtime.motion.playEmbeddedGltfAnimation(99, priority: 5),
        returnsNormally,
      );
      runtime.update(0);
      expect(binding.nodes[0]!.localTransform.storage[12], 1.0);

      runtime.motion.playProgrammaticPose(pose, priority: 11);
      runtime.update(0);
      expect(binding.nodes[0]!.localTransform.storage[12], 7.0);
    },
  );

  test('runtime motion masks limit animated nodes', () {
    final binary = _floats([
      0.0, 1.0, // input times
      0.0, 0.0, 0.0, 2.0, 0.0, 0.0, // node 0 translation
      0.0, 0.0, 0.0, 4.0, 0.0, 0.0, // node 1 translation
    ]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
            [32, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
            {
              'sampler': 1,
              'target': {'node': 1, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
            {'input': 0, 'output': 2},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.addAdditiveLayer(
      VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(translation: [1.0, 0.0, 0.0]),
          1: GltfNodePose(translation: [1.0, 0.0, 0.0]),
        },
      ),
      nodeMask: {1},
    );
    runtime.motion.playEmbeddedGltfAnimation(0, nodeMask: {1});
    runtime.update(0.5);

    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
    expect(binding.nodes[1]!.localTransform.storage[12], 3.0);

    final humanoidRuntime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final humanoidBinding = _FakeBinding();
    humanoidRuntime.bind(humanoidBinding);
    humanoidRuntime.motion.playEmbeddedGltfAnimation(
      0,
      humanoidMask: {VrmHumanoidBone.spine},
    );
    humanoidRuntime.update(0.5);

    expect(humanoidBinding.nodes[0]!.localTransform.storage[12], 0.0);
    expect(humanoidBinding.nodes[1]!.localTransform.storage[12], 2.0);
  });

  test('runtime motion fades in generic glTF animation output', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(
      0,
      fadeIn: const Duration(seconds: 1),
    );
    runtime.update(0.5);

    expect(binding.nodes[0]!.localTransform.storage[12], 1.0);
  });

  test('runtime motion crossfades from the current clip pose', () {
    final binary = _floats([
      0.0, 1.0, // input times
      0.0, 0.0, 0.0, 4.0, 0.0, 0.0, // clip 0 translation
      0.0, 0.0, 0.0, -4.0, 0.0, 0.0, // clip 1 translation
    ]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
            [32, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 2},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(0);
    runtime.update(1.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 4.0);

    runtime.motion.playEmbeddedGltfAnimation(
      1,
      fadeIn: const Duration(seconds: 1),
    );
    runtime.update(0.5);

    expect(binding.nodes[0]!.localTransform.storage[12], 1.0);
  });

  test('runtime motion crossfades cleanly between different node masks', () {
    VrmProgrammaticPose pose(
      double node0,
      double node1,
      double morph0,
      double morph1,
    ) => VrmProgrammaticPose(
      nodePoses: {
        0: GltfNodePose(translation: [node0, 0.0, 0.0]),
        1: GltfNodePose(translation: [node1, 0.0, 0.0]),
      },
      morphWeights: {
        0: [morph0],
        1: [morph1],
      },
    );

    final json = _minimalVrmJson(
      meshes: [
        for (var i = 0; i < 2; i++)
          {
            'primitives': [
              {
                'attributes': <String, Object?>{},
                'targets': [<String, Object?>{}],
              },
            ],
          },
      ],
      nodeMesh: {0: 0, 1: 1},
    );
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playProgrammaticPose(
      pose(10.0, 20.0, 0.8, 0.6),
      nodeMask: {0},
    );
    runtime.update(0.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 10.0);
    expect(binding.nodes[1]!.localTransform.storage[12], 0.0);
    expect(binding.meshes[0]!.weights['0:0'], 0.8);
    expect(binding.meshes[1]!.weights['0:0'], 0.0);

    runtime.motion.playProgrammaticPose(
      pose(30.0, 40.0, 0.2, 1.0),
      nodeMask: {1},
      fadeIn: const Duration(seconds: 1),
    );
    runtime.update(0.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 10.0);
    expect(binding.nodes[1]!.localTransform.storage[12], 0.0);
    expect(binding.meshes[0]!.weights['0:0'], 0.8);
    expect(binding.meshes[1]!.weights['0:0'], 0.0);

    runtime.update(0.5);
    expect(binding.nodes[0]!.localTransform.storage[12], 5.0);
    expect(binding.nodes[1]!.localTransform.storage[12], 20.0);
    expect(binding.meshes[0]!.weights['0:0'], 0.4);
    expect(binding.meshes[1]!.weights['0:0'], 0.5);

    runtime.update(0.5);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
    expect(binding.nodes[1]!.localTransform.storage[12], 40.0);
    expect(binding.meshes[0]!.weights['0:0'], 0.0);
    expect(binding.meshes[1]!.weights['0:0'], 1.0);
  });

  test('runtime motion preserves pose when a crossfade is interrupted', () {
    VrmProgrammaticPose pose(double x) => VrmProgrammaticPose(
      nodePoses: {
        0: GltfNodePose(translation: [x, 0.0, 0.0]),
      },
    );

    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playProgrammaticPose(pose(0.0));
    runtime.update(0.0);
    runtime.motion.playProgrammaticPose(
      pose(10.0),
      fadeIn: const Duration(seconds: 2),
    );
    runtime.update(1.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 5.0);

    runtime.motion.playProgrammaticPose(
      pose(20.0),
      fadeIn: const Duration(seconds: 2),
    );
    runtime.update(0.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 5.0);

    runtime.update(1.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 12.5);
  });

  test('interrupted crossfade preserves morph, expression, and LookAt', () {
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {
              'attributes': <String, Object?>{},
              'targets': [
                <String, Object?>{},
                <String, Object?>{},
                <String, Object?>{},
              ],
            },
          ],
        },
      ],
      nodeMesh: {0: 0},
      expressions: {
        'preset': {
          'happy': {
            'morphTargetBinds': [
              {'node': 0, 'index': 1, 'weight': 1.0},
            ],
          },
          for (final name in ['lookLeft', 'lookRight'])
            name: {
              'morphTargetBinds': [
                {'node': 0, 'index': 2, 'weight': 1.0},
              ],
            },
        },
      },
    );
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    vrm['lookAt'] = _lookAtJson(type: 'expression');

    VrmProgrammaticPose pose(double morph, double happy, double yaw) =>
        VrmProgrammaticPose(
          morphWeights: {
            0: [morph],
          },
          expressionWeights: {'happy': happy},
          lookAtYawDegrees: yaw,
          lookAtPitchDegrees: 0.0,
        );

    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playProgrammaticPose(pose(0.0, 0.0, 0.0));
    runtime.update(0.0);
    runtime.motion.playProgrammaticPose(
      pose(0.8, 0.6, 60.0),
      fadeIn: const Duration(seconds: 2),
    );
    runtime.update(1.0);
    final before = Map<String, double>.of(binding.meshes[0]!.weights);
    expect(before['0:0'], closeTo(0.4, 0.0001));
    expect(before['0:1'], closeTo(0.3, 0.0001));
    expect(before['0:2'], greaterThan(0.0));

    runtime.motion.playProgrammaticPose(
      pose(0.2, 0.1, -60.0),
      fadeIn: const Duration(seconds: 2),
    );
    runtime.update(0.0);

    for (final entry in before.entries) {
      expect(
        binding.meshes[0]!.weights[entry.key],
        closeTo(entry.value, 0.0001),
      );
    }

    runtime.motion.stop(fadeOut: const Duration(seconds: 2));
    runtime.update(1.0);

    for (final entry in before.entries) {
      expect(
        binding.meshes[0]!.weights[entry.key],
        closeTo(entry.value * 0.5, 0.0001),
      );
    }
  });

  test('runtime motion fades the current crossfade pose to rest', () {
    VrmProgrammaticPose pose(double x) => VrmProgrammaticPose(
      nodePoses: {
        0: GltfNodePose(translation: [x, 0.0, 0.0]),
      },
    );

    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playProgrammaticPose(pose(4.0));
    runtime.update(0.0);
    runtime.motion.playProgrammaticPose(
      pose(10.0),
      fadeIn: const Duration(seconds: 2),
    );
    runtime.update(1.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 7.0);

    runtime.motion.stop(fadeOut: const Duration(seconds: 2));
    runtime.update(1.0);

    expect(binding.nodes[0]!.localTransform.storage[12], 3.5);

    runtime.motion.playProgrammaticPose(
      pose(20.0),
      fadeIn: const Duration(seconds: 2),
    );
    runtime.update(0.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 3.5);

    runtime.update(1.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 11.75);
  });

  test('runtime motion fades out before clearing active clip', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(0);
    runtime.update(0.5);
    runtime.motion.stop(fadeOut: const Duration(seconds: 1));
    runtime.update(0.5);

    expect(runtime.motion.isPlaying, isTrue);
    expect(binding.nodes[0]!.localTransform.storage[12], 1.0);

    runtime.update(0.5);
    expect(runtime.motion.isPlaying, isFalse);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
  });

  test('motion controller clears fade-out during standalone update', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final controller = VrmMotionController(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );

    controller.playEmbeddedGltfAnimation(0);
    controller.stop(fadeOut: const Duration(seconds: 1));
    controller.update(0.5);

    expect(controller.isPlaying, isTrue);

    controller.update(0.5);
    expect(controller.isPlaying, isFalse);
  });

  test('runtime motion supports reverse playback and clamps to start', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();
    var completed = 0;

    runtime.bind(binding);
    runtime.motion.onCompleted = () {
      completed++;
    };
    runtime.motion.playEmbeddedGltfAnimation(0, speed: -1, startTimeSeconds: 1);
    runtime.update(0.25);
    expect(runtime.motion.timeSeconds, 0.75);
    expect(binding.nodes[0]!.localTransform.storage[12], 3.0);
    expect(completed, 0);

    runtime.update(1.0);
    expect(runtime.motion.isPlaying, isFalse);
    expect(runtime.motion.timeSeconds, 0.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
    expect(completed, 1);

    runtime.update(1.0);
    expect(completed, 1);
  });

  test('runtime motion loops reverse playback', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();
    var loops = 0;

    runtime.bind(binding);
    runtime.motion.onLooped = () {
      loops++;
    };
    runtime.motion.playEmbeddedGltfAnimation(
      0,
      loop: true,
      speed: -1,
      startTimeSeconds: 0.25,
    );
    runtime.update(0.5);

    expect(loops, 1);
    expect(runtime.motion.timeSeconds, closeTo(0.75, 0.0001));
    expect(binding.nodes[0]!.localTransform.storage[12], closeTo(3.0, 0.0001));
  });

  test('runtime motion completes when landing exactly on clip end', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();
    var completed = 0;

    runtime.bind(binding);
    runtime.motion.onCompleted = () {
      completed++;
    };
    runtime.motion.playEmbeddedGltfAnimation(0);
    runtime.update(1.0);

    expect(runtime.motion.isPlaying, isFalse);
    expect(runtime.motion.timeSeconds, 1.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 4.0);
    expect(completed, 1);
  });

  test('runtime motion supports zero playback speed', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(
      0,
      speed: 0,
      startTimeSeconds: 0.25,
    );
    runtime.update(1.0);

    expect(runtime.motion.isPlaying, isTrue);
    expect(runtime.motion.timeSeconds, 0.25);
    expect(binding.nodes[0]!.localTransform.storage[12], 1.0);
  });

  test('runtime motion changes playback speed while playing', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(0);
    runtime.update(0.25);
    runtime.motion.speed = 2;
    runtime.update(0.25);

    expect(runtime.motion.speed, 2.0);
    expect(runtime.motion.timeSeconds, 0.75);
    expect(binding.nodes[0]!.localTransform.storage[12], 3.0);

    runtime.motion.speed = -1;
    runtime.update(0.25);
    expect(runtime.motion.timeSeconds, 0.5);
    expect(binding.nodes[0]!.localTransform.storage[12], 2.0);
  });

  test('runtime motion ignores negative update delta', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(0, startTimeSeconds: 0.5);
    runtime.update(-1.0);

    expect(runtime.motion.timeSeconds, 0.5);
    expect(binding.nodes[0]!.localTransform.storage[12], 2.0);
  });

  test('runtime motion sanitizes non-finite time inputs', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(
      0,
      speed: double.nan,
      startTimeSeconds: double.nan,
    );
    runtime.update(double.nan);

    expect(runtime.motion.timeSeconds, 0.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);

    runtime.motion.speed = double.infinity;
    runtime.update(0.5);

    expect(runtime.motion.timeSeconds, 0.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
  });

  test('runtime motion applies additive programmatic translation', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();
    final additive = VrmProgrammaticPose(
      nodePoses: {
        0: GltfNodePose(translation: [1.0, 0.0, 0.0]),
      },
    );

    runtime.bind(binding);
    runtime.motion.setAdditiveProgrammaticPose(additive, weight: 0.5);
    runtime.motion.playEmbeddedGltfAnimation(0);
    runtime.update(0.5);
    expect(binding.nodes[0]!.localTransform.storage[12], 1.5);

    runtime.motion.stop();
    runtime.update(0);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.5);

    runtime.motion.clearAdditiveProgrammaticPose();
    runtime.update(0);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
  });

  test('runtime motion preserves an intentional identity override pose', () {
    final json = _minimalVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[0]
      ..['translation'] = [5.0, 0.0, 0.0]
      ..['rotation'] = [0.0, 0.0, math.sqrt1_2, math.sqrt1_2]
      ..['scale'] = [2.0, 2.0, 2.0];
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playProgrammaticPose(
      VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(
            translation: [0.0, 0.0, 0.0],
            rotation: [0.0, 0.0, 0.0, 1.0],
            scale: [1.0, 1.0, 1.0],
          ),
        },
      ),
    );
    runtime.motion.setAdditiveProgrammaticPose(
      VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(
            translation: [1.0, 0.0, 0.0],
            rotation: [0.0, 0.0, math.sqrt1_2, math.sqrt1_2],
            scale: [2.0, 2.0, 2.0],
          ),
        },
      ),
    );

    runtime.update(0);

    final transform = binding.nodes[0]!.localTransform.storage;
    expect(transform[0], closeTo(0.0, 0.000001));
    expect(transform[1], closeTo(2.0, 0.000001));
    expect(transform[4], closeTo(-2.0, 0.000001));
    expect(transform[5], closeTo(0.0, 0.000001));
    expect(transform[12], closeTo(1.0, 0.000001));
  });

  test('runtime motion stacks additive programmatic layers', () {
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {
              'attributes': <String, Object?>{},
              'targets': [<String, Object?>{}],
            },
          ],
        },
      ],
      nodeMesh: {0: 0},
    );
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.setAdditiveProgrammaticPose(
      VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(translation: [1.0, 0.0, 0.0]),
        },
        morphWeights: const {
          0: [0.2],
        },
      ),
    );
    runtime.motion.addAdditiveProgrammaticPose(
      VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(translation: [0.0, 2.0, 0.0]),
        },
        morphWeights: const {
          0: [0.4],
        },
      ),
      weight: 0.5,
    );
    runtime.update(0);

    expect(binding.nodes[0]!.localTransform.storage[12], 1.0);
    expect(binding.nodes[0]!.localTransform.storage[13], 1.0);
    expect(binding.meshes[0]!.weights['0:0'], closeTo(0.4, 0.0001));
  });

  test('runtime motion layers an embedded clip with an independent mask', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 1, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
    final runtime = VrmRuntime(
      VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
    );
    final binding = _FakeBinding();

    runtime.bind(binding);
    final layerId = runtime.motion.addAdditiveLayer(
      0,
      weight: 0.5,
      nodeMask: {1},
    );
    runtime.motion.playProgrammaticPose(
      VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(translation: [10.0, 0.0, 0.0]),
        },
      ),
      nodeMask: {0},
    );
    runtime.update(0.5);

    expect(runtime.motion.additiveLayerCount, 1);
    expect(binding.nodes[0]!.localTransform.storage[12], 10.0);
    expect(binding.nodes[1]!.localTransform.storage[12], 0.5);

    runtime.motion.pause();
    runtime.update(0.25);
    expect(binding.nodes[1]!.localTransform.storage[12], 0.5);

    runtime.motion.resume();
    runtime.update(0.25);
    expect(binding.nodes[1]!.localTransform.storage[12], 0.75);

    expect(runtime.motion.setAdditiveLayerWeight(layerId, 1.0), isTrue);
    expect(
      runtime.motion.seekAdditiveLayer(layerId, const Duration(seconds: 1)),
      isTrue,
    );
    runtime.update(0);
    expect(binding.nodes[1]!.localTransform.storage[12], 2.0);

    expect(runtime.motion.removeAdditiveLayer(layerId), isTrue);
    expect(runtime.motion.removeAdditiveLayer(layerId), isFalse);
    runtime.update(0);
    expect(runtime.motion.additiveLayerCount, 0);
    expect(binding.nodes[1]!.localTransform.storage[12], 0.0);
  });

  test('runtime motion layers external and procedural additive sources', () {
    final binary = _floats([0.0, 1.0, 5.0, 0.0, 0.0, 7.0, 0.0, 0.0]);
    final json = <String, Object?>{
      'asset': {'version': '2.0'},
      'nodes': [
        {
          'translation': [5.0, 0.0, 0.0],
        },
      ],
      ..._animationStorageJson(
        binary.length,
        [
          [0, 8],
          [8, 24],
        ],
        accessorTypes: ['SCALAR', 'VEC3'],
      ),
      'animations': [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ],
    };
    final external = GltfAsset.parse(bytes: _glb(json, binaryChunk: binary));
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();
    VrmProgrammaticPose procedural(double time) => VrmProgrammaticPose(
      nodePoses: {
        0: GltfNodePose(translation: [0.0, time, 0.0]),
      },
    );

    runtime.bind(binding);
    runtime.motion.addAdditiveLayer(
      external,
      startTime: const Duration(seconds: 1),
      weight: 0.5,
    );
    runtime.motion.addAdditiveLayer(procedural, speed: 2.0);
    runtime.update(0.25);

    expect(binding.nodes[0]!.localTransform.storage[12], 1.0);
    expect(binding.nodes[0]!.localTransform.storage[13], 0.5);

    runtime.motion.clearAdditiveLayers();
    runtime.update(0);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[13], 0.0);
  });

  test('runtime motion composes additive VRMA model-root motion', () {
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();

    runtime.bind(binding);
    final layerId = runtime.motion.addAdditiveLayer(
      _hipsTranslationVrma(2.0),
      startTime: const Duration(seconds: 1),
      weight: 0.5,
      hipsTranslationScale: 2.0,
    );
    runtime.motion.playVrmAnimation(
      _hipsTranslationVrma(1.0),
      startTime: const Duration(seconds: 1),
    );
    runtime.update(0);

    expect(binding.modelRootMotionTransform.storage[12], 3.0);

    runtime.motion.removeAdditiveLayer(layerId);
    runtime.update(0);
    expect(binding.modelRootMotionTransform.storage[12], 1.0);
  });

  test('runtime motion ignores non-finite morph weights', () {
    final json = _minimalVrmJson(
      meshes: [
        {
          'weights': [0.25],
          'primitives': [
            {
              'attributes': <String, Object?>{},
              'targets': [<String, Object?>{}],
            },
          ],
        },
      ],
      nodeMesh: {0: 0},
    );
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.setAdditiveProgrammaticPose(
      VrmProgrammaticPose(
        morphWeights: const {
          0: [double.nan],
        },
      ),
    );
    runtime.motion.play(
      VrmProgrammaticPose(
        morphWeights: const {
          0: [double.infinity],
        },
      ),
    );
    runtime.update(0);

    expect(binding.meshes[0]!.weights['0:0'], 0.25);
  });

  test('runtime motion ignores morph weights outside target range', () {
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {
              'attributes': <String, Object?>{},
              'targets': [<String, Object?>{}],
            },
          ],
        },
      ],
      nodeMesh: {0: 0},
    );
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.setAdditiveProgrammaticPose(
      VrmProgrammaticPose(
        morphWeights: const {
          0: [0.1, 0.8],
        },
      ),
    );
    runtime.motion.play(
      VrmProgrammaticPose(
        morphWeights: const {
          0: [0.4, 0.9],
        },
      ),
    );
    runtime.update(0);

    expect(binding.meshes[0]!.weights['0:0'], closeTo(0.5, 0.0001));
    expect(binding.meshes[0]!.weights.containsKey('0:1'), isFalse);
  });

  test('runtime motion applies additive programmatic rotation and scale', () {
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();
    final quarterTurnY = [
      0.0,
      math.sin(math.pi / 4),
      0.0,
      math.cos(math.pi / 4),
    ];

    runtime.bind(binding);
    runtime.motion.setAdditiveProgrammaticPose(
      VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(rotation: quarterTurnY, scale: const [3.0, 1.0, 1.0]),
        },
      ),
      weight: 0.5,
    );
    runtime.update(0);

    final m = binding.nodes[0]!.localTransform.storage;
    expect(m[0], closeTo(math.sqrt2, 0.0001));
    expect(m[2], closeTo(-math.sqrt2, 0.0001));
    expect(m[8], closeTo(math.sqrt1_2, 0.0001));
  });

  test('runtime motion applies external glTF animation by node index', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0]);
    final animationJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'nodes': [
              {'name': 'animated'},
            ],
          }
          ..addAll(
            _animationStorageJson(
              binary.length,
              [
                [0, 8],
                [8, 24],
              ],
              accessorTypes: ['SCALAR', 'VEC3'],
            ),
          )
          ..['animations'] = [
            {
              'channels': [
                {
                  'sampler': 0,
                  'target': {'node': 0, 'path': 'translation'},
                },
              ],
              'samplers': [
                {'input': 0, 'output': 1},
              ],
            },
          ];
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();
    final animation = GltfAsset.parse(
      bytes: _glb(animationJson, binaryChunk: binary),
    );

    runtime.bind(binding);
    runtime.motion.play(animation);
    runtime.update(0.5);

    expect(binding.nodes[0]!.localTransform.storage[12], 2.0);
  });

  test('runtime motion reports external glTF without animations clearly', () {
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final animation = GltfAsset.parse(
      bytes: _glb({
        'asset': {'version': '2.0'},
      }),
    );

    expect(
      () => runtime.motion.playGltfAnimation(animation, 0),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'glTF asset does not contain animations.',
        ),
      ),
    );
  });

  test('runtime motion selects external glTF animation clips by index', () {
    final binary = _floats([
      0.0, 1.0, // time
      0.0, 0.0, 0.0, 4.0, 0.0, 0.0, // clip 0 translation
      0.0, 0.0, 0.0, -6.0, 0.0, 0.0, // clip 1 translation
    ]);
    final animationJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'nodes': [
              {'name': 'animated'},
            ],
          }
          ..addAll(
            _animationStorageJson(
              binary.length,
              [
                [0, 8],
                [8, 24],
                [32, 24],
              ],
              accessorTypes: ['SCALAR', 'VEC3', 'VEC3'],
            ),
          )
          ..['animations'] = [
            {
              'channels': [
                {
                  'sampler': 0,
                  'target': {'node': 0, 'path': 'translation'},
                },
              ],
              'samplers': [
                {'input': 0, 'output': 1},
              ],
            },
            {
              'channels': [
                {
                  'sampler': 0,
                  'target': {'node': 0, 'path': 'translation'},
                },
              ],
              'samplers': [
                {'input': 0, 'output': 2},
              ],
            },
          ];
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();
    final animation = GltfAsset.parse(
      bytes: _glb(animationJson, binaryChunk: binary),
    );

    runtime.bind(binding);
    runtime.motion.play(animation, animationIndex: 1);
    runtime.update(0.5);

    expect(binding.nodes[0]!.localTransform.storage[12], -3.0);
  });

  test(
    'runtime motion supports pause, seek, loop, stop, and morph weights',
    () {
      final binary = _floats([0.0, 1.0, 0.0, 0.0, 1.0, 0.5]);
      final json =
          _minimalVrmJson(
              meshes: [
                {
                  'weights': [0.2, 0.4],
                  'primitives': [
                    {
                      'attributes': <String, Object?>{},
                      'targets': [<String, Object?>{}, <String, Object?>{}],
                    },
                    {
                      'attributes': <String, Object?>{},
                      'targets': [<String, Object?>{}, <String, Object?>{}],
                    },
                  ],
                },
              ],
              nodeMesh: {0: 0},
            )
            ..addAll(
              _animationStorageJson(
                binary.length,
                [
                  [0, 8],
                  [8, 16],
                ],
                accessorTypes: ['SCALAR', 'SCALAR'],
              ),
            )
            ..['animations'] = [
              {
                'channels': [
                  {
                    'sampler': 0,
                    'target': {'node': 0, 'path': 'weights'},
                  },
                ],
                'samplers': [
                  {'input': 0, 'output': 1},
                ],
              },
            ];
      (json['nodes']! as List<Map<String, Object?>>)[0]['weights'] = [0.3, 0.6];
      final runtime = VrmRuntime(
        VrmModel.parseGlb(_glb(json, binaryChunk: binary)),
      );
      final binding = _FakeBinding();
      var loops = 0;

      runtime.bind(binding);
      runtime.update(0);
      expect(binding.meshes[0]!.weights['0:0'], 0.3);
      expect(binding.meshes[0]!.weights['0:1'], 0.6);

      runtime.motion.onLooped = () {
        loops++;
      };
      runtime.motion.playEmbeddedGltfAnimation(0, loop: true);
      runtime.update(1.25);

      expect(loops, 1);
      expect(runtime.motion.timeSeconds, closeTo(0.25, 0.0001));
      expect(binding.meshes[0]!.weights['0:0'], closeTo(0.25, 0.0001));
      expect(binding.meshes[0]!.weights['0:1'], closeTo(0.125, 0.0001));
      expect(binding.meshes[0]!.weights['1:0'], closeTo(0.25, 0.0001));
      expect(binding.meshes[0]!.weights['1:1'], closeTo(0.125, 0.0001));

      runtime.motion.pause();
      runtime.update(0.5);
      expect(runtime.motion.timeSeconds, closeTo(0.25, 0.0001));

      runtime.motion.resume();
      runtime.motion.seek(const Duration(milliseconds: 750));
      runtime.update(0);
      expect(binding.meshes[0]!.weights['0:0'], closeTo(0.75, 0.0001));

      runtime.motion.stop();
      runtime.update(0);
      expect(runtime.motion.isPlaying, isFalse);
      expect(binding.meshes[0]!.weights['0:0'], 0.3);
      expect(binding.meshes[0]!.weights['0:1'], 0.6);
    },
  );

  test('runtime motion applies programmatic pose source', () {
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {
              'attributes': <String, Object?>{},
              'targets': [<String, Object?>{}, <String, Object?>{}],
            },
          ],
        },
      ],
      materials: [
        {
          'pbrMetallicRoughness': {
            'baseColorFactor': [0.0, 0.0, 0.0, 1.0],
          },
        },
      ],
      nodeMesh: {0: 0},
      expressions: {
        'preset': {
          'happy': {
            'materialColorBinds': [
              {
                'material': 0,
                'type': 'color',
                'targetValue': [1.0, 0.0, 0.0, 1.0],
              },
            ],
          },
          'lookLeft': {
            'morphTargetBinds': [
              {'node': 0, 'index': 1, 'weight': 1.0},
            ],
          },
        },
      },
    );
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    vrm['lookAt'] = _lookAtJson(type: 'expression');
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.play(
      VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(translation: [3.0, 0.0, 0.0]),
        },
        morphWeights: const {
          0: [0.4],
        },
        expressionWeights: const {'happy': 0.5},
        lookAtYawDegrees: 45,
        lookAtPitchDegrees: 0,
      ),
    );
    runtime.update(0);

    expect(binding.nodes[0]!.localTransform.storage[12], 3.0);
    expect(binding.meshes[0]!.weights['0:0'], 0.4);
    expect(binding.meshes[0]!.weights['0:1'], closeTo(0.5, 0.0001));
    expect(
      binding.materials[0]!.colors['color'],
      VrmVector4(0.5, 0.0, 0.0, 1.0),
    );

    runtime.motion.stop();
    runtime.update(0);

    expect(runtime.motion.isPlaying, isFalse);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
    expect(binding.meshes[0]!.weights['0:0'], 0.0);
    expect(binding.meshes[0]!.weights['0:1'], 0.0);
    expect(
      binding.materials[0]!.colors['color'],
      VrmVector4(0.0, 0.0, 0.0, 1.0),
    );
  });

  test('programmatic pose copies caller-owned node pose lists', () {
    final translation = [1.0, 2.0, 3.0];
    final rotation = [0.0, 0.0, 0.0, 1.0];
    final scale = [1.0, 1.0, 1.0];
    final nodePose = GltfNodePose(
      translation: translation,
      rotation: rotation,
      scale: scale,
    );
    final pose = VrmProgrammaticPose(nodePoses: {0: nodePose});

    translation[0] = 9.0;
    rotation[3] = 0.0;
    scale[0] = 9.0;

    expect(nodePose.translation, [1.0, 2.0, 3.0]);
    expect(nodePose.rotation, [0.0, 0.0, 0.0, 1.0]);
    expect(nodePose.scale, [1.0, 1.0, 1.0]);
    expect(() => nodePose.translation![0] = 9.0, throwsUnsupportedError);
    expect(pose.nodePoses[0]!.translation, [1.0, 2.0, 3.0]);
    expect(pose.nodePoses[0]!.rotation, [0.0, 0.0, 0.0, 1.0]);
    expect(pose.nodePoses[0]!.scale, [1.0, 1.0, 1.0]);
    expect(
      () => pose.nodePoses[0]!.translation![0] = 9.0,
      throwsUnsupportedError,
    );
  });

  test('runtime motion ignores invalid programmatic transform lists', () {
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.setAdditiveProgrammaticPose(
      VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(translation: [double.nan, 0.0, 0.0]),
        },
      ),
    );
    runtime.motion.play(
      VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(
            translation: [double.nan, 0.0, 0.0],
            rotation: [0.0],
            scale: [double.infinity, 1.0, 1.0],
          ),
        },
      ),
    );
    runtime.update(0);

    expect(
      binding.nodes[0]!.localTransform.storage.every((v) => v.isFinite),
      isTrue,
    );
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
  });

  test('runtime motion plays procedural pose callbacks', () {
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();
    VrmProgrammaticPose idle(double timeSeconds) => VrmProgrammaticPose(
      nodePoses: {
        0: GltfNodePose(translation: [timeSeconds, 0.0, 0.0]),
      },
    );

    runtime.bind(binding);
    runtime.motion.play(idle, speed: 2, startTimeSeconds: 0.25);
    runtime.update(0);

    expect(binding.nodes[0]!.localTransform.storage[12], 0.25);
    expect(runtime.motion.timeSeconds, 0.25);

    runtime.update(0.5);
    expect(binding.nodes[0]!.localTransform.storage[12], 1.25);
    expect(runtime.motion.timeSeconds, 1.25);

    runtime.motion.seek(const Duration(milliseconds: 750));
    runtime.update(0);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.75);
    expect(runtime.motion.timeSeconds, 0.75);

    runtime.motion.playProgrammaticPose(
      VrmProgrammaticPose(
        nodePoses: {
          0: GltfNodePose(translation: [9.0, 0.0, 0.0]),
        },
      ),
      priority: -1,
    );
    runtime.update(0);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.75);

    runtime.motion.stop();
    runtime.update(0);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
  });
}
