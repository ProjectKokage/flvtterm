part of '../flvtterm_test.dart';

void gltfMeshTests() {
  test('reports primitives without attributes', () {
    final json = {
      'asset': {'version': '2.0'},
      'meshes': [
        {
          'primitives': [<String, Object?>{}],
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
      contains('gltf.missingPrimitiveAttributes'),
    );
    expect(
      result.validation.errors
          .singleWhere((d) => d.code == 'gltf.missingPrimitiveAttributes')
          .jsonPath,
      r'$.meshes[0].primitives[0].attributes',
    );
  });

  test('reports invalid primitive target arrays', () {
    final json = {
      'asset': {'version': '2.0'},
      'meshes': [
        {
          'primitives': [
            {'attributes': <String, Object?>{}, 'targets': []},
            {'attributes': <String, Object?>{}, 'targets': 'bad'},
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
        (d) => d.code == 'gltf.invalidPrimitiveTargets',
      ),
      hasLength(2),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidPrimitiveTargets')
          .map((d) => d.jsonPath),
      containsAll([
        r'$.meshes[0].primitives[0].targets',
        r'$.meshes[0].primitives[1].targets',
      ]),
    );
  });

  test('warns for mesh target names that do not match morph targets', () {
    final json = {
      'asset': {'version': '2.0'},
      'accessors': [
        {
          'componentType': 5126,
          'count': 1,
          'type': 'VEC3',
          'min': [0.0, 0.0, 0.0],
          'max': [0.0, 0.0, 0.0],
        },
        {'componentType': 5126, 'count': 1, 'type': 'VEC3'},
      ],
      'meshes': [
        {
          'extras': {
            'targetNames': ['smile', 7],
          },
          'primitives': [
            {
              'mode': 0,
              'attributes': {'POSITION': 0},
              'targets': [
                {'POSITION': 1},
              ],
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
      result.validation.warnings.map((d) => d.code),
      contains('gltf.invalidMeshTargetNames'),
    );
    expect(
      result.validation.warnings
          .singleWhere((d) => d.code == 'gltf.invalidMeshTargetNames')
          .jsonPath,
      r'$.meshes[0].extras.targetNames',
    );
  });

  test('reports material textures without matching TEXCOORD attributes', () {
    final json = {
      'asset': {'version': '2.0'},
      'accessors': [
        {
          'componentType': 5126,
          'count': 3,
          'type': 'VEC3',
          'min': [0.0, 0.0, 0.0],
          'max': [1.0, 1.0, 1.0],
        },
        {'componentType': 5126, 'count': 3, 'type': 'VEC2'},
      ],
      'textures': [<String, Object?>{}],
      'materials': [
        {
          'pbrMetallicRoughness': {
            'baseColorTexture': {'index': 0, 'texCoord': 1},
          },
        },
      ],
      'meshes': [
        {
          'primitives': [
            {
              'material': 0,
              'attributes': {'POSITION': 0, 'TEXCOORD_0': 1},
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
      contains('gltf.missingTextureCoordinateAttribute'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.missingTextureCoordinateAttribute')
          .map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[0].attributes'),
    );
  });

  test('reports tangent accessors with invalid handedness values', () {
    final tangent = _floats([0.0, 0.0, 1.0, 0.5]);
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': tangent.length,
          'uri':
              'data:application/octet-stream;base64,${base64.encode(tangent)}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': tangent.length},
      ],
      'accessors': [
        {'bufferView': 0, 'componentType': 5126, 'count': 1, 'type': 'VEC4'},
      ],
      'meshes': [
        {
          'primitives': [
            {
              'mode': 0,
              'attributes': {'TANGENT': 0},
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
      contains('gltf.invalidTangentHandedness'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidTangentHandedness')
          .map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[0].attributes.TANGENT'),
    );
  });

  test('reports COLOR_0 accessors outside the clamped range', () {
    final binary = _floats([
      0.0, 0.0, 0.0, // POSITION
      1.2, 0.0, 0.0, 1.0, // COLOR_0
    ]);
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': binary.length,
          'uri':
              'data:application/octet-stream;base64,${base64.encode(binary)}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 12},
        {'buffer': 0, 'byteOffset': 12, 'byteLength': 16},
      ],
      'accessors': [
        {
          'bufferView': 0,
          'componentType': 5126,
          'count': 1,
          'type': 'VEC3',
          'min': [0.0, 0.0, 0.0],
          'max': [0.0, 0.0, 0.0],
        },
        {'bufferView': 1, 'componentType': 5126, 'count': 1, 'type': 'VEC4'},
      ],
      'meshes': [
        {
          'primitives': [
            {
              'mode': 0,
              'attributes': {'POSITION': 0, 'COLOR_0': 1},
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
      contains('gltf.invalidColorAccessorValue'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidColorAccessorValue')
          .map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[0].attributes.COLOR_0'),
    );
  });

  test('reports invalid skin weight values', () {
    final binary = Uint8List(20);
    binary.setAll(0, [100, 100, 0, 0]);
    binary.setAll(4, _floats([-0.1, 1.0, 0.0, 0.0]));
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': binary.length,
          'uri':
              'data:application/octet-stream;base64,${base64.encode(binary)}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 4},
        {'buffer': 0, 'byteOffset': 4, 'byteLength': 16},
      ],
      'accessors': [
        {'componentType': 5121, 'count': 1, 'type': 'VEC4'},
        {
          'bufferView': 0,
          'componentType': 5121,
          'count': 1,
          'type': 'VEC4',
          'normalized': true,
        },
        {'bufferView': 1, 'componentType': 5126, 'count': 1, 'type': 'VEC4'},
      ],
      'meshes': [
        {
          'primitives': [
            {
              'mode': 0,
              'attributes': {'JOINTS_0': 0, 'WEIGHTS_0': 1},
            },
            {
              'mode': 0,
              'attributes': {'JOINTS_0': 0, 'WEIGHTS_0': 2},
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
      containsAll(['gltf.invalidSkinWeightSum', 'gltf.invalidSkinWeightValue']),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidSkinWeightSum')
          .map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[0].attributes.WEIGHTS_0'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidSkinWeightValue')
          .map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[1].attributes.WEIGHTS_0'),
    );
  });

  test('warns for float skin weights that do not sum to one', () {
    final binary = Uint8List(20);
    binary.setAll(4, _floats([0.25, 0.25, 0.0, 0.0]));
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': binary.length,
          'uri':
              'data:application/octet-stream;base64,${base64.encode(binary)}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 4},
        {'buffer': 0, 'byteOffset': 4, 'byteLength': 16},
      ],
      'accessors': [
        {'bufferView': 0, 'componentType': 5121, 'count': 1, 'type': 'VEC4'},
        {'bufferView': 1, 'componentType': 5126, 'count': 1, 'type': 'VEC4'},
      ],
      'meshes': [
        {
          'primitives': [
            {
              'mode': 0,
              'attributes': {'JOINTS_0': 0, 'WEIGHTS_0': 1},
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
    expect(result.validation.hasErrors, isFalse);
    expect(
      result.validation.warnings.map((d) => d.code),
      contains('gltf.skinWeightSum'),
    );
    expect(
      result.validation.warnings.map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[0].attributes.WEIGHTS_0'),
    );
  });

  test(
    'reports non-indexed primitive vertex counts invalid for the draw mode',
    () {
      final json = {
        'asset': {'version': '2.0'},
        'accessors': [
          {
            'componentType': 5126,
            'count': 2,
            'type': 'VEC3',
            'min': [0.0, 0.0, 0.0],
            'max': [1.0, 1.0, 1.0],
          },
        ],
        'meshes': [
          {
            'primitives': [
              {
                'mode': 4,
                'attributes': {'POSITION': 0},
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
        contains('gltf.invalidPrimitiveVertexCount'),
      );
    },
  );

  test('reports primitive index counts invalid for the draw mode', () {
    final indices = Uint8List.fromList([0, 1]);
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': indices.length,
          'uri':
              'data:application/octet-stream;base64,${base64.encode(indices)}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': indices.length},
      ],
      'accessors': [
        {'bufferView': 0, 'componentType': 5121, 'count': 2, 'type': 'SCALAR'},
        {
          'componentType': 5126,
          'count': 2,
          'type': 'VEC3',
          'min': [0.0, 0.0, 0.0],
          'max': [1.0, 1.0, 1.0],
        },
      ],
      'meshes': [
        {
          'primitives': [
            {
              'mode': 4,
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
      contains('gltf.invalidPrimitiveIndexCount'),
    );
    expect(
      result.validation.errors.map((d) => d.code),
      isNot(contains('gltf.primitiveIndexOutOfRange')),
    );
  });

  test('reports primitive indices using the restart value', () {
    final indices = Uint8List.fromList([0, 255, 1]);
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': indices.length,
          'uri':
              'data:application/octet-stream;base64,${base64.encode(indices)}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': indices.length},
      ],
      'accessors': [
        {'bufferView': 0, 'componentType': 5121, 'count': 3, 'type': 'SCALAR'},
        {
          'componentType': 5126,
          'count': 256,
          'type': 'VEC3',
          'min': [0.0, 0.0, 0.0],
          'max': [1.0, 1.0, 1.0],
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
      contains('gltf.primitiveIndexUsesRestartValue'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.primitiveIndexUsesRestartValue')
          .map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[0].indices'),
    );
    expect(
      result.validation.errors.map((d) => d.code),
      isNot(contains('gltf.primitiveIndexOutOfRange')),
    );
  });

  test('warns for degenerate indexed triangle primitives', () {
    final indices = Uint8List.fromList([0, 1, 1]);
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': indices.length,
          'uri':
              'data:application/octet-stream;base64,${base64.encode(indices)}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': indices.length},
      ],
      'accessors': [
        {'bufferView': 0, 'componentType': 5121, 'count': 3, 'type': 'SCALAR'},
        {
          'componentType': 5126,
          'count': 2,
          'type': 'VEC3',
          'min': [0.0, 0.0, 0.0],
          'max': [1.0, 1.0, 1.0],
        },
      ],
      'meshes': [
        {
          'primitives': [
            {
              'mode': 4,
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
    expect(result.validation.hasErrors, isFalse);
    expect(
      result.validation.warnings.map((d) => d.code),
      contains('gltf.degeneratePrimitive'),
    );
    expect(
      result.validation.warnings
          .singleWhere((d) => d.code == 'gltf.degeneratePrimitive')
          .jsonPath,
      r'$.meshes[0].primitives[0].indices',
    );
  });

  test('reports primitive indices outside the attribute count', () {
    final indices = Uint8List(6);
    final data = ByteData.sublistView(indices);
    data.setUint16(0, 0, Endian.little);
    data.setUint16(2, 3, Endian.little);
    data.setUint16(4, 1, Endian.little);
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': indices.length,
          'uri':
              'data:application/octet-stream;base64,${base64.encode(indices)}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': indices.length},
      ],
      'accessors': [
        {'bufferView': 0, 'componentType': 5123, 'count': 3, 'type': 'SCALAR'},
        {
          'componentType': 5126,
          'count': 3,
          'type': 'VEC3',
          'min': [0.0, 0.0, 0.0],
          'max': [1.0, 1.0, 1.0],
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
      contains('gltf.primitiveIndexOutOfRange'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.primitiveIndexOutOfRange')
          .map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[0].indices'),
    );
  });

  test('reports invalid indexed primitive attribute semantics', () {
    final json = {
      'asset': {'version': '2.0'},
      'accessors': [
        {'componentType': 5126, 'count': 1, 'type': 'VEC2'},
        {'componentType': 5126, 'count': 1, 'type': 'VEC4'},
        {'componentType': 5121, 'count': 1, 'type': 'VEC4'},
        {'componentType': 5121, 'count': 1, 'type': 'VEC4'},
        {'componentType': 5126, 'count': 1, 'type': 'VEC4'},
      ],
      'meshes': [
        {
          'primitives': [
            {
              'attributes': {
                'TEXCOORD_1': 0,
                'COLOR_01': 1,
                'JOINTS_0': 2,
                'JOINTS_2': 3,
                'WEIGHTS_0': 4,
              },
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
      result.validation.errors.where(
        (d) => d.code == 'gltf.invalidPrimitiveAttributeSemantic',
      ),
      hasLength(3),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidPrimitiveAttributeSemantic')
          .map((d) => d.jsonPath),
      everyElement(r'$.meshes[0].primitives[0].attributes'),
    );
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.mismatchedSkinAttributeSets'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.mismatchedSkinAttributeSets')
          .map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[0].attributes'),
    );
  });

  test('accepts texture coordinate and color morph target semantics', () {
    final json = {
      'asset': {'version': '2.0'},
      'accessors': [
        {
          'componentType': 5126,
          'count': 1,
          'type': 'VEC3',
          'min': [0.0, 0.0, 0.0],
          'max': [1.0, 1.0, 1.0],
        },
        {'componentType': 5126, 'count': 1, 'type': 'VEC2'},
        {'componentType': 5121, 'count': 1, 'type': 'VEC4', 'normalized': true},
        {
          'componentType': 5126,
          'count': 1,
          'type': 'VEC3',
          'min': [0.0, 0.0, 0.0],
          'max': [0.0, 0.0, 0.0],
        },
        {'componentType': 5122, 'count': 1, 'type': 'VEC2', 'normalized': true},
        {'componentType': 5120, 'count': 1, 'type': 'VEC4', 'normalized': true},
      ],
      'meshes': [
        {
          'primitives': [
            {
              'mode': 0,
              'attributes': {'POSITION': 0, 'TEXCOORD_0': 1, 'COLOR_0': 2},
              'targets': [
                {'POSITION': 3, 'TEXCOORD_0': 4, 'COLOR_0': 5},
              ],
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
    expect(result.validation.hasErrors, isFalse);
  });

  test(
    'reports invalid texture coordinate morph target semantics and shape',
    () {
      final json = {
        'asset': {'version': '2.0'},
        'accessors': [
          {
            'componentType': 5126,
            'count': 1,
            'type': 'VEC3',
            'min': [0.0, 0.0, 0.0],
            'max': [1.0, 1.0, 1.0],
          },
          {'componentType': 5126, 'count': 1, 'type': 'VEC2'},
          {'componentType': 5126, 'count': 1, 'type': 'VEC3'},
        ],
        'meshes': [
          {
            'primitives': [
              {
                'attributes': {'POSITION': 0, 'TEXCOORD_0': 1},
                'targets': [
                  {'TEXCOORD_0': 2, 'TEXCOORD_01': 2},
                ],
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
        containsAll([
          'gltf.invalidPrimitiveTargetSemantic',
          'gltf.invalidPrimitiveTargetAccessor',
        ]),
      );
      expect(
        result.validation.errors
            .where((d) => d.code == 'gltf.invalidPrimitiveTargetSemantic')
            .map((d) => d.jsonPath),
        contains(r'$.meshes[0].primitives[0].targets[0]'),
      );
      expect(
        result.validation.errors
            .where((d) => d.code == 'gltf.invalidPrimitiveTargetAccessor')
            .map((d) => d.jsonPath),
        contains(r'$.meshes[0].primitives[0].targets[0].TEXCOORD_0'),
      );
    },
  );

  test('reports custom primitive semantics without underscore prefixes', () {
    final json = {
      'asset': {'version': '2.0'},
      'accessors': [
        {
          'componentType': 5126,
          'count': 1,
          'type': 'VEC3',
          'min': [0.0, 0.0, 0.0],
          'max': [1.0, 1.0, 1.0],
        },
        {'componentType': 5126, 'count': 1, 'type': 'SCALAR'},
        {'componentType': 5126, 'count': 1, 'type': 'VEC3'},
      ],
      'meshes': [
        {
          'primitives': [
            {
              'mode': 0,
              'attributes': {'POSITION': 0, 'CUSTOM': 1, '_CUSTOM': 1},
              'targets': [
                {'POSITION': 2, 'CUSTOM_TARGET': 2, '_CUSTOM_TARGET': 2},
              ],
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
      containsAll([
        'gltf.invalidPrimitiveAttributeSemantic',
        'gltf.invalidPrimitiveTargetSemantic',
      ]),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidPrimitiveAttributeSemantic')
          .map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[0].attributes'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidPrimitiveTargetSemantic')
          .map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[0].targets[0]'),
    );
  });
}
