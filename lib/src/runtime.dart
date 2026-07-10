part of '../flvtterm.dart';

/// Runtime object that can apply renderer-neutral VRM state to a scene binding.
final class VrmRuntime {
  /// Creates a runtime for [model].
  VrmRuntime(VrmModel model) : this._(model, VrmExpressionController(model));

  VrmRuntime._(this.model, this.expressions)
    : motion = VrmMotionController(model),
      lookAt = VrmLookAtController(model),
      constraints = VrmNodeConstraintController(model),
      springBones = VrmSpringBoneController(model),
      firstPerson = VrmFirstPersonController(model),
      emotion = VrmEmotionController(expressions),
      lipSync = VrmLipSyncController(expressions),
      blink = VrmBlinkController(expressions);

  /// Parsed model backing this runtime.
  final VrmModel model;

  /// Motion playback controller.
  final VrmMotionController motion;

  /// LookAt controller.
  final VrmLookAtController lookAt;

  /// Node constraint controller.
  final VrmNodeConstraintController constraints;

  /// SpringBone procedural animation controller.
  final VrmSpringBoneController springBones;

  /// First-person mesh visibility controller.
  final VrmFirstPersonController firstPerson;

  /// Expression controller.
  final VrmExpressionController expressions;

  /// Emotion expression convenience controller.
  final VrmEmotionController emotion;

  /// Lip-sync expression convenience controller.
  final VrmLipSyncController lipSync;

  /// Blink expression convenience controller.
  final VrmBlinkController blink;

  VrmSceneBinding? _binding;

  /// Binds this runtime to a renderer scene.
  void bind(VrmSceneBinding binding) {
    _binding = binding;
    springBones.reset();
  }

  /// Detaches any renderer scene binding.
  void unbind() {
    _binding = null;
  }

  /// Resets SpringBone simulation state, for example after teleporting.
  void resetSpringBones() {
    springBones.reset();
  }

  /// Applies one runtime frame.
  void update(double deltaSeconds) {
    final binding = _binding;
    if (binding == null) return;

    binding.beginFrame();
    try {
      _resetPose(binding);
      motion.update(deltaSeconds);
      motion.applyTo(binding, expressions, lookAt);
      lookAt.applyTo(binding, expressions);
      expressions.applyTo(binding);
      constraints.applyTo(binding);
      springBones.applyTo(binding, deltaSeconds);
      firstPerson.applyTo(binding);
    } finally {
      binding.commitFrame();
    }
  }

  void _resetPose(VrmSceneBinding binding) {
    if (binding case final VrmModelRootBinding rootBinding) {
      rootBinding.modelRootMotionTransform = VrmMatrix4.identity();
    }
    for (final node in model.gltf.nodes) {
      binding.nodeByGltfIndex(node.index).localTransform = node.restTransform;
      final meshIndex = node.mesh;
      if (meshIndex == null) continue;
      final mesh = model.gltf.meshes.elementAtOrNull(meshIndex);
      final meshBinding = binding.meshByNodeIndex(node.index);
      if (mesh == null || meshBinding == null) continue;
      meshBinding.setVisible(true);
      final baseWeights = node.weights.isNotEmpty ? node.weights : mesh.weights;
      for (var primitive = 0; primitive < mesh.primitives.length; primitive++) {
        final targets = mesh.primitives[primitive].targets;
        for (var morph = 0; morph < targets.length; morph++) {
          meshBinding.setMorphWeight(
            primitiveIndex: primitive,
            morphIndex: morph,
            weight: morph < baseWeights.length ? baseWeights[morph] : 0,
          );
        }
      }
    }
    _resetExpressionMaterials(binding);
  }

  void _resetExpressionMaterials(VrmSceneBinding binding) {
    for (final expression in model.vrm.expressions.all.values) {
      for (final bind in expression.materialColorBinds) {
        final material = model.gltf.materials.elementAtOrNull(bind.material);
        if (material == null) continue;
        binding
            .materialByGltfIndex(bind.material)
            .setColor(bind.type, _baseMaterialColor(material, bind.type));
      }
      for (final bind in expression.textureTransformBinds) {
        final material = model.gltf.materials.elementAtOrNull(bind.material);
        if (material == null) continue;
        final transform = _baseTextureTransform(material);
        binding
            .materialByGltfIndex(bind.material)
            .setTextureTransform(
              scale: transform.scale,
              offset: transform.offset,
            );
      }
    }
  }
}

