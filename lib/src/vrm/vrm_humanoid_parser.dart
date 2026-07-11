part of '../../flvtterm.dart';

VrmHumanoid _parseHumanoid(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path, {
  bool validateRequiredBones = true,
}) {
  if (value is! Map) {
    sink.error(
      'vrm.invalidHumanoidObject',
      'Humanoid must be a JSON object.',
      jsonPath: path,
    );
  }
  final raw = _object(value);
  if (raw.containsKey('humanBones') && raw['humanBones'] is! Map) {
    sink.error(
      'vrm.invalidHumanoidBonesObject',
      'humanoid.humanBones must be a JSON object.',
      jsonPath: '$path.humanBones',
    );
  } else if (value is Map &&
      !raw.containsKey('humanBones') &&
      path == r'$.extensions.VRMC_vrm.humanoid') {
    sink.error(
      'vrm.missingHumanoidHumanBones',
      'VRMC_vrm.humanoid.humanBones is required.',
      jsonPath: '$path.humanBones',
    );
  }
  final humanBonesJson = _object(raw['humanBones']);
  final humanBones = <VrmHumanoidBone, VrmHumanBone>{};
  final usedNodes = <int, VrmHumanoidBone>{};

  for (final entry in humanBonesJson.entries) {
    final bone = VrmHumanoidBone.fromSpecName(entry.key);
    if (bone == null) {
      sink.warning(
        'vrm.unknownHumanoidBone',
        'Unknown humanoid bone "${entry.key}" was ignored.',
        jsonPath: '$path.humanBones.${entry.key}',
      );
      continue;
    }
    if (entry.value is! Map) {
      sink.error(
        'vrm.invalidHumanoidBoneObject',
        'Humanoid bone ${bone.specName} must be a JSON object.',
        jsonPath: '$path.humanBones.${bone.specName}',
      );
      continue;
    }
    final assignment = _object(entry.value);
    final nodeValue = assignment['node'];
    final node = _int(nodeValue);
    if (!assignment.containsKey('node')) {
      sink.error(
        'vrm.humanoidBoneMissingNode',
        'Humanoid bone ${bone.specName} must specify a node.',
        jsonPath: '$path.humanBones.${bone.specName}.node',
      );
      continue;
    }
    if (node == null) {
      sink.error(
        'vrm.humanoidBoneInvalidNode',
        'Humanoid bone ${bone.specName} node must be an integer.',
        jsonPath: '$path.humanBones.${bone.specName}.node',
      );
      continue;
    }
    _validateIndex(
      node,
      gltf.nodes.length,
      sink,
      'vrm.invalidHumanoidNode',
      '$path.humanBones.${bone.specName}.node',
    );
    if (node < 0 || node >= gltf.nodes.length) continue;
    final previous = usedNodes[node];
    if (previous != null) {
      sink.error(
        'vrm.duplicateHumanoidNode',
        'Node $node is assigned to both ${previous.specName} and ${bone.specName}.',
        jsonPath: '$path.humanBones.${bone.specName}.node',
        gltfNodeIndex: node,
      );
      continue;
    }
    usedNodes[node] = bone;
    humanBones[bone] = VrmHumanBone(bone: bone, node: node, raw: assignment);
  }

  if (validateRequiredBones) {
    for (final bone in VrmHumanoidBone.values.where(
      (bone) => bone.isRequired,
    )) {
      if (!humanBones.containsKey(bone)) {
        sink.error(
          'vrm.missingRequiredHumanoidBone',
          'Required humanoid bone ${bone.specName} is missing.',
          jsonPath: '$path.humanBones.${bone.specName}',
        );
      }
    }
  }

  _validateHumanoidTransforms(gltf, humanBones, sink);
  _validateHumanoidParents(gltf, humanBones, sink, path);
  return VrmHumanoid._(humanBones: Map.unmodifiable(humanBones), raw: raw);
}

