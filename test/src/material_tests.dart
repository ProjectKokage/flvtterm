part of '../flvtterm_test.dart';

void materialTests() {
  test('parses MToon material metadata and validates extension fields', () {
    final json =
        _minimalVrmJson(
            materials: [
              {
                'pbrMetallicRoughness': {
                  'baseColorFactor': [0.9, 0.8, 0.7, 0.6],
                  'metallicFactor': 0.25,
                  'roughnessFactor': 0.75,
                  'baseColorTexture': {'index': 0, 'texCoord': 1},
                  'metallicRoughnessTexture': {'index': 0},
                  'extensions': {
                    'VENDOR_pbr': {
                      'mode': 'debug',
                      'tags': ['source'],
                    },
                  },
                  'extras': {'source': 'pbr'},
                },
                'alphaMode': 'MASK',
                'alphaCutoff': 0.4,
                'doubleSided': true,
                'normalTexture': {'index': 0, 'scale': 0.8},
                'occlusionTexture': {'index': 0, 'strength': 0.6},
                'emissiveFactor': [0.2, 0.3, 0.4],
                'emissiveTexture': {'index': 0},
                'extensions': {
                  'KHR_materials_emissive_strength': {'emissiveStrength': 2.5},
                  'KHR_materials_unlit': {},
                  'VRMC_materials_mtoon': {
                    'specVersion': '1.0',
                    'transparentWithZWrite': true,
                    'renderQueueOffsetNumber': 0,
                    'shadeColorFactor': [0.1, 0.2, 0.3],
                    'shadeMultiplyTexture': {
                      'index': 0,
                      'texCoord': 1,
                      'extensions': {
                        'KHR_texture_transform': {
                          'offset': [0.25, 0.5],
                          'rotation': 1.5,
                          'scale': [2.0, 3.0],
                          'texCoord': 2,
                          'extras': {'transform': 1},
                        },
                      },
                    },
                    'shadingShiftFactor': -0.2,
                    'shadingShiftTexture': {'index': 0, 'scale': 0.4},
                    'shadingToonyFactor': 0.8,
                    'giEqualizationFactor': 0.7,
                    'matcapFactor': [0.9, 0.8, 0.7],
                    'matcapTexture': {'index': 0},
                    'parametricRimColorFactor': [0.4, 0.5, 0.6],
                    'rimMultiplyTexture': {'index': 0},
                    'rimLightingMixFactor': 0.25,
                    'parametricRimFresnelPowerFactor': 2.0,
                    'parametricRimLiftFactor': 0.1,
                    'outlineWidthMode': 'worldCoordinates',
                    'outlineWidthFactor': 0.01,
                    'outlineWidthMultiplyTexture': {'index': 0},
                    'outlineColorFactor': [0.0, 0.1, 0.2],
                    'outlineLightingMixFactor': 0.3,
                    'uvAnimationMaskTexture': {'index': 0},
                    'uvAnimationScrollXSpeedFactor': 0.4,
                    'uvAnimationScrollYSpeedFactor': 0.5,
                    'uvAnimationRotationSpeedFactor': 0.6,
                    'extensions': {
                      'VENDOR_mtoon': {
                        'mode': 'debug',
                        'tags': ['source'],
                      },
                    },
                    'extras': {'source': 'mtoon'},
                  },
                },
              },
              {
                'normalTexture': {'index': 0},
                'occlusionTexture': {'index': 0},
                'extensions': {
                  'VRMC_materials_mtoon': {
                    'specVersion': '1.0',
                    'shadingShiftTexture': {'index': 0},
                  },
                },
              },
            ],
          )
          ..['textures'] = [
            {'source': 0, 'sampler': 0},
          ]
          ..['samplers'] = [
            {'magFilter': 9729, 'minFilter': 9987, 'wrapS': 33071},
          ]
          ..['images'] = [
            {'uri': 'data:image/png;base64,'},
          ];
    (json['extensionsUsed']! as List<Object?>).add('VRMC_materials_mtoon');
    (json['extensionsUsed']! as List<Object?>).add(
      'KHR_materials_emissive_strength',
    );
    (json['extensionsUsed']! as List<Object?>).add('KHR_materials_unlit');
    (json['extensionsUsed']! as List<Object?>).add('KHR_texture_transform');
    (json['extensionsUsed']! as List<Object?>).add('VENDOR_pbr');
    (json['extensionsUsed']! as List<Object?>).add('VENDOR_mtoon');

    final model = VrmModel.parseGlb(_glb(json));
    final material = model.gltf.materials.first;
    final mtoon = model.gltf.materials.first.mtoon!;
    final defaultMToon = model.gltf.materials[1].mtoon!;

    expect(model.gltf.textures.single.sampler, 0);
    expect(model.gltf.samplers.single.magFilter, 9729);
    expect(model.gltf.samplers.single.wrapS, 33071);
    expect(model.gltf.samplers.single.wrapT, 10497);
    expect(material.baseColorFactor, VrmVector4(0.9, 0.8, 0.7, 0.6));
    expect(material.baseColorTexture!.index, 0);
    expect(material.baseColorTexture!.texCoord, 1);
    expect(material.metallicFactor, 0.25);
    expect(material.roughnessFactor, 0.75);
    expect(material.metallicRoughnessTexture!.index, 0);
    expect(material.pbrMetallicRoughnessExtensions, {
      'VENDOR_pbr': {
        'mode': 'debug',
        'tags': ['source'],
      },
    });
    final pbrExtension =
        material.pbrMetallicRoughnessExtensions['VENDOR_pbr']!
            as Map<String, Object?>;
    final pbrTags = pbrExtension['tags']! as List<Object?>;
    expect(() => pbrExtension['other'] = true, throwsUnsupportedError);
    expect(() => pbrTags.add('copy'), throwsUnsupportedError);
    expect(material.pbrMetallicRoughnessExtras, {'source': 'pbr'});
    expect(
      () =>
          (material.pbrMetallicRoughnessExtras! as Map<String, Object?>)['x'] =
              true,
      throwsUnsupportedError,
    );
    expect(material.normalTexture!.scale, 0.8);
    expect(material.occlusionTexture!.strength, 0.6);
    expect(model.gltf.materials[1].normalTexture!.scale, 1);
    expect(model.gltf.materials[1].occlusionTexture!.strength, 1);
    expect(material.emissiveFactor, VrmVector4(0.2, 0.3, 0.4, 1.0));
    expect(model.gltf.materials[1].emissiveFactor, VrmVector4(0, 0, 0, 1));
    expect(material.emissiveTexture!.index, 0);
    expect(material.emissiveStrength, 2.5);
    expect(material.alphaMode, GltfAlphaMode.mask);
    expect(material.alphaCutoff, 0.4);
    expect(material.doubleSided, isTrue);
    expect(material.unlit, isTrue);
    expect(material.preferredRenderMode(), GltfMaterialRenderMode.mtoon);
    expect(
      material.preferredRenderMode(supportsMToon: false),
      GltfMaterialRenderMode.unlit,
    );
    expect(
      material.mtoonFallbackWarning()!,
      isA<VrmDiagnostic>()
          .having((d) => d.code, 'code', 'mtoon.fallback')
          .having((d) => d.gltfMaterialIndex, 'gltfMaterialIndex', 0),
    );
    expect(mtoon.specVersion, '1.0');
    expect(mtoon.transparentWithZWrite, isTrue);
    expect(mtoon.renderQueueOffsetNumber, 0);
    expect(mtoon.shadeColorFactor, VrmVector4(0.1, 0.2, 0.3, 1.0));
    expect(mtoon.shadeMultiplyTexture!.index, 0);
    expect(mtoon.shadeMultiplyTexture!.texCoord, 1);
    expect(
      mtoon.shadeMultiplyTexture!.textureTransform!.offset,
      VrmVector2(0.25, 0.5),
    );
    expect(mtoon.shadeMultiplyTexture!.textureTransform!.rotation, 1.5);
    expect(
      mtoon.shadeMultiplyTexture!.textureTransform!.scale,
      VrmVector2(2.0, 3.0),
    );
    expect(mtoon.shadeMultiplyTexture!.textureTransform!.texCoord, 2);
    expect(mtoon.shadeMultiplyTexture!.textureTransform!.raw['extras'], {
      'transform': 1,
    });
    expect(mtoon.shadingShiftTexture!.scale, 0.4);
    expect(mtoon.shadingShiftFactor, -0.2);
    expect(mtoon.shadingToonyFactor, 0.8);
    expect(mtoon.giEqualizationFactor, 0.7);
    expect(mtoon.matcapFactor, VrmVector4(0.9, 0.8, 0.7, 1.0));
    expect(mtoon.matcapTexture!.index, 0);
    expect(mtoon.parametricRimColorFactor, VrmVector4(0.4, 0.5, 0.6, 1.0));
    expect(mtoon.rimMultiplyTexture!.index, 0);
    expect(mtoon.rimLightingMixFactor, 0.25);
    expect(mtoon.parametricRimFresnelPowerFactor, 2.0);
    expect(mtoon.parametricRimLiftFactor, 0.1);
    expect(mtoon.outlineWidthMode, VrmMToonOutlineWidthMode.worldCoordinates);
    expect(mtoon.outlineWidthFactor, 0.01);
    expect(mtoon.outlineWidthMultiplyTexture!.index, 0);
    expect(mtoon.outlineColorFactor, VrmVector4(0.0, 0.1, 0.2, 1.0));
    expect(mtoon.outlineLightingMixFactor, 0.3);
    expect(mtoon.uvAnimationMaskTexture!.index, 0);
    expect(mtoon.uvAnimationScrollXSpeedFactor, 0.4);
    expect(mtoon.uvAnimationScrollYSpeedFactor, 0.5);
    expect(mtoon.uvAnimationRotationSpeedFactor, 0.6);
    expect(mtoon.extensions, {
      'VENDOR_mtoon': {
        'mode': 'debug',
        'tags': ['source'],
      },
    });
    final mtoonExtension =
        mtoon.extensions['VENDOR_mtoon']! as Map<String, Object?>;
    final mtoonTags = mtoonExtension['tags']! as List<Object?>;
    expect(() => mtoonExtension['other'] = true, throwsUnsupportedError);
    expect(() => mtoonTags.add('copy'), throwsUnsupportedError);
    expect(mtoon.extras, {'source': 'mtoon'});
    expect(
      () => (mtoon.extras! as Map<String, Object?>)['x'] = true,
      throwsUnsupportedError,
    );
    expect(
      () => material.pbrMetallicRoughnessExtensions['VENDOR_other'] = {},
      throwsUnsupportedError,
    );
    expect(
      () => material.extensions['VENDOR_other'] = {},
      throwsUnsupportedError,
    );
    expect(
      () => material.baseColorTexture!.raw['extra'] = 1,
      throwsUnsupportedError,
    );
    expect(
      () => mtoon.shadeMultiplyTexture!.textureTransform!.raw['extra'] = 1,
      throwsUnsupportedError,
    );
    expect(() => mtoon.extensions['VENDOR_other'] = {}, throwsUnsupportedError);
    expect(() => mtoon.raw['extra'] = 1, throwsUnsupportedError);
    expect(defaultMToon.shadingShiftTexture!.scale, 1);
    expect(
      model.gltf.materials[1].preferredRenderMode(supportsMToon: false),
      GltfMaterialRenderMode.pbr,
    );
    expect(defaultMToon.shadeColorFactor, VrmVector4.white);
    expect(defaultMToon.parametricRimColorFactor, VrmVector4(0, 0, 0, 1));
    expect(defaultMToon.outlineColorFactor, VrmVector4(0, 0, 0, 1));
  });

  test('does not enable malformed material extensions', () {
    final json = _minimalVrmJson(
      materials: [
        {
          'extensions': {
            'KHR_materials_emissive_strength': null,
            'KHR_materials_unlit': null,
            'VRMC_materials_mtoon': null,
          },
        },
      ],
    );
    (json['extensionsUsed']! as List<Object?>).add(
      'KHR_materials_emissive_strength',
    );
    (json['extensionsUsed']! as List<Object?>).add('KHR_materials_unlit');
    (json['extensionsUsed']! as List<Object?>).add('VRMC_materials_mtoon');

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'gltf.invalidMaterialEmissiveStrengthObject',
        'gltf.invalidMaterialUnlitObject',
        'mtoon.invalidExtensionObject',
      ]),
    );
    expect(result.asset!.gltf.materials.single.unlit, isFalse);
    expect(result.asset!.gltf.materials.single.mtoon, isNull);
  });

  test('reports invalid MToon metadata in permissive mode', () {
    final json =
        _minimalVrmJson(
            materials: [
              {
                'pbrMetallicRoughness': {
                  'baseColorFactor': [1.2, 0.0, 0.0],
                  'metallicFactor': 1.5,
                  'roughnessFactor': -0.1,
                  'baseColorTexture': {
                    'index': 9,
                    'texCoord': -1,
                    'extensions': {
                      'KHR_texture_transform': {
                        'offset': [0.0],
                        'scale': [1.0, 'bad'],
                        'rotation': 'bad',
                        'texCoord': -2,
                      },
                    },
                  },
                },
                'alphaMode': 'PUNCHTHROUGH',
                'alphaCutoff': -1,
                'doubleSided': 'yes',
                'normalTexture': {
                  'index': 0,
                  'scale': 'bad',
                  'extensions': {'KHR_texture_transform': 'bad'},
                },
                'emissiveFactor': [0.0, 2.0, 0.0],
                'emissiveTexture': {'texCoord': 0},
                'occlusionTexture': {'index': 0, 'strength': 2.0},
                'extensions': {
                  'KHR_materials_emissive_strength': {'emissiveStrength': -1},
                  'VRMC_materials_mtoon': {
                    'specVersion': '0.9',
                    'transparentWithZWrite': 'yes',
                    'renderQueueOffsetNumber': 42,
                    'shadeColorFactor': [1.2, 0.0, 0.0],
                    'shadingShiftFactor': 'bad',
                    'shadingToonyFactor': 2.0,
                    'giEqualizationFactor': -0.1,
                    'matcapFactor': [0.0, 0.0],
                    'rimLightingMixFactor': 2.0,
                    'parametricRimFresnelPowerFactor': -1.0,
                    'parametricRimLiftFactor': 'bad',
                    'outlineWidthMode': 'wide',
                    'outlineWidthFactor': -0.01,
                    'outlineLightingMixFactor': 2.0,
                    'shadingShiftTexture': {
                      'index': 0,
                      'texCoord': 'bad',
                      'scale': 'bad',
                    },
                    'matcapTexture': {
                      'index': 7,
                      'texCoord': -1,
                      'extensions': {
                        'KHR_texture_transform': {
                          'offset': [0.0],
                          'scale': [1.0],
                          'rotation': 'bad',
                          'texCoord': -1,
                        },
                      },
                    },
                    'uvAnimationScrollXSpeedFactor': 'bad',
                    'uvAnimationScrollYSpeedFactor': 'bad',
                    'uvAnimationRotationSpeedFactor': 'bad',
                  },
                },
              },
              {
                'extensions': {
                  'KHR_materials_emissive_strength': 'bad',
                  'KHR_materials_unlit': 'bad',
                  'VRMC_materials_mtoon': {
                    'specVersion': '1.0',
                    'renderQueueOffsetNumber': 'bad',
                    'outlineWidthMode': 7,
                  },
                },
              },
              {
                'extensions': {'VRMC_materials_mtoon': 'bad'},
              },
              {'alphaCutoff': 0.5},
            ],
          )
          ..['textures'] = [
            {'sampler': 3},
            {'sampler': 0},
            {'sampler': 'bad', 'source': 'bad'},
          ]
          ..['samplers'] = [
            {'magFilter': 1, 'minFilter': 2, 'wrapS': 3, 'wrapT': 4},
            {
              'magFilter': 'bad',
              'minFilter': 'bad',
              'wrapS': 'bad',
              'wrapT': 'bad',
            },
          ]
          ..['images'] = [
            {'uri': 'data:image/png;base64,', 'bufferView': 0},
            {'uri': 1, 'bufferView': 'bad', 'mimeType': 3},
            {},
          ];

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      containsAll([
        'mtoon.unsupportedSpecVersion',
        'mtoon.invalidTransparentWithZWrite',
        'mtoon.invalidRenderQueueOffsetType',
        'mtoon.invalidRenderQueueOffset',
        'mtoon.invalidOutlineWidthMode',
        'mtoon.invalidNumber',
        'mtoon.invalidFactor',
        'mtoon.invalidColorFactor',
        'mtoon.invalidTextureScale',
        'mtoon.invalidTexture',
        'gltf.invalidMaterialBaseColorFactor',
        'gltf.invalidMaterialMetallicFactor',
        'gltf.invalidMaterialRoughnessFactor',
        'gltf.invalidMaterialEmissiveFactor',
        'gltf.invalidMaterialEmissiveStrength',
        'gltf.invalidMaterialEmissiveStrengthObject',
        'gltf.invalidMaterialUnlitObject',
        'gltf.invalidMaterialAlphaMode',
        'gltf.invalidMaterialAlphaCutoff',
        'gltf.materialAlphaCutoffWithoutAlphaMode',
        'gltf.invalidMaterialDoubleSided',
        'gltf.invalidNormalTextureScale',
        'gltf.invalidMaterialBaseColorTexture',
        'gltf.invalidMaterialEmissiveTexture',
        'gltf.invalidTextureTexCoord',
        'gltf.invalidTextureStrength',
        'gltf.invalidTextureTransformOffset',
        'gltf.invalidTextureTransformScale',
        'gltf.invalidTextureTransformRotation',
        'gltf.invalidTextureTransformTexCoord',
        'gltf.invalidTextureTransformObject',
        'mtoon.invalidExtensionObject',
        'gltf.invalidTextureSampler',
        'gltf.invalidSamplerMagFilter',
        'gltf.invalidSamplerMinFilter',
        'gltf.invalidSamplerWrapS',
        'gltf.invalidSamplerWrapT',
        'gltf.missingImageSource',
        'gltf.invalidImageUri',
        'gltf.invalidImageBufferView',
        'gltf.invalidImageMimeType',
        'gltf.invalidImageSource',
        'gltf.missingImageMimeType',
      ]),
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'mtoon.invalidOutlineWidthMode')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'mtoon.invalidNumber')
          .length,
      5,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidTextureTexCoord')
          .length,
      3,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidTextureTransformOffset')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidTextureTransformScale')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidTextureTransformRotation')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidTextureTransformTexCoord')
          .length,
      2,
    );
    expect(
      result.validation.errors
          .singleWhere((d) => d.code == 'gltf.invalidMaterialBaseColorTexture')
          .gltfMaterialIndex,
      0,
    );
    expect(
      result.validation.errors
          .where((d) => d.code == 'gltf.invalidTextureTransformTexCoord')
          .map((d) => d.gltfMaterialIndex),
      everyElement(0),
    );
    for (final code in [
      'gltf.invalidSamplerMagFilter',
      'gltf.invalidSamplerMinFilter',
      'gltf.invalidSamplerWrapS',
      'gltf.invalidSamplerWrapT',
    ]) {
      expect(result.validation.errors.where((d) => d.code == code).length, 2);
    }

    Iterable<String?> pathsFor(String code) => result.validation.errors
        .where((diagnostic) => diagnostic.code == code)
        .map((diagnostic) => diagnostic.jsonPath);

    expect(
      pathsFor('gltf.invalidMaterialBaseColorFactor'),
      contains(r'$.materials[0].pbrMetallicRoughness.baseColorFactor'),
    );
    expect(
      pathsFor('gltf.invalidMaterialMetallicFactor'),
      contains(r'$.materials[0].pbrMetallicRoughness.metallicFactor'),
    );
    expect(
      pathsFor('gltf.invalidMaterialRoughnessFactor'),
      contains(r'$.materials[0].pbrMetallicRoughness.roughnessFactor'),
    );
    expect(
      pathsFor('gltf.invalidMaterialEmissiveFactor'),
      contains(r'$.materials[0].emissiveFactor'),
    );
    expect(
      pathsFor('gltf.invalidMaterialEmissiveStrength'),
      contains(
        r'$.materials[0].extensions.KHR_materials_emissive_strength.emissiveStrength',
      ),
    );
    expect(
      pathsFor('gltf.invalidMaterialEmissiveStrengthObject'),
      contains(r'$.materials[1].extensions.KHR_materials_emissive_strength'),
    );
    expect(
      pathsFor('gltf.invalidMaterialUnlitObject'),
      contains(r'$.materials[1].extensions.KHR_materials_unlit'),
    );
    expect(
      pathsFor('gltf.invalidMaterialAlphaMode'),
      contains(r'$.materials[0].alphaMode'),
    );
    expect(
      pathsFor('gltf.invalidMaterialAlphaCutoff'),
      contains(r'$.materials[0].alphaCutoff'),
    );
    expect(
      pathsFor('gltf.materialAlphaCutoffWithoutAlphaMode'),
      contains(r'$.materials[3].alphaCutoff'),
    );
    expect(
      pathsFor('gltf.invalidMaterialDoubleSided'),
      contains(r'$.materials[0].doubleSided'),
    );
    expect(
      pathsFor('gltf.invalidNormalTextureScale'),
      contains(r'$.materials[0].normalTexture.scale'),
    );
    expect(
      pathsFor('gltf.invalidMaterialBaseColorTexture'),
      contains(r'$.materials[0].pbrMetallicRoughness.baseColorTexture'),
    );
    expect(
      pathsFor('gltf.invalidMaterialEmissiveTexture'),
      contains(r'$.materials[0].emissiveTexture'),
    );
    expect(
      pathsFor('gltf.invalidTextureStrength'),
      contains(r'$.materials[0].occlusionTexture.strength'),
    );
    expect(
      pathsFor('gltf.invalidTextureTransformObject'),
      contains(
        r'$.materials[0].normalTexture.extensions.KHR_texture_transform',
      ),
    );
    expect(
      pathsFor('gltf.invalidTextureSampler'),
      containsAll([r'$.textures[0].sampler', r'$.textures[2].sampler']),
    );
    expect(
      pathsFor('gltf.invalidTextureSource'),
      contains(r'$.textures[2].source'),
    );
    expect(
      pathsFor('gltf.invalidSamplerMagFilter'),
      containsAll([r'$.samplers[0].magFilter', r'$.samplers[1].magFilter']),
    );
    expect(
      pathsFor('gltf.invalidSamplerMinFilter'),
      containsAll([r'$.samplers[0].minFilter', r'$.samplers[1].minFilter']),
    );
    expect(
      pathsFor('gltf.invalidSamplerWrapS'),
      containsAll([r'$.samplers[0].wrapS', r'$.samplers[1].wrapS']),
    );
    expect(
      pathsFor('gltf.invalidSamplerWrapT'),
      containsAll([r'$.samplers[0].wrapT', r'$.samplers[1].wrapT']),
    );
    expect(pathsFor('gltf.invalidImageUri'), contains(r'$.images[1].uri'));
    expect(
      pathsFor('gltf.invalidImageBufferView'),
      contains(r'$.images[1].bufferView'),
    );
    expect(
      pathsFor('gltf.invalidImageMimeType'),
      contains(r'$.images[1].mimeType'),
    );
    expect(pathsFor('gltf.invalidImageSource'), contains(r'$.images[0]'));
    expect(
      pathsFor('gltf.missingImageMimeType'),
      contains(r'$.images[0].mimeType'),
    );
    expect(pathsFor('gltf.missingImageSource'), contains(r'$.images[2]'));

    expect(
      pathsFor('mtoon.unsupportedSpecVersion'),
      contains(r'$.materials[0].extensions.VRMC_materials_mtoon.specVersion'),
    );
    expect(
      pathsFor('mtoon.invalidTransparentWithZWrite'),
      contains(
        r'$.materials[0].extensions.VRMC_materials_mtoon.transparentWithZWrite',
      ),
    );
    expect(
      pathsFor('mtoon.invalidRenderQueueOffsetType'),
      contains(
        r'$.materials[1].extensions.VRMC_materials_mtoon.renderQueueOffsetNumber',
      ),
    );
    expect(
      pathsFor('mtoon.invalidRenderQueueOffset'),
      contains(
        r'$.materials[0].extensions.VRMC_materials_mtoon.renderQueueOffsetNumber',
      ),
    );
    expect(
      pathsFor('mtoon.invalidOutlineWidthMode'),
      contains(
        r'$.materials[1].extensions.VRMC_materials_mtoon.outlineWidthMode',
      ),
    );
    expect(
      pathsFor('mtoon.invalidNumber'),
      contains(
        r'$.materials[0].extensions.VRMC_materials_mtoon.shadingShiftFactor',
      ),
    );
    expect(
      pathsFor('mtoon.invalidFactor'),
      contains(
        r'$.materials[0].extensions.VRMC_materials_mtoon.shadingToonyFactor',
      ),
    );
    expect(
      pathsFor('mtoon.invalidColorFactor'),
      contains(
        r'$.materials[0].extensions.VRMC_materials_mtoon.shadeColorFactor',
      ),
    );
    expect(
      pathsFor('mtoon.invalidTextureScale'),
      contains(
        r'$.materials[0].extensions.VRMC_materials_mtoon.shadingShiftTexture.scale',
      ),
    );
    expect(
      pathsFor('mtoon.invalidTexture'),
      contains(r'$.materials[0].extensions.VRMC_materials_mtoon.matcapTexture'),
    );
    expect(
      pathsFor('mtoon.invalidExtensionObject'),
      contains(r'$.materials[2].extensions.VRMC_materials_mtoon'),
    );
  });

  test('reports missing MToon specVersion', () {
    final json = _minimalVrmJson(
      materials: [
        {
          'extensions': {'VRMC_materials_mtoon': <String, Object?>{}},
        },
      ],
    );
    (json['extensionsUsed']! as List<Object?>).add('VRMC_materials_mtoon');

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors.map((d) => d.code),
      contains('mtoon.missingSpecVersion'),
    );
    expect(
      result.validation.errors.map((d) => d.code),
      isNot(contains('mtoon.unsupportedSpecVersion')),
    );
  });

  test('reports MToon texture info without index', () {
    final json = _minimalVrmJson(
      materials: [
        {
          'extensions': {
            'VRMC_materials_mtoon': {
              'specVersion': '1.0',
              'shadeMultiplyTexture': {'texCoord': 0},
              'rimMultiplyTexture': 'bad',
            },
          },
        },
      ],
    );
    (json['extensionsUsed']! as List<Object?>).add('VRMC_materials_mtoon');

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    expect(result.asset, isNotNull);
    expect(
      result.validation.errors
          .where((d) => d.code == 'mtoon.invalidTexture')
          .map((d) => d.jsonPath),
      containsAll([
        r'$.materials[0].extensions.VRMC_materials_mtoon.shadeMultiplyTexture',
        r'$.materials[0].extensions.VRMC_materials_mtoon.rimMultiplyTexture',
      ]),
    );
  });

  test('validates texture info fields when index is missing', () {
    final json = _minimalVrmJson(
      materials: [
        {
          'pbrMetallicRoughness': {
            'baseColorTexture': {
              'texCoord': -1,
              'extensions': {
                'KHR_texture_transform': {'rotation': 'bad'},
              },
            },
          },
          'normalTexture': {'scale': 'bad'},
          'occlusionTexture': {'strength': 2.0},
          'extensions': {
            'VRMC_materials_mtoon': {
              'specVersion': '1.0',
              'shadingShiftTexture': {
                'scale': 'bad',
                'extensions': {
                  'KHR_texture_transform': {
                    'scale': [1.0],
                  },
                },
              },
            },
          },
        },
      ],
    );
    (json['extensionsUsed']! as List<Object?>).add('KHR_texture_transform');
    (json['extensionsUsed']! as List<Object?>).add('VRMC_materials_mtoon');

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );

    Iterable<String?> pathsFor(String code) => result.validation.errors
        .where((diagnostic) => diagnostic.code == code)
        .map((diagnostic) => diagnostic.jsonPath);

    expect(result.asset, isNotNull);
    expect(
      pathsFor('gltf.invalidMaterialBaseColorTexture'),
      contains(r'$.materials[0].pbrMetallicRoughness.baseColorTexture'),
    );
    expect(
      pathsFor('gltf.invalidTextureTexCoord'),
      contains(
        r'$.materials[0].pbrMetallicRoughness.baseColorTexture.texCoord',
      ),
    );
    expect(
      pathsFor('gltf.invalidTextureTransformRotation'),
      contains(
        r'$.materials[0].pbrMetallicRoughness.baseColorTexture.extensions.KHR_texture_transform.rotation',
      ),
    );
    expect(
      pathsFor('gltf.invalidTextureStrength'),
      contains(r'$.materials[0].occlusionTexture.strength'),
    );
    expect(
      pathsFor('gltf.invalidNormalTextureScale'),
      contains(r'$.materials[0].normalTexture.scale'),
    );
    expect(
      pathsFor('mtoon.invalidTexture'),
      contains(
        r'$.materials[0].extensions.VRMC_materials_mtoon.shadingShiftTexture',
      ),
    );
    expect(
      pathsFor('mtoon.invalidTextureScale'),
      contains(
        r'$.materials[0].extensions.VRMC_materials_mtoon.shadingShiftTexture.scale',
      ),
    );
    expect(
      pathsFor('gltf.invalidTextureTransformScale'),
      contains(
        r'$.materials[0].extensions.VRMC_materials_mtoon.shadingShiftTexture.extensions.KHR_texture_transform.scale',
      ),
    );
  });

  test('validates MToon render queue offset for alpha mode', () {
    Map<String, Object?> material(
      String alphaMode,
      int offset, {
      bool? transparentWithZWrite,
    }) {
      return {
        'alphaMode': alphaMode,
        'extensions': {
          'VRMC_materials_mtoon': {
            'specVersion': '1.0',
            'renderQueueOffsetNumber': offset,
            'transparentWithZWrite': ?transparentWithZWrite,
          },
        },
      };
    }

    final json = _minimalVrmJson(
      materials: [
        material('OPAQUE', 1),
        material('MASK', -1),
        material('BLEND', -1, transparentWithZWrite: true),
        material('BLEND', 1),
        material('OPAQUE', 0),
        material('MASK', 0),
        material('BLEND', 9, transparentWithZWrite: true),
        material('BLEND', -9),
      ],
    );
    (json['extensionsUsed']! as List<Object?>).add('VRMC_materials_mtoon');

    final result = VrmModel.tryParseGlb(
      _glb(json),
      validation: VrmValidationMode.permissive,
    );
    final invalidOffsets = result.validation.errors
        .where((d) => d.code == 'mtoon.invalidRenderQueueOffset')
        .toList();

    expect(result.asset, isNotNull);
    expect(invalidOffsets.map((d) => d.gltfMaterialIndex), [0, 1, 2, 3]);
  });
}
