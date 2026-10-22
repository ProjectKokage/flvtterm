import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flvtterm/flvtterm.dart';
import 'package:flvtterm_flutter_scene/src/flutter_scene_skin_reduction.dart'
    show remapJointSlots;
import 'package:flvtterm_flutter_scene/vrm_flutter_scene.dart';

void main() {
  test('leaves skins as authored without a palette capacity', () {
    final gltf = GltfAsset.parse(
      bytes: _skinnedGlb(),
      validation: VrmValidationMode.permissive,
    );

    expect(FlutterSceneResolvedImport.fromGltf(gltf), isNull);
  });

  test('keeps skins that fit the palette', () {
    final gltf = GltfAsset.parse(
      bytes: _skinnedGlb(),
      validation: VrmValidationMode.permissive,
    );

    expect(
      FlutterSceneResolvedImport.fromGltf(gltf, jointPaletteCapacity: 4),
      isNull,
    );
  });

  test('reduces an oversized skin to the joints its mesh weights', () async {
    final gltf = GltfAsset.parse(
      bytes: _skinnedGlb(),
      validation: VrmValidationMode.permissive,
    );

    final resolved = FlutterSceneResolvedImport.fromGltf(
      gltf,
      jointPaletteCapacity: 2,
    )!;

    expect(resolved.skinReduction!.jointSlotRemapsByNode, {
      0: [-1, 0, -1, 1],
    });
    expect(resolved.skinReduction!.remapForNode(1), isNull);
    final rendererJson =
        jsonDecode(utf8.decode(resolved.gltfJson)) as Map<String, Object?>;
    final skins = rendererJson['skins'] as List;
    expect(skins, hasLength(1));
    expect((skins.single as Map)['joints'], [2, 4]);
    expect((skins.single as Map)['name'], 'authored');
    expect(((rendererJson['nodes'] as List)[0] as Map)['skin'], 0);
    expect(gltf.skins.single.joints, [1, 2, 3, 4], reason: 'core is unchanged');
    expect(gltf.json['skins'], [
      {
        'name': 'authored',
        'joints': [1, 2, 3, 4],
        'inverseBindMatrices': 2,
      },
    ]);

    // Read the rewritten data back through core parsing of the renderer JSON.
    final resources = <String, Uint8List>{};
    for (final buffer in rendererJson['buffers'] as List) {
      final uri = (buffer as Map)['uri'] as String;
      resources[uri] = await resolved.resolveUri(uri);
    }
    final renderer = GltfAsset.parse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(rendererJson))),
      validation: VrmValidationMode.permissive,
      uriResolver: (uri) => resources[uri],
    );
    final skin = renderer.skins.single;
    expect(
      renderer.readAccessorNumbers(
        skin.inverseBindMatrices!,
        requireFloat: true,
      ),
      [...List.filled(16, 2.0), ...List.filled(16, 4.0)],
    );
    final primitive = renderer.meshes.first.primitives.single;
    expect(
      renderer.readAccessorNumbers(
        primitive.attributes['JOINTS_0']!,
        applyNormalization: false,
      ),
      [1, 0, 0, 0, 0, 0, 0, 0],
      reason: 'weighted slots follow the subset; zero-weight slots reset to 0',
    );
    expect(renderer.readAccessorNumbers(primitive.attributes['WEIGHTS_0']!), [
      0.5,
      0.5,
      0,
      0,
      1,
      0,
      0,
      0,
    ]);
    expect(
      renderer.accessors[primitive.attributes['JOINTS_0']!].componentType,
      5121,
    );
  });

  test(
    'gives nodes sharing one mesh under different skins their own copies',
    () {
      final gltf = GltfAsset.parse(
        bytes: _skinnedGlb(secondNodeSkinJoints: [1, 2, 3, 4, 5]),
        validation: VrmValidationMode.permissive,
      );

      final resolved = FlutterSceneResolvedImport.fromGltf(
        gltf,
        jointPaletteCapacity: 2,
      )!;

      expect(resolved.skinReduction!.jointSlotRemapsByNode, {
        0: [-1, 0, -1, 1],
        6: [-1, 0, -1, 1, -1],
      });
      final rendererJson =
          jsonDecode(utf8.decode(resolved.gltfJson)) as Map<String, Object?>;
      final nodes = rendererJson['nodes'] as List;
      final skins = rendererJson['skins'] as List;
      final meshes = rendererJson['meshes'] as List;
      expect(skins, hasLength(2));
      expect((skins[0] as Map)['joints'], [2, 4]);
      expect((skins[1] as Map)['joints'], [2, 4]);
      expect(
        meshes,
        hasLength(3),
        reason: 'the second node needs its own JOINTS_0',
      );
      expect((nodes[0] as Map)['mesh'], 0);
      expect((nodes[6] as Map)['mesh'], 2);
      expect((nodes[6] as Map)['skin'], 1);
      final firstJoints =
          (((meshes[0] as Map)['primitives'] as List).single
              as Map)['attributes'];
      final secondJoints =
          (((meshes[2] as Map)['primitives'] as List).single
              as Map)['attributes'];
      expect(
        (firstJoints as Map)['JOINTS_0'],
        isNot((secondJoints as Map)['JOINTS_0']),
      );
      expect(gltf.meshes, hasLength(2), reason: 'core is unchanged');
    },
  );

  test(
    'shares one reduced skin and mesh between nodes with the same subset',
    () {
      final gltf = GltfAsset.parse(
        bytes: _skinnedGlb(secondNodeSkinJoints: [1, 2, 3, 4]),
        validation: VrmValidationMode.permissive,
      );

      final resolved = FlutterSceneResolvedImport.fromGltf(
        gltf,
        jointPaletteCapacity: 2,
      )!;

      final rendererJson =
          jsonDecode(utf8.decode(resolved.gltfJson)) as Map<String, Object?>;
      expect(rendererJson['skins'], hasLength(2));
      expect(rendererJson['meshes'], hasLength(2));
      expect(((rendererJson['nodes'] as List)[6] as Map)['skin'], 1);
      expect(((rendererJson['nodes'] as List)[6] as Map)['mesh'], 0);
    },
  );

  test('keeps a skin whose mesh weights more joints than the palette', () {
    final gltf = GltfAsset.parse(
      bytes: _skinnedGlb(),
      validation: VrmValidationMode.permissive,
    );

    final resolved = FlutterSceneResolvedImport.fromGltf(
      gltf,
      jointPaletteCapacity: 1,
    );

    expect(resolved?.skinReduction, isNull);
    if (resolved != null) {
      final rendererJson =
          jsonDecode(utf8.decode(resolved.gltfJson)) as Map<String, Object?>;
      expect(rendererJson['skins'], gltf.json['skins']);
      expect(rendererJson['meshes'], gltf.json['meshes']);
    }
  });

  test('keeps a skin when any of its mesh nodes cannot be reduced', () {
    // The second node weights every joint; the first could be reduced alone.
    final gltf = GltfAsset.parse(
      bytes: _skinnedGlb(secondNodeSkinJoints: [1, 2, 3, 4], secondNodeMesh: 1),
      validation: VrmValidationMode.permissive,
    );

    final resolved = FlutterSceneResolvedImport.fromGltf(
      gltf,
      jointPaletteCapacity: 3,
    )!;

    expect(resolved.skinReduction!.jointSlotRemapsByNode.keys, [0]);
    final rendererJson =
        jsonDecode(utf8.decode(resolved.gltfJson)) as Map<String, Object?>;
    final skins = rendererJson['skins'] as List;
    expect((skins[0] as Map)['joints'], [2, 4]);
    expect((skins[1] as Map)['joints'], [1, 2, 3, 4], reason: 'authored');
  });

  test('remaps joint slots through the reduced subset', () {
    expect(
      remapJointSlots([3, 1, 2, 0, 1, 1, 0, 0], [0.5, 0.5, 0, 0, 1, 0, 0, 0], [
        -1,
        0,
        -1,
        1,
      ]),
      [1, 0, 0, 0, 0, 0, 0, 0],
    );
  });
}