void _validateHumanoidTransforms(
  GltfAsset gltf,
  Map<VrmHumanoidBone, VrmHumanBone> humanBones,
  _DiagnosticSink sink,
) {
  for (final assignment in humanBones.values) {
    final node = gltf.nodes.elementAtOrNull(assignment.node);
    if (node == null) continue;
    if (node.restScale.any((component) => component <= 0) ||
        _hasReflectedMatrixBasis(node.matrix)) {
      sink.error(
        'vrm.nonPositiveHumanoidScale',
        'Humanoid bone ${assignment.bone.specName} must have positive scale components.',
        jsonPath: node.matrix == null
            ? '\$.nodes[${assignment.node}].scale'
            : '\$.nodes[${assignment.node}].matrix',
        gltfNodeIndex: assignment.node,
      );
    }
  }
}

bool _hasReflectedMatrixBasis(VrmMatrix4? matrix) {
  if (matrix == null) return false;
  final m = matrix.storage;
  final determinant =
      m[0] * (m[5] * m[10] - m[9] * m[6]) -
      m[4] * (m[1] * m[10] - m[9] * m[2]) +
      m[8] * (m[1] * m[6] - m[5] * m[2]);
  return determinant <= 0;
}

void _validateHumanoidParents(
  GltfAsset gltf,
  Map<VrmHumanoidBone, VrmHumanBone> humanBones,
  _DiagnosticSink sink,
  String path,
) {
  final parents = _nodeParents(gltf);
  for (final entry in humanBones.entries) {
    final expectedParent = _nearestAssignedHumanoidParent(
      entry.key,
      humanBones,
    );
    if (expectedParent == null) continue;
    final childNode = entry.value.node;
    final parentNode = humanBones[expectedParent]?.node;
    if (parentNode == null ||
        !_isDescendantOf(childNode, parentNode, parents)) {
      sink.error(
        'vrm.invalidHumanoidParent',
        '${entry.key.specName} must be a descendant of ${expectedParent.specName}.',
        jsonPath: '$path.humanBones.${entry.key.specName}.node',
        gltfNodeIndex: childNode,
      );
    }
  }
}

Map<int, int> _nodeParents(GltfAsset gltf) {
  final parents = <int, int>{};
  for (final node in gltf.nodes) {
    for (final child in node.children) {
      parents.putIfAbsent(child, () => node.index);
    }
  }
  return parents;
}

VrmHumanoidBone? _nearestAssignedHumanoidParent(
  VrmHumanoidBone bone,
  Map<VrmHumanoidBone, VrmHumanBone> humanBones,
) {
  var parent = _directHumanoidParent[bone];
  while (parent != null) {
    if (humanBones.containsKey(parent)) return parent;
    parent = _directHumanoidParent[parent];
  }
  return null;
}

bool _isDescendantOf(int node, int expectedAncestor, Map<int, int> parents) {
  final seen = <int>{};
  var current = parents[node];
  while (current != null && seen.add(current)) {
    if (current == expectedAncestor) return true;
    current = parents[current];
  }
  return false;
}

