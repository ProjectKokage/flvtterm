part of '../flvtterm_test.dart';

void gltfAnimationTests() {
  test('reports animation targeting a matrix node', () {
    final binary = _floats([
      0.0, 1.0, // input times
      0.0, 0.0, 0.0, // output translation 0
      1.0, 0.0, 0.0, // output translation 1
    ]);
    final json = {
      'asset': {'version': '2.0'},
      'nodes': [
        {
          'matrix': [
            1.0,
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
            0.0,
            0.0,
            0.0,
            0.0,
            1.0,
          ],
        },
      ],
      ..._animationStorageJson(binary.length, [
        [0, 8],
        [8, 24],
      ]),
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

    final strict = GltfAsset.tryParse(bytes: _glb(json, binaryChunk: binary));
    final permissive = GltfAsset.tryParse(
      bytes: _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );

    expect(strict.asset, isNull);
    expect(permissive.asset, isNotNull);
    expect(
      strict.validation.errors.map((d) => d.code),
      contains('gltf.animatedNodeMatrix'),
    );
  });

  test('evaluates glTF animation accessors from a GLB BIN chunk', () {
    final binary = _floats([
      // accessor 0: input times
      0.0, 1.0, 2.0,
      // accessor 1: node 0 translations
      0.0, 0.0, 0.0,
      2.0, 0.0, 0.0,
      4.0, 0.0, 0.0,
      // accessor 2: node 1 scales
      1.0, 1.0, 1.0,
      3.0, 3.0, 3.0,
      5.0, 5.0, 5.0,
    ]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(binary.length, [
          [0, 12],
          [12, 36],
          [48, 36],
        ]),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {
                'node': 0,
                'path': 'translation',
                'extensions': {
                  'VENDOR_target': {'mode': 'target'},
                },
              },
              'extensions': {
                'VENDOR_channel': {'mode': 'channel'},
              },
            },
            {
              'sampler': 1,
              'target': {'node': 1, 'path': 'scale'},
            },
          ],
          'samplers': [
            {
              'input': 0,
              'output': 1,
              'interpolation': 'LINEAR',
              'extensions': {
                'VENDOR_sampler': {'mode': 'sampler'},
              },
            },
            {'input': 0, 'output': 2, 'interpolation': 'STEP'},
          ],
          'extensions': {
            'VENDOR_animation': {'mode': 'animation'},
          },
        },
      ];
    (json['extensionsUsed']! as List<String>).addAll([
      'VENDOR_animation',
      'VENDOR_channel',
      'VENDOR_target',
      'VENDOR_sampler',
    ]);

    final model = VrmModel.parseGlb(_glb(json, binaryChunk: binary));
    final animation = model.gltf.animations.single;
    final frame = GltfAnimationEvaluator(model.gltf).evaluate(0, 0.5);
    final exactFrame = GltfAnimationEvaluator(model.gltf).evaluate(0, 1.0);

    expect(() => animation.channels.clear(), throwsUnsupportedError);
    expect(() => animation.samplers.clear(), throwsUnsupportedError);
    expect(animation.extensions, {
      'VENDOR_animation': {'mode': 'animation'},
    });
    expect(animation.channels.first.targetExtensions, {
      'VENDOR_target': {'mode': 'target'},
    });
    expect(animation.channels.first.extensions, {
      'VENDOR_channel': {'mode': 'channel'},
    });
    expect(animation.samplers.first.extensions, {
      'VENDOR_sampler': {'mode': 'sampler'},
    });
    expect(() => animation.extensions['extra'] = 1, throwsUnsupportedError);
    expect(
      () => animation.channels.first.targetExtensions['extra'] = 1,
      throwsUnsupportedError,
    );
    expect(
      () => animation.channels.first.extensions['extra'] = 1,
      throwsUnsupportedError,
    );
    expect(
      () => animation.samplers.first.extensions['extra'] = 1,
      throwsUnsupportedError,
    );
    expect(frame.nodePoses[0]!.translation, [1.0, 0.0, 0.0]);
    expect(frame.nodePoses[1]!.scale, [1.0, 1.0, 1.0]);
    expect(exactFrame.nodePoses[1]!.scale, [3.0, 3.0, 3.0]);
    expect(
      () => frame.nodePoses[0]!.translation![0] = 9.0,
      throwsUnsupportedError,
    );
  });

  test('loops mixed-duration animation samplers at the clip boundary', () {
    final binary = _floats([
      0.0, 1.0, // accessor 0: short input times
      0.0, 0.0, 0.0, // accessor 1: short translation frame 0
      10.0, 0.0, 0.0, // accessor 1: short translation frame 1
      0.0, 2.0, // accessor 2: long input times
      0.0, 0.0, 0.0, // accessor 3: long translation frame 0
      20.0, 0.0, 0.0, // accessor 3: long translation frame 1
    ]);
    final json = _minimalVrmJson()
      ..['buffers'] = [
        {'byteLength': binary.length},
      ]
      ..['bufferViews'] = [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 8},
        {'buffer': 0, 'byteOffset': 8, 'byteLength': 24},
        {'buffer': 0, 'byteOffset': 32, 'byteLength': 8},
        {'buffer': 0, 'byteOffset': 40, 'byteLength': 24},
      ]
      ..['accessors'] = [
        {
          'bufferView': 0,
          'componentType': 5126,
          'count': 2,
          'type': 'SCALAR',
          'min': [0.0],
          'max': [1.0],
        },
        {'bufferView': 1, 'componentType': 5126, 'count': 2, 'type': 'VEC3'},
        {
          'bufferView': 2,
          'componentType': 5126,
          'count': 2,
          'type': 'SCALAR',
          'min': [0.0],
          'max': [2.0],
        },
        {'bufferView': 3, 'componentType': 5126, 'count': 2, 'type': 'VEC3'},
      ]
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
            {'input': 2, 'output': 3},
          ],
        },
      ];
    final model = VrmModel.parseGlb(_glb(json, binaryChunk: binary));
    final evaluator = GltfAnimationEvaluator(model.gltf);

    final beforeLoop = evaluator.evaluate(0, 1.5, loop: true);
    final afterLoop = evaluator.evaluate(0, 2.5, loop: true);

    expect(evaluator.duration(0), 2.0);
    expect(beforeLoop.nodePoses[0]!.translation, [10.0, 0.0, 0.0]);
    expect(beforeLoop.nodePoses[1]!.translation, [15.0, 0.0, 0.0]);
    expect(afterLoop.nodePoses[0]!.translation, [5.0, 0.0, 0.0]);
    expect(afterLoop.nodePoses[1]!.translation, [5.0, 0.0, 0.0]);

    final runtime = VrmRuntime(model);
    final binding = _FakeBinding();
    runtime.bind(binding);
    runtime.motion.playEmbeddedGltfAnimation(
      0,
      loop: true,
      startTimeSeconds: 1.5,
    );
    runtime.update(0);

    expect(binding.nodes[0]!.localTransform.storage[12], 10.0);
    expect(binding.nodes[1]!.localTransform.storage[12], 15.0);

    runtime.motion.seek(const Duration(milliseconds: 2500));
    runtime.update(0);

    expect(binding.nodes[0]!.localTransform.storage[12], 5.0);
    expect(binding.nodes[1]!.localTransform.storage[12], 5.0);
  });

  test('evaluates sparse glTF animation accessor overrides', () {
    final binary = Uint8List(24);
    final data = ByteData.sublistView(binary);
    data.setFloat32(0, 0.0, Endian.little);
    data.setFloat32(4, 1.0, Endian.little);
    binary[8] = 1;
    data.setFloat32(12, 3.0, Endian.little);
    data.setFloat32(16, 0.0, Endian.little);
    data.setFloat32(20, 0.0, Endian.little);
    final json = _minimalVrmJson()
      ..['buffers'] = [
        {'byteLength': binary.length},
      ]
      ..['bufferViews'] = [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 8},
        {'buffer': 0, 'byteOffset': 8, 'byteLength': 1},
        {'buffer': 0, 'byteOffset': 12, 'byteLength': 12},
      ]
      ..['accessors'] = [
        {
          'bufferView': 0,
          'componentType': 5126,
          'count': 2,
          'type': 'SCALAR',
          'min': [0.0],
          'max': [1.0],
        },
        {
          'componentType': 5126,
          'count': 2,
          'type': 'VEC3',
          'sparse': {
            'count': 1,
            'indices': {'bufferView': 1, 'componentType': 5121},
            'values': {'bufferView': 2},
          },
        },
      ]
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

    final model = VrmModel.parseGlb(_glb(json, binaryChunk: binary));
    final frame = GltfAnimationEvaluator(model.gltf).evaluate(0, 0.5);

    expect(frame.nodePoses[0]!.translation, [1.5, 0.0, 0.0]);
  });

  test('evaluates glTF rotation slerp and cubic spline animation', () {
    final binary = _floats([
      // accessor 0: input times
      0.0, 1.0,
      // accessor 1: node 0 rotations
      0.0, 0.0, 0.0, 1.0,
      0.0, 0.0, 1.0, 0.0,
      // accessor 2: node 1 cubic translation frames
      0.0, 0.0, 0.0, // frame 0 in tangent
      0.0, 0.0, 0.0, // frame 0 value
      0.0, 0.0, 0.0, // frame 0 out tangent
      0.0, 0.0, 0.0, // frame 1 in tangent
      2.0, 0.0, 0.0, // frame 1 value
      0.0, 0.0, 0.0, // frame 1 out tangent
    ]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 32],
            [40, 72],
          ],
          accessorTypes: ['SCALAR', 'VEC4', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'rotation'},
            },
            {
              'sampler': 1,
              'target': {'node': 1, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1, 'interpolation': 'LINEAR'},
            {'input': 0, 'output': 2, 'interpolation': 'CUBICSPLINE'},
          ],
        },
      ];

    final model = VrmModel.parseGlb(_glb(json, binaryChunk: binary));
    final frame = GltfAnimationEvaluator(model.gltf).evaluate(0, 0.5);
    final rotation = frame.nodePoses[0]!.rotation!;

    expect(rotation[0], closeTo(0.0, 0.0001));
    expect(rotation[1], closeTo(0.0, 0.0001));
    expect(rotation[2], closeTo(0.7071, 0.0001));
    expect(rotation[3], closeTo(0.7071, 0.0001));
    expect(frame.nodePoses[1]!.translation, [1.0, 0.0, 0.0]);
  });

  test('evaluates CUBICSPLINE animation tangents with keyframe duration', () {
    final binary = _floats([
      // accessor 0: input times
      0.0, 2.0,
      // accessor 1: node 0 cubic translation frames
      0.0, 0.0, 0.0, // frame 0 in tangent
      0.0, 0.0, 0.0, // frame 0 value
      2.0, 0.0, 0.0, // frame 0 out tangent
      0.0, 0.0, 0.0, // frame 1 in tangent
      4.0, 0.0, 0.0, // frame 1 value
      0.0, 0.0, 0.0, // frame 1 out tangent
    ]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 72],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['accessors'] = [
        {
          'bufferView': 0,
          'componentType': 5126,
          'count': 2,
          'type': 'SCALAR',
          'min': [0.0],
          'max': [2.0],
        },
        {'bufferView': 1, 'componentType': 5126, 'count': 6, 'type': 'VEC3'},
      ]
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1, 'interpolation': 'CUBICSPLINE'},
          ],
        },
      ];

    final model = VrmModel.parseGlb(_glb(json, binaryChunk: binary));
    final frame = GltfAnimationEvaluator(model.gltf).evaluate(0, 1.0);

    expect(frame.nodePoses[0]!.translation![0], closeTo(2.5, 0.0001));
  });

  test('reports CUBICSPLINE animation with one keyframe', () {
    final binary = _floats([0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(binary.length, [
          [0, 4],
          [4, 36],
        ]),
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
            {'input': 0, 'output': 1, 'interpolation': 'CUBICSPLINE'},
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
      contains('gltf.invalidAnimationCubicSplineKeyframes'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidAnimationCubicSplineKeyframes')
          .map((d) => d.jsonPath),
      contains(r'$.animations[0].samplers[0].input'),
    );
    expect(
      GltfAnimationEvaluator(result.asset!.gltf).evaluate(0, 0).nodePoses,
      isEmpty,
    );
  });

  test('reports weights animation without morph targets', () {
    final binary = _floats([
      0.0, 1.0, // input times
      0.0, 1.0, // output weights
    ]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 8],
          ],
          accessorTypes: const ['SCALAR', 'SCALAR'],
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

    final result = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.animationWeightsWithoutMorphTargets'),
    );
  });

  test('evaluates normalized integer rotation and weight outputs', () {
    final binary = Uint8List.fromList([
      0, 0, 0, 0, // input time 0.0
      0, 0, 128, 63, // input time 1.0
      0, 0, 0, 127, // rotation frame 0
      0, 0, 90, 90, // rotation frame 1
      0, 255, // weights frame 0
      128, 64, // weights frame 1
    ]);
    final json =
        _minimalVrmJson(
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
            nodeMesh: {0: 0},
          )
          ..['buffers'] = [
            {'byteLength': binary.length},
          ]
          ..['bufferViews'] = [
            {'buffer': 0, 'byteOffset': 0, 'byteLength': 8},
            {'buffer': 0, 'byteOffset': 8, 'byteLength': 8},
            {'buffer': 0, 'byteOffset': 16, 'byteLength': 4},
          ]
          ..['accessors'] = [
            {
              'bufferView': 0,
              'componentType': 5126,
              'count': 2,
              'type': 'SCALAR',
              'min': [0.0],
              'max': [1.0],
            },
            {
              'bufferView': 1,
              'componentType': 5120,
              'normalized': true,
              'count': 2,
              'type': 'VEC4',
            },
            {
              'bufferView': 2,
              'componentType': 5121,
              'normalized': true,
              'count': 4,
              'type': 'SCALAR',
            },
          ]
          ..['animations'] = [
            {
              'channels': [
                {
                  'sampler': 0,
                  'target': {'node': 0, 'path': 'rotation'},
                },
                {
                  'sampler': 1,
                  'target': {'node': 0, 'path': 'weights'},
                },
              ],
              'samplers': [
                {'input': 0, 'output': 1, 'interpolation': 'STEP'},
                {'input': 0, 'output': 2, 'interpolation': 'STEP'},
              ],
            },
          ];

    final model = VrmModel.parseGlb(_glb(json, binaryChunk: binary));
    final frame = GltfAnimationEvaluator(model.gltf).evaluate(0, 1.0);
    final rotation = frame.nodePoses[0]!.rotation!;

    expect(rotation[0], 0.0);
    expect(rotation[1], 0.0);
    expect(rotation[2], closeTo(0.7071, 0.0001));
    expect(rotation[3], closeTo(0.7071, 0.0001));
    expect(frame.morphWeights[0]![0], closeTo(128 / 255, 0.0001));
    expect(frame.morphWeights[0]![1], closeTo(64 / 255, 0.0001));
  });

  test('reports non-unit glTF rotation animation keyframes', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0, 0.0, 1.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 32],
          ],
          accessorTypes: ['SCALAR', 'VEC4'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'rotation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1, 'interpolation': 'STEP'},
          ],
        },
      ];

    final strict = VrmModel.tryParseGlb(_glb(json, binaryChunk: binary));
    final permissive = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );

    expect(strict.asset, isNull);
    expect(permissive.asset, isNotNull);
    expect(
      strict.validation.errors.map((d) => d.code),
      contains('gltf.invalidAnimationRotationQuaternion'),
    );
    expect(
      strict.validation.errors
          .where((d) => d.code == 'gltf.invalidAnimationRotationQuaternion')
          .map((d) => d.jsonPath),
      contains(r'$.animations[0].samplers[0].output'),
    );
  });

  test('reports non-finite glTF animation output values', () {
    final binary = Uint8List(32);
    final data = ByteData.sublistView(binary);
    data.setFloat32(0, 0.0, Endian.little);
    data.setFloat32(4, 1.0, Endian.little);
    data.setFloat32(8, 0.0, Endian.little);
    data.setFloat32(12, 0.0, Endian.little);
    data.setFloat32(16, 0.0, Endian.little);
    data.setFloat32(20, double.nan, Endian.little);
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

    final strict = VrmModel.tryParseGlb(_glb(json, binaryChunk: binary));
    final permissive = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );

    expect(strict.asset, isNull);
    expect(permissive.asset, isNotNull);
    expect(
      GltfAnimationEvaluator(permissive.asset!.gltf).evaluate(0, 1.0).nodePoses,
      isEmpty,
    );
    expect(
      strict.validation.errors.map((d) => d.code),
      contains('gltf.invalidAnimationOutputValue'),
    );
    expect(
      strict.validation.errors
          .where((d) => d.code == 'gltf.invalidAnimationOutputValue')
          .map((d) => d.jsonPath),
      contains(r'$.animations[0].samplers[0].output'),
    );
  });

  test('normalizes exact glTF rotation animation keyframes', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0, 2.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 32],
          ],
          accessorTypes: ['SCALAR', 'VEC4'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'rotation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1, 'interpolation': 'STEP'},
          ],
        },
      ];

    final model = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    ).asset!;
    final evaluator = GltfAnimationEvaluator(model.gltf);

    expect(evaluator.evaluate(0, 0.0).nodePoses[0]!.rotation, [
      0.0,
      0.0,
      0.0,
      1.0,
    ]);
    expect(evaluator.evaluate(0, 1.0).nodePoses[0]!.rotation, [
      0.0,
      0.0,
      1.0,
      0.0,
    ]);
  });
}
