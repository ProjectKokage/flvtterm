part of '../../flvtterm.dart';

List<GltfAnimation> _parseAnimations(Object? value, _DiagnosticSink sink) {
  final list = _list(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfAnimation._(
        index: i,
        name: _string(_object(list[i])['name']),
        channels: _parseAnimationChannels(
          i,
          _object(list[i])['channels'],
          sink,
        ),
        samplers: _parseAnimationSamplers(
          i,
          _object(list[i])['samplers'],
          sink,
        ),
        extensions: _object(_object(list[i])['extensions']),
        extras: _object(list[i])['extras'],
      ),
  ];
}

List<GltfAnimationChannel> _parseAnimationChannels(
  int animationIndex,
  Object? value,
  _DiagnosticSink sink,
) {
  final list = _list(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfAnimationChannel._(
        sampler: _int(_object(list[i])['sampler']),
        targetNode: _int(_object(_object(list[i])['target'])['node']),
        targetPath: _parseAnimationTargetPath(
          _object(_object(list[i])['target']),
          sink,
          animationIndex,
          i,
        ),
        targetExtensions: _object(
          _object(_object(list[i])['target'])['extensions'],
        ),
        targetExtras: _object(_object(list[i])['target'])['extras'],
        extensions: _object(_object(list[i])['extensions']),
        extras: _object(list[i])['extras'],
      ),
  ];
}

List<GltfAnimationSampler> _parseAnimationSamplers(
  int animationIndex,
  Object? value,
  _DiagnosticSink sink,
) {
  final list = _list(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfAnimationSampler._(
        input: _int(_object(list[i])['input']),
        output: _int(_object(list[i])['output']),
        interpolation: _parseAnimationInterpolation(
          _object(list[i]),
          sink,
          animationIndex,
          i,
        ),
        extensions: _object(_object(list[i])['extensions']),
        extras: _object(list[i])['extras'],
      ),
  ];
}

String? _parseAnimationTargetPath(
  Map<String, Object?> target,
  _DiagnosticSink sink,
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
  _DiagnosticSink sink,
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
