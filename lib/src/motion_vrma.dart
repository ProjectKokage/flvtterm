part of '../flvtterm.dart';

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
  final fade = controller._fadeWeight;
  final snapshot = _snapshotVrmaFrame(controller, vrma, frame);
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
  controller._clearIfFadeOutFinished();
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
  Map<int, List<double>>? sourceRestWorldRotations,
}) {
  final model = controller.model;
  final allowsNode = isNodeAllowed ?? controller._isNodeAllowed;
  final nodePoses = <int, GltfNodePose>{};
  GltfNodePose? modelRootPose;
  final sourceNodeToBone = <int, VrmHumanoidBone>{
    for (final entry in vrma.animation.humanoid.humanBones.entries)
      entry.value.node: entry.key,
  };
  for (final entry in frame.nodePoses.entries) {
    final bone = sourceNodeToBone[entry.key];
    if (bone == null) continue;
    if (bone == VrmHumanoidBone.leftEye || bone == VrmHumanoidBone.rightEye) {
      continue;
    }
    final destinationNodeIndex = model.vrm.humanoid.nodeFor(bone);
    final destinationNode = destinationNodeIndex == null
        ? null
        : model.gltf.nodes.elementAtOrNull(destinationNodeIndex);
    final sourceNode = vrma.gltf.nodes.elementAtOrNull(entry.key);
    if (destinationNodeIndex == null ||
        destinationNode == null ||
        sourceNode == null) {
      continue;
    }
    if (!allowsNode(destinationNodeIndex)) continue;
    final retargeted = controller.vrmaRetargeter.retargetBone(
      bone: bone,
      sourcePose: entry.value,
      sourceRestNode: sourceNode,
      sourceRestWorldRotation:
          (sourceRestWorldRotations ??
              controller._vrmaRestWorldRotations)[sourceNode.index] ??
          sourceNode.restRotation,
      destinationRestNode: destinationNode,
      destinationRestWorldRotation:
          controller._modelRestWorldRotations[destinationNode.index] ??
          destinationNode.restRotation,
      hipsTranslationScale:
          hipsTranslationScale ?? controller._vrmaHipsTranslationScale,
    );
    if (retargeted.modelRootPose != null) {
      modelRootPose = retargeted.modelRootPose;
    }
    if (retargeted.nodePose != null) {
      nodePoses[destinationNodeIndex] = retargeted.nodePose!;
    }
  }

  final expressionNodes = <int, List<String>>{};
  for (final entry in vrma.animation.presetExpressions.entries) {
    expressionNodes.putIfAbsent(entry.value, () => []).add(entry.key.specName);
  }
  for (final entry in vrma.animation.customExpressions.entries) {
    expressionNodes.putIfAbsent(entry.value, () => []).add(entry.key);
  }
  final expressionWeights = <String, double>{};
  for (final entry in frame.nodePoses.entries) {
    final expressionNames = expressionNodes[entry.key];
    final translation = entry.value.translation;
    if (expressionNames == null || translation == null) continue;
    for (final expressionName in expressionNames) {
      expressionWeights[expressionName] = _clamp01(translation[0]);
    }
  }
  final lookAtNode = vrma.animation.lookAt;
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
