import 'dart:typed_data';

import 'package:flvtterm/flvtterm.dart';

/// Joint subsets the renderer import substituted for skins whose joint count
/// exceeds Flutter Scene's fixed joint-palette capacity.
///
/// A glTF skin may list every joint of the skeleton while each mesh only
/// weights a few of them. When such a skin is larger than the renderer's
/// palette, the import gives each mesh node its own skin that keeps only the
/// joints its vertices reference and rewrites the mesh's `JOINTS_0`
/// attribute to index that subset. The parsed core model is unchanged; this
/// value records the per-node remap so vertex data the adapter packs itself
/// (reusable morph geometry) indexes the same subset.
final class FlutterSceneSkinReduction {
  FlutterSceneSkinReduction._(Map<int, List<int>> jointSlotRemapsByNode)
    : jointSlotRemapsByNode = Map.unmodifiable({
        for (final entry in jointSlotRemapsByNode.entries)
          entry.key: List<int>.unmodifiable(entry.value),
      });

  /// For each reduced glTF node index, the original skin joint slot to its
  /// reduced slot, or `-1` for a joint the node's mesh does not weight.
  final Map<int, List<int>> jointSlotRemapsByNode;

  /// The remap for [nodeIndex], or null when its skin was not reduced.
  List<int>? remapForNode(int nodeIndex) => jointSlotRemapsByNode[nodeIndex];
}

/// Rewrites `JOINTS_0` values through [remap], following the reduced skin.
///
/// A slot with zero weight contributes nothing, so its joint index is reset
/// to 0 rather than kept outside the reduced palette. The renderer import and
/// the adapter's own vertex packing both use this so they agree exactly.
List<int> remapJointSlots(
  List<double> joints,
  List<double> weights,
  List<int> remap,
) {
  final result = List<int>.filled(joints.length, 0);
  for (var index = 0; index < joints.length; index++) {
    if (weights[index] <= 0) continue;
    final slot = joints[index].toInt();
    final reduced = slot >= 0 && slot < remap.length ? remap[slot] : -1;
    result[index] = reduced < 0 ? 0 : reduced;
  }
  return result;
}

/// Whether [gltf] has a mesh node whose skin exceeds [jointPaletteCapacity].
bool gltfNeedsSkinReduction(GltfAsset gltf, int jointPaletteCapacity) =>
    gltf.nodes.any((node) {
      final skin = node.skin;
      return node.mesh != null &&
          skin != null &&
          skin >= 0 &&
          skin < gltf.skins.length &&
          gltf.skins[skin].joints.length > jointPaletteCapacity;
    });

