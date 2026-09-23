import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/scene.dart' as scene;
import 'package:flutter_scene/src/importer/gltf.dart' as importer;
import 'package:flvtterm/flvtterm.dart';
import 'package:flvtterm_flutter_scene/vrm_flutter_scene.dart';

void main() {
  test('keeps self-contained GLBs on the direct renderer path', () {
    final gltf = GltfAsset.parse(
      bytes: _glb({
        'asset': {'version': '2.0'},
        'images': [
          {
            'uri':
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          },
        ],
      }),
    );

    expect(FlutterSceneResolvedImport.fromGltf(gltf), isNull);
  });

  test(
    'passes VRM-owned required extensions to core and preserves unknown ones',
    () {
      final gltf = GltfAsset.parse(
        bytes: _glb({
          'asset': {'version': '2.0'},
          'extensionsUsed': ['VRMC_vrm', 'EXAMPLE_unknown'],
          'extensionsRequired': ['VRMC_vrm', 'EXAMPLE_unknown'],
          'extensions': {
            'VRMC_vrm': {'specVersion': '1.0'},
          },
        }),
        validation: VrmValidationMode.permissive,
      );
      final resolved = FlutterSceneResolvedImport.fromGltf(gltf)!;
      final rendererJson = jsonDecode(utf8.decode(resolved.gltfJson)) as Map;
      expect(rendererJson['extensionsRequired'], ['EXAMPLE_unknown']);
      expect((rendererJson['extensions'] as Map)['VRMC_vrm'], {
        'specVersion': '1.0',
      });
      expect(gltf.extensionsRequired, ['VRMC_vrm', 'EXAMPLE_unknown']);
    },
  );

  test(
    'replays each resolved buffer without aliasing its synthetic URI',
    () async {
      final payloads = {
        'first.bin': Uint8List.fromList([1, 2, 3, 4]),
        'second.bin': Uint8List.fromList([5, 6, 7, 8]),
      };
      final gltf = GltfAsset.parse(
        bytes: _glb({
          'asset': {'version': '2.0'},
          'buffers': [
            for (final uri in payloads.keys) {'uri': uri, 'byteLength': 4},
          ],
        }),
        uriResolver: (uri) => payloads[uri],
      );
      final resolved = FlutterSceneResolvedImport.fromGltf(gltf)!;
      final rendererJson = jsonDecode(utf8.decode(resolved.gltfJson)) as Map;
      final uris = (rendererJson['buffers'] as List)
          .map((buffer) => (buffer as Map)['uri'] as String)
          .toList();
      expect(uris.toSet(), hasLength(2));
      expect(await resolved.resolveUri(uris[0]), payloads['first.bin']);
      expect(await resolved.resolveUri(uris[1]), payloads['second.bin']);
    },
  );

  test(
    'optional compression uses the exact validated ordinary geometry',
    () async {
      final original = _compressedFallback();
      final gltf = GltfAsset.parse(bytes: _glb(original, binary: _positions));
      final resolved = FlutterSceneResolvedImport.fromGltf(gltf)!;
      final rendererJson =
          jsonDecode(utf8.decode(resolved.gltfJson)) as Map<String, Object?>;
      final buffers = rendererJson['buffers'] as List;
      final bytes = await resolved.resolveUri(
        (buffers.single as Map)['uri'] as String,
      );
      expect(bytes, _positions);
      expect(rendererJson['accessors'], original['accessors']);
      expect(rendererJson['extensionsUsed'], ['EXAMPLE_metadata']);
      expect((buffers.single as Map)['extensions'], {
        'EXAMPLE_metadata': {'kept': true},
      });
      expect(
        ((rendererJson['bufferViews'] as List).single as Map)['extensions'],
        isEmpty,
      );
      expect(
        (((rendererJson['meshes'] as List).single as Map)['primitives'] as List)
            .single,
        {
          'attributes': {'POSITION': 0},
          'extensions': {
            'EXAMPLE_metadata': {'kept': true},
          },
        },
      );
      expect(gltf.json, original, reason: 'The core model remains immutable.');

      final document = importer.parseGltfJson(rendererJson);
      final decoded = importer.decodeMeshoptBufferViews(document, bytes);
      final packed = importer.packGltfPrimitive(
        primitive: decoded.doc.meshes.single.primitives.single,
        accessors: decoded.doc.accessors,
        bufferViews: decoded.doc.bufferViews,
        bufferData: decoded.bufferData,
        coordinatePolicy: importer.GltfCoordinatePolicy.runtimeBoundary,
      );
      expect(packed.vertexCount, 3);
      final vertices = ByteData.sublistView(packed.vertexBytes);
      for (var vertex = 0; vertex < 3; vertex++) {
        for (var axis = 0; axis < 3; axis++) {
          expect(
            vertices.getFloat32(vertex * 72 + axis * 4, Endian.little),
            ByteData.sublistView(
              _positions,
            ).getFloat32((vertex * 3 + axis) * 4, Endian.little),
          );
        }
      }
    },
  );

  for (final extension in [
    'KHR_draco_mesh_compression',
    'EXT_meshopt_compression',
  ]) {
    test('required $extension retains the existing core rejection', () {
      final json = _compressedFallback()..['extensionsRequired'] = [extension];
      final bytes = _glb(json, binary: _positions);
      final strict = GltfAsset.tryParse(bytes: bytes);
      expect(strict.asset, isNull);
      expect(
        strict.validation.errors.map((d) => d.code),
        contains('gltf.unsupportedRequiredExtension'),
      );
      final permissive = GltfAsset.parse(
        bytes: bytes,
        validation: VrmValidationMode.permissive,
      );
      expect(
        () => FlutterSceneResolvedImport.fromGltf(permissive),
        throwsA(
          isA<VrmInvalidAssetException>().having(
            (e) => e.validation.errors.map((d) => d.code),
            'diagnostics',
            contains('gltf.unsupportedRequiredExtension'),
          ),
        ),
      );
      expect(permissive.extensionsRequired, [extension]);
    });
  }

  test('required compression without ordinary buffer bytes stays rejected', () {
    final json = _compressedFallback()
      ..['extensionsRequired'] = ['EXT_meshopt_compression'];
    final bytes = _glb(json);
    final strict = GltfAsset.tryParse(bytes: bytes);
    expect(strict.asset, isNull);
    expect(
      strict.validation.errors.map((d) => d.code),
      contains('gltf.unsupportedRequiredExtension'),
    );
    final permissive = GltfAsset.parse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );
    expect(
      () => FlutterSceneResolvedImport.fromGltf(permissive),
      throwsStateError,
    );
    expect(permissive.extensionsRequired, ['EXT_meshopt_compression']);
  });

  test('optional compression cannot normalize malformed fallback data', () {
    final json = _compressedFallback();
    ((json['bufferViews'] as List).single as Map)['byteLength'] =
        _positions.length + 4;
    final gltf = GltfAsset.parse(
      bytes: _glb(json, binary: _positions),
      validation: VrmValidationMode.permissive,
    );
    expect(
      () => FlutterSceneResolvedImport.fromGltf(gltf),
      throwsA(isA<VrmInvalidAssetException>()),
    );
  });

  test(
    'normalization leaves unknown required extensions for renderer rejection',
    () async {
      final json = _compressedFallback()
        ..['extensionsRequired'] = ['EXAMPLE_metadata'];
      final gltf = GltfAsset.parse(
        bytes: _glb(json, binary: _positions),
        validation: VrmValidationMode.permissive,
      );
      final resolved = FlutterSceneResolvedImport.fromGltf(gltf)!;
      await expectLater(
        scene.Node.fromGltfBytes(
          resolved.gltfJson,
          resolveUri: resolved.resolveUri,
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('replays core-resolved external buffers and images', () async {
    final bufferBytes = Uint8List.fromList([1, 2, 3, 4]);
    final imageBytes = Uint8List.fromList([5, 6, 7]);
    final gltf = GltfAsset.parse(
      bytes: _glb({
        'asset': {'version': '2.0'},
        'buffers': [
          {'uri': 'mesh.bin', 'byteLength': bufferBytes.length},
        ],
        'images': [
          {'uri': 'texture.png'},
        ],
      }),
      uriResolver: (uri) => switch (uri) {
        'mesh.bin' => bufferBytes,
        'texture.png' => imageBytes,
        _ => null,
      },
    );

    final resolved = FlutterSceneResolvedImport.fromGltf(gltf)!;
    final rendererJson = jsonDecode(utf8.decode(resolved.gltfJson)) as Map;
    final rendererBuffers = rendererJson['buffers'] as List;
    final syntheticBufferUri = (rendererBuffers.single as Map)['uri'] as String;

    expect(syntheticBufferUri, isNot('mesh.bin'));
    expect(await resolved.resolveUri(syntheticBufferUri), bufferBytes);
    expect(await resolved.resolveUri('texture.png'), imageBytes);
    await expectLater(
      resolved.resolveUri('missing.bin'),
      throwsA(isA<StateError>()),
    );
  });

  test('rewrites embedded GLB buffers when an image is external', () async {
    final bufferBytes = Uint8List.fromList([9, 8, 7, 6]);
    final imageBytes = Uint8List.fromList([5, 4, 3]);
    final gltf = GltfAsset.parse(
      bytes: _glb({
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': bufferBytes.length},
        ],
        'images': [
          {'uri': 'external.png'},
        ],
      }, binary: bufferBytes),
      uriResolver: (uri) => uri == 'external.png' ? imageBytes : null,
    );

    final resolved = FlutterSceneResolvedImport.fromGltf(gltf)!;
    final rendererJson = jsonDecode(utf8.decode(resolved.gltfJson)) as Map;
    final rendererBuffers = rendererJson['buffers'] as List;
    final syntheticBufferUri = (rendererBuffers.single as Map)['uri'] as String;

    expect(await resolved.resolveUri(syntheticBufferUri), bufferBytes);
    expect(await resolved.resolveUri('external.png'), imageBytes);
  });
}

final _positions = Float32List.fromList([
  -1,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  0,
]).buffer.asUint8List();

Map<String, Object?> _compressedFallback() => {
  'asset': {'version': '2.0'},
  'extensionsUsed': [
    'KHR_draco_mesh_compression',
    'EXT_meshopt_compression',
    'EXAMPLE_metadata',
  ],
  'buffers': [
    {
      'byteLength': _positions.length,
      'extensions': {
        'EXT_meshopt_compression': {'fallback': true},
        'EXAMPLE_metadata': {'kept': true},
      },
    },
  ],
  'bufferViews': [
    {
      'buffer': 0,
      'byteLength': _positions.length,
      'extensions': {
        'EXT_meshopt_compression': {
          'buffer': 0,
          'byteOffset': 0,
          'byteLength': 1,
          'count': 0x7fffffff,
          'byteStride': 12,
          'mode': 'ATTRIBUTES',
        },
      },
    },
  ],
  'accessors': [
    {
      'bufferView': 0,
      'componentType': 5126,
      'count': 3,
      'type': 'VEC3',
      'min': [-1, 0, 0],
      'max': [1, 1, 0],
    },
    // Legitimate zero-initialized accessors remain zero-initialized.
    {'componentType': 5126, 'count': 1, 'type': 'SCALAR'},
  ],
  'meshes': [
    {
      'primitives': [
        {
          'attributes': {'POSITION': 0},
          'extensions': {
            // Deliberately invalid compressed bytes; the accepted fallback wins.
            'KHR_draco_mesh_compression': {
              'bufferView': 0,
              'attributes': {'POSITION': 0},
            },
            'EXAMPLE_metadata': {'kept': true},
          },
        },
      ],
    },
  ],
};

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
