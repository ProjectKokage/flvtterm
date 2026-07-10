part of '../flvtterm_test.dart';

Uint8List _glb(Map<String, Object?> json, {Uint8List? binaryChunk}) {
  final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));
  final paddedJsonLength = (jsonBytes.length + 3) & ~3;
  final paddedBinLength = binaryChunk == null
      ? 0
      : (binaryChunk.length + 3) & ~3;
  final totalLength =
      12 +
      8 +
      paddedJsonLength +
      (binaryChunk == null ? 0 : 8 + paddedBinLength);
  final bytes = Uint8List(totalLength);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, 0x46546c67, Endian.little);
  data.setUint32(4, 2, Endian.little);
  data.setUint32(8, totalLength, Endian.little);
  data.setUint32(12, paddedJsonLength, Endian.little);
  data.setUint32(16, 0x4e4f534a, Endian.little);
  bytes.setRange(20, 20 + jsonBytes.length, jsonBytes);
  for (var i = 20 + jsonBytes.length; i < 20 + paddedJsonLength; i++) {
    bytes[i] = 0x20;
  }
  if (binaryChunk != null) {
    final binHeader = 20 + paddedJsonLength;
    data.setUint32(binHeader, paddedBinLength, Endian.little);
    data.setUint32(binHeader + 4, 0x004e4942, Endian.little);
    bytes.setRange(
      binHeader + 8,
      binHeader + 8 + binaryChunk.length,
      binaryChunk,
    );
  }
  return bytes;
}

Uint8List _glbChunks(List<MapEntry<int, Uint8List>> chunks) {
  final paddedChunks = chunks.map((chunk) {
    final paddedLength = (chunk.value.length + 3) & ~3;
    final bytes = Uint8List(paddedLength);
    bytes.setRange(0, chunk.value.length, chunk.value);
    for (var i = chunk.value.length; i < paddedLength; i++) {
      bytes[i] = chunk.key == 0x4e4f534a ? 0x20 : 0;
    }
    return MapEntry(chunk.key, bytes);
  }).toList();
  final totalLength =
      12 +
      paddedChunks.fold<int>(0, (sum, chunk) {
        return sum + 8 + chunk.value.length;
      });
  final bytes = Uint8List(totalLength);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, 0x46546c67, Endian.little);
  data.setUint32(4, 2, Endian.little);
  data.setUint32(8, totalLength, Endian.little);
  var offset = 12;
  for (final chunk in paddedChunks) {
    data.setUint32(offset, chunk.value.length, Endian.little);
    data.setUint32(offset + 4, chunk.key, Endian.little);
    bytes.setRange(offset + 8, offset + 8 + chunk.value.length, chunk.value);
    offset += 8 + chunk.value.length;
  }
  return bytes;
}

Uint8List _floats(List<double> values) {
  final bytes = Uint8List(values.length * 4);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < values.length; i++) {
    data.setFloat32(i * 4, values[i], Endian.little);
  }
  return bytes;
}

Map<String, Object?> _animationStorageJson(
  int byteLength,
  List<List<int>> bufferViewRanges, {
  List<String> accessorTypes = const ['SCALAR', 'VEC3', 'VEC3'],
}) {
  return {
    'buffers': [
      <String, Object?>{'byteLength': byteLength},
    ],
    'bufferViews': [
      for (final range in bufferViewRanges)
        <String, Object?>{
          'buffer': 0,
          'byteOffset': range[0],
          'byteLength': range[1],
        },
    ],
    'accessors': [
      for (var i = 0; i < bufferViewRanges.length; i++)
        <String, Object?>{
          'bufferView': i,
          'componentType': 5126,
          'count':
              bufferViewRanges[i][1] ~/
              (_testComponentCount(accessorTypes[i]) * 4),
          'type': accessorTypes[i],
          if (i == 0 && accessorTypes[i] == 'SCALAR') ...{
            'min': [0.0],
            'max': [
              (bufferViewRanges[i][1] ~/
                          (_testComponentCount(accessorTypes[i]) * 4) -
                      1)
                  .toDouble(),
            ],
          },
        },
    ],
  };
}

