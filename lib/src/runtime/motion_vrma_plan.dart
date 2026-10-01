part of '../../flvtterm.dart';

final class _VrmaRetargetPlan {
  _VrmaRetargetPlan(
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
       armSpacing = _ArmSpacing.build(model, animation),
       armSources = _armSpacingSources(animation);

  _VrmaRetargetPlan.humanoidOnly(
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
       armSpacing = _ArmSpacing.build(model, animation),
       armSources = _armSpacingSources(animation);

  final List<_VrmaRetargetTarget> targets;
  final List<_VrmaExpressionTarget> expressionTargets;
  final int? lookAtNode;

  /// Null when either skeleton lacks the bones arm spacing measures.
  final _ArmSpacing? armSpacing;

  /// Source bones whose rotations place the source hands.
  final List<_VrmaArmSource> armSources;
}

final class _VrmaArmSource {
  const _VrmaArmSource(this.bone, this.node, this.restWorldRotation);

  final VrmHumanoidBone bone;
  final GltfNode node;
  final List<double> restWorldRotation;
}

List<_VrmaArmSource> _armSpacingSources(VrmAnimationAsset animation) {
  final restWorld = _restWorldRotations(animation.gltf);
  final bones = {
    ..._armSpacingRoots,
    for (final side in _armSpacingSides) ...[
      side.shoulder,
      side.upperArm,
      side.lowerArm,
      side.hand,
    ],
  };
  return List.unmodifiable([
    for (final entry in animation.animation.humanoid.humanBones.entries)
      if (bones.contains(entry.key))
        if (animation.gltf.nodes.elementAtOrNull(entry.value.node)
            case final node?)
          _VrmaArmSource(
            entry.key,
            node,
            restWorld[node.index] ?? node.restRotation,
          ),
  ]);
}

List<_VrmaRetargetTarget> _buildVrmaRetargetTargets(
  VrmModel model,
  VrmAnimationAsset animation,
  Map<int, List<double>> destinationRestWorldRotations,
) {
  final sourceBones = animation.animation.humanoid.humanBones;
  final destinationBones = model.vrm.humanoid.humanBones;
  final sourceRestWorldRotations = _restWorldRotations(animation.gltf);
  final targets = <_VrmaRetargetTarget>[];
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

    final collapsedAncestors = <_VrmaSourceBone>[];
    var ancestor = _directHumanoidParent[bone];
    while (ancestor != null) {
      final sourceAncestor = sourceBones[ancestor];
      final destinationAncestor = destinationBones[ancestor];
      if (sourceAncestor != null && destinationAncestor != null) break;
      if (sourceAncestor != null && destinationAncestor == null) {
        final node = animation.gltf.nodes.elementAtOrNull(sourceAncestor.node);
        if (node != null) {
          collapsedAncestors.add(
            _VrmaSourceBone(
              node,
              sourceRestWorldRotations[node.index] ?? node.restRotation,
            ),
          );
        }
      }
      ancestor = _directHumanoidParent[ancestor];
    }

    targets.add(
      _VrmaRetargetTarget(
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
  VrmSourceVersion.vrm0 => _quatMultiply(const [
    0.0,
    1.0,
    0.0,
    0.0,
  ], sourceWorldRotation),
  VrmSourceVersion.vrm1 => sourceWorldRotation,
};

List<_VrmaExpressionTarget> _buildVrmaExpressionTargets(
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
      _VrmaExpressionTarget(entry.key, List.unmodifiable(entry.value)),
  ]);
}

final class _VrmaRetargetTarget {
  const _VrmaRetargetTarget({
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
  final List<_VrmaSourceBone> collapsedAncestors;

  GltfNodePose? sourcePose(GltfAnimationFrame frame) {
    List<double>? normalized;
    for (final ancestor in collapsedAncestors) {
      final rotation = frame.nodePoses[ancestor.node.index]?.rotation;
      if (rotation == null) continue;
      final next = _normalizedHumanoidRotation(
        localRest: ancestor.node.restRotation,
        worldRest: ancestor.restWorldRotation,
        current: rotation,
      );
      normalized = normalized == null ? next : _quatMultiply(normalized, next);
    }

    final ownPose = frame.nodePoses[sourceNode.index];
    final ownRotation = ownPose?.rotation;
    if (ownRotation != null) {
      final ownNormalized = _normalizedHumanoidRotation(
        localRest: sourceNode.restRotation,
        worldRest: sourceRestWorldRotation,
        current: ownRotation,
      );
      normalized = normalized == null
          ? ownNormalized
          : _quatMultiply(normalized, ownNormalized);
    }
    if (normalized == null) return ownPose;
    return GltfNodePose(
      translation: ownPose?.translation,
      rotation: _humanoidLocalRotationFromNormalized(
        localRest: sourceNode.restRotation,
        worldRest: sourceRestWorldRotation,
        normalized: normalized,
      ),
      scale: ownPose?.scale,
    );
  }
}

final class _VrmaSourceBone {
  const _VrmaSourceBone(this.node, this.restWorldRotation);

  final GltfNode node;
  final List<double> restWorldRotation;
}

final class _VrmaExpressionTarget {
  const _VrmaExpressionTarget(this.nodeIndex, this.names);

  final int nodeIndex;
  final List<String> names;
}
