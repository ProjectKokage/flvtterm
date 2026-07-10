part of '../flvtterm_test.dart';

void vrmaMotionTests() {
  test('runtime motion reports VRMA without glTF animations clearly', () {
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final vrma = VrmAnimationAsset.parse(
      bytes: _glb({
        'asset': {'version': '2.0'},
        'extensionsUsed': ['VRMC_vrm_animation'],
        'extensions': {
          'VRMC_vrm_animation': {'specVersion': '1.0'},
        },
      }),
    );

    expect(
      () => runtime.motion.playVrmAnimation(vrma),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'VRMA asset does not contain glTF animations.',
        ),
      ),
    );
  });

  test('runtime selects VRMA animations and defaults to first', () {
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();
    final vrma = _hipsTranslationVrma(2.0, secondX: 4.0);

    expect(vrma.gltf.animations, hasLength(2));
    expect(vrma.defaultAnimationIndex, 0);
    runtime.bind(binding);

    runtime.motion.playVrmAnimation(vrma);
    runtime.update(1.0);
    expect(binding.modelRootMotionTransform.storage[12], closeTo(2.0, 0.0001));

    runtime.motion.playVrmAnimation(vrma, animationIndex: 1);
    runtime.update(1.0);
    expect(binding.modelRootMotionTransform.storage[12], closeTo(4.0, 0.0001));
  });

  test('runtime motion plays VRMA humanoid and expression animation', () {
    final modelJson = _minimalVrmJson(
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
      expressions: {
        'preset': {
          'happy': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
        },
      },
    );
    final vrmaBinary = _floats([
      0.0,
      1.0,
      0.0,
      0.0,
      0.0,
      2.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.8,
      0.0,
      0.0,
    ]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {'name': 'sourceHips'},
              {'name': 'happyExpression'},
            ],
          }
          ..addAll(
            _animationStorageJson(vrmaBinary.length, [
              [0, 8],
              [8, 24],
              [32, 24],
            ]),
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
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'humanoid': {
                'humanBones': {
                  'hips': {'node': 0},
                },
              },
              'expressions': {
                'preset': {
                  'happy': {'node': 1},
                },
              },
            },
          };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(modelJson)));
    final binding = _FakeBinding();
    final vrma = VrmAnimationAsset.tryParse(
      bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
      validation: VrmValidationMode.permissive,
    );

    runtime.bind(binding);
    runtime.motion.play(
      vrma.asset!,
      hipsTranslationScale: 0.5,
      fadeIn: const Duration(seconds: 1),
    );
    runtime.update(0.5);

    expect(binding.modelRootMotionTransform.storage[12], 0.25);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
    expect(binding.meshes[0]!.weights['0:0'], closeTo(0.2, 0.0001));

    runtime.motion.stop();
    runtime.update(0);
    expect(binding.modelRootMotionTransform.storage[12], 0.0);
  });

  test('runtime motion crossfades VRMA root motion to programmatic pose', () {
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playVrmAnimation(_hipsTranslationVrma(2.0));
    runtime.update(1.0);
    expect(binding.modelRootMotionTransform.storage[12], closeTo(2.0, 0.0001));

    runtime.motion.playProgrammaticPose(
      VrmProgrammaticPose(),
      fadeIn: const Duration(seconds: 1),
    );
    runtime.update(0.5);

    expect(binding.modelRootMotionTransform.storage[12], closeTo(1.0, 0.0001));

    runtime.update(0.5);
    expect(binding.modelRootMotionTransform.storage[12], closeTo(0.0, 0.0001));
  });

  test('runtime motion crossfades VRMA root motion to generic glTF', () {
    final binary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
    final json =
        <String, Object?>{
          'asset': {'version': '2.0'},
          'nodes': [
            {'name': 'targetHips'},
          ],
        }..addAll(
          _animationStorageJson(binary.length, [
            [0, 8],
            [8, 24],
          ]),
        );
    json['animations'] = [
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
    final generic = GltfAsset.parse(bytes: _glb(json, binaryChunk: binary));
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playVrmAnimation(_hipsTranslationVrma(2.0));
    runtime.update(1.0);

    runtime.motion.play(generic, fadeIn: const Duration(seconds: 1));
    runtime.update(0.5);

    expect(binding.modelRootMotionTransform.storage[12], closeTo(1.0, 0.0001));

    runtime.update(0.5);
    expect(binding.modelRootMotionTransform.storage[12], closeTo(0.0, 0.0001));
  });

  test('runtime motion composes root fallback after crossfaded node pose', () {
    final modelJson = _minimalVrmJson();
    (modelJson['nodes']! as List<Map<String, Object?>>).add({
      'name': 'modelRoot',
      'children': [0],
    });
    ((modelJson['scenes']! as List<Object?>).single
        as Map<String, Object?>)['nodes'] = [
      15,
    ];
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(modelJson)));
    final binding = _OrderBinding();

    runtime.bind(binding);
    runtime.motion.playVrmAnimation(_hipsTranslationVrma(2.0));
    runtime.update(1.0);
    expect(binding.nodeByGltfIndex(15).localTransform.storage[12], 2.0);

    runtime.motion.playProgrammaticPose(
      VrmProgrammaticPose(
        nodePoses: {
          15: GltfNodePose(translation: [0.0, 0.0, 0.0]),
        },
      ),
      fadeIn: const Duration(seconds: 1),
    );
    runtime.update(0.5);

    expect(binding.nodeByGltfIndex(15).localTransform.storage[12], 1.0);
  });

  test(
    'runtime motion preserves root motion when crossfade is interrupted',
    () {
      final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
      final binding = _FakeBinding();

      runtime.bind(binding);
      runtime.motion.playVrmAnimation(_hipsTranslationVrma(2.0));
      runtime.update(1.0);
      runtime.motion.playProgrammaticPose(
        VrmProgrammaticPose(),
        fadeIn: const Duration(seconds: 2),
      );
      runtime.update(1.0);
      expect(binding.modelRootMotionTransform.storage[12], 1.0);

      runtime.motion.playVrmAnimation(
        _hipsTranslationVrma(4.0),
        fadeIn: const Duration(seconds: 2),
      );
      runtime.update(0.0);
      expect(binding.modelRootMotionTransform.storage[12], 1.0);

      runtime.update(1.0);
      expect(binding.modelRootMotionTransform.storage[12], 2.5);
    },
  );

  test('runtime motion fades the current VRMA root crossfade to rest', () {
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playVrmAnimation(_hipsTranslationVrma(2.0));
    runtime.update(1.0);
    runtime.motion.playVrmAnimation(
      _hipsTranslationVrma(4.0),
      fadeIn: const Duration(seconds: 2),
    );
    runtime.update(1.0);
    expect(binding.modelRootMotionTransform.storage[12], 3.0);

    runtime.motion.stop(fadeOut: const Duration(seconds: 2));
    runtime.update(1.0);

    expect(binding.modelRootMotionTransform.storage[12], 1.5);
  });

  test('runtime motion drives multiple VRMA expressions from one node', () {
    final modelJson = _minimalVrmJson(
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
      expressions: {
        'preset': {
          'happy': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
          'angry': {
            'morphTargetBinds': [
              {'node': 0, 'index': 1, 'weight': 1.0},
            ],
          },
        },
      },
    );
    final vrmaBinary = _floats([0.0, 1.0, 0.2, 0.0, 0.0, 0.8, 0.0, 0.0]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {'name': 'sharedExpression'},
            ],
          }
          ..addAll(
            _animationStorageJson(vrmaBinary.length, [
              [0, 8],
              [8, 24],
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
                {'input': 0, 'output': 1},
              ],
            },
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'expressions': {
                'preset': {
                  'happy': {'node': 0},
                  'angry': {'node': 0},
                },
              },
            },
          };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(modelJson)));
    final binding = _FakeBinding();
    final vrma = VrmAnimationAsset.parse(
      bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
    );

    runtime.bind(binding);
    runtime.motion.playVrmAnimation(vrma);
    runtime.update(0.5);

    expect(binding.meshes[0]!.weights['0:0'], closeTo(0.5, 0.0001));
    expect(binding.meshes[0]!.weights['0:1'], closeTo(0.5, 0.0001));
  });

  test('runtime motion retargets VRMA rotation through rest poses', () {
    List<double> yRotation(double degrees) {
      final radians = degrees * math.pi / 360;
      return [0.0, math.sin(radians), 0.0, math.cos(radians)];
    }

    final modelJson = _minimalVrmJson();
    (modelJson['nodes']! as List<Map<String, Object?>>)[0]['rotation'] =
        yRotation(45);
    final vrmaBinary = _floats([0.0, 1.0, ...yRotation(90), ...yRotation(180)]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {'name': 'sourceHips', 'rotation': yRotation(90)},
            ],
          }
          ..addAll(
            _animationStorageJson(
              vrmaBinary.length,
              [
                [0, 8],
                [8, 32],
              ],
              accessorTypes: const ['SCALAR', 'VEC4'],
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
                {'input': 0, 'output': 1},
              ],
            },
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'humanoid': {
                'humanBones': {
                  'hips': {'node': 0},
                },
              },
            },
          };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(modelJson)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playVrmAnimation(
      VrmAnimationAsset.tryParse(
        bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
        validation: VrmValidationMode.permissive,
      ).asset!,
    );
    runtime.update(1);

    final matrix = binding.nodes[0]!.localTransform.storage;
    expect(matrix[0], closeTo(mathCosDegrees(135), 0.0001));
    expect(matrix[8], closeTo(math.sin(135 * math.pi / 180), 0.0001));
    expect(matrix[10], closeTo(mathCosDegrees(135), 0.0001));
  });

  test('runtime motion normalizes VRMA world rest rotations', () {
    List<double> xRotation(double degrees) {
      final radians = degrees * math.pi / 360;
      return [math.sin(radians), 0.0, 0.0, math.cos(radians)];
    }

    List<double> yRotation(double degrees) {
      final radians = degrees * math.pi / 360;
      return [0.0, math.sin(radians), 0.0, math.cos(radians)];
    }

    final modelJson = _minimalVrmJson();
    final modelNodes = modelJson['nodes']! as List<Map<String, Object?>>;
    modelNodes.add({
      'name': 'destinationParent',
      'children': [0],
      'rotation': yRotation(-90),
    });
    ((modelJson['scenes']! as List<Object?>).first
        as Map<String, Object?>)['nodes'] = [
      modelNodes.length - 1,
    ];

    final vrmaBinary = _floats([0.0, 1.0, ...xRotation(0), ...xRotation(90)]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {
                'name': 'sourceParent',
                'children': [1],
                'rotation': yRotation(90),
              },
              {'name': 'sourceHips'},
            ],
          }
          ..addAll(
            _animationStorageJson(
              vrmaBinary.length,
              [
                [0, 8],
                [8, 32],
              ],
              accessorTypes: const ['SCALAR', 'VEC4'],
            ),
          )
          ..['animations'] = [
            {
              'channels': [
                {
                  'sampler': 0,
                  'target': {'node': 1, 'path': 'rotation'},
                },
              ],
              'samplers': [
                {'input': 0, 'output': 1},
              ],
            },
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'humanoid': {
                'humanBones': {
                  'hips': {'node': 1},
                },
              },
            },
          };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(modelJson)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    final vrma = VrmAnimationAsset.tryParse(
      bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
      validation: VrmValidationMode.permissive,
    ).asset!;
    runtime.motion.playVrmAnimation(vrma);
    runtime.update(1);

    final expected = _testTrs(rotation: xRotation(-90)).storage;
    void expectExpectedRotation() {
      final actual = binding.nodes[0]!.localTransform.storage;
      for (var index = 0; index < actual.length; index++) {
        expect(actual[index], closeTo(expected[index], 0.0001));
      }
    }

    expectExpectedRotation();

    runtime.motion.stop();
    runtime.motion.addAdditiveLayer(vrma);
    runtime.update(1);

    expectExpectedRotation();
  });

  test('runtime motion preserves source-only optional bone rotations', () {
    List<double> xRotation(double degrees) {
      final radians = degrees * math.pi / 360;
      return [math.sin(radians), 0.0, 0.0, math.cos(radians)];
    }

    List<double> yRotation(double degrees) {
      final radians = degrees * math.pi / 360;
      return [0.0, math.sin(radians), 0.0, math.cos(radians)];
    }

    final vrmaBinary = _floats([
      0.0,
      1.0,
      ...yRotation(0),
      ...yRotation(90),
      ...xRotation(0),
      ...xRotation(90),
    ]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {
                'name': 'sourceSpine',
                'children': [1],
              },
              {
                'name': 'sourceUpperChest',
                'children': [2],
              },
              {'name': 'sourceHead'},
            ],
          }
          ..addAll(
            _animationStorageJson(
              vrmaBinary.length,
              [
                [0, 8],
                [8, 32],
                [40, 32],
              ],
              accessorTypes: const ['SCALAR', 'VEC4', 'VEC4'],
            ),
          )
          ..['animations'] = [
            {
              'channels': [
                {
                  'sampler': 0,
                  'target': {'node': 1, 'path': 'rotation'},
                },
                {
                  'sampler': 1,
                  'target': {'node': 2, 'path': 'rotation'},
                },
              ],
              'samplers': [
                {'input': 0, 'output': 1},
                {'input': 0, 'output': 2},
              ],
            },
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'humanoid': {
                'humanBones': {
                  'spine': {'node': 0},
                  'upperChest': {'node': 1},
                  'head': {'node': 2},
                },
              },
            },
          };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();

    runtime.bind(binding);
    final vrma = VrmAnimationAsset.tryParse(
      bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
      validation: VrmValidationMode.permissive,
    ).asset!;
    runtime.motion.playVrmAnimation(vrma);
    runtime.update(1);

    final expected = _testTrs(rotation: const [0.5, 0.5, -0.5, 0.5]).storage;
    void expectExpectedRotation() {
      final actual = binding.nodes[2]!.localTransform.storage;
      for (var index = 0; index < actual.length; index++) {
        expect(actual[index], closeTo(expected[index], 0.0001));
      }
    }

    expectExpectedRotation();

    runtime.motion.stop();
    runtime.motion.addAdditiveLayer(vrma);
    runtime.update(1);

    expectExpectedRotation();
  });

  test('runtime motion retargets VRMA hips translation from rest poses', () {
    final modelJson = _minimalVrmJson();
    (modelJson['nodes']! as List<Map<String, Object?>>)[0]['translation'] = [
      0.0,
      10.0,
      0.0,
    ];
    final vrmaBinary = _floats([0.0, 1.0, 0.0, 2.0, 0.0, 0.0, 6.0, 0.0]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {
                'name': 'sourceHips',
                'translation': [0.0, 2.0, 0.0],
              },
            ],
          }
          ..addAll(
            _animationStorageJson(vrmaBinary.length, [
              [0, 8],
              [8, 24],
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
                {'input': 0, 'output': 1},
              ],
            },
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'humanoid': {
                'humanBones': {
                  'hips': {'node': 0},
                },
              },
            },
          };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(modelJson)));
    final binding = _FakeBinding();
    final vrma = VrmAnimationAsset.parse(
      bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
      validation: VrmValidationMode.permissive,
    );

    runtime.bind(binding);
    runtime.motion.playVrmAnimation(vrma, hipsTranslationScale: 0.5);
    runtime.update(1.0);

    expect(binding.modelRootMotionTransform.storage[12], 0.0);
    expect(binding.modelRootMotionTransform.storage[13], 2.0);
    expect(binding.modelRootMotionTransform.storage[14], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[13], 10.0);
  });

  test('runtime motion masks VRMA hips root motion', () {
    final vrmaBinary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {'name': 'sourceHips'},
            ],
          }
          ..addAll(
            _animationStorageJson(vrmaBinary.length, [
              [0, 8],
              [8, 24],
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
                {'input': 0, 'output': 1},
              ],
            },
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'humanoid': {
                'humanBones': {
                  'hips': {'node': 0},
                },
              },
            },
          };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();
    final vrma = VrmAnimationAsset.parse(
      bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
      validation: VrmValidationMode.permissive,
    );

    runtime.bind(binding);
    runtime.motion.playVrmAnimation(vrma, humanoidMask: {VrmHumanoidBone.head});
    runtime.update(1.0);

    expect(binding.modelRootMotionTransform.storage[12], 0.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
  });

  test('runtime motion can use a custom VRMA humanoid retargeter', () {
    final vrmaBinary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {'name': 'sourceHips'},
            ],
          }
          ..addAll(
            _animationStorageJson(vrmaBinary.length, [
              [0, 8],
              [8, 24],
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
                {'input': 0, 'output': 1},
              ],
            },
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'humanoid': {
                'humanBones': {
                  'hips': {'node': 0},
                },
              },
            },
          };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();
    final retargeter = _OffsetRetargeter();
    final vrma = VrmAnimationAsset.parse(
      bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
      validation: VrmValidationMode.permissive,
    );

    runtime.motion.vrmaRetargeter = retargeter;
    runtime.bind(binding);
    runtime.motion.playVrmAnimation(vrma, hipsTranslationScale: 3);
    runtime.update(1.0);

    expect(retargeter.bone, VrmHumanoidBone.hips);
    expect(retargeter.hipsTranslationScale, 3);
    expect(binding.nodes[0]!.localTransform.storage[12], 4.0);
    expect(binding.modelRootMotionTransform.storage[14], 9.0);
  });

  test('runtime motion plays VRMA JSON animation from data URI buffer', () {
    final vrmaBinary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {'name': 'sourceHips'},
            ],
          }
          ..addAll(
            _animationStorageJson(vrmaBinary.length, [
              [0, 8],
              [8, 24],
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
                {'input': 0, 'output': 1},
              ],
            },
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'humanoid': {
                'humanBones': {
                  'hips': {'node': 0},
                },
              },
            },
          };
    ((vrmaJson['buffers']! as List<Object?>).single
            as Map<String, Object?>)['uri'] =
        'data:application/octet-stream;base64,${base64.encode(vrmaBinary)}';
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
    final binding = _FakeBinding();
    final vrma = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(vrmaJson))),
      validation: VrmValidationMode.permissive,
    );

    runtime.bind(binding);
    runtime.motion.playVrmAnimation(vrma.asset!);
    runtime.update(0.5);

    expect(binding.modelRootMotionTransform.storage[12], 1.0);
    expect(binding.nodes[0]!.localTransform.storage[12], 0.0);
  });

  test(
    'runtime motion falls back to scene root nodes for VRMA root motion',
    () {
      final modelJson = _minimalVrmJson();
      (modelJson['nodes']! as List<Map<String, Object?>>).add({
        'name': 'modelRoot',
        'children': [0],
      });
      ((modelJson['scenes']! as List<Object?>).single
          as Map<String, Object?>)['nodes'] = [
        15,
      ];
      final vrmaBinary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0]);
      final vrmaJson =
          <String, Object?>{
              'asset': {'version': '2.0'},
              'extensionsUsed': ['VRMC_vrm_animation'],
              'nodes': [
                {'name': 'sourceHips'},
              ],
            }
            ..addAll(
              _animationStorageJson(vrmaBinary.length, [
                [0, 8],
                [8, 24],
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
                  {'input': 0, 'output': 1},
                ],
              },
            ]
            ..['extensions'] = {
              'VRMC_vrm_animation': {
                'specVersion': '1.0',
                'humanoid': {
                  'humanBones': {
                    'hips': {'node': 0},
                  },
                },
              },
            };
      final runtime = VrmRuntime(VrmModel.parseGlb(_glb(modelJson)));
      final binding = _OrderBinding();

      runtime.bind(binding);
      runtime.motion.playVrmAnimation(
        VrmAnimationAsset.parse(
          bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
          validation: VrmValidationMode.permissive,
        ),
      );
      runtime.update(0.5);

      expect(binding.nodeByGltfIndex(15).localTransform.storage[12], 1.0);
      expect(binding.nodeByGltfIndex(0).localTransform.storage[12], 0.0);
    },
  );

  test('runtime motion plays VRMA LookAt animation through expressions', () {
    final modelJson = _minimalVrmJson(
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
      expressions: {
        'preset': {
          'lookLeft': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
        },
      },
    );
    final vrm =
        (modelJson['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    vrm['lookAt'] = _lookAtJson(type: 'expression');
    final halfTurn = math.sin(math.pi / 4);
    final vrmaBinary = _floats([
      0.0,
      1.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
      halfTurn,
      0.0,
      halfTurn,
    ]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {'name': 'lookAt'},
            ],
          }
          ..addAll(
            _animationStorageJson(
              vrmaBinary.length,
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
                {'input': 0, 'output': 1},
              ],
            },
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'lookAt': {'node': 0},
            },
          };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(modelJson)));
    final binding = _FakeBinding();
    final vrma = VrmAnimationAsset.parse(
      bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
    );

    runtime.bind(binding);
    runtime.motion.playVrmAnimation(vrma);
    runtime.update(0.5);

    expect(binding.meshes[0]!.weights['0:0'], closeTo(0.5, 0.0001));

    runtime.motion.stop();
    runtime.update(0);
    expect(binding.meshes[0]!.weights['0:0'], 0.0);
  });

  test('runtime motion converts VRMA LookAt pitch through expressions', () {
    final modelJson = _minimalVrmJson(
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
      expressions: {
        'preset': {
          'lookDown': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
        },
      },
    );
    final vrm =
        (modelJson['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    vrm['lookAt'] = _lookAtJson(type: 'expression');
    final halfTurn = math.sin(math.pi / 4);
    final vrmaBinary = _floats([
      0.0,
      1.0,
      0.0,
      0.0,
      0.0,
      1.0,
      halfTurn,
      0.0,
      0.0,
      halfTurn,
    ]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {'name': 'lookAt'},
            ],
          }
          ..addAll(
            _animationStorageJson(
              vrmaBinary.length,
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
                {'input': 0, 'output': 1},
              ],
            },
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'lookAt': {'node': 0},
            },
          };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(modelJson)));
    final binding = _FakeBinding();
    final vrma = VrmAnimationAsset.parse(
      bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
    );

    runtime.bind(binding);
    runtime.motion.playVrmAnimation(vrma);
    runtime.update(1.0);

    expect(binding.meshes[0]!.weights['0:0'], closeTo(1.0, 0.0001));
  });

  test('stopping VRMA playback clears motion expression inputs', () {
    final modelJson = _minimalVrmJson(
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
      expressions: {
        'preset': {
          'happy': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
        },
      },
    );
    final vrmaBinary = _floats([0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {'name': 'happyExpression'},
            ],
          }
          ..addAll(
            _animationStorageJson(
              vrmaBinary.length,
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
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'expressions': {
                'preset': {
                  'happy': {'node': 0},
                },
              },
            },
          };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(modelJson)));
    final binding = _FakeBinding();
    final vrma = VrmAnimationAsset.parse(
      bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
    );

    runtime.bind(binding);
    runtime.motion.playVrmAnimation(vrma);
    runtime.update(0.5);
    expect(binding.meshes[0]!.weights['0:0'], 1.0);

    runtime.motion.stop();
    runtime.update(0);
    expect(binding.meshes[0]!.weights['0:0'], 0.0);
  });

  test('runtime skips invalid VRMA look expression mapping', () {
    final modelJson = _minimalVrmJson(
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
      expressions: {
        'preset': {
          'lookLeft': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
        },
      },
    );
    final vrmaBinary = _floats([0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'nodes': [
              {'name': 'lookLeftExpression'},
            ],
          }
          ..addAll(
            _animationStorageJson(
              vrmaBinary.length,
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
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'expressions': {
                'preset': {
                  'lookLeft': {'node': 0},
                },
              },
            },
          };
    final vrma = VrmAnimationAsset.tryParse(
      bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
      validation: VrmValidationMode.permissive,
    );
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(modelJson)));
    final binding = _FakeBinding();

    expect(
      vrma.validation.errors.map((d) => d.code),
      contains('vrma.invalidLookExpressionTarget'),
    );
    expect(
      vrma.validation.errors
          .singleWhere((d) => d.code == 'vrma.invalidLookExpressionTarget')
          .jsonPath,
      r'$.extensions.VRMC_vrm_animation.expressions.preset.lookLeft',
    );
    runtime.bind(binding);
    runtime.motion.playVrmAnimation(vrma.asset!);
    runtime.update(0.5);

    expect(binding.meshes[0]!.weights['0:0'], 0.0);
  });

  test('runtime skips invalid VRMA eye humanoid mapping', () {
    final modelJson = _minimalVrmJson();
    final nodes = modelJson['nodes']! as List<Map<String, Object?>>;
    nodes[2]['children'] = [15];
    nodes.add({'name': 'leftEye'});
    final vrm =
        (modelJson['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    final humanBones =
        (vrm['humanoid']! as Map<String, Object?>)['humanBones']!
            as Map<String, Object?>;
    humanBones['leftEye'] = {'node': 15};

    final vrmaBinary = _floats([
      0.0, 1.0, // input times
      0.0, 0.0, 0.0, 1.0, // identity
      0.0, 0.0, 0.7071068, 0.7071068, // invalid eye rotation
    ]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'nodes': [
              {'name': 'sourceLeftEye'},
            ],
          }
          ..addAll(
            _animationStorageJson(
              vrmaBinary.length,
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
                {'input': 0, 'output': 1},
              ],
            },
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'humanoid': {
                'humanBones': {
                  'leftEye': {'node': 0},
                },
              },
            },
          };
    final vrma = VrmAnimationAsset.tryParse(
      bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
      validation: VrmValidationMode.permissive,
    );
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(modelJson)));
    final binding = _FakeBinding();

    expect(
      vrma.validation.errors.map((d) => d.code),
      containsAll(['vrma.eyeBoneMapping', 'vrma.eyeBoneAnimation']),
    );
    expect(
      vrma.validation.errors
          .singleWhere((d) => d.code == 'vrma.eyeBoneMapping')
          .jsonPath,
      r'$.extensions.VRMC_vrm_animation.humanoid.humanBones.leftEye',
    );
    expect(
      vrma.validation.errors
          .singleWhere((d) => d.code == 'vrma.eyeBoneAnimation')
          .jsonPath,
      r'$.animations[0].channels[0].target.node',
    );
    runtime.bind(binding);
    runtime.motion.playVrmAnimation(vrma.asset!);
    runtime.update(1.0);

    expect(binding.nodes[15]!.localTransform.storage[0], 1.0);
    expect(binding.nodes[15]!.localTransform.storage[1], 0.0);
  });

  test('parses VRMA JSON and validates humanoid animation restrictions', () {
    final json = _minimalVrmaJson();
    final result = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(result.asset!.defaultAnimationIndex, 0);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'vrma.eyeBoneMapping',
        'vrma.eyeBoneAnimation',
        'vrma.humanoidScaleAnimation',
      ]),
    );
    expect(
      result.validation.errors
          .singleWhere((d) => d.code == 'vrma.humanoidScaleAnimation')
          .jsonPath,
      r'$.animations[0].channels[0].target.path',
    );
  });

  test('warns for VRMA humanoid rest-pose scale', () {
    final source = _minimalVrmJson();
    final nodes = [
      for (final node in source['nodes']! as List<Object?>)
        Map<String, Object?>.from(node! as Map),
    ];
    nodes[0]['scale'] = [2.0, 1.0, 1.0];
    final json = {
      'asset': {'version': '2.0'},
      'extensionsUsed': ['VRMC_vrm_animation'],
      'nodes': nodes,
      'extensions': {
        'VRMC_vrm_animation': {
          'specVersion': '1.0',
          'humanoid': {
            'humanBones': {
              for (final entry in _boneNodes.entries)
                entry.key.specName: {'node': entry.value},
            },
          },
        },
      },
    };

    final result = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );
    final warning = result.validation.warnings.singleWhere(
      (diagnostic) => diagnostic.code == 'vrma.humanoidRestScale',
    );

    expect(result.asset, isNotNull);
    expect(warning.jsonPath, r'$.nodes[0].scale');
    expect(warning.gltfNodeIndex, 0);
  });

  test('warns for reflected VRMA humanoid rest-pose matrix', () {
    final source = _minimalVrmJson();
    final nodes = [
      for (final node in source['nodes']! as List<Object?>)
        Map<String, Object?>.from(node! as Map),
    ];
    nodes[0]['matrix'] = [
      -1.0,
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
    ];
    final json = {
      'asset': {'version': '2.0'},
      'extensionsUsed': ['VRMC_vrm_animation'],
      'nodes': nodes,
      'extensions': {
        'VRMC_vrm_animation': {
          'specVersion': '1.0',
          'humanoid': {
            'humanBones': {
              for (final entry in _boneNodes.entries)
                entry.key.specName: {'node': entry.value},
            },
          },
        },
      },
    };

    final result = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );
    final warning = result.validation.warnings.singleWhere(
      (diagnostic) => diagnostic.code == 'vrma.humanoidRestScale',
    );

    expect(result.asset, isNotNull);
    expect(warning.jsonPath, r'$.nodes[0].matrix');
    expect(warning.gltfNodeIndex, 0);
  });

  test('reports malformed VRMA root extension object', () {
    final json = {
      'asset': {'version': '2.0'},
      'extensions': {'VRMC_vrm_animation': 'bad'},
    };

    final result = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('vrma.invalidExtensionObject'),
    );
  });

  test('reports malformed JSON VRMA instead of throwing', () {
    final result = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode('{')),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNull);
    expect(result.validation.errors.single.code, 'gltf.badJson');
  });

  test('reports missing VRMA specVersion', () {
    final json = {
      'asset': {'version': '2.0'},
      'extensions': {'VRMC_vrm_animation': <String, Object?>{}},
    };

    final result = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('vrma.missingSpecVersion'),
    );
    expect(
      result.validation.errors.map((d) => d.code),
      isNot(contains('vrma.unsupportedSpecVersion')),
    );
  });

  test('warns when a VRMA embeds a VRM root extension', () {
    final json = {
      'asset': {'version': '2.0'},
      'extensionsUsed': ['VRMC_vrm_animation', 'VRMC_vrm'],
      'extensions': {
        'VRMC_vrm_animation': {'specVersion': '1.0'},
        'VRMC_vrm': {'specVersion': '1.0'},
      },
    };

    final result = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
    );

    expect(result.asset, isNotNull);
    expect(result.validation.hasErrors, isFalse);
    expect(
      result.validation.warnings.map((d) => d.code),
      contains('vrma.embeddedVrmExtension'),
    );
    expect(
      result.validation.warnings
          .singleWhere((d) => d.code == 'vrma.embeddedVrmExtension')
          .jsonPath,
      r'$.extensions.VRMC_vrm',
    );
    expect(result.asset!.gltf.extensions['VRMC_vrm'], {'specVersion': '1.0'});
  });

  test('reports invalid VRMA expression containers', () {
    final invalidExpressions = <String, Object?>{
      'asset': {'version': '2.0'},
      'extensions': {
        'VRMC_vrm_animation': {'specVersion': '1.0', 'expressions': 'bad'},
      },
    };
    final invalidGroups = <String, Object?>{
      'asset': {'version': '2.0'},
      'extensions': {
        'VRMC_vrm_animation': {
          'specVersion': '1.0',
          'expressions': {
            'preset': 'bad',
            'custom': [<String, Object?>{}],
          },
        },
      },
    };

    final expressionResult = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(invalidExpressions))),
      validation: VrmValidationMode.permissive,
    );
    final groupResult = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(invalidGroups))),
      validation: VrmValidationMode.permissive,
    );

    expect(expressionResult.asset, isNotNull);
    expect(
      expressionResult.validation.errors.map((d) => d.code),
      contains('vrma.invalidExpressionsObject'),
    );
    expect(groupResult.asset, isNotNull);
    expect(
      groupResult.validation.errors.where(
        (d) => d.code == 'vrma.invalidExpressionGroup',
      ),
      hasLength(2),
    );
  });

  test('reports invalid VRMA LookAt object', () {
    final json = {
      'asset': {'version': '2.0'},
      'extensionsUsed': ['VRMC_vrm_animation'],
      'extensions': {
        'VRMC_vrm_animation': {'specVersion': '1.0', 'lookAt': 'bad'},
      },
    };

    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));
    final result = VrmAnimationAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );
    final strict = VrmAnimationAsset.tryParse(bytes: bytes);

    expect(result.asset, isNotNull);
    expect(strict.asset, isNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('vrma.invalidLookAtObject'),
    );
    expect(
      result.validation.errors.map((d) => d.code),
      isNot(contains('vrma.lookAtMissingNode')),
    );
  });

  test('reports explicit null VRMA object fields', () {
    final json = {
      'asset': {'version': '2.0'},
      'extensions': {
        'VRMC_vrm_animation': {
          'specVersion': '1.0',
          'humanoid': null,
          'expressions': null,
          'lookAt': null,
        },
      },
    };

    final result = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'vrm.invalidHumanoidObject',
        'vrma.invalidExpressionsObject',
        'vrma.invalidLookAtObject',
      ]),
    );
  });

  test('reports invalid VRMA expression and LookAt node mappings', () {
    final json = {
      'asset': {'version': '2.0'},
      'nodes': [
        {'name': 'onlyNode'},
      ],
      'animations': [
        {
          'channels': [
            {
              'target': {'node': 0, 'path': 'rotation'},
            },
          ],
        },
      ],
      'extensions': {
        'VRMC_vrm_animation': {
          'specVersion': '1.0',
          'expressions': {
            'preset': {
              'happy': {'node': 0},
              'lookUp': {'node': 0},
              'angry': {'node': 'bad'},
              'relaxed': {'node': 9},
              'sad': <String, Object?>{},
              'surprised': 'bad-expression',
              'notAPreset': {'node': 0},
            },
            'custom': {
              'happy': {'node': 0},
              'smile': {'node': 0},
              'wink': {'node': 'bad'},
              'wide': {'node': 9},
              'squint': <String, Object?>{},
              'smirk': 'bad-expression',
            },
          },
          'lookAt': {
            'node': 9,
            'offsetFromHeadBone': [0.0, 'bad'],
          },
        },
      },
    };

    final result = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'vrma.invalidLookExpressionTarget',
        'vrma.customExpressionPresetCollision',
        'vrma.presetExpressionMissingNode',
        'vrma.invalidPresetExpressionNode',
        'vrma.invalidPresetExpressionObject',
        'vrma.customExpressionMissingNode',
        'vrma.invalidCustomExpressionNode',
        'vrma.invalidCustomExpressionObject',
        'vrma.invalidLookAtNode',
        'vrma.invalidLookAtOffset',
        'vrma.expressionAnimationTargetPath',
      ]),
    );
    Iterable<String?> pathsFor(String code) => result.validation.errors
        .where((d) => d.code == code)
        .map((d) => d.jsonPath);

    expect(
      pathsFor('vrma.invalidLookExpressionTarget'),
      contains(r'$.extensions.VRMC_vrm_animation.expressions.preset.lookUp'),
    );
    expect(
      pathsFor('vrma.customExpressionPresetCollision'),
      contains(r'$.extensions.VRMC_vrm_animation.expressions.custom.happy'),
    );
    expect(
      pathsFor('vrma.presetExpressionMissingNode'),
      contains(r'$.extensions.VRMC_vrm_animation.expressions.preset.sad.node'),
    );
    expect(
      pathsFor('vrma.invalidPresetExpressionNode'),
      containsAll([
        r'$.extensions.VRMC_vrm_animation.expressions.preset.angry.node',
        r'$.extensions.VRMC_vrm_animation.expressions.preset.relaxed.node',
      ]),
    );
    expect(
      pathsFor('vrma.invalidPresetExpressionObject'),
      contains(r'$.extensions.VRMC_vrm_animation.expressions.preset.surprised'),
    );
    expect(
      pathsFor('vrma.customExpressionMissingNode'),
      contains(
        r'$.extensions.VRMC_vrm_animation.expressions.custom.squint.node',
      ),
    );
    expect(
      pathsFor('vrma.invalidCustomExpressionNode'),
      containsAll([
        r'$.extensions.VRMC_vrm_animation.expressions.custom.wink.node',
        r'$.extensions.VRMC_vrm_animation.expressions.custom.wide.node',
      ]),
    );
    expect(
      pathsFor('vrma.invalidCustomExpressionObject'),
      contains(r'$.extensions.VRMC_vrm_animation.expressions.custom.smirk'),
    );
    expect(
      result.validation.errors
          .singleWhere((d) => d.code == 'vrma.expressionAnimationTargetPath')
          .jsonPath,
      r'$.animations[0].channels[0].target.path',
    );
    expect(
      result.validation.warnings.map((d) => d.code),
      contains('vrma.unknownPresetExpression'),
    );
    expect(
      result.validation.warnings
          .singleWhere((d) => d.code == 'vrma.unknownPresetExpression')
          .jsonPath,
      r'$.extensions.VRMC_vrm_animation.expressions.preset.notAPreset',
    );
    expect(
      result.asset!.animation.presetExpressions,
      isNot(containsPair(VrmExpressionPreset.relaxed, 9)),
    );
    expect(
      result.asset!.animation.presetExpressions,
      isNot(containsPair(VrmExpressionPreset.lookUp, 0)),
    );
    expect(
      result.asset!.animation.customExpressions,
      isNot(containsPair('wide', 9)),
    );
    expect(result.asset!.animation.customExpressions, containsPair('smile', 0));
    expect(
      () =>
          result.asset!.animation.presetExpressions[VrmExpressionPreset.aa] = 0,
      throwsUnsupportedError,
    );
    expect(
      () => result.asset!.animation.customExpressions['other'] = 0,
      throwsUnsupportedError,
    );
    expect(result.asset!.animation.lookAt, isNull);
  });

  test('reports invalid VRMA LookAt animation target path', () {
    final json = {
      'asset': {'version': '2.0'},
      'nodes': [
        {'name': 'lookAt'},
      ],
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
      'extensions': {
        'VRMC_vrm_animation': {
          'specVersion': '1.0',
          'lookAt': {'node': 0},
        },
      },
    };

    final result = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('vrma.lookAtAnimationTargetPath'),
    );
    expect(
      result.validation.errors
          .singleWhere((d) => d.code == 'vrma.lookAtAnimationTargetPath')
          .jsonPath,
      r'$.animations[0].channels[0].target.path',
    );
  });

  test('warns for VRMA expression weights outside range', () {
    final binary = _floats([0.0, 1.2, 0.0, 0.0]);
    final json =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {'name': 'happy'},
            ],
          }
          ..addAll(
            _animationStorageJson(binary.length, [
              [0, 4],
              [4, 12],
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
                {'input': 0, 'output': 1},
              ],
            },
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'expressions': {
                'preset': {
                  'happy': {'node': 0},
                },
              },
            },
          };

    final result = VrmAnimationAsset.tryParse(
      bytes: _glb(json, binaryChunk: binary),
    );

    expect(result.asset, isNotNull);
    expect(result.validation.hasErrors, isFalse);
    expect(
      result.validation.warnings.map((d) => d.code),
      contains('vrma.expressionWeightOutOfRange'),
    );
    expect(
      result.validation.warnings
          .singleWhere((d) => d.code == 'vrma.expressionWeightOutOfRange')
          .jsonPath,
      r'$.animations[0].samplers[0].output',
    );
  });

  test('allows VRMA LookAt offset without a node', () {
    final json = {
      'asset': {'version': '2.0'},
      'extensionsUsed': ['VRMC_vrm_animation'],
      'extensions': {
        'VRMC_vrm_animation': {
          'specVersion': '1.0',
          'extras': {
            'tags': ['source'],
          },
          'lookAt': {
            'offsetFromHeadBone': [0.0, 0.0, 0.0],
          },
        },
      },
    };

    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));
    final result = VrmAnimationAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );
    final strict = VrmAnimationAsset.tryParse(bytes: bytes);

    expect(result.asset, isNotNull);
    expect(strict.asset, isNotNull);
    expect(result.validation.hasErrors, isFalse);
    expect(result.asset!.animation.lookAt, isNull);
    expect(result.asset!.animation.offsetFromHeadBone, [0.0, 0.0, 0.0]);
    expect(
      () => result.asset!.animation.offsetFromHeadBone.add(1.0),
      throwsUnsupportedError,
    );
    expect(
      () => result.asset!.animation.raw['extra'] = true,
      throwsUnsupportedError,
    );
    final rawExtras =
        result.asset!.animation.raw['extras']! as Map<String, Object?>;
    final rawTags = rawExtras['tags']! as List<Object?>;
    expect(() => rawExtras['other'] = true, throwsUnsupportedError);
    expect(() => rawTags.add('copy'), throwsUnsupportedError);
  });

  test('allows VRMA assets without humanoid mappings', () {
    final json = {
      'asset': {'version': '2.0'},
      'extensionsUsed': ['VRMC_vrm_animation'],
      'extensions': {
        'VRMC_vrm_animation': {'specVersion': '1.0'},
      },
    };

    final result = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
    );

    expect(result.validation.hasErrors, isFalse);
    expect(result.asset, isNotNull);
  });

  test('reports VRMA humanoid object without humanBones', () {
    final json = {
      'asset': {'version': '2.0'},
      'extensions': {
        'VRMC_vrm_animation': {'specVersion': '1.0', 'humanoid': {}},
      },
    };

    final result = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('vrma.missingHumanoidHumanBones'),
    );
  });

  test('strict mode rejects VRMA humanoid missing required bones', () {
    final json = {
      'asset': {'version': '2.0'},
      'extensionsUsed': ['VRMC_vrm_animation'],
      'nodes': [
        {'name': 'sourceHips'},
      ],
      'extensions': {
        'VRMC_vrm_animation': {
          'specVersion': '1.0',
          'humanoid': {
            'humanBones': {
              'hips': {'node': 0},
            },
          },
        },
      },
    };

    final strict = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
    );
    final permissive = VrmAnimationAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(strict.asset, isNull);
    expect(permissive.asset, isNotNull);
    expect(
      strict.validation.errors.map((d) => d.code),
      contains('vrm.missingRequiredHumanoidBone'),
    );
  });
}

