part of '../flvtterm_test.dart';

void parserTests() {
  test('core library stays renderer-neutral', () {
    const bannedImports = [
      'dart:ffi',
      'dart:html',
      'dart:io',
      'dart:js',
      'dart:ui',
      'package:flutter/',
      'package:flutter_scene/',
      'package:flutter_gpu/',
    ];
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            file
                .readAsLinesSync()
                .where((line) => line.trimLeft().startsWith('import '))
                .any((line) => bannedImports.any(line.contains)))
          file.path,
    ];

    expect(offenders, isEmpty);
  });

  test('Flutter helper package stays renderer-neutral', () {
    const bannedImports = [
      'dart:ui',
      'package:flutter_scene/',
      'package:flutter_gpu/',
    ];
    final offenders = [
      for (final file in Directory(
        'packages/vrm_flutter/lib',
      ).listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            file
                .readAsLinesSync()
                .where((line) => line.trimLeft().startsWith('import '))
                .any((line) => bannedImports.any(line.contains)))
          file.path,
    ];
    final pubspec = File(
      'packages/vrm_flutter/pubspec.yaml',
    ).readAsStringSync();

    expect(offenders, isEmpty);
    expect(pubspec, isNot(contains('flutter_scene:')));
    expect(pubspec, isNot(contains('flutter_gpu:')));
  });

  test('Flutter Scene dependency stays isolated to adapter and examples', () {
    final offenders = <String>[];
    final roots = [
      File('pubspec.yaml'),
      Directory('lib'),
      Directory('packages'),
      Directory('examples'),
    ];

    for (final root in roots) {
      final files = root is File
          ? [root]
          : (root as Directory).listSync(recursive: true).whereType<File>();
      for (final file in files) {
        final path = file.path.replaceAll(r'\', '/');
        final isSurface =
            path.endsWith('pubspec.yaml') ||
            (path.endsWith('.dart') && path.contains('/lib/')) ||
            path.startsWith('lib/');
        if (!isSurface ||
            path.startsWith('packages/vrm_flutter_scene/') ||
            path.startsWith('examples/')) {
          continue;
        }
        final text = file.readAsStringSync();
        if (text.contains('flutter_scene') || text.contains('flutter_gpu')) {
          offenders.add(path);
        }
      }
    }

    expect(offenders, isEmpty);
  });

  test('validation result groups diagnostics by severity', () {
    final result = VrmValidationResult([
      const VrmDiagnostic(severity: VrmInfo(), code: 'info', message: 'info'),
      const VrmDiagnostic(
        severity: VrmWarning(),
        code: 'warning',
        message: 'warning',
      ),
      const VrmDiagnostic(
        severity: VrmError(),
        code: 'error',
        message: 'error',
      ),
    ]);

    expect(result.infos.single.code, 'info');
    expect(result.warnings.single.code, 'warning');
    expect(result.errors.single.code, 'error');
    expect(result.hasErrors, isTrue);
  });

  test('matrix storage is immutable and value-comparable', () {
    final matrix = VrmMatrix4.identity();

    expect(() => matrix.storage[0] = 2, throwsUnsupportedError);
    expect(matrix, VrmMatrix4.identity());
    expect(matrix.hashCode, VrmMatrix4.identity().hashCode);
    expect(matrix, isNot(VrmMatrix4(List.filled(16, 0))));
    expect(matrix.toString(), startsWith('VrmMatrix4('));
  });

  test('parsed public string and index lists are immutable', () {
    final model = VrmModel.parseGlb(_glb(_minimalVrmJson()));

    expect(
      () => model.gltf.extensionsUsed.add('VENDOR_mutation'),
      throwsUnsupportedError,
    );
    expect(
      () => model.gltf.nodes.add(model.gltf.nodes.first),
      throwsUnsupportedError,
    );
    expect(
      () => model.gltf.scenes.add(model.gltf.scenes.single),
      throwsUnsupportedError,
    );
    expect(
      () => model.gltf.scenes.single.nodes.add(99),
      throwsUnsupportedError,
    );
    expect(
      () => model.gltf.nodes.first.children.add(99),
      throwsUnsupportedError,
    );
    expect(
      () => model.gltf.nodes.first.translation[0] = 9.0,
      throwsUnsupportedError,
    );
    expect(
      () => model.gltf.nodes.first.rotation[3] = 0.0,
      throwsUnsupportedError,
    );
    expect(() => model.gltf.nodes.first.scale[0] = 9.0, throwsUnsupportedError);
    expect(
      () => model.gltf.nodes.first.weights.add(1.0),
      throwsUnsupportedError,
    );
    expect(() => model.vrm.meta.authors.add('Mutator'), throwsUnsupportedError);
  });

  test('parsed public extension and raw maps are immutable', () {
    final json = _minimalVrmJson();
    final rootExtensions = Map<String, Object?>.from(
      json['extensions']! as Map,
    );
    rootExtensions['EXT_root'] = {'enabled': true};
    json['extensions'] = rootExtensions;
    (json['extensionsUsed']! as List<Object?>).add('EXT_root');
    final model = VrmModel.parseGlb(_glb(json));
    final gltfJsonAsset = model.gltf.json['asset']! as Map<String, Object?>;
    final gltfRootExtension =
        model.gltf.extensions['EXT_root']! as Map<String, Object?>;
    final vrmRawMeta = model.vrm.raw['meta']! as Map<String, Object?>;

    expect(
      () => model.gltf.json['asset'] = {'version': '2.0'},
      throwsUnsupportedError,
    );
    expect(() => gltfJsonAsset['version'] = 'mutator', throwsUnsupportedError);
    expect(
      () => model.gltf.extensions['EXT_other'] = true,
      throwsUnsupportedError,
    );
    expect(() => gltfRootExtension['enabled'] = false, throwsUnsupportedError);
    expect(
      () => model.gltf.asset['generator'] = 'mutator',
      throwsUnsupportedError,
    );
    expect(
      () => model.vrm.raw['specVersion'] = 'mutator',
      throwsUnsupportedError,
    );
    expect(() => vrmRawMeta['name'] = 'mutator', throwsUnsupportedError);
    expect(
      () => model.vrm.meta.raw['name'] = 'mutator',
      throwsUnsupportedError,
    );
  });

  test('parsed public mesh primitive collections are immutable', () {
    final json = _minimalVrmJson(
      meshes: [
        {
          'extensions': {'EXT_mesh': true},
          'primitives': [
            {
              'attributes': {'POSITION': 0},
              'targets': [
                {'POSITION': 1},
              ],
              'extensions': {'EXT_primitive': true},
            },
          ],
        },
      ],
    );
    (json['extensionsUsed']! as List<String>).addAll([
      'EXT_mesh',
      'EXT_primitive',
    ]);
    json['accessors'] = [
      {
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'min': [0.0, 0.0, 0.0],
        'max': [1.0, 1.0, 1.0],
      },
      {
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'min': [0.0, 0.0, 0.0],
        'max': [0.0, 0.0, 0.0],
      },
    ];
    final model = VrmModel.parseGlb(_glb(json));
    final primitive = model.gltf.meshes.single.primitives.single;

    expect(
      () => model.gltf.meshes.single.primitives.add(primitive),
      throwsUnsupportedError,
    );
    expect(
      () => model.gltf.meshes.single.extensions['EXT_other'] = true,
      throwsUnsupportedError,
    );
    expect(() => primitive.attributes['NORMAL'] = 2, throwsUnsupportedError);
    expect(() => primitive.targets.add(const {}), throwsUnsupportedError);
    expect(
      () => primitive.targets.single['NORMAL'] = 2,
      throwsUnsupportedError,
    );
    expect(
      () => primitive.extensions['EXT_other'] = true,
      throwsUnsupportedError,
    );
  });

  test('parsed public VRM collections are immutable', () {
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {
              'attributes': <String, Object?>{},
              'targets': [<String, Object?>{}],
            },
          ],
        },
      ],
      materials: [
        {
          'pbrMetallicRoughness': {
            'baseColorFactor': [1.0, 1.0, 1.0, 1.0],
          },
        },
      ],
      nodeMesh: {0: 0},
      firstPerson: {
        'meshAnnotations': [
          {'node': 0, 'type': 'both'},
        ],
      },
      expressions: {
        'preset': {
          'happy': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
            'materialColorBinds': [
              {
                'material': 0,
                'type': 'color',
                'targetValue': [1.0, 0.0, 0.0, 1.0],
              },
            ],
            'textureTransformBinds': [
              {
                'material': 0,
                'scale': [1.0, 1.0],
                'offset': [0.0, 0.0],
              },
            ],
          },
        },
        'custom': {
          'winkStrong': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 0.5},
            ],
          },
        },
      },
    );
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    (vrm['meta']! as Map<String, Object?>)['references'] = ['source'];
    vrm['lookAt'] = {
      'type': 'expression',
      'offsetFromHeadBone': [0.0, 0.1, 0.2],
    };

    final model = VrmModel.parseGlb(_glb(json));
    final happy = model.vrm.expressions.preset[VrmExpressionPreset.happy]!;

    expect(() => model.vrm.meta.references.add('copy'), throwsUnsupportedError);
    expect(() => model.vrm.humanoid.humanBones.clear(), throwsUnsupportedError);
    expect(
      () => model.vrm.firstPerson.meshAnnotations.clear(),
      throwsUnsupportedError,
    );
    expect(() => model.vrm.expressions.preset.clear(), throwsUnsupportedError);
    expect(() => model.vrm.expressions.custom.clear(), throwsUnsupportedError);
    expect(
      () => happy.morphTargetBinds.add(happy.morphTargetBinds.single),
      throwsUnsupportedError,
    );
    expect(() => happy.materialColorBinds.clear(), throwsUnsupportedError);
    expect(() => happy.textureTransformBinds.clear(), throwsUnsupportedError);
    expect(
      () => model.vrm.lookAt!.offsetFromHeadBone.add(0.3),
      throwsUnsupportedError,
    );
  });

  test('closed VRM enums match VRM 1.0 schema names', () {
    expect(VrmHumanoidBone.values.map((bone) => bone.specName), [
      'hips',
      'spine',
      'chest',
      'upperChest',
      'neck',
      'head',
      'leftEye',
      'rightEye',
      'jaw',
      'leftUpperLeg',
      'leftLowerLeg',
      'leftFoot',
      'leftToes',
      'rightUpperLeg',
      'rightLowerLeg',
      'rightFoot',
      'rightToes',
      'leftShoulder',
      'leftUpperArm',
      'leftLowerArm',
      'leftHand',
      'rightShoulder',
      'rightUpperArm',
      'rightLowerArm',
      'rightHand',
      'leftThumbMetacarpal',
      'leftThumbProximal',
      'leftThumbDistal',
      'leftIndexProximal',
      'leftIndexIntermediate',
      'leftIndexDistal',
      'leftMiddleProximal',
      'leftMiddleIntermediate',
      'leftMiddleDistal',
      'leftRingProximal',
      'leftRingIntermediate',
      'leftRingDistal',
      'leftLittleProximal',
      'leftLittleIntermediate',
      'leftLittleDistal',
      'rightThumbMetacarpal',
      'rightThumbProximal',
      'rightThumbDistal',
      'rightIndexProximal',
      'rightIndexIntermediate',
      'rightIndexDistal',
      'rightMiddleProximal',
      'rightMiddleIntermediate',
      'rightMiddleDistal',
      'rightRingProximal',
      'rightRingIntermediate',
      'rightRingDistal',
      'rightLittleProximal',
      'rightLittleIntermediate',
      'rightLittleDistal',
    ]);
    expect(
      VrmHumanoidBone.values
          .where((bone) => bone.isRequired)
          .map((bone) => bone.specName),
      [
        'hips',
        'spine',
        'head',
        'leftUpperLeg',
        'leftLowerLeg',
        'leftFoot',
        'rightUpperLeg',
        'rightLowerLeg',
        'rightFoot',
        'leftUpperArm',
        'leftLowerArm',
        'leftHand',
        'rightUpperArm',
        'rightLowerArm',
        'rightHand',
      ],
    );
    expect(VrmExpressionPreset.values.map((preset) => preset.specName), [
      'happy',
      'angry',
      'sad',
      'relaxed',
      'surprised',
      'aa',
      'ih',
      'ou',
      'ee',
      'oh',
      'blink',
      'blinkLeft',
      'blinkRight',
      'lookUp',
      'lookDown',
      'lookLeft',
      'lookRight',
      'neutral',
    ]);
    expect(VrmMetaAvatarPermission.values.map((value) => value.specName), [
      'onlyAuthor',
      'onlySeparatelyLicensedPerson',
      'everyone',
    ]);
    expect(VrmMetaCommercialUsage.values.map((value) => value.specName), [
      'personalNonProfit',
      'personalProfit',
      'corporation',
    ]);
    expect(VrmMetaCreditNotation.values.map((value) => value.specName), [
      'required',
      'unnecessary',
    ]);
    expect(VrmMetaModification.values.map((value) => value.specName), [
      'prohibited',
      'allowModification',
      'allowModificationRedistribution',
    ]);
    expect(VrmExpressionOverrideMode.values.map((value) => value.specName), [
      'none',
      'block',
      'blend',
    ]);
    expect(
      VrmFirstPersonMeshAnnotationType.values.map((value) => value.specName),
      ['thirdPersonOnly', 'firstPersonOnly', 'both', 'auto'],
    );
    expect(VrmLookAtType.values.map((value) => value.specName), [
      'bone',
      'expression',
    ]);
    expect(VrmNodeConstraintKind.values.map((value) => value.specName), [
      'roll',
      'aim',
      'rotation',
    ]);
    expect(VrmNodeConstraintRollAxis.values.map((value) => value.specName), [
      'X',
      'Y',
      'Z',
    ]);
    expect(VrmNodeConstraintAimAxis.values.map((value) => value.specName), [
      'PositiveX',
      'NegativeX',
      'PositiveY',
      'NegativeY',
      'PositiveZ',
      'NegativeZ',
    ]);
    expect(
      VrmSpringBoneColliderShapeType.values.map((value) => value.specName),
      ['sphere', 'capsule'],
    );
    expect(VrmMToonOutlineWidthMode.values.map((value) => value.specName), [
      'none',
      'worldCoordinates',
      'screenCoordinates',
    ]);
  });

  test('parses a minimal VRM 1.0 GLB and preserves humanoid indices', () {
    final json = _minimalVrmJson();
    json['asset'] = {
      'version': '2.0',
      'minVersion': '2.0',
      'generator': 'flvtterm-test',
      'copyright': '2026',
      'extensions': {
        'EXT_asset': {'source': 'fixture'},
      },
      'extras': {'asset': 1},
    };
    (json['extensionsUsed']! as List<Object?>).add('EXT_asset');

    final result = VrmModel.tryParseGlb(_glb(json));

    expect(result.validation.hasErrors, isFalse);
    expect(result.asset, isNotNull);
    expect(result.asset!.vrm.meta.name, 'Avatar');
    expect(result.asset!.gltf.assetVersion, '2.0');
    expect(result.asset!.gltf.assetMinVersion, '2.0');
    expect(result.asset!.gltf.assetGenerator, 'flvtterm-test');
    expect(result.asset!.gltf.assetCopyright, '2026');
    expect(result.asset!.gltf.assetExtensions['EXT_asset'], {
      'source': 'fixture',
    });
    expect(result.asset!.gltf.assetExtras, {'asset': 1});
    expect(result.asset!.gltf.scene, 0);
    expect(result.asset!.gltf.scenes.single.nodes, [0]);
    expect(
      result.asset!.vrm.humanoid.nodeFor(VrmHumanoidBone.leftHand),
      _boneNodes[VrmHumanoidBone.leftHand],
    );
  });

  test('VRM GLB parser resolves external image URIs', () {
    final json = _minimalVrmJson();
    json['images'] = [
      {'uri': 'texture.png', 'mimeType': 'image/png'},
    ];
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
    var requestedUri = '';

    final result = VrmModel.tryParseGlb(
      _glb(json),
      uriResolver: (uri) {
        requestedUri = uri;
        return pngBytes;
      },
    );

    expect(result.validation.hasErrors, isFalse);
    expect(requestedUri, 'texture.png');
    expect(result.asset!.gltf.images.single.data, pngBytes);
  });

  test('reports malformed VRM root extension object', () {
    final json = _minimalVrmJson();
    final extensions = Map<String, Object?>.from(json['extensions']! as Map);
    json['extensions'] = extensions;
    extensions['VRMC_vrm'] = 'bad';

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('vrm.invalidExtensionObject'),
    );
  });

  test('reports missing required VRM root fields', () {
    final json = _minimalVrmJson();
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    vrm
      ..remove('meta')
      ..remove('humanoid');

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll(['vrm.missingMeta', 'vrm.missingHumanoid']),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      containsAll([
        r'$.extensions.VRMC_vrm.meta',
        r'$.extensions.VRMC_vrm.humanoid',
      ]),
    );
  });

  test('reports explicit null VRM object fields', () {
    final json =
        jsonDecode(jsonEncode(_minimalVrmJson())) as Map<String, Object?>;
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    vrm
      ..['meta'] = null
      ..['humanoid'] = null
      ..['firstPerson'] = null
      ..['expressions'] = null;

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'vrm.metaInvalidObject',
        'vrm.invalidHumanoidObject',
        'vrm.invalidFirstPersonObject',
        'vrm.invalidExpressionsObject',
      ]),
    );
  });

  test('reports missing VRM specVersion', () {
    final json = _minimalVrmJson();
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    vrm.remove('specVersion');

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('vrm.missingSpecVersion'),
    );
    expect(
      result.validation.errors.map((d) => d.code),
      isNot(contains('vrm.unsupportedSpecVersion')),
    );
  });

  test('warns when a VRM embeds a VRMA root extension', () {
    final json = _minimalVrmJson();
    final extensions = json['extensions']! as Map<String, Object?>;
    extensions['VRMC_vrm_animation'] = {'specVersion': '1.0'};
    (json['extensionsUsed']! as List<Object?>).add('VRMC_vrm_animation');

    final result = VrmModel.tryParseGlb(_glb(json));

    expect(result.asset, isNotNull);
    expect(result.validation.hasErrors, isFalse);
    expect(
      result.validation.warnings.map((d) => d.code),
      contains('vrm.embeddedVrmaExtension'),
    );
    expect(
      result.validation.warnings
          .singleWhere((d) => d.code == 'vrm.embeddedVrmaExtension')
          .jsonPath,
      r'$.extensions.VRMC_vrm_animation',
    );
    expect(result.asset!.gltf.extensions['VRMC_vrm_animation'], {
      'specVersion': '1.0',
    });
  });

  test('reports malformed GLB diagnostics instead of crashing', () {
    final result = VrmModel.tryParseGlb(Uint8List.fromList([1, 2, 3]));

    expect(result.asset, isNull);
    expect(result.validation.hasErrors, isTrue);
    expect(result.validation.errors.single.code, 'glb.tooShort');
  });

  test('reports malformed GLB JSON UTF-8 instead of throwing', () {
    final result = GltfAsset.tryParse(
      bytes: _glbChunks([
        MapEntry(0x4e4f534a, Uint8List.fromList([0xff, 0xff, 0xff, 0xff])),
      ]),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.badUtf8'),
    );
  });

  test('reports malformed JSON glTF instead of throwing', () {
    final badJson = GltfAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode('{')),
      validation: VrmValidationMode.permissive,
    );
    final badRoot = GltfAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode('[]')),
      validation: VrmValidationMode.permissive,
    );

    expect(badJson.asset, isNull);
    expect(badJson.validation.errors.single.code, 'gltf.badJson');
    expect(badRoot.asset, isNull);
    expect(badRoot.validation.errors.single.code, 'gltf.rootNotObject');
  });

  test('reports unaligned GLB chunk length in permissive mode', () {
    var jsonBytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
        }),
      ),
    );
    if (jsonBytes.length % 4 == 0) {
      jsonBytes = Uint8List.fromList([...jsonBytes, 0x20]);
    }
    final bytes = Uint8List(20 + jsonBytes.length);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, 0x46546c67, Endian.little);
    data.setUint32(4, 2, Endian.little);
    data.setUint32(8, bytes.length, Endian.little);
    data.setUint32(12, jsonBytes.length, Endian.little);
    data.setUint32(16, 0x4e4f534a, Endian.little);
    bytes.setRange(20, bytes.length, jsonBytes);

    final result = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('glb.invalidChunkLength'),
    );
  });

  test('reports non-space GLB JSON chunk padding', () {
    final json = <String, Object?>{
      'asset': {'version': '2.0'},
      'extras': '',
    };
    var jsonBytesLength = utf8.encode(jsonEncode(json)).length;
    while (jsonBytesLength % 4 == 0) {
      json['extras'] = '${json['extras']}x';
      jsonBytesLength = utf8.encode(jsonEncode(json)).length;
    }
    final bytes = _glb(json);
    bytes[20 + jsonBytesLength] = 0x09;

    final result = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('glb.invalidJsonChunkPadding'),
    );

    final zeroPadded = _glb(json);
    zeroPadded[20 + jsonBytesLength] = 0x00;
    final zeroResult = GltfAsset.tryParse(
      bytes: zeroPadded,
      validation: VrmValidationMode.permissive,
    );

    expect(
      zeroResult.validation.errors.map((d) => d.code),
      contains('glb.invalidJsonChunkPadding'),
    );
  });

  test('does not read past declared GLB length', () {
    final bytes = _glb({
      'asset': {'version': '2.0'},
    });
    final data = ByteData.sublistView(bytes);
    data.setUint32(8, 20, Endian.little);

    final result = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll(['glb.badLength', 'glb.truncatedChunk']),
    );
  });

  test('reports duplicate GLB chunks in permissive mode', () {
    final jsonChunk = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
        }),
      ),
    );
    final bytes = _glbChunks([
      MapEntry(0x4e4f534a, jsonChunk),
      MapEntry(0x004e4942, Uint8List(4)),
      MapEntry(0x4e4f534a, jsonChunk),
      MapEntry(0x004e4942, Uint8List(4)),
    ]);

    final result = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll(['glb.duplicateJsonChunk', 'glb.duplicateBinChunk']),
    );
  });

  test('reports GLB BIN chunks that are not second', () {
    final jsonChunk = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
        }),
      ),
    );
    final bytes = _glbChunks([
      MapEntry(0x4e4f534a, jsonChunk),
      MapEntry(0x12345678, Uint8List(4)),
      MapEntry(0x004e4942, Uint8List(4)),
    ]);

    final strict = GltfAsset.tryParse(bytes: bytes);
    final permissive = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(strict.asset, isNull);
    expect(permissive.asset, isNotNull);
    expect(
      strict.validation.errors.map((d) => d.code),
      contains('glb.binChunkNotSecond'),
    );
  });

  test('exposes GLB BIN chunk bytes as buffer data', () {
    final binary = Uint8List.fromList([1, 2, 3, 4]);
    final result = GltfAsset.tryParse(
      bytes: _glb({
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': 4},
        ],
      }, binaryChunk: binary),
    );

    expect(result.validation.hasErrors, isFalse);
    expect(result.asset!.binaryChunk, binary);
    expect(result.asset!.buffers.single.data, binary);
  });

  test(
    'generic glTF parser rejects unsupported required extensions in strict mode',
    () {
      final json = {
        'asset': {'version': '2.0'},
        'extensionsRequired': ['VENDOR_required_extension'],
      };
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));

      final strict = GltfAsset.tryParse(bytes: bytes);
      final permissive = GltfAsset.tryParse(
        bytes: bytes,
        validation: VrmValidationMode.permissive,
      );

      expect(strict.asset, isNull);
      expect(
        strict.validation.errors.map((d) => d.code),
        contains('gltf.unsupportedRequiredExtension'),
      );
      expect(
        strict.validation.errors
            .where((d) => d.code == 'gltf.unsupportedRequiredExtension')
            .map((d) => d.jsonPath),
        contains(r'$.extensionsRequired[0]'),
      );
      expect(permissive.asset, isNotNull);
    },
  );

  test('generic glTF parser reports malformed root extension lists', () {
    final invalidItems = GltfAsset.tryParse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'extensionsUsed': ['KHR_materials_unlit', 1],
            'extensionsRequired': 'VENDOR_required_extension',
          }),
        ),
      ),
      validation: VrmValidationMode.permissive,
    );
    final emptyLists = GltfAsset.tryParse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'extensionsUsed': <Object?>[],
            'extensionsRequired': <Object?>[],
          }),
        ),
      ),
      validation: VrmValidationMode.permissive,
    );

    expect(invalidItems.asset, isNotNull);
    expect(
      invalidItems.validation.errors.map((d) => d.code),
      containsAll([
        'gltf.invalidExtensionsUsed',
        'gltf.invalidExtensionsRequired',
      ]),
    );
    expect(
      invalidItems.validation.errors.map((d) => d.jsonPath),
      containsAll([r'$.extensionsUsed[1]', r'$.extensionsRequired']),
    );
    expect(emptyLists.asset, isNotNull);
    expect(
      emptyLists.validation.errors.map((d) => d.code),
      containsAll([
        'gltf.invalidExtensionsUsed',
        'gltf.invalidExtensionsRequired',
      ]),
    );
    expect(
      emptyLists.validation.errors.map((d) => d.jsonPath),
      containsAll([r'$.extensionsUsed', r'$.extensionsRequired']),
    );
  });

  test('generic glTF parser validates root extension list consistency', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'extensionsUsed': ['KHR_materials_unlit', 'KHR_materials_unlit'],
          'extensionsRequired': [
            'KHR_materials_unlit',
            'KHR_materials_emissive_strength',
            'KHR_materials_unlit',
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
        'gltf.duplicateExtensionUsed',
        'gltf.duplicateExtensionRequired',
        'gltf.requiredExtensionNotUsed',
      ]),
    );
    expect(
      strict.validation.errors
          .where((d) => d.code == 'gltf.requiredExtensionNotUsed')
          .map((d) => d.jsonPath),
      contains(r'$.extensionsRequired[1]'),
    );
  });

  test('generic glTF parser rejects default scene without scenes', () {
    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'scene': 0,
          }),
        ),
      ),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.defaultSceneWithoutScenes'),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      contains(r'$.scene'),
    );
  });

  test(
    'generic glTF parser reports extension objects missing from used list',
    () {
      final bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'nodes': [
              {
                'extensions': {'VENDOR_node_extension': true},
              },
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
        contains('gltf.extensionNotUsed'),
      );
      expect(
        strict.validation.errors
            .singleWhere((d) => d.code == 'gltf.extensionNotUsed')
            .jsonPath,
        r'$.nodes[0].extensions.VENDOR_node_extension',
      );
    },
  );

  test('generic glTF parser ignores extension-shaped data in extras', () {
    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {
              'version': '2.0',
              'extras': {
                'extensions': {'VENDOR_assetNote': <String, Object?>{}},
              },
            },
            'extras': {
              'extensions': {'VENDOR_rootNote': <String, Object?>{}},
            },
            'nodes': [
              {
                'extras': {
                  'extensions': {'VENDOR_nodeNote': <String, Object?>{}},
                },
              },
            ],
          }),
        ),
      ),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      isNot(contains('gltf.extensionNotUsed')),
    );
  });

  test('generic glTF parser reports malformed root extensions object', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'extensions': 'bad',
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
      contains('gltf.invalidExtensionsObject'),
    );
    expect(
      strict.validation.errors.map((d) => d.jsonPath),
      contains(r'$.extensions'),
    );
  });

  test('generic glTF parser reports malformed leaf extensions object', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'nodes': [
            {'extensions': 'bad'},
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
      contains('gltf.invalidExtensionsObject'),
    );
    expect(
      strict.validation.errors.map((d) => d.jsonPath),
      contains(r'$.nodes[0].extensions'),
    );
  });

  test('generic glTF parser reports malformed asset metadata', () {
    final missing = Uint8List.fromList(utf8.encode(jsonEncode({})));
    final invalid = Uint8List.fromList(
      utf8.encode(jsonEncode({'asset': 'bad'})),
    );

    final missingStrict = GltfAsset.tryParse(bytes: missing);
    final missingPermissive = GltfAsset.tryParse(
      bytes: missing,
      validation: VrmValidationMode.permissive,
    );
    final invalidStrict = GltfAsset.tryParse(bytes: invalid);
    final invalidPermissive = GltfAsset.tryParse(
      bytes: invalid,
      validation: VrmValidationMode.permissive,
    );

    expect(missingStrict.asset, isNull);
    expect(invalidStrict.asset, isNull);
    expect(missingPermissive.asset, isNotNull);
    expect(invalidPermissive.asset, isNotNull);
    expect(
      missingStrict.validation.errors.map((d) => d.code),
      contains('gltf.missingAsset'),
    );
    expect(
      invalidStrict.validation.errors.map((d) => d.code),
      contains('gltf.invalidAssetObject'),
    );
    expect(
      invalidStrict.validation.errors.map((d) => d.code),
      isNot(contains('gltf.unsupportedVersion')),
    );
  });

  test('generic glTF parser validates asset version shape', () {
    final missingVersion = Uint8List.fromList(
      utf8.encode(jsonEncode({'asset': <String, Object?>{}})),
    );
    final malformedVersion = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2'},
        }),
      ),
    );
    final patchVersion = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0.1'},
        }),
      ),
    );
    final unsupportedVersion = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '1.0'},
        }),
      ),
    );

    final missingResult = GltfAsset.tryParse(
      bytes: missingVersion,
      validation: VrmValidationMode.permissive,
    );
    final malformedResult = GltfAsset.tryParse(
      bytes: malformedVersion,
      validation: VrmValidationMode.permissive,
    );
    final patchResult = GltfAsset.tryParse(
      bytes: patchVersion,
      validation: VrmValidationMode.permissive,
    );
    final unsupportedResult = GltfAsset.tryParse(
      bytes: unsupportedVersion,
      validation: VrmValidationMode.permissive,
    );

    expect(missingResult.asset, isNotNull);
    expect(malformedResult.asset, isNotNull);
    expect(patchResult.asset, isNotNull);
    expect(unsupportedResult.asset, isNotNull);
    expect(
      missingResult.validation.errors.map((d) => d.code),
      contains('gltf.invalidAssetVersion'),
    );
    expect(
      malformedResult.validation.errors.map((d) => d.code),
      contains('gltf.invalidAssetVersion'),
    );
    expect(
      malformedResult.validation.errors.map((d) => d.code),
      isNot(contains('gltf.unsupportedVersion')),
    );
    expect(
      patchResult.validation.errors.map((d) => d.code),
      contains('gltf.invalidAssetVersion'),
    );
    expect(
      unsupportedResult.validation.errors.map((d) => d.code),
      contains('gltf.unsupportedVersion'),
    );
  });

  test('generic glTF parser validates asset minVersion', () {
    final invalidType = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0', 'minVersion': 2},
        }),
      ),
    );
    final tooNew = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0', 'minVersion': '2.1'},
        }),
      ),
    );
    final malformedVersion = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0', 'minVersion': '2.0.1'},
        }),
      ),
    );

    final invalidTypeResult = GltfAsset.tryParse(
      bytes: invalidType,
      validation: VrmValidationMode.permissive,
    );
    final tooNewResult = GltfAsset.tryParse(
      bytes: tooNew,
      validation: VrmValidationMode.permissive,
    );
    final malformedResult = GltfAsset.tryParse(
      bytes: malformedVersion,
      validation: VrmValidationMode.permissive,
    );

    expect(invalidTypeResult.asset, isNotNull);
    expect(tooNewResult.asset, isNotNull);
    expect(malformedResult.asset, isNotNull);
    expect(
      invalidTypeResult.validation.errors.map((d) => d.code),
      contains('gltf.invalidAssetMinVersion'),
    );
    expect(
      tooNewResult.validation.errors.map((d) => d.code),
      contains('gltf.invalidAssetMinVersion'),
    );
    expect(
      malformedResult.validation.errors.map((d) => d.code),
      contains('gltf.invalidAssetMinVersion'),
    );
    expect(
      tooNewResult.validation.errors.map((d) => d.jsonPath),
      contains(r'$.asset.minVersion'),
    );
  });

  test('generic glTF parser validates asset metadata strings', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0', 'copyright': [], 'generator': 1},
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
      containsAll(['gltf.invalidAssetCopyright', 'gltf.invalidAssetGenerator']),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      containsAll([r'$.asset.copyright', r'$.asset.generator']),
    );
  });

  test('generic glTF parser reports malformed root arrays', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'nodes': 'bad',
          'materials': [],
          'buffers': [1],
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
        'gltf.invalidRootArray',
        'gltf.emptyRootArray',
        'gltf.invalidRootArrayItem',
      ]),
    );
    expect(
      strict.validation.errors.map((d) => d.jsonPath),
      containsAll([r'$.nodes', r'$.materials', r'$.buffers[0]']),
    );
  });

  test('generic glTF parser validates root object names', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'nodes': [
            {'name': 1},
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
      contains('gltf.invalidName'),
    );
    expect(
      strict.validation.errors.map((d) => d.jsonPath),
      contains(r'$.nodes[0].name'),
    );
  });

  test('generic glTF parser rejects unsupported external buffer URIs', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {'byteLength': 4, 'uri': 'mesh.bin'},
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
      contains('gltf.unsupportedExternalBufferUri'),
    );
  });

  test('generic glTF parser resolves external buffer URIs', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {'byteLength': 4, 'uri': 'mesh.bin'},
          ],
        }),
      ),
    );
    var requestedUri = '';

    final result = GltfAsset.tryParse(
      bytes: bytes,
      uriResolver: (uri) {
        requestedUri = uri;
        return Uint8List.fromList([1, 2, 3, 4]);
      },
    );

    expect(result.validation.hasErrors, isFalse);
    expect(requestedUri, 'mesh.bin');
    expect(result.asset!.buffers.single.data, [1, 2, 3, 4]);
  });

  test('generic glTF parser reports unresolved external URIs', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {'byteLength': 4, 'uri': 'mesh.bin'},
          ],
          'images': [
            {'uri': 'texture.png', 'mimeType': 'image/png'},
          ],
        }),
      ),
    );

    final result = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
      uriResolver: (_) => null,
    );

    expect(result.asset, isNotNull);
    expect(result.validation.errors.map((d) => d.code), [
      contains('gltf.unresolvedExternalBufferUri'),
      contains('gltf.unresolvedExternalImageUri'),
    ]);
    expect(
      result.validation.errors.map((d) => d.code),
      isNot(contains('gltf.unsupportedExternalBufferUri')),
    );
    expect(
      result.validation.errors.map((d) => d.code),
      isNot(contains('gltf.unsupportedExternalImageUri')),
    );
  });

  test('generic glTF parser reports external URI resolver failures', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {'byteLength': 4, 'uri': 'mesh.bin'},
          ],
        }),
      ),
    );

    final result = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
      uriResolver: (_) => throw StateError('missing fixture'),
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors
          .singleWhere((d) => d.code == 'gltf.unresolvedExternalBufferUri')
          .message,
      contains('missing fixture'),
    );
  });

  test('generic glTF parser validates buffer data URI metadata', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {'byteLength': 4, 'uri': 'data:text/plain;base64,AAAAAA=='},
            {'byteLength': 4, 'uri': 'data:application/octet-stream,ABCD'},
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
      strict.validation.errors
          .where((d) => d.code == 'gltf.invalidBufferDataUri')
          .length,
      2,
    );
    expect(
      strict.validation.errors
          .where((d) => d.code == 'gltf.invalidBufferDataUri')
          .map((d) => d.jsonPath),
      containsAll([r'$.buffers[0].uri', r'$.buffers[1].uri']),
    );
  });

  test('generic glTF parser reports invalid buffer data URI payloads', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {'byteLength': 1, 'uri': 'data:application/octet-stream;base64'},
            {'byteLength': 1, 'uri': 'data:application/octet-stream;base64,?'},
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
      strict.validation.errors
          .where((d) => d.code == 'gltf.invalidBufferDataUri')
          .map((d) => d.jsonPath),
      containsAll([r'$.buffers[0].uri', r'$.buffers[1].uri']),
    );
  });

  test('generic glTF parser rejects JSON buffers without URIs', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {'byteLength': 4},
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
      contains('gltf.missingBufferUri'),
    );
    expect(
      strict.validation.errors.map((d) => d.jsonPath),
      contains(r'$.buffers[0].uri'),
    );
  });

  test('generic glTF parser reports invalid image MIME types', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {'byteLength': 4},
          ],
          'bufferViews': [
            {'buffer': 0, 'byteLength': 4},
          ],
          'images': [
            {'bufferView': 0, 'mimeType': 'image/gif'},
            {'uri': 'data:image/gif;base64,', 'mimeType': 'image/gif'},
            {'uri': 'texture.png'},
            {'uri': 'data:image/png;base64,', 'mimeType': 'image/jpeg'},
            {
              'uri':
                  'data:image/png;base64,${base64.encode(Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]))}',
            },
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
      strict.validation.errors
          .where((d) => d.code == 'gltf.invalidImageMimeType')
          .length,
      2,
    );
    expect(
      strict.validation.errors.map((d) => d.code),
      contains('gltf.unsupportedExternalImageUri'),
    );
    expect(
      strict.validation.errors.map((d) => d.code),
      contains('gltf.imageMimeTypeMismatch'),
    );
    expect(
      strict.validation.errors.map((d) => d.code),
      contains('gltf.invalidImageData'),
    );
  });

  test('generic glTF parser resolves external image URIs', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'images': [
            {'uri': 'texture.png', 'mimeType': 'image/png'},
          ],
        }),
      ),
    );
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
    var requestedUri = '';

    final result = GltfAsset.tryParse(
      bytes: bytes,
      uriResolver: (uri) {
        requestedUri = uri;
        return pngBytes;
      },
    );

    expect(result.validation.hasErrors, isFalse);
    expect(requestedUri, 'texture.png');
    expect(result.asset!.images.single.data, pngBytes);
  });

  test('generic glTF parser exposes bufferView image bytes', () {
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
    final result = GltfAsset.tryParse(
      bytes: _glb({
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': pngBytes.length},
        ],
        'bufferViews': [
          {'buffer': 0, 'byteLength': pngBytes.length},
        ],
        'images': [
          {'bufferView': 0, 'mimeType': 'image/png'},
        ],
      }, binaryChunk: pngBytes),
    );

    expect(result.validation.hasErrors, isFalse);
    expect(result.asset!.images.single.data, pngBytes);
  });

  test('generic glTF parser validates image data URI media type', () {
    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'images': [
              {'uri': 'data:image/gif;base64,'},
            ],
          }),
        ),
      ),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidImageMimeType'),
    );
  });

  test('generic glTF parser reports invalid image data URI payloads', () {
    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'images': [
              {'uri': 'data:image/png;base64,not base64'},
              {'uri': 'data:image/png,%'},
              {'uri': 'data:image/png;base64'},
            ],
          }),
        ),
      ),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.where(
        (d) => d.code == 'gltf.invalidImageDataUri',
      ),
      hasLength(3),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidImageDataUri')
          .map((d) => d.jsonPath),
      containsAll([r'$.images[0].uri', r'$.images[1].uri', r'$.images[2].uri']),
    );
  });

  test('generic glTF parser warns for texture without source', () {
    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'asset': {'version': '2.0'},
            'textures': [
              {'sampler': 0},
            ],
            'samplers': [<String, Object?>{}],
          }),
        ),
      ),
    );

    expect(result.asset, isNotNull);
    expect(result.validation.hasErrors, isFalse);
    expect(
      result.validation.warnings.map((d) => d.code),
      contains('gltf.textureWithoutSource'),
    );
    expect(
      result.validation.warnings.map((d) => d.jsonPath),
      contains(r'$.textures[0]'),
    );
  });

  test('generic glTF parser reports invalid material texture texCoord', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'textures': [<String, Object?>{}],
          'materials': [
            {
              'pbrMetallicRoughness': {
                'baseColorTexture': {'index': 0, 'texCoord': 'bad'},
                'metallicRoughnessTexture': {'index': 0, 'texCoord': -1},
              },
              'normalTexture': {'index': 0, 'texCoord': 1},
            },
            {'pbrMetallicRoughness': 'bad', 'normalTexture': 'bad'},
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
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidTextureTexCoord')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidTextureTexCoord')
          .map((d) => d.jsonPath),
      containsAll([
        r'$.materials[0].pbrMetallicRoughness.baseColorTexture.texCoord',
        r'$.materials[0].pbrMetallicRoughness.metallicRoughnessTexture.texCoord',
      ]),
    );
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'gltf.invalidMaterialPbrMetallicRoughness',
        'gltf.invalidMaterialNormalTexture',
      ]),
    );
  });

  test('generic glTF parser reports malformed animation arrays', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'animations': [
            <String, Object?>{},
            {'channels': [], 'samplers': []},
            {'channels': 'bad', 'samplers': 'bad'},
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
        'gltf.missingAnimationChannels',
        'gltf.missingAnimationSamplers',
        'gltf.invalidAnimationChannels',
        'gltf.invalidAnimationSamplers',
      ]),
    );
    expect(
      strict.validation.errors.map((d) => d.jsonPath),
      containsAll([
        r'$.animations[0].channels',
        r'$.animations[0].samplers',
        r'$.animations[2].channels',
        r'$.animations[2].samplers',
      ]),
    );
  });

  test('generic glTF parser reports malformed animation channel targets', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'animations': [
            {
              'channels': [
                {'sampler': 0, 'target': 'bad'},
                {'sampler': 0},
                {
                  'sampler': 0,
                  'target': {'path': 1},
                },
              ],
              'samplers': [<String, Object?>{}],
            },
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
        'gltf.invalidAnimationTarget',
        'gltf.invalidAnimationTargetPath',
        'gltf.missingAnimationTarget',
      ]),
    );
    expect(
      strict.validation.errors.map((d) => d.code),
      isNot(contains('gltf.missingAnimationTargetPath')),
    );
    expect(
      strict.validation.errors.map((d) => d.jsonPath),
      containsAll([
        r'$.animations[0].channels[0].target',
        r'$.animations[0].channels[1].target',
        r'$.animations[0].channels[2].target.path',
      ]),
    );
  });

  test('generic glTF parser reports malformed animation item objects', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'animations': [
            {
              'channels': ['bad'],
              'samplers': ['bad'],
            },
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
        'gltf.invalidAnimationChannelObject',
        'gltf.invalidAnimationSamplerObject',
      ]),
    );
    expect(
      strict.validation.errors.map((d) => d.jsonPath),
      containsAll([
        r'$.animations[0].channels[0]',
        r'$.animations[0].samplers[0]',
      ]),
    );
    final codes = strict.validation.errors.map((d) => d.code);
    expect(codes, isNot(contains('gltf.missingAnimationSampler')));
    expect(codes, isNot(contains('gltf.missingAnimationTarget')));
    expect(codes, isNot(contains('gltf.missingAnimationInput')));
    expect(codes, isNot(contains('gltf.missingAnimationOutput')));
  });

  test('generic glTF parser warns for animation target without node', () {
    final binary = _floats([0.0, 0.0, 0.0, 0.0]);
    final json = <String, Object?>{
      'asset': {'version': '2.0'},
    };
    json.addAll(
      _animationStorageJson(binary.length, [
        [0, 4],
        [4, 12],
      ]),
    );
    json['animations'] = [
      {
        'channels': [
          {
            'sampler': 0,
            'target': {'path': 'translation'},
          },
        ],
        'samplers': [
          {'input': 0, 'output': 1},
        ],
      },
    ];

    final result = GltfAsset.tryParse(bytes: _glb(json, binaryChunk: binary));

    expect(result.asset, isNotNull);
    expect(result.validation.hasErrors, isFalse);
    expect(
      result.validation.warnings.map((d) => d.code),
      contains('gltf.animationTargetWithoutNode'),
    );
  });

  test('generic glTF parser reports malformed mesh primitive arrays', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'meshes': [
            <String, Object?>{},
            {'primitives': []},
            {'primitives': 'bad'},
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
      containsAll(['gltf.missingMeshPrimitives', 'gltf.invalidMeshPrimitives']),
    );
  });

  test('generic glTF parser reports invalid node hierarchy', () {
    final json = {
      'asset': {'version': '2.0'},
      'scene': 0,
      'scenes': [
        {
          'nodes': [0, 0],
        },
        {'nodes': <Object?>[]},
      ],
      'nodes': [
        {
          'children': [1, 1],
        },
        {
          'children': [0, 2],
        },
        <String, Object?>{},
        {
          'children': [2],
        },
        {'children': <Object?>[]},
      ],
      'skins': [
        {'joints': <Object?>[]},
      ],
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));

    final result = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'gltf.nodeCycle',
        'gltf.duplicateNodeChild',
        'gltf.duplicateSceneNode',
        'gltf.nodeMultipleParents',
        'gltf.sceneRootHasParent',
        'gltf.invalidSceneNode',
        'gltf.invalidNodeChild',
        'gltf.invalidSkinJoint',
      ]),
    );
    Iterable<String?> pathsFor(String code) => result.validation.errors
        .where((diagnostic) => diagnostic.code == code)
        .map((diagnostic) => diagnostic.jsonPath);

    expect(
      pathsFor('gltf.duplicateSceneNode'),
      contains(r'$.scenes[0].nodes[1]'),
    );
    expect(
      pathsFor('gltf.duplicateNodeChild'),
      contains(r'$.nodes[0].children[1]'),
    );
    expect(
      pathsFor('gltf.nodeMultipleParents'),
      contains(r'$.nodes[3].children[0]'),
    );
    expect(
      pathsFor('gltf.sceneRootHasParent'),
      contains(r'$.scenes[0].nodes[0]'),
    );
    expect(pathsFor('gltf.nodeCycle'), contains(r'$.nodes[0].children'));
  });

  test('generic glTF parser reports invalid accessor layout', () {
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': 24,
          'uri':
              'data:application/octet-stream;base64,${base64.encode(Uint8List(24))}',
        },
      ],
      'bufferViews': [
        {
          'buffer': 0,
          'byteOffset': 1,
          'byteLength': 6,
          'byteStride': 6,
          'target': 34962,
        },
        {'buffer': 0, 'byteOffset': 8, 'byteLength': 12, 'target': 34963},
      ],
      'accessors': [
        {'bufferView': 0, 'componentType': 5123, 'count': 1, 'type': 'SCALAR'},
        {
          'byteOffset': 4,
          'componentType': 5126,
          'count': 1,
          'type': 'SCALAR',
          'normalized': true,
        },
        {
          'componentType': 5126,
          'count': 1,
          'type': 'VEC3',
          'min': [1.0, 0.0, 0.0],
          'max': [0.0, 0.0, 0.0],
        },
        {'componentType': 5126, 'count': 1, 'type': 'VEC3'},
        {
          'componentType': 5126,
          'count': 1,
          'type': 'VEC3',
          'min': [0.0],
          'max': [0.0],
        },
        {'componentType': 5126, 'count': 2, 'type': 'VEC3'},
        {'bufferView': 1, 'componentType': 5126, 'count': 1, 'type': 'VEC3'},
      ],
      'meshes': [
        {
          'weights': [0.5, 'bad'],
          'primitives': [
            {
              'indices': 2,
              'attributes': {
                'POSITION': 3,
                'NORMAL': 5,
                'TANGENT': 1,
                'COLOR_0': 6,
              },
              'targets': [
                {'POSITION': 5, 'NORMAL': 6, 'TANGENT': 1, 'TEXCOORD_0': 5},
              ],
            },
            {
              'indices': 0,
              'attributes': {'POSITION': 3},
            },
            {
              'mode': 'bad',
              'material': 'bad',
              'indices': 'bad',
              'attributes': {'POSITION': 'bad'},
              'targets': [
                {'POSITION': 'bad'},
              ],
            },
          ],
        },
      ],
      'nodes': [
        {
          'mesh': 0,
          'weights': [0.1, 'bad'],
        },
      ],
      'animations': [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 1, 'output': 3},
          ],
        },
      ],
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));

    final result = GltfAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'gltf.accessorByteOffsetWithoutBufferView',
        'gltf.invalidAccessorAlignment',
        'gltf.invalidAccessorBounds',
        'gltf.invalidAccessorMax',
        'gltf.invalidAccessorMin',
        'gltf.invalidAccessorNormalized',
        'gltf.invalidBufferViewStride',
        'gltf.invalidMeshWeights',
        'gltf.invalidNodeWeights',
        'gltf.invalidPrimitiveAttributeAccessor',
        'gltf.invalidPrimitiveAttributeBufferViewTarget',
        'gltf.invalidPrimitiveAttribute',
        'gltf.invalidPrimitiveIndices',
        'gltf.invalidPrimitiveIndicesBufferViewTarget',
        'gltf.invalidPrimitiveIndicesAccessor',
        'gltf.invalidPrimitiveMaterial',
        'gltf.invalidPrimitiveMode',
        'gltf.invalidPrimitiveTarget',
        'gltf.invalidPrimitiveTargetAccessor',
        'gltf.invalidPrimitiveTargetBufferViewTarget',
        'gltf.mismatchedPrimitiveAttributeCount',
        'gltf.mismatchedPrimitiveMorphTargetCount',
        'gltf.mismatchedPrimitiveTargetCount',
        'gltf.missingMorphTargetPositionAccessorBounds',
        'gltf.missingPrimitiveMorphTargetBase',
        'gltf.missingAnimationInputAccessorBounds',
        'gltf.missingPositionAccessorBounds',
      ]),
    );
    Iterable<String?> pathsFor(String code) => result.validation.errors
        .where((diagnostic) => diagnostic.code == code)
        .map((diagnostic) => diagnostic.jsonPath);

    expect(
      pathsFor('gltf.accessorByteOffsetWithoutBufferView'),
      contains(r'$.accessors[1].byteOffset'),
    );
    expect(
      pathsFor('gltf.invalidAccessorAlignment'),
      contains(r'$.accessors[0].byteOffset'),
    );
    expect(
      pathsFor('gltf.invalidAccessorBounds'),
      contains(r'$.accessors[2].min'),
    );
    expect(
      pathsFor('gltf.invalidAccessorMin'),
      contains(r'$.accessors[4].min'),
    );
    expect(
      pathsFor('gltf.invalidAccessorMax'),
      contains(r'$.accessors[4].max'),
    );
    expect(
      pathsFor('gltf.invalidAccessorNormalized'),
      contains(r'$.accessors[1].normalized'),
    );
    expect(
      pathsFor('gltf.invalidBufferViewStride'),
      contains(r'$.bufferViews[0].byteStride'),
    );
    expect(
      pathsFor('gltf.invalidMeshWeights'),
      contains(r'$.meshes[0].weights'),
    );
    expect(
      pathsFor('gltf.invalidPrimitiveMode'),
      contains(r'$.meshes[0].primitives[2].mode'),
    );
    expect(
      pathsFor('gltf.invalidPrimitiveMaterial'),
      contains(r'$.meshes[0].primitives[2].material'),
    );
    expect(
      pathsFor('gltf.invalidPrimitiveIndices'),
      contains(r'$.meshes[0].primitives[2].indices'),
    );
    expect(
      pathsFor('gltf.invalidPrimitiveIndicesBufferViewTarget'),
      contains(r'$.meshes[0].primitives[1].indices'),
    );
    expect(
      pathsFor('gltf.invalidPrimitiveAttribute'),
      contains(r'$.meshes[0].primitives[2].attributes'),
    );
    expect(
      pathsFor('gltf.invalidPrimitiveAttributeBufferViewTarget'),
      contains(r'$.meshes[0].primitives[0].attributes.COLOR_0'),
    );
    expect(
      pathsFor('gltf.invalidPrimitiveTarget'),
      contains(r'$.meshes[0].primitives[2].targets[0]'),
    );
    expect(
      pathsFor('gltf.invalidPrimitiveTargetBufferViewTarget'),
      contains(r'$.meshes[0].primitives[0].targets[0].NORMAL'),
    );
    expect(
      pathsFor('gltf.mismatchedPrimitiveTargetCount'),
      contains(r'$.meshes[0].primitives[1].targets'),
    );
  });

  test('generic glTF parser validates unused bufferView stride limits', () {
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
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 16, 'byteStride': 3},
      ],
    };

    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidBufferViewStride'),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      contains(r'$.bufferViews[0].byteStride'),
    );
  });

  test('generic glTF parser rejects stride outside vertex attributes', () {
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
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 16, 'byteStride': 4},
      ],
    };

    final result = GltfAsset.tryParse(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidBufferViewStride'),
    );
  });

  test('generic glTF parser requires stride for shared vertex bufferViews', () {
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [
        {
          'byteLength': 24,
          'uri':
              'data:application/octet-stream;base64,${base64.encode(Uint8List(24))}',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 24},
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
        {
          'bufferView': 0,
          'byteOffset': 12,
          'componentType': 5126,
          'count': 1,
          'type': 'VEC3',
        },
      ],
      'meshes': [
        {
          'primitives': [
            {
              'attributes': {'POSITION': 0, 'NORMAL': 1},
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
      contains('gltf.missingBufferViewStride'),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      contains(r'$.bufferViews[0].byteStride'),
    );
  });

  test('generic glTF parser validates vertex attribute offset alignment', () {
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
        {
          'bufferView': 0,
          'byteOffset': 2,
          'componentType': 5123,
          'count': 1,
          'type': 'VEC4',
        },
      ],
      'meshes': [
        {
          'primitives': [
            {
              'attributes': {'JOINTS_0': 0},
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
      contains('gltf.invalidAccessorAlignment'),
    );
  });

  test('generic glTF parser validates vertex attribute accessor shapes', () {
    final json = {
      'asset': {'version': '2.0'},
      'accessors': [
        {'componentType': 5126, 'count': 1, 'type': 'VEC3'},
        {'componentType': 5121, 'count': 1, 'type': 'VEC2'},
        {'componentType': 5126, 'count': 1, 'type': 'VEC2'},
        {'componentType': 5123, 'count': 1, 'type': 'VEC3'},
        {'componentType': 5125, 'count': 1, 'type': 'VEC4'},
        {'componentType': 5123, 'count': 1, 'type': 'VEC4'},
        {'componentType': 5126, 'count': 1, 'type': 'VEC3'},
        {'componentType': 5126, 'count': 1, 'type': 'VEC2'},
        {'componentType': 5121, 'count': 1, 'type': 'VEC4', 'normalized': true},
        {'componentType': 5121, 'count': 1, 'type': 'VEC4'},
        {'componentType': 5121, 'count': 1, 'type': 'VEC4', 'normalized': true},
      ],
      'meshes': [
        {
          'primitives': [
            {
              'attributes': {
                'TEXCOORD_0': 0,
                'TEXCOORD_1': 1,
                'COLOR_0': 2,
                'JOINTS_0': 3,
                'JOINTS_1': 4,
                'WEIGHTS_0': 5,
                'WEIGHTS_1': 6,
                'TEXCOORD_2': 7,
                'COLOR_1': 8,
                'JOINTS_2': 9,
                'WEIGHTS_2': 10,
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
        (d) => d.code == 'gltf.invalidPrimitiveAttributeAccessor',
      ),
      hasLength(7),
    );
  });

  test('runtime rest pose respects glTF node matrix transforms', () {
    final json = _minimalVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[0]
      ..remove('translation')
      ..['matrix'] = [
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        3.0,
        4.0,
        5.0,
        1.0,
      ];
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();
    final node = runtime.model.gltf.nodes[0];
    final trsNode = runtime.model.gltf.nodes[1];

    runtime.bind(binding);
    runtime.update(0);

    expect(identical(node.restTransform, node.restTransform), isTrue);
    expect(identical(node.restTranslation, node.restTranslation), isTrue);
    expect(identical(node.restRotation, node.restRotation), isTrue);
    expect(identical(node.restScale, node.restScale), isTrue);
    expect(identical(trsNode.restTransform, trsNode.restTransform), isTrue);
    expect(() => node.restTranslation.add(1), throwsUnsupportedError);
    expect(() => node.restRotation.add(1), throwsUnsupportedError);
    expect(() => node.restScale.add(1), throwsUnsupportedError);
    expect(binding.nodes[0]!.localTransform.storage[12], 3.0);
    expect(binding.nodes[0]!.localTransform.storage[13], 4.0);
    expect(binding.nodes[0]!.localTransform.storage[14], 5.0);
  });

  test('reports glTF node matrices that are not decomposable to TRS', () {
    final json = _minimalVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[0]
      ..remove('translation')
      ..['matrix'] = [
        1.0,
        0.0,
        0.0,
        0.0,
        0.5,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
      ];

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidNodeMatrixDecomposition'),
    );
  });

  test('reports invalid glTF node transform shapes in permissive mode', () {
    final json = _minimalVrmJson();
    json['scene'] = 'bad-scene';
    json['scenes'] = [
      {
        'nodes': [0, 'bad-scene-node'],
      },
    ];
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[0]
      ..['children'] = [1, 3, 6, 'bad-child']
      ..['translation'] = [1.0, 2.0]
      ..['matrix'] = [1.0, 0.0]
      ..['skin'] = 0;
    nodes[1]
      ..['rotation'] = [0.0, 0.0, 1.0]
      ..['mesh'] = 0
      ..['skin'] = 0;
    nodes[2]
      ..['scale'] = [1.0, 'bad', 1.0]
      ..['mesh'] = 'bad-mesh'
      ..['skin'] = 'bad-skin';
    nodes[3]['rotation'] = [0.0, 0.0, 0.0, 0.5];
    json['buffers'] = [
      {'byteLength': 64, 'uri': 3},
    ];
    json['bufferViews'] = [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 4, 'target': 34962},
      {'buffer': 0, 'byteOffset': 4, 'byteLength': 4, 'byteStride': 4},
      {'buffer': 0, 'byteOffset': 8, 'byteLength': 4},
      {'buffer': 0, 'byteOffset': 16, 'byteLength': 16, 'byteStride': 2},
      {'buffer': 0, 'byteOffset': 32, 'byteLength': 4, 'target': 7},
      {'buffer': 'bad', 'byteOffset': 36, 'byteLength': 4},
      {'buffer': 0, 'byteOffset': 'bad', 'byteLength': 4},
      {
        'buffer': 0,
        'byteOffset': 40,
        'byteLength': 4,
        'byteStride': 'bad',
        'target': 'bad',
      },
    ];
    json['accessors'] = [
      {'bufferView': 0, 'componentType': 9999, 'count': 1, 'type': 'SCALAR'},
      {'bufferView': 1, 'componentType': 5126, 'count': 1, 'type': 'VEC5'},
      {'bufferView': 2, 'componentType': 5126, 'count': 2, 'type': 'SCALAR'},
      {'bufferView': 3, 'componentType': 5126, 'count': 2, 'type': 'SCALAR'},
      {
        'componentType': 5126,
        'count': 1,
        'type': 'SCALAR',
        'sparse': {
          'count': 0,
          'indices': {'bufferView': 0, 'componentType': 5126},
          'values': {'bufferView': 1},
        },
      },
      {
        'componentType': 5126,
        'count': 2,
        'type': 'SCALAR',
        'sparse': {
          'count': 2,
          'indices': {'bufferView': 0, 'componentType': 5121},
          'values': {'bufferView': 3, 'byteOffset': 1},
        },
      },
      {'bufferView': 3, 'componentType': 5126, 'count': 1, 'type': 'MAT4'},
      {
        'bufferView': 'bad',
        'byteOffset': 'bad',
        'componentType': 5126,
        'count': 1,
        'type': 'SCALAR',
        'normalized': 'bad',
        'sparse': {
          'count': 'bad',
          'indices': {
            'bufferView': 'bad',
            'byteOffset': 'bad',
            'componentType': 'bad',
          },
          'values': {'bufferView': 'bad', 'byteOffset': 'bad'},
        },
      },
    ];
    json['skins'] = [
      {
        'joints': [0, 1, 1, 'bad-joint'],
        'inverseBindMatrices': 6,
      },
      {
        'joints': [0],
        'skeleton': 'bad-skeleton',
        'inverseBindMatrices': 'bad-inverse-bind-matrices',
      },
      <String, Object?>{},
    ];
    json['meshes'] = [
      {
        'primitives': [
          {'mode': 9},
        ],
      },
    ];
    json['animations'] = [
      {
        'channels': [
          {
            'sampler': 0,
            'target': {'node': 0, 'path': 'translation'},
          },
          {
            'sampler': 1,
            'target': {'node': 0, 'path': 'rotation'},
          },
          {
            'sampler': 0,
            'target': {'node': 0, 'path': 'color'},
          },
          {
            'sampler': 0,
            'target': {'node': 0, 'path': 'translation'},
          },
          {
            'target': {'node': 0, 'path': 'scale'},
          },
          {
            'sampler': 0,
            'target': {'node': 0},
          },
          {
            'sampler': 0,
            'target': {'node': 0, 'path': 3},
          },
          {
            'sampler': 'bad',
            'target': {'node': 'bad', 'path': 'weights'},
          },
        ],
        'samplers': [
          {'input': 0, 'output': 1, 'interpolation': 'BOUNCE'},
          {'input': 2, 'output': 3, 'interpolation': 'CUBICSPLINE'},
          <String, Object?>{},
          {'input': 0, 'output': 1, 'interpolation': 3},
          {'input': 'bad', 'output': 'bad'},
        ],
      },
    ];

    final result = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: _floats([0.0, 1.0])),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'gltf.nodeMatrixWithTrs',
        'gltf.invalidNodeMatrix',
        'gltf.invalidNodeTranslation',
        'gltf.invalidNodeRotation',
        'gltf.invalidNodeRotationQuaternion',
        'gltf.invalidNodeScale',
        'gltf.invalidSceneNode',
        'gltf.invalidDefaultScene',
        'gltf.invalidNodeChild',
        'gltf.invalidNodeMesh',
        'gltf.invalidNodeSkin',
        'gltf.invalidBufferUri',
        'gltf.bufferOutOfRange',
        'gltf.invalidBufferViewBuffer',
        'gltf.invalidBufferViewRange',
        'gltf.invalidAccessorBufferView',
        'gltf.invalidAccessorShape',
        'gltf.invalidAccessorComponentType',
        'gltf.invalidAccessorType',
        'gltf.invalidAccessorNormalized',
        'gltf.accessorOutOfRange',
        'gltf.invalidBufferViewStride',
        'gltf.invalidBufferViewTarget',
        'gltf.invalidSparseAccessor',
        'gltf.invalidSparseAccessorAlignment',
        'gltf.invalidSparseAccessorBufferView',
        'gltf.invalidSparseAccessorType',
        'gltf.invalidSparseAccessorIndices',
        'gltf.skinnedNodeMissingMesh',
        'gltf.skinnedPrimitiveMissingAttributes',
        'gltf.duplicateSkinJoint',
        'gltf.invalidSkinJoint',
        'gltf.invalidSkinSkeleton',
        'gltf.invalidSkinInverseBindMatrices',
        'gltf.invalidSkinInverseBindMatricesAccessor',
        'gltf.missingSkinJoints',
        'gltf.invalidPrimitiveMode',
        'gltf.invalidAnimationInterpolation',
        'gltf.invalidAnimationSampler',
        'gltf.invalidAnimationTargetNode',
        'gltf.invalidAnimationInput',
        'gltf.invalidAnimationInputAccessor',
        'gltf.invalidAnimationOutput',
        'gltf.invalidAnimationOutputAccessor',
        'gltf.invalidAnimationOutputCount',
        'gltf.invalidAnimationTargetPath',
        'gltf.duplicateAnimationTarget',
        'gltf.missingAnimationSampler',
        'gltf.missingAnimationTargetPath',
        'gltf.missingAnimationInput',
        'gltf.missingAnimationOutput',
      ]),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      containsAll([
        r'$.buffers[0].byteLength',
        r'$.buffers[0].uri',
        r'$.scenes[0].nodes[1]',
        r'$.nodes[0].matrix',
        r'$.nodes[0].translation',
        r'$.nodes[0].children[3]',
        r'$.nodes[0].mesh',
        r'$.nodes[2].mesh',
        r'$.nodes[2].skin',
        r'$.skins[0].joints[2]',
        r'$.skins[0].joints[3]',
        r'$.skins[0].inverseBindMatrices',
        r'$.skins[1].skeleton',
        r'$.skins[1].inverseBindMatrices',
        r'$.skins[2].joints',
        r'$.animations[0].samplers[0].input',
        r'$.animations[0].samplers[1].output',
        r'$.animations[0].channels[6].target.path',
        r'$.animations[0].samplers[3].interpolation',
      ]),
    );
    Iterable<String?> pathsFor(String code) => result.validation.errors
        .where((diagnostic) => diagnostic.code == code)
        .map((diagnostic) => diagnostic.jsonPath);

    expect(
      pathsFor('gltf.skinnedNodeMissingMesh'),
      contains(r'$.nodes[0].mesh'),
    );
    expect(
      pathsFor('gltf.duplicateSkinJoint'),
      contains(r'$.skins[0].joints[2]'),
    );
    expect(
      pathsFor('gltf.invalidAnimationInputAccessor'),
      contains(r'$.animations[0].samplers[0].input'),
    );
    expect(
      pathsFor('gltf.missingAnimationInputAccessorBounds'),
      contains(r'$.animations[0].samplers[0].input'),
    );
    expect(
      pathsFor('gltf.invalidAnimationOutputAccessor'),
      contains(r'$.animations[0].samplers[1].output'),
    );
    expect(
      pathsFor('gltf.invalidAnimationOutputCount'),
      contains(r'$.animations[0].samplers[1].output'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidBufferViewStride')
          .length,
      5,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidBufferViewTarget')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidSparseAccessorBufferView')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidSparseAccessorAlignment')
          .length,
      1,
    );
  });

  test('generic glTF parser reports sparse accessor missing fields', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'accessors': [
            {
              'componentType': 5126,
              'count': 1,
              'type': 'SCALAR',
              'sparse': <String, Object?>{},
            },
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
      strict.validation.errors.where(
        (d) => d.code == 'gltf.missingSparseAccessorField',
      ),
      hasLength(3),
    );
    expect(
      strict.validation.errors.map((d) => d.jsonPath),
      containsAll([
        r'$.accessors[0].sparse.count',
        r'$.accessors[0].sparse.indices',
        r'$.accessors[0].sparse.values',
      ]),
    );
  });

  test('reports invalid glTF animation input times', () {
    final binary = _floats([0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0]);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];

    final result = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidAnimationInputTimes'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidAnimationInputTimes')
          .map((d) => d.jsonPath),
      contains(r'$.animations[0].samplers[0].input'),
    );
  });

  test('reports non-finite glTF animation input times', () {
    final binary = Uint8List(32);
    final data = ByteData.sublistView(binary);
    data.setFloat32(0, 0.0, Endian.little);
    data.setFloat32(4, double.nan, Endian.little);
    data.setFloat32(8, 0.0, Endian.little);
    data.setFloat32(12, 0.0, Endian.little);
    data.setFloat32(16, 0.0, Endian.little);
    data.setFloat32(20, 0.0, Endian.little);
    data.setFloat32(24, 1.0, Endian.little);
    data.setFloat32(28, 0.0, Endian.little);
    final json = _minimalVrmJson()
      ..addAll(
        _animationStorageJson(
          binary.length,
          [
            [0, 8],
            [8, 24],
          ],
          accessorTypes: ['SCALAR', 'VEC3'],
        ),
      )
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'translation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];

    final result = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.invalidAnimationInputTimes'),
    );
    expect(GltfAnimationEvaluator(result.asset!.gltf).duration(0), 0.0);
  });

  test('preserves glTF leaf extensions and extras', () {
    final json = _minimalVrmJson();
    final nodes = [
      for (final node in json['nodes']! as List<Map<String, Object?>>)
        Map<String, Object?>.from(node),
    ];
    Map<String, Object?> extensionValue(String name) => {
      'name': name,
      'tags': ['metadata'],
    };
    json
      ..['asset'] = {
        'version': '2.0',
        'extras': {
          'asset': ['metadata'],
        },
      }
      ..['extras'] = {
        'root': ['metadata'],
      }
      ..['scenes'] = [
        {
          'name': 'scene',
          'nodes': [0],
          'extensions': {'EXT_scene': extensionValue('EXT_scene')},
          'extras': {'scene': 1},
        },
      ]
      ..['nodes'] = nodes
      ..['cameras'] = [
        {
          'name': 'perspective',
          'type': 'perspective',
          'perspective': {
            'yfov': 1.0,
            'znear': 0.1,
            'extensions': {
              'EXT_perspective': extensionValue('EXT_perspective'),
            },
            'extras': {'perspective': 1},
          },
          'extensions': {'EXT_camera': extensionValue('EXT_camera')},
          'extras': {'camera': 1},
        },
        {
          'name': 'orthographic',
          'type': 'orthographic',
          'orthographic': {
            'xmag': 1.0,
            'ymag': 1.0,
            'znear': 0.1,
            'zfar': 10.0,
            'extensions': {
              'EXT_orthographic': extensionValue('EXT_orthographic'),
            },
            'extras': {'orthographic': 1},
          },
        },
      ]
      ..['buffers'] = [
        {
          'name': 'buffer',
          'byteLength': 12,
          'extensions': {'EXT_buffer': extensionValue('EXT_buffer')},
          'extras': {'buffer': 1},
        },
      ]
      ..['bufferViews'] = [
        {
          'name': 'bufferView',
          'buffer': 0,
          'byteOffset': 0,
          'byteLength': 4,
          'target': 34962,
          'extensions': {'EXT_bufferView': extensionValue('EXT_bufferView')},
          'extras': {'bufferView': 1},
        },
        {'buffer': 0, 'byteOffset': 4, 'byteLength': 1},
        {'buffer': 0, 'byteOffset': 8, 'byteLength': 4},
      ]
      ..['skins'] = [
        {
          'name': 'skin',
          'joints': [0],
          'extensions': {'EXT_skin': extensionValue('EXT_skin')},
          'extras': {'skin': 1},
        },
      ]
      ..['accessors'] = [
        {
          'name': 'accessor',
          'componentType': 5126,
          'count': 1,
          'type': 'SCALAR',
          'min': [1.0],
          'max': [1.0],
          'extensions': {'EXT_accessor': extensionValue('EXT_accessor')},
          'extras': {'accessor': 1},
          'sparse': {
            'count': 1,
            'indices': {
              'bufferView': 1,
              'componentType': 5121,
              'extensions': {
                'EXT_sparse_indices': extensionValue('EXT_sparse_indices'),
              },
              'extras': {'sparseIndices': 1},
            },
            'values': {
              'bufferView': 2,
              'extensions': {
                'EXT_sparse_values': extensionValue('EXT_sparse_values'),
              },
              'extras': {'sparseValues': 1},
            },
            'extensions': {'EXT_sparse': extensionValue('EXT_sparse')},
            'extras': {'sparse': 1},
          },
        },
        {'componentType': 5126, 'count': 1, 'type': 'VEC3'},
      ]
      ..['textures'] = [
        {
          'name': 'texture',
          'source': 0,
          'sampler': 0,
          'extensions': {'EXT_texture': extensionValue('EXT_texture')},
          'extras': {'texture': 1},
        },
      ]
      ..['images'] = [
        {
          'name': 'image',
          'uri': 'data:image/png;base64,',
          'extensions': {'EXT_image': extensionValue('EXT_image')},
          'extras': {'image': 1},
        },
      ]
      ..['samplers'] = [
        {
          'name': 'sampler',
          'extensions': {'EXT_sampler': extensionValue('EXT_sampler')},
          'extras': {'sampler': 1},
        },
      ]
      ..['materials'] = [
        {
          'name': 'material',
          'extensions': {'EXT_material': extensionValue('EXT_material')},
          'extras': {'material': 1},
        },
      ]
      ..['meshes'] = [
        {
          'name': 'mesh',
          'primitives': [
            {
              'mode': 5,
              'attributes': <String, Object?>{},
              'extensions': {'EXT_primitive': extensionValue('EXT_primitive')},
              'extras': {'primitive': 1},
            },
            {'attributes': <String, Object?>{}},
          ],
          'extensions': {'EXT_mesh': extensionValue('EXT_mesh')},
          'extras': {'mesh': 1},
        },
      ]
      ..['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {
                'node': 0,
                'path': 'translation',
                'extensions': {'EXT_target': extensionValue('EXT_target')},
                'extras': {'target': 1},
              },
              'extensions': {'EXT_channel': extensionValue('EXT_channel')},
              'extras': {'channel': 1},
            },
          ],
          'samplers': [
            {
              'input': 0,
              'output': 1,
              'extensions': {
                'EXT_anim_sampler': extensionValue('EXT_anim_sampler'),
              },
              'extras': {'animSampler': 1},
            },
          ],
          'extensions': {'EXT_animation': extensionValue('EXT_animation')},
          'extras': {'animation': 1},
        },
      ];
    final rootExtensions = Map<String, Object?>.from(
      json['extensions']! as Map,
    );
    json['extensions'] = rootExtensions;
    rootExtensions['EXT_root'] = extensionValue('EXT_root');
    (json['nodes']! as List<Map<String, Object?>>).first
      ..['extensions'] = {'EXT_node': extensionValue('EXT_node')}
      ..['extras'] = {'node': 1};
    (json['extensionsUsed']! as List).addAll(<String>[
      'EXT_root',
      'EXT_scene',
      'EXT_node',
      'EXT_camera',
      'EXT_perspective',
      'EXT_orthographic',
      'EXT_buffer',
      'EXT_bufferView',
      'EXT_skin',
      'EXT_accessor',
      'EXT_sparse_indices',
      'EXT_sparse_values',
      'EXT_sparse',
      'EXT_texture',
      'EXT_image',
      'EXT_sampler',
      'EXT_material',
      'EXT_mesh',
      'EXT_primitive',
      'EXT_target',
      'EXT_channel',
      'EXT_anim_sampler',
      'EXT_animation',
    ]);

    final binary = Uint8List(12);
    ByteData.sublistView(binary).setFloat32(8, 1.0, Endian.little);
    final model = VrmModel.parseGlb(_glb(json, binaryChunk: binary));
    void expectExtraMapImmutable(Object? value) {
      final extra = value! as Map<String, Object?>;
      expect(() => extra['mutated'] = true, throwsUnsupportedError);
    }

    void expectExtraListImmutable(Object? value, String key) {
      final extra = value! as Map<String, Object?>;
      final list = extra[key]! as List<Object?>;
      expect(() => list.add('mutated'), throwsUnsupportedError);
    }

    void expectExtensionImmutable(Map<String, Object?> extensions, String key) {
      expect(extensions[key], {
        'name': key,
        'tags': ['metadata'],
      });
      final extension = extensions[key]! as Map<String, Object?>;
      final tags = extension['tags']! as List<Object?>;
      expect(() => extension['name'] = 'mutated', throwsUnsupportedError);
      expect(() => tags.add('mutated'), throwsUnsupportedError);
    }

    expectExtensionImmutable(model.gltf.extensions, 'EXT_root');
    expect(model.gltf.extras, {
      'root': ['metadata'],
    });
    expectExtraMapImmutable(model.gltf.extras);
    expectExtraListImmutable(model.gltf.extras, 'root');
    expect(model.gltf.assetExtras, {
      'asset': ['metadata'],
    });
    expectExtraMapImmutable(model.gltf.assetExtras);
    expectExtraListImmutable(model.gltf.assetExtras, 'asset');
    expect(model.gltf.scenes.single.name, 'scene');
    expectExtensionImmutable(model.gltf.scenes.single.extensions, 'EXT_scene');
    expect(model.gltf.scenes.single.extras, {'scene': 1});
    expectExtraMapImmutable(model.gltf.scenes.single.extras);
    expectExtensionImmutable(model.gltf.nodes.first.extensions, 'EXT_node');
    expect(model.gltf.nodes.first.extras, {'node': 1});
    expectExtraMapImmutable(model.gltf.nodes.first.extras);
    expect(model.gltf.cameras.first.name, 'perspective');
    expectExtensionImmutable(model.gltf.cameras.first.extensions, 'EXT_camera');
    expect(model.gltf.cameras.first.extras, {'camera': 1});
    expectExtraMapImmutable(model.gltf.cameras.first.extras);
    expectExtensionImmutable(
      model.gltf.cameras.first.perspective!.extensions,
      'EXT_perspective',
    );
    expect(model.gltf.cameras.first.perspective!.extras, {'perspective': 1});
    expectExtraMapImmutable(model.gltf.cameras.first.perspective!.extras);
    expectExtensionImmutable(
      model.gltf.cameras[1].orthographic!.extensions,
      'EXT_orthographic',
    );
    expect(model.gltf.cameras[1].orthographic!.extras, {'orthographic': 1});
    expectExtraMapImmutable(model.gltf.cameras[1].orthographic!.extras);
    expect(model.gltf.buffers.single.name, 'buffer');
    expectExtensionImmutable(
      model.gltf.buffers.single.extensions,
      'EXT_buffer',
    );
    expect(model.gltf.buffers.single.extras, {'buffer': 1});
    expectExtraMapImmutable(model.gltf.buffers.single.extras);
    expect(model.gltf.bufferViews.first.name, 'bufferView');
    expect(model.gltf.bufferViews.first.target, 34962);
    expectExtensionImmutable(
      model.gltf.bufferViews.first.extensions,
      'EXT_bufferView',
    );
    expect(model.gltf.bufferViews.first.extras, {'bufferView': 1});
    expectExtraMapImmutable(model.gltf.bufferViews.first.extras);
    expect(
      () => model.gltf.bufferViews.first.extensions['EXT_other'] = true,
      throwsUnsupportedError,
    );
    expect(model.gltf.skins.single.name, 'skin');
    expectExtensionImmutable(model.gltf.skins.single.extensions, 'EXT_skin');
    expect(model.gltf.skins.single.extras, {'skin': 1});
    expectExtraMapImmutable(model.gltf.skins.single.extras);
    expect(() => model.gltf.skins.single.joints.add(2), throwsUnsupportedError);
    expect(model.gltf.accessors.first.name, 'accessor');
    expect(model.gltf.accessors.first.minimum, [1.0]);
    expect(model.gltf.accessors.first.maximum, [1.0]);
    expectExtensionImmutable(
      model.gltf.accessors.first.extensions,
      'EXT_accessor',
    );
    expect(model.gltf.accessors.first.extras, {'accessor': 1});
    expectExtraMapImmutable(model.gltf.accessors.first.extras);
    expect(
      () => model.gltf.accessors.first.minimum!.add(2.0),
      throwsUnsupportedError,
    );
    expect(
      () => model.gltf.accessors.first.maximum![0] = 2.0,
      throwsUnsupportedError,
    );
    final sparse = model.gltf.accessors.first.sparse!;
    expectExtensionImmutable(sparse.extensions, 'EXT_sparse');
    expect(sparse.extras, {'sparse': 1});
    expectExtraMapImmutable(sparse.extras);
    expectExtensionImmutable(sparse.indicesExtensions, 'EXT_sparse_indices');
    expect(sparse.indicesExtras, {'sparseIndices': 1});
    expectExtraMapImmutable(sparse.indicesExtras);
    expectExtensionImmutable(sparse.valuesExtensions, 'EXT_sparse_values');
    expect(sparse.valuesExtras, {'sparseValues': 1});
    expectExtraMapImmutable(sparse.valuesExtras);
    expect(
      () => sparse.indicesExtensions['EXT_other'] = true,
      throwsUnsupportedError,
    );
    expect(
      () => sparse.valuesExtensions['EXT_other'] = true,
      throwsUnsupportedError,
    );
    expect(() => sparse.extensions['EXT_other'] = true, throwsUnsupportedError);
    expect(model.gltf.textures.single.name, 'texture');
    expectExtensionImmutable(
      model.gltf.textures.single.extensions,
      'EXT_texture',
    );
    expect(model.gltf.textures.single.extras, {'texture': 1});
    expectExtraMapImmutable(model.gltf.textures.single.extras);
    expect(
      () => model.gltf.textures.single.extensions['EXT_other'] = true,
      throwsUnsupportedError,
    );
    expect(model.gltf.images.single.name, 'image');
    expectExtensionImmutable(model.gltf.images.single.extensions, 'EXT_image');
    expect(model.gltf.images.single.extras, {'image': 1});
    expectExtraMapImmutable(model.gltf.images.single.extras);
    expect(
      () => model.gltf.images.single.extensions['EXT_other'] = true,
      throwsUnsupportedError,
    );
    expect(model.gltf.samplers.single.name, 'sampler');
    expectExtensionImmutable(
      model.gltf.samplers.single.extensions,
      'EXT_sampler',
    );
    expect(model.gltf.samplers.single.extras, {'sampler': 1});
    expectExtraMapImmutable(model.gltf.samplers.single.extras);
    expect(
      () => model.gltf.samplers.single.extensions['EXT_other'] = true,
      throwsUnsupportedError,
    );
    expect(model.gltf.materials.single.name, 'material');
    expectExtensionImmutable(
      model.gltf.materials.single.extensions,
      'EXT_material',
    );
    expect(model.gltf.materials.single.extras, {'material': 1});
    expectExtraMapImmutable(model.gltf.materials.single.extras);
    expect(model.gltf.meshes.single.name, 'mesh');
    expectExtensionImmutable(model.gltf.meshes.single.extensions, 'EXT_mesh');
    expect(model.gltf.meshes.single.extras, {'mesh': 1});
    expectExtraMapImmutable(model.gltf.meshes.single.extras);
    expect(model.gltf.meshes.single.primitives.first.mode, 5);
    expectExtensionImmutable(
      model.gltf.meshes.single.primitives.first.extensions,
      'EXT_primitive',
    );
    expect(model.gltf.meshes.single.primitives.first.extras, {'primitive': 1});
    expectExtraMapImmutable(model.gltf.meshes.single.primitives.first.extras);
    expect(model.gltf.meshes.single.primitives.last.mode, 4);
    expectExtensionImmutable(
      model.gltf.animations.single.extensions,
      'EXT_animation',
    );
    expect(model.gltf.animations.single.extras, {'animation': 1});
    expectExtraMapImmutable(model.gltf.animations.single.extras);
    expectExtensionImmutable(
      model.gltf.animations.single.channels.single.extensions,
      'EXT_channel',
    );
    expect(model.gltf.animations.single.channels.single.extras, {'channel': 1});
    expectExtraMapImmutable(
      model.gltf.animations.single.channels.single.extras,
    );
    expectExtensionImmutable(
      model.gltf.animations.single.channels.single.targetExtensions,
      'EXT_target',
    );
    expect(model.gltf.animations.single.channels.single.targetExtras, {
      'target': 1,
    });
    expectExtraMapImmutable(
      model.gltf.animations.single.channels.single.targetExtras,
    );
    expectExtensionImmutable(
      model.gltf.animations.single.samplers.single.extensions,
      'EXT_anim_sampler',
    );
    expect(model.gltf.animations.single.samplers.single.extras, {
      'animSampler': 1,
    });
    expectExtraMapImmutable(
      model.gltf.animations.single.samplers.single.extras,
    );
  });
}
