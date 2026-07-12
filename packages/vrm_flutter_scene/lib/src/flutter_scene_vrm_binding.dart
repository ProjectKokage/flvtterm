import 'package:flutter_scene/scene.dart' as scene;
import 'package:flvtterm/flvtterm.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'flutter_scene_morph_target_primitive.dart';
import 'morph_target_blender.dart';

/// Controls how [FlutterSceneVrmBinding] maps glTF node indices to
/// Flutter Scene nodes.
final class FlutterSceneVrmBindingOptions {
  /// Creates binding options.
  FlutterSceneVrmBindingOptions({
    Map<int, List<int>> nodeIndexPaths = const {},
    this.includeRootAsGltfNode,
  }) : nodeIndexPaths = Map.unmodifiable({
         for (final entry in nodeIndexPaths.entries)
           entry.key: List<int>.unmodifiable(entry.value),
       });

  /// Explicit child index paths from [FlutterSceneVrmBinding.root] to glTF
  /// node indices.
  ///
  /// Prefer this when an importer can expose stable node index paths. Any
  /// omitted node falls back to the parsed glTF scene hierarchy.
  final Map<int, List<int>> nodeIndexPaths;

  /// Whether fallback traversal should treat the supplied root as glTF node 0.
  ///
  /// When null, the binding excludes the supplied root if its descendants are
  /// enough to cover all glTF nodes, which matches `Node.fromGlbBytes` wrapper
  /// roots. Otherwise it includes the root.
  final bool? includeRootAsGltfNode;
}

