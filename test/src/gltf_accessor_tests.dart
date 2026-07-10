part of '../flvtterm_test.dart';

void gltfAccessorTests() {
  test('reads accessor numbers with optional normalization', () {
    final bytes = Uint8List.fromList([0, 127, 255]);
    final asset = GltfAsset.parse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'buffers': [
              {
                'byteLength': bytes.length,
                'uri':
                    'data:application/octet-stream;base64,${base64.encode(bytes)}',
              },
            ],
            'bufferViews': [
              {'buffer': 0, 'byteLength': bytes.length},
            ],
            'accessors': [
              {
                'bufferView': 0,
                'componentType': 5121,
                'count': 3,
                'type': 'SCALAR',
                'normalized': true,
              },
            ],
          }),
        ),
      ),
    );

    expect(asset.readAccessorNumbers(0), [0.0, 127 / 255, 1.0]);
    expect(asset.readAccessorNumbers(0, applyNormalization: false), [
      0.0,
      127.0,
      255.0,
    ]);
    expect(asset.readAccessorNumbers(99), isNull);
  });

  test('reads sparse accessor overrides', () {
    final bytes = Uint8List(12);
    bytes[0] = 1;
    final data = ByteData.sublistView(bytes);
    data.setFloat32(4, 2.0, Endian.little);
    data.setFloat32(8, 3.0, Endian.little);

    final asset = GltfAsset.parse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'buffers': [
              {
                'byteLength': bytes.length,
                'uri':
                    'data:application/octet-stream;base64,${base64.encode(bytes)}',
              },
            ],
            'bufferViews': [
              {'buffer': 0, 'byteOffset': 0, 'byteLength': 1},
              {'buffer': 0, 'byteOffset': 4, 'byteLength': 8},
            ],
            'accessors': [
              {
                'componentType': 5126,
                'count': 3,
                'type': 'VEC2',
                'sparse': {
                  'count': 1,
                  'indices': {'bufferView': 0, 'componentType': 5121},
                  'values': {'bufferView': 1},
                },
              },
            ],
          }),
        ),
      ),
    );

    expect(asset.readAccessorNumbers(0), [0.0, 0.0, 2.0, 3.0, 0.0, 0.0]);
  });

  test('negative accessor counts stay diagnostic in permissive mode', () {
    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'accessors': [
              {'componentType': 5126, 'count': -1, 'type': 'SCALAR'},
            ],
          }),
        ),
      ),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((diagnostic) => diagnostic.code),
      contains('gltf.invalidAccessorShape'),
    );
    expect(result.asset!.readAccessorNumbers(0), isNull);
  });

  test('reports invalid unused accessor component type and type', () {
    final json = {
      'asset': {'version': '2.0'},
      'accessors': [
        {'componentType': 'bad', 'count': 1, 'type': 'SCALAR'},
        {'componentType': 5126, 'count': 1, 'type': 7},
        {'componentType': 9999, 'count': 1, 'type': 'VEC5'},
      ],
    };

    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.where(
        (d) => d.code == 'gltf.invalidAccessorComponentType',
      ),
      hasLength(2),
    );
    expect(
      result.validation.errors.where(
        (d) => d.code == 'gltf.invalidAccessorType',
      ),
      hasLength(2),
    );
  });

  test('reports non-numeric accessor min and max entries', () {
    final json = {
      'asset': {'version': '2.0'},
      'accessors': [
        {
          'componentType': 5126,
          'count': 1,
          'type': 'VEC2',
          'min': [0.0, 'bad', 1.0],
          'max': [0.0, 'bad', 1.0],
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
      containsAll(['gltf.invalidAccessorMin', 'gltf.invalidAccessorMax']),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      containsAll([r'$.accessors[0].min', r'$.accessors[0].max']),
    );
  });

  test('reports accessor min and max mismatches with buffer data', () {
    final bytes = _floats([1.0, 2.0, 3.0]);
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': bytes.length,
          'uri': 'data:application/octet-stream;base64,${base64.encode(bytes)}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteLength': bytes.length},
      ],
      'accessors': [
        {
          'bufferView': 0,
          'componentType': 5126,
          'count': 3,
          'type': 'SCALAR',
          'min': [0.0],
          'max': [2.0],
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
      contains('gltf.accessorBoundsMismatch'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.accessorBoundsMismatch')
          .map((d) => d.jsonPath),
      contains(r'$.accessors[0].min'),
    );
  });

  test('reads and validates matrix accessors with column padding', () {
    final bytes = Uint8List(64)..fillRange(0, 64, 0xff);
    final data = ByteData.sublistView(bytes);
    const values = {0: 1, 2: 2, 4: 3, 8: 4, 10: 5, 12: 6, 16: 7, 18: 8, 20: 9};
    for (final entry in values.entries) {
      data.setUint16(entry.key, entry.value, Endian.little);
    }
    bytes[48] = 0;
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': bytes.length,
          'uri': 'data:application/octet-stream;base64,${base64.encode(bytes)}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 22},
        {'buffer': 0, 'byteOffset': 24, 'byteLength': 18},
        {'buffer': 0, 'byteOffset': 48, 'byteLength': 1},
      ],
      'accessors': [
        {
          'bufferView': 0,
          'componentType': 5123,
          'count': 1,
          'type': 'MAT3',
          'min': [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0],
          'max': [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0],
        },
        {'bufferView': 1, 'componentType': 5123, 'count': 1, 'type': 'MAT3'},
        {
          'componentType': 5123,
          'count': 1,
          'type': 'MAT3',
          'sparse': {
            'count': 1,
            'indices': {'bufferView': 2, 'componentType': 5121},
            'values': {'bufferView': 0},
          },
        },
      ],
    };

    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(result.asset!.readAccessorNumbers(0, applyNormalization: false), [
      1.0,
      2.0,
      3.0,
      4.0,
      5.0,
      6.0,
      7.0,
      8.0,
      9.0,
    ]);
    expect(result.asset!.readAccessorNumbers(2, applyNormalization: false), [
      1.0,
      2.0,
      3.0,
      4.0,
      5.0,
      6.0,
      7.0,
      8.0,
      9.0,
    ]);
    expect(
      result.validation.errors
          .where((d) => d.jsonPath == r'$.accessors[0].min')
          .map((d) => d.code),
      isNot(contains('gltf.accessorBoundsMismatch')),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.accessorOutOfRange')
          .map((d) => d.jsonPath),
      contains(r'$.accessors[1].bufferView'),
    );
  });

  test('reports non-finite FLOAT accessor values', () {
    final bytes = Uint8List(8);
    final data = ByteData.sublistView(bytes);
    data.setFloat32(0, 0.0, Endian.little);
    data.setFloat32(4, double.negativeInfinity, Endian.little);
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': bytes.length,
          'uri': 'data:application/octet-stream;base64,${base64.encode(bytes)}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteLength': bytes.length},
      ],
      'accessors': [
        {'bufferView': 0, 'componentType': 5126, 'count': 2, 'type': 'SCALAR'},
      ],
    };

    final strict = GltfAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
    );
    final permissive = GltfAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(strict.asset, isNull);
    expect(permissive.asset, isNotNull);
    expect(
      strict.validation.errors.map((d) => d.code),
      contains('gltf.invalidAccessorFloatValue'),
    );
    expect(
      strict.validation.errors
          .where((d) => d.code == 'gltf.invalidAccessorFloatValue')
          .map((d) => d.jsonPath),
      contains(r'$.accessors[0]'),
    );
  });

  test('reports UNSIGNED_INT accessors outside primitive indices', () {
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': 8,
          'uri':
              'data:application/octet-stream;base64,${base64.encode(Uint8List(8))}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 4},
        {'buffer': 0, 'byteOffset': 4, 'byteLength': 4},
      ],
      'accessors': [
        {'bufferView': 0, 'componentType': 5125, 'count': 1, 'type': 'SCALAR'},
        {'bufferView': 1, 'componentType': 5125, 'count': 1, 'type': 'SCALAR'},
      ],
      'meshes': [
        {
          'primitives': [
            {'indices': 1},
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
      result.validation.errors.where(
        (d) => d.code == 'gltf.invalidAccessorUnsignedIntUse',
      ),
      hasLength(1),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      contains(r'$.accessors[0].componentType'),
    );
  });

  test('reports sparse accessor bufferViews with target or byteStride', () {
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
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 4, 'target': 34962},
        {'buffer': 0, 'byteOffset': 4, 'byteLength': 12, 'byteStride': 4},
      ],
      'accessors': [
        {
          'componentType': 5126,
          'count': 2,
          'type': 'VEC3',
          'sparse': {
            'count': 1,
            'indices': {'bufferView': 0, 'componentType': 5121},
            'values': {'bufferView': 1},
          },
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
      contains('gltf.invalidSparseAccessorBufferView'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidSparseAccessorBufferView')
          .map((d) => d.jsonPath),
      containsAll([
        r'$.accessors[0].sparse.indices',
        r'$.accessors[0].sparse.values',
      ]),
    );
  });
}
