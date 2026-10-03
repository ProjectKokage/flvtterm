import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../gltf/accessor_reader.dart';
import '../gltf/gltf_types.dart';
import '../math_types.dart';
import '../matrix_math.dart';
import '../safe_list_index.dart';
import '../vrm/vrm_assets.dart';
import '../vrm/vrm_enums.dart';
import '../vrm/vrm_humanoid_parser.dart';
import 'constraint_math.dart';
import 'motion_retargeter.dart';

// Joint rotations alone keep a motion's arm angles, not where its hands are.
// A motion made on one body, replayed on an avatar with narrower shoulders or
// wider hips, can put a hanging hand inside the avatar's own thigh. When
// enabled, a hanging upper arm turns outward about the body's forward axis
// through the shoulder until the wrist clears the avatar's hip and thigh
// surface, measured from its skinned mesh at rest. A hand the motion already
// holds clear is left alone, and raised arms keep their joint angles.

@internal
const armSpacingSides = [
  (
    shoulder: VrmHumanoidBone.leftShoulder,
    upperArm: VrmHumanoidBone.leftUpperArm,
    lowerArm: VrmHumanoidBone.leftLowerArm,
    hand: VrmHumanoidBone.leftHand,
    outward: 1.0,
  ),
  (
    shoulder: VrmHumanoidBone.rightShoulder,
    upperArm: VrmHumanoidBone.rightUpperArm,
    lowerArm: VrmHumanoidBone.rightLowerArm,
    hand: VrmHumanoidBone.rightHand,
    outward: -1.0,
  ),
];

const _armSpacingRoots = [
  VrmHumanoidBone.hips,
  VrmHumanoidBone.spine,
  VrmHumanoidBone.chest,
  VrmHumanoidBone.upperChest,
];

// Skin bound to these bones, or to unmapped bones below them such as skirt
// joints, forms the body beside a hanging hand.
const _armSpacingBodyBones = {
  VrmHumanoidBone.hips,
  VrmHumanoidBone.leftUpperLeg,
  VrmHumanoidBone.rightUpperLeg,
};

// The correction is whole while the upper arm is within 30 degrees of hanging
// straight down and fades out by 60 degrees.
final _armSpacingFullCosine = math.cos(math.pi / 6);
final _armSpacingNoneCosine = math.cos(math.pi / 3);
const _armSpacingMaxRadians = 25 * math.pi / 180;

// The wrist joint sits inside the hand: a hanging wrist this far beyond the
// body surface keeps the palm off it on a 1.6 m avatar. Scales with height.
const _armSpacingClearance = .03;

final _armSpacingCache = Expando<_ArmSpacingEntry>('arm spacing');

final class _ArmSpacingEntry {
  const _ArmSpacingEntry(this.value);

  final ArmSpacing? value;
}

/// One avatar's skeleton at rest and the body surface its hanging hands must
/// clear, in the runtime frame: +Y up, +Z forward, the character's left +X.
@internal
final class ArmSpacing {
  const ArmSpacing(this.positions, this.clearOf);

  /// Rest position of each mapped humanoid bone.
  final Map<VrmHumanoidBone, List<double>> positions;

  /// Per side (+1 left, -1 right): the sideways distance from the hips joint
  /// that a hanging wrist must reach.
  final Map<double, double> clearOf;

  /// The avatar's arm spacing, measured once per model; null when the avatar
  /// lacks the bones or body skin it needs.
  static ArmSpacing? of(VrmModel model) =>
      (_armSpacingCache[model] ??= _ArmSpacingEntry(_build(model))).value;

  static ArmSpacing? _build(VrmModel model) {
    final mirror = model.sourceVersion == VrmSourceVersion.vrm0;
    List<double> runtime(List<double> p) => mirror ? [-p[0], p[1], -p[2]] : p;
    final nodePositions = _restWorldPositions(model.gltf);
    final positions = <VrmHumanoidBone, List<double>>{
      for (final entry in model.vrm.humanoid.humanBones.entries)
        if (nodePositions[entry.value.node] case final p?)
          entry.key: runtime(p),
    };
    final hips = positions[VrmHumanoidBone.hips];
    final head = positions[VrmHumanoidBone.head];
    if (hips == null || head == null) return null;
    final lowest = positions.values.map((p) => p[1]).reduce(math.min);
    final clearance = _armSpacingClearance * (head[1] - lowest) / 1.6;
    final clearOf = <double, double>{};
    for (final side in armSpacingSides) {
      final shoulder = positions[side.upperArm];
      final elbow = positions[side.lowerArm];
      final wrist = positions[side.hand];
      if (shoulder == null || elbow == null || wrist == null) return null;
      final forearm = _vectorLength(_vectorSubtract(wrist, elbow));
      // A hanging wrist sits an arm's length below the shoulder; the hand
      // spans about half a forearm either side of that height.
      final hanging =
          shoulder[1] -
          _vectorLength(_vectorSubtract(elbow, shoulder)) -
          forearm;
      final extent = _bodyExtent(
        model,
        runtime,
        side: side.outward,
        low: hanging - forearm / 2,
        high: hanging + forearm / 2,
      );
      if (extent == null) return null;
      clearOf[side.outward] = extent - hips[0] * side.outward + clearance;
    }
    return ArmSpacing(Map.unmodifiable(positions), Map.unmodifiable(clearOf));
  }

