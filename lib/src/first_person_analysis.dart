part of '../flvtterm.dart';

bool? _meshHasHeadInfluence(VrmModel model, int nodeIndex) {
  final node = model.gltf.nodes.elementAtOrNull(nodeIndex);
  if (node == null || node.mesh == null) return null;
  final mesh = model.gltf.meshes.elementAtOrNull(node.mesh!);
  if (mesh == null) return null;

  var sawClassifiedPrimitive = false;
  var sawUnclassifiedPrimitive = false;
  for (var i = 0; i < mesh.primitives.length; i++) {
    final hasHeadInfluence = _primitiveHasHeadInfluence(model, nodeIndex, i);
    if (hasHeadInfluence == null) {
      sawUnclassifiedPrimitive = true;
      continue;
    }
    sawClassifiedPrimitive = true;
    if (hasHeadInfluence) return true;
  }
  if (sawUnclassifiedPrimitive) return null;
  return sawClassifiedPrimitive ? false : null;
}

bool? _primitiveHasHeadInfluence(
  VrmModel model,
  int nodeIndex,
  int primitiveIndex,
) {
  final influences = _primitiveVertexHeadInfluence(
    model,
    nodeIndex,
    primitiveIndex,
  );
  if (influences == null) return null;
  return influences.contains(true);
}

List<bool>? _primitiveTriangleHeadInfluence(
  VrmModel model,
  int nodeIndex,
  int primitiveIndex,
) {
  final node = model.gltf.nodes.elementAtOrNull(nodeIndex);
  if (node == null || node.mesh == null) return null;
  final primitive = model.gltf.meshes
      .elementAtOrNull(node.mesh!)
      ?.primitives
      .elementAtOrNull(primitiveIndex);
  if (primitive == null || !_isTriangleTopology(primitive.mode)) return null;
  final vertexInfluence = _primitiveVertexHeadInfluence(
    model,
    nodeIndex,
    primitiveIndex,
  );
  if (vertexInfluence == null) return null;
  final indices = primitive.indices == null
      ? null
      : _readAccessorNumbers(
          model.gltf,
          primitive.indices!,
          applyNormalization: false,
        );
  final vertexOrderCount = indices?.length ?? vertexInfluence.length;
  final result = <bool>[];
  final triangleCount = _triangleCountForTopology(
    primitive.mode,
    vertexOrderCount,
  );
  for (var triangle = 0; triangle < triangleCount; triangle++) {
    var influenced = false;
    for (var corner = 0; corner < 3; corner++) {
      final orderIndex = _triangleTopologyOrderIndex(
        primitive.mode,
        triangle,
        corner,
      );
      final vertex = indices == null ? orderIndex : indices[orderIndex].round();
      if (vertex < 0 || vertex >= vertexInfluence.length) return null;
      influenced = influenced || vertexInfluence[vertex];
    }
    result.add(influenced);
  }
  return result;
}

int? _primitiveTriangleCount(
  GltfAsset gltf,
  int nodeIndex,
  int primitiveIndex,
) {
  final node = gltf.nodes.elementAtOrNull(nodeIndex);
  if (node == null || node.mesh == null) return null;
  final primitive = gltf.meshes
      .elementAtOrNull(node.mesh!)
      ?.primitives
      .elementAtOrNull(primitiveIndex);
  if (primitive == null || !_isTriangleTopology(primitive.mode)) return null;
  if (primitive.indices != null) {
    final count = gltf.accessors.elementAtOrNull(primitive.indices!)?.count;
    return count == null
        ? null
        : _triangleCountForTopology(primitive.mode, count);
  }
  final count = _primitiveVertexCount(gltf, primitive);
  return count == null
      ? null
      : _triangleCountForTopology(primitive.mode, count);
}

