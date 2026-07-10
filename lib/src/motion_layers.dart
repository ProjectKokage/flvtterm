part of '../flvtterm.dart';

/// Additive motion-layer controls for [VrmMotionController].
extension VrmAdditiveMotionLayers on VrmMotionController {
  /// Number of active additive layers.
  int get additiveLayerCount => _additiveLayers.length;

  /// Adds any supported motion [source] as an additive layer.
  ///
  /// An [int] selects an embedded glTF animation. [GltfAsset],
  /// [VrmAnimationAsset], [VrmProgrammaticPose], and [VrmProceduralMotion] use
  /// the same source forms accepted by [play]. Animated node and morph values
  /// are converted to deltas from the source rest pose before application.
  /// Returns an ID for updating, seeking, or removing the layer.
  int addAdditiveLayer(
    Object source, {
    int? animationIndex,
    bool loop = false,
    double speed = 1,
    double startTimeSeconds = 0,
    Duration? startTime,
    double weight = 1,
    double hipsTranslationScale = 1,
    Set<int>? nodeMask,
    Set<VrmHumanoidBone>? humanoidMask,
  }) {
    GltfAnimationEvaluator? evaluator;
    GltfAsset? referenceGltf;
    int? selectedAnimation;

    if (source is int) {
      selectedAnimation = source;
      evaluator = _evaluator;
      referenceGltf = model.gltf;
      _checkAdditiveAnimationIndex(
        selectedAnimation,
        model.gltf.animations,
        'VRM model does not contain embedded glTF animations.',
      );
    } else if (source is GltfAsset) {
      selectedAnimation = animationIndex ?? 0;
      evaluator = GltfAnimationEvaluator(source);
      referenceGltf = source;
      _checkAdditiveAnimationIndex(
        selectedAnimation,
        source.animations,
        'glTF asset does not contain animations.',
      );
    } else if (source is VrmAnimationAsset) {
      selectedAnimation = animationIndex ?? source.defaultAnimationIndex;
      if (selectedAnimation == null) {
        throw StateError('VRMA asset does not contain glTF animations.');
      }
      evaluator = GltfAnimationEvaluator(source.gltf);
      referenceGltf = source.gltf;
      _checkAdditiveAnimationIndex(
        selectedAnimation,
        source.gltf.animations,
        'VRMA asset does not contain glTF animations.',
      );
    } else if (source is! VrmProgrammaticPose &&
        source is! VrmProceduralMotion) {
      throw ArgumentError.value(
        source,
        'source',
        'Expected int, GltfAsset, VrmAnimationAsset, VrmProgrammaticPose, or VrmProceduralMotion.',
      );
    }

    final duration = selectedAnimation == null
        ? 0.0
        : evaluator!.duration(selectedAnimation);
    final layer = _AdditiveMotionLayer(
      id: _nextAdditiveLayerId++,
      source: source,
      evaluator: evaluator,
      referenceGltf: referenceGltf,
      vrmaRetargetPlan: source is VrmAnimationAsset
          ? _VrmaRetargetPlan(
              model,
              source,
              destinationRestWorldRotations: _modelRestWorldRotations,
            )
          : null,
      animationIndex: selectedAnimation,
      durationSeconds: duration,
      loop: loop,
      speed: _finiteOrZero(speed),
      timeSeconds: _startTimeSeconds(startTime, startTimeSeconds),
      weight: _clamp01(weight),
      hipsTranslationScale: hipsTranslationScale.isFinite
          ? hipsTranslationScale
          : 1,
      nodeMask: _resolveNodeMask(nodeMask, humanoidMask),
    );
    if (source is VrmProgrammaticPose) {
      layer.frame = _snapshotProgrammaticPose(source);
    }
    layer.normalizeTime();
    _additiveLayers.add(layer);
    return layer.id;
  }

  /// Updates an additive layer's blend weight. Returns false for an unknown ID.
  bool setAdditiveLayerWeight(int layerId, double weight) {
    for (final layer in _additiveLayers) {
      if (layer.id != layerId) continue;
      layer.weight = _clamp01(weight);
      return true;
    }
    return false;
  }

  /// Seeks an additive layer. Returns false for an unknown ID.
  bool seekAdditiveLayer(int layerId, Duration position) {
    for (final layer in _additiveLayers) {
      if (layer.id != layerId) continue;
      layer.timeSeconds =
          position.inMicroseconds / Duration.microsecondsPerSecond;
      layer.normalizeTime();
      return true;
    }
    return false;
  }

  /// Removes one additive layer. Returns false for an unknown ID.
  bool removeAdditiveLayer(int layerId) {
    final index = _additiveLayers.indexWhere((layer) => layer.id == layerId);
    if (index < 0) return false;
    _additiveLayers.removeAt(index);
    return true;
  }

  /// Removes every additive layer.
  void clearAdditiveLayers() {
    _additiveLayers.clear();
  }

  void _updateAdditiveLayers(double deltaSeconds) {
    for (final layer in _additiveLayers) {
      layer.advance(deltaSeconds);
    }
  }