  /// The bones from the hips to [side]'s hand that this avatar maps.
  List<VrmHumanoidBone> chain(
    ({
      VrmHumanoidBone shoulder,
      VrmHumanoidBone upperArm,
      VrmHumanoidBone lowerArm,
      VrmHumanoidBone hand,
      double outward,
    })
    side,
  ) => [
    for (final bone in [
      ..._armSpacingRoots,
      side.shoulder,
      side.upperArm,
      side.lowerArm,
      side.hand,
    ])
      if (positions.containsKey(bone)) bone,
  ];

  /// Returns [normalized] with each hanging upper arm turned outward just far
  /// enough for its wrist to clear the body.
  ///
  /// [normalized] holds the normalized rotation of every bone the avatar
  /// applies, with unmapped source ancestors already collapsed into them.
  Map<VrmHumanoidBone, List<double>> adjust(
    Map<VrmHumanoidBone, List<double>> normalized,
  ) {
    final result = Map.of(normalized);
    for (final side in armSpacingSides) {
      final chain = this.chain(side);
      final rotations = <VrmHumanoidBone, List<double>>{};
      final points = <VrmHumanoidBone, List<double>>{};
      VrmHumanoidBone? previous;
      for (final bone in chain) {
        final own = result[bone] ?? const [0.0, 0.0, 0.0, 1.0];
        if (previous == null) {
          rotations[bone] = own;
          points[bone] = positions[bone]!;
        } else {
          points[bone] = _vectorAdd(
            points[previous]!,
            rotateVectorPreservingLength(
              rotations[previous]!,
              _vectorSubtract(positions[bone]!, positions[previous]!),
            ),
          );
          rotations[bone] = quatMultiply(rotations[previous]!, own);
        }
        previous = bone;
      }
      final hips = rotations[VrmHumanoidBone.hips]!;
      List<double> inHips(List<double> point) => rotateVectorPreservingLength(
        quatInverse(hips),
        _vectorSubtract(point, points[VrmHumanoidBone.hips]!),
      );
      final shoulder = inHips(points[side.upperArm]!);
      final elbow = inHips(points[side.lowerArm]!);
      final wrist = inHips(points[side.hand]!);

      final upper = normalizeVector(_vectorSubtract(elbow, shoulder));
      final weight = _smoothStep(
        (-upper[1] - _armSpacingNoneCosine) /
            (_armSpacingFullCosine - _armSpacingNoneCosine),
      );
      final wanted = clearOf[side.outward]!;
      if (weight <= 0 || wrist[0] * side.outward >= wanted) continue;

      final reach = _vectorSubtract(wrist, shoulder);
      final out = reach[0] * side.outward;
      final down = -reach[1];
      final radius = math.sqrt(out * out + down * down);
      if (radius < 1e-6) continue;
      final needed = wanted - shoulder[0] * side.outward;
      final turn =
          (math.asin((needed / radius).clamp(-1.0, 1.0)) -
                  math.atan2(out, down))
              .clamp(0.0, _armSpacingMaxRadians) *
          weight;
      if (turn < 1e-9) continue;

      // Turn about the hips' forward axis, expressed in the world frame.
      final half = side.outward * turn / 2;
      final local = [0.0, 0.0, math.sin(half), math.cos(half)];
      final world = quatMultiply(quatMultiply(hips, local), quatInverse(hips));
      final index = chain.indexOf(side.upperArm);
      final parent = index > 0
          ? rotations[chain[index - 1]]!
          : const [0.0, 0.0, 0.0, 1.0];
      result[side.upperArm] = quatMultiply(
        quatMultiply(quatMultiply(quatInverse(parent), world), parent),
        result[side.upperArm] ?? const [0.0, 0.0, 0.0, 1.0],
      );
    }
    return result;
  }
}

