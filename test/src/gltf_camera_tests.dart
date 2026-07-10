part of '../flvtterm_test.dart';

void gltfCameraTests() {
  test('parses glTF cameras and node camera references', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'extensionsUsed': [
            'VENDOR_camera',
            'VENDOR_projection',
            'VENDOR_ortho',
          ],
          'cameras': [
            {
              'name': 'Main camera',
              'type': 'perspective',
              'perspective': {
                'aspectRatio': 1.5,
                'yfov': 1.0,
                'znear': 0.1,
                'zfar': 100.0,
                'extensions': {'VENDOR_projection': true},
                'extras': {'tag': 'debug'},
              },
              'extensions': {'VENDOR_camera': true},
              'extras': {'role': 'viewer'},
            },
            {
              'type': 'orthographic',
              'orthographic': {
                'xmag': 2.0,
                'ymag': 1.0,
                'znear': 0.0,
                'zfar': 10.0,
                'extensions': {'VENDOR_ortho': true},
              },
            },
          ],
          'nodes': [
            {'camera': 0},
          ],
        }),
      ),
    );

    final result = GltfAsset.tryParse(bytes: bytes);

    expect(result.validation.hasErrors, isFalse);
    final asset = result.asset!;
    final camera = asset.cameras.first;
    final orthographic = asset.cameras[1];
    expect(asset.nodes.single.camera, 0);
    expect(asset.cameras, hasLength(2));
    expect(camera.name, 'Main camera');
    expect(camera.type, GltfCameraType.perspective);
    expect(camera.perspective!.aspectRatio, 1.5);
    expect(camera.perspective!.yfov, 1.0);
    expect(camera.perspective!.znear, 0.1);
    expect(camera.perspective!.zfar, 100.0);
    expect(camera.extensions['VENDOR_camera'], isTrue);
    expect(camera.perspective!.extensions['VENDOR_projection'], isTrue);
    expect(camera.extras, {'role': 'viewer'});
    expect(orthographic.orthographic!.extensions['VENDOR_ortho'], isTrue);
    expect(() => camera.extensions['extra'] = true, throwsUnsupportedError);
    expect(
      () => camera.perspective!.extensions['extra'] = true,
      throwsUnsupportedError,
    );
    expect(
      () => orthographic.orthographic!.extensions['extra'] = true,
      throwsUnsupportedError,
    );
  });

  test('validates glTF camera definitions and node references', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'cameras': [
            {'type': 'perspective'},
            {
              'type': 'perspective',
              'perspective': {'yfov': 0, 'znear': 1, 'zfar': 0.5},
            },
            {
              'type': 'orthographic',
              'orthographic': {'xmag': 0, 'ymag': 1, 'znear': -1, 'zfar': 0},
            },
            {'type': 'bad'},
            {
              'perspective': {'yfov': 1, 'znear': 0.1},
            },
            {'type': 'orthographic', 'orthographic': 'bad'},
            {
              'type': 'perspective',
              'perspective': {'yfov': 1, 'znear': 0.1},
              'orthographic': {'xmag': 1, 'ymag': 1, 'znear': 0, 'zfar': 1},
            },
          ],
          'nodes': [
            {'camera': 'bad'},
            {'camera': 99},
          ],
        }),
      ),
    );

    final strict = GltfAsset.tryParse(bytes: bytes);
    final permissive = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(strict.asset, isNull);
    expect(permissive.asset, isNotNull);
    expect(
      strict.validation.errors.map((d) => d.code),
      containsAll([
        'gltf.missingCameraProjection',
        'gltf.invalidCameraPerspective',
        'gltf.invalidCameraOrthographic',
        'gltf.invalidCameraType',
        'gltf.missingCameraType',
        'gltf.invalidCameraProjection',
        'gltf.invalidNodeCamera',
      ]),
    );
  });

  test('warns for negative orthographic camera magnification', () {
    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'cameras': [
              {
                'type': 'orthographic',
                'orthographic': {
                  'xmag': -1.0,
                  'ymag': 1.0,
                  'znear': 0.0,
                  'zfar': 1.0,
                },
              },
            ],
          }),
        ),
      ),
    );

    expect(result.asset, isNotNull);
    expect(result.validation.hasErrors, isFalse);
    expect(
      result.validation.warnings.map((d) => d.code),
      contains('gltf.negativeCameraOrthographicMagnification'),
    );
  });

  test('warns for perspective camera yfov of pi or greater', () {
    final json = {
      'asset': {'version': '2.0'},
      'cameras': [
        {
          'type': 'perspective',
          'perspective': {'yfov': math.pi, 'znear': 0.1},
        },
      ],
    };
    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
    );

    expect(result.asset, isNotNull);
    expect(result.validation.hasErrors, isFalse);
    expect(
      result.validation.warnings.map((d) => d.code),
      contains('gltf.largeCameraPerspectiveYfov'),
    );
  });
}
