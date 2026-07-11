part of '../../flvtterm.dart';

/// Retargets one VRMA humanoid bone pose onto a destination VRM humanoid bone.
abstract interface class VrmHumanoidRetargeter {
  /// Converts [sourcePose] from the source rest frame to the destination rest
  /// frame.
  ///
  /// [sourceRestWorldRotation] and [destinationRestWorldRotation] include all
  /// glTF ancestors, including nodes without humanoid assignments. The
  /// destination frame also includes any source-to-runtime model basis, such
  /// as the persistent Y-180 rotation used for VRM 0.x. When the destination
  /// omits source humanoid ancestors, [sourcePose] includes their normalized
  /// rotations collapsed into this bone.
  VrmRetargetedBonePose retargetBone({
    required VrmHumanoidBone bone,
    required GltfNodePose sourcePose,
    required GltfNode sourceRestNode,
    required List<double> sourceRestWorldRotation,
    required GltfNode destinationRestNode,
    required List<double> destinationRestWorldRotation,
    required double hipsTranslationScale,
  });
}

/// Result of retargeting a single VRMA humanoid bone.
final class VrmRetargetedBonePose {
  /// Creates a retargeted bone pose.
  const VrmRetargetedBonePose({this.nodePose, this.modelRootPose});

  /// Destination humanoid node pose.
  final GltfNodePose? nodePose;

  /// Optional model-root pose, used for hips translation.
  final GltfNodePose? modelRootPose;
}

/// Simple FK VRMA humanoid retargeter.
///
/// Rotations are normalized through source and destination world rest frames.
/// Hips translation is applied as model-root motion using the source rest-pose
/// delta multiplied by `hipsTranslationScale`.
final class VrmFkHumanoidRetargeter implements VrmHumanoidRetargeter {
  /// Creates the default FK retargeter.
  const VrmFkHumanoidRetargeter();

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
    final hipsTranslation = bone == VrmHumanoidBone.hips
        ? _retargetHipsRootTranslation(
            sourceRest: sourceRestNode.restTranslation,
            sourceCurrent: sourcePose.translation,
            scale: hipsTranslationScale,
          )
        : null;
    final rotation = sourcePose.rotation == null
        ? null
        : _retargetHumanoidRotation(
            sourceRestLocal: sourceRestNode.restRotation,
            sourceRestWorld: sourceRestWorldRotation,
            sourceCurrent: sourcePose.rotation!,
            destinationRestLocal: destinationRestNode.restRotation,
            destinationRestWorld: destinationRestWorldRotation,
          );
    return VrmRetargetedBonePose(
      nodePose: rotation == null ? null : GltfNodePose(rotation: rotation),
      modelRootPose: hipsTranslation == null
          ? null
          : GltfNodePose(translation: hipsTranslation),
    );
  }
}

List<double> _retargetHumanoidRotation({
  required List<double> sourceRestLocal,
  required List<double> sourceRestWorld,
  required List<double> sourceCurrent,
  required List<double> destinationRestLocal,
  required List<double> destinationRestWorld,
}) {
  final normalized = _normalizedHumanoidRotation(
    localRest: sourceRestLocal,
    worldRest: sourceRestWorld,
    current: sourceCurrent,
  );
  return _humanoidLocalRotationFromNormalized(
    localRest: destinationRestLocal,
    worldRest: destinationRestWorld,
    normalized: normalized,
  );
}

List<double> _normalizedHumanoidRotation({
  required List<double> localRest,
  required List<double> worldRest,
  required List<double> current,
}) => _quatMultiply(
  _quatMultiply(_quatMultiply(worldRest, _quatInverse(localRest)), current),
  _quatInverse(worldRest),
);

List<double> _humanoidLocalRotationFromNormalized({
  required List<double> localRest,
  required List<double> worldRest,
  required List<double> normalized,
}) => _quatMultiply(
  _quatMultiply(_quatMultiply(localRest, _quatInverse(worldRest)), normalized),
  worldRest,
);

Map<int, List<double>> _restWorldRotations(GltfAsset gltf) {
  final parents = _nodeParents(gltf);
  final result = <int, List<double>>{};
  for (final start in gltf.nodes) {
    if (result.containsKey(start.index)) continue;
    final chain = <GltfNode>[];
    final visited = <int>{};
    var currentIndex = start.index;
    var world = const <double>[0, 0, 0, 1];
    while (true) {
      final cached = result[currentIndex];
      if (cached != null) {
        world = cached;
        break;
      }
      if (!visited.add(currentIndex)) break;
      final current = gltf.nodes.elementAtOrNull(currentIndex);
      if (current == null) break;
      chain.add(current);
      final parent = parents[currentIndex];
      if (parent == null) break;
      currentIndex = parent;
    }
    for (final node in chain.reversed) {
      world = List.unmodifiable(_quatMultiply(world, node.restRotation));
      result[node.index] = world;
    }
  }
  return Map.unmodifiable(result);
}

List<double>? _retargetHipsRootTranslation({
  required List<double> sourceRest,
  required List<double>? sourceCurrent,
  required double scale,
}) {
  if (sourceCurrent == null) return null;
  return [
    (sourceCurrent[0] - sourceRest[0]) * scale,
    (sourceCurrent[1] - sourceRest[1]) * scale,
    (sourceCurrent[2] - sourceRest[2]) * scale,
  ];
}
