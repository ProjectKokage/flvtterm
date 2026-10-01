part of '../../flvtterm.dart';

void _applyVrmaMotion(
  VrmMotionController controller,
  VrmSceneBinding binding,
  VrmExpressionController expressions,
  VrmLookAtController lookAt,
  VrmAnimationAsset vrma,
  int animationIndex,
) {
  final evaluator = controller._vrmaEvaluator;
  if (evaluator == null) return;
  final frame = evaluator.evaluate(animationIndex, controller._timeSeconds);
  final snapshot = _snapshotVrmaFrame(controller, vrma, frame);
  _applyHumanoidMotionSnapshot(
    controller,
    binding,
    expressions,
    lookAt,
    snapshot,
  );
}

void _applyHumanoidMotionSnapshot(
  VrmMotionController controller,
  VrmSceneBinding binding,
  VrmExpressionController expressions,
  VrmLookAtController lookAt,
  _MotionSnapshot snapshot,
) {
  final fade = controller._fadeWeight;
  controller._applyNodePoses(
    binding,
    snapshot.nodePoses,
    fade,
    from: controller._crossFadeFrom?.nodePoses,
  );
  expressions._setMotionInputs(
    controller._additiveMotionInputs(
      controller._blendMotionInputs(snapshot.expressionWeights, fade),
    ),
  );
  lookAt._setMotionYawPitch(
    controller._additiveLookAt(controller._blendLookAt(snapshot.lookAt, fade)),
  );
  controller._applyAdditiveNodePoses(binding);
  controller._applyModelRootPose(
    binding,
    snapshot.modelRootPose,
    fade,
    from: controller._crossFadeFrom?.modelRootPose,
  );
  controller._clearFinishedCrossFade();
}

_MotionSnapshot? _captureVrmaMotionSnapshot(
  VrmMotionController controller,
  VrmAnimationAsset vrma,
  int animationIndex,
) {
  final evaluator = controller._vrmaEvaluator;
  if (evaluator == null) return null;
  final frame = evaluator.evaluate(animationIndex, controller._timeSeconds);
  return _snapshotVrmaFrame(controller, vrma, frame);
}

_MotionSnapshot _snapshotVrmaFrame(
  VrmMotionController controller,
  VrmAnimationAsset vrma,
  GltfAnimationFrame frame, {
  bool Function(int nodeIndex)? isNodeAllowed,
  double? hipsTranslationScale,
  _VrmaRetargetPlan? retargetPlan,
  bool spaceArms = true,
}) {
  final model = controller.model;
  final allowsNode = isNodeAllowed ?? controller._isNodeAllowed;
  final nodePoses = <int, GltfNodePose>{};
  GltfNodePose? modelRootPose;
  final resolvedPlan =
      retargetPlan ??
      controller._vrmaRetargetPlan ??
      _VrmaRetargetPlan(
        model,
        vrma,
        destinationRestWorldRotations: controller._modelRestWorldRotations,
      );
  final sourcePoses = <_VrmaRetargetTarget, GltfNodePose>{
    for (final target in resolvedPlan.targets)
      if (allowsNode(target.destinationNode.index))
        target: ?target.sourcePose(frame),
  };
  final armSpacing = resolvedPlan.armSpacing;
  if (spaceArms && controller.proportionalArmSpacing && armSpacing != null) {
    _spaceArms(armSpacing, resolvedPlan.armSources, frame, sourcePoses);
  }
  for (final MapEntry(key: target, value: sourcePose) in sourcePoses.entries) {
    final retargeted = controller.vrmaRetargeter.retargetBone(
      bone: target.bone,
      sourcePose: sourcePose,
      sourceRestNode: target.sourceNode,
      sourceRestWorldRotation: target.sourceRestWorldRotation,
      destinationRestNode: target.destinationNode,
      destinationRestWorldRotation: target.destinationRestWorldRotation,
      hipsTranslationScale:
          hipsTranslationScale ?? controller._vrmaHipsTranslationScale,
    );
    if (retargeted.modelRootPose != null) {
      modelRootPose = retargeted.modelRootPose;
    }
    if (retargeted.nodePose != null) {
      nodePoses[target.destinationNode.index] = retargeted.nodePose!;
    }
  }

  final expressionWeights = <String, double>{};
  for (final target in resolvedPlan.expressionTargets) {
    final translation = frame.nodePoses[target.nodeIndex]?.translation;
    if (translation == null) continue;
    for (final expressionName in target.names) {
      expressionWeights[expressionName] = _clamp01(translation[0]);
    }
  }
  final lookAtNode = resolvedPlan.lookAtNode;
  final lookAtRotation = lookAtNode == null
      ? null
      : frame.nodePoses[lookAtNode]?.rotation;
  return _MotionSnapshot(
    nodePoses: Map.unmodifiable(nodePoses),
    modelRootPose: modelRootPose,
    expressionWeights: Map.unmodifiable(expressionWeights),
    lookAt: lookAtRotation == null
        ? null
        : _yawPitchFromExtrinsicZxy(lookAtRotation),
  );
}

/// Replaces the upper-arm poses in [sourcePoses] by [armSpacing]'s.
void _spaceArms(
  _ArmSpacing armSpacing,
  List<_VrmaArmSource> armSources,
  GltfAnimationFrame frame,
  Map<_VrmaRetargetTarget, GltfNodePose> sourcePoses,
) {
  final source = <VrmHumanoidBone, List<double>>{
    for (final arm in armSources)
      if (frame.nodePoses[arm.node.index]?.rotation case final rotation?)
        arm.bone: _normalizedHumanoidRotation(
          localRest: arm.node.restRotation,
          worldRest: arm.restWorldRotation,
          current: rotation,
        ),
  };
  final destination = <VrmHumanoidBone, List<double>>{
    for (final MapEntry(key: target, value: pose) in sourcePoses.entries)
      if (pose.rotation case final rotation?)
        target.bone: _normalizedHumanoidRotation(
          localRest: target.sourceNode.restRotation,
          worldRest: target.sourceRestWorldRotation,
          current: rotation,
        ),
  };
  final adjusted = armSpacing.adjust(source, destination);
  for (final MapEntry(key: target, value: pose) in sourcePoses.entries) {
    final side = _armSpacingSides.where((s) => s.upperArm == target.bone);
    if (side.isEmpty || pose.rotation == null) continue;
    final rotation = adjusted[target.bone];
    if (rotation == null || identical(rotation, destination[target.bone])) {
      continue;
    }
    sourcePoses[target] = GltfNodePose(
      translation: pose.translation,
      rotation: _humanoidLocalRotationFromNormalized(
        localRest: target.sourceNode.restRotation,
        worldRest: target.sourceRestWorldRotation,
        normalized: rotation,
      ),
      scale: pose.scale,
    );
  }
}