/// Node 0 draws mesh 0 under skin 0 (joints at nodes 1-4). The mesh weights
/// joint slots 3 and 1 only. With [secondNodeSkinJoints], node 6 draws the
/// same mesh (or mesh 1, which weights every slot) under skin 1.
Uint8List _skinnedGlb({
  List<int>? secondNodeSkinJoints,
  int secondNodeMesh = 0,
}) {
  final joints = Uint8List.fromList([3, 1, 2, 0, 1, 1, 0, 0]);
  final allJoints = Uint8List.fromList([0, 1, 2, 3, 0, 1, 2, 3]);
  final weights = Float32List.fromList([0.5, 0.5, 0, 0, 1, 0, 0, 0]);
  final allWeights = Float32List.fromList([
    0.25,
    0.25,
    0.25,
    0.25,
    0.25,
    0.25,
    0.25,
    0.25,
  ]);
  final positions = Float32List.fromList([0, 0, 0, 1, 0, 0]);
  final matrices = Float32List(4 * 16);
  for (var slot = 0; slot < 4; slot++) {
    for (var component = 0; component < 16; component++) {
      matrices[slot * 16 + component] = slot + 1;
    }
  }
  final secondMatrices = Float32List(5 * 16);
  final binary = BytesBuilder()
    ..add(joints) // 0..8
    ..add(weights.buffer.asUint8List()) // 8..40
    ..add(matrices.buffer.asUint8List()) // 40..296
    ..add(positions.buffer.asUint8List()) // 296..320
    ..add(allJoints) // 320..328
    ..add(allWeights.buffer.asUint8List()) // 328..360
    ..add(secondMatrices.buffer.asUint8List()); // 360..680
  final json = <String, Object?>{
    'asset': {'version': '2.0'},
    'scene': 0,
    'scenes': [
      {
        'nodes': [0, if (secondNodeSkinJoints != null) 6],
      },
    ],
    'nodes': [
      {
        'mesh': 0,
        'skin': 0,
        'children': [1],
      },
      {
        'children': [2],
      },
      {
        'children': [3],
      },
      {
        'children': [4],
      },
      {
        'children': [5],
      },
      <String, Object?>{},
      if (secondNodeSkinJoints != null) {'mesh': secondNodeMesh, 'skin': 1},
    ],
    'meshes': [
      {
        'primitives': [
          {
            'attributes': {'POSITION': 3, 'JOINTS_0': 0, 'WEIGHTS_0': 1},
          },
        ],
      },
      {
        'primitives': [
          {
            'attributes': {'POSITION': 3, 'JOINTS_0': 4, 'WEIGHTS_0': 5},
          },
        ],
      },
    ],
    'skins': [
      {
        'name': 'authored',
        'joints': [1, 2, 3, 4],
        'inverseBindMatrices': 2,
      },
      if (secondNodeSkinJoints != null)
        {
          'joints': secondNodeSkinJoints,
          if (secondNodeSkinJoints.length == 5) 'inverseBindMatrices': 6,
        },
    ],
    'buffers': [
      {'byteLength': binary.length},
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 8},
      {'buffer': 0, 'byteOffset': 8, 'byteLength': 32},
      {'buffer': 0, 'byteOffset': 40, 'byteLength': 256},
      {'buffer': 0, 'byteOffset': 296, 'byteLength': 24},
      {'buffer': 0, 'byteOffset': 320, 'byteLength': 8},
      {'buffer': 0, 'byteOffset': 328, 'byteLength': 32},
      {'buffer': 0, 'byteOffset': 360, 'byteLength': 320},
    ],
    'accessors': [
      {'bufferView': 0, 'componentType': 5121, 'count': 2, 'type': 'VEC4'},
      {'bufferView': 1, 'componentType': 5126, 'count': 2, 'type': 'VEC4'},
      {'bufferView': 2, 'componentType': 5126, 'count': 4, 'type': 'MAT4'},
      {
        'bufferView': 3,
        'componentType': 5126,
        'count': 2,
        'type': 'VEC3',
        'min': [0, 0, 0],
        'max': [1, 0, 0],
      },
      {'bufferView': 4, 'componentType': 5121, 'count': 2, 'type': 'VEC4'},
      {'bufferView': 5, 'componentType': 5126, 'count': 2, 'type': 'VEC4'},
      {'bufferView': 6, 'componentType': 5126, 'count': 5, 'type': 'MAT4'},
    ],
  };
  return _glb(json, binary: binary.toBytes());
}

Uint8List _glb(Map<String, Object?> json, {Uint8List? binary}) {
  final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));
  final jsonLength = (jsonBytes.length + 3) & ~3;
  final binaryLength = binary == null ? 0 : (binary.length + 3) & ~3;
  final bytes = Uint8List(
    20 + jsonLength + (binary == null ? 0 : 8 + binaryLength),
  );
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, 0x46546c67, Endian.little);
  data.setUint32(4, 2, Endian.little);
  data.setUint32(8, bytes.length, Endian.little);
  data.setUint32(12, jsonLength, Endian.little);
  data.setUint32(16, 0x4e4f534a, Endian.little);
  bytes.setRange(20, 20 + jsonBytes.length, jsonBytes);
  for (var index = 20 + jsonBytes.length; index < 20 + jsonLength; index++) {
    bytes[index] = 0x20;
  }
  if (binary != null) {
    final header = 20 + jsonLength;
    data.setUint32(header, binaryLength, Endian.little);
    data.setUint32(header + 4, 0x004e4942, Endian.little);
    bytes.setRange(header + 8, header + 8 + binary.length, binary);
  }
  return bytes;
}
