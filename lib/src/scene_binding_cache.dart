part of '../flvtterm.dart';

VrmSceneBinding _resolveSceneBinding(VrmModel model, VrmSceneBinding binding) =>
    binding is VrmModelRootBinding
    ? _ResolvedModelRootBinding(model, binding)
    : _ResolvedFallbackModelRootBinding(model, binding);

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

final class _ResolvedModelRootBinding
    implements VrmModelRootBinding, VrmModelWorldBinding {
  _ResolvedModelRootBinding(VrmModel model, this._rootDelegate)
    : _resolved = _ResolvedSceneBinding(model, _rootDelegate),
      _sourceToRuntimeTransform = model.sourceToRuntimeTransform;

  final VrmModelRootBinding _rootDelegate;
  final _ResolvedSceneBinding _resolved;
  final VrmMatrix4 _sourceToRuntimeTransform;

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
  VrmMatrix4 get modelWorldTransform => _rootDelegate is VrmModelWorldBinding
      ? (_rootDelegate as VrmModelWorldBinding).modelWorldTransform
      : modelRootMotionTransform;

  @override
  set modelRootMotionTransform(VrmMatrix4 value) {
    _rootDelegate.modelRootMotionTransform = _multiplyMatrices(
      value,
      _sourceToRuntimeTransform,
    );
  }
}

final class _ResolvedFallbackModelRootBinding
    implements VrmModelRootBinding, VrmModelWorldBinding {
  _ResolvedFallbackModelRootBinding(VrmModel model, VrmSceneBinding delegate)
    : _resolved = _ResolvedSceneBinding(model, delegate),
      _worldDelegate = delegate is VrmModelWorldBinding ? delegate : null,
      _sourceToRuntimeTransform = model.sourceToRuntimeTransform,
      _sceneRoots = List.unmodifiable(_activeSceneRootNodeIndices(model.gltf)) {
    final roots = _sceneRoots.toSet();
    final parents = _nodeParents(model.gltf);
    _nodes = List.unmodifiable([
      for (final node in model.gltf.nodes)
        _RootTransformNodeBinding(
          _resolved.nodeByGltfIndex(node.index),
          () => _modelRootMotionTransform,
          _sceneBindingPath(_resolved, node.index, roots, parents),
        ),
    ]);
  }

  final _ResolvedSceneBinding _resolved;
  final VrmModelWorldBinding? _worldDelegate;
  final VrmMatrix4 _sourceToRuntimeTransform;
  final List<int> _sceneRoots;
  late final List<VrmNodeBinding> _nodes;
  var _modelRootMotionTransform = VrmMatrix4.identity();

  @override
  void beginFrame() {
    _resolved.beginFrame();
  }

  @override
  void commitFrame() {
    if (!_isIdentityMatrix(_modelRootMotionTransform)) {
      for (final nodeIndex in _sceneRoots) {
        final node = _resolved.nodeByGltfIndex(nodeIndex);
        node.localTransform = _multiplyMatrices(
          _modelRootMotionTransform,
          node.localTransform,
        );
      }
    }
    _resolved.commitFrame();
  }

  @override
  VrmMaterialBinding materialByGltfIndex(int materialIndex) =>
      _resolved.materialByGltfIndex(materialIndex);

  @override
  VrmMeshBinding? meshByNodeIndex(int nodeIndex) =>
      _resolved.meshByNodeIndex(nodeIndex);

  @override
  VrmNodeBinding nodeByGltfIndex(int nodeIndex) => _nodes[nodeIndex];

  @override
  VrmMatrix4 get modelRootMotionTransform => _modelRootMotionTransform;

  @override
  VrmMatrix4 get modelWorldTransform {
    final world = _worldDelegate?.modelWorldTransform;
    return world == null
        ? _modelRootMotionTransform
        : _multiplyMatrices(world, _modelRootMotionTransform);
  }

  @override
  set modelRootMotionTransform(VrmMatrix4 value) {
    _modelRootMotionTransform = _multiplyMatrices(
      value,
      _sourceToRuntimeTransform,
    );
  }
}

final class _RootTransformNodeBinding implements VrmNodeBinding {
  const _RootTransformNodeBinding(
    this._delegate,
    this._rootTransform,
    this._scenePath,
  );

  final VrmNodeBinding _delegate;
  final VrmMatrix4 Function() _rootTransform;
  final List<VrmNodeBinding>? _scenePath;

  @override
  String? get debugName => _delegate.debugName;

  @override
  VrmMatrix4 get localTransform => _delegate.localTransform;

  @override
  set localTransform(VrmMatrix4 value) {
    _delegate.localTransform = value;
  }

  @override
  VrmMatrix4 get worldTransform {
    final scenePath = _scenePath;
    if (scenePath == null || scenePath.isEmpty) {
      return _multiplyMatrices(_rootTransform(), _delegate.worldTransform);
    }
    final sceneRoot = scenePath.first;
    final inverseRootLocal = _tryInvertAffineMatrix(sceneRoot.localTransform);
    if (inverseRootLocal == null) {
      return _multiplyMatrices(_rootTransform(), _delegate.worldTransform);
    }
    final externalWorld = _multiplyMatrices(
      sceneRoot.worldTransform,
      inverseRootLocal,
    );
    var modelPath = VrmMatrix4.identity();
    for (final binding in scenePath) {
      modelPath = _multiplyMatrices(modelPath, binding.localTransform);
    }
    return _multiplyMatrices(
      _multiplyMatrices(externalWorld, _rootTransform()),
      modelPath,
    );
  }
}

List<VrmNodeBinding>? _sceneBindingPath(
  _ResolvedSceneBinding binding,
  int nodeIndex,
  Set<int> sceneRoots,
  Map<int, int> parents,
) {
  if (sceneRoots.isEmpty) return null;
  final indices = <int>[];
  final seen = <int>{};
  var current = nodeIndex;
  while (seen.add(current)) {
    indices.add(current);
    if (sceneRoots.contains(current)) {
      return List.unmodifiable([
        for (final index in indices.reversed) binding.nodeByGltfIndex(index),
      ]);
    }
    final parent = parents[current];
    if (parent == null) return null;
    current = parent;
  }
  return null;
}
