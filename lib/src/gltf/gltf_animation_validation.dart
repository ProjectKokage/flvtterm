part of '../../flvtterm.dart';

void _validateGltfAnimations(GltfAsset gltf, _DiagnosticSink sink) {
  final rawAnimations = _list(gltf.json['animations']);
  for (final animation in gltf.animations) {
    final rawAnimation = _object(
      rawAnimations.elementAtOrNull(animation.index),
    );
    _validateRequiredArray(
      rawAnimation,
      'channels',
      sink,
      'gltf.missingAnimationChannels',
      'gltf.invalidAnimationChannels',
      'Animation channels must be a non-empty array.',
      _animationPath(animation.index, '.channels'),
    );
    _validateRequiredArray(
      rawAnimation,
      'samplers',
      sink,
      'gltf.missingAnimationSamplers',
      'gltf.invalidAnimationSamplers',
      'Animation samplers must be a non-empty array.',
      _animationPath(animation.index, '.samplers'),
    );
    final rawChannels = _list(rawAnimation['channels']);
    final rawAnimationSamplers = _list(rawAnimation['samplers']);
    final channelTargets = <String>{};
    for (
      var channelIndex = 0;
      channelIndex < animation.channels.length;
      channelIndex++
    ) {
      final channel = animation.channels[channelIndex];
      final channelPath = _animationChannelPath(animation.index, channelIndex);
      final rawChannelValue = rawChannels.elementAtOrNull(channelIndex);
      if (rawChannelValue is! Map) {
        sink.error(
          'gltf.invalidAnimationChannelObject',
          'Animation channel entries must be JSON objects.',
          jsonPath: channelPath,
        );
        continue;
      }
      final rawChannel = _object(rawChannelValue);
      final hasTarget = rawChannel.containsKey('target');
      final targetIsObject = rawChannel['target'] is Map;
      final rawTarget = _object(rawChannel['target']);
      if (rawChannel.containsKey('sampler') && rawChannel['sampler'] is! int) {
        sink.error(
          'gltf.invalidAnimationSampler',
          'Animation channel sampler must be an integer.',
          jsonPath: '$channelPath.sampler',
        );
      } else if (channel.sampler == null) {
        sink.error(
          'gltf.missingAnimationSampler',
          'Animation channel sampler is required.',
          jsonPath: '$channelPath.sampler',
        );
      }
      if (channel.sampler != null) {
        _validateIndex(
          channel.sampler!,
          animation.samplers.length,
          sink,
          'gltf.invalidAnimationSampler',
          '$channelPath.sampler',
        );
      }
      if (!hasTarget) {
        sink.error(
          'gltf.missingAnimationTarget',
          'Animation channel target is required.',
          jsonPath: '$channelPath.target',
        );
      } else if (!targetIsObject) {
        sink.error(
          'gltf.invalidAnimationTarget',
          'Animation channel target must be a JSON object.',
          jsonPath: '$channelPath.target',
        );
      }
      if (rawTarget.containsKey('node') && rawTarget['node'] is! int) {
        sink.error(
          'gltf.invalidAnimationTargetNode',
          'Animation target node must be an integer.',
          jsonPath: '$channelPath.target.node',
        );
      } else if (channel.targetNode != null) {
        _validateIndex(
          channel.targetNode!,
          gltf.nodes.length,
          sink,
          'gltf.invalidAnimationTargetNode',
          '$channelPath.target.node',
        );
      } else if (targetIsObject && channel.targetExtensions.isEmpty) {
        sink.warning(
          'gltf.animationTargetWithoutNode',
          'Animation target without node needs an extension-defined target.',
          jsonPath: '$channelPath.target.node',
        );
      }
      if (targetIsObject &&
          !rawTarget.containsKey('path') &&
          channel.targetPath == null) {
        sink.error(
          'gltf.missingAnimationTargetPath',
          'Animation channel target path is required.',
          jsonPath: '$channelPath.target.path',
        );
      }
      if (channel.targetPath != null &&
          !const {
            'translation',
            'rotation',
            'scale',
            'weights',
          }.contains(channel.targetPath)) {
        sink.error(
          'gltf.invalidAnimationTargetPath',
          'Animation target path must be translation, rotation, scale, or weights.',
          jsonPath: '$channelPath.target.path',
        );
      }
      if (channel.targetPath == 'weights' &&
          channel.targetNode != null &&
          channel.targetNode! >= 0 &&
          channel.targetNode! < gltf.nodes.length &&
          !_animationTargetHasMorphTargets(gltf, channel.targetNode!)) {
        sink.error(
          'gltf.animationWeightsWithoutMorphTargets',
          'Animation weights channels must target a node with morph targets.',
          jsonPath: '$channelPath.target.path',
          gltfNodeIndex: channel.targetNode,
        );
      }
      final targetNode = channel.targetNode;
      final targetPath = channel.targetPath;
      if (targetNode != null &&
          targetPath != null &&
          !channelTargets.add('$targetNode/$targetPath')) {
        sink.error(
          'gltf.duplicateAnimationTarget',
          'Animation channels must not target the same node and path.',
          jsonPath: '$channelPath.target',
          gltfNodeIndex: targetNode,
        );
      }
      if (channel.sampler != null &&
          channel.sampler! >= 0 &&
          channel.sampler! < animation.samplers.length) {
        _validateAnimationChannelOutputCount(
          gltf,
          channel,
          animation.samplers[channel.sampler!],
          sink,
          _animationSamplerPath(animation.index, channel.sampler!),
        );
      }
    }
    for (
      var samplerIndex = 0;
      samplerIndex < animation.samplers.length;
      samplerIndex++
    ) {
      final sampler = animation.samplers[samplerIndex];
      final samplerPath = _animationSamplerPath(animation.index, samplerIndex);
      final rawSamplerValue = rawAnimationSamplers.elementAtOrNull(
        samplerIndex,
      );
      if (rawSamplerValue is! Map) {
        sink.error(
          'gltf.invalidAnimationSamplerObject',
          'Animation sampler entries must be JSON objects.',
          jsonPath: samplerPath,
        );
        continue;
      }
      final rawSampler = _object(rawSamplerValue);
      if (!rawSampler.containsKey('input')) {
        sink.error(
          'gltf.missingAnimationInput',
          'Animation sampler input accessor is required.',
          jsonPath: '$samplerPath.input',
        );
      } else if (rawSampler['input'] is! int) {
        sink.error(
          'gltf.invalidAnimationInput',
          'Animation sampler input must be an integer.',
          jsonPath: '$samplerPath.input',
        );
      }
      if (!rawSampler.containsKey('output')) {
        sink.error(
          'gltf.missingAnimationOutput',
          'Animation sampler output accessor is required.',
          jsonPath: '$samplerPath.output',
        );
      } else if (rawSampler['output'] is! int) {
        sink.error(
          'gltf.invalidAnimationOutput',
          'Animation sampler output must be an integer.',
          jsonPath: '$samplerPath.output',
        );
      }
      if (!const {
        'LINEAR',
        'STEP',
        'CUBICSPLINE',
      }.contains(sampler.interpolation)) {
        sink.error(
          'gltf.invalidAnimationInterpolation',
          'Animation sampler interpolation must be LINEAR, STEP, or CUBICSPLINE.',
          jsonPath: '$samplerPath.interpolation',
        );
      }
      if (sampler.input != null) {
        _validateIndex(
          sampler.input!,
          gltf.accessors.length,
          sink,
          'gltf.invalidAnimationInput',
          '$samplerPath.input',
        );
      }
      _validateAnimationSamplerAccessors(gltf, sampler, sink, samplerPath);
      if (sampler.output != null) {
        _validateIndex(
          sampler.output!,
          gltf.accessors.length,
          sink,
          'gltf.invalidAnimationOutput',
          '$samplerPath.output',
        );
      }
    }
  }
}

String _animationPath(int animationIndex, String suffix) =>
    '\$.animations[$animationIndex]$suffix';

String _animationChannelPath(int animationIndex, int channelIndex) =>
    _animationPath(animationIndex, '.channels[$channelIndex]');

String _animationSamplerPath(int animationIndex, int samplerIndex) =>
    _animationPath(animationIndex, '.samplers[$samplerIndex]');