  void _evaluateAdditiveLayers() {
    for (final layer in _additiveLayers) {
      final source = layer.source;
      if (source is VrmProgrammaticPose) continue;
      if (source is VrmProceduralMotion) {
        layer.frame = _snapshotProgrammaticPose(source(layer.timeSeconds));
        continue;
      }
      final evaluator = layer.evaluator!;
      final animationIndex = layer.animationIndex!;
      final evaluated = evaluator.evaluate(animationIndex, layer.timeSeconds);
      if (source is VrmAnimationAsset) {
        final retargeted = _snapshotVrmaFrame(
          this,
          source,
          evaluated,
          isNodeAllowed: layer.allowsNode,
          hipsTranslationScale: layer.hipsTranslationScale,
          retargetPlan: layer.vrmaRetargetPlan,
        );
        layer.frame = _relativeAdditiveSnapshot(
          retargeted,
          model.gltf,
          layer.allowsNode,
          preserveModelRoot: true,
        );
      } else {
        layer.frame = _relativeAdditiveSnapshot(
          _MotionSnapshot(
            nodePoses: evaluated.nodePoses,
            morphWeights: evaluated.morphWeights,
          ),
          layer.referenceGltf!,
          layer.allowsNode,
        );
      }
    }
  }

  void _checkAdditiveAnimationIndex(
    int index,
    List<GltfAnimation> animations,
    String emptyMessage,
  ) {
    if (animations.isEmpty) throw StateError(emptyMessage);
    if (index < 0 || index >= animations.length) {
      throw RangeError.range(index, 0, animations.length - 1, 'animationIndex');
    }
  }
}

final class _AdditiveMotionLayer {
  _AdditiveMotionLayer({
    required this.id,
    required this.source,
    required this.evaluator,
    required this.referenceGltf,
    required this.vrmaRetargetPlan,
    required this.animationIndex,
    required this.durationSeconds,
    required this.loop,
    required this.speed,
    required this.timeSeconds,
    required this.weight,
    required this.hipsTranslationScale,
    required this.nodeMask,
  });

  final int id;
  final Object source;
  final GltfAnimationEvaluator? evaluator;
  final GltfAsset? referenceGltf;
  final _VrmaRetargetPlan? vrmaRetargetPlan;
  final int? animationIndex;
  final double durationSeconds;
  final bool loop;
  final double speed;
  final double hipsTranslationScale;
  final Set<int>? nodeMask;
  double timeSeconds;
  double weight;
  _MotionSnapshot frame = const _MotionSnapshot();

  bool allowsNode(int nodeIndex) =>
      nodeMask == null || nodeMask!.contains(nodeIndex);

  void advance(double deltaSeconds) {
    if (source is VrmProgrammaticPose) return;
    timeSeconds += deltaSeconds * speed;
    if (source is! VrmProceduralMotion) normalizeTime();
  }

  void normalizeTime() {
    if (source is VrmProgrammaticPose || source is VrmProceduralMotion) return;
    if (durationSeconds <= 0) {
      timeSeconds = 0;
    } else if (loop) {
      timeSeconds %= durationSeconds;
      if (timeSeconds < 0) timeSeconds += durationSeconds;
    } else {
      timeSeconds = timeSeconds.clamp(0.0, durationSeconds).toDouble();
    }
  }
}

_MotionSnapshot _relativeAdditiveSnapshot(
  _MotionSnapshot source,
  GltfAsset reference,
  bool Function(int nodeIndex) allowsNode, {
  bool preserveModelRoot = false,
}) {
  final nodePoses = <int, GltfNodePose>{};
  for (final entry in source.nodePoses.entries) {
    if (!allowsNode(entry.key)) continue;
    final node = reference.nodes.elementAtOrNull(entry.key);
    if (node == null) continue;
    nodePoses[entry.key] = _relativeAdditiveNodePose(entry.value, node);
  }
  final morphWeights = <int, List<double>>{};
  for (final entry in source.morphWeights.entries) {
    if (!allowsNode(entry.key)) continue;
    final node = reference.nodes.elementAtOrNull(entry.key);
    final mesh = node?.mesh == null
        ? null
        : reference.meshes.elementAtOrNull(node!.mesh!);
    if (node == null || mesh == null) continue;
    final base = node.weights.isEmpty ? mesh.weights : node.weights;
    morphWeights[entry.key] = [
      for (var index = 0; index < entry.value.length; index++)
        entry.value[index] - (base.elementAtOrNull(index) ?? 0.0),
    ];
  }
  return _MotionSnapshot(
    nodePoses: Map.unmodifiable(nodePoses),
    modelRootPose: preserveModelRoot ? source.modelRootPose : null,
    morphWeights: Map.unmodifiable(morphWeights),
    expressionWeights: source.expressionWeights,
    lookAt: source.lookAt,
  );
}

GltfNodePose _relativeAdditiveNodePose(GltfNodePose pose, GltfNode rest) {
  final translation = pose.translation;
  final rotation = pose.rotation;
  final scale = pose.scale;
  return GltfNodePose(
    translation: translation != null && translation.length >= 3
        ? [
            translation[0] - rest.restTranslation[0],
            translation[1] - rest.restTranslation[1],
            translation[2] - rest.restTranslation[2],
          ]
        : null,
    rotation: rotation != null && rotation.length >= 4
        ? _quatMultiply(_quatInverse(rest.restRotation), rotation)
        : null,
    scale: scale != null && scale.length >= 3
        ? [
            _relativeScale(scale[0], rest.restScale[0]),
            _relativeScale(scale[1], rest.restScale[1]),
            _relativeScale(scale[2], rest.restScale[2]),
          ]
        : null,
  );
}

double _relativeScale(double value, double rest) =>
    rest == 0 ? 1 : value / rest;
