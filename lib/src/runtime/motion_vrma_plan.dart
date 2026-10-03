import 'package:meta/meta.dart';

import '../gltf/gltf_animation_types.dart';
import '../gltf/gltf_scene_types.dart';
import '../safe_list_index.dart';
import '../vrm/vrm_assets.dart';
import '../vrm/vrm_enums.dart';
import '../vrm/vrm_humanoid_parser.dart';
import 'constraint_math.dart';
import 'motion_arm_spacing.dart';
import 'motion_retargeter.dart';

@internal
final class VrmaRetargetPlan {
  VrmaRetargetPlan(
    VrmModel model,
    VrmAnimationAsset animation, {
    required Map<int, List<double>> destinationRestWorldRotations,
  }) : targets = _buildVrmaRetargetTargets(
         model,
         animation,
         destinationRestWorldRotations,
       ),
       expressionTargets = _buildVrmaExpressionTargets(animation),
       lookAtNode = animation.animation.lookAt,
       armSpacing = ArmSpacing.of(model);

  VrmaRetargetPlan.humanoidOnly(
    VrmModel model,
    VrmAnimationAsset animation, {
    required Map<int, List<double>> destinationRestWorldRotations,
  }) : targets = _buildVrmaRetargetTargets(
         model,
         animation,
         destinationRestWorldRotations,
       ),
       expressionTargets = const [],
       lookAtNode = null,
       armSpacing = ArmSpacing.of(model);

  final List<VrmaRetargetTarget> targets;
  final List<VrmaExpressionTarget> expressionTargets;
  final int? lookAtNode;

  /// Null when the avatar lacks the bones or body skin arm spacing measures.
  final ArmSpacing? armSpacing;
}

List<VrmaRetargetTarget> _buildVrmaRetargetTargets(
  VrmModel model,
  VrmAnimationAsset animation,
  Map<int, List<double>> destinationRestWorldRotations,
) {
  final sourceBones = animation.animation.humanoid.humanBones;
  final destinationBones = model.vrm.humanoid.humanBones;
  final sourceRestWorldRotations = restWorldRotations(animation.gltf);
  final targets = <VrmaRetargetTarget>[];
  for (final entry in sourceBones.entries) {
    final bone = entry.key;
    if (bone == VrmHumanoidBone.leftEye || bone == VrmHumanoidBone.rightEye) {
      continue;
    }
    final destinationAssignment = destinationBones[bone];
    final sourceNode = animation.gltf.nodes.elementAtOrNull(entry.value.node);
    final destinationNode = destinationAssignment == null
        ? null
        : model.gltf.nodes.elementAtOrNull(destinationAssignment.node);
    if (sourceNode == null || destinationNode == null) continue;

    final collapsedAncestors = <VrmaSourceBone>[];
    var ancestor = directHumanoidParent[bone];
    while (ancestor != null) {
      final sourceAncestor = sourceBones[ancestor];
      final destinationAncestor = destinationBones[ancestor];
      if (sourceAncestor != null && destinationAncestor != null) break;
      if (sourceAncestor != null && destinationAncestor == null) {
        final node = animation.gltf.nodes.elementAtOrNull(sourceAncestor.node);
        if (node != null) {
          collapsedAncestors.add(
            VrmaSourceBone(
              node,
              sourceRestWorldRotations[node.index] ?? node.restRotation,
            ),
          );
        }
      }
      ancestor = directHumanoidParent[ancestor];
    }

    targets.add(
      VrmaRetargetTarget(
        bone: bone,
        sourceNode: sourceNode,
        sourceRestWorldRotation:
            sourceRestWorldRotations[sourceNode.index] ??
            sourceNode.restRotation,
        destinationNode: destinationNode,
        destinationRestWorldRotation: _destinationRestWorldRotation(
          model.sourceVersion,
          destinationRestWorldRotations[destinationNode.index] ??
              destinationNode.restRotation,
        ),
        collapsedAncestors: collapsedAncestors.reversed.toList(growable: false),
      ),
    );
  }
  return List.unmodifiable(targets);
}

List<double> _destinationRestWorldRotation(
  VrmSourceVersion version,
  List<double> sourceWorldRotation,
) => switch (version) {
  VrmSourceVersion.vrm0 => quatMultiply(const [
    0.0,
    1.0,
    0.0,
    0.0,
  ], sourceWorldRotation),
  VrmSourceVersion.vrm1 => sourceWorldRotation,
};

List<VrmaExpressionTarget> _buildVrmaExpressionTargets(
  VrmAnimationAsset animation,
) {
  final namesByNode = <int, List<String>>{};
  for (final entry in animation.animation.presetExpressions.entries) {
    namesByNode.putIfAbsent(entry.value, () => []).add(entry.key.specName);
  }
  for (final entry in animation.animation.customExpressions.entries) {
    namesByNode.putIfAbsent(entry.value, () => []).add(entry.key);
  }
  return List.unmodifiable([
    for (final entry in namesByNode.entries)
      VrmaExpressionTarget(entry.key, List.unmodifiable(entry.value)),
  ]);
}

@internal
final class VrmaRetargetTarget {
  const VrmaRetargetTarget({
    required this.bone,
    required this.sourceNode,
    required this.sourceRestWorldRotation,
    required this.destinationNode,
    required this.destinationRestWorldRotation,
    required this.collapsedAncestors,
  });

  final VrmHumanoidBone bone;
  final GltfNode sourceNode;
  final List<double> sourceRestWorldRotation;
  final GltfNode destinationNode;
  final List<double> destinationRestWorldRotation;
  final List<VrmaSourceBone> collapsedAncestors;

  GltfNodePose? sourcePose(GltfAnimationFrame frame) {
    List<double>? normalized;
    for (final ancestor in collapsedAncestors) {
      final rotation = frame.nodePoses[ancestor.node.index]?.rotation;
      if (rotation == null) continue;
      final next = normalizedHumanoidRotation(
        localRest: ancestor.node.restRotation,
        worldRest: ancestor.restWorldRotation,
        current: rotation,
      );
      normalized = normalized == null ? next : quatMultiply(normalized, next);
    }

    final ownPose = frame.nodePoses[sourceNode.index];
    final ownRotation = ownPose?.rotation;
    if (ownRotation != null) {
      final ownNormalized = normalizedHumanoidRotation(
        localRest: sourceNode.restRotation,
        worldRest: sourceRestWorldRotation,
        current: ownRotation,
      );
      normalized = normalized == null
          ? ownNormalized
          : quatMultiply(normalized, ownNormalized);
    }
    if (normalized == null) return ownPose;
    return GltfNodePose(
      translation: ownPose?.translation,
      rotation: humanoidLocalRotationFromNormalized(
        localRest: sourceNode.restRotation,
        worldRest: sourceRestWorldRotation,
        normalized: normalized,
      ),
      scale: ownPose?.scale,
    );
  }
}

@internal
final class VrmaSourceBone {
  const VrmaSourceBone(this.node, this.restWorldRotation);

  final GltfNode node;
  final List<double> restWorldRotation;
}

@internal
final class VrmaExpressionTarget {
  const VrmaExpressionTarget(this.nodeIndex, this.names);

  final int nodeIndex;
  final List<String> names;
}