/// Applies first-person mesh visibility policy to a scene binding.
final class VrmFirstPersonController {
  /// Creates a first-person controller for [model].
  VrmFirstPersonController(this.model);

  /// Parsed model backing this controller.
  final VrmModel model;

  /// Active visibility perspective.
  VrmFirstPersonView view = VrmFirstPersonView.thirdPerson;

  /// Switches visibility to first-person camera policy.
  void useFirstPerson() {
    view = VrmFirstPersonView.firstPerson;
  }

  /// Switches visibility to third-person camera policy.
  void useThirdPerson() {
    view = VrmFirstPersonView.thirdPerson;
  }

  /// Returns whether the mesh node should be visible for the current [view].
  bool isVisible(int nodeIndex) {
    final type = model.conservativeFirstPersonTypeForNode(nodeIndex);
    return switch (type) {
      VrmFirstPersonMeshAnnotationType.thirdPersonOnly =>
        view == VrmFirstPersonView.thirdPerson,
      VrmFirstPersonMeshAnnotationType.firstPersonOnly =>
        view == VrmFirstPersonView.firstPerson,
      VrmFirstPersonMeshAnnotationType.both => true,
      VrmFirstPersonMeshAnnotationType.auto => true,
    };
  }

  /// Warnings for `auto` mesh nodes that need splitting or cannot be classified.
  List<VrmDiagnostic> geometrySplitWarnings() {
    final warnings = <VrmDiagnostic>[];
    for (final node in model.gltf.nodes) {
      if (node.mesh == null) continue;
      if (model.firstPersonNeedsGeometrySplit(node.index)) {
        warnings.add(
          VrmDiagnostic(
            severity: const VrmWarning(),
            code: 'vrm.firstPersonGeometrySplitRequired',
            message:
                'First-person auto visibility for node ${node.index} needs ${model.firstPersonNeedsPrimitiveSplit(node.index) ? 'primitive' : 'triangle'} splitting; whole-mesh visibility is conservative.',
            jsonPath: '\$.nodes[${node.index}]',
            gltfNodeIndex: node.index,
          ),
        );
        continue;
      }
      if (model.conservativeFirstPersonTypeForNode(node.index) ==
          VrmFirstPersonMeshAnnotationType.auto) {
        warnings.add(
          VrmDiagnostic(
            severity: const VrmWarning(),
            code: 'vrm.firstPersonAutoClassificationUnavailable',
            message:
                'First-person auto visibility for node ${node.index} could not be classified from skin weights; whole-mesh visibility remains conservative.',
            jsonPath: '\$.nodes[${node.index}]',
            gltfNodeIndex: node.index,
          ),
        );
      }
    }
    return warnings;
  }

  /// Applies mesh visibility for all glTF nodes that have meshes.
  void applyTo(VrmSceneBinding binding) {
    for (final node in model.gltf.nodes) {
      if (node.mesh == null) continue;
      binding.meshByNodeIndex(node.index)?.setVisible(isVisible(node.index));
    }
  }
}

/// Convenience API for emotion preset expressions.
final class VrmEmotionController {
  /// Creates an emotion controller over [expressions].
  VrmEmotionController(this.expressions);

  /// Backing expression controller.
  final VrmExpressionController expressions;

  /// Sets an emotion weight in `[0, 1]`.
  void set(VrmEmotion emotion, double weight) {
    expressions.setPreset(emotion.preset, weight);
  }
}

/// Convenience API for lip-sync viseme expressions.
final class VrmLipSyncController {
  /// Creates a lip-sync controller over [expressions].
  VrmLipSyncController(this.expressions);

  /// Backing expression controller.
  final VrmExpressionController expressions;

  /// Sets a viseme weight in `[0, 1]`.
  void setViseme(VrmViseme viseme, double weight) {
    expressions.setLipSync(viseme, weight);
  }
}

/// Convenience API for blink expressions.
final class VrmBlinkController {
  /// Creates a blink controller over [expressions].
  VrmBlinkController(this.expressions);

  /// Backing expression controller.
  final VrmExpressionController expressions;

  /// Sets both-eye blink weight in `[0, 1]`.
  void setBoth(double weight) {
    expressions.setPreset(VrmExpressionPreset.blink, weight);
  }

  /// Sets left-eye blink weight in `[0, 1]`.
  void setLeft(double weight) {
    expressions.setPreset(VrmExpressionPreset.blinkLeft, weight);
  }

  /// Sets right-eye blink weight in `[0, 1]`.
  void setRight(double weight) {
    expressions.setPreset(VrmExpressionPreset.blinkRight, weight);
  }
}
