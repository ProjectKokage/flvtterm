import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flvtterm/flvtterm.dart';
import 'package:flvtterm_flutter_scene/src/flutter_scene_resolved_import.dart';

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
