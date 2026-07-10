part of '../flvtterm.dart';

extension _VrmMotionApply on VrmMotionController {
  void _applyProgrammaticPose(
    VrmSceneBinding binding,
    VrmExpressionController expressions,
    VrmLookAtController lookAt,
    VrmProgrammaticPose pose,
  ) {
    final fade = _fadeWeight;
    _applyNodePoses(
      binding,
      pose.nodePoses,
      fade,
      from: _crossFadeFrom?.nodePoses,
    );
    _applyMorphWeights(
      binding,
      pose.morphWeights,
      fade,
      from: _crossFadeFrom?.morphWeights,
    );
    expressions._setMotionInputs(
      _additiveMotionInputs(
        _blendMotionInputs({
          for (final entry in pose.expressionWeights.entries)
            entry.key: _clamp01(entry.value),
        }, fade),
      ),
    );
    final yaw = pose.lookAtYawDegrees;
    final pitch = pose.lookAtPitchDegrees;
    lookAt._setMotionYawPitch(
      _additiveLookAt(
        _blendLookAt(
          yaw == null || pitch == null ? null : _YawPitch(yaw, pitch),
          fade,
        ),
      ),
    );
    _applyAdditiveNodePoses(binding);
    _applyModelRootPose(
      binding,
      null,
      fade,
      from: _crossFadeFrom?.modelRootPose,
    );
    _clearIfFadeOutFinished();
    _clearFinishedCrossFade();
  }

  void _applyNodePoses(
    VrmSceneBinding binding,
    Map<int, GltfNodePose> nodePoses,
    double fade, {
    Map<int, GltfNodePose>? from,
  }) {
    final fromPoses = from ?? const <int, GltfNodePose>{};
    final nodeIndices = {...fromPoses.keys, ...nodePoses.keys};
    for (final nodeIndex in nodeIndices) {
      final targetAllowed = _isNodeAllowed(nodeIndex);
      final fromPose = fromPoses[nodeIndex];
      if (!targetAllowed && fromPose == null) continue;
      final node = model.gltf.nodes.elementAtOrNull(nodeIndex);
      if (node == null) continue;
      final targetPose = targetAllowed ? nodePoses[nodeIndex] : null;
      binding.nodeByGltfIndex(nodeIndex).localTransform = _trsMatrix(
        _lerpList(
          _finiteListOr(fromPose?.translation, node.restTranslation, 3),
          _finiteListOr(targetPose?.translation, node.restTranslation, 3),
          fade,
        ),
        _slerp(
          _finiteListOr(fromPose?.rotation, node.restRotation, 4),
          _finiteListOr(targetPose?.rotation, node.restRotation, 4),
          fade,
        ),
        _lerpList(
          _finiteListOr(fromPose?.scale, node.restScale, 3),
          _finiteListOr(targetPose?.scale, node.restScale, 3),
          fade,
        ),
      );
    }
  }

  void _applyMorphWeights(
    VrmSceneBinding binding,
    Map<int, List<double>> morphWeights,
    double fade, {
    Map<int, List<double>>? from,
  }) {
    final fromWeights = from ?? const <int, List<double>>{};
    final nodeIndices = {
      ...fromWeights.keys,
      ...morphWeights.keys,
      for (final layer in _additiveLayers) ...layer.frame.morphWeights.keys,
    };
    for (final nodeIndex in nodeIndices) {
      final overrideAllowed = _isNodeAllowed(nodeIndex);
      final hasSource = fromWeights.containsKey(nodeIndex);
      final additiveMorphCount = _additiveMorphCount(nodeIndex);
      if (!overrideAllowed && !hasSource && additiveMorphCount == 0) continue;
      final meshIndex = model.gltf.nodes.elementAtOrNull(nodeIndex)?.mesh;
      if (meshIndex == null) continue;
      final mesh = model.gltf.meshes.elementAtOrNull(meshIndex);
      final meshBinding = binding.meshByNodeIndex(nodeIndex);
      if (mesh == null || meshBinding == null) continue;
      final node = model.gltf.nodes.elementAtOrNull(nodeIndex);
      final baseWeights = node == null || node.weights.isEmpty
          ? mesh.weights
          : node.weights;
      for (var primitive = 0; primitive < mesh.primitives.length; primitive++) {
        final target = overrideAllowed
            ? morphWeights[nodeIndex] ?? const <double>[]
            : const <double>[];
        final source = fromWeights[nodeIndex] ?? const <double>[];
        final requestedMorphCount = math.max(
          math.max(target.length, source.length),
          additiveMorphCount,
        );
        final morphCount = math.min(
          mesh.primitives[primitive].targets.length,
          requestedMorphCount,
        );
        for (var morph = 0; morph < morphCount; morph++) {
          final base = _finiteAtOr(baseWeights, morph, 0.0);
          final from = _finiteAtOr(source, morph, base);
          final to = _finiteAtOr(target, morph, base);
          meshBinding.setMorphWeight(
            primitiveIndex: primitive,
            morphIndex: morph,
            weight:
                from +
                (to - from) * fade +
                _additiveMorphDelta(nodeIndex, morph),
          );
        }
      }
    }
  }

