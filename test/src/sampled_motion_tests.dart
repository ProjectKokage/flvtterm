part of '../flvtterm_test.dart';

void sampledMotionTests() {
  group('sampled humanoid motion', () {
    test(
      'captures the current body for an uninterrupted sampled transition',
      () {
        final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
        final binding = _FakeBinding();
        runtime.bind(binding);
        final layer = runtime.motion.addAdditiveLayer(
          VrmProgrammaticPose(
            nodePoses: {
              2: GltfNodePose(rotation: [0, 0, .6, .8]),
            },
            modelRootTranslation: const VrmVector3(2, 0, 0),
          ),
        );
        runtime.update(0);
        final before = binding.nodes[2]!.localTransform;
        final captured = runtime.captureHumanoidPose({
          VrmHumanoidBone.head,
          VrmHumanoidBone.upperChest, // Not mapped by this avatar.
        })!;
        expect(captured.nodePoses.keys, [2]);
        expect(captured.morphWeights, isEmpty);
        expect(captured.expressionWeights, isEmpty);
        expect(captured.lookAtYawDegrees, isNull);
        expect(captured.modelRootTranslation!.x, 2);
        runtime.motion.removeAdditiveLayer(layer);
        runtime.motion.play(captured);
        runtime.motion.play(
          _sampledHips(6),
          fadeIn: const Duration(seconds: 1),
        );
        runtime.update(0);
        _expectSampledMatrix(binding.nodes[2]!.localTransform, before);
        expect(binding.modelRootMotionTransform.storage[12], 2);
        runtime.update(.5);
        expect(binding.modelRootMotionTransform.storage[12], 4);
        // The source head rotates through half of its original Z angle.
        expect(binding.nodes[2]!.localTransform.storage[0], closeTo(.8, 1e-9));
        expect(binding.nodes[2]!.localTransform.storage[1], closeTo(.6, 1e-9));
        runtime.update(.5);
        expect(binding.modelRootMotionTransform.storage[12], 6);
        _expectSampledMatrix(
          binding.nodes[2]!.localTransform,
          VrmMatrix4.identity(),
        );
        // Capture data must not track subsequent runtime mutations.
        expect(captured.nodePoses[2]!.rotation, orderedEquals([0, 0, .6, .8]));
      },
    );

    test('captures mirrored nonuniform TRS and rejects invalid transforms', () {
      final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
      const bones = {VrmHumanoidBone.head};
      expect(runtime.captureHumanoidPose(bones), isNull);
      final binding = _FakeBinding();
      runtime.bind(binding);
      runtime.update(0);
      // Z rotation +90 degrees, scale (-2, 3, 4), translation (5, 6, 7).
      final transform = VrmMatrix4([
        0,
        -2,
        0,
        0,
        -3,
        0,
        0,
        0,
        0,
        0,
        4,
        0,
        5,
        6,
        7,
        1,
      ]);
      binding.nodes[2]!.localTransform = transform;
      final captured = runtime.captureHumanoidPose(bones)!;
      expect(captured.nodePoses[2]!.scale, [-2, 3, 4]);
      runtime.motion.play(captured);
      runtime.update(0);
      _expectSampledMatrix(binding.nodes[2]!.localTransform, transform);
      for (final (index, value) in [
        (0, double.nan),
        (12, double.infinity),
        (0, 0.0), // Singular.
        (4, .25), // Shear.
        (3, .25), // Not affine.
      ]) {
        final values = List<double>.of(VrmMatrix4.identity().storage);
        values[index] = value;
        binding.nodes[2]!.localTransform = VrmMatrix4(values);
        expect(runtime.captureHumanoidPose(bones), isNull);
      }
      binding.nodes[2]!.localTransform = VrmMatrix4.identity();
      binding.modelRootMotionTransform = VrmMatrix4([
        ...VrmMatrix4.identity().storage.take(12),
        double.nan,
        0,
        0,
        1,
      ]);
      expect(runtime.captureHumanoidPose(bones), isNull);
      runtime.bind(_FakeBinding());
      runtime.update(0);
      expect(runtime.captureHumanoidPose(bones), isNotNull);
      runtime.unbind();
      expect(runtime.captureHumanoidPose(bones), isNull);
    });

    test('isolates target and blended roots and never resamples a release', () {
      final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
      final binding = _FakeBinding();
      runtime.bind(binding);
      runtime.motion.play(
        VrmProgrammaticPose(modelRootTranslation: const VrmVector3(2, 0, 0)),
      );
      var calls = 0;
      runtime.motion.play(
        _sampledHips(6, sampleTime: (_) => calls++),
        fadeIn: const Duration(seconds: 1),
      );
      runtime.motion.addAdditiveLayer(
        VrmProgrammaticPose(modelRootTranslation: const VrmVector3(20, 0, 0)),
        weight: .5,
      );
      expect(runtime.motion.sampleModelRootTranslation()!.x, 2);
      expect(runtime.motion.sampleModelRootTranslation(blended: false)!.x, 6);
      expect(runtime.motion.position, Duration.zero);
      runtime.update(.5);
      expect(runtime.motion.sampleModelRootTranslation()!.x, 4);
      expect(binding.modelRootMotionTransform.storage[12], 14);
      runtime.motion.stop(fadeOut: const Duration(seconds: 1));
      final atStop = calls;
      runtime.update(.5);
      expect(runtime.motion.sampleModelRootTranslation()!.x, 2);
      expect(runtime.motion.sampleModelRootTranslation(blended: false), isNull);
      expect(binding.modelRootMotionTransform.storage[12], 12);
      expect(calls, atStop);
      runtime.update(.5);
      expect(runtime.motion.sampleModelRootTranslation(), isNull);
      expect(binding.modelRootMotionTransform.storage[12], 10);
      expect(calls, atStop);
      for (final value in [double.nan, double.infinity, -double.infinity]) {
        expect(
          () => VrmProgrammaticPose(
            modelRootTranslation: VrmVector3(0, value, 0),
          ),
          throwsArgumentError,
        );
      }
    });

    for (final legacy in [false, true]) {
      for (final rootBinding in [false, true]) {
        test('matches VRMA with legacy=$legacy rootBinding=$rootBinding', () {
          final model = VrmModel.parseGlb(
            _glb(legacy ? _minimalVrm0Json() : _minimalVrmJson()),
          );
          final fixture = _sampledRetargetFixture();
          final clip = VrmRuntime(model);
          final sampled = VrmRuntime(model);
          final clipBinding = _FakeBinding();
          final sampledBinding = _FakeBinding();
          clip.bind(
            rootBinding ? clipBinding : _Vrm0FallbackBinding(clipBinding),
          );
          sampled.bind(
            rootBinding ? sampledBinding : _Vrm0FallbackBinding(sampledBinding),
          );
          clip.motion.play(fixture.clip, speed: 0, hipsTranslationScale: 2);
          sampled.motion.play(
            VrmSampledHumanoidMotion(
              restPose: fixture.rest,
              duration: const Duration(seconds: 1),
              sample: _retargetSample,
            ),
            speed: 0,
            hipsTranslationScale: 2,
          );
          for (final milliseconds in [0, 250, 800, 1000]) {
            final position = Duration(milliseconds: milliseconds);
            clip.motion.seek(position);
            sampled.motion.seek(position);
            clip.update(0);
            sampled.update(0);
            for (final node in model.gltf.nodes) {
              _expectSampledMatrix(
                sampledBinding.nodes[node.index]!.localTransform,
                clipBinding.nodes[node.index]!.localTransform,
              );
            }
            _expectSampledMatrix(
              sampledBinding.modelRootMotionTransform,
              clipBinding.modelRootMotionTransform,
            );
          }
          if (rootBinding && !legacy) {
            // Parent +90 Y rotates the source (.3, .2, .4) rest delta.
            final root = sampledBinding.modelRootMotionTransform.storage;
            expect(root[12], closeTo(.8, 1e-6));
            expect(root[13], closeTo(.4, 1e-6));
            expect(root[14], closeTo(-.6, 1e-6));
            expect(sampledBinding.nodes[0]!.localTransform.storage[12], 0);
            // upperChest is absent from the destination. Its motion still
            // reaches the common descendant head through semantic retargeting.
            expect(
              sampledBinding.nodes[2]!.localTransform.storage[0],
              isNot(closeTo(1, 1e-6)),
            );
          }
        });
      }
    }

    test('owns an exact duration, pause, seek, reverse and completion', () {
      final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
      runtime.bind(_FakeBinding());
      final times = <double>[];
      final source = _sampledHips(
        1,
        sampleTime: times.add,
        duration: const Duration(microseconds: 1234567),
      );
      var completed = 0;
      runtime.motion.onCompleted = () => completed++;
      runtime.motion.play(source);
      runtime.update(.25);
      runtime.motion.pause();
      runtime.update(1);
      expect(times.last, .25);
      runtime.motion.resume();
      runtime.update(5);
      expect(runtime.motion.position.inMicroseconds, 1234567);
      expect(times.last, 1.234567);
      expect(completed, 1);
      runtime.update(1);
      expect(completed, 1);
      runtime.motion.play(source, speed: -1, startTimeSeconds: .1);
      runtime.update(.2);
      expect(times.last, 0);
      expect(completed, 2);
      runtime.motion.play(source, speed: 0);
      runtime.motion.seek(const Duration(seconds: 8));
      runtime.update(8);
      expect(times.last, 1.234567);
    });

    test('crossfades, priority and stop release the sampled callback', () {
      final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
      final binding = _FakeBinding();
      runtime.bind(binding);
      var sampledCalls = 0;
      runtime.motion.play(
        _sampledHips(4, sampleTime: (_) => sampledCalls++),
        priority: 5,
      );
      runtime.update(0);
      runtime.motion.play(_sampledHips(100), priority: 4);
      runtime.update(0);
      expect(binding.modelRootMotionTransform.storage[12], 4);
      runtime.motion.play(
        _hipsTranslationVrma(2),
        speed: 0,
        startTimeSeconds: 1,
        priority: 5,
        fadeIn: const Duration(seconds: 1),
      );
      final callsAtReplacement = sampledCalls;
      runtime.update(.5);
      expect(binding.modelRootMotionTransform.storage[12], 3);
      runtime.motion.play(
        _sampledHips(7),
        priority: 5,
        fadeIn: const Duration(seconds: 1),
      );
      runtime.update(.5);
      expect(binding.modelRootMotionTransform.storage[12], 5);
      expect(sampledCalls, callsAtReplacement);
      runtime.motion.stop(fadeOut: const Duration(seconds: 1));
      runtime.update(.5);
      expect(binding.modelRootMotionTransform.storage[12], 2.5);
      runtime.update(.5);
      expect(binding.modelRootMotionTransform.storage[12], 0);
      expect(runtime.motion.isPlaying, isFalse);
    });

    test('masks root motion and isolates additive command root movement', () {
      final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
      final binding = _FakeBinding();
      runtime.bind(binding);
      runtime.motion.play(
        _sampledHips(9),
        humanoidMask: {VrmHumanoidBone.head},
      );
      runtime.update(0);
      expect(binding.modelRootMotionTransform.storage[12], 0);
      runtime.motion.play(_sampledHips(1));
      final layer = runtime.motion.addAdditiveLayer(
        _sampledHips(8),
        weight: .25,
        speed: 0,
      );
      runtime.motion.addAdditiveLayer(
        _hipsTranslationVrma(40),
        startTimeSeconds: 1,
        speed: 0,
      );
      runtime.update(0);
      expect(binding.modelRootMotionTransform.storage[12], 43);
      expect(runtime.motion.additiveLayerModelRootTranslation(layer)!.x, 2);
      runtime.motion.removeAdditiveLayer(layer);
      runtime.update(0);
      expect(binding.modelRootMotionTransform.storage[12], 41);
      expect(runtime.motion.additiveLayerModelRootTranslation(layer), isNull);
    });

    test('uses the injected retargeter and ignores reference animation', () {
      final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
      final binding = _FakeBinding();
      final retargeter = _OffsetRetargeter();
      runtime.motion.vrmaRetargeter = retargeter;
      runtime.bind(binding);
      runtime.motion.play(_sampledHips(1), hipsTranslationScale: 3);
      runtime.update(0);
      expect(retargeter.bone, VrmHumanoidBone.hips);
      expect(retargeter.hipsTranslationScale, 3);
      expect(binding.modelRootMotionTransform.storage[12], 7);
      expect(binding.nodes[0]!.localTransform.storage[12], 4);
    });

    test(
      'reference face bindings cannot take expression or gaze ownership',
      () {
        final json = _minimalVrmJson(
          expressions: {
            'preset': {
              'happy': <String, Object?>{},
              'lookDown': <String, Object?>{},
            },
          },
        );
        final vrm =
            (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
                as Map<String, Object?>;
        vrm['lookAt'] = _lookAtJson(type: 'expression');
        final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
        runtime.bind(_FakeBinding());
        runtime.expressions.setPreset(VrmExpressionPreset.happy, .2);
        final source = VrmSampledHumanoidMotion(
          restPose: _sampledRetargetFixture(faceAliases: true).rest,
          duration: const Duration(seconds: 1),
          sample: _retargetSample,
        );
        runtime.motion.play(source, startTimeSeconds: 1, speed: 0);
        runtime.motion.addAdditiveLayer(source, startTimeSeconds: 1, speed: 0);
        runtime.update(0);
        expect(runtime.expressions.evaluate()['happy'], .2);
        expect(runtime.expressions.evaluate()['lookDown'], 0);
        runtime.lookAt.setYawPitch(yawDegrees: 0, pitchDegrees: 45);
        runtime.update(0);
        expect(runtime.expressions.evaluate()['happy'], .2);
        expect(runtime.expressions.evaluate()['lookDown'], .5);
      },
    );

    test(
      'rejects nonfinite, nonunit, eye and unmapped input; copies samples',
      () {
        for (final q in [
          VrmVector4(double.nan, 0, 0, 1),
          VrmVector4(0, double.infinity, 0, 1),
          const VrmVector4(0, 0, 0, 0),
          const VrmVector4(0, 0, 0, 2),
        ]) {
          expect(
            () => VrmHumanoidSample(rotations: {VrmHumanoidBone.hips: q}),
            throwsArgumentError,
          );
        }
        expect(
          () => VrmHumanoidSample(
            rotations: {VrmHumanoidBone.leftEye: const VrmVector4(0, 0, 0, 1)},
          ),
          throwsArgumentError,
        );
        expect(
          () => VrmHumanoidSample(
            rotations: const {},
            hipsTranslation: VrmVector3(double.infinity, 0, 0),
          ),
          throwsArgumentError,
        );
        expect(
          () => _sampledHips(1, duration: Duration.zero),
          throwsArgumentError,
        );
        expect(
          () => _sampledHips(1, duration: Duration(microseconds: 1 << 53)),
          throwsArgumentError,
        );
        final rotations = {VrmHumanoidBone.head: const VrmVector4(0, 0, 0, 1)};
        final pose = VrmHumanoidSample(rotations: rotations);
        rotations.clear();
        expect(pose.rotations, hasLength(1));
        expect(() => pose.rotations.clear(), throwsUnsupportedError);
        final runtime = VrmRuntime(VrmModel.parseGlb(_glb(_minimalVrmJson())));
        runtime.bind(_FakeBinding());
        runtime.motion.play(
          VrmSampledHumanoidMotion(
            restPose: _hipsTranslationVrma(1),
            duration: const Duration(seconds: 1),
            sample: (_) => pose,
          ),
        );
        expect(() => runtime.update(0), throwsStateError);
      },
    );
  });
}

VrmSampledHumanoidMotion _sampledHips(
  double x, {
  void Function(double)? sampleTime,
  Duration duration = const Duration(seconds: 10),
}) => VrmSampledHumanoidMotion(
  restPose: _hipsTranslationVrma(100),
  duration: duration,
  sample: (time) {
    sampleTime?.call(time);
    return VrmHumanoidSample(
      rotations: const {},
      hipsTranslation: VrmVector3(x, 0, 0),
    );
  },
);

VrmHumanoidSample _retargetSample(double time) => VrmHumanoidSample(
  hipsTranslation: VrmVector3(.3 * time, 1 + .2 * time, .4 * time),
  rotations: {
    VrmHumanoidBone.upperChest: VrmVector4(
      math.sin(math.pi / 4 * time),
      0,
      0,
      math.cos(math.pi / 4 * time),
    ),
    VrmHumanoidBone.head: VrmVector4(
      0,
      math.sin(math.pi / 8 * time),
      0,
      math.cos(math.pi / 8 * time),
    ),
  },
);

({VrmAnimationAsset clip, VrmAnimationAsset rest}) _sampledRetargetFixture({
  bool faceAliases = false,
}) {
  const half = .7071067811865476;
  final json = <String, Object?>{
    'asset': {'version': '2.0'},
    'extensionsUsed': ['VRMC_vrm_animation'],
    'nodes': [
      {
        'rotation': [0.0, half, 0.0, half],
        'children': [1],
      },
      {
        'translation': [0.0, 1.0, 0.0],
        'rotation': [0.0, 0.0, half, half],
        'children': [2],
      },
      {
        'children': [3],
      },
      {
        'children': [4],
      },
      <String, Object?>{},
    ],
    'extensions': {
      'VRMC_vrm_animation': {
        'specVersion': '1.0',
        if (faceAliases) ...{
          'expressions': {
            'preset': {
              'happy': {'node': 1},
            },
          },
          'lookAt': {'node': 3},
        },
        'humanoid': {
          'humanBones': {
            'hips': {'node': 1},
            'spine': {'node': 2},
            'upperChest': {'node': 3},
            'head': {'node': 4},
          },
        },
      },
    },
  };
  final rest = VrmAnimationAsset.parse(
    bytes: _glb(json),
    validation: VrmValidationMode.permissive,
  );
  final finalPose = _retargetSample(1);
  final binary = _floats([
    0,
    1,
    0,
    1,
    0,
    .3,
    1.2,
    .4,
    for (final q in finalPose.rotations.values) ...[
      0,
      0,
      0,
      1,
      q.x,
      q.y,
      q.z,
      q.w,
    ],
  ]);
  json.addAll(
    _animationStorageJson(
      binary.length,
      [
        [0, 8],
        [8, 24],
        [32, 32],
        [64, 32],
      ],
      accessorTypes: ['SCALAR', 'VEC3', 'VEC4', 'VEC4'],
    ),
  );
  json['animations'] = [
    {
      'channels': [
        {
          'sampler': 0,
          'target': {'node': 1, 'path': 'translation'},
        },
        {
          'sampler': 1,
          'target': {'node': 3, 'path': 'rotation'},
        },
        {
          'sampler': 2,
          'target': {'node': 4, 'path': 'rotation'},
        },
      ],
      'samplers': [
        for (var i = 1; i <= 3; i++) {'input': 0, 'output': i},
      ],
    },
  ];
  return (
    rest: rest,
    clip: VrmAnimationAsset.parse(
      bytes: _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    ),
  );
}

void _expectSampledMatrix(VrmMatrix4 actual, VrmMatrix4 expected) {
  for (var i = 0; i < 16; i++) {
    expect(actual.storage[i], closeTo(expected.storage[i], 1e-6));
  }
}