/// Renderer binding from flvtterm's core runtime to Flutter Scene.
///
/// The binding keeps Flutter Scene types in this optional package. Node
/// transforms, mesh-component visibility, and supported morph target weights
/// are applied directly. Texture transforms still emit capability warnings
/// because Flutter Scene does not document a public mutator for imported
/// texture transforms.
final class FlutterSceneVrmBinding
    implements VrmModelRootBinding, VrmModelWorldBinding {
  /// Creates a binding for a Flutter Scene GLB root.
  FlutterSceneVrmBinding.fromRootNode(
    this.root, {
    required this.model,
    FlutterSceneVrmBindingOptions? options,
  }) {
    options ??= FlutterSceneVrmBindingOptions();
    _capabilityWarnings.addAll(
      VrmFirstPersonController(model).geometrySplitWarnings(),
    );
    for (final material in model.gltf.materials) {
      final warning =
          model.vrm0MtoonFallbackWarning(material.index) ??
          material.mtoonFallbackWarning();
      if (warning != null) _capabilityWarnings.add(warning);
    }
    for (final entry in options.nodeIndexPaths.entries) {
      if (entry.key < 0 || entry.key >= model.gltf.nodes.length) {
        _warnOnce(
          code: 'flutterScene.invalidNodeIndexPath',
          message:
              'Flutter Scene node index path targets a glTF node outside the parsed model.',
          gltfNodeIndex: entry.key,
        );
      } else if (root.getChildByIndexPath(entry.value) == null) {
        _warnOnce(
          code: 'flutterScene.invalidNodeIndexPath',
          message:
              'Flutter Scene node index path could not be resolved from the supplied root node.',
          gltfNodeIndex: entry.key,
        );
      }
    }
    final sceneNodes = _sceneNodesByGltfIndex(root, model, options);
    final claimedSceneNodes = <scene.Node>{};
    sceneNodes.removeWhere((nodeIndex, sceneNode) {
      if (claimedSceneNodes.add(sceneNode)) return false;
      _warnOnce(
        code: 'flutterScene.duplicateNodeBinding',
        message:
            'Flutter Scene node index paths mapped more than one glTF node index to the same scene node.',
        gltfNodeIndex: nodeIndex,
      );
      return true;
    });
    for (final entry in sceneNodes.entries) {
      if (identical(entry.value, root)) {
        _rootGltfNodeIndex = entry.key;
        break;
      }
    }
    final rootGltfNodeIndex = _rootGltfNodeIndex;
    if (rootGltfNodeIndex == null) {
      _importRootLocalTransform = root.localTransform.clone();
    } else {
      _rootNodeLocalTransform =
          model.gltf.nodes[rootGltfNodeIndex].restTransform;
      final inverseRest = vm.Matrix4.tryInvert(
        _toSceneMatrix(_rootNodeLocalTransform!),
      );
      if (inverseRest == null) {
        _importRootLocalTransform = vm.Matrix4.identity();
        _warnOnce(
          code: 'flutterScene.nonInvertibleGltfRoot',
          message:
              'The glTF scene-root transform is not invertible; its importer transform could not be separated from model-root motion.',
          gltfNodeIndex: rootGltfNodeIndex,
        );
      } else {
        _importRootLocalTransform = root.localTransform.clone()
          ..multiply(inverseRest);
      }
    }
    final coreFromSceneTransform = vm.Matrix4.tryInvert(
      _importRootLocalTransform,
    );
    _coreFromSceneTransform = coreFromSceneTransform ?? vm.Matrix4.identity();
    if (coreFromSceneTransform == null) {
      _warnOnce(
        code: 'flutterScene.nonInvertibleImportRoot',
        message:
            'Flutter Scene import root transform is not invertible; core world transforms cannot be converted from renderer coordinates.',
      );
    }
    for (final node in model.gltf.nodes) {
      if (sceneNodes.containsKey(node.index)) continue;
      _warnOnce(
        code: 'flutterScene.missingNodeBinding',
        message:
            'Flutter Scene node traversal did not produce a node for this glTF node index.',
        gltfNodeIndex: node.index,
      );
    }
    _nodeBindings = {
      for (final entry in sceneNodes.entries)
        entry.key: entry.key == rootGltfNodeIndex
            ? _FlutterSceneRootNodeBinding(this, entry.value)
            : _FlutterSceneNodeBinding(entry.value, _coreFromSceneTransform),
    };
    final morphTargetDataFactory = MorphTargetDataFactory(model.gltf);
    _meshBindings = {
      for (final entry in sceneNodes.entries)
        if (entry.value.mesh != null)
          entry.key: _FlutterSceneMeshBinding(
            this,
            entry.key,
            entry.value,
            morphTargetDataFactory,
          ),
    };
    _materialBindings = {
      for (final entry in _sceneMaterials(sceneNodes, model).entries)
        entry.key: _FlutterSceneMaterialBinding(this, entry.key, entry.value),
    };
    for (final entry in _materialBindings.entries) {
      if (entry.key < 0 || entry.key >= model.gltf.materials.length) continue;
      final material = model.gltf.materials[entry.key];
      if (material.mtoon == null &&
          model.vrm0MtoonFallbackWarning(entry.key) == null) {
        continue;
      }
      entry.value.applyFallback(material);
    }
  }

  /// Flutter Scene root for the loaded avatar.
  final scene.Node root;

  /// Parsed VRM model for the same GLB bytes.
  final VrmModel model;

  late final Map<int, VrmNodeBinding> _nodeBindings;
  late final Map<int, _FlutterSceneMeshBinding> _meshBindings;
  late final Map<int, _FlutterSceneMaterialBinding> _materialBindings;
  final List<VrmDiagnostic> _capabilityWarnings = [];
  final Set<String> _warningCodes = {};
  late final vm.Matrix4 _importRootLocalTransform;
  late final vm.Matrix4 _coreFromSceneTransform;
  int? _rootGltfNodeIndex;
  VrmMatrix4? _rootNodeLocalTransform;
  var _modelRootMotionTransform = VrmMatrix4.identity();

  /// Warnings for renderer features this adapter cannot currently mutate.
  List<VrmDiagnostic> get capabilityWarnings =>
      List.unmodifiable(_capabilityWarnings);

  /// Whether every morph-bearing mesh in this binding has visible, reusable
  /// Flutter Scene morph geometry.
  bool get supportsVisibleMorphTargets {
    final declared = model.gltf.nodes.where((node) {
      final meshIndex = node.mesh;
      if (meshIndex == null || meshIndex >= model.gltf.meshes.length) {
        return false;
      }
      return model.gltf.meshes[meshIndex].primitives.any(
        (primitive) => primitive.targets.isNotEmpty,
      );
    });
    return declared.isNotEmpty &&
        declared.every(
          (node) =>
              _meshBindings[node.index]?.supportsAllDeclaredMorphTargets ??
              false,
        );
  }

  @override
  VrmMatrix4 get modelRootMotionTransform => _modelRootMotionTransform;

  @override
  VrmMatrix4 get modelWorldTransform {
    for (final rootIndex in _defaultSceneRootNodeIndices(model)) {
      final binding = _nodeBindings[rootIndex];
      if (binding == null) continue;
      final inverseLocal = vm.Matrix4.tryInvert(
        _toSceneMatrix(binding.localTransform),
      );
      if (inverseLocal == null) continue;
      return _fromSceneMatrix(
        _toSceneMatrix(binding.worldTransform)..multiply(inverseLocal),
      );
    }
    return _modelRootMotionTransform;
  }

  @override
  set modelRootMotionTransform(VrmMatrix4 value) {
    _modelRootMotionTransform = value;
    _applyRootTransform();
  }

  void _applyRootTransform() {
    final transform = _importRootLocalTransform.clone()
      ..multiply(_toSceneMatrix(_modelRootMotionTransform));
    final rootNodeLocal = _rootNodeLocalTransform;
    if (rootNodeLocal != null) {
      transform.multiply(_toSceneMatrix(rootNodeLocal));
    }
    root.localTransform = transform;
  }

  @override
  VrmNodeBinding nodeByGltfIndex(int nodeIndex) {
    final binding = _nodeBindings[nodeIndex];
    if (binding == null) {
      throw RangeError.index(nodeIndex, model.gltf.nodes, 'nodeIndex');
    }
    return binding;
  }

  @override
  VrmMeshBinding? meshByNodeIndex(int nodeIndex) => _meshBindings[nodeIndex];

  @override
  VrmMaterialBinding materialByGltfIndex(int materialIndex) =>
      _materialBindings.putIfAbsent(
        materialIndex,
        () => _FlutterSceneMaterialBinding(this, materialIndex, null),
      );

  @override
  void beginFrame() {}

  @override
  void commitFrame() {
    for (final mesh in _meshBindings.values) {
      mesh.commitMorphTargets();
      mesh.commitVisibility();
    }
  }

  void _warnOnce({
    required String code,
    required String message,
    int? gltfNodeIndex,
    int? gltfMaterialIndex,
  }) {
    final key = '$code:$gltfNodeIndex:$gltfMaterialIndex';
    if (!_warningCodes.add(key)) return;
    _capabilityWarnings.add(
      VrmDiagnostic(
        severity: const VrmWarning(),
        code: code,
        message: message,
        gltfNodeIndex: gltfNodeIndex,
        gltfMaterialIndex: gltfMaterialIndex,
      ),
    );
  }
}

