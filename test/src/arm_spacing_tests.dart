part of '../flvtterm_test.dart';

void armSpacingTests() {
  group('hands kept clear of the body', () {
    // The motion's skeleton: its proportions no longer matter.
    final source = VrmAnimationAsset.parse(
      bytes: _glb(_armSkeletonJson(shoulder: .19, hip: .095)),
      validation: VrmValidationMode.permissive,
    );
    const shoulder = .08;
    const arm = .25 + .22;
    // Head 1.6 m, feet at 0.15 m: the clearance scales to 1.45 m.
    const clearance = .03 * 1.45 / 1.6;

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

    // The hanging angle from vertical of each arm the binding holds.
    (double, double) hangingDegrees(VrmModel model, _FakeBinding binding) {
      double angle(VrmHumanoidBone bone) {
        final node = model.vrm.humanoid.nodeFor(bone)!;
        final storage = binding.nodes[node]!.localTransform.storage;
        return math.atan2(storage[1], storage[0]) * 180 / math.pi;
      }

      return (
        90 + angle(VrmHumanoidBone.leftUpperArm),
        90 - angle(VrmHumanoidBone.rightUpperArm),
      );
    }

    double run(double outDegrees, {double? thigh, bool clear = true}) {
      final model = VrmModel.parseGlb(
        _armSkeletonGlb(shoulder: shoulder, hip: .07, thigh: thigh),
      );
      final runtime = VrmRuntime(model);
      final binding = _FakeBinding();
      runtime.bind(binding);
      runtime.motion.keepHandsClear = clear;
      runtime.motion.play(arms(outDegrees), speed: 0);
      runtime.update(0);
      final (left, right) = hangingDegrees(model, binding);
      expect(right, closeTo(left, 1e-6));
      return left;
    }

    double degreesToReach(double wrist) =>
        math.asin((wrist - shoulder) / arm) * 180 / math.pi;

    test('is off by default and copies joint angles', () {
      final runtime = VrmRuntime(
        VrmModel.parseGlb(_armSkeletonGlb(shoulder: shoulder, hip: .07)),
      );
      expect(runtime.motion.keepHandsClear, isFalse);
      expect(run(16, thigh: .22, clear: false), closeTo(16, 1e-6));
    });

    test('moves a hanging hand just clear of the thigh surface', () {
      // At 16 degrees the wrist is 0.21 m out, inside a 0.22 m thigh.
      expect(degreesToReach(.22 + clearance), greaterThan(16));
      expect(
        run(16, thigh: .22),
        closeTo(degreesToReach(.22 + clearance), 1e-6),
      );
    });

    test('leaves a hand that is already clear', () {
      expect(run(16, thigh: .15), closeTo(16, 1e-6));
    });

    test('leaves a raised arm at its joint angles', () {
      // Horizontal arms are 90 degrees from hanging, past the 60-degree fade.
      expect(run(90, thigh: .4), closeTo(90, 1e-6));
    });

    test('limits the turn to 25 degrees', () {
      expect(run(0, thigh: .4), closeTo(25, 1e-6));
    });

    test('leaves an avatar without body skin unchanged', () {
      expect(run(16), closeTo(16, 1e-6));
    });
  });
}

/// A humanoid whose arms reach sideways from shoulders [shoulder] metres from
/// the centre, with upper legs [hip] metres from it. Joints 0 to 14 follow
/// `_boneNodes`; feet stand at 0.15 m and the head at 1.6 m.
Map<String, Object?> _armSkeletonJson({
  required double shoulder,
  required double hip,
  bool vrm = false,
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
    if (!vrm) ...{
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

/// The avatar of [_armSkeletonJson], with, when [thigh] is given, a skinned
/// point on each upper leg [thigh] metres from the centre at 0.95 m, where
/// the hanging hands are.
Uint8List _armSkeletonGlb({
  required double shoulder,
  required double hip,
  double? thigh,
}) {
  final json = _armSkeletonJson(shoulder: shoulder, hip: hip, vrm: true);
  if (thigh == null) return _glb(json);
  final nodes = json['nodes']! as List<Map<String, Object?>>;
  // Rest world positions of joints 0 to 14; every rest rotation is identity.
  final world = <List<double>>[];
  final parents = <int, int>{};
  for (var i = 0; i < nodes.length; i++) {
    for (final child in (nodes[i]['children'] as List<int>?) ?? const <int>[]) {
      parents[child] = i;
    }
  }
  for (var i = 0; i < nodes.length; i++) {
    final t = nodes[i]['translation']! as List<double>;
    final parent = parents[i];
    world.add(
      parent == null
          ? t
          : [
              world[parent][0] + t[0],
              world[parent][1] + t[1],
              world[parent][2] + t[2],
            ],
    );
  }
  final points = [thigh, .95, 0.0, -thigh, .95, 0.0];
  final joints = Uint8List(16);
  ByteData.sublistView(joints)
    ..setUint16(0, 3, Endian.little)
    ..setUint16(8, 6, Endian.little);
  final weights = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0];
  final inverseBinds = [
    for (final p in world) ...[
      1.0, 0.0, 0.0, 0.0, //
      0.0, 1.0, 0.0, 0.0,
      0.0, 0.0, 1.0, 0.0,
      -p[0], -p[1], -p[2], 1.0,
    ],
  ];
  final binary = BytesBuilder()
    ..add(_floats(points))
    ..add(joints)
    ..add(_floats(weights))
    ..add(_floats(inverseBinds));
  final bytes = binary.toBytes();
  nodes.add({'mesh': 0, 'skin': 0});
  (json['scenes']! as List<Map<String, Object?>>)[0]['nodes'] = [0, 15];
  json.addAll({
    'buffers': [
      {'byteLength': bytes.length},
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 24},
      {'buffer': 0, 'byteOffset': 24, 'byteLength': 16},
      {'buffer': 0, 'byteOffset': 40, 'byteLength': 32},
      {'buffer': 0, 'byteOffset': 72, 'byteLength': 960},
    ],
    'accessors': [
      {
        'bufferView': 0,
        'componentType': 5126,
        'count': 2,
        'type': 'VEC3',
        'min': [-thigh, .95, 0.0],
        'max': [thigh, .95, 0.0],
      },
      {'bufferView': 1, 'componentType': 5123, 'count': 2, 'type': 'VEC4'},
      {'bufferView': 2, 'componentType': 5126, 'count': 2, 'type': 'VEC4'},
      {'bufferView': 3, 'componentType': 5126, 'count': 15, 'type': 'MAT4'},
    ],
    'meshes': [
      {
        'primitives': [
          {
            'attributes': {'POSITION': 0, 'JOINTS_0': 1, 'WEIGHTS_0': 2},
            'mode': 0,
          },
        ],
      },
    ],
    'skins': [
      {
        'joints': [for (var i = 0; i < 15; i++) i],
        'inverseBindMatrices': 3,
      },
    ],
  });
  return _glb(json, binaryChunk: bytes);
}
