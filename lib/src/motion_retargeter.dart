part of '../flvtterm.dart';

/// Retargets one VRMA humanoid bone pose onto a destination VRM humanoid bone.
abstract interface class VrmHumanoidRetargeter {
  /// Converts [sourcePose] from [sourceRestNode] space to a destination pose
  /// relative to [destinationRestNode].
  VrmRetargetedBonePose retargetBone({
    required VrmHumanoidBone bone,
    required GltfNodePose sourcePose,
    required GltfNode sourceRestNode,
    required GltfNode destinationRestNode,
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
/// Rotations are transferred by source-rest delta into destination-rest space.
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
    required GltfNode destinationRestNode,
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
        : _rotationConstraint(
            sourceRest: sourceRestNode.restRotation,
            sourceCurrent: sourcePose.rotation!,
            destinationRest: destinationRestNode.restRotation,
          );
    return VrmRetargetedBonePose(
      nodePose: rotation == null ? null : GltfNodePose(rotation: rotation),
      modelRootPose: hipsTranslation == null
          ? null
          : GltfNodePose(translation: hipsTranslation),
    );
  }
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