List<bool>? _primitiveVertexHeadInfluence(
  VrmModel model,
  int nodeIndex,
  int primitiveIndex,
) {
  final node = model.gltf.nodes.elementAtOrNull(nodeIndex);
  if (node == null || node.mesh == null || node.skin == null) return null;
  final mesh = model.gltf.meshes.elementAtOrNull(node.mesh!);
  final primitive = mesh?.primitives.elementAtOrNull(primitiveIndex);
  final skin = model.gltf.skins.elementAtOrNull(node.skin!);
  final head = model.vrm.humanoid.nodeFor(VrmHumanoidBone.head);
  if (primitive == null || skin == null || head == null) return null;
  final vertexCount = _primitiveVertexCount(model.gltf, primitive);
  if (vertexCount == null) return null;

  final headNodes = _descendantsIncluding(model.gltf, head);
  final headJointIndices = <int>{};
  for (var i = 0; i < skin.joints.length; i++) {
    if (headNodes.contains(skin.joints[i])) headJointIndices.add(i);
  }
  if (headJointIndices.isEmpty) return List.filled(vertexCount, false);

  final result = List.filled(vertexCount, false);
  var sawSkinning = false;
  for (final entry in primitive.attributes.entries) {
    if (!entry.key.startsWith('JOINTS_')) continue;
    final suffix = entry.key.substring('JOINTS_'.length);
    final weightAccessor = primitive.attributes['WEIGHTS_$suffix'];
    if (weightAccessor == null) continue;
    final joints = _readAccessorNumbers(
      model.gltf,
      entry.value,
      applyNormalization: false,
    );
    final weights = _readAccessorNumbers(model.gltf, weightAccessor);
    if (joints == null || weights == null) return null;
    final jointComponents = model.gltf.accessors
        .elementAtOrNull(entry.value)
        ?.componentCount;
    final weightComponents = model.gltf.accessors
        .elementAtOrNull(weightAccessor)
        ?.componentCount;
    final jointVertexCount = model.gltf.accessors
        .elementAtOrNull(entry.value)
        ?.count;
    final weightVertexCount = model.gltf.accessors
        .elementAtOrNull(weightAccessor)
        ?.count;
    if (jointComponents == null ||
        weightComponents == null ||
        jointVertexCount == null ||
        weightVertexCount == null ||
        vertexCount > jointVertexCount ||
        vertexCount > weightVertexCount) {
      return null;
    }
    sawSkinning = true;
    final components = math.min(jointComponents, weightComponents);
    for (var vertex = 0; vertex < vertexCount; vertex++) {
      for (var component = 0; component < components; component++) {
        final joint = joints[vertex * jointComponents + component].round();
        final weight = weights[vertex * weightComponents + component];
        if (weight > 0 && headJointIndices.contains(joint)) {
          result[vertex] = true;
        }
      }
    }
  }
  return sawSkinning ? result : null;
}

int? _primitiveVertexCount(GltfAsset gltf, GltfMeshPrimitive primitive) {
  for (final accessorIndex in primitive.attributes.values) {
    final count = gltf.accessors.elementAtOrNull(accessorIndex)?.count;
    if (count != null) return count;
  }
  return null;
}

Set<int> _descendantsIncluding(GltfAsset gltf, int root) {
  final result = <int>{};
  final stack = [root];
  while (stack.isNotEmpty) {
    final nodeIndex = stack.removeLast();
    if (!result.add(nodeIndex)) continue;
    final node = gltf.nodes.elementAtOrNull(nodeIndex);
    if (node != null) stack.addAll(node.children);
  }
  return result;
}

bool _isTriangleTopology(int mode) => mode == 4 || mode == 5 || mode == 6;

int _triangleCountForTopology(int mode, int vertexOrderCount) {
  if (mode == 4) return vertexOrderCount ~/ 3;
  return math.max(0, vertexOrderCount - 2);
}

int _triangleTopologyOrderIndex(int mode, int triangle, int corner) {
  if (mode == 4) return triangle * 3 + corner;
  if (mode == 5) {
    return switch (corner) {
      0 => triangle,
      1 => triangle + 1 + triangle % 2,
      _ => triangle + 2 - triangle % 2,
    };
  }
  return corner == 2 ? 0 : triangle + corner + 1;
}
