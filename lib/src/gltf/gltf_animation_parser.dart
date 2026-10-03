import 'package:meta/meta.dart';

import '../diagnostics.dart';
import '../json_values.dart';
import 'gltf_animation_types.dart';

@internal
List<GltfAnimation> parseAnimations(Object? value, DiagnosticSink sink) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfAnimation.internal(
        index: i,
        name: jsonString(jsonObject(list[i])['name']),
        channels: _parseAnimationChannels(
          i,
          jsonObject(list[i])['channels'],
          sink,
        ),
        samplers: _parseAnimationSamplers(
          i,
          jsonObject(list[i])['samplers'],
          sink,
        ),
        extensions: jsonObject(jsonObject(list[i])['extensions']),
        extras: jsonObject(list[i])['extras'],
      ),
  ];
}

List<GltfAnimationChannel> _parseAnimationChannels(
  int animationIndex,
  Object? value,
  DiagnosticSink sink,
) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfAnimationChannel.internal(
        sampler: jsonInt(jsonObject(list[i])['sampler']),
        targetNode: jsonInt(jsonObject(jsonObject(list[i])['target'])['node']),
        targetPath: _parseAnimationTargetPath(
          jsonObject(jsonObject(list[i])['target']),
          sink,
          animationIndex,
          i,
        ),
        targetExtensions: jsonObject(
          jsonObject(jsonObject(list[i])['target'])['extensions'],
        ),
        targetExtras: jsonObject(jsonObject(list[i])['target'])['extras'],
        extensions: jsonObject(jsonObject(list[i])['extensions']),
        extras: jsonObject(list[i])['extras'],
      ),
  ];
}

List<GltfAnimationSampler> _parseAnimationSamplers(
  int animationIndex,
  Object? value,
  DiagnosticSink sink,
) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfAnimationSampler.internal(
        input: jsonInt(jsonObject(list[i])['input']),
        output: jsonInt(jsonObject(list[i])['output']),
        interpolation: _parseAnimationInterpolation(
          jsonObject(list[i]),
          sink,
          animationIndex,
          i,
        ),
        extensions: jsonObject(jsonObject(list[i])['extensions']),
        extras: jsonObject(list[i])['extras'],
      ),
  ];
}

String? _parseAnimationTargetPath(
  Map<String, Object?> target,
  DiagnosticSink sink,
  int animationIndex,
  int channelIndex,
) {
  final value = target['path'];
  if (value == null) return null;
  if (value is String) return value;
  sink.error(
    'gltf.invalidAnimationTargetPath',
    'Animation target path must be a string.',
    jsonPath:
        '\$.animations[$animationIndex].channels[$channelIndex].target.path',
  );
  return null;
}

String _parseAnimationInterpolation(
  Map<String, Object?> sampler,
  DiagnosticSink sink,
  int animationIndex,
  int samplerIndex,
) {
  final value = sampler['interpolation'];
  if (value == null) return 'LINEAR';
  if (value is String) return value;
  sink.error(
    'gltf.invalidAnimationInterpolation',
    'Animation sampler interpolation must be a string.',
    jsonPath:
        '\$.animations[$animationIndex].samplers[$samplerIndex].interpolation',
  );
  return 'LINEAR';
}