final _directHumanoidParent = <VrmHumanoidBone, VrmHumanoidBone>{
  VrmHumanoidBone.spine: VrmHumanoidBone.hips,
  VrmHumanoidBone.chest: VrmHumanoidBone.spine,
  VrmHumanoidBone.upperChest: VrmHumanoidBone.chest,
  VrmHumanoidBone.neck: VrmHumanoidBone.upperChest,
  VrmHumanoidBone.head: VrmHumanoidBone.neck,
  VrmHumanoidBone.leftEye: VrmHumanoidBone.head,
  VrmHumanoidBone.rightEye: VrmHumanoidBone.head,
  VrmHumanoidBone.jaw: VrmHumanoidBone.head,
  VrmHumanoidBone.leftUpperLeg: VrmHumanoidBone.hips,
  VrmHumanoidBone.leftLowerLeg: VrmHumanoidBone.leftUpperLeg,
  VrmHumanoidBone.leftFoot: VrmHumanoidBone.leftLowerLeg,
  VrmHumanoidBone.leftToes: VrmHumanoidBone.leftFoot,
  VrmHumanoidBone.rightUpperLeg: VrmHumanoidBone.hips,
  VrmHumanoidBone.rightLowerLeg: VrmHumanoidBone.rightUpperLeg,
  VrmHumanoidBone.rightFoot: VrmHumanoidBone.rightLowerLeg,
  VrmHumanoidBone.rightToes: VrmHumanoidBone.rightFoot,
  VrmHumanoidBone.leftShoulder: VrmHumanoidBone.upperChest,
  VrmHumanoidBone.leftUpperArm: VrmHumanoidBone.leftShoulder,
  VrmHumanoidBone.leftLowerArm: VrmHumanoidBone.leftUpperArm,
  VrmHumanoidBone.leftHand: VrmHumanoidBone.leftLowerArm,
  VrmHumanoidBone.rightShoulder: VrmHumanoidBone.upperChest,
  VrmHumanoidBone.rightUpperArm: VrmHumanoidBone.rightShoulder,
  VrmHumanoidBone.rightLowerArm: VrmHumanoidBone.rightUpperArm,
  VrmHumanoidBone.rightHand: VrmHumanoidBone.rightLowerArm,
  VrmHumanoidBone.leftThumbMetacarpal: VrmHumanoidBone.leftHand,
  VrmHumanoidBone.leftThumbProximal: VrmHumanoidBone.leftThumbMetacarpal,
  VrmHumanoidBone.leftThumbDistal: VrmHumanoidBone.leftThumbProximal,
  VrmHumanoidBone.leftIndexProximal: VrmHumanoidBone.leftHand,
  VrmHumanoidBone.leftIndexIntermediate: VrmHumanoidBone.leftIndexProximal,
  VrmHumanoidBone.leftIndexDistal: VrmHumanoidBone.leftIndexIntermediate,
  VrmHumanoidBone.leftMiddleProximal: VrmHumanoidBone.leftHand,
  VrmHumanoidBone.leftMiddleIntermediate: VrmHumanoidBone.leftMiddleProximal,
  VrmHumanoidBone.leftMiddleDistal: VrmHumanoidBone.leftMiddleIntermediate,
  VrmHumanoidBone.leftRingProximal: VrmHumanoidBone.leftHand,
  VrmHumanoidBone.leftRingIntermediate: VrmHumanoidBone.leftRingProximal,
  VrmHumanoidBone.leftRingDistal: VrmHumanoidBone.leftRingIntermediate,
  VrmHumanoidBone.leftLittleProximal: VrmHumanoidBone.leftHand,
  VrmHumanoidBone.leftLittleIntermediate: VrmHumanoidBone.leftLittleProximal,
  VrmHumanoidBone.leftLittleDistal: VrmHumanoidBone.leftLittleIntermediate,
  VrmHumanoidBone.rightThumbMetacarpal: VrmHumanoidBone.rightHand,
  VrmHumanoidBone.rightThumbProximal: VrmHumanoidBone.rightThumbMetacarpal,
  VrmHumanoidBone.rightThumbDistal: VrmHumanoidBone.rightThumbProximal,
  VrmHumanoidBone.rightIndexProximal: VrmHumanoidBone.rightHand,
  VrmHumanoidBone.rightIndexIntermediate: VrmHumanoidBone.rightIndexProximal,
  VrmHumanoidBone.rightIndexDistal: VrmHumanoidBone.rightIndexIntermediate,
  VrmHumanoidBone.rightMiddleProximal: VrmHumanoidBone.rightHand,
  VrmHumanoidBone.rightMiddleIntermediate: VrmHumanoidBone.rightMiddleProximal,
  VrmHumanoidBone.rightMiddleDistal: VrmHumanoidBone.rightMiddleIntermediate,
  VrmHumanoidBone.rightRingProximal: VrmHumanoidBone.rightHand,
  VrmHumanoidBone.rightRingIntermediate: VrmHumanoidBone.rightRingProximal,
  VrmHumanoidBone.rightRingDistal: VrmHumanoidBone.rightRingIntermediate,
  VrmHumanoidBone.rightLittleProximal: VrmHumanoidBone.rightHand,
  VrmHumanoidBone.rightLittleIntermediate: VrmHumanoidBone.rightLittleProximal,
  VrmHumanoidBone.rightLittleDistal: VrmHumanoidBone.rightLittleIntermediate,
};