/// Reduces oversized skins inside [decoded], the renderer's JSON copy of
/// [gltf], appending the rewritten joint and inverse-bind data as one new
/// buffer served through [resources].
///
/// Returns the applied remaps, or null when no skin could be reduced. A skin
/// is only replaced when every mesh node using it fits the capacity; otherwise
/// that skin stays as authored and the renderer reports it as before.
FlutterSceneSkinReduction? reduceOversizedSkins(
  GltfAsset gltf,
  Map<String, Object?> decoded,
  Map<String, Uint8List> resources,
  Set<String> reservedUris, {
  required int jointPaletteCapacity,
}) {
  final plans = <int, _NodePlan>{};
  final nodesBySkin = <int, List<int>>{};
  for (final node in gltf.nodes) {
    final skinIndex = node.skin;
    final meshIndex = node.mesh;
    if (skinIndex == null ||
        meshIndex == null ||
        skinIndex < 0 ||
        skinIndex >= gltf.skins.length ||
        meshIndex < 0 ||
        meshIndex >= gltf.meshes.length) {
      continue;
    }
    final skin = gltf.skins[skinIndex];
    if (skin.joints.length <= jointPaletteCapacity) continue;
    nodesBySkin.putIfAbsent(skinIndex, () => []).add(node.index);
    final plan = _planNode(
      gltf,
      node.index,
      meshIndex,
      skin,
      jointPaletteCapacity,
    );
    if (plan != null) plans[node.index] = plan;
  }
  // Replace a skin only when all of its mesh nodes can use a reduced copy.
  for (final entry in nodesBySkin.entries) {
    if (entry.value.any((nodeIndex) => !plans.containsKey(nodeIndex))) {
      entry.value.forEach(plans.remove);
    }
  }
  if (plans.isEmpty) return null;

  final skins = _jsonList(decoded, 'skins');
  final meshes = _jsonList(decoded, 'meshes');
  final nodes = _jsonList(decoded, 'nodes');
  final accessors = _jsonList(decoded, 'accessors');
  final bufferViews = _jsonList(decoded, 'bufferViews');
  final buffers = _jsonList(decoded, 'buffers');
  final bytes = BytesBuilder(copy: false);
  final bufferIndex = buffers.length;

  int addBufferView(Uint8List data) {
    while (bytes.length % 4 != 0) {
      bytes.addByte(0);
    }
    bufferViews.add(<String, Object?>{
      'buffer': bufferIndex,
      'byteOffset': bytes.length,
      'byteLength': data.length,
    });
    bytes.add(data);
    return bufferViews.length - 1;
  }

  // Reduced skins keyed by original skin and remap, so nodes sharing one
  // mesh and skin share one reduced skin.
  final reducedSkins = <int, Map<String, int>>{};
  final replacedSkins = <int>{};
  // Meshes already rewritten, with the remap their JOINTS_0 now follows.
  final rewrittenMeshes = <int, (String, int)>{};

  for (final plan in plans.values) {
    final node = nodes[plan.nodeIndex] as Map;
    final remapKey = plan.remap.join(',');

    final skinSlot = reducedSkins
        .putIfAbsent(plan.skinIndex, () => {})
        .putIfAbsent(remapKey, () {
          final original = skins[plan.skinIndex] as Map;
          final reduced = Map<String, Object?>.from(
            original.cast<String, Object?>(),
          );
          reduced['joints'] = [
            for (final slot in plan.usedSlots)
              gltf.skins[plan.skinIndex].joints[slot],
          ];
          final inverseBind = plan.inverseBindMatrices;
          if (inverseBind == null) {
            reduced.remove('inverseBindMatrices');
          } else {
            final matrices = Float32List(plan.usedSlots.length * 16);
            for (var index = 0; index < plan.usedSlots.length; index++) {
              final source = plan.usedSlots[index] * 16;
              for (var component = 0; component < 16; component++) {
                matrices[index * 16 + component] =
                    inverseBind[source + component];
              }
            }
            accessors.add(<String, Object?>{
              'bufferView': addBufferView(
                matrices.buffer.asUint8List(
                  matrices.offsetInBytes,
                  matrices.lengthInBytes,
                ),
              ),
              'componentType': 5126,
              'count': plan.usedSlots.length,
              'type': 'MAT4',
            });
            reduced['inverseBindMatrices'] = accessors.length - 1;
          }
          if (replacedSkins.add(plan.skinIndex)) {
            skins[plan.skinIndex] = reduced;
            return plan.skinIndex;
          }
          skins.add(reduced);
          return skins.length - 1;
        });
    node['skin'] = skinSlot;

    var meshIndex = plan.meshIndex;
    final rewritten = rewrittenMeshes[meshIndex];
    if (rewritten != null && rewritten.$1 != remapKey) {
      // Another node already rewrote this mesh for a different subset.
      meshes.add(_deepCopy(meshes[meshIndex]));
      meshIndex = meshes.length - 1;
      node['mesh'] = meshIndex;
    }
    if (rewritten != null && rewritten.$1 == remapKey) {
      node['mesh'] = rewritten.$2;
      continue;
    }
    rewrittenMeshes[plan.meshIndex] = (remapKey, meshIndex);
    final primitives = (meshes[meshIndex] as Map)['primitives'] as List;
    for (final entry in plan.primitiveJoints.entries) {
      final attributes = (primitives[entry.key] as Map)['attributes'] as Map;
      final values = entry.value;
      final wide = plan.usedSlots.length > 255;
      final Uint8List data;
      if (wide) {
        final shorts = Uint16List.fromList(values);
        data = shorts.buffer.asUint8List(
          shorts.offsetInBytes,
          shorts.lengthInBytes,
        );
      } else {
        data = Uint8List.fromList(values);
      }
      accessors.add(<String, Object?>{
        'bufferView': addBufferView(data),
        'componentType': wide ? 5123 : 5121,
        'count': values.length ~/ 4,
        'type': 'VEC4',
      });
      attributes['JOINTS_0'] = accessors.length - 1;
    }
  }

  final uri = _uniqueSkinBufferUri(reservedUris);
  reservedUris.add(uri);
  final data = bytes.takeBytes();
  buffers.add(<String, Object?>{'uri': uri, 'byteLength': data.length});
  resources[uri] = data;
  return FlutterSceneSkinReduction._({
    for (final plan in plans.values) plan.nodeIndex: plan.remap,
  });
}

