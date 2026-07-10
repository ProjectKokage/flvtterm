part of '../flvtterm_test.dart';

void expressionLookAtTests() {
  test('expression bind and LookAt range constructors copy raw maps', () {
    final raw = <String, Object?>{
      'extras': <String, Object?>{
        'tags': <Object?>['source'],
      },
    };
    final morph = VrmMorphTargetBind(node: 0, index: 0, weight: 1, raw: raw);
    final color = VrmMaterialColorBind(
      material: 0,
      type: 'color',
      targetValue: VrmVector4.white,
      raw: raw,
    );
    final texture = VrmTextureTransformBind(
      material: 0,
      scale: VrmVector2.one,
      offset: VrmVector2.zero,
      raw: raw,
    );
    final range = VrmLookAtRangeMap(
      inputMaxValue: 90,
      outputScale: 10,
      raw: raw,
    );

    final rawExtras = raw['extras']! as Map<String, Object?>;
    (rawExtras['tags']! as List<Object?>).add('mutated');
    rawExtras['other'] = true;
    raw['extras'] = 'mutated';

    List<Object?> tags(Map<String, Object?> raw) =>
        (raw['extras']! as Map<String, Object?>)['tags']! as List<Object?>;

    expect(tags(morph.raw), ['source']);
    expect(tags(color.raw), ['source']);
    expect(tags(texture.raw), ['source']);
    expect(tags(range.raw), ['source']);
    expect(() => morph.raw['extra'] = true, throwsUnsupportedError);
    expect(() => color.raw['extra'] = true, throwsUnsupportedError);
    expect(() => texture.raw['extra'] = true, throwsUnsupportedError);
    expect(() => range.raw['extra'] = true, throwsUnsupportedError);
    expect(() => tags(morph.raw).add('copy'), throwsUnsupportedError);
  });

  test('applies expression clamp, binary threshold, and blink override', () {
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {
              'attributes': <String, Object?>{},
              'targets': [
                <String, Object?>{},
                <String, Object?>{},
                <String, Object?>{},
              ],
            },
          ],
        },
      ],
      materials: [
        {
          'pbrMetallicRoughness': {
            'baseColorFactor': [0.2, 0.2, 0.2, 1.0],
            'baseColorTexture': {
              'index': 0,
              'extensions': {
                'KHR_texture_transform': {
                  'scale': [2.0, 2.0],
                  'offset': [0.25, 0.5],
                },
              },
            },
          },
        },
      ],
      nodeMesh: {0: 0},
      expressions: {
        'preset': {
          'happy': {
            'isBinary': true,
            'overrideBlink': 'block',
            'morphTargetBinds': [
              {
                'node': 0,
                'index': 1,
                'weight': 0.7,
                'extras': {'source': 'morph'},
              },
            ],
            'materialColorBinds': [
              {
                'material': 0,
                'type': 'color',
                'targetValue': [1.0, 0.0, 0.0, 1.0],
                'extensions': {'VENDOR_color': true},
              },
            ],
          },
          'blink': {
            'isBinary': true,
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
          'aa': {
            'morphTargetBinds': [
              {'node': 0, 'index': 2, 'weight': 1.0},
            ],
          },
        },
        'custom': {
          'softUv': {
            'textureTransformBinds': [
              {
                'material': 0,
                'scale': [4.0, 6.0],
                'offset': [0.75, 1.0],
                'extras': {'source': 'uv'},
              },
            ],
          },
        },
        'extras': {'source': 'expressions'},
      },
    );
    json['textures'] = [<String, Object?>{}];
    (json['extensionsUsed']! as List).addAll(<String>[
      'KHR_texture_transform',
      'VENDOR_color',
    ]);
    final model = VrmModel.parseGlb(_glb(json));
    final binding = _FakeBinding();
    final runtime = VrmRuntime(model)..bind(binding);

    runtime.emotion.set(VrmEmotion.happy, 0.6);
    runtime.blink.setBoth(1.0);
    runtime.lipSync.setViseme(VrmViseme.aa, 0.3);
    runtime.expressions.setCustom('softUv', 0.5);
    runtime.update(1 / 60);

    final happy = model.vrm.expressions.preset[VrmExpressionPreset.happy]!;
    expect(
      identical(model.vrm.expressions.all, model.vrm.expressions.all),
      isTrue,
    );
    expect(model.vrm.expressions.all.keys, containsAll(['happy', 'softUv']));
    expect(model.vrm.expressions.raw['extras'], {'source': 'expressions'});
    expect(happy.morphTargetBinds.single.raw['extras'], {'source': 'morph'});
    expect(happy.materialColorBinds.single.raw['extensions'], {
      'VENDOR_color': true,
    });
    expect(
      model
          .vrm
          .expressions
          .custom['softUv']!
          .textureTransformBinds
          .single
          .raw['extras'],
      {'source': 'uv'},
    );

    expect(binding.meshes[0]!.weights['0:0'], 0.0);
    expect(binding.meshes[0]!.weights['0:1'], 0.7);
    expect(binding.meshes[0]!.weights['0:2'], 0.3);
    expect(
      binding.materials[0]!.colors['color'],
      VrmVector4(1.0, 0.0, 0.0, 1.0),
    );
    expect(binding.materials[0]!.scale, VrmVector2(3.0, 4.0));
    expect(binding.materials[0]!.offset, VrmVector2(0.5, 0.75));
    expect(binding.began, 1);
    expect(binding.committed, 1);

    runtime.expressions.clear();
    runtime.update(1 / 60);

    expect(binding.meshes[0]!.weights['0:1'], 0.0);
    expect(
      binding.materials[0]!.colors['color'],
      VrmVector4(0.2, 0.2, 0.2, 1.0),
    );
    expect(binding.materials[0]!.scale, VrmVector2(2.0, 2.0));
    expect(binding.materials[0]!.offset, VrmVector2(0.25, 0.5));
    expect(binding.began, 2);
    expect(binding.committed, 2);
  });

  test(
    'expression blend override scales mouth and suppresses binary targets',
    () {
      final model = VrmModel.parseGlb(
        _glb(
          _minimalVrmJson(
            expressions: {
              'preset': {
                'relaxed': {'overrideMouth': 'blend'},
                'happy': {'isBinary': true, 'overrideMouth': 'blend'},
                'aa': <String, Object?>{},
                'ih': {'isBinary': true},
              },
            },
          ),
        ),
      );
      final controller = VrmExpressionController(model)
        ..setPreset(VrmExpressionPreset.relaxed, 0.25)
        ..setPreset(VrmExpressionPreset.aa, 0.8)
        ..setPreset(VrmExpressionPreset.ih, 1.0);

      var weights = controller.evaluate();

      expect(weights['aa'], closeTo(0.6, 0.000001));
      expect(weights['ih'], 0.0);

      controller.setPreset(VrmExpressionPreset.happy, 0.51);
      weights = controller.evaluate();

      expect(weights['aa'], 0.0);
    },
  );

  test('binary expression override uses output threshold before blocking', () {
    final model = VrmModel.parseGlb(
      _glb(
        _minimalVrmJson(
          expressions: {
            'preset': {
              'happy': {'isBinary': true, 'overrideBlink': 'block'},
              'blink': <String, Object?>{},
            },
          },
        ),
      ),
    );
    final controller = VrmExpressionController(model)
      ..setPreset(VrmExpressionPreset.blink, 1.0);

    controller.setPreset(VrmExpressionPreset.happy, 0.5);
    var weights = controller.evaluate();

    expect(weights['happy'], 0.0);
    expect(weights['blink'], 1.0);

    controller.setPreset(VrmExpressionPreset.happy, 0.5001);
    weights = controller.evaluate();

    expect(weights['happy'], 1.0);
    expect(weights['blink'], 0.0);
  });

  test('material color binds ignore alpha for RGB-only targets', () {
    final model = VrmModel.parseGlb(
      _glb(
        _minimalVrmJson(
          materials: [
            {
              'emissiveFactor': [0.1, 0.2, 0.3],
              'pbrMetallicRoughness': {
                'baseColorFactor': [0.2, 0.3, 0.4, 0.5],
              },
            },
          ],
          expressions: {
            'preset': {
              'happy': {
                'materialColorBinds': [
                  {
                    'material': 0,
                    'type': 'color',
                    'targetValue': [1.0, 0.0, 0.0, 0.25],
                  },
                  {
                    'material': 0,
                    'type': 'emissionColor',
                    'targetValue': [0.9, 0.8, 0.7, 0.0],
                  },
                ],
              },
            },
          },
        ),
      ),
    );
    final binding = _FakeBinding();
    final runtime = VrmRuntime(model)..bind(binding);

    runtime.emotion.set(VrmEmotion.happy, 1.0);
    runtime.update(0);

    expect(
      binding.materials[0]!.colors['color'],
      VrmVector4(1.0, 0.0, 0.0, 0.25),
    );
    expect(
      binding.materials[0]!.colors['emissionColor'],
      VrmVector4(0.9, 0.8, 0.7, 1.0),
    );
  });

  test('expression setters clamp non-finite weights', () {
    final model = VrmModel.parseGlb(
      _glb(
        _minimalVrmJson(
          expressions: {
            'preset': {
              'happy': <String, Object?>{},
              'sad': <String, Object?>{},
            },
            'custom': {'custom': <String, Object?>{}},
          },
        ),
      ),
    );
    final controller = VrmExpressionController(model)
      ..setPreset(VrmExpressionPreset.happy, double.nan)
      ..setPreset(VrmExpressionPreset.sad, double.infinity)
      ..setCustom('custom', double.negativeInfinity);

    final weights = controller.evaluate();

    expect(weights['happy'], 0.0);
    expect(weights['sad'], 1.0);
    expect(weights['custom'], 0.0);
  });

  test('reports invalid expression bind indices in permissive mode', () {
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
      materials: [<String, Object?>{}],
      nodeMesh: {0: 0},
      expressions: {
        'preset': {
          'angry': 'bad-expression',
          'happy': {
            'isBinary': 'yes',
            'overrideBlink': 'bad',
            'overrideMouth': 1,
            'morphTargetBinds': [
              {'node': 0, 'index': 2, 'weight': 1.2},
              {'node': 1, 'index': 0, 'weight': 0.5},
              {'node': 0, 'index': 0, 'weight': 'bad'},
            ],
            'materialColorBinds': [
              {
                'material': 9,
                'type': 'color',
                'targetValue': [1.0, 1.0, 1.0, 1.0],
              },
              {
                'material': 'bad',
                'type': 'color',
                'targetValue': [1.0, 1.0, 1.0, 1.0],
              },
              {
                'material': 0,
                'type': 'bad',
                'targetValue': [1.0, 1.0, 1.0, 1.0],
              },
              {'material': 0, 'type': 'color'},
              {
                'material': 0,
                'type': 'color',
                'targetValue': [1.0, 1.0],
              },
            ],
            'textureTransformBinds': [
              {'material': 9},
              {'material': 'bad'},
              {
                'material': 0,
                'scale': [1.0],
                'offset': [0.0, 'bad'],
              },
            ],
          },
        },
        'custom': {
          'badLists': {
            'morphTargetBinds': 'bad',
            'materialColorBinds': <Object?>[],
            'textureTransformBinds': <Object?>[],
          },
        },
      },
    );

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'vrm.invalidMorphTargetWeight',
        'vrm.invalidMorphTargetIndex',
        'vrm.invalidMorphTargetMesh',
        'vrm.invalidMaterialColorMaterial',
        'vrm.invalidMaterialColorType',
        'vrm.invalidMaterialColorBind',
        'vrm.invalidMaterialColorTargetValue',
        'vrm.invalidTextureTransformMaterial',
        'vrm.invalidTextureTransformScale',
        'vrm.invalidTextureTransformOffset',
        'vrm.invalidExpressionObject',
        'vrm.invalidExpressionIsBinary',
        'vrm.invalidExpressionOverrideMode',
        'vrm.invalidExpressionBindList',
      ]),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.invalidMorphTargetWeight')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.invalidMaterialColorMaterial')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.invalidTextureTransformMaterial')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.invalidExpressionOverrideMode')
          .length,
      2,
    );
    Iterable<String?> pathsFor(String code) => result.validation.errors
        .where((diagnostic) => diagnostic.code == code)
        .map((diagnostic) => diagnostic.jsonPath);

    expect(
      pathsFor('vrm.invalidMorphTargetWeight'),
      containsAll([
        r'$.extensions.VRMC_vrm.expressions.preset.happy.morphTargetBinds[0].weight',
        r'$.extensions.VRMC_vrm.expressions.preset.happy.morphTargetBinds[2].weight',
      ]),
    );
    expect(
      pathsFor('vrm.invalidMorphTargetIndex'),
      contains(
        r'$.extensions.VRMC_vrm.expressions.preset.happy.morphTargetBinds[0].index',
      ),
    );
    expect(
      pathsFor('vrm.invalidMorphTargetMesh'),
      contains(
        r'$.extensions.VRMC_vrm.expressions.preset.happy.morphTargetBinds[1].node',
      ),
    );
    expect(
      pathsFor('vrm.invalidMaterialColorMaterial'),
      containsAll([
        r'$.extensions.VRMC_vrm.expressions.preset.happy.materialColorBinds[0].material',
        r'$.extensions.VRMC_vrm.expressions.preset.happy.materialColorBinds[1].material',
      ]),
    );
    expect(
      pathsFor('vrm.invalidMaterialColorType'),
      contains(
        r'$.extensions.VRMC_vrm.expressions.preset.happy.materialColorBinds[2].type',
      ),
    );
    expect(
      pathsFor('vrm.invalidMaterialColorTargetValue'),
      contains(
        r'$.extensions.VRMC_vrm.expressions.preset.happy.materialColorBinds[4].targetValue',
      ),
    );
    expect(
      pathsFor('vrm.invalidTextureTransformMaterial'),
      containsAll([
        r'$.extensions.VRMC_vrm.expressions.preset.happy.textureTransformBinds[0].material',
        r'$.extensions.VRMC_vrm.expressions.preset.happy.textureTransformBinds[1].material',
      ]),
    );
    expect(
      pathsFor('vrm.invalidTextureTransformScale'),
      contains(
        r'$.extensions.VRMC_vrm.expressions.preset.happy.textureTransformBinds[2].scale',
      ),
    );
    expect(
      pathsFor('vrm.invalidTextureTransformOffset'),
      contains(
        r'$.extensions.VRMC_vrm.expressions.preset.happy.textureTransformBinds[2].offset',
      ),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.invalidExpressionOverrideMode')
          .map((d) => d.jsonPath),
      containsAll([
        r'$.extensions.VRMC_vrm.expressions.preset.happy.overrideBlink',
        r'$.extensions.VRMC_vrm.expressions.preset.happy.overrideMouth',
      ]),
    );
    expect(
      result.validation.errors
          .singleWhere((d) => d.code == 'vrm.invalidExpressionIsBinary')
          .jsonPath,
      r'$.extensions.VRMC_vrm.expressions.preset.happy.isBinary',
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.invalidExpressionBindList')
          .length,
      3,
    );
    expect(
      pathsFor('vrm.invalidExpressionBindList'),
      containsAll([
        r'$.extensions.VRMC_vrm.expressions.custom.badLists.morphTargetBinds',
        r'$.extensions.VRMC_vrm.expressions.custom.badLists.materialColorBinds',
        r'$.extensions.VRMC_vrm.expressions.custom.badLists.textureTransformBinds',
      ]),
    );
    expect(
      result.asset!.vrm.expressions.preset,
      isNot(containsPair(VrmExpressionPreset.angry, anything)),
    );

    final binding = _FakeBinding();
    final runtime = VrmRuntime(result.asset!)..bind(binding);
    runtime.emotion.set(VrmEmotion.happy, 1.0);
    runtime.update(0);

    expect(binding.meshes[0]?.weights.containsKey('0:2') ?? false, isFalse);
    expect(binding.meshes[1], isNull);
    expect(binding.materials[0]?.colors, isNull);
    expect(binding.materials[0]?.scale, isNull);
    expect(binding.materials[9], isNull);
  });

  test('reports invalid expression containers in permissive mode', () {
    final badRoot = _minimalVrmJson();
    final badRootVrm =
        (badRoot['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    badRootVrm['expressions'] = 'bad';

    final badGroups = _minimalVrmJson();
    final badGroupsVrm =
        (badGroups['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    badGroupsVrm['expressions'] = {'preset': 'bad', 'custom': <Object?>[]};

    final badNames = _minimalVrmJson();
    final badNamesVrm =
        (badNames['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    badNamesVrm['expressions'] = {
      'preset': {'notAPreset': <String, Object?>{}},
      'custom': {'happy': <String, Object?>{}, 'wink': <String, Object?>{}},
    };

    final badRootResult = VrmModel.tryParseGlb(
      _glb(badRoot),
      validation: VrmValidationMode.permissive,
    );
    final badGroupsResult = VrmModel.tryParseGlb(
      _glb(badGroups),
      validation: VrmValidationMode.permissive,
    );
    final badNamesResult = VrmModel.tryParseGlb(
      _glb(badNames),
      validation: VrmValidationMode.permissive,
    );

    expect(badRootResult.asset, isNotNull);
    expect(
      badRootResult.validation.errors.map((d) => d.code),
      contains('vrm.invalidExpressionsObject'),
    );
    expect(badGroupsResult.asset, isNotNull);
    expect(
      badGroupsResult.validation.errors
          .where((d) => d.code == 'vrm.invalidExpressionGroup')
          .length,
      2,
    );
    expect(badNamesResult.asset, isNotNull);
    expect(
      badNamesResult.validation.errors.map((d) => d.code),
      contains('vrm.customExpressionPresetCollision'),
    );
    expect(
      badNamesResult.validation.errors.map((d) => d.jsonPath),
      contains(r'$.extensions.VRMC_vrm.expressions.custom.happy'),
    );
    expect(
      badNamesResult.validation.warnings.map((d) => d.code),
      contains('vrm.unknownPresetExpression'),
    );
    expect(
      badNamesResult.validation.warnings.map((d) => d.jsonPath),
      contains(r'$.extensions.VRMC_vrm.expressions.preset.notAPreset'),
    );
    expect(
      badNamesResult.asset!.vrm.expressions.custom,
      isNot(containsPair('happy', anything)),
    );
    expect(
      badNamesResult.asset!.vrm.expressions.custom,
      containsPair('wink', isA<VrmExpression>()),
    );
  });

  test('reports malformed expression bind item objects', () {
    final json = _minimalVrmJson(
      expressions: {
        'preset': {
          'happy': {
            'morphTargetBinds': [null],
            'materialColorBinds': [null],
            'textureTransformBinds': [null],
          },
        },
      },
    );

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'vrm.invalidMorphTargetBindObject',
        'vrm.invalidMaterialColorBindObject',
        'vrm.invalidTextureTransformBindObject',
      ]),
    );
    Iterable<String?> pathsFor(String code) => result.validation.errors
        .where((diagnostic) => diagnostic.code == code)
        .map((diagnostic) => diagnostic.jsonPath);

    expect(
      pathsFor('vrm.invalidMorphTargetBindObject'),
      contains(
        r'$.extensions.VRMC_vrm.expressions.preset.happy.morphTargetBinds[0]',
      ),
    );
    expect(
      pathsFor('vrm.invalidMaterialColorBindObject'),
      contains(
        r'$.extensions.VRMC_vrm.expressions.preset.happy.materialColorBinds[0]',
      ),
    );
    expect(
      pathsFor('vrm.invalidTextureTransformBindObject'),
      contains(
        r'$.extensions.VRMC_vrm.expressions.preset.happy.textureTransformBinds[0]',
      ),
    );
  });

  test('reports procedural expressions overriding their own kind', () {
    final result = VrmModel.tryParseGlb(
      _glb(
        _minimalVrmJson(
          expressions: {
            'preset': {
              'aa': {'overrideMouth': 'blend'},
              'blink': {'overrideBlink': 'block'},
              'lookLeft': {'overrideLookAt': 'blend'},
            },
          },
        ),
      ),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors
          .where((d) => d.code == 'vrm.invalidExpressionOverrideKind')
          .map((d) => d.jsonPath),
      containsAll([
        r'$.extensions.VRMC_vrm.expressions.preset.aa.overrideMouth',
        r'$.extensions.VRMC_vrm.expressions.preset.blink.overrideBlink',
        r'$.extensions.VRMC_vrm.expressions.preset.lookLeft.overrideLookAt',
      ]),
    );
    final expressions = result.asset!.vrm.expressions.preset;
    expect(
      expressions[VrmExpressionPreset.aa]!.overrideMouth,
      VrmExpressionOverrideMode.none,
    );
    expect(
      expressions[VrmExpressionPreset.blink]!.overrideBlink,
      VrmExpressionOverrideMode.none,
    );
    expect(
      expressions[VrmExpressionPreset.lookLeft]!.overrideLookAt,
      VrmExpressionOverrideMode.none,
    );
  });

  test('LookAt expression mode drives look expression weights', () {
    final json = _minimalVrmJson(
      meshes: [
        {
          'primitives': [
            {
              'attributes': <String, Object?>{},
              'targets': [
                <String, Object?>{},
                <String, Object?>{},
                <String, Object?>{},
                <String, Object?>{},
              ],
            },
          ],
        },
      ],
      nodeMesh: {0: 0},
      expressions: {
        'preset': {
          'lookLeft': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
          'lookRight': {
            'morphTargetBinds': [
              {'node': 0, 'index': 1, 'weight': 1.0},
            ],
          },
          'lookUp': {
            'morphTargetBinds': [
              {'node': 0, 'index': 2, 'weight': 1.0},
            ],
          },
          'lookDown': {
            'morphTargetBinds': [
              {'node': 0, 'index': 3, 'weight': 1.0},
            ],
          },
        },
      },
    );
    final lookAt = _lookAtJson(type: 'expression');
    lookAt['extras'] = {'source': 'lookAt'};
    final horizontalInner = Map<String, Object?>.from(
      lookAt['rangeMapHorizontalInner']! as Map,
    );
    lookAt['rangeMapHorizontalInner'] = horizontalInner;
    horizontalInner['extras'] = {'source': 'horizontal-inner'};
    ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>)['lookAt'] =
        lookAt;
    final model = VrmModel.parseGlb(_glb(json));
    final runtime = VrmRuntime(model);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.lookAt.setYawPitch(yawDegrees: 45, pitchDegrees: -30);
    runtime.update(0);

    expect(binding.meshes[0]!.weights['0:0'], 0.5);
    expect(binding.meshes[0]!.weights['0:1'], 0.0);
    expect(binding.meshes[0]!.weights['0:2'], closeTo(1 / 3, 0.0001));
    expect(binding.meshes[0]!.weights['0:3'], 0.0);
    expect(model.vrm.lookAt!.raw['extras'], {'source': 'lookAt'});
    expect(model.vrm.lookAt!.rangeMapHorizontalInner.raw['extras'], {
      'source': 'horizontal-inner',
    });
  });

  test('LookAt range map with zero input max snaps nonzero gaze', () {
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
      nodeMesh: {0: 0},
      expressions: {
        'preset': {
          'lookLeft': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
        },
      },
    );
    final lookAt = _lookAtJson(type: 'expression');
    lookAt['rangeMapHorizontalOuter'] = {
      'inputMaxValue': 0.0,
      'outputScale': 0.75,
    };
    ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>)['lookAt'] =
        lookAt;
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.lookAt.setYawPitch(yawDegrees: 1, pitchDegrees: 0);
    runtime.update(0);

    expect(binding.meshes[0]!.weights['0:0'], 0.75);
  });

  test('reports invalid LookAt settings in permissive mode', () {
    final json = _minimalVrmJson();
    ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
        as Map<String, Object?>)['lookAt'] = {
      'type': 1,
      'offsetFromHeadBone': [0.0, 1.0],
      'rangeMapHorizontalInner': {'inputMaxValue': 181.0, 'outputScale': 'bad'},
      'rangeMapHorizontalOuter': {'inputMaxValue': -1.0},
      'rangeMapVerticalDown': 'bad',
      'rangeMapVerticalUp': null,
    };

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(result.asset!.vrm.lookAt, isNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'vrm.invalidLookAtType',
        'vrm.invalidLookAtOffset',
        'vrm.invalidLookAtRangeMapObject',
        'vrm.invalidLookAtRangeMapInput',
        'vrm.invalidLookAtRangeMapOutput',
      ]),
    );
    expect(
      result.validation.errors.map((d) => d.jsonPath),
      containsAll([
        r'$.extensions.VRMC_vrm.lookAt.rangeMapHorizontalInner.inputMaxValue',
        r'$.extensions.VRMC_vrm.lookAt.rangeMapHorizontalInner.outputScale',
        r'$.extensions.VRMC_vrm.lookAt.rangeMapHorizontalOuter.inputMaxValue',
        r'$.extensions.VRMC_vrm.lookAt.rangeMapVerticalDown',
        r'$.extensions.VRMC_vrm.lookAt.rangeMapVerticalUp',
      ]),
    );
  });

  test('reports invalid LookAt object in permissive mode', () {
    for (final value in ['bad', null]) {
      final json = Map<String, Object?>.from(_minimalVrmJson());
      final extensions = Map<String, Object?>.from(
        json['extensions']! as Map<String, Object?>,
      );
      final vrm = Map<String, Object?>.from(
        extensions['VRMC_vrm']! as Map<String, Object?>,
      );
      vrm['lookAt'] = value;
      extensions['VRMC_vrm'] = vrm;
      json['extensions'] = extensions;

      final result = VrmModel.tryParseGlb(
        _glb(json),
        validation: VrmValidationMode.permissive,
      );

      expect(result.asset, isNotNull);
      expect(result.asset!.vrm.lookAt, isNull);
      expect(
        result.validation.errors.map((d) => d.code),
        contains('vrm.invalidLookAtObject'),
      );
    }
  });

  test('runtime skips invalid LookAt type', () {
    final json = _minimalVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[2]['children'] = [15, 16];
    nodes
      ..add({'name': 'leftEye'})
      ..add({'name': 'rightEye'});
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    final humanBones =
        (vrm['humanoid']! as Map<String, Object?>)['humanBones']!
            as Map<String, Object?>;
    humanBones['leftEye'] = {'node': 15};
    humanBones['rightEye'] = {'node': 16};
    vrm['lookAt'] = _lookAtJson(
      type: 'bogus',
      horizontalInnerOutput: 10,
      horizontalOuterOutput: 20,
    );

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );
    final runtime = VrmRuntime(result.asset!);
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.lookAt.setYawPitch(yawDegrees: 90, pitchDegrees: 0);
    runtime.update(0);

    expect(binding.nodes[15]!.localTransform.storage[0], 1.0);
    expect(binding.nodes[16]!.localTransform.storage[0], 1.0);
  });

  test('LookAt world target converts through model root transform', () {
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
      nodeMesh: {0: 0},
      expressions: {
        'preset': {
          'lookLeft': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
        },
      },
    );
    ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
        as Map<String, Object?>)['lookAt'] = _lookAtJson(
      type: 'expression',
    );
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.lookAt.lookAtWorld(
      const VrmVector3(11, 0, 1),
      modelWorldTransform: _testTrs(translation: const [10, 0, 0]),
    );
    runtime.update(0);

    expect(binding.meshes[0]!.weights['0:0'], closeTo(0.5, 0.0001));
  });

  test('LookAt world target accounts for runtime root motion', () {
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
      nodeMesh: {0: 0},
      expressions: {
        'preset': {
          'lookLeft': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
        },
      },
    );
    ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
        as Map<String, Object?>)['lookAt'] = _lookAtJson(
      type: 'expression',
    );
    final vrmaBinary = _floats([0.0, 1.0, 0.0, 0.0, 0.0, 10.0, 0.0, 0.0]);
    final vrmaJson =
        <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {'name': 'sourceHips'},
            ],
          }
          ..addAll(
            _animationStorageJson(vrmaBinary.length, [
              [0, 8],
              [8, 24],
            ]),
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
          ]
          ..['extensions'] = {
            'VRMC_vrm_animation': {
              'specVersion': '1.0',
              'humanoid': {
                'humanBones': {
                  'hips': {'node': 0},
                },
              },
            },
          };
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.playVrmAnimation(
      VrmAnimationAsset.parse(
        bytes: _glb(vrmaJson, binaryChunk: vrmaBinary),
        validation: VrmValidationMode.permissive,
      ),
    );
    runtime.lookAt.lookAtWorld(const VrmVector3(11, 0, 1));
    runtime.update(1);

    expect(binding.modelRootMotionTransform.storage[12], 10.0);
    expect(binding.meshes[0]!.weights['0:0'], closeTo(0.5, 0.0001));
  });

  test('LookAt world target accounts for rotated model root', () {
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
      nodeMesh: {0: 0},
      expressions: {
        'preset': {
          'lookLeft': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
        },
      },
    );
    ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
        as Map<String, Object?>)['lookAt'] = _lookAtJson(
      type: 'expression',
    );
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.lookAt.lookAtWorld(
      const VrmVector3(1, 0, 0),
      modelWorldTransform: _testTrs(
        rotation: [0.0, math.sqrt1_2, 0.0, math.sqrt1_2],
      ),
    );
    runtime.update(0);

    expect(binding.meshes[0]!.weights['0:0'], 0.0);
  });

  test('LookAt target uses the current animated head position', () {
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
      nodeMesh: {0: 0},
      expressions: {
        'preset': {
          'lookRight': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
        },
      },
    );
    ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
        as Map<String, Object?>)['lookAt'] = _lookAtJson(
      type: 'expression',
    );
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.play(
      VrmProgrammaticPose(
        nodePoses: {
          2: GltfNodePose(translation: [10.0, 0.0, 0.0]),
        },
      ),
    );
    runtime.lookAt.lookAtModel(const VrmVector3(0, 0, 1));
    runtime.update(0);

    expect(binding.meshes[0]!.weights['0:0'], greaterThan(0.9));
  });

  test('LookAt target composes animated parent transforms', () {
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
      nodeMesh: {0: 0},
      expressions: {
        'preset': {
          'lookRight': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
        },
      },
    );
    ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
        as Map<String, Object?>)['lookAt'] = _lookAtJson(
      type: 'expression',
    );
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();
    final quarterTurnY = [0.0, math.sqrt1_2, 0.0, math.sqrt1_2];

    runtime.bind(binding);
    runtime.motion.play(
      VrmProgrammaticPose(
        nodePoses: {
          1: GltfNodePose(rotation: quarterTurnY),
          2: GltfNodePose(translation: [0.0, 0.0, 1.0]),
        },
      ),
    );
    runtime.lookAt.lookAtModel(const VrmVector3(0, 0, 1));
    runtime.update(0);

    expect(binding.meshes[0]!.weights['0:0'], 1.0);
  });

  test('LookAt target applies head-local offset in LookAt space', () {
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
      nodeMesh: {0: 0},
      expressions: {
        'preset': {
          'lookRight': {
            'morphTargetBinds': [
              {'node': 0, 'index': 0, 'weight': 1.0},
            ],
          },
        },
      },
    );
    (json['nodes']! as List<Map<String, Object?>>)[2]['rotation'] = [
      0.0,
      math.sqrt1_2,
      0.0,
      math.sqrt1_2,
    ];
    final lookAt = _lookAtJson(type: 'expression');
    lookAt['offsetFromHeadBone'] = [1.0, 0.0, 0.0];
    ((json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>)['lookAt'] =
        lookAt;
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.lookAt.lookAtModel(VrmVector3.zero);
    runtime.update(0);

    expect(binding.meshes[0]!.weights['0:0'], 0.0);
  });

  test('LookAt bone mode applies eye local transforms', () {
    final json = _minimalVrmJson();
    final nodes = json['nodes']! as List<Map<String, Object?>>;
    nodes[2]['children'] = [15, 16];
    nodes
      ..add({'name': 'leftEye'})
      ..add({'name': 'rightEye'});
    final vrm =
        (json['extensions']! as Map<String, Object?>)['VRMC_vrm']!
            as Map<String, Object?>;
    final humanBones =
        (vrm['humanoid']! as Map<String, Object?>)['humanBones']!
            as Map<String, Object?>;
    humanBones['leftEye'] = {'node': 15};
    humanBones['rightEye'] = {'node': 16};
    final lookAt = _lookAtJson(
      type: 'bone',
      horizontalInnerOutput: 10,
      horizontalOuterOutput: 20,
    );
    (lookAt['rangeMapVerticalDown']! as Map<String, Object?>)['outputScale'] =
        30.0;
    (lookAt['rangeMapVerticalUp']! as Map<String, Object?>)['outputScale'] =
        40.0;
    vrm['lookAt'] = lookAt;
    final runtime = VrmRuntime(VrmModel.parseGlb(_glb(json)));
    final binding = _FakeBinding();

    runtime.bind(binding);
    runtime.motion.play(
      VrmProgrammaticPose(
        nodePoses: {
          15: GltfNodePose(translation: [2.0, 0.0, 0.0]),
        },
      ),
    );
    runtime.lookAt.setYawPitch(yawDegrees: 90, pitchDegrees: 0);
    runtime.update(0);

    expect(binding.nodes[15]!.localTransform.storage[12], 2.0);
    expect(
      binding.nodes[15]!.localTransform.storage[0],
      closeTo(mathCosDegrees(20), 0.0001),
    );
    expect(
      binding.nodes[16]!.localTransform.storage[0],
      closeTo(mathCosDegrees(10), 0.0001),
    );

    runtime.lookAt.setYawPitch(yawDegrees: -90, pitchDegrees: 0);
    runtime.update(0);
    expect(
      binding.nodes[15]!.localTransform.storage[0],
      closeTo(mathCosDegrees(10), 0.0001),
    );
    expect(
      binding.nodes[16]!.localTransform.storage[0],
      closeTo(mathCosDegrees(20), 0.0001),
    );

    runtime.lookAt.setYawPitch(yawDegrees: 0, pitchDegrees: 90);
    runtime.update(0);
    for (final eye in [15, 16]) {
      expect(
        binding.nodes[eye]!.localTransform.storage[5],
        closeTo(mathCosDegrees(30), 0.0001),
      );
      expect(
        binding.nodes[eye]!.localTransform.storage[6],
        closeTo(math.sin(30 * math.pi / 180), 0.0001),
      );
    }

    runtime.lookAt.setYawPitch(yawDegrees: 0, pitchDegrees: -90);
    runtime.update(0);
    for (final eye in [15, 16]) {
      expect(
        binding.nodes[eye]!.localTransform.storage[5],
        closeTo(mathCosDegrees(40), 0.0001),
      );
      expect(
        binding.nodes[eye]!.localTransform.storage[6],
        closeTo(-math.sin(40 * math.pi / 180), 0.0001),
      );
    }
  });
}