Map<int, scene.Node> _sceneNodesByGltfIndex(
  scene.Node root,
  VrmModel model,
  FlutterSceneVrmBindingOptions options,
) {
  final nodes = <int, scene.Node>{};
  for (final entry in options.nodeIndexPaths.entries) {
    if (entry.key < 0 || entry.key >= model.gltf.nodes.length) continue;
    final node = root.getChildByIndexPath(entry.value);
    if (node != null) nodes[entry.key] = node;
  }

  final fallback = _fallbackNodesByGltfIndex(root, model, options);
  for (final entry in fallback.entries) {
    nodes.putIfAbsent(entry.key, () => entry.value);
  }

  return nodes;
}

Map<int, scene.Node> _fallbackNodesByGltfIndex(
  scene.Node root,
  VrmModel model,
  FlutterSceneVrmBindingOptions options,
) {
  final mapped = <int, scene.Node>{};
  if (model.gltf.nodes.isEmpty) return mapped;

  final descendants = <scene.Node>[];
  for (final child in root.children) {
    _collectDepthFirst(child, descendants);
  }
  final sceneRoots = _defaultSceneRootNodeIndices(model);
  final reachableNodeCount = _reachableNodeCount(model, sceneRoots);
  final includeRoot =
      options.includeRootAsGltfNode ?? descendants.length < reachableNodeCount;
  final visited = <int>{};
  if (includeRoot || sceneRoots.isEmpty) {
    _mapNodeHierarchy(
      gltfNodeIndex: 0,
      sceneNode: root,
      model: model,
      output: mapped,
      visited: visited,
    );
    return mapped;
  }

  final rootCount = sceneRoots.length < root.children.length
      ? sceneRoots.length
      : root.children.length;
  for (var i = 0; i < rootCount; i++) {
    _mapNodeHierarchy(
      gltfNodeIndex: sceneRoots[i],
      sceneNode: root.children[i],
      model: model,
      output: mapped,
      visited: visited,
    );
  }
  return mapped;
}

void _collectDepthFirst(scene.Node node, List<scene.Node> output) {
  output.add(node);
  for (final child in node.children) {
    _collectDepthFirst(child, output);
  }
}