final class _NodePlan {
  const _NodePlan({
    required this.nodeIndex,
    required this.meshIndex,
    required this.skinIndex,
    required this.usedSlots,
    required this.remap,
    required this.primitiveJoints,
    required this.inverseBindMatrices,
  });

  final int nodeIndex;
  final int meshIndex;
  final int skinIndex;
  final List<int> usedSlots;
  final List<int> remap;
  final Map<int, List<int>> primitiveJoints;
  final List<double>? inverseBindMatrices;
}

_NodePlan? _planNode(
  GltfAsset gltf,
  int nodeIndex,
  int meshIndex,
  GltfSkin skin,
  int capacity,
) {
  final jointCount = skin.joints.length;
  final used = <int>{};
  final reads = <int, (List<double>, List<double>)>{};
  final primitives = gltf.meshes[meshIndex].primitives;
  for (var index = 0; index < primitives.length; index++) {
    final primitive = primitives[index];
    final jointsIndex = primitive.attributes['JOINTS_0'];
    final weightsIndex = primitive.attributes['WEIGHTS_0'];
    if (jointsIndex == null || weightsIndex == null) continue;
    final joints = gltf.readAccessorNumbers(
      jointsIndex,
      applyNormalization: false,
    );
    final weights = gltf.readAccessorNumbers(weightsIndex);
    if (joints == null ||
        weights == null ||
        joints.isEmpty ||
        joints.length != weights.length ||
        joints.length % 4 != 0) {
      return null;
    }
    for (var slot = 0; slot < joints.length; slot++) {
      if (!(weights[slot] > 0)) continue;
      final joint = joints[slot];
      if (!joint.isFinite || joint < 0 || joint >= jointCount) return null;
      used.add(joint.toInt());
    }
    reads[index] = (joints, weights);
  }
  if (used.isEmpty) used.add(0);
  final usedSlots = used.toList()..sort();
  if (usedSlots.length > capacity) return null;
  final remap = List<int>.filled(jointCount, -1);
  for (var index = 0; index < usedSlots.length; index++) {
    remap[usedSlots[index]] = index;
  }
  List<double>? inverseBind;
  final inverseBindIndex = skin.inverseBindMatrices;
  if (inverseBindIndex != null) {
    inverseBind = gltf.readAccessorNumbers(
      inverseBindIndex,
      requireFloat: true,
    );
    if (inverseBind == null || inverseBind.length != jointCount * 16) {
      return null;
    }
  }
  return _NodePlan(
    nodeIndex: nodeIndex,
    meshIndex: meshIndex,
    skinIndex: skin.index,
    usedSlots: usedSlots,
    remap: remap,
    primitiveJoints: {
      for (final entry in reads.entries)
        entry.key: remapJointSlots(entry.value.$1, entry.value.$2, remap),
    },
    inverseBindMatrices: inverseBind,
  );
}

List<Object?> _jsonList(Map<String, Object?> decoded, String key) {
  final value = decoded[key];
  if (value is List<Object?>) return value;
  if (value != null) {
    throw StateError('Parsed glTF $key is not an array.');
  }
  final created = <Object?>[];
  decoded[key] = created;
  return created;
}

Object? _deepCopy(Object? value) => switch (value) {
  Map<Object?, Object?> map => {
    for (final entry in map.entries) entry.key: _deepCopy(entry.value),
  },
  List<Object?> list => [for (final item in list) _deepCopy(item)],
  _ => value,
};

String _uniqueSkinBufferUri(Set<String> reserved) {
  var suffix = 0;
  while (true) {
    final candidate = '__flvtterm_reduced_skins_$suffix.bin';
    if (!reserved.contains(candidate)) return candidate;
    suffix++;
  }
}
