part of '../flvtterm.dart';

/// Renderer-neutral scene binding for applying VRM runtime state.
abstract interface class VrmSceneBinding {
  /// Returns a node binding for the glTF node index.
  VrmNodeBinding nodeByGltfIndex(int nodeIndex);

  /// Returns a mesh binding for the glTF node index, if one exists.
  VrmMeshBinding? meshByNodeIndex(int nodeIndex);

  /// Returns a material binding for the glTF material index.
  VrmMaterialBinding materialByGltfIndex(int materialIndex);

  /// Called before a runtime frame is applied.
  void beginFrame();

  /// Called after a runtime frame is applied.
  void commitFrame();
}

/// Optional binding for avatar root motion outside the glTF node hierarchy.
///
/// Implement this when a renderer has a parent/root object for the loaded
/// avatar. The runtime writes model-space root motion here instead of baking
/// locomotion into the humanoid hips bone.
abstract interface class VrmModelRootBinding implements VrmSceneBinding {
  /// Runtime-owned root motion transform, composed below app/world placement.
  VrmMatrix4 get modelRootMotionTransform;

  /// Sets the runtime-owned root motion transform.
  set modelRootMotionTransform(VrmMatrix4 value);
}

/// Optional binding that exposes the avatar's complete model-to-world transform.
///
/// The transform maps source glTF model space through any compatibility basis,
/// runtime-owned root motion, and application/world placement. Implement this
/// when world-space procedural systems such as SpringBone must remain correct
/// under an outer rotated or scaled parent.
abstract interface class VrmModelWorldBinding implements VrmSceneBinding {
  /// Current transform from source glTF model space to renderer world space.
  VrmMatrix4 get modelWorldTransform;
}

/// Renderer-neutral node binding.
abstract interface class VrmNodeBinding {
  /// Local transform in model space.
  VrmMatrix4 get localTransform;

  /// Sets the local transform in model space.
  set localTransform(VrmMatrix4 value);

  /// World transform in renderer space.
  VrmMatrix4 get worldTransform;

  /// Optional name for diagnostics and debugging.
  String? get debugName;
}

/// Renderer-neutral mesh binding.
abstract interface class VrmMeshBinding {
  /// Sets a morph target weight on one primitive.
  void setMorphWeight({
    required int primitiveIndex,
    required int morphIndex,
    required double weight,
  });

  /// Sets mesh visibility for renderer-neutral first-person policy.
  void setVisible(bool visible);
}

/// Renderer-neutral material binding.
abstract interface class VrmMaterialBinding {
  /// Sets a color-like material parameter.
  void setColor(String parameter, VrmVector4 value);

  /// Sets a texture transform for UV-accessed material textures.
  void setTextureTransform({
    required VrmVector2 scale,
    required VrmVector2 offset,
  });
}
