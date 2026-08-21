import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' as scene;
import 'package:flvtterm/flvtterm.dart';

/// Maps parsed glTF node indices to their imported Flutter Scene nodes.
Map<int, scene.Node> mapFlutterSceneNodesByGltfHierarchy(
  scene.Node root,
  GltfAsset gltf, {
  bool? includeRoot,
}) {
  final mapped = <int, scene.Node>{};
  if (gltf.nodes.isEmpty) return mapped;

  final roots = defaultGltfSceneRoots(gltf);
  final useRoot =
      includeRoot ?? _descendantCount(root) < _reachableNodeCount(gltf, roots);
  final visited = <int>{};
  if (useRoot || roots.isEmpty) {
    _mapNodeHierarchy(0, root, gltf, mapped, visited);
    return mapped;
  }

  final count = math.min(roots.length, root.children.length);
  for (var index = 0; index < count; index++) {
    _mapNodeHierarchy(
      roots[index],
      root.children[index],
      gltf,
      mapped,
      visited,
    );
  }
  return mapped;
}

/// Aligns parsed primitives with the subset imported by Flutter Scene.
List<GltfMeshPrimitive> materialAlignedFlutterScenePrimitives(
  List<GltfMeshPrimitive> primitives,
  int scenePrimitiveCount,
) {
  if (primitives.length == scenePrimitiveCount) return primitives;
  // Flutter Scene omits non-TRIANGLES primitives during GLB import.
  final triangles = [
    for (final primitive in primitives)
      if (primitive.mode == 4) primitive,
  ];
  return triangles.length == scenePrimitiveCount ? triangles : primitives;
}

int _descendantCount(scene.Node root) {
  var count = 0;

  void visit(scene.Node node) {
    count += 1;
    for (final child in node.children) {
      visit(child);
    }
  }

  for (final child in root.children) {
    visit(child);
  }
  return count;
}

/// Returns the parsed glTF roots for its selected default scene.
List<int> defaultGltfSceneRoots(GltfAsset gltf) {
  if (gltf.scenes.isEmpty) return const [];
  final sceneIndex = gltf.scene ?? 0;
  if (sceneIndex < 0 || sceneIndex >= gltf.scenes.length) return const [];
  return gltf.scenes[sceneIndex].nodes;
}

int _reachableNodeCount(GltfAsset gltf, List<int> roots) {
  final visited = <int>{};

  void visit(int nodeIndex) {
    if (nodeIndex < 0 || nodeIndex >= gltf.nodes.length) return;
    if (!visited.add(nodeIndex)) return;
    for (final childIndex in gltf.nodes[nodeIndex].children) {
      visit(childIndex);
    }
  }

  for (final root in roots) {
    visit(root);
  }
  return visited.length;
}

void _mapNodeHierarchy(
  int gltfNodeIndex,
  scene.Node sceneNode,
  GltfAsset gltf,
  Map<int, scene.Node> output,
  Set<int> visited,
) {
  if (gltfNodeIndex < 0 || gltfNodeIndex >= gltf.nodes.length) return;
  if (!visited.add(gltfNodeIndex)) return;
  output[gltfNodeIndex] = sceneNode;

  final gltfChildren = gltf.nodes[gltfNodeIndex].children;
  final count = math.min(gltfChildren.length, sceneNode.children.length);
  for (var index = 0; index < count; index++) {
    _mapNodeHierarchy(
      gltfChildren[index],
      sceneNode.children[index],
      gltf,
      output,
      visited,
    );
  }
}
