part of '../../flvtterm.dart';

void _validateVrmaAnimationRules(
  GltfAsset gltf,
  VrmAnimationExtension animation,
  _DiagnosticSink sink,
) {
  _validateVrmaHumanoidRestPose(gltf, animation, sink);

  final boneByNode = <int, VrmHumanoidBone>{
    for (final entry in animation.humanoid.humanBones.entries)
      entry.value.node: entry.key,
  };
  final expressionNodes = {
    ...animation.presetExpressions.values,
    ...animation.customExpressions.values,
  };
  final lookAtNode = animation.lookAt;

  for (final bone in [VrmHumanoidBone.leftEye, VrmHumanoidBone.rightEye]) {
    if (animation.humanoid.humanBones.containsKey(bone)) {
      sink.error(
        'vrma.eyeBoneMapping',
        'VRMA humanoid must not define ${bone.specName}; use LookAt.',
        jsonPath: _vrmaHumanoidBonePath(bone),
      );
    }
  }

  for (final preset in [
    VrmExpressionPreset.lookUp,
    VrmExpressionPreset.lookDown,
    VrmExpressionPreset.lookLeft,
    VrmExpressionPreset.lookRight,
  ]) {
    if (animation.presetExpressions.containsKey(preset)) {
      sink.error(
        'vrma.invalidLookExpressionTarget',
        '${preset.specName} must use VRMA LookAt, not expression animation.',
        jsonPath: _vrmaExpressionPath('preset', preset.specName),
      );
    }
  }

  for (final gltfAnimation in gltf.animations) {
    for (
      var channelIndex = 0;
      channelIndex < gltfAnimation.channels.length;
      channelIndex++
    ) {
      final channel = gltfAnimation.channels[channelIndex];
      final targetPath =
          '\$.animations[${gltfAnimation.index}].channels[$channelIndex].target.path';
      final targetNodePath =
          '\$.animations[${gltfAnimation.index}].channels[$channelIndex].target.node';
      final node = channel.targetNode;
      if (node != null &&
          expressionNodes.contains(node) &&
          channel.targetPath != null &&
          channel.targetPath != 'translation') {
        sink.error(
          'vrma.expressionAnimationTargetPath',
          'VRMA expression animation must use translation channels.',
          jsonPath: targetPath,
          gltfNodeIndex: node,
        );
      }
      if (node != null &&
          expressionNodes.contains(node) &&
          channel.targetPath == 'translation') {
        _validateVrmaExpressionWeightRange(gltf, gltfAnimation, channel, sink);
      }
      if (node != null &&
          node == lookAtNode &&
          channel.targetPath != null &&
          channel.targetPath != 'rotation') {
        sink.error(
          'vrma.lookAtAnimationTargetPath',
          'VRMA LookAt animation must use rotation channels.',
          jsonPath: targetPath,
          gltfNodeIndex: node,
        );
      }
      final bone = node == null ? null : boneByNode[node];
      if (bone == null) continue;
      if (bone == VrmHumanoidBone.leftEye || bone == VrmHumanoidBone.rightEye) {
        sink.error(
          'vrma.eyeBoneAnimation',
          'VRMA must not animate ${bone.specName}; use LookAt.',
          jsonPath: targetNodePath,
          gltfNodeIndex: node,
        );
      }
      if (channel.targetPath == 'scale') {
        sink.error(
          'vrma.humanoidScaleAnimation',
          'VRMA humanoid animation must not include scale channels.',
          jsonPath: targetPath,
          gltfNodeIndex: node,
        );
      }
      if (channel.targetPath == 'translation' && bone != VrmHumanoidBone.hips) {
        sink.error(
          'vrma.nonHipsHumanoidTranslation',
          'VRMA humanoid translation is allowed only on hips.',
          jsonPath: targetPath,
          gltfNodeIndex: node,
        );
      }
    }
  }
}

void _validateVrmaHumanoidRestPose(
  GltfAsset gltf,
  VrmAnimationExtension animation,
  _DiagnosticSink sink,
) {
  for (final assignment in animation.humanoid.humanBones.values) {
    final node = gltf.nodes.elementAtOrNull(assignment.node);
    if (node == null) continue;
    if (node.restScale.every(_isUnitScaleComponent) &&
        !_hasReflectedMatrixBasis(node.matrix)) {
      continue;
    }
    sink.warning(
      'vrma.humanoidRestScale',
      'VRMA humanoid rest pose should not include separate scale.',
      jsonPath: node.matrix == null
          ? '\$.nodes[${assignment.node}].scale'
          : '\$.nodes[${assignment.node}].matrix',
      gltfNodeIndex: assignment.node,
    );
  }
}

bool _isUnitScaleComponent(double component) => (component - 1.0).abs() < 1e-6;

void _validateVrmaExpressionWeightRange(
  GltfAsset gltf,
  GltfAnimation animation,
  GltfAnimationChannel channel,
  _DiagnosticSink sink,
) {
  final samplerIndex = channel.sampler;
  if (samplerIndex == null ||
      samplerIndex < 0 ||
      samplerIndex >= animation.samplers.length) {
    return;
  }
  final sampler = animation.samplers[samplerIndex];
  final output = sampler.output;
  if (output == null) return;
  final values = _readAccessorNumbers(gltf, output, requireFloat: true);
  if (values == null) return;
  final stride = sampler.interpolation == 'CUBICSPLINE' ? 9 : 3;
  final xOffset = sampler.interpolation == 'CUBICSPLINE' ? 3 : 0;
  for (var i = xOffset; i < values.length; i += stride) {
    final weight = values[i];
    if (weight >= 0 && weight <= 1) continue;
    sink.warning(
      'vrma.expressionWeightOutOfRange',
      'VRMA expression animation weights should be in [0, 1]; runtime clamps them.',
      jsonPath:
          '\$.animations[${animation.index}].samplers[$samplerIndex].output',
      gltfNodeIndex: channel.targetNode,
    );
    return;
  }
}

String _vrmaHumanoidBonePath(VrmHumanoidBone bone, [String suffix = '']) =>
    '\$.extensions.VRMC_vrm_animation.humanoid.humanBones.${bone.specName}$suffix';
