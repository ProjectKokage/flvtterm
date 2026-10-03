part of '../flvtterm_test.dart';

void gltfBufferTests() {
  test('reads raw bufferView bytes from data URI buffers', () {
    final data = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
    final asset = GltfAsset.parse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'buffers': [
              {
                'byteLength': data.length,
                'uri':
                    'data:application/octet-stream;base64,${base64.encode(data)}',
              },
            ],
            'bufferViews': [
              {'buffer': 0, 'byteOffset': 2, 'byteLength': 3},
            ],
          }),
        ),
      ),
    );

    expect(asset.readBufferViewBytes(0), [3, 4, 5]);
    expect(asset.readBufferViewBytes(1), isNull);
  });

  test('negative bufferView lengths stay diagnostic in permissive mode', () {
    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'buffers': [
              {
                'byteLength': 1,
                'uri': 'data:application/octet-stream;base64,AA==',
              },
            ],
            'bufferViews': [
              {'buffer': 0, 'byteLength': -1},
            ],
            'images': [
              {'bufferView': 0, 'mimeType': 'image/png'},
            ],
          }),
        ),
      ),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((diagnostic) => diagnostic.code),
      contains('gltf.invalidBufferViewRange'),
    );
    expect(result.asset!.images.single.data, isNull);
    expect(result.asset!.readBufferViewBytes(0), isNull);
  });

  test('reads raw bufferView bytes from GLB BIN chunks', () {
    final data = Uint8List.fromList([10, 11, 12, 13, 14, 15, 16, 17]);
    final asset = GltfAsset.parse(
      bytes: _glb({
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': data.length},
        ],
        'bufferViews': [
          {'buffer': 0, 'byteOffset': 1, 'byteLength': 4},
        ],
      }, binaryChunk: data),
    );

    expect(asset.readBufferViewBytes(0), [11, 12, 13, 14]);
  });

  test('parsed public byte buffers are immutable', () {
    final pngBytes = Uint8List.fromList([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);
    final asset = GltfAsset.parse(
      bytes: _glb({
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': pngBytes.length},
        ],
        'bufferViews': [
          {'buffer': 0, 'byteOffset': 1, 'byteLength': 4},
          {'buffer': 0, 'byteLength': pngBytes.length},
        ],
        'images': [
          {'bufferView': 1, 'mimeType': 'image/png'},
        ],
      }, binaryChunk: pngBytes),
    );
    final binaryChunk = asset.binaryChunk!;
    final bufferData = asset.buffers.single.data!;
    final viewBytes = asset.readBufferViewBytes(0)!;
    final imageData = asset.images.single.data!;

    expect(() => binaryChunk[0] = 0, throwsUnsupportedError);
    expect(() => bufferData[0] = 0, throwsUnsupportedError);
    expect(() => viewBytes[0] = 0, throwsUnsupportedError);
    expect(() => imageData[0] = 0, throwsUnsupportedError);
  });

  test('parsed bytes do not follow later changes to the caller bytes', () {
    const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    final binary = Uint8List.fromList([1, 2, 3, 4, ...png]);
    final source = _glb({
      'asset': {'version': '2.0'},
      'buffers': [
        {'byteLength': binary.length},
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 4, 'byteLength': png.length},
      ],
      'images': [
        {'bufferView': 0, 'mimeType': 'image/png'},
      ],
    }, binaryChunk: binary);
    final asset = GltfAsset.parse(bytes: source);

    source.fillRange(0, source.length, 0xff);

    expect(asset.binaryChunk, [1, 2, 3, 4, ...png]);
    expect(asset.buffers.single.data, [1, 2, 3, 4, ...png]);
    expect(asset.readBufferViewBytes(0), png);
    expect(asset.images.single.data, png);
  });

  test('parsed bytes do not follow later changes to resolver bytes', () {
    final resolved = Uint8List.fromList([9, 8, 7, 6]);
    final asset = GltfAsset.parse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'buffers': [
              {'uri': 'data.bin', 'byteLength': resolved.length},
            ],
            'images': [
              {'uri': 'image.png'},
            ],
          }),
        ),
      ),
      uriResolver: (_) => resolved,
    );

    resolved.fillRange(0, resolved.length, 0);

    expect(asset.buffers.single.data, [9, 8, 7, 6]);
    expect(asset.images.single.data, [9, 8, 7, 6]);
    expect(() => asset.buffers.single.data![0] = 0, throwsUnsupportedError);
    expect(() => asset.images.single.data![0] = 0, throwsUnsupportedError);
  });

  test('a GLB keeps one copy of its binary chunk', () {
    const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    final binary = Uint8List.fromList([1, 2, 3, 4, ...png]);
    final asset = GltfAsset.parse(
      bytes: _glb({
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': binary.length},
        ],
        'bufferViews': [
          {'buffer': 0, 'byteOffset': 4, 'byteLength': png.length},
        ],
        'images': [
          {'bufferView': 0, 'mimeType': 'image/png'},
        ],
      }, binaryChunk: binary),
    );
    final chunk = asset.binaryChunk!;

    // The buffer and the embedded image are views into the chunk's memory,
    // at their own offsets, instead of separate copies.
    expect(asset.buffers.single.data!.offsetInBytes, chunk.offsetInBytes);
    expect(asset.images.single.data!.offsetInBytes, chunk.offsetInBytes + 4);
    expect(asset.images.single.data, png);
  });

  test('does not expose GLB BIN padding as buffer data', () {
    final data = Uint8List.fromList([1, 2, 3]);
    final result = GltfAsset.tryParse(
      bytes: _glb({
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': data.length},
        ],
        'bufferViews': [
          {'buffer': 0, 'byteOffset': 1, 'byteLength': 2},
          {'buffer': 0, 'byteOffset': 3, 'byteLength': 1},
        ],
      }, binaryChunk: data),
      validation: VrmValidationMode.permissive,
    );

    final asset = result.asset!;
    expect(asset.binaryChunk, [1, 2, 3, 0]);
    expect(asset.buffers.single.data, [1, 2, 3]);
    expect(asset.readBufferViewBytes(0), [2, 3]);
    expect(asset.readBufferViewBytes(1), isNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.bufferViewOutOfRange'),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      contains(r'$.bufferViews[1].byteLength'),
    );
  });

  test('reports GLB buffer 0 URI when BIN chunk is present', () {
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {'byteLength': 1, 'uri': 'data:application/octet-stream;base64,AA=='},
      ],
    };
    final bytes = _glb(json, binaryChunk: Uint8List(1));

    final strict = GltfAsset.tryParse(bytes: bytes);
    final permissive = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(strict.asset, isNull);
    expect(permissive.asset, isNotNull);
    expect(
      strict.validation.errors.map((d) => d.code),
      contains('gltf.invalidGlbBufferUri'),
    );
  });

  test('reports GLB BIN chunks with more than 3 bytes of padding', () {
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {'byteLength': 1},
      ],
    };

    final result = GltfAsset.tryParse(
      bytes: _glb(json, binaryChunk: Uint8List(8)),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidGlbBinChunkLength'),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      contains(r'$.buffers[0].byteLength'),
    );
  });

  test('reports nonzero GLB BIN chunk padding bytes', () {
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {'byteLength': 5},
      ],
    };
    final binary = Uint8List.fromList([1, 2, 3, 4, 5, 9, 0, 0]);

    final result = GltfAsset.tryParse(
      bytes: _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidGlbBinChunkPadding'),
    );
  });

  test('reports zero buffer and bufferView byte lengths', () {
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {'byteLength': 0, 'uri': 'data:application/octet-stream;base64,'},
        {
          'byteLength': 1,
          'uri':
              'data:application/octet-stream;base64,${base64.encode(Uint8List(1))}',
        },
      ],
      'bufferViews': [
        {'buffer': 1, 'byteOffset': 0, 'byteLength': 0},
      ],
    };

    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'gltf.invalidBufferByteLength',
        'gltf.invalidBufferViewRange',
      ]),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      containsAll([r'$.buffers[0].byteLength', r'$.bufferViews[0]']),
    );
  });

  test('reports mixed bufferView data kinds', () {
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': 16,
          'uri':
              'data:application/octet-stream;base64,${base64.encode(Uint8List(16))}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 16},
      ],
      'accessors': [
        {'bufferView': 0, 'componentType': 5123, 'count': 1, 'type': 'SCALAR'},
        {
          'bufferView': 0,
          'componentType': 5126,
          'count': 1,
          'type': 'VEC3',
          'min': [0.0, 0.0, 0.0],
          'max': [0.0, 0.0, 0.0],
        },
      ],
      'meshes': [
        {
          'primitives': [
            {
              'indices': 0,
              'attributes': {'POSITION': 1},
            },
          ],
        },
      ],
    };

    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.mixedBufferViewData'),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      contains(r'$.bufferViews[0]'),
    );
  });
}