List<int> _defaultSceneRootNodeIndices(VrmModel model) {
  if (model.gltf.scenes.isEmpty) return const [];
  final sceneIndex = model.gltf.scene ?? 0;
  if (sceneIndex < 0 || sceneIndex >= model.gltf.scenes.length) {
    return const [];
  }
  return model.gltf.scenes[sceneIndex].nodes;
}

int _reachableNodeCount(VrmModel model, List<int> roots) {
  final visited = <int>{};

  void visit(int nodeIndex) {
    if (nodeIndex < 0 || nodeIndex >= model.gltf.nodes.length) return;
    if (!visited.add(nodeIndex)) return;
    for (final childIndex in model.gltf.nodes[nodeIndex].children) {
      visit(childIndex);
    }
  }

  for (final rootIndex in roots) {
    visit(rootIndex);
  }
  return visited.length;
}

void _mapNodeHierarchy({
  required int gltfNodeIndex,
  required scene.Node sceneNode,
  required VrmModel model,
  required Map<int, scene.Node> output,
  required Set<int> visited,
}) {
  if (gltfNodeIndex < 0 || gltfNodeIndex >= model.gltf.nodes.length) return;
  if (!visited.add(gltfNodeIndex)) return;
  output[gltfNodeIndex] = sceneNode;

  final gltfChildren = model.gltf.nodes[gltfNodeIndex].children;
  final childCount = gltfChildren.length < sceneNode.children.length
      ? gltfChildren.length
      : sceneNode.children.length;
  for (var i = 0; i < childCount; i++) {
    _mapNodeHierarchy(
      gltfNodeIndex: gltfChildren[i],
      sceneNode: sceneNode.children[i],
      model: model,
      output: output,
      visited: visited,
    );
  }
}

Map<int, scene.Material> _sceneMaterials(
  Map<int, scene.Node> nodes,
  VrmModel model,
) {
  final materials = <int, scene.Material>{};
  for (final entry in nodes.entries) {
    final nodeIndex = entry.key;
    if (nodeIndex < 0 || nodeIndex >= model.gltf.nodes.length) continue;
    final gltfNode = model.gltf.nodes[nodeIndex];
    final meshIndex = gltfNode.mesh;
    if (meshIndex == null || meshIndex >= model.gltf.meshes.length) continue;
    final scenePrimitives = entry.value.mesh?.primitives;
    if (scenePrimitives == null) continue;
    final gltfPrimitives = _materialAlignedGltfPrimitives(
      model.gltf.meshes[meshIndex].primitives,
      scenePrimitives.length,
    );
    for (
      var i = 0;
      i < gltfPrimitives.length && i < scenePrimitives.length;
      i++
    ) {
      final materialIndex = gltfPrimitives[i].material;
      if (materialIndex == null) continue;
      materials.putIfAbsent(materialIndex, () => scenePrimitives[i].material);
    }
  }
  return materials;
}

List<GltfMeshPrimitive> _materialAlignedGltfPrimitives(
  List<GltfMeshPrimitive> primitives,
  int scenePrimitiveCount,
) {
  if (primitives.length == scenePrimitiveCount) return primitives;
  // Flutter Scene 0.16 omits non-TRIANGLES primitives during GLB import.
  final triangles = [
    for (final primitive in primitives)
      if (primitive.mode == 4) primitive,
  ];
  return triangles.length == scenePrimitiveCount ? triangles : primitives;
}

final class _FlutterSceneNodeBinding implements VrmNodeBinding {
  _FlutterSceneNodeBinding(this._node, this._coreFromSceneTransform);

  final scene.Node _node;
  final vm.Matrix4 _coreFromSceneTransform;

  @override
  VrmMatrix4 get localTransform => _fromSceneMatrix(_node.localTransform);

  @override
  set localTransform(VrmMatrix4 value) {
    _node.localTransform = _toSceneMatrix(value);
  }

  @override
  VrmMatrix4 get worldTransform => _fromSceneMatrix(
    _coreFromSceneTransform.clone()..multiply(_node.globalTransform),
  );

  @override
  String? get debugName => _node.name.isEmpty ? null : _node.name;
}

final class _FlutterSceneRootNodeBinding implements VrmNodeBinding {
  const _FlutterSceneRootNodeBinding(this._owner, this._node);

  final FlutterSceneVrmBinding _owner;
  final scene.Node _node;

  @override
  VrmMatrix4 get localTransform => _owner._rootNodeLocalTransform!;

