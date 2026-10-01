part of '../flvtterm_test.dart';

void armSpacingTests() {
  group('proportional arm spacing', () {
    // A motion made on broad shoulders (0.19 m from the centre over hips
    // 0.095 m) replayed on narrow ones (0.08 m over 0.07 m).
    final source = VrmAnimationAsset.parse(
      bytes: _glb(_armSkeletonJson(shoulder: .19, hip: .095, animation: true)),
      validation: VrmValidationMode.permissive,
    );
    final model = VrmModel.parseGlb(
      _glb(_armSkeletonJson(shoulder: .08, hip: .07, animation: false)),
    );
    const upperArm = .25;
    const forearm = .22;

    // Rest arms point sideways; a turn of -(90 - out) degrees about +Z hangs
    // the left arm [out] degrees from vertical, the right one mirrored.
    VrmSampledHumanoidMotion arms(double outDegrees) =>
        VrmSampledHumanoidMotion(
          restPose: source,
          duration: const Duration(seconds: 1),
          sample: (_) {
            final half = (90 - outDegrees) * math.pi / 360;
            return VrmHumanoidSample(
              rotations: {
                VrmHumanoidBone.leftUpperArm: VrmVector4(
                  0,
                  0,
                  -math.sin(half),
                  math.cos(half),
                ),
                VrmHumanoidBone.rightUpperArm: VrmVector4(
                  0,
                  0,
                  math.sin(half),
                  math.cos(half),
                ),
              },
            );
          },
        );

    // The hanging angle from vertical of the arm whose local rotation about Z
    // the binding holds.
    double hangingDegrees(_FakeBinding binding, VrmHumanoidBone bone) {
      final node = model.vrm.humanoid.nodeFor(bone)!;
      final storage = binding.nodes[node]!.localTransform.storage;
      final angle = math.atan2(storage[1], storage[0]) * 180 / math.pi;
      return bone == VrmHumanoidBone.leftUpperArm ? 90 + angle : 90 - angle;
    }

    double run(double outDegrees, {required bool spacing}) {
      final runtime = VrmRuntime(model);
      final binding = _FakeBinding();
      runtime.bind(binding);
      runtime.motion.proportionalArmSpacing = spacing;
      runtime.motion.play(arms(outDegrees), speed: 0);
      runtime.update(0);
      final left = hangingDegrees(binding, VrmHumanoidBone.leftUpperArm);
      final right = hangingDegrees(binding, VrmHumanoidBone.rightUpperArm);
      expect(right, closeTo(left, 1e-6));
      return left;
    }

    test('is off by default and copies joint angles', () {
      final runtime = VrmRuntime(model);
      expect(runtime.motion.proportionalArmSpacing, isFalse);
      expect(run(16, spacing: false), closeTo(16, 1e-6));
    });

    test('keeps a hanging hand at the source hip-relative distance', () {
      const out = 16.0;
      final sourceWrist =
          .19 + (upperArm + forearm) * math.sin(out * math.pi / 180);
      final wanted = sourceWrist / .095 * .07;
      final expected =
          math.asin((wanted - .08) / (upperArm + forearm)) * 180 / math.pi;
      // Narrow shoulders need the arm further out than the source's angle.
      expect(expected, greaterThan(out + 3));
      expect(run(out, spacing: true), closeTo(expected, 1e-6));
    });

    test('leaves a raised arm at its joint angles', () {
      // Horizontal arms are 90 degrees from hanging, past the 60-degree fade.
      expect(run(90, spacing: true), closeTo(90, 1e-6));
    });

    test('limits the turn to 25 degrees', () {
      final wide = VrmModel.parseGlb(
        _glb(_armSkeletonJson(shoulder: .02, hip: .2, animation: false)),
      );
      final runtime = VrmRuntime(wide);
      final binding = _FakeBinding();
      runtime.bind(binding);
      runtime.motion.proportionalArmSpacing = true;
      runtime.motion.play(arms(0), speed: 0);
      runtime.update(0);
      final node = wide.vrm.humanoid.nodeFor(VrmHumanoidBone.leftUpperArm)!;
      final storage = binding.nodes[node]!.localTransform.storage;
      final angle = math.atan2(storage[1], storage[0]) * 180 / math.pi;
      expect(90 + angle, closeTo(25, 1e-6));
    });
  });
}

/// A humanoid whose arms reach sideways from shoulders [shoulder] metres from
/// the centre, with upper legs [hip] metres from it.
Map<String, Object?> _armSkeletonJson({
  required double shoulder,
  required double hip,
  required bool animation,
}) {
  final nodes = <Map<String, Object?>>[
    {
      'name': 'hips',
      'translation': [0.0, 1.0, 0.0],
      'children': [1, 3, 6],
    },
    {
      'name': 'spine',
      'translation': [0.0, .1, 0.0],
      'children': [2, 9, 12],
    },
    {
      'name': 'head',
      'translation': [0.0, .5, 0.0],
    },
    for (final sign in [1.0, -1.0]) ...[
      {
        'name': 'upperLeg',
        'translation': [sign * hip, -.05, 0.0],
        'children': [sign > 0 ? 4 : 7],
      },
      {
        'name': 'lowerLeg',
        'translation': [0.0, -.4, 0.0],
        'children': [sign > 0 ? 5 : 8],
      },
      {
        'name': 'foot',
        'translation': [0.0, -.4, 0.0],
      },
    ],
    for (final sign in [1.0, -1.0]) ...[
      {
        'name': 'upperArm',
        'translation': [sign * shoulder, .35, 0.0],
        'children': [sign > 0 ? 10 : 13],
      },
      {
        'name': 'lowerArm',
        'translation': [sign * .25, 0.0, 0.0],
        'children': [sign > 0 ? 11 : 14],
      },
      {
        'name': 'hand',
        'translation': [sign * .22, 0.0, 0.0],
      },
    ],
  ];
  final humanBones = {
    for (final entry in _boneNodes.entries)
      entry.key.specName: {'node': entry.value},
  };
  return {
    'asset': {'version': '2.0'},
    'scene': 0,
    'scenes': [
      {
        'nodes': [0],
      },
    ],
    'nodes': nodes,
    if (animation) ...{
      'extensionsUsed': ['VRMC_vrm_animation'],
      'extensions': {
        'VRMC_vrm_animation': {
          'specVersion': '1.0',
          'humanoid': {'humanBones': humanBones},
        },
      },
    } else ...{
      'extensionsUsed': ['VRMC_vrm'],
      'extensionsRequired': ['VRMC_vrm'],
      'extensions': {
        'VRMC_vrm': {
          'specVersion': '1.0',
          'meta': {
            'name': 'Avatar',
            'authors': ['Author'],
            'licenseUrl': 'https://example.com/license',
          },
          'humanoid': {'humanBones': humanBones},
        },
      },
    },
  };
}
