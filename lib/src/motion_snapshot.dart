part of '../flvtterm.dart';

extension _VrmMotionSnapshot on VrmMotionController {
  _MotionSnapshot? _captureSnapshot() {
    final target = _captureRawSnapshot();
    if (target == null) return null;
    final fade = _fadeWeight;
    if (fade >= 1) return target;
    final source = _crossFadeFrom;
    if (fade <= 0 && source != null) return source;
    return _blendSnapshots(source, target, fade);
  }

  _MotionSnapshot? _captureRawSnapshot() {
    final programmaticPose = _programmaticPose;
    if (programmaticPose != null) {
      return _snapshotProgrammaticPose(programmaticPose);
    }
    final proceduralMotion = _proceduralMotion;
    if (proceduralMotion != null) {
      return _snapshotProgrammaticPose(proceduralMotion(_timeSeconds));
    }

    final animationIndex = _animationIndex;
    if (animationIndex == null) return null;
    final vrma = _vrma;
    if (vrma != null) {
      return _captureVrmaMotionSnapshot(this, vrma, animationIndex);
    }
    final evaluator = _externalGltfEvaluator ?? _evaluator;
    final frame = evaluator.evaluate(animationIndex, _timeSeconds);
    return _MotionSnapshot(
      nodePoses: frame.nodePoses,
      morphWeights: frame.morphWeights,
    );
  }

  _MotionSnapshot _snapshotProgrammaticPose(VrmProgrammaticPose pose) {
    final yaw = pose.lookAtYawDegrees;
    final pitch = pose.lookAtPitchDegrees;
    return _MotionSnapshot(
      nodePoses: pose.nodePoses,
      morphWeights: pose.morphWeights,
      expressionWeights: {
        for (final entry in pose.expressionWeights.entries)
          entry.key: _clamp01(entry.value),
      },
      lookAt: yaw == null || pitch == null ? null : _YawPitch(yaw, pitch),
    );
  }

  _MotionSnapshot _blendSnapshots(
    _MotionSnapshot? source,
    _MotionSnapshot target,
    double fade,
  ) {
    return _MotionSnapshot(
      nodePoses: _blendSnapshotNodePoses(
        source?.nodePoses ?? const {},
        target.nodePoses,
        fade,
      ),
      modelRootPose: _blendSnapshotRootPose(
        source?.modelRootPose,
        target.modelRootPose,
        fade,
      ),
      morphWeights: _blendSnapshotMorphWeights(
        source?.morphWeights ?? const {},
        target.morphWeights,
        fade,
      ),
      expressionWeights: _blendSnapshotExpressionWeights(
        source?.expressionWeights ?? const {},
        target.expressionWeights,
        fade,
      ),
      lookAt: _lerpSnapshotLookAt(source?.lookAt, target.lookAt, fade),
    );
  }

  Map<int, GltfNodePose> _blendSnapshotNodePoses(
    Map<int, GltfNodePose> source,
    Map<int, GltfNodePose> target,
    double fade,
  ) {
    final result = <int, GltfNodePose>{};
    for (final nodeIndex in {...source.keys, ...target.keys}) {
      final node = model.gltf.nodes.elementAtOrNull(nodeIndex);
      if (node == null) continue;
      final from = source[nodeIndex];
      final to = target[nodeIndex];
      result[nodeIndex] = GltfNodePose(
        translation: _lerpList(
          _snapshotListOr(from?.translation, node.restTranslation, 3),
          _snapshotListOr(to?.translation, node.restTranslation, 3),
          fade,
        ),
        rotation: _slerp(
          _snapshotListOr(from?.rotation, node.restRotation, 4),
          _snapshotListOr(to?.rotation, node.restRotation, 4),
          fade,
        ),
        scale: _lerpList(
          _snapshotListOr(from?.scale, node.restScale, 3),
          _snapshotListOr(to?.scale, node.restScale, 3),
          fade,
        ),
      );
    }
    return Map.unmodifiable(result);
  }

