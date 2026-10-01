part of '../../flvtterm.dart';

// Joint rotations alone keep a motion's arm angles, not where its hands are.
// A motion recorded on a skeleton whose shoulders are twice its hip width,
// replayed on an avatar whose shoulders are barely wider than its hips, puts
// every hanging hand onto the thighs and presses the arms into the torso.
// When enabled, each hanging hand keeps its sideways distance from the body
// in proportion to the hip width, as it had on the source skeleton: the
// upper arm turns about the body's forward axis through the shoulder until
// the wrist is there. Raised arms keep their joint angles.

const _armSpacingRoots = [
  VrmHumanoidBone.hips,
  VrmHumanoidBone.spine,
  VrmHumanoidBone.chest,
  VrmHumanoidBone.upperChest,
];

const _armSpacingSides = [
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

// The correction is whole while the upper arm is within 30 degrees of hanging
// straight down and fades out by 60 degrees.
final _armSpacingFullCosine = math.cos(math.pi / 6);
final _armSpacingNoneCosine = math.cos(math.pi / 3);
const _armSpacingMaxRadians = 25 * math.pi / 180;

/// Rest positions of one skeleton's humanoid bones in the shared normalized
/// frame: +Y up, +Z forward, the character's left along +X.
final class _ArmSpacingSkeleton {
  const _ArmSpacingSkeleton(this.positions, this.hipHalfWidth);

  final Map<VrmHumanoidBone, List<double>> positions;
  final double hipHalfWidth;

  static _ArmSpacingSkeleton? of(Map<VrmHumanoidBone, List<double>> positions) {
    final left = positions[VrmHumanoidBone.leftUpperLeg];
    final right = positions[VrmHumanoidBone.rightUpperLeg];
    if (left == null || right == null) return null;
    final halfWidth = (left[0] - right[0]).abs() / 2;
    if (!halfWidth.isFinite || halfWidth < 1e-6) return null;
    for (final side in _armSpacingSides) {
      if (!positions.containsKey(side.upperArm) ||
          !positions.containsKey(side.lowerArm) ||
          !positions.containsKey(side.hand)) {
        return null;
      }
    }
    if (!positions.containsKey(VrmHumanoidBone.hips)) return null;
    return _ArmSpacingSkeleton(Map.unmodifiable(positions), halfWidth);
  }

  /// The bones from the hips to [hand] that this skeleton maps, in order.
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

  /// World rotation (relative to rest) and position of each bone of [chain]
  /// under the normalized rotations [normalized].
  (Map<VrmHumanoidBone, List<double>>, Map<VrmHumanoidBone, List<double>>) pose(
    List<VrmHumanoidBone> chain,
    Map<VrmHumanoidBone, List<double>> normalized,
  ) {
    final rotations = <VrmHumanoidBone, List<double>>{};
    final points = <VrmHumanoidBone, List<double>>{};
    VrmHumanoidBone? previous;
    for (final bone in chain) {
      final own = normalized[bone] ?? const [0.0, 0.0, 0.0, 1.0];
      if (previous == null) {
        rotations[bone] = own;
        points[bone] = positions[bone]!;
      } else {
        final offset = _vectorSubtract(positions[bone]!, positions[previous]!);
        points[bone] = _vectorAdd(
          points[previous]!,
          _rotateVectorPreservingLength(rotations[previous]!, offset),
        );
        rotations[bone] = _quatMultiply(rotations[previous]!, own);
      }
      previous = bone;
    }
    return (rotations, points);
  }
}

final class _ArmSpacing {
  const _ArmSpacing(this.source, this.destination);

  final _ArmSpacingSkeleton source;
  final _ArmSpacingSkeleton destination;

  static _ArmSpacing? build(VrmModel model, VrmAnimationAsset animation) {
    final sourcePositions = _restWorldPositions(animation.gltf);
    final source = _ArmSpacingSkeleton.of({
      for (final entry in animation.animation.humanoid.humanBones.entries)
        entry.key: ?sourcePositions[entry.value.node],
    });
    final destinationPositions = _restWorldPositions(model.gltf);
    final destination = _ArmSpacingSkeleton.of({
      for (final entry in model.vrm.humanoid.humanBones.entries)
        if (destinationPositions[entry.value.node] case final position?)
          entry.key: switch (model.sourceVersion) {
            // VRM 0.x faces -Z; the runtime turns it 180 degrees about Y.
            VrmSourceVersion.vrm0 => [-position[0], position[1], -position[2]],
            VrmSourceVersion.vrm1 => position,
          },
    });
    if (source == null || destination == null) return null;
    return _ArmSpacing(source, destination);
  }

  /// Returns [destinationNormalized] with each hanging upper arm turned so its
  /// hand keeps the source's hip-relative sideways distance.
  ///
  /// [sourceNormalized] holds the normalized rotation of every animated
  /// source bone; [destinationNormalized] holds those the destination
  /// applies, with unmapped source ancestors already collapsed into them.
  Map<VrmHumanoidBone, List<double>> adjust(
    Map<VrmHumanoidBone, List<double>> sourceNormalized,
    Map<VrmHumanoidBone, List<double>> destinationNormalized,
  ) {
    final result = Map.of(destinationNormalized);
    final scale = destination.hipHalfWidth / source.hipHalfWidth;
    for (final side in _armSpacingSides) {
      final (sourceRotations, sourcePoints) = source.pose(
        source.chain(side),
        sourceNormalized,
      );
      final destinationChain = destination.chain(side);
      final (rotations, points) = destination.pose(destinationChain, result);

      final sourceHips = sourceRotations[VrmHumanoidBone.hips]!;
      final sourceWrist = _rotateVectorPreservingLength(
        _quatInverse(sourceHips),
        _vectorSubtract(
          sourcePoints[side.hand]!,
          sourcePoints[VrmHumanoidBone.hips]!,
        ),
      );
      final hips = rotations[VrmHumanoidBone.hips]!;
      List<double> inHips(List<double> point) => _rotateVectorPreservingLength(
        _quatInverse(hips),
        _vectorSubtract(point, points[VrmHumanoidBone.hips]!),
      );
      final shoulder = inHips(points[side.upperArm]!);
      final elbow = inHips(points[side.lowerArm]!);
      final wrist = inHips(points[side.hand]!);

      final upper = _normalizeVector(_vectorSubtract(elbow, shoulder));
      final hanging = -upper[1];
      final weight = _smoothStep(
        (hanging - _armSpacingNoneCosine) /
            (_armSpacingFullCosine - _armSpacingNoneCosine),
      );
      if (weight <= 0) continue;

      final reach = _vectorSubtract(wrist, shoulder);
      final out = reach[0] * side.outward;
      final down = -reach[1];
      final radius = math.sqrt(out * out + down * down);
      if (radius < 1e-6) continue;
      final wanted =
          sourceWrist[0] * side.outward * scale - shoulder[0] * side.outward;
      final turn =
          (math.asin((wanted / radius).clamp(-1.0, 1.0)) -
                  math.atan2(out, down))
              .clamp(-_armSpacingMaxRadians, _armSpacingMaxRadians) *
          weight;
      if (turn.abs() < 1e-9) continue;

      // Turn about the hips' forward axis, expressed in the world frame.
      final half = side.outward * turn / 2;
      final local = [0.0, 0.0, math.sin(half), math.cos(half)];
      final world = _quatMultiply(
        _quatMultiply(hips, local),
        _quatInverse(hips),
      );
      final index = destinationChain.indexOf(side.upperArm);
      final parent = index > 0
          ? rotations[destinationChain[index - 1]]!
          : const [0.0, 0.0, 0.0, 1.0];
      result[side.upperArm] = _quatMultiply(
        _quatMultiply(_quatMultiply(_quatInverse(parent), world), parent),
        result[side.upperArm] ?? const [0.0, 0.0, 0.0, 1.0],
      );
    }
    return result;
  }
}

Map<int, List<double>> _restWorldPositions(GltfAsset gltf) {
  final parents = _nodeParents(gltf);
  final rotations = _restWorldRotations(gltf);
  final result = <int, List<double>>{};
  List<double> position(int index, Set<int> visiting) {
    final cached = result[index];
    if (cached != null) return cached;
    final node = gltf.nodes[index];
    final parent = parents[index];
    if (parent == null || !visiting.add(index)) {
      return result[index] = List.unmodifiable(node.restTranslation);
    }
    final parentPosition = position(parent, visiting);
    return result[index] = List.unmodifiable(
      _vectorAdd(
        parentPosition,
        _rotateVectorPreservingLength(
          rotations[parent] ?? const [0.0, 0.0, 0.0, 1.0],
          node.restTranslation,
        ),
      ),
    );
  }

  for (final node in gltf.nodes) {
    position(node.index, <int>{});
  }
  return Map.unmodifiable(result);
}

double _smoothStep(double value) {
  final t = value.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

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