int _testComponentCount(String type) {
  return switch (type) {
    'SCALAR' => 1,
    'VEC3' => 3,
    'VEC4' => 4,
    _ => throw ArgumentError.value(type, 'type'),
  };
}

double mathCosDegrees(double degrees) => math.cos(degrees * math.pi / 180);

VrmMatrix4 _testTrs({
  List<double> translation = const [0.0, 0.0, 0.0],
  List<double> rotation = const [0.0, 0.0, 0.0, 1.0],
  List<double> scale = const [1.0, 1.0, 1.0],
}) {
  final x = rotation[0];
  final y = rotation[1];
  final z = rotation[2];
  final w = rotation[3];
  final sx = scale[0];
  final sy = scale[1];
  final sz = scale[2];
  final xx = x * x;
  final xy = x * y;
  final xz = x * z;
  final xw = x * w;
  final yy = y * y;
  final yz = y * z;
  final yw = y * w;
  final zz = z * z;
  final zw = z * w;
  return VrmMatrix4([
    (1 - 2 * (yy + zz)) * sx,
    2 * (xy + zw) * sx,
    2 * (xz - yw) * sx,
    0,
    2 * (xy - zw) * sy,
    (1 - 2 * (xx + zz)) * sy,
    2 * (yz + xw) * sy,
    0,
    2 * (xz + yw) * sz,
    2 * (yz - xw) * sz,
    (1 - 2 * (xx + yy)) * sz,
    0,
    translation[0],
    translation[1],
    translation[2],
    1,
  ]);
}

Map<String, Object?> _lookAtJson({
  required String type,
  double horizontalInnerOutput = 1,
  double horizontalOuterOutput = 1,
}) {
  return {
    'type': type,
    'offsetFromHeadBone': [0.0, 0.0, 0.0],
    'rangeMapHorizontalInner': {
      'inputMaxValue': 90.0,
      'outputScale': horizontalInnerOutput,
    },
    'rangeMapHorizontalOuter': {
      'inputMaxValue': 90.0,
      'outputScale': horizontalOuterOutput,
    },
    'rangeMapVerticalDown': {'inputMaxValue': 90.0, 'outputScale': 1.0},
    'rangeMapVerticalUp': {'inputMaxValue': 90.0, 'outputScale': 1.0},
  };
}

Map<String, Object?> _minimalVrmJson({
  List<Object?> meshes = const [],
  List<Object?> materials = const [],
  Map<int, int> nodeMesh = const {},
  Map<String, Object?> firstPerson = const {},
  Map<String, Object?> expressions = const {},
}) {
  return {
    'asset': {'version': '2.0'},
    'extensionsUsed': ['VRMC_vrm'],
    'extensionsRequired': ['VRMC_vrm'],
    'scene': 0,
    'scenes': [
      {
        'nodes': [0],
      },
    ],
    'nodes': _nodes(nodeMesh),
    if (meshes.isNotEmpty) 'meshes': meshes,
    if (materials.isNotEmpty) 'materials': materials,
    'extensions': {
      'VRMC_vrm': {
        'specVersion': '1.0',
        'meta': {
          'name': 'Avatar',
          'authors': ['Author'],
          'licenseUrl': 'https://example.com/license',
        },
        'humanoid': {
          'humanBones': {
            for (final entry in _boneNodes.entries)
              entry.key.specName: {'node': entry.value},
          },
        },
        if (firstPerson.isNotEmpty) 'firstPerson': firstPerson,
        if (expressions.isNotEmpty) 'expressions': expressions,
      },
    },
  };
}

Map<String, Object?> _minimalVrmaJson() {
  final json = _minimalVrmJson();
  final nodes = [
    ...(json['nodes']! as List<Object?>),
    {'name': 'sourceLeftEye'},
  ];
  return {
    'asset': {'version': '2.0'},
    'extensionsUsed': ['VRMC_vrm_animation'],
    'nodes': nodes,
    'accessors': [
      {
        'count': 1,
        'componentType': 5126,
        'type': 'SCALAR',
        'min': [0.0],
        'max': [0.0],
      },
      {'count': 1, 'componentType': 5126, 'type': 'VEC3'},
    ],
    'animations': [
      {
        'channels': [
          {
            'sampler': 0,
            'target': {'node': 15, 'path': 'scale'},
          },
        ],
        'samplers': [
          {'input': 0, 'output': 1},
        ],
      },
    ],
    'extensions': {
      'VRMC_vrm_animation': {
        'specVersion': '1.0',
        'humanoid': {
          'humanBones': {
            for (final entry in _boneNodes.entries)
              entry.key.specName: {'node': entry.value},
            'leftEye': {'node': 15},
          },
        },
      },
    },
  };
}

