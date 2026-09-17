part of '../flvtterm_test.dart';

void sampledMotionTests() {
  group('sampled humanoid motion', () {
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
