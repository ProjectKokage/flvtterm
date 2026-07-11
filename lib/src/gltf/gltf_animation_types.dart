part of '../../flvtterm.dart';

/// Parsed glTF animation.
final class GltfAnimation {
  GltfAnimation._({
    required this.index,
    required this.name,
    required List<GltfAnimationChannel> channels,
    required List<GltfAnimationSampler> samplers,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : channels = List.unmodifiable(channels),
       samplers = List.unmodifiable(samplers),
       extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// glTF animation index.
  final int index;

  /// Optional animation name.
  final String? name;

  /// Animation channels.
  final List<GltfAnimationChannel> channels;

  /// Animation samplers.
  final List<GltfAnimationSampler> samplers;

  /// Animation extensions, preserved.
  final Map<String, Object?> extensions;

  /// Animation extras, preserved.
  final Object? extras;
}

/// Parsed glTF animation channel.
final class GltfAnimationChannel {
  GltfAnimationChannel._({
    required this.sampler,
    required this.targetNode,
    required this.targetPath,
    required Map<String, Object?> targetExtensions,
    required Object? targetExtras,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : targetExtensions =
           _immutableJsonValue(targetExtensions) as Map<String, Object?>,
       targetExtras = _immutableJsonValue(targetExtras),
       extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// Referenced animation sampler index.
  final int? sampler;

  /// Target node index.
  final int? targetNode;

  /// Target path such as `translation`, `rotation`, `scale`, or `weights`.
  final String? targetPath;

  /// Animation channel target extensions, preserved.
  final Map<String, Object?> targetExtensions;

  /// Animation channel target extras, preserved.
  final Object? targetExtras;

  /// Animation channel extensions, preserved.
  final Map<String, Object?> extensions;

  /// Animation channel extras, preserved.
  final Object? extras;
}

/// Parsed glTF animation sampler.
final class GltfAnimationSampler {
  GltfAnimationSampler._({
    required this.input,
    required this.output,
    required this.interpolation,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// Input accessor index.
  final int? input;

  /// Output accessor index.
  final int? output;

  /// Interpolation mode.
  final String interpolation;

  /// Animation sampler extensions, preserved.
  final Map<String, Object?> extensions;

  /// Animation sampler extras, preserved.
  final Object? extras;
}

/// Evaluated values for a glTF animation at one point in time.
final class GltfAnimationFrame {
  GltfAnimationFrame._({
    required Map<int, GltfNodePose> nodePoses,
    required Map<int, List<double>> morphWeights,
  }) : nodePoses = Map.unmodifiable({
         for (final entry in nodePoses.entries)
           entry.key: _copyNodePose(entry.value),
       }),
       morphWeights = Map.unmodifiable({
         for (final entry in morphWeights.entries)
           entry.key: List<double>.unmodifiable(entry.value),
       });

  /// Node transform values by glTF node index.
  final Map<int, GltfNodePose> nodePoses;

  /// Morph target weights by glTF node index.
  final Map<int, List<double>> morphWeights;
}

/// Partial node pose produced by a glTF animation.
final class GltfNodePose {
  /// Creates a partial node pose.
  GltfNodePose({
    List<double>? translation,
    List<double>? rotation,
    List<double>? scale,
  }) : translation = translation == null
           ? null
           : List.unmodifiable(translation),
       rotation = rotation == null ? null : List.unmodifiable(rotation),
       scale = scale == null ? null : List.unmodifiable(scale);

  /// Animated translation.
  final List<double>? translation;

  /// Animated rotation quaternion.
  final List<double>? rotation;

  /// Animated scale.
  final List<double>? scale;
}

/// Static motion source for applying a programmatic pose through
/// [VrmMotionController].
final class VrmProgrammaticPose {
  /// Creates a programmatic pose.
  VrmProgrammaticPose({
    Map<int, GltfNodePose> nodePoses = const {},
    Map<int, List<double>> morphWeights = const {},
    Map<String, double> expressionWeights = const {},
    this.lookAtYawDegrees,
    this.lookAtPitchDegrees,
  }) : nodePoses = Map.unmodifiable({
         for (final entry in nodePoses.entries)
           entry.key: _copyNodePose(entry.value),
       }),
       morphWeights = Map.unmodifiable({
         for (final entry in morphWeights.entries)
           entry.key: List<double>.unmodifiable(entry.value),
       }),
       expressionWeights = Map.unmodifiable(expressionWeights);

  /// Node poses by destination glTF node index.
  final Map<int, GltfNodePose> nodePoses;

  /// Morph target weights by destination glTF node index.
  final Map<int, List<double>> morphWeights;

  /// Expression weights by VRM preset or custom expression name.
  final Map<String, double> expressionWeights;

  /// Optional LookAt yaw in degrees.
  final double? lookAtYawDegrees;

  /// Optional LookAt pitch in degrees.
  final double? lookAtPitchDegrees;
}

GltfNodePose _copyNodePose(GltfNodePose pose) {
  return GltfNodePose(
    translation: _copyDoubleList(pose.translation),
    rotation: _copyDoubleList(pose.rotation),
    scale: _copyDoubleList(pose.scale),
  );
}

List<double>? _copyDoubleList(List<double>? values) =>
    values == null ? null : List<double>.unmodifiable(values);

/// Produces a renderer-neutral procedural pose for local motion time in
/// seconds.
typedef VrmProceduralMotion = VrmProgrammaticPose Function(double timeSeconds);

/// Evaluates glTF animation clips from parsed accessors.
final class GltfAnimationEvaluator {
  /// Creates an evaluator for [gltf].
  const GltfAnimationEvaluator(this.gltf);

  /// Parsed glTF asset.
  final GltfAsset gltf;

  /// Returns the animation duration in seconds.
  double duration(int animationIndex) {
    final animation = gltf.animations[animationIndex];
    var duration = 0.0;
    for (final sampler in animation.samplers) {
      final input = _readSamplerTimes(sampler);
      if (input != null && input.isNotEmpty && input.last > duration) {
        duration = input.last;
      }
    }
    return duration;
  }

  /// Evaluates [animationIndex] at [timeSeconds].
  GltfAnimationFrame evaluate(
    int animationIndex,
    double timeSeconds, {
    bool loop = false,
  }) {
    final animation = gltf.animations[animationIndex];
    var evaluationTime = timeSeconds;
    if (loop) {
      final clipDuration = duration(animationIndex);
      if (clipDuration > 0) {
        evaluationTime %= clipDuration;
        if (evaluationTime < 0) evaluationTime += clipDuration;
      }
    }
    final poses = <int, GltfNodePose>{};
    final morphWeights = <int, List<double>>{};

    for (final channel in animation.channels) {
      final node = channel.targetNode;
      final samplerIndex = channel.sampler;
      final path = channel.targetPath;
      if (node == null || samplerIndex == null || path == null) continue;
      if (samplerIndex < 0 || samplerIndex >= animation.samplers.length) {
        continue;
      }
      final sampler = animation.samplers[samplerIndex];
      final valueDimension = _animationValueDimension(node, path, sampler);
      if (valueDimension == null) continue;
      final value = _evaluateSampler(
        sampler,
        path,
        valueDimension,
        evaluationTime,
      );
      if (value == null) continue;

      if (path == 'weights') {
        morphWeights[node] = List.unmodifiable(value);
      } else {
        final existing = poses[node];
        poses[node] = GltfNodePose(
          translation: path == 'translation' ? value : existing?.translation,
          rotation: path == 'rotation' ? value : existing?.rotation,
          scale: path == 'scale' ? value : existing?.scale,
        );
      }
    }

    return GltfAnimationFrame._(
      nodePoses: Map.unmodifiable(poses),
      morphWeights: Map.unmodifiable(morphWeights),
    );
  }

  int? _animationValueDimension(
    int node,
    String path,
    GltfAnimationSampler sampler,
  ) {
    return switch (path) {
      'translation' || 'scale' => 3,
      'rotation' => 4,
      'weights' => _morphTargetCount(node) ?? _inferWeightDimension(sampler),
      _ => null,
    };
  }

  int? _morphTargetCount(int nodeIndex) {
    final meshIndex = gltf.nodes.elementAtOrNull(nodeIndex)?.mesh;
    final mesh = meshIndex == null
        ? null
        : gltf.meshes.elementAtOrNull(meshIndex);
    if (mesh == null || mesh.primitives.isEmpty) return null;
    return mesh.primitives.first.targets.length;
  }

  int? _inferWeightDimension(GltfAnimationSampler sampler) {
    final input = sampler.input == null
        ? null
        : _readAccessorScalars(sampler.input!);
    final output = sampler.output == null
        ? null
        : _readAccessorScalars(sampler.output!);
    if (input == null || output == null || input.isEmpty) return null;
    final frameMultiplier = sampler.interpolation == 'CUBICSPLINE' ? 3 : 1;
    final divisor = input.length * frameMultiplier;
    if (divisor == 0 || output.length % divisor != 0) return null;
    return output.length ~/ divisor;
  }

  List<double>? _evaluateSampler(
    GltfAnimationSampler sampler,
    String targetPath,
    int valueDimension,
    double timeSeconds,
  ) {
    if (sampler.input == null || sampler.output == null) return null;
    if (!_animationSamplerAccessorsAreRunnable(sampler, targetPath)) {
      return null;
    }
    final times = _readSamplerTimes(sampler);
    final output = _readAccessorNumbers(gltf, sampler.output!);
    if (times == null || output == null) return null;
    if (output.any((value) => !value.isFinite)) return null;
    final interpolation = sampler.interpolation;
    if (interpolation != 'LINEAR' &&
        interpolation != 'STEP' &&
        interpolation != 'CUBICSPLINE') {
      return null;
    }
    if (interpolation == 'CUBICSPLINE' && times.length < 2) return null;
    final outputMultiplier = interpolation == 'CUBICSPLINE' ? 3 : 1;
    final expectedOutputLength =
        times.length * outputMultiplier * valueDimension;
    if (output.length != expectedOutputLength) return null;

    final time = timeSeconds;
    if (time <= times.first) {
      return _animationSamplerValue(
        output,
        0,
        valueDimension,
        interpolation,
        targetPath,
      );
    }
    if (time >= times.last) {
      return _animationSamplerValue(
        output,
        times.length - 1,
        valueDimension,
        interpolation,
        targetPath,
      );
    }
    for (var i = 1; i < times.length - 1; i++) {
      if (time == times[i]) {
        return _animationSamplerValue(
          output,
          i,
          valueDimension,
          interpolation,
          targetPath,
        );
      }
    }

    var key = 0;
    while (key + 1 < times.length && times[key + 1] < time) {
      key++;
    }
    final startTime = times[key];
    final endTime = times[key + 1];
    final localT = (time - startTime) / (endTime - startTime);

    if (interpolation == 'STEP') {
      return _animationSamplerValue(
        output,
        key,
        valueDimension,
        interpolation,
        targetPath,
      );
    }
    if (interpolation == 'CUBICSPLINE') {
      final value = _cubicSpline(
        output,
        key,
        valueDimension,
        localT,
        endTime - startTime,
      );
      return targetPath == 'rotation' ? _normalize(value) : value;
    }

    final a = _samplerValue(output, key, valueDimension, interpolation);
    final b = _samplerValue(output, key + 1, valueDimension, interpolation);
    return targetPath == 'rotation'
        ? _slerp(a, b, localT)
        : _lerpList(a, b, localT);
  }

  List<double> _animationSamplerValue(
    List<double> output,
    int key,
    int valueDimension,
    String interpolation,
    String targetPath,
  ) {
    final value = _samplerValue(output, key, valueDimension, interpolation);
    return targetPath == 'rotation' ? _normalize(value) : value;
  }

  bool _animationSamplerAccessorsAreRunnable(
    GltfAnimationSampler sampler,
    String targetPath,
  ) {
    final input = gltf.accessors.elementAtOrNull(sampler.input!);
    final output = gltf.accessors.elementAtOrNull(sampler.output!);
    if (input == null || output == null) return false;
    if (input.type != 'SCALAR' ||
        input.componentType != 5126 ||
        input.normalized) {
      return false;
    }
    final outputType = switch (targetPath) {
      'translation' || 'scale' => 'VEC3',
      'rotation' => 'VEC4',
      'weights' => 'SCALAR',
      _ => null,
    };
    return outputType != null &&
        output.type == outputType &&
        _isValidAnimationOutputComponent(output, targetPath);
  }

  List<double>? _readSamplerTimes(GltfAnimationSampler sampler) {
    if (sampler.input == null) return null;
    final input = gltf.accessors.elementAtOrNull(sampler.input!);
    if (input == null ||
        input.type != 'SCALAR' ||
        input.componentType != 5126 ||
        input.normalized ||
        input.minimum == null ||
        input.maximum == null) {
      return null;
    }
    final times = _readAccessorScalars(sampler.input!);
    if (times == null || times.isEmpty) return null;
    if (times.first < 0 || !_isStrictlyIncreasing(times)) return null;
    return times;
  }

  List<double>? _readAccessorScalars(int accessorIndex) {
    return _readAccessorNumbers(gltf, accessorIndex, requireFloat: true);
  }
}