  void _applyModelRootPose(
    VrmSceneBinding binding,
    GltfNodePose? pose,
    double fade, {
    GltfNodePose? from,
  }) {
    final hasAdditiveRoot = _additiveLayers.any(
      (layer) => layer.frame.modelRootPose != null,
    );
    if (pose == null && from == null && !hasAdditiveRoot) return;
    final translation = List<double>.of(
      _lerpList(
        _finiteListOr(from?.translation, const [0.0, 0.0, 0.0], 3),
        _finiteListOr(pose?.translation, const [0.0, 0.0, 0.0], 3),
        fade,
      ),
    );
    var rotation = _slerp(
      _finiteListOr(from?.rotation, const [0.0, 0.0, 0.0, 1.0], 4),
      _finiteListOr(pose?.rotation, const [0.0, 0.0, 0.0, 1.0], 4),
      fade,
    );
    final scale = List<double>.of(
      _lerpList(
        _finiteListOr(from?.scale, const [1.0, 1.0, 1.0], 3),
        _finiteListOr(pose?.scale, const [1.0, 1.0, 1.0], 3),
        fade,
      ),
    );
    for (final layer in _additiveLayers) {
      final additive = layer.frame.modelRootPose;
      if (additive == null) continue;
      final additiveTranslation = additive.translation;
      final additiveRotation = additive.rotation;
      final additiveScale = additive.scale;
      final weight = layer.weight;
      if (_hasFiniteLength(additiveTranslation, 3)) {
        final values = additiveTranslation!;
        translation[0] += values[0] * weight;
        translation[1] += values[1] * weight;
        translation[2] += values[2] * weight;
      }
      if (_hasFiniteLength(additiveRotation, 4)) {
        rotation = _quatMultiply(
          rotation,
          _slerp(const [0.0, 0.0, 0.0, 1.0], additiveRotation!, weight),
        );
      }
      if (_hasFiniteLength(additiveScale, 3)) {
        final values = additiveScale!;
        scale[0] *= 1 + (values[0] - 1) * weight;
        scale[1] *= 1 + (values[1] - 1) * weight;
        scale[2] *= 1 + (values[2] - 1) * weight;
      }
    }
    final transform = _trsMatrix(translation, rotation, scale);
    if (binding case final VrmModelRootBinding rootBinding) {
      rootBinding.modelRootMotionTransform = transform;
      return;
    }
    for (final nodeIndex in _sceneRootNodeIndices()) {
      final node = binding.nodeByGltfIndex(nodeIndex);
      node.localTransform = _multiplyMatrices(transform, node.localTransform);
    }
  }

  List<int> _sceneRootNodeIndices() {
    final sceneIndex =
        model.gltf.scene ?? (model.gltf.scenes.isEmpty ? null : 0);
    if (sceneIndex == null) return const [];
    return model.gltf.scenes.elementAtOrNull(sceneIndex)?.nodes ?? const [];
  }