VrmAnimationAsset _hipsTranslationVrma(double x, {double? secondX}) {
  final binary = _floats([
    0.0,
    1.0,
    0.0,
    0.0,
    0.0,
    x,
    0.0,
    0.0,
    if (secondX != null) ...[0.0, 0.0, 0.0, secondX, 0.0, 0.0],
  ]);
  final json =
      <String, Object?>{
        'asset': {'version': '2.0'},
        'extensionsUsed': ['VRMC_vrm_animation'],
        'nodes': [
          {'name': 'sourceHips'},
        ],
      }..addAll(
        _animationStorageJson(binary.length, [
          [0, 8],
          [8, 24],
          if (secondX != null) [32, 24],
        ]),
      );
  json['animations'] = [
    for (final output in [1, if (secondX != null) 2])
      {
        'channels': [
          {
            'sampler': 0,
            'target': {'node': 0, 'path': 'translation'},
          },
        ],
        'samplers': [
          {'input': 0, 'output': output},
        ],
      },
  ];
  json['extensions'] = {
    'VRMC_vrm_animation': {
      'specVersion': '1.0',
      'humanoid': {
        'humanBones': {
          'hips': {'node': 0},
        },
      },
    },
  };
  return VrmAnimationAsset.parse(
    bytes: _glb(json, binaryChunk: binary),
    validation: VrmValidationMode.permissive,
  );
}

final class _OffsetRetargeter implements VrmHumanoidRetargeter {
  VrmHumanoidBone? bone;
  double? hipsTranslationScale;

  @override
  VrmRetargetedBonePose retargetBone({
    required VrmHumanoidBone bone,
    required GltfNodePose sourcePose,
    required GltfNode sourceRestNode,
    required List<double> sourceRestWorldRotation,
    required GltfNode destinationRestNode,
    required List<double> destinationRestWorldRotation,
    required double hipsTranslationScale,
  }) {
    this.bone = bone;
    this.hipsTranslationScale = hipsTranslationScale;
    return VrmRetargetedBonePose(
      nodePose: GltfNodePose(translation: [4.0, 5.0, 6.0]),
      modelRootPose: GltfNodePose(translation: [7.0, 8.0, 9.0]),
    );
  }
}