  @override
  set localTransform(VrmMatrix4 value) {
    _owner._rootNodeLocalTransform = value;
    _owner._applyRootTransform();
  }

  @override
  VrmMatrix4 get worldTransform => _fromSceneMatrix(
    _owner._coreFromSceneTransform.clone()..multiply(_node.globalTransform),
  );

  @override
  String? get debugName => _node.name.isEmpty ? null : _node.name;
}

final class _FlutterSceneMeshBinding implements VrmMeshBinding {
  _FlutterSceneMeshBinding(
    this._owner,
    this._nodeIndex,
    this._node,
    MorphTargetDataFactory morphTargetDataFactory,
  ) : _meshComponents = List.unmodifiable(
        _node.getComponents<scene.MeshComponent>(),
      ) {
    _installMorphTargets(morphTargetDataFactory);
  }

  final FlutterSceneVrmBinding _owner;
  final int _nodeIndex;
  final scene.Node _node;
  final List<scene.MeshComponent> _meshComponents;
  final Map<int, FlutterSceneMorphTargetPrimitive> _morphPrimitives = {};
  final Map<int, String> _morphFailures = {};
  var _requestedVisible = true;
  var _visible = true;

  bool get declaresMorphTargets {
    final meshIndex = _owner.model.gltf.nodes[_nodeIndex].mesh;
    if (meshIndex == null || meshIndex >= _owner.model.gltf.meshes.length) {
      return false;
    }
    return _owner.model.gltf.meshes[meshIndex].primitives.any(
      (primitive) => primitive.targets.isNotEmpty,
    );
  }

  bool get supportsAllDeclaredMorphTargets =>
      declaresMorphTargets && _morphFailures.isEmpty;

  @override
  void setMorphWeight({
    required int primitiveIndex,
    required int morphIndex,
    required double weight,
  }) {
    final primitive = _morphPrimitives[primitiveIndex];
    if (primitive == null) {
      _owner._warnOnce(
        code: 'flutterScene.unsupportedMorphTarget',
        message:
            _morphFailures[primitiveIndex] ??
            'The imported Flutter Scene primitive has no reusable morph '
                'geometry.',
        gltfNodeIndex: _nodeIndex,
      );
      return;
    }
    if (!primitive.setWeight(morphIndex, weight)) {
      _owner._warnOnce(
        code: 'flutterScene.invalidMorphTargetWrite',
        message:
            'A morph target write used an out-of-range index or non-finite '
            'weight and was ignored.',
        gltfNodeIndex: _nodeIndex,
      );
    }
  }

  @override
  void setVisible(bool visible) {
    _requestedVisible = visible;
  }

  void commitVisibility() {
    if (_requestedVisible == _visible) return;
    if (_requestedVisible) {
      for (final component in _meshComponents) {
        if (!component.isAttached) _node.addComponent(component);
      }
    } else {
      for (final component in _meshComponents) {
        if (component.isAttached) _node.removeComponent(component);
      }
    }
    _visible = _requestedVisible;
  }

  void commitMorphTargets() {
    for (final primitive in _morphPrimitives.values) {
      primitive.commit();
    }
  }