/// The 98th-percentile sideways reach, on [side], of skin bound mainly to the
/// hips or upper legs between heights [low] and [high], at rest.
double? _bodyExtent(
  VrmModel model,
  List<double> Function(List<double>) runtime, {
  required double side,
  required double low,
  required double high,
}) {
  final gltf = model.gltf;
  final humanoidNodes = {
    for (final entry in model.vrm.humanoid.humanBones.entries)
      entry.value.node: entry.key,
  };
  final parents = nodeParents(gltf);
  bool isBody(int node) {
    int? cursor = node;
    final visited = <int>{};
    while (cursor != null && visited.add(cursor)) {
      final bone = humanoidNodes[cursor];
      if (bone != null) return _armSpacingBodyBones.contains(bone);
      cursor = parents[cursor];
    }
    return false;
  }

  final worlds = _restWorldMatrices(gltf);
  final reaches = <double>[];
  for (final node in gltf.nodes) {
    final mesh = node.mesh == null
        ? null
        : gltf.meshes.elementAtOrNull(node.mesh!);
    final skin = node.skin == null
        ? null
        : gltf.skins.elementAtOrNull(node.skin!);
    if (mesh == null || skin == null) continue;
    final inverseBinds = skin.inverseBindMatrices == null
        ? null
        : readGltfAccessorNumbers(gltf, skin.inverseBindMatrices!);
    final body = [for (final joint in skin.joints) isBody(joint)];
    final skinMatrices = [
      for (var i = 0; i < skin.joints.length; i++)
        multiplyMatrices(
          worlds[skin.joints[i]] ?? VrmMatrix4.identity(),
          inverseBinds == null || inverseBinds.length < (i + 1) * 16
              ? VrmMatrix4.identity()
              : VrmMatrix4(inverseBinds.sublist(i * 16, (i + 1) * 16)),
        ).storage,
    ];
    for (final primitive in mesh.primitives) {
      final positionAccessor = primitive.attributes['POSITION'];
      final jointAccessor = primitive.attributes['JOINTS_0'];
      final weightAccessor = primitive.attributes['WEIGHTS_0'];
      if (positionAccessor == null ||
          jointAccessor == null ||
          weightAccessor == null) {
        continue;
      }
      final points = readGltfAccessorNumbers(gltf, positionAccessor);
      final joints = readGltfAccessorNumbers(
        gltf,
        jointAccessor,
        applyNormalization: false,
      );
      final weights = readGltfAccessorNumbers(gltf, weightAccessor);
      if (points == null || joints == null || weights == null) continue;
      final count = math.min(
        points.length ~/ 3,
        math.min(joints.length ~/ 4, weights.length ~/ 4),
      );
      for (var vertex = 0; vertex < count; vertex++) {
        var strongest = 0;
        for (var k = 1; k < 4; k++) {
          if (weights[vertex * 4 + k] > weights[vertex * 4 + strongest]) {
            strongest = k;
          }
        }
        final joint = joints[vertex * 4 + strongest].round();
        if (joint < 0 || joint >= body.length || !body[joint]) continue;
        final x = points[vertex * 3];
        final y = points[vertex * 3 + 1];
        final z = points[vertex * 3 + 2];
        var px = 0.0;
        var py = 0.0;
        var pz = 0.0;
        for (var k = 0; k < 4; k++) {
          final w = weights[vertex * 4 + k];
          final j = joints[vertex * 4 + k].round();
          if (w <= 0 || j < 0 || j >= skinMatrices.length) continue;
          final m = skinMatrices[j];
          px += w * (m[0] * x + m[4] * y + m[8] * z + m[12]);
          py += w * (m[1] * x + m[5] * y + m[9] * z + m[13]);
          pz += w * (m[2] * x + m[6] * y + m[10] * z + m[14]);
        }
        final position = runtime([px, py, pz]);
        if (position[1] < low || position[1] > high) continue;
        final reach = position[0] * side;
        if (reach > 0) reaches.add(reach);
      }
    }
  }
  if (reaches.isEmpty) return null;
  reaches.sort();
  return reaches[((reaches.length - 1) * .98).round()];
}

Map<int, VrmMatrix4> _restWorldMatrices(GltfAsset gltf) {
  final parents = nodeParents(gltf);
  final result = <int, VrmMatrix4>{};
  VrmMatrix4 world(int index, Set<int> visiting) {
    final cached = result[index];
    if (cached != null) return cached;
    final node = gltf.nodes[index];
    final parent = parents[index];
    if (parent == null || !visiting.add(index)) {
      return result[index] = node.restTransform;
    }
    return result[index] = multiplyMatrices(
      world(parent, visiting),
      node.restTransform,
    );
  }

  for (final node in gltf.nodes) {
    world(node.index, <int>{});
  }
  return result;
}

Map<int, List<double>> _restWorldPositions(GltfAsset gltf) => {
  for (final entry in _restWorldMatrices(gltf).entries)
    entry.key: List.unmodifiable(matrixTranslation(entry.value)),
};

double _smoothStep(double value) {
  final t = value.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _vectorLength(List<double> value) => math.sqrt(vectorDot(value, value));

List<double> _vectorAdd(List<double> a, List<double> b) => [
  a[0] + b[0],
  a[1] + b[1],
  a[2] + b[2],
];

List<double> _vectorSubtract(List<double> a, List<double> b) => [
  a[0] - b[0],
  a[1] - b[1],
  a[2] - b[2],
];