  GltfNodePose? _blendSnapshotRootPose(
    GltfNodePose? source,
    GltfNodePose? target,
    double fade,
  ) {
    if (source == null && target == null) return null;
    return GltfNodePose(
      translation: _lerpList(
        _snapshotListOr(source?.translation, const [0.0, 0.0, 0.0], 3),
        _snapshotListOr(target?.translation, const [0.0, 0.0, 0.0], 3),
        fade,
      ),
      rotation: _slerp(
        _snapshotListOr(source?.rotation, const [0.0, 0.0, 0.0, 1.0], 4),
        _snapshotListOr(target?.rotation, const [0.0, 0.0, 0.0, 1.0], 4),
        fade,
      ),
      scale: _lerpList(
        _snapshotListOr(source?.scale, const [1.0, 1.0, 1.0], 3),
        _snapshotListOr(target?.scale, const [1.0, 1.0, 1.0], 3),
        fade,
      ),
    );
  }

  Map<int, List<double>> _blendSnapshotMorphWeights(
    Map<int, List<double>> source,
    Map<int, List<double>> target,
    double fade,
  ) {
    final result = <int, List<double>>{};
    for (final nodeIndex in {...source.keys, ...target.keys}) {
      final node = model.gltf.nodes.elementAtOrNull(nodeIndex);
      final meshIndex = node?.mesh;
      final mesh = meshIndex == null
          ? null
          : model.gltf.meshes.elementAtOrNull(meshIndex);
      final base = node == null || node.weights.isEmpty
          ? mesh?.weights ?? const <double>[]
          : node.weights;
      final from = source[nodeIndex] ?? const <double>[];
      final to = target[nodeIndex] ?? const <double>[];
      final count = math.max(from.length, to.length);
      result[nodeIndex] = List<double>.unmodifiable([
        for (var index = 0; index < count; index++)
          _snapshotAt(from, index, _snapshotAt(base, index, 0.0)) * (1 - fade) +
              _snapshotAt(to, index, _snapshotAt(base, index, 0.0)) * fade,
      ]);
    }
    return Map.unmodifiable(result);
  }

  Map<String, double> _blendSnapshotExpressionWeights(
    Map<String, double> source,
    Map<String, double> target,
    double fade,
  ) {
    return Map.unmodifiable({
      for (final name in {...source.keys, ...target.keys})
        name: _clamp01(
          (source[name] ?? 0.0) * (1 - fade) + (target[name] ?? 0.0) * fade,
        ),
    });
  }

  Map<String, double> _blendMotionInputs(
    Map<String, double> target,
    double fade,
  ) {
    final source =
        _crossFadeFrom?.expressionWeights ?? const <String, double>{};
    return {
      for (final name in {...source.keys, ...target.keys})
        name: _clamp01(
          (source[name] ?? 0.0) * (1 - fade) + (target[name] ?? 0.0) * fade,
        ),
    };
  }

  _YawPitch? _blendLookAt(_YawPitch? target, double fade) =>
      _lerpSnapshotLookAt(_crossFadeFrom?.lookAt, target, fade);
}

_YawPitch? _lerpSnapshotLookAt(
  _YawPitch? source,
  _YawPitch? target,
  double fade,
) {
  if (source == null && target == null) return null;
  return _YawPitch(
    (source?.yawDegrees ?? 0.0) * (1 - fade) +
        (target?.yawDegrees ?? 0.0) * fade,
    (source?.pitchDegrees ?? 0.0) * (1 - fade) +
        (target?.pitchDegrees ?? 0.0) * fade,
  );
}

List<double> _snapshotListOr(
  List<double>? value,
  List<double> fallback,
  int length,
) {
  if (value == null || value.length < length) return fallback;
  for (var index = 0; index < length; index++) {
    if (!value[index].isFinite) return fallback;
  }
  return value;
}

double _snapshotAt(List<double> values, int index, double fallback) {
  if (index >= values.length) return fallback;
  final value = values[index];
  return value.isFinite ? value : fallback;
}

final class _MotionSnapshot {
  const _MotionSnapshot({
    this.nodePoses = const {},
    this.modelRootPose,
    this.morphWeights = const {},
    this.expressionWeights = const {},
    this.lookAt,
  });

  final Map<int, GltfNodePose> nodePoses;
  final GltfNodePose? modelRootPose;
  final Map<int, List<double>> morphWeights;
  final Map<String, double> expressionWeights;
  final _YawPitch? lookAt;
}
