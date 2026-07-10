part of '../flvtterm_test.dart';

void gltfSkinTests() {
  test('reports skin skeleton outside the joint common root', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'scene': 0,
          'scenes': [
            {
              'nodes': [0],
            },
          ],
          'nodes': [
            {
              'children': [1, 2],
            },
            {'name': 'left'},
            {'name': 'right'},
          ],
          'skins': [
            {
              'joints': [1, 2],
              'skeleton': 1,
            },
            {
              'joints': [1, 2],
              'skeleton': 0,
            },
          ],
        }),
      ),
    );

    final result = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.where(
        (d) => d.code == 'gltf.invalidSkinSkeletonRoot',
      ),
      hasLength(1),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      contains(r'$.skins[0].skeleton'),
    );
  });

  test('reports skin joints without a common root', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'nodes': [
            {'name': 'leftRoot'},
            {'name': 'rightRoot'},
          ],
          'skins': [
            {
              'joints': [0, 1],
            },
          ],
        }),
      ),
    );

    final result = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.skinJointsMissingCommonRoot'),
    );
    expect(
      result.validation.errors
          .singleWhere((d) => d.code == 'gltf.skinJointsMissingCommonRoot')
          .jsonPath,
      r'$.skins[0].joints',
    );
  });

  test('reports skin joints outside the skinned node scene', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'scene': 0,
          'scenes': [
            {
              'nodes': [0],
            },
          ],
          'nodes': [
            {
              'children': [1, 2, 4],
            },
            {'mesh': 0, 'skin': 0},
            {'name': 'jointInScene'},
            {'name': 'jointOutsideScene'},
            {'mesh': 0, 'skin': 1},
          ],
          'skins': [
            {
              'joints': [2, 3],
            },
            {
              'joints': [2],
            },
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
          'accessors': [
            {'componentType': 5121, 'count': 1, 'type': 'VEC4'},
            {'componentType': 5126, 'count': 1, 'type': 'VEC4'},
          ],
        }),
      ),
    );

    final result = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.where(
        (d) => d.code == 'gltf.skinJointNotInScene',
      ),
      hasLength(1),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      contains(r'$.nodes[1].skin'),
    );
  });

  test('reports joint attribute values outside the skin joint range', () {
    final joints = Uint8List.fromList([2, 0, 0, 0]);
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {
              'byteLength': joints.length,
              'uri':
                  'data:application/octet-stream;base64,${base64.encode(joints)}',
            },
          ],
          'bufferViews': [
            {'buffer': 0, 'byteOffset': 0, 'byteLength': joints.length},
          ],
          'accessors': [
            {
              'bufferView': 0,
              'componentType': 5121,
              'count': 1,
              'type': 'VEC4',
            },
            {'componentType': 5126, 'count': 1, 'type': 'VEC4'},
          ],
          'nodes': [
            {'mesh': 0, 'skin': 0},
            {
              'name': 'joint0',
              'children': [2],
            },
            {'name': 'joint1'},
          ],
          'skins': [
            {
              'joints': [1, 2],
            },
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
        }),
      ),
    );

    final result = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.skinJointValueOutOfRange'),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[0].attributes.JOINTS_0'),
    );
  });

  test('warns for nonzero unused skin joint values', () {
    final binary = Uint8List(20);
    binary.setAll(0, [1, 0, 0, 0]);
    binary.setAll(4, _floats([0.0, 1.0, 0.0, 0.0]));
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
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
            {
              'bufferView': 0,
              'componentType': 5121,
              'count': 1,
              'type': 'VEC4',
            },
            {
              'bufferView': 1,
              'componentType': 5126,
              'count': 1,
              'type': 'VEC4',
            },
          ],
          'nodes': [
            {'mesh': 0, 'skin': 0},
            {
              'name': 'joint0',
              'children': [2],
            },
            {'name': 'joint1'},
          ],
          'skins': [
            {
              'joints': [1, 2],
            },
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
        }),
      ),
    );

    final result = GltfAsset.tryParse(bytes: bytes);

    expect(result.asset, isNotNull);
    expect(result.validation.hasErrors, isFalse);
    expect(
      result.validation.warnings.map((d) => d.code),
      contains('gltf.nonzeroUnusedSkinJoint'),
    );
    expect(
      result.validation.warnings.map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[0].attributes.JOINTS_0'),
    );
  });

  test('reports duplicate non-zero joint weights for one vertex', () {
    final binary = Uint8List(40);
    binary.setAll(0, [0, 1, 0, 0]);
    binary.setAll(4, _floats([0.5, 0.5, 0.0, 0.0]));
    binary.setAll(20, [1, 0, 0, 0]);
    binary.setAll(24, _floats([0.25, 0.0, 0.0, 0.0]));
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
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
            {'buffer': 0, 'byteOffset': 20, 'byteLength': 4},
            {'buffer': 0, 'byteOffset': 24, 'byteLength': 16},
          ],
          'accessors': [
            {
              'bufferView': 0,
              'componentType': 5121,
              'count': 1,
              'type': 'VEC4',
            },
            {
              'bufferView': 1,
              'componentType': 5126,
              'count': 1,
              'type': 'VEC4',
            },
            {
              'bufferView': 2,
              'componentType': 5121,
              'count': 1,
              'type': 'VEC4',
            },
            {
              'bufferView': 3,
              'componentType': 5126,
              'count': 1,
              'type': 'VEC4',
            },
          ],
          'nodes': [
            {'mesh': 0, 'skin': 0},
            {
              'name': 'joint0',
              'children': [2],
            },
            {'name': 'joint1'},
          ],
          'skins': [
            {
              'joints': [1, 2],
            },
          ],
          'meshes': [
            {
              'primitives': [
                {
                  'mode': 0,
                  'attributes': {
                    'JOINTS_0': 0,
                    'WEIGHTS_0': 1,
                    'JOINTS_1': 2,
                    'WEIGHTS_1': 3,
                  },
                },
              ],
            },
          ],
        }),
      ),
    );

    final result = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.duplicateSkinJointWeight'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.duplicateSkinJointWeight')
          .map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[0].attributes.JOINTS_1'),
    );
  });
}
