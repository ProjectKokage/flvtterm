part of '../flvtterm_test.dart';

void vrmFirstPersonTests() {
  test('humanoid and first-person constructors copy raw maps', () {
    final raw = <String, Object?>{
      'extras': <String, Object?>{
        'tags': <Object?>['source'],
      },
    };
    final bone = VrmHumanBone(bone: VrmHumanoidBone.head, node: 2, raw: raw);
    final annotation = VrmFirstPersonMeshAnnotation(
      node: 3,
      type: VrmFirstPersonMeshAnnotationType.both,
      raw: raw,
    );

    final rawExtras = raw['extras']! as Map<String, Object?>;
    (rawExtras['tags']! as List<Object?>).add('mutated');
    rawExtras['other'] = true;
    raw['extras'] = 'mutated';

    List<Object?> tags(Map<String, Object?> raw) =>
        (raw['extras']! as Map<String, Object?>)['tags']! as List<Object?>;

    expect(tags(bone.raw), ['source']);
    expect(tags(annotation.raw), ['source']);
    expect(() => bone.raw['extra'] = true, throwsUnsupportedError);
    expect(() => annotation.raw['extra'] = true, throwsUnsupportedError);
    expect(() => tags(annotation.raw).add('copy'), throwsUnsupportedError);
  });

  test('strict mode rejects missing required humanoid bones', () {
    final json = (jsonDecode(jsonEncode(_minimalVrmJson())) as Map)
        .cast<String, Object?>();
    json['scene'] = 2;
    (json['scenes']! as List<Object?>).add({
      'nodes': [99],
    });
    final humanBones =
        ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
                as Map<String, Object?>)['humanoid']!
            as Map<String, Object?>;
    final humanBoneMap = Map<String, Object?>.from(
      humanBones['humanBones']! as Map,
    );
    humanBones['humanBones'] = humanBoneMap;
    humanBoneMap.remove('head');
    humanBoneMap['neck'] = <String, Object?>{'node': 'bad'};

    final strict = VrmModel.tryParseGlb(_glb(json));
    final permissive = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(strict.asset, isNull);
    expect(
      strict.validation.errors.map((d) => d.code),
      containsAll([
        'vrm.missingRequiredHumanoidBone',
        'vrm.humanoidBoneInvalidNode',
        'gltf.invalidDefaultScene',
        'gltf.invalidSceneNode',
      ]),
    );
    expect(permissive.asset, isNotNull);
  });

  test('drops invalid humanoid bone mappings', () {
    final json = _minimalVrmJson();
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    final humanoid = Map<String, Object?>.from(vrm['humanoid']! as Map);
    vrm['humanoid'] = humanoid;
    humanoid['extras'] = {'source': 'humanoid'};
    final humanBones = Map<String, Object?>.from(
      humanoid['humanBones']! as Map,
    );
    humanoid['humanBones'] = humanBones;
    final head = Map<String, Object?>.from(humanBones['head']! as Map);
    humanBones['head'] = head;
    head['extras'] = {'source': 'fixture'};
    head['extensions'] = {
      'VENDOR_humanoid': {'locked': true},
    };
    humanBones['neck'] = {'node': 99};
    humanBones['chest'] = {'node': 2};

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(
      result.validation.errors.map((d) => d.code),
      containsAll(['vrm.invalidHumanoidNode', 'vrm.duplicateHumanoidNode']),
    );
    expect(result.asset!.vrm.humanoid.raw['extras'], {'source': 'humanoid'});
    expect(result.asset!.vrm.humanoid.nodeFor(VrmHumanoidBone.head), 2);
    final headBone =
        result.asset!.vrm.humanoid.humanBones[VrmHumanoidBone.head]!;
    expect(headBone.raw['extras'], {'source': 'fixture'});
    expect(headBone.raw['extensions'], {
      'VENDOR_humanoid': {'locked': true},
    });
    expect(result.asset!.vrm.humanoid.nodeFor(VrmHumanoidBone.neck), isNull);
    expect(result.asset!.vrm.humanoid.nodeFor(VrmHumanoidBone.chest), isNull);
  });

  test('reports invalid humanoid containers', () {
    final badRoot = _minimalVrmJson();
    final badRootVrm =
        (badRoot['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    badRootVrm['humanoid'] = 'bad';

    final badBones = _minimalVrmJson();
    final badBonesVrm =
        (badBones['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    final badBonesHumanoid = Map<String, Object?>.from(
      badBonesVrm['humanoid']! as Map,
    );
    badBonesVrm['humanoid'] = badBonesHumanoid;
    badBonesHumanoid['humanBones'] = 'bad';

    final badBone = _minimalVrmJson();
    final badBoneVrm =
        (badBone['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    final badBoneHumanoid = Map<String, Object?>.from(
      badBoneVrm['humanoid']! as Map,
    );
    badBoneVrm['humanoid'] = badBoneHumanoid;
    final badBoneMap = Map<String, Object?>.from(
      badBoneHumanoid['humanBones']! as Map,
    );
    badBoneHumanoid['humanBones'] = badBoneMap;
    badBoneMap['head'] = 'bad';

    final badRootResult = VrmModel.tryParseGlb(
      _glb(badRoot),
      validation: VrmValidationMode.permissive,
    );
    final badBonesResult = VrmModel.tryParseGlb(
      _glb(badBones),
      validation: VrmValidationMode.permissive,
    );
    final badBoneResult = VrmModel.tryParseGlb(
      _glb(badBone),
      validation: VrmValidationMode.permissive,
    );

    expect(badRootResult.asset, isNotNull);
    expect(
      badRootResult.validation.errors.map((d) => d.code),
      contains('vrm.invalidHumanoidObject'),
    );
    expect(badBonesResult.asset, isNotNull);
    expect(
      badBonesResult.validation.errors.map((d) => d.code),
      contains('vrm.invalidHumanoidBonesObject'),
    );
    expect(badBoneResult.asset, isNotNull);
    expect(
      badBoneResult.validation.errors.map((d) => d.code),
      contains('vrm.invalidHumanoidBoneObject'),
    );
  });

  test('reports VRM humanoid object without humanBones', () {
    final json = _minimalVrmJson();
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    vrm['humanoid'] = <String, Object?>{};

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('vrm.missingHumanoidHumanBones'),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      contains(r'$.extensions.VRMC_vrm.humanoid.humanBones'),
    );
  });

  test('reports humanoid scale and parent diagnostics with paths', () {
    final json = _minimalVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[0]['scale'] = [1.0, 0.0, 1.0];
    nodes[3]['children'] = <int>[5];

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'vrm.nonPositiveHumanoidScale',
        'vrm.invalidHumanoidParent',
      ]),
    );
    expect(
      result.validation.errors
          .singleWhere((d) => d.code == 'vrm.nonPositiveHumanoidScale')
          .jsonPath,
      r'$.nodes[0].scale',
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.invalidHumanoidParent')
          .map((d) => d.jsonPath),
      contains(r'$.extensions.VRMC_vrm.humanoid.humanBones.leftLowerLeg.node'),
    );
  });

  test('reports reflected humanoid matrix basis as non-positive scale', () {
    final json = _minimalVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[0]['matrix'] = [
      -1.0,
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
      0.0,
      0.0,
      0.0,
      1.0,
    ];

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(
      result.validation.errors
          .singleWhere((d) => d.code == 'vrm.nonPositiveHumanoidScale')
          .jsonPath,
      r'$.nodes[0].matrix',
    );
  });

  test('reports malformed VRM meta authors in permissive mode', () {
    final json = _minimalVrmJson();
    final meta =
        ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
                as Map<String, Object?>)['meta']!
            as Map<String, Object?>;
    meta['authors'] = ['Author', '', 3];

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('vrm.metaInvalidAuthors'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.metaInvalidAuthors')
          .map((d) => d.jsonPath),
      containsAll([
        r'$.extensions.VRMC_vrm.meta.authors[1]',
        r'$.extensions.VRMC_vrm.meta.authors[2]',
      ]),
    );

    final badAuthors = _minimalVrmJson();
    final badAuthorsMeta =
        ((badAuthors['extensions']! as Map<String, Object?>)['VRMC_vrm']!
                as Map<String, Object?>)['meta']!
            as Map<String, Object?>;
    badAuthorsMeta['authors'] = 'Author';

    final badAuthorsResult = VrmModel.tryParseGlb(
      _glb(badAuthors),
      validation: VrmValidationMode.permissive,
    );

    expect(badAuthorsResult.asset, isNotNull);
    expect(
      badAuthorsResult.validation.errors.map((d) => d.code),
      contains('vrm.metaInvalidAuthors'),
    );
    expect(
      badAuthorsResult.validation.errors
          .where((d) => d.code == 'vrm.metaInvalidAuthors')
          .map((d) => d.jsonPath),
      contains(r'$.extensions.VRMC_vrm.meta.authors'),
    );
    expect(
      badAuthorsResult.validation.errors.map((d) => d.code),
      isNot(contains('vrm.metaMissingAuthors')),
    );
  });

  test('reports malformed VRM meta object in permissive mode', () {
    final json = _minimalVrmJson();
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    vrm['meta'] = 'bad';

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('vrm.metaInvalidObject'),
    );
  });

  test('reports malformed required VRM meta strings', () {
    final json = _minimalVrmJson();
    final meta =
        ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
                as Map<String, Object?>)['meta']!
            as Map<String, Object?>;
    meta
      ..['name'] = 7
      ..['licenseUrl'] = 9;

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.metaInvalidString')
          .map((d) => d.jsonPath),
      containsAll([
        r'$.extensions.VRMC_vrm.meta.name',
        r'$.extensions.VRMC_vrm.meta.licenseUrl',
      ]),
    );
    expect(
      result.validation.errors.map((d) => d.code),
      isNot(contains('vrm.metaMissingName')),
    );
  });

  test('allows empty VRM meta licenseUrl', () {
    final json = _minimalVrmJson();
    final meta =
        ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
                as Map<String, Object?>)['meta']!
            as Map<String, Object?>;
    meta['licenseUrl'] = '';

    final result = VrmModel.tryParseGlb(_glb(json));

    expect(result.validation.hasErrors, isFalse);
    expect(result.asset!.vrm.meta.licenseUrl, '');
  });

  test('parses VRM meta license and thumbnail fields', () {
    final json = _minimalVrmJson();
    json['images'] = [
      {
        'uri':
            'data:image/png;base64,${base64.encode([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])}',
      },
    ];
    final meta =
        ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
                as Map<String, Object?>)['meta']!
            as Map<String, Object?>;
    meta
      ..['version'] = '1.2.3'
      ..['copyrightInformation'] = 'Copyright'
      ..['contactInformation'] = 'contact@example.com'
      ..['references'] = ['Original']
      ..['thirdPartyLicenses'] = 'Third party'
      ..['thumbnailImage'] = 0
      ..['avatarPermission'] = 'everyone'
      ..['allowExcessivelyViolentUsage'] = true
      ..['allowExcessivelySexualUsage'] = true
      ..['commercialUsage'] = 'corporation'
      ..['allowPoliticalOrReligiousUsage'] = true
      ..['allowAntisocialOrHateUsage'] = true
      ..['creditNotation'] = 'unnecessary'
      ..['allowRedistribution'] = true
      ..['modification'] = 'allowModificationRedistribution'
      ..['otherLicenseUrl'] = 'https://example.com/other';

    final result = VrmModel.tryParseGlb(_glb(json));
    final parsed = result.asset!.vrm.meta;

    expect(result.validation.hasErrors, isFalse);
    expect(parsed.version, '1.2.3');
    expect(parsed.references, ['Original']);
    expect(parsed.thumbnailImage, 0);
    expect(parsed.avatarPermission, VrmMetaAvatarPermission.everyone);
    expect(parsed.allowExcessivelyViolentUsage, isTrue);
    expect(parsed.commercialUsage, VrmMetaCommercialUsage.corporation);
    expect(parsed.allowPoliticalOrReligiousUsage, isTrue);
    expect(parsed.allowAntisocialOrHateUsage, isTrue);
    expect(parsed.creditNotation, VrmMetaCreditNotation.unnecessary);
    expect(parsed.allowRedistribution, isTrue);
    expect(
      parsed.modification,
      VrmMetaModification.allowModificationRedistribution,
    );
    expect(parsed.otherLicenseUrl, 'https://example.com/other');
  });

  test('reports non-square PNG and JPEG VRM thumbnails', () {
    for (final image in [
      (mimeType: 'image/png', bytes: _testPngHeader(width: 4, height: 2)),
      (mimeType: 'image/jpeg', bytes: _testJpegHeader(width: 3, height: 5)),
    ]) {
      final bytes = _vrmWithThumbnail(image.mimeType, image.bytes);
      final permissive = VrmModel.tryParseGlb(
        bytes,
        validation: VrmValidationMode.permissive,
      );
      final diagnostic = permissive.validation.errors.singleWhere(
        (entry) => entry.code == 'vrm.metaThumbnailNotSquare',
      );

      expect(permissive.asset, isNotNull);
      expect(diagnostic.message, contains('image 0 is'));
      expect(diagnostic.jsonPath, r'$.extensions.VRMC_vrm.meta.thumbnailImage');
      expect(VrmModel.tryParseGlb(bytes).asset, isNull);
    }
  });

  test('accepts square PNG and JPEG VRM thumbnails', () {
    for (final image in [
      (mimeType: 'image/png', bytes: _testPngHeader(width: 4, height: 4)),
      (mimeType: 'image/jpeg', bytes: _testJpegHeader(width: 5, height: 5)),
    ]) {
      final result = VrmModel.tryParseGlb(
        _vrmWithThumbnail(image.mimeType, image.bytes),
      );

      expect(result.asset, isNotNull);
      expect(
        result.validation.errors.map((entry) => entry.code),
        isNot(contains('vrm.metaThumbnailNotSquare')),
      );
    }
  });

  test('reports malformed optional VRM meta fields', () {
    final json = _minimalVrmJson();
    final meta =
        ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
                as Map<String, Object?>)['meta']!
            as Map<String, Object?>;
    meta
      ..['version'] = 3
      ..['references'] = <Object?>[]
      ..['thumbnailImage'] = 0
      ..['avatarPermission'] = 'bad'
      ..['allowRedistribution'] = 'yes';

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'vrm.metaInvalidString',
        'vrm.metaInvalidStringList',
        'vrm.metaInvalidThumbnailImage',
        'vrm.metaInvalidEnum',
        'vrm.metaInvalidBoolean',
      ]),
    );
    expect(
      result.asset!.vrm.meta.avatarPermission,
      VrmMetaAvatarPermission.onlyAuthor,
    );
    expect(result.asset!.vrm.meta.allowRedistribution, isFalse);
  });

  test('first-person annotations default missing meshes to auto', () {
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {'attributes': <String, Object?>{}},
          ],
        },
      ],
      nodeMesh: {0: 0},
    );
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    vrm['firstPerson'] = {
      'extras': {'source': 'first-person'},
      'meshAnnotations': [
        {
          'node': 0,
          'type': 'thirdPersonOnly',
          'extras': {'reason': 'head mesh'},
          'extensions': {'VENDOR_visibility': true},
        },
      ],
    };
    (json['extensionsUsed']! as List<Object?>).add('VENDOR_visibility');

    final model = VrmModel.parseGlb(_glb(json));
    final annotation = model.vrm.firstPerson.meshAnnotations.single;
    expect(model.vrm.firstPerson.raw['extras'], {'source': 'first-person'});
    expect(
      model.vrm.firstPerson.typeForNode(0),
      VrmFirstPersonMeshAnnotationType.thirdPersonOnly,
    );
    expect(annotation.raw['extras'], {'reason': 'head mesh'});
    expect(annotation.raw['extensions'], {'VENDOR_visibility': true});
    expect(
      model.vrm.firstPerson.typeForNode(1),
      VrmFirstPersonMeshAnnotationType.auto,
    );
    expect(
      VrmModel.parseGlb(_glb(_minimalVrmJson())).vrm.firstPerson.typeForNode(0),
      VrmFirstPersonMeshAnnotationType.auto,
    );
  });

  test('reports invalid first-person mesh annotations', () {
    final json = _minimalVrmJson();
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    vrm['firstPerson'] = {
      'meshAnnotations': [
        {'node': 99, 'type': 'bad'},
        {'node': 0},
        {'type': 'both'},
        {'node': 'zero', 'type': 3},
        {'node': 1, 'type': 'both'},
      ],
    };

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'vrm.invalidFirstPersonMeshNode',
        'vrm.invalidFirstPersonMeshAnnotationType',
        'vrm.firstPersonMeshAnnotationMissingNode',
        'vrm.firstPersonMeshAnnotationMissingType',
        'vrm.firstPersonMeshNodeMissingMesh',
      ]),
    );
    expect(
      result.validation.errors
          .singleWhere((d) => d.code == 'vrm.firstPersonMeshNodeMissingMesh')
          .jsonPath,
      r'$.extensions.VRMC_vrm.firstPerson.meshAnnotations[4].node',
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.invalidFirstPersonMeshNode')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.invalidFirstPersonMeshNode')
          .map((d) => d.jsonPath),
      containsAll([
        r'$.extensions.VRMC_vrm.firstPerson.meshAnnotations[0].node',
        r'$.extensions.VRMC_vrm.firstPerson.meshAnnotations[3].node',
      ]),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.invalidFirstPersonMeshAnnotationType')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.invalidFirstPersonMeshAnnotationType')
          .map((d) => d.jsonPath),
      containsAll([
        r'$.extensions.VRMC_vrm.firstPerson.meshAnnotations[0].type',
        r'$.extensions.VRMC_vrm.firstPerson.meshAnnotations[3].type',
      ]),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.firstPersonMeshAnnotationMissingNode')
          .map((d) => d.jsonPath),
      contains(r'$.extensions.VRMC_vrm.firstPerson.meshAnnotations[2].node'),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.firstPersonMeshAnnotationMissingType')
          .map((d) => d.jsonPath),
      contains(r'$.extensions.VRMC_vrm.firstPerson.meshAnnotations[1].type'),
    );
    expect(
      result.asset!.vrm.firstPerson.typeForNode(0),
      VrmFirstPersonMeshAnnotationType.auto,
    );
    expect(result.asset!.vrm.firstPerson.meshAnnotations, isEmpty);
  });

  test('reports invalid first-person containers', () {
    final badRoot = _minimalVrmJson();
    final badRootVrm =
        (badRoot['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    badRootVrm['firstPerson'] = 'bad';

    final badList = _minimalVrmJson();
    final badListVrm =
        (badList['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    badListVrm['firstPerson'] = {'meshAnnotations': <Object?>[]};

    final badEntry = _minimalVrmJson();
    final badEntryVrm =
        (badEntry['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    badEntryVrm['firstPerson'] = {
      'meshAnnotations': ['bad'],
    };

    final badRootResult = VrmModel.tryParseGlb(
      _glb(badRoot),
      validation: VrmValidationMode.permissive,
    );
    final badListResult = VrmModel.tryParseGlb(
      _glb(badList),
      validation: VrmValidationMode.permissive,
    );
    final badEntryResult = VrmModel.tryParseGlb(
      _glb(badEntry),
      validation: VrmValidationMode.permissive,
    );

    expect(badRootResult.asset, isNotNull);
    expect(
      badRootResult.validation.errors.map((d) => d.code),
      contains('vrm.invalidFirstPersonObject'),
    );
    expect(badListResult.asset, isNotNull);
    expect(
      badListResult.validation.errors.map((d) => d.code),
      contains('vrm.invalidFirstPersonMeshAnnotations'),
    );
    expect(badEntryResult.asset, isNotNull);
    expect(
      badEntryResult.validation.errors.map((d) => d.code),
      contains('vrm.invalidFirstPersonMeshAnnotationObject'),
    );
  });

  test('first-person auto policy classifies skinned head influence', () {
    final binary = Uint8List(40);
    final data = ByteData.sublistView(binary);
    binary[0] = 0;
    data.setFloat32(4, 1.0, Endian.little);
    binary[20] = 1;
    data.setFloat32(24, 1.0, Endian.little);
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {
              'mode': 0,
              'attributes': {'JOINTS_0': 0, 'WEIGHTS_0': 1},
            },
            {
              'mode': 0,
              'attributes': {'JOINTS_0': 2, 'WEIGHTS_0': 3},
            },
          ],
        },
        {
          'primitives': [
            {
              'mode': 0,
              'attributes': {'JOINTS_0': 2, 'WEIGHTS_0': 3},
            },
          ],
        },
      ],
      nodeMesh: {0: 0, 3: 1},
    );
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[0]['skin'] = 0;
    nodes[3]['skin'] = 0;
    json
      ..['buffers'] = [
        {'byteLength': binary.length},
      ]
      ..['bufferViews'] = [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 4},
        {'buffer': 0, 'byteOffset': 4, 'byteLength': 16},
        {'buffer': 0, 'byteOffset': 20, 'byteLength': 4},
        {'buffer': 0, 'byteOffset': 24, 'byteLength': 16},
      ]
      ..['accessors'] = [
        {'bufferView': 0, 'componentType': 5121, 'count': 1, 'type': 'VEC4'},
        {'bufferView': 1, 'componentType': 5126, 'count': 1, 'type': 'VEC4'},
        {'bufferView': 2, 'componentType': 5121, 'count': 1, 'type': 'VEC4'},
        {'bufferView': 3, 'componentType': 5126, 'count': 1, 'type': 'VEC4'},
      ]
      ..['skins'] = [
        {
          'joints': [2, 3],
        },
      ];

    final model = VrmModel.parseGlb(_glb(json, binaryChunk: binary));

    expect(
      model.conservativeFirstPersonTypeForNode(0),
      VrmFirstPersonMeshAnnotationType.thirdPersonOnly,
    );
    expect(
      model.firstPersonTypeForPrimitive(0, 0),
      VrmFirstPersonMeshAnnotationType.thirdPersonOnly,
    );
    expect(
      model.firstPersonTypeForPrimitive(0, 1),
      VrmFirstPersonMeshAnnotationType.both,
    );
    expect(model.firstPersonNeedsPrimitiveSplit(0), isTrue);
    expect(model.firstPersonNeedsGeometrySplit(0), isTrue);
    expect(
      model.conservativeFirstPersonTypeForNode(3),
      VrmFirstPersonMeshAnnotationType.both,
    );
    expect(model.firstPersonNeedsPrimitiveSplit(3), isFalse);
    expect(model.firstPersonNeedsGeometrySplit(3), isFalse);
    expect(
      model.conservativeFirstPersonTypeForNode(1),
      VrmFirstPersonMeshAnnotationType.auto,
    );
    expect(model.firstPersonNeedsPrimitiveSplit(1), isFalse);
    expect(model.firstPersonNeedsGeometrySplit(1), isFalse);

    final runtime = VrmRuntime(model);
    final binding = _FakeBinding();

    expect(
      runtime.firstPerson.geometrySplitWarnings().single,
      isA<VrmDiagnostic>()
          .having((d) => d.code, 'code', 'vrm.firstPersonGeometrySplitRequired')
          .having((d) => d.gltfNodeIndex, 'gltfNodeIndex', 0)
          .having((d) => d.message, 'message', contains('primitive splitting'))
          .having((d) => d.jsonPath, 'jsonPath', r'$.nodes[0]'),
    );

    runtime.bind(binding);
    runtime.firstPerson.useFirstPerson();
    runtime.update(0);

    expect(binding.meshes[0]!.visible, isFalse);
    expect(binding.meshes[3]!.visible, isTrue);

    runtime.firstPerson.useThirdPerson();
    runtime.update(0);

    expect(binding.meshes[0]!.visible, isTrue);
    expect(binding.meshes[3]!.visible, isTrue);
  });

  test('first-person auto treats head descendants as head influence', () {
    final binary = Uint8List(20);
    final data = ByteData.sublistView(binary);
    binary[0] = 1;
    data.setFloat32(4, 1.0, Endian.little);
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {
              'mode': 0,
              'attributes': {'JOINTS_0': 0, 'WEIGHTS_0': 1},
            },
          ],
        },
      ],
      nodeMesh: {0: 0},
    );
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[0]['skin'] = 0;
    nodes[2]['children'] = [15];
    nodes.add({'name': 'headChild'});
    json
      ..['buffers'] = [
        {'byteLength': binary.length},
      ]
      ..['bufferViews'] = [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 4},
        {'buffer': 0, 'byteOffset': 4, 'byteLength': 16},
      ]
      ..['accessors'] = [
        {'bufferView': 0, 'componentType': 5121, 'count': 1, 'type': 'VEC4'},
        {'bufferView': 1, 'componentType': 5126, 'count': 1, 'type': 'VEC4'},
      ]
      ..['skins'] = [
        {
          'joints': [2, 15],
        },
      ];

    final model = VrmModel.parseGlb(_glb(json, binaryChunk: binary));

    expect(
      model.conservativeFirstPersonTypeForNode(0),
      VrmFirstPersonMeshAnnotationType.thirdPersonOnly,
    );
  });

  test('first-person auto policy classifies triangle groups', () {
    final binary = Uint8List(120);
    final data = ByteData.sublistView(binary);
    for (var vertex = 0; vertex < 6; vertex++) {
      binary[vertex * 4] = vertex == 0 ? 0 : 1;
      data.setFloat32(24 + vertex * 16, 1.0, Endian.little);
    }
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {
              'attributes': {'JOINTS_0': 0, 'WEIGHTS_0': 1},
            },
          ],
        },
      ],
      nodeMesh: {0: 0},
    );
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[0]['skin'] = 0;
    json
      ..['buffers'] = [
        {'byteLength': binary.length},
      ]
      ..['bufferViews'] = [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 24},
        {'buffer': 0, 'byteOffset': 24, 'byteLength': 96},
      ]
      ..['accessors'] = [
        {'bufferView': 0, 'componentType': 5121, 'count': 6, 'type': 'VEC4'},
        {'bufferView': 1, 'componentType': 5126, 'count': 6, 'type': 'VEC4'},
      ]
      ..['skins'] = [
        {
          'joints': [2, 3],
        },
      ];

    final model = VrmModel.parseGlb(_glb(json, binaryChunk: binary));

    expect(model.firstPersonTriangleTypesForPrimitive(0, 0), [
      VrmFirstPersonMeshAnnotationType.thirdPersonOnly,
      VrmFirstPersonMeshAnnotationType.both,
    ]);
    expect(
      model.firstPersonTypeForPrimitive(0, 0),
      VrmFirstPersonMeshAnnotationType.thirdPersonOnly,
    );
    expect(model.firstPersonNeedsTriangleSplit(0, 0), isTrue);
    expect(model.firstPersonNeedsGeometrySplit(0), isTrue);
    expect(
      VrmRuntime(model).firstPerson.geometrySplitWarnings().single.message,
      contains('triangle splitting'),
    );
  });

  test('first-person auto policy classifies triangle strip and fan groups', () {
    final binary = Uint8List(160);
    final data = ByteData.sublistView(binary);
    for (var vertex = 0; vertex < 4; vertex++) {
      binary[vertex * 4] = vertex == 0 ? 0 : 1;
      data.setFloat32(32 + vertex * 16, 1.0, Endian.little);
    }
    for (var vertex = 0; vertex < 4; vertex++) {
      binary[16 + vertex * 4] = vertex == 1 ? 0 : 1;
      data.setFloat32(96 + vertex * 16, 1.0, Endian.little);
    }
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {
              'mode': 5,
              'attributes': {'JOINTS_0': 0, 'WEIGHTS_0': 1},
            },
            {
              'mode': 6,
              'attributes': {'JOINTS_0': 2, 'WEIGHTS_0': 3},
            },
          ],
        },
      ],
      nodeMesh: {0: 0},
    );
    (json['nodes']! as List<Map<String, Object?>>)[0]['skin'] = 0;
    json
      ..['buffers'] = [
        {'byteLength': binary.length},
      ]
      ..['bufferViews'] = [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 16},
        {'buffer': 0, 'byteOffset': 32, 'byteLength': 64},
        {'buffer': 0, 'byteOffset': 16, 'byteLength': 16},
        {'buffer': 0, 'byteOffset': 96, 'byteLength': 64},
      ]
      ..['accessors'] = [
        {'bufferView': 0, 'componentType': 5121, 'count': 4, 'type': 'VEC4'},
        {'bufferView': 1, 'componentType': 5126, 'count': 4, 'type': 'VEC4'},
        {'bufferView': 2, 'componentType': 5121, 'count': 4, 'type': 'VEC4'},
        {'bufferView': 3, 'componentType': 5126, 'count': 4, 'type': 'VEC4'},
      ]
      ..['skins'] = [
        {
          'joints': [2, 3],
        },
      ];

    final model = VrmModel.parseGlb(_glb(json, binaryChunk: binary));

    expect(model.firstPersonTriangleTypesForPrimitive(0, 0), [
      VrmFirstPersonMeshAnnotationType.thirdPersonOnly,
      VrmFirstPersonMeshAnnotationType.both,
    ]);
    expect(model.firstPersonTriangleTypesForPrimitive(0, 1), [
      VrmFirstPersonMeshAnnotationType.thirdPersonOnly,
      VrmFirstPersonMeshAnnotationType.both,
    ]);
    expect(model.firstPersonNeedsGeometrySplit(0), isTrue);
  });

  test('first-person auto keeps partially classified meshes ambiguous', () {
    final binary = Uint8List(20);
    final data = ByteData.sublistView(binary);
    binary[0] = 1;
    data.setFloat32(4, 1.0, Endian.little);
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {
              'mode': 0,
              'attributes': {'JOINTS_0': 0, 'WEIGHTS_0': 1},
            },
            {'mode': 0, 'attributes': <String, Object?>{}},
          ],
        },
      ],
      nodeMesh: {0: 0},
    );
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[0]['skin'] = 0;
    json
      ..['buffers'] = [
        {'byteLength': binary.length},
      ]
      ..['bufferViews'] = [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 4},
        {'buffer': 0, 'byteOffset': 4, 'byteLength': 16},
      ]
      ..['accessors'] = [
        {'bufferView': 0, 'componentType': 5121, 'count': 1, 'type': 'VEC4'},
        {'bufferView': 1, 'componentType': 5126, 'count': 1, 'type': 'VEC4'},
      ]
      ..['skins'] = [
        {
          'joints': [2, 3],
        },
      ];

    final result = VrmModel.tryParseGlb(
      _glb(json, binaryChunk: binary),
      validation: VrmValidationMode.permissive,
    );
    final model = result.asset!;

    expect(
      result.validation.errors.map((d) => d.code),
      contains('gltf.skinnedPrimitiveMissingAttributes'),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      contains(r'$.meshes[0].primitives[1].attributes'),
    );
    expect(
      model.conservativeFirstPersonTypeForNode(0),
      VrmFirstPersonMeshAnnotationType.auto,
    );
    expect(
      model.firstPersonTypeForPrimitive(0, 0),
      VrmFirstPersonMeshAnnotationType.both,
    );
    expect(
      model.firstPersonTypeForPrimitive(0, 1),
      VrmFirstPersonMeshAnnotationType.auto,
    );
    expect(model.firstPersonNeedsPrimitiveSplit(0), isTrue);
    expect(model.firstPersonNeedsGeometrySplit(0), isTrue);
  });

  test('first-person auto warnings report unclassified meshes', () {
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {'attributes': <String, Object?>{}},
          ],
        },
      ],
      nodeMesh: {0: 0},
    );
    final model = VrmModel.parseGlb(_glb(json));

    final warning = VrmRuntime(
      model,
    ).firstPerson.geometrySplitWarnings().single;

    expect(
      warning,
      isA<VrmDiagnostic>()
          .having(
            (d) => d.code,
            'code',
            'vrm.firstPersonAutoClassificationUnavailable',
          )
          .having((d) => d.gltfNodeIndex, 'gltfNodeIndex', 0)
          .having((d) => d.message, 'message', contains('skin weights'))
          .having((d) => d.jsonPath, 'jsonPath', r'$.nodes[0]'),
    );
  });

  test('runtime applies first-person mesh visibility policy', () {
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {'attributes': <String, Object?>{}},
          ],
        },
        {
          'primitives': [
            {'attributes': <String, Object?>{}},
          ],
        },
        {
          'primitives': [
            {'attributes': <String, Object?>{}},
          ],
        },
      ],
      nodeMesh: {0: 0, 1: 1, 3: 2},
    );
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    vrm['firstPerson'] = {
      'meshAnnotations': [
        {'node': 0, 'type': 'thirdPersonOnly'},
        {'node': 1, 'type': 'firstPersonOnly'},
        {'node': 3, 'type': 'both'},
      ],
    };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.firstPerson.useFirstPerson();
    runtime.update(0);

    expect(binding.meshes[0]!.visible, isFalse);
    expect(binding.meshes[1]!.visible, isTrue);
    expect(binding.meshes[3]!.visible, isTrue);

    runtime.firstPerson.useThirdPerson();
    runtime.update(0);

    expect(binding.meshes[0]!.visible, isTrue);
    expect(binding.meshes[1]!.visible, isFalse);
    expect(binding.meshes[3]!.visible, isTrue);
  });
}

Uint8List _vrmWithThumbnail(String mimeType, Uint8List imageBytes) {
  final json = _minimalVrmJson();
  json['images'] = [
    {'uri': 'data:$mimeType;base64,${base64.encode(imageBytes)}'},
  ];
  final vrm =
      (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
          as Map<String, Object?>;
  (vrm['meta']! as Map<String, Object?>)['thumbnailImage'] = 0;
  return _glb(json);
}

Uint8List _testPngHeader({required int width, required int height}) {
  final bytes = Uint8List(24);
  bytes.setRange(0, 8, const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 13, Endian.big);
  bytes.setRange(12, 16, const [0x49, 0x48, 0x44, 0x52]);
  data.setUint32(16, width, Endian.big);
  data.setUint32(20, height, Endian.big);
  return bytes;
}

Uint8List _testJpegHeader({required int width, required int height}) =>
    Uint8List.fromList([
      0xff,
      0xd8,
      0xff,
      0xc0,
      0x00,
      0x0b,
      0x08,
      height >> 8,
      height & 0xff,
      width >> 8,
      width & 0xff,
      0x01,
      0x01,
      0x11,
      0x00,
      0xff,
      0xd9,
    ]);