List<Map<String, Object?>> _nodes(Map<int, int> nodeMesh) {
  final nodes = <Map<String, Object?>>[];
  for (var i = 0; i < _nodeChildren.length; i++) {
    final node = <String, Object?>{'name': 'node$i'};
    if (_nodeChildren[i].isNotEmpty) node['children'] = _nodeChildren[i];
    final mesh = nodeMesh[i];
    if (mesh != null) node['mesh'] = mesh;
    nodes.add(node);
  }
  return nodes;
}

const _nodeChildren = <List<int>>[
  [1, 3, 6],
  [2, 9, 12],
  [],
  [4],
  [5],
  [],
  [7],
  [8],
  [],
  [10],
  [11],
  [],
  [13],
  [14],
  [],
];

const _boneNodes = <VrmHumanoidBone, int>{
  VrmHumanoidBone.hips: 0,
  VrmHumanoidBone.spine: 1,
  VrmHumanoidBone.head: 2,
  VrmHumanoidBone.leftUpperLeg: 3,
  VrmHumanoidBone.leftLowerLeg: 4,
  VrmHumanoidBone.leftFoot: 5,
  VrmHumanoidBone.rightUpperLeg: 6,
  VrmHumanoidBone.rightLowerLeg: 7,
  VrmHumanoidBone.rightFoot: 8,
  VrmHumanoidBone.leftUpperArm: 9,
  VrmHumanoidBone.leftLowerArm: 10,
  VrmHumanoidBone.leftHand: 11,
  VrmHumanoidBone.rightUpperArm: 12,
  VrmHumanoidBone.rightLowerArm: 13,
  VrmHumanoidBone.rightHand: 14,
};

final class _FakeBinding implements VrmModelRootBinding {
  final nodes = <int, _FakeNode>{};
  final meshes = <int, _FakeMesh>{};
  final materials = <int, _FakeMaterial>{};
  var began = 0;
  var committed = 0;
  var nodeLookups = 0;

  @override
  VrmMatrix4 modelRootMotionTransform = VrmMatrix4.identity();

  @override
  void beginFrame() {
    began++;
  }

  @override
  void commitFrame() {
    committed++;
  }

  @override
  VrmMaterialBinding materialByGltfIndex(int materialIndex) =>
      materials.putIfAbsent(materialIndex, _FakeMaterial.new);

  @override
  VrmMeshBinding? meshByNodeIndex(int nodeIndex) =>
      meshes.putIfAbsent(nodeIndex, _FakeMesh.new);

  @override
  VrmNodeBinding nodeByGltfIndex(int nodeIndex) {
    nodeLookups++;
    return nodes.putIfAbsent(nodeIndex, _FakeNode.new);
  }
}

final class _FakeNode implements VrmNodeBinding {
  @override
  String? debugName;

  @override
  VrmMatrix4 localTransform = VrmMatrix4.identity();

  @override
  VrmMatrix4 worldTransform = VrmMatrix4.identity();
}

final class _FakeMesh implements VrmMeshBinding {
  final weights = <String, double>{};
  var visible = true;

  @override
  void setMorphWeight({
    required int primitiveIndex,
    required int morphIndex,
    required double weight,
  }) {
    weights['$primitiveIndex:$morphIndex'] = weight;
  }

  @override
  void setVisible(bool visible) {
    this.visible = visible;
  }
}

final class _FakeMaterial implements VrmMaterialBinding {
  final colors = <String, VrmVector4>{};
  VrmVector2? scale;
  VrmVector2? offset;

  @override
  void setColor(String parameter, VrmVector4 value) {
    colors[parameter] = value;
  }

  @override
  void setTextureTransform({
    required VrmVector2 scale,
    required VrmVector2 offset,
  }) {
    this.scale = scale;
    this.offset = offset;
  }
}