  void _applyAdditiveNodePoses(VrmSceneBinding binding) {
    for (final layer in _additiveLayers) {
      for (final entry in layer.frame.nodePoses.entries) {
        if (!layer.allowsNode(entry.key)) continue;
        final gltfNode = model.gltf.nodes.elementAtOrNull(entry.key);
        if (gltfNode == null) continue;
        final node = binding.nodeByGltfIndex(entry.key);
        final current = node.localTransform;
        final translation = _matrixTranslation(
          current,
          fallback: gltfNode.restTranslation,
        );
        final rotation = _matrixRotation(
          current,
          fallback: gltfNode.restRotation,
        );
        final scale = _matrixScale(current, fallback: gltfNode.restScale);
        final additive = entry.value;
        final additiveTranslation = additive.translation;
        final additiveRotation = additive.rotation;
        final additiveScale = additive.scale;
        final finiteAdditiveTranslation =
            _hasFiniteLength(additiveTranslation, 3)
            ? additiveTranslation!
            : null;
        final finiteAdditiveRotation = _hasFiniteLength(additiveRotation, 4)
            ? additiveRotation!
            : null;
        final finiteAdditiveScale = _hasFiniteLength(additiveScale, 3)
            ? additiveScale!
            : null;
        final weight = layer.weight;

        node.localTransform = _trsMatrix(
          finiteAdditiveTranslation == null
              ? translation
              : [
                  translation[0] + finiteAdditiveTranslation[0] * weight,
                  translation[1] + finiteAdditiveTranslation[1] * weight,
                  translation[2] + finiteAdditiveTranslation[2] * weight,
                ],
          finiteAdditiveRotation == null
              ? rotation
              : _quatMultiply(
                  rotation,
                  _slerp(
                    const [0.0, 0.0, 0.0, 1.0],
                    finiteAdditiveRotation,
                    weight,
                  ),
                ),
          finiteAdditiveScale == null
              ? scale
              : [
                  scale[0] * (1 + (finiteAdditiveScale[0] - 1) * weight),
                  scale[1] * (1 + (finiteAdditiveScale[1] - 1) * weight),
                  scale[2] * (1 + (finiteAdditiveScale[2] - 1) * weight),
                ],
        );
      }
    }
  }

  Map<String, double> _additiveMotionInputs(Map<String, double> base) {
    if (_additiveLayers.every(
      (layer) => layer.frame.expressionWeights.isEmpty,
    )) {
      return base;
    }
    final names = {...base.keys};
    for (final layer in _additiveLayers) {
      names.addAll(layer.frame.expressionWeights.keys);
    }
    return {
      for (final name in names) name: _clamp01(_additiveExpression(name, base)),
    };
  }

  int _additiveMorphCount(int nodeIndex) {
    var count = 0;
    for (final layer in _additiveLayers) {
      if (!layer.allowsNode(nodeIndex)) continue;
      count = math.max(count, layer.frame.morphWeights[nodeIndex]?.length ?? 0);
    }
    return count;
  }

  double _additiveMorphDelta(int nodeIndex, int morphIndex) {
    var delta = 0.0;
    for (final layer in _additiveLayers) {
      if (!layer.allowsNode(nodeIndex)) continue;
      final values = layer.frame.morphWeights[nodeIndex];
      if (values != null && morphIndex < values.length) {
        final value = values[morphIndex];
        if (value.isFinite) delta += value * layer.weight;
      }
    }
    return delta;
  }

  double _additiveExpression(String name, Map<String, double> base) {
    var value = base[name] ?? 0.0;
    for (final layer in _additiveLayers) {
      value += (layer.frame.expressionWeights[name] ?? 0.0) * layer.weight;
    }
    return value;
  }

  _YawPitch? _additiveLookAt(_YawPitch? base) {
    var hasValue = base != null;
    var yaw = base?.yawDegrees ?? 0.0;
    var pitch = base?.pitchDegrees ?? 0.0;
    for (final layer in _additiveLayers) {
      final additive = layer.frame.lookAt;
      if (additive == null) continue;
      hasValue = true;
      yaw += additive.yawDegrees * layer.weight;
      pitch += additive.pitchDegrees * layer.weight;
    }
    return hasValue ? _YawPitch(yaw, pitch) : null;
  }

  List<double> _finiteListOr(
    List<double>? value,
    List<double> fallback,
    int length,
  ) => _hasFiniteLength(value, length) ? value! : fallback;

  double _finiteAtOr(List<double> values, int index, double fallback) {
    if (index >= values.length) return fallback;
    final value = values[index];
    return value.isFinite ? value : fallback;
  }

  bool _hasFiniteLength(List<double>? value, int length) {
    if (value == null || value.length < length) return false;
    for (var i = 0; i < length; i++) {
      if (!value[i].isFinite) return false;
    }
    return true;
  }
}