  void _installMorphTargets(MorphTargetDataFactory dataFactory) {
    final gltfNode = _owner.model.gltf.nodes[_nodeIndex];
    final meshIndex = gltfNode.mesh;
    if (meshIndex == null || meshIndex >= _owner.model.gltf.meshes.length) {
      return;
    }
    final gltfMesh = _owner.model.gltf.meshes[meshIndex];
    if (!gltfMesh.primitives.any((primitive) => primitive.targets.isNotEmpty)) {
      return;
    }
    final sceneMesh = _node.mesh;
    final pending =
        <
          ({
            int primitiveIndex,
            scene.Geometry geometry,
            MorphTargetPrimitiveData data,
          })
        >[];
    String? failure;
    var scenePrimitiveIndex = 0;
    for (
      var primitiveIndex = 0;
      primitiveIndex < gltfMesh.primitives.length;
      primitiveIndex++
    ) {
      final gltfPrimitive = gltfMesh.primitives[primitiveIndex];
      if (gltfPrimitive.mode != 4) {
        if (gltfPrimitive.targets.isNotEmpty) {
          failure = 'Only TRIANGLES morph primitives are supported.';
        }
        continue;
      }
      if (gltfPrimitive.targets.isNotEmpty) {
        final scenePrimitives = sceneMesh?.primitives;
        if (scenePrimitives == null ||
            scenePrimitiveIndex >= scenePrimitives.length) {
          failure = 'Flutter Scene did not import the morph-bearing primitive.';
        } else {
          final result = dataFactory.build(gltfPrimitive);
          final data = result.data;
          final geometry = scenePrimitives[scenePrimitiveIndex].geometry;
          final geometryMatches = data == null
              ? false
              : data.isSkinned
              ? geometry is scene.SkinnedGeometry
              : geometry is scene.UnskinnedGeometry &&
                    geometry is! scene.SkinnedGeometry;
          if (data == null) {
            failure = result.failure ?? 'Morph primitive data is unsupported.';
          } else if (!geometryMatches) {
            failure =
                'Flutter Scene imported a vertex layout that does not match '
                'the parsed morph primitive.';
          } else {
            pending.add((
              primitiveIndex: primitiveIndex,
              geometry: geometry,
              data: data,
            ));
          }
        }
      }
      scenePrimitiveIndex++;
    }
    if (failure != null) {
      for (
        var primitiveIndex = 0;
        primitiveIndex < gltfMesh.primitives.length;
        primitiveIndex++
      ) {
        if (gltfMesh.primitives[primitiveIndex].targets.isNotEmpty) {
          _morphFailures[primitiveIndex] = failure;
        }
      }
      return;
    }
    final prepared =
        <({int primitiveIndex, FlutterSceneMorphTargetPrimitive primitive})>[];
    try {
      for (final entry in pending) {
        prepared.add((
          primitiveIndex: entry.primitiveIndex,
          primitive: FlutterSceneMorphTargetPrimitive.prepare(
            entry.geometry,
            entry.data,
          ),
        ));
      }
    } on Object {
      failure =
          'Flutter Scene could not prepare reusable GPU morph geometry for '
          'this mesh.';
    }
    if (failure != null) {
      for (final entry in pending) {
        _morphFailures[entry.primitiveIndex] = failure;
      }
      return;
    }
    for (final entry in prepared) {
      entry.primitive.activate();
      _morphPrimitives[entry.primitiveIndex] = entry.primitive;
    }
  }
}

final class _FlutterSceneMaterialBinding implements VrmMaterialBinding {
  _FlutterSceneMaterialBinding(
    this._owner,
    this._materialIndex,
    this._material,
  );

  final FlutterSceneVrmBinding? _owner;
  final int _materialIndex;
  final dynamic _material;

  void applyFallback(GltfMaterial material) {
    setColor('color', material.baseColorFactor);
    setColor('emissionColor', material.emissiveFactor);
  }

  @override
  void setColor(String parameter, VrmVector4 value) {
    final material = _material;
    if (material == null) {
      _owner?._warnOnce(
        code: 'flutterScene.missingMaterial',
        message: 'Flutter Scene material $_materialIndex was not found.',
        gltfMaterialIndex: _materialIndex,
      );
      return;
    }
    try {
      switch (parameter) {
        case 'color':
          material.baseColorFactor = vm.Vector4(
            value.x,
            value.y,
            value.z,
            value.w,
          );
          return;
        case 'emissionColor':
          material.emissiveFactor = vm.Vector4(
            value.x,
            value.y,
            value.z,
            value.w,
          );
          return;
      }
    } on Object {
      _owner?._warnOnce(
        code: 'flutterScene.unsupportedMaterialColor',
        message:
            'Flutter Scene fallback binding only maps VRM color and emissionColor binds.',
        gltfMaterialIndex: _materialIndex,
      );
      return;
    }
    _owner?._warnOnce(
      code: 'flutterScene.unsupportedMaterialColor',
      message:
          'Flutter Scene fallback binding only maps VRM color and emissionColor binds.',
      gltfMaterialIndex: _materialIndex,
    );
  }

  @override
  void setTextureTransform({
    required VrmVector2 scale,
    required VrmVector2 offset,
  }) {
    _owner?._warnOnce(
      code: 'flutterScene.unsupportedTextureTransform',
      message:
          'Flutter Scene does not expose a documented texture transform mutator for imported materials.',
      gltfMaterialIndex: _materialIndex,
    );
  }
}

VrmMatrix4 _fromSceneMatrix(vm.Matrix4 value) => VrmMatrix4(value.storage);

vm.Matrix4 _toSceneMatrix(VrmMatrix4 value) =>
    vm.Matrix4.fromList(value.storage);
