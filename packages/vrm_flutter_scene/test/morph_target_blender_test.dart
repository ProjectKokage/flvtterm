import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flvtterm/flvtterm.dart';
import 'package:flvtterm_flutter_scene/src/morph_target_blender.dart';

void main() {
  test('batches target weights into one non-accumulating skinned blend', () {
    final base = Float32List.fromList([
      // position, normal, uv, color, joints, skin weights
      1, 2, 3, 0, 0, 1, 0.25, 0.75, 1, 0.5, 0.25, 1, 0, 1, 2, 3, 1, 0, 0, 0,
      4, 5, 6, 0, 1, 0, 0.5, 0.5, 0.5, 1, 0.25, 1, 3, 2, 1, 0, 0, 1, 0, 0,
    ]);
    final data = MorphTargetPrimitiveData(
      vertexCount: 2,
      strideFloats: 20,
      isSkinned: true,
      baseVertices: base,
      positionDeltas: [
        Float32List.fromList([2, 0, 0, 0, 4, 0]),
        Float32List.fromList([0, 0, -4, -2, 0, 0]),
      ],
      normalDeltas: [
        Float32List.fromList([0, 2, 0, 0, 0, 0]),
        null,
      ],
    );
    final blender = MorphTargetBlender(data);

    expect(blender.setWeight(0, 0.5), isTrue);
    expect(blender.setWeight(0, 0.25), isTrue);
    expect(blender.setWeight(1, 0.5), isTrue);
    expect(blender.commit(), isTrue);
    expect(blender.revision, 1);

    expect(blender.workingVertices[0], closeTo(1.5, 0.000001));
    expect(blender.workingVertices[1], closeTo(2, 0.000001));
    expect(blender.workingVertices[2], closeTo(1, 0.000001));
    expect(blender.workingVertices[20], closeTo(3, 0.000001));
    expect(blender.workingVertices[21], closeTo(6, 0.000001));
    expect(blender.workingVertices[22], closeTo(6, 0.000001));
    expect(blender.workingVertices[3], closeTo(0, 0.000001));
    expect(
      blender.workingVertices[4],
      closeTo(0.5 / math.sqrt(1.25), 0.000001),
    );
    expect(blender.workingVertices[5], closeTo(1 / math.sqrt(1.25), 0.000001));
    for (final offset in [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]) {
      expect(
        blender.workingVertices[offset],
        base[offset],
        reason: 'Non-morph vertex field $offset changed.',
      );
    }

    expect(blender.commit(), isFalse);
    expect(blender.revision, 1);

    expect(blender.setWeight(0, 0), isTrue);
    expect(blender.setWeight(1, 0), isTrue);
    expect(blender.commit(), isTrue);
    expect(blender.revision, 2);
    expect(blender.workingVertices, orderedEquals(base));
  });

  test('rejects invalid writes and preserves exact base for zero deltas', () {
    final base = Float32List.fromList([
      0,
      0,
      0,
      0.25,
      0.5,
      0.75,
      0,
      0,
      1,
      1,
      1,
      1,
    ]);
    final blender = MorphTargetBlender(
      MorphTargetPrimitiveData(
        vertexCount: 1,
        strideFloats: 12,
        isSkinned: false,
        baseVertices: base,
        positionDeltas: [Float32List(3)],
        normalDeltas: [Float32List(3)],
      ),
    );

    expect(blender.setWeight(-1, 1), isFalse);
    expect(blender.setWeight(1, 1), isFalse);
    expect(blender.setWeight(0, double.nan), isFalse);
    expect(blender.setWeight(0, double.infinity), isFalse);
    expect(blender.setWeight(0, 0.75), isTrue);
    expect(blender.commit(), isTrue);
    expect(blender.workingVertices, orderedEquals(base));
  });

  test('rejects tangent morphs that Flutter Scene cannot represent', () {
    final gltf = _gltfWithTangentMorph();
    final result = MorphTargetDataFactory(
      gltf,
    ).build(gltf.meshes.single.primitives.single);

    expect(result.data, isNull);
    expect(result.failure, contains('TANGENT'));
  });
}

GltfAsset _gltfWithTangentMorph() {
  final data = ByteData(36);
  const values = <double>[0, 0, 0, 0, 0, 1, 1, 0, 0];
  for (var index = 0; index < values.length; index++) {
    data.setFloat32(index * 4, values[index], Endian.little);
  }
  final uri =
      'data:application/octet-stream;base64,'
      '${base64Encode(data.buffer.asUint8List())}';
  final json = <String, Object?>{
    'asset': {'version': '2.0'},
    'buffers': [
      {'byteLength': data.lengthInBytes, 'uri': uri},
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 12},
      {'buffer': 0, 'byteOffset': 12, 'byteLength': 12},
      {'buffer': 0, 'byteOffset': 24, 'byteLength': 12},
    ],
    'accessors': [
      {
        'bufferView': 0,
        'componentType': 5126,
        'count': 1,
        'type': 'VEC3',
        'min': [0, 0, 0],
        'max': [0, 0, 0],
      },
      {'bufferView': 1, 'componentType': 5126, 'count': 1, 'type': 'VEC3'},
      {'bufferView': 2, 'componentType': 5126, 'count': 1, 'type': 'VEC3'},
    ],
    'meshes': [
      {
        'primitives': [
          {
            'attributes': {'POSITION': 0, 'NORMAL': 1},
            'targets': [
              {'TANGENT': 2},
            ],
          },
        ],
      },
    ],
  };
  return GltfAsset.parse(
    bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
    validation: VrmValidationMode.permissive,
  );
}
