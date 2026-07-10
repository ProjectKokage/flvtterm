part of '../flvtterm.dart';

VrmSceneBinding _resolveSceneBinding(VrmModel model, VrmSceneBinding binding) =>
    binding is VrmModelRootBinding
    ? _ResolvedModelRootBinding(model, binding)
    : _ResolvedSceneBinding(model, binding);

class _ResolvedSceneBinding implements VrmSceneBinding {
  _ResolvedSceneBinding(VrmModel model, VrmSceneBinding delegate)
    : _delegate = delegate,
      _nodes = List.unmodifiable([
        for (final node in model.gltf.nodes)
          delegate.nodeByGltfIndex(node.index),
      ]),
      _meshes = List.unmodifiable([
        for (final node in model.gltf.nodes)
          node.mesh == null ? null : delegate.meshByNodeIndex(node.index),
      ]),
      _materials = _resolveMaterialBindings(model, delegate);

  final VrmSceneBinding _delegate;
  final List<VrmNodeBinding> _nodes;
  final List<VrmMeshBinding?> _meshes;
  final List<VrmMaterialBinding?> _materials;

  @override
  void beginFrame() {
    _delegate.beginFrame();
  }

  @override
  void commitFrame() {
    _delegate.commitFrame();
  }

  @override
  VrmMaterialBinding materialByGltfIndex(int materialIndex) =>
      _materials[materialIndex] ??= _delegate.materialByGltfIndex(
        materialIndex,
      );

  @override
  VrmMeshBinding? meshByNodeIndex(int nodeIndex) => _meshes[nodeIndex];

  @override
  VrmNodeBinding nodeByGltfIndex(int nodeIndex) => _nodes[nodeIndex];
}

List<VrmMaterialBinding?> _resolveMaterialBindings(
  VrmModel model,
  VrmSceneBinding binding,
) {
  final referenced = <int>{};
  for (final expression in model.vrm.expressions.all.values) {
    for (final bind in expression.materialColorBinds) {
      referenced.add(bind.material);
    }
    for (final bind in expression.textureTransformBinds) {
      referenced.add(bind.material);
    }
  }
  return [
    for (final material in model.gltf.materials)
      referenced.contains(material.index)
          ? binding.materialByGltfIndex(material.index)
          : null,
  ];
}

final class _ResolvedModelRootBinding implements VrmModelRootBinding {
  _ResolvedModelRootBinding(VrmModel model, this._rootDelegate)
    : _resolved = _ResolvedSceneBinding(model, _rootDelegate);

  final VrmModelRootBinding _rootDelegate;
  final _ResolvedSceneBinding _resolved;

  @override
  void beginFrame() {
    _resolved.beginFrame();
  }

  @override
  void commitFrame() {
    _resolved.commitFrame();
  }

  @override
  VrmMaterialBinding materialByGltfIndex(int materialIndex) =>
      _resolved.materialByGltfIndex(materialIndex);

  @override
  VrmMeshBinding? meshByNodeIndex(int nodeIndex) =>
      _resolved.meshByNodeIndex(nodeIndex);

  @override
  VrmNodeBinding nodeByGltfIndex(int nodeIndex) =>
      _resolved.nodeByGltfIndex(nodeIndex);

  @override
  VrmMatrix4 get modelRootMotionTransform =>
      _rootDelegate.modelRootMotionTransform;

  @override
  set modelRootMotionTransform(VrmMatrix4 value) {
    _rootDelegate.modelRootMotionTransform = value;
  }
}
