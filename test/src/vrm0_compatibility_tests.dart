part of '../flvtterm_test.dart';

void vrm0CompatibilityTests() {
  group('VRM 0.x compatibility', () {
    test(
      'detects legacy VRM automatically and preserves immutable typed data',
      () {
        final model = VrmModel.parseGlb(_glb(_minimalVrm0Json()));
        final legacy = model.vrm0!;

        expect(model.sourceVersion, VrmSourceVersion.vrm0);
        expect(model.vrm.sourceVersion, VrmSourceVersion.vrm0);
        expect(model.vrm.specVersion, '0.0');
        expect(legacy.specVersion, '0.0');
        expect(legacy.exporterVersion, 'UniVRM-0.99.4');
        expect(legacy.meta!.title, 'Legacy Avatar');
        expect(model.vrm.meta.name, 'Legacy Avatar');
        expect(model.vrm.meta.authors, ['Legacy Author']);
        expect(model.vrm.meta.licenseUrl, 'https://example.com/license');
        expect(
          model.sourceToRuntimeTransform,
          VrmMatrix4(const [-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1]),
        );

        final rawMeta = legacy.raw['meta']! as Map<String, Object?>;
        final rawBones =
            (legacy.raw['humanoid']! as Map<String, Object?>)['humanBones']!
                as List<Object?>;
        expect(() => legacy.raw['extra'] = true, throwsUnsupportedError);
        expect(() => rawMeta['title'] = 'mutated', throwsUnsupportedError);
        expect(() => rawBones.clear(), throwsUnsupportedError);
        expect(
          () => legacy.humanoid!.humanBones.clear(),
          throwsUnsupportedError,
        );
        expect(
          () => legacy.humanoid!.humanBones.first.raw['node'] = 99,
          throwsUnsupportedError,
        );

        final binding = _FakeBinding();
        (VrmRuntime(model)..bind(binding)).update(0);
        expect(
          binding.modelRootMotionTransform,
          model.sourceToRuntimeTransform,
        );
      },
    );

    test('applies the legacy orientation through fallback scene roots', () {
      final model = VrmModel.parseGlb(_glb(_minimalVrm0Json()));
      final delegate = _FakeBinding();
      final binding = _Vrm0FallbackBinding(delegate);

      (VrmRuntime(model)..bind(binding)).update(0);

      expect(delegate.nodes[0]!.localTransform, model.sourceToRuntimeTransform);
    });

    test('fallback world transforms match a real model-root binding', () {
      final json = _minimalVrm0Json();
      (json['extensionsUsed']! as List<Object?>).add('VRMC_node_constraint');
      final nodes = json['nodes']! as List<Map<String, Object?>>;
      nodes[3]['translation'] = [1.0, 0.5, 0.75];
      nodes[6]['translation'] = [-0.5, 0.0, -0.25];
      nodes[6]['extensions'] = {
        'VRMC_node_constraint': {
          'specVersion': '1.0',
          'constraint': {
            'aim': {'source': 3, 'aimAxis': 'PositiveX', 'weight': 1.0},
          },
        },
      };
      final model = VrmModel.parseGlb(_glb(json));
      final external = _testTrs(
        rotation: [math.sin(math.pi / 8), 0.0, 0.0, math.cos(math.pi / 8)],
        scale: const [2.0, 1.0, 0.5],
      );
      final fallback = _ComputedFallbackBinding(model, external);
      final rooted = _ComputedModelRootBinding(model, external);

      (VrmRuntime(model)..bind(fallback)).update(0);
      (VrmRuntime(model)..bind(rooted)).update(0);

      final fallbackTransform = fallback.state.nodes[6]!.localTransform.storage;
      final rootedTransform = rooted.state.nodes[6]!.localTransform.storage;
      expect(fallbackTransform[0], isNot(closeTo(1, 0.000001)));
      for (var i = 0; i < 16; i++) {
        expect(fallbackTransform[i], closeTo(rootedTransform[i], 0.000001));
      }
    });

    test('normalizes accepted non-canonical permission casing', () {
      final json = _minimalVrm0Json();
      final meta = _vrm0Root(json)['meta']! as Map<String, Object?>
        ..['allowedUserName'] = 'everyone'
        ..['violentUssageName'] = 'allow'
        ..['sexualUssageName'] = 'allow'
        ..['commercialUssageName'] = 'allow';

      final result = VrmModel.tryParseGlb(_glb(json));
      final normalized = result.asset!.vrm.meta;

      expect(meta, isNotEmpty);
      expect(normalized.avatarPermission, VrmMetaAvatarPermission.everyone);
      expect(normalized.allowExcessivelyViolentUsage, isTrue);
      expect(normalized.allowExcessivelySexualUsage, isTrue);
      expect(normalized.commercialUsage, VrmMetaCommercialUsage.personalProfit);
      expect(
        result.validation.warnings
            .where(
              (diagnostic) => diagnostic.code == 'vrm0.nonCanonicalEnumCase',
            )
            .length,
        4,
      );
    });

    test('accepts VRM as a required glTF extension', () {
      final json = _minimalVrm0Json();

      final result = VrmModel.tryParseGlb(_glb(json));

      expect(json['extensionsRequired'], ['VRM']);
      expect(result.asset, isNotNull);
      expect(result.validation.errors, isEmpty);
      expect(
        result.validation.diagnostics.map((diagnostic) => diagnostic.code),
        isNot(contains('gltf.unsupportedRequiredExtension')),
      );
    });

    test('missing legacy specVersion is strict-only fatal', () {
      final json = _minimalVrm0Json();
      _vrm0Root(json).remove('specVersion');
      final bytes = _glb(json);

      final strict = VrmModel.tryParseGlb(bytes);
      final permissive = VrmModel.tryParseGlb(
        bytes,
        validation: VrmValidationMode.permissive,
      );

      expect(strict.asset, isNull);
      expect(
        strict.validation.errors.map((diagnostic) => diagnostic.code),
        contains('vrm0.missingSpecVersion'),
      );
      expect(permissive.asset, isNotNull);
      expect(permissive.asset!.sourceVersion, VrmSourceVersion.vrm0);
      expect(permissive.asset!.vrm0!.specVersion, isNull);
      expect(
        permissive.validation.warnings.map((diagnostic) => diagnostic.code),
        contains('vrm0.missingSpecVersion'),
      );
      expect(
        permissive.validation.warnings
            .singleWhere(
              (diagnostic) => diagnostic.code == 'vrm0.missingSpecVersion',
            )
            .jsonPath,
        r'$.extensions.VRM.specVersion',
      );
    });

    test('rejects unsupported legacy specVersion values safely', () {
      final json = _minimalVrm0Json();
      _vrm0Root(json)['specVersion'] = '0.1';

      final result = VrmModel.tryParseGlb(
        _glb(json),
        validation: VrmValidationMode.permissive,
      );

      expect(result.asset, isNull);
      expect(
        result.validation.errors
            .singleWhere(
              (diagnostic) => diagnostic.code == 'vrm0.unsupportedSpecVersion',
            )
            .jsonPath,
        r'$.extensions.VRM.specVersion',
      );
    });

    test('rejects ambiguous VRM 0.x and VRM 1.0 root extensions', () {
      final json = _minimalVrm0Json();
      final modern = _minimalVrmJson();
      final modernRoot =
          (modern['extensions']! as Map<String, Object?>)['VRMC_vrm']!;
      (json['extensionsUsed']! as List<Object?>).add('VRMC_vrm');
      (json['extensionsRequired']! as List<Object?>).add('VRMC_vrm');
      (json['extensions']! as Map<String, Object?>)['VRMC_vrm'] = modernRoot;
      final bytes = _glb(json);

      final strict = VrmModel.tryParseGlb(bytes);
      final permissive = VrmModel.tryParseGlb(
        bytes,
        validation: VrmValidationMode.permissive,
      );

      expect(strict.asset, isNull);
      expect(permissive.asset, isNotNull);
      expect(permissive.asset!.sourceVersion, VrmSourceVersion.vrm1);
      expect(permissive.asset!.vrm0, isNull);
      expect(
        permissive.validation.errors.map((diagnostic) => diagnostic.code),
        contains('vrm.ambiguousVersionExtensions'),
      );
      expect(
        permissive.validation.errors
            .singleWhere(
              (diagnostic) =>
                  diagnostic.code == 'vrm.ambiguousVersionExtensions',
            )
            .jsonPath,
        r'$.extensions',
      );
    });

    test('requires legacy chest and neck and remaps legacy thumb bones', () {
      final missingJson = _minimalVrm0Json();
      final missingBones = _vrm0HumanBones(missingJson);
      missingBones.removeWhere((entry) {
        final bone = (entry as Map<String, Object?>)['bone'];
        return bone == 'chest' || bone == 'neck';
      });

      final missing = VrmModel.tryParseGlb(
        _glb(missingJson),
        validation: VrmValidationMode.permissive,
      );

      expect(missing.asset, isNotNull);
      expect(
        missing.validation.errors
            .where(
              (diagnostic) =>
                  diagnostic.code == 'vrm0.missingRequiredHumanoidBone',
            )
            .length,
        2,
      );
      expect(
        missing.validation.errors
            .where(
              (diagnostic) =>
                  diagnostic.code == 'vrm0.missingRequiredHumanoidBone',
            )
            .map((diagnostic) => diagnostic.jsonPath),
        everyElement(r'$.extensions.VRM.humanoid.humanBones'),
      );
      expect(VrmModel.tryParseGlb(_glb(missingJson)).asset, isNull);

      final thumbsJson = _minimalVrm0Json();
      final nodes = thumbsJson['nodes']! as List<Map<String, Object?>>;
      final thumbNodes = <String, int>{};
      for (final name in const [
        'leftThumbProximal',
        'leftThumbIntermediate',
        'leftThumbDistal',
        'rightThumbProximal',
        'rightThumbIntermediate',
        'rightThumbDistal',
      ]) {
        thumbNodes[name] = nodes.length;
        nodes.add({'name': name});
      }
      nodes[11]['children'] = [thumbNodes['leftThumbProximal']!];
      nodes[thumbNodes['leftThumbProximal']!]['children'] = [
        thumbNodes['leftThumbIntermediate']!,
      ];
      nodes[thumbNodes['leftThumbIntermediate']!]['children'] = [
        thumbNodes['leftThumbDistal']!,
      ];
      nodes[14]['children'] = [thumbNodes['rightThumbProximal']!];
      nodes[thumbNodes['rightThumbProximal']!]['children'] = [
        thumbNodes['rightThumbIntermediate']!,
      ];
      nodes[thumbNodes['rightThumbIntermediate']!]['children'] = [
        thumbNodes['rightThumbDistal']!,
      ];
      _vrm0HumanBones(thumbsJson).addAll([
        for (final entry in thumbNodes.entries)
          <String, Object?>{'bone': entry.key, 'node': entry.value},
      ]);

      final thumbs = VrmModel.parseGlb(_glb(thumbsJson));

      expect(
        thumbs.vrm.humanoid.nodeFor(VrmHumanoidBone.leftThumbMetacarpal),
        thumbNodes['leftThumbProximal'],
      );
      expect(
        thumbs.vrm.humanoid.nodeFor(VrmHumanoidBone.leftThumbProximal),
        thumbNodes['leftThumbIntermediate'],
      );
      expect(
        thumbs.vrm.humanoid.nodeFor(VrmHumanoidBone.leftThumbDistal),
        thumbNodes['leftThumbDistal'],
      );
      expect(
        thumbs.vrm.humanoid.nodeFor(VrmHumanoidBone.rightThumbMetacarpal),
        thumbNodes['rightThumbProximal'],
      );
      expect(
        thumbs.vrm.humanoid.nodeFor(VrmHumanoidBone.rightThumbProximal),
        thumbNodes['rightThumbIntermediate'],
      );
      expect(
        thumbs.vrm.humanoid.nodeFor(VrmHumanoidBone.rightThumbDistal),
        thumbNodes['rightThumbDistal'],
      );
      expect(
        thumbs.vrm0!.humanoid!.humanBones
            .firstWhere((bone) => bone.bone == 'leftThumbProximal')
            .normalizedBone,
        VrmHumanoidBone.leftThumbMetacarpal,
      );
    });

    test('validates legacy humanoid normalization and assignments', () {
      final json = _minimalVrm0Json();
      final nodes = json['nodes']! as List<Map<String, Object?>>;
      final halfSqrt = math.sqrt(0.5);
      nodes[1]['scale'] = [-1.0, 1.0, 1.0];
      nodes[2]['rotation'] = [halfSqrt, 0.0, 0.0, halfSqrt];
      nodes[3]['children'] = <int>[];
      nodes[0]['children'] = [...(nodes[0]['children']! as List<int>), 4];
      _vrm0HumanBones(json).addAll([
        <String, Object?>{'bone': 'head', 'node': 2},
        <String, Object?>{'bone': 'leftEye', 'node': 2},
      ]);

      final result = VrmModel.tryParseGlb(
        _glb(json),
        validation: VrmValidationMode.permissive,
      );

      expect(result.asset, isNotNull);
      final errors = result.validation.errors;
      VrmDiagnostic diagnostic(String code) =>
          errors.singleWhere((diagnostic) => diagnostic.code == code);
      expect(
        diagnostic('vrm0.nonPositiveHumanoidScale').jsonPath,
        r'$.extensions.VRM.humanoid.humanBones[1].node',
      );
      expect(diagnostic('vrm0.nonUnitHumanoidScale').gltfNodeIndex, 1);
      expect(
        diagnostic('vrm0.nonIdentityHumanoidRotation').jsonPath,
        r'$.extensions.VRM.humanoid.humanBones[2].node',
      );
      expect(diagnostic('vrm0.invalidHumanoidParent').gltfNodeIndex, 4);
      expect(
        diagnostic('vrm0.duplicateHumanoidBone').jsonPath,
        r'$.extensions.VRM.humanoid.humanBones[17].bone',
      );
      expect(
        diagnostic('vrm0.duplicateHumanoidNode').jsonPath,
        r'$.extensions.VRM.humanoid.humanBones[18].node',
      );
    });

    test(
      'normalizes blend-shape presets, mesh binds, weights, and materials',
      () {
        final json = _minimalVrm0Json(
          nodeMesh: const {6: 0, 8: 0},
          meshes: [
            {
              'primitives': [
                {
                  'attributes': <String, Object?>{},
                  'targets': [<String, Object?>{}, <String, Object?>{}],
                },
              ],
            },
          ],
          materials: [
            {
              'name': 'Face',
              'pbrMetallicRoughness': {
                'baseColorFactor': [0.2, 0.3, 0.4, 1.0],
              },
            },
          ],
          blendShapeMaster: {
            'blendShapeGroups': [
              {
                'name': 'Joy',
                'presetName': 'joy',
                'binds': [
                  {'mesh': 0, 'index': 1, 'weight': 100.0},
                ],
                'materialValues': [
                  {
                    'materialName': 'Face',
                    'propertyName': '_Color',
                    'targetValue': [0.9, 0.8, 0.7, 0.6],
                  },
                  {
                    'materialName': 'Face',
                    'propertyName': '_MainTex_ST',
                    'targetValue': [2.0, 3.0, 0.25, 0.5],
                  },
                ],
                'isBinary': true,
              },
            ],
          },
          materialProperties: [_vrm0MaterialProperty(name: 'Face')],
        );
        final model = VrmModel.parseGlb(_glb(json));
        final expression =
            model.vrm.expressions.preset[VrmExpressionPreset.happy]!;

        expect(expression.name, 'happy');
        expect(expression.isBinary, isTrue);
        expect(expression.morphTargetBinds.map((bind) => bind.node), [6, 8]);
        expect(
          expression.morphTargetBinds.every((bind) => bind.index == 1),
          isTrue,
        );
        expect(
          expression.morphTargetBinds.every((bind) => bind.weight == 1.0),
          isTrue,
        );
        expect(expression.materialColorBinds.single.material, 0);
        expect(expression.materialColorBinds.single.type, 'color');
        expect(
          expression.materialColorBinds.single.targetValue,
          const VrmVector4(0.9, 0.8, 0.7, 0.6),
        );
        expect(expression.textureTransformBinds.single.material, 0);
        expect(
          expression.textureTransformBinds.single.scale,
          const VrmVector2(2.0, 3.0),
        );
        expect(
          expression.textureTransformBinds.single.offset,
          const VrmVector2(0.25, -2.5),
        );
        expect(
          model
              .vrm0!
              .blendShapeMaster!
              .blendShapeGroups
              .single
              .binds
              .single
              .weight,
          100.0,
        );

        final binding = _FakeBinding();
        final runtime = VrmRuntime(model)..bind(binding);
        runtime.emotion.set(VrmEmotion.happy, 0.5);
        runtime.update(0);
        expect(binding.meshes[6]!.weights['0:1'], 0.0);
        expect(binding.meshes[8]!.weights['0:1'], 0.0);

        runtime.emotion.set(VrmEmotion.happy, 0.5001);
        runtime.update(0);
        expect(binding.meshes[6]!.weights['0:1'], 1.0);
        expect(binding.meshes[8]!.weights['0:1'], 1.0);
        final appliedColor = binding.materials[0]!.colors['color']!;
        expect(appliedColor.x, closeTo(0.9, 0.0000001));
        expect(appliedColor.y, closeTo(0.8, 0.0000001));
        expect(appliedColor.z, closeTo(0.7, 0.0000001));
        expect(appliedColor.w, closeTo(0.6, 0.0000001));
        expect(binding.materials[0]!.scale, const VrmVector2(2.0, 3.0));
        expect(binding.materials[0]!.offset, const VrmVector2(0.25, -2.5));
      },
    );

    test(
      'keeps presets when a legacy custom name normalizes to the same ID',
      () {
        final json = _minimalVrm0Json(
          nodeMesh: const {6: 0},
          meshes: [
            {
              'primitives': [
                {
                  'attributes': <String, Object?>{},
                  'targets': [<String, Object?>{}, <String, Object?>{}],
                },
              ],
            },
          ],
          blendShapeMaster: {
            'blendShapeGroups': [
              {
                'name': 'Joy',
                'presetName': 'joy',
                'binds': [
                  {'mesh': 0, 'index': 0, 'weight': 100.0},
                ],
              },
              {
                'name': 'happy',
                'presetName': 'unknown',
                'binds': [
                  {'mesh': 0, 'index': 1, 'weight': 100.0},
                ],
              },
            ],
          },
        );

        final result = VrmModel.tryParseGlb(_glb(json));
        final expressions = result.asset!.vrm.expressions;

        expect(
          expressions
              .preset[VrmExpressionPreset.happy]!
              .morphTargetBinds
              .single
              .index,
          0,
        );
        expect(expressions.custom, isNot(contains('happy')));
        expect(
          result.validation.warnings.map((diagnostic) => diagnostic.code),
          contains('vrm0.customExpressionPresetCollision'),
        );
      },
    );

    test('reports invalid legacy expression and spring references', () {
      final json = _minimalVrm0Json(
        nodeMesh: const {6: 0},
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
        blendShapeMaster: {
          'blendShapeGroups': [
            {
              'name': 'bad',
              'presetName': 'unknown',
              'binds': [
                {'mesh': 0, 'index': 4, 'weight': 100.0},
                {'mesh': 0, 'index': 0, 'weight': 101.0},
              ],
            },
          ],
        },
        secondaryAnimation: {
          'colliderGroups': [
            {'node': 999, 'colliders': <Object?>[]},
          ],
          'boneGroups': [
            {
              'center': 999,
              'bones': [999],
              'colliderGroups': [1],
            },
          ],
        },
      );

      final result = VrmModel.tryParseGlb(
        _glb(json),
        validation: VrmValidationMode.permissive,
      );

      expect(result.asset, isNotNull);
      expect(
        result.validation.errors
            .singleWhere(
              (diagnostic) =>
                  diagnostic.code == 'vrm0.morphTargetIndexOutOfRange',
            )
            .jsonPath,
        r'$.extensions.VRM.blendShapeMaster.blendShapeGroups[0].binds[0].index',
      );
      expect(
        result.validation.errors
            .singleWhere(
              (diagnostic) => diagnostic.code == 'vrm0.numberOutOfRange',
            )
            .jsonPath,
        r'$.extensions.VRM.blendShapeMaster.blendShapeGroups[0].binds[1].weight',
      );
      expect(
        result.asset!.vrm.expressions.custom['bad']!.morphTargetBinds,
        isEmpty,
      );
      expect(
        result.validation.errors
            .where((diagnostic) => diagnostic.code == 'vrm0.indexOutOfRange')
            .map((diagnostic) => diagnostic.jsonPath),
        containsAll([
          r'$.extensions.VRM.secondaryAnimation.colliderGroups[0].node',
          r'$.extensions.VRM.secondaryAnimation.boneGroups[0].center',
          r'$.extensions.VRM.secondaryAnimation.boneGroups[0].bones[0]',
          r'$.extensions.VRM.secondaryAnimation.boneGroups[0].colliderGroups[0]',
        ]),
      );
      expect(result.asset!.springBone!.springs, isEmpty);
    });

    test('preserves an arbitrary first-person anchor and maps mesh flags', () {
      final json = _minimalVrm0Json(
        nodeMesh: const {6: 0, 8: 0},
        meshes: [
          {
            'primitives': [
              {'attributes': <String, Object?>{}},
            ],
          },
        ],
        firstPerson: {
          'firstPersonBone': 7,
          'firstPersonBoneOffset': {'x': 0.1, 'y': 0.2, 'z': 0.3},
          'meshAnnotations': [
            {'mesh': 0, 'firstPersonFlag': 'FirstPersonOnly'},
          ],
          'lookAtTypeName': 'Bone',
          'lookAtHorizontalInner': _vrm0DegreeMap(),
          'lookAtHorizontalOuter': _vrm0DegreeMap(),
          'lookAtVerticalDown': _vrm0DegreeMap(),
          'lookAtVerticalUp': _vrm0DegreeMap(),
        },
      );

      final model = VrmModel.parseGlb(_glb(json));
      final firstPerson = model.vrm.firstPerson;

      expect(model.vrm0!.firstPerson!.firstPersonBone, 7);
      expect(
        model.vrm0!.firstPerson!.firstPersonBoneOffset,
        const VrmVector3(0.1, 0.2, 0.3),
      );
      expect(firstPerson.firstPersonBone, 7);
      expect(firstPerson.meshAnnotations.map((annotation) => annotation.node), [
        6,
        8,
      ]);
      expect(
        firstPerson.meshAnnotations.every(
          (annotation) =>
              annotation.type ==
              VrmFirstPersonMeshAnnotationType.firstPersonOnly,
        ),
        isTrue,
      );
      expect(model.vrm.lookAt!.originNode, 7);
      expect(model.vrm.lookAt!.offsetFromHeadBone, [0.1, 0.2, -0.3]);

      final controller = VrmFirstPersonController(model);
      expect(controller.isVisible(6), isFalse);
      expect(controller.isVisible(8), isFalse);
      controller.useFirstPerson();
      expect(controller.isVisible(6), isTrue);
      expect(controller.isVisible(8), isTrue);
    });

    test('adapts the legacy -Z gaze convention and nonlinear LookAt curve', () {
      final json = _minimalVrm0Json(
        nodeMesh: const {6: 0},
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
        firstPerson: {
          'firstPersonBone': 2,
          'firstPersonBoneOffset': {'x': 0.0, 'y': 0.0, 'z': 0.0},
          'meshAnnotations': <Object?>[],
          'lookAtTypeName': 'BlendShape',
          'lookAtHorizontalInner': _vrm0DegreeMap(),
          'lookAtHorizontalOuter': _vrm0DegreeMap(
            curve: const [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0],
          ),
          'lookAtVerticalDown': _vrm0DegreeMap(),
          'lookAtVerticalUp': _vrm0DegreeMap(),
        },
        blendShapeMaster: {
          'blendShapeGroups': [
            {
              'name': 'LOOKLEFT',
              'presetName': 'lookleft',
              'binds': [
                {'mesh': 0, 'index': 0, 'weight': 100.0},
              ],
              'materialValues': <Object?>[],
              'isBinary': false,
            },
          ],
        },
      );
      final model = VrmModel.parseGlb(_glb(json));
      final binding = _FakeBinding();
      final runtime = VrmRuntime(model)..bind(binding);

      // The public runtime convention faces +Z. Internally this target becomes
      // (-X, -Z), the forward-left direction of a legacy VRM 0.x source.
      runtime.lookAt.lookAtModel(VrmVector3(math.tan(math.pi / 8), 0.0, 1.0));
      runtime.update(0);

      expect(model.vrm.lookAt!.type, VrmLookAtType.expression);
      expect(model.vrm.lookAt!.rangeMapHorizontalOuter.curve, [
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        1.0,
        0.0,
        0.0,
      ]);
      // 22.5 degrees is t=0.25 in a 90-degree map. Zero-tangent Hermite
      // interpolation yields smoothstep(0.25) = 0.15625, not linear 0.25.
      expect(binding.meshes[6]!.weights['0:0'], closeTo(0.15625, 0.000001));
    });

    test('accepts a single-key legacy LookAt curve as constant', () {
      final json = _minimalVrm0Json(
        nodeMesh: const {6: 0},
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
        firstPerson: {
          'firstPersonBone': 2,
          'firstPersonBoneOffset': {'x': 0.0, 'y': 0.0, 'z': 0.0},
          'meshAnnotations': <Object?>[],
          'lookAtTypeName': 'BlendShape',
          'lookAtHorizontalInner': _vrm0DegreeMap(),
          'lookAtHorizontalOuter': _vrm0DegreeMap(
            curve: const [0.5, 0.25, 0.0, 0.0],
            yRange: 2.0,
          ),
          'lookAtVerticalDown': _vrm0DegreeMap(),
          'lookAtVerticalUp': _vrm0DegreeMap(),
        },
        blendShapeMaster: {
          'blendShapeGroups': [
            {
              'name': 'LOOKLEFT',
              'presetName': 'lookleft',
              'binds': [
                {'mesh': 0, 'index': 0, 'weight': 100.0},
              ],
            },
          ],
        },
      );
      final result = VrmModel.tryParseGlb(_glb(json));
      final binding = _FakeBinding();
      final runtime = VrmRuntime(result.asset!)..bind(binding);

      runtime.lookAt.setYawPitch(yawDegrees: 45, pitchDegrees: 0);
      runtime.update(0);

      expect(
        result.validation.diagnostics.map((diagnostic) => diagnostic.code),
        isNot(contains('vrm0.invalidDegreeMapCurve')),
      );
      expect(result.asset!.vrm.lookAt!.rangeMapHorizontalOuter.curve, [
        0.5,
        0.25,
        0.0,
        0.0,
      ]);
      expect(binding.meshes[6]!.weights['0:0'], closeTo(0.5, 0.000001));
    });

    test('preserves zero and signed legacy LookAt ranges', () {
      final json = _minimalVrm0Json();
      final firstPerson =
          _vrm0Root(json)['firstPerson']! as Map<String, Object?>;
      firstPerson['lookAtHorizontalOuter'] = _vrm0DegreeMap(
        xRange: 0,
        yRange: -2,
      );

      final model = VrmModel.parseGlb(_glb(json));
      final range = model.vrm.lookAt!.rangeMapHorizontalOuter;

      expect(range.inputMaxValue, 0);
      expect(range.outputScale, -2);
    });

    test('applies legacy bone LookAt in the source eye frame', () {
      final json = _minimalVrm0Json();
      final nodes = json['nodes']! as List<Map<String, Object?>>;
      final leftEye = nodes.length;
      final rightEye = leftEye + 1;
      nodes[2]['children'] = [leftEye, rightEye];
      nodes
        ..add({'name': 'leftEye'})
        ..add({'name': 'rightEye'});
      _vrm0HumanBones(json).addAll([
        <String, Object?>{'bone': 'leftEye', 'node': leftEye},
        <String, Object?>{'bone': 'rightEye', 'node': rightEye},
      ]);
      final firstPerson =
          _vrm0Root(json)['firstPerson']! as Map<String, Object?>;
      (firstPerson['lookAtVerticalDown']! as Map<String, Object?>)['yRange'] =
          30.0;
      final model = VrmModel.parseGlb(_glb(json));
      final binding = _FakeBinding();
      final runtime = VrmRuntime(model)..bind(binding);

      runtime.lookAt.setYawPitch(yawDegrees: 0, pitchDegrees: 90);
      runtime.update(0);

      expect(model.vrm.lookAt!.type, VrmLookAtType.bone);
      for (final eye in [leftEye, rightEye]) {
        expect(
          binding.nodes[eye]!.localTransform.storage[6],
          closeTo(-0.5, 0.000001),
        );
      }
    });

    test('normalizes legacy secondary animation and runs the 7 cm leaf', () {
      final json = _minimalVrm0Json();
      final nodes = json['nodes']! as List<Map<String, Object?>>;
      final springRoot = nodes.length;
      final springLeaf = springRoot + 1;
      nodes[0]['children'] = [
        ...(nodes[0]['children']! as List<int>),
        springRoot,
      ];
      nodes.add({
        'name': 'springRoot',
        'translation': [0.0, 1.0, 0.0],
        'children': [springLeaf],
      });
      nodes.add({
        'name': 'springLeaf',
        'translation': [0.0, 1.0, 0.0],
      });
      _vrm0Root(json)['secondaryAnimation'] = {
        'colliderGroups': [
          {
            'node': 2,
            'colliders': [
              {
                'offset': {'x': 0.1, 'y': 0.2, 'z': 0.3},
                'radius': 0.25,
              },
            ],
          },
        ],
        'boneGroups': [
          {
            'comment': 'hair',
            'stiffiness': 0.0,
            'gravityPower': 1.0,
            'gravityDir': {'x': 1.0, 'y': 0.0, 'z': 0.5},
            'dragForce': 0.0,
            'center': -1,
            'hitRadius': 0.01,
            'bones': [springRoot],
            'colliderGroups': [0],
          },
        ],
      };

      final model = VrmModel.parseGlb(_glb(json));
      final springBone = model.springBone!;
      final spring = springBone.springs.single;

      expect(springBone.sourceVersion, VrmSourceVersion.vrm0);
      expect(springBone.specVersion, '0.0');
      expect(springBone.colliders.single.node, 2);
      expect(
        springBone.colliders.single.shape.type,
        VrmSpringBoneColliderShapeType.sphere,
      );
      expect(springBone.colliders.single.shape.offset, [0.1, 0.2, -0.3]);
      expect(springBone.colliders.single.shape.radius, 0.25);
      expect(springBone.colliderGroups.single.colliders, [0]);
      expect(spring.name, 'hair');
      expect(spring.joints.map((joint) => joint.node), [
        springRoot,
        springLeaf,
      ]);
      expect(spring.joints.every((joint) => joint.stiffness == 0.0), isTrue);
      expect(spring.joints.every((joint) => joint.gravityPower == 1.0), isTrue);
      expect(spring.joints.first.gravityDir, [1.0, 0.0, -0.5]);
      expect(spring.colliderGroups, [0]);
      expect(spring.center, isNull);
      expect(spring.legacyTerminalLength, closeTo(0.07, 0.0000001));

      final binding = _FakeBinding();
      final runtime = VrmRuntime(model)..bind(binding);
      runtime.update(1.0);

      // The legacy extension vector first becomes glTF source space and then
      // follows the model's 180-degree compatibility basis into runtime space.
      expect(
        binding.nodes[springRoot]!.localTransform.storage[4],
        greaterThan(0),
      );
      // A VRM 1.0 two-joint spring rotates only the first joint. The changed
      // leaf proves that VRM 0.x's synthetic 7 cm terminal was simulated.
      expect(
        binding.nodes[springLeaf]!.localTransform,
        isNot(_testTrs(translation: const [0.0, 1.0, 0.0])),
      );
    });

    test('preserves spring branches and reports overlapping roots', () {
      final json = _minimalVrm0Json();
      final nodes = json['nodes']! as List<Map<String, Object?>>;
      final springRoot = nodes.length;
      final firstChild = springRoot + 1;
      final secondChild = springRoot + 2;
      nodes[0]['children'] = [
        ...(nodes[0]['children']! as List<int>),
        springRoot,
      ];
      nodes.add({
        'name': 'branchingSpringRoot',
        'children': [firstChild, secondChild],
      });
      nodes.add({'name': 'firstChild'});
      nodes.add({'name': 'secondChild'});
      _vrm0Root(json)['secondaryAnimation'] = {
        'colliderGroups': <Object?>[],
        'boneGroups': [
          {
            'bones': [springRoot, firstChild],
            'colliderGroups': <Object?>[],
          },
        ],
      };

      final result = VrmModel.tryParseGlb(
        _glb(json),
        validation: VrmValidationMode.permissive,
      );

      expect(result.asset, isNotNull);
      expect(
        result.validation.warnings.map((diagnostic) => diagnostic.code),
        isNot(contains('vrm0.springBranchUsesFirstChild')),
      );
      expect(
        result.validation.errors.map((diagnostic) => diagnostic.code),
        contains('vrm0.overlappingSpringChain'),
      );
      expect(
        result.asset!.springBone!.springs.first.joints.map(
          (joint) => joint.node,
        ),
        [springRoot, firstChild, secondChild],
      );
    });

    test('animates every branch in a legacy spring subtree', () {
      final json = _minimalVrm0Json();
      final nodes = json['nodes']! as List<Map<String, Object?>>;
      final springRoot = nodes.length;
      final firstChild = springRoot + 1;
      final secondChild = springRoot + 2;
      nodes[0]['children'] = [
        ...(nodes[0]['children']! as List<int>),
        springRoot,
      ];
      nodes.add({
        'name': 'branchingSpringRoot',
        'translation': [0.0, 1.0, 0.0],
        'children': [firstChild, secondChild],
      });
      nodes.add({
        'name': 'firstChild',
        'translation': [0.0, 1.0, 0.0],
      });
      nodes.add({
        'name': 'secondChild',
        'translation': [1.0, 0.0, 0.0],
      });
      _vrm0Root(json)['secondaryAnimation'] = {
        'colliderGroups': <Object?>[],
        'boneGroups': [
          {
            'stiffiness': 0.0,
            'gravityPower': 1.0,
            'gravityDir': {'x': 0.0, 'y': 0.0, 'z': 1.0},
            'dragForce': 0.0,
            'bones': [springRoot],
            'colliderGroups': <Object?>[],
          },
        ],
      };

      final model = VrmModel.parseGlb(_glb(json));
      final binding = _FakeBinding();
      (VrmRuntime(model)..bind(binding)).update(1);

      expect(
        model.springBone!.springs.single.joints.map((joint) => joint.node),
        [springRoot, firstChild, secondChild],
      );
      expect(
        binding.nodes[firstChild]!.localTransform,
        isNot(_testTrs(translation: const [0.0, 1.0, 0.0])),
      );
      expect(
        binding.nodes[secondChild]!.localTransform,
        isNot(_testTrs(translation: const [1.0, 0.0, 0.0])),
      );
    });

    test('runs legacy springs with an arbitrary sibling center', () {
      final json = _minimalVrm0Json();
      final nodes = json['nodes']! as List<Map<String, Object?>>;
      final center = nodes.length;
      final springRoot = center + 1;
      final springLeaf = center + 2;
      nodes[0]['children'] = [
        ...(nodes[0]['children']! as List<int>),
        center,
        springRoot,
      ];
      nodes.add({
        'name': 'siblingCenter',
        'translation': [2.0, 0.0, 0.0],
      });
      nodes.add({
        'name': 'centeredSpringRoot',
        'translation': [0.0, 1.0, 0.0],
        'children': [springLeaf],
      });
      nodes.add({
        'name': 'centeredSpringLeaf',
        'translation': [0.0, 1.0, 0.0],
      });
      _vrm0Root(json)['secondaryAnimation'] = {
        'colliderGroups': <Object?>[],
        'boneGroups': [
          {
            'center': center,
            'stiffiness': 0.0,
            'gravityPower': 1.0,
            'gravityDir': {'x': 1.0, 'y': 0.0, 'z': 0.0},
            'dragForce': 0.0,
            'bones': [springRoot],
            'colliderGroups': <Object?>[],
          },
        ],
      };

      final model = VrmModel.parseGlb(_glb(json));
      final binding = _FakeBinding();
      (VrmRuntime(model)..bind(binding)).update(1);

      expect(model.springBone!.springs.single.center, center);
      expect(
        binding.nodes[springRoot]!.localTransform,
        isNot(_testTrs(translation: const [0.0, 1.0, 0.0])),
      );
    });

    test('scales legacy spring collisions through outer world placement', () {
      final json = _minimalVrm0Json();
      final nodes = json['nodes']! as List<Map<String, Object?>>;
      final springRoot = nodes.length;
      final springLeaf = springRoot + 1;
      final colliderNode = springRoot + 2;
      nodes[0]['children'] = [
        ...(nodes[0]['children']! as List<int>),
        springRoot,
        colliderNode,
      ];
      nodes.add({
        'name': 'scaledSpringRoot',
        'children': [springLeaf],
      });
      nodes.add({
        'name': 'scaledSpringLeaf',
        'translation': [0.0, 1.0, 0.0],
      });
      nodes.add({
        'name': 'scaledCollider',
        'translation': [0.4, 1.0, 0.0],
      });
      _vrm0Root(json)['secondaryAnimation'] = {
        'colliderGroups': [
          {
            'node': colliderNode,
            'colliders': [
              {
                'offset': {'x': 0.0, 'y': 0.0, 'z': 0.0},
                'radius': 0.5,
              },
            ],
          },
        ],
        'boneGroups': [
          {
            'stiffiness': 0.0,
            'gravityPower': 0.0,
            'dragForce': 1.0,
            'bones': [springRoot],
            'colliderGroups': [0],
          },
        ],
      };

      final model = VrmModel.parseGlb(_glb(json));
      final externalTransform = _testTrs(
        rotation: [0.0, 0.0, math.sqrt1_2, math.sqrt1_2],
        scale: const [2.0, 2.0, 2.0],
      );
      final externalBinding = _ComputedModelRootBinding(
        model,
        externalTransform,
      )..modelRootMotionTransform = model.sourceToRuntimeTransform;
      final rootedBinding =
          _ComputedModelRootBinding(model, VrmMatrix4.identity())
            ..modelRootMotionTransform = _vrm0TestMultiply(
              externalTransform,
              model.sourceToRuntimeTransform,
            );
      for (final node in model.gltf.nodes) {
        externalBinding.nodeByGltfIndex(node.index).localTransform =
            node.restTransform;
        rootedBinding.nodeByGltfIndex(node.index).localTransform =
            node.restTransform;
      }

      VrmSpringBoneController(model).applyTo(externalBinding, 0);
      VrmSpringBoneController(model).applyTo(rootedBinding, 0);

      expect(
        externalBinding.state.nodes[springRoot]!.localTransform.storage[4]
            .abs(),
        greaterThan(0.01),
      );
      final externalOutput =
          externalBinding.state.nodes[springRoot]!.localTransform.storage;
      final rootedOutput =
          rootedBinding.state.nodes[springRoot]!.localTransform.storage;
      for (var i = 0; i < 16; i++) {
        expect(externalOutput[i], closeTo(rootedOutput[i], 0.000001));
      }
    });

    test('retargets VRMA through a rotated legacy intermediary', () {
      List<double> xRotation(double degrees) {
        final radians = degrees * math.pi / 360;
        return [math.sin(radians), 0.0, 0.0, math.cos(radians)];
      }

      List<double> yRotation(double degrees) {
        final radians = degrees * math.pi / 360;
        return [0.0, math.sin(radians), 0.0, math.cos(radians)];
      }

      final modelJson = _minimalVrm0Json();
      final nodes = modelJson['nodes']! as List<Map<String, Object?>>;
      final intermediary = nodes.length;
      nodes[16]['children'] = [intermediary];
      nodes.add({
        'name': 'rotatedIntermediary',
        'rotation': xRotation(90),
        'children': [2],
      });
      final binary = _floats([0.0, 1.0, ...yRotation(0), ...yRotation(90)]);
      final vrmaJson =
          <String, Object?>{
            'asset': {'version': '2.0'},
            'extensionsUsed': ['VRMC_vrm_animation'],
            'nodes': [
              {'name': 'sourceHead'},
            ],
          }..addAll(
            _animationStorageJson(
              binary.length,
              const [
                [0, 8],
                [8, 32],
              ],
              accessorTypes: const ['SCALAR', 'VEC4'],
            ),
          );
      vrmaJson['animations'] = [
        {
          'channels': [
            {
              'sampler': 0,
              'target': {'node': 0, 'path': 'rotation'},
            },
          ],
          'samplers': [
            {'input': 0, 'output': 1},
          ],
        },
      ];
      vrmaJson['extensions'] = {
        'VRMC_vrm_animation': {
          'specVersion': '1.0',
          'humanoid': {
            'humanBones': {
              'head': {'node': 0},
            },
          },
        },
      };

      final model = VrmModel.parseGlb(_glb(modelJson));
      final binding = _FakeBinding();
      final runtime = VrmRuntime(model)..bind(binding);
      final vrma = VrmAnimationAsset.tryParse(
        bytes: _glb(vrmaJson, binaryChunk: binary),
        validation: VrmValidationMode.permissive,
      ).asset!;

      runtime.motion.playVrmAnimation(vrma);
      runtime.update(1);

      // The correct source-local result is -90 degrees around Z. Applying a
      // blanket global-basis conjugation after retargeting produces +90.
      expect(
        binding.nodes[2]!.localTransform.storage[1],
        closeTo(-1, 0.000001),
      );
      expect(binding.nodes[2]!.localTransform.storage[4], closeTo(1, 0.000001));
    });

    test('partial legacy UV binds preserve untouched base axes', () {
      Map<String, Object?> uvBind(String property, List<double> target) => {
        'materialName': 'Face',
        'propertyName': property,
        'targetValue': target,
      };

      final json = _minimalVrm0Json(
        materials: [
          {'name': 'Face'},
        ],
        materialProperties: [
          _vrm0MaterialProperty(
            name: 'Face',
            vectorProperties: const {
              '_MainTex': [2.0, 3.0, 0.25, 0.5],
            },
          ),
        ],
        blendShapeMaster: {
          'blendShapeGroups': [
            {
              'name': 'uvS',
              'presetName': 'unknown',
              'materialValues': [
                uvBind('_MainTex_ST_S', [4.0, 99.0, 0.5, 99.0]),
              ],
            },
            {
              'name': 'uvT',
              'presetName': 'unknown',
              'materialValues': [
                uvBind('_MainTex_ST_T', [99.0, 5.0, 99.0, 0.25]),
              ],
            },
            {
              'name': 'uvBoth',
              'presetName': 'unknown',
              'materialValues': [
                uvBind('_MainTex_ST_S', [4.0, 99.0, 0.5, 99.0]),
                uvBind('_MainTex_ST_T', [99.0, 5.0, 99.0, 0.25]),
              ],
            },
          ],
        },
      );
      final model = VrmModel.parseGlb(_glb(json));

      final cases = <String, (VrmVector2, VrmVector2)>{
        'uvS': (const VrmVector2(4, 3), const VrmVector2(0.5, -2.5)),
        'uvT': (const VrmVector2(2, 5), const VrmVector2(0.25, -4.25)),
        'uvBoth': (const VrmVector2(4, 5), const VrmVector2(0.5, -4.25)),
      };
      for (final entry in cases.entries) {
        final binding = _FakeBinding();
        final runtime = VrmRuntime(model)..bind(binding);
        runtime.expressions.setCustom(entry.key, 1);
        runtime.update(0);
        expect(binding.materials[0]!.scale, entry.value.$1);
        expect(binding.materials[0]!.offset, entry.value.$2);
      }
    });

    test(
      'preserves legacy Unity material properties and fallback metadata',
      () {
        final property = _vrm0MaterialProperty(
          name: 'Face',
          shader: 'VRM/MToon',
          renderQueue: 2450,
          floatProperties: const {'_Cutoff': 0.42},
          vectorProperties: const {
            '_Color': [0.1, 0.2, 0.3, 0.4],
            '_MatCapColor': [0.6, 0.7, 0.8, 0.9],
            '_MainTex': [2.0, 3.0, 0.25, 0.5],
          },
          textureProperties: const {'_MainTex': 0},
          keywordMap: const {'_ALPHATEST_ON': true},
          tagMap: const {'RenderType': 'TransparentCutout'},
        );
        final json = _minimalVrm0Json(
          materials: [
            {
              'name': 'Face',
              'pbrMetallicRoughness': {
                'baseColorFactor': [0.1, 0.2, 0.3, 0.4],
              },
            },
          ],
          materialProperties: [property],
          blendShapeMaster: {
            'blendShapeGroups': [
              {
                'name': 'MatcapShift',
                'presetName': 'unknown',
                'binds': <Object?>[],
                'materialValues': [
                  {
                    'materialName': 'Face',
                    'propertyName': '_MatCapColor',
                    'targetValue': [1.0, 0.0, 0.0, 1.0],
                  },
                ],
                'isBinary': false,
              },
            ],
          },
        );
        json['textures'] = [<String, Object?>{}];

        final model = VrmModel.parseGlb(_glb(json));
        final legacy = model.vrm0!.materialProperties.single;

        expect(legacy.name, 'Face');
        expect(legacy.shader, 'VRM/MToon');
        expect(legacy.renderQueue, 2450);
        expect(legacy.floatProperties, {'_Cutoff': 0.42});
        expect(legacy.vectorProperties['_Color'], [0.1, 0.2, 0.3, 0.4]);
        expect(legacy.vectorProperties['_MainTex'], [2.0, 3.0, 0.25, 0.5]);
        expect(legacy.textureProperties, {'_MainTex': 0});
        expect(legacy.keywordMap, {'_ALPHATEST_ON': true});
        expect(legacy.tagMap, {'RenderType': 'TransparentCutout'});
        expect(
          () => legacy.floatProperties['_Cutoff'] = 1,
          throwsUnsupportedError,
        );
        expect(
          () => legacy.vectorProperties['_Color']![0] = 1,
          throwsUnsupportedError,
        );
        expect(
          model.preferredRenderModeForMaterial(0),
          GltfMaterialRenderMode.mtoon,
        );
        expect(
          model.preferredRenderModeForMaterial(0, supportsMToon: false),
          GltfMaterialRenderMode.pbr,
        );
        final warning = model.vrm0MtoonFallbackWarning(0)!;
        expect(warning.code, 'vrm0.mtoonFallback');
        expect(warning.jsonPath, r'$.extensions.VRM.materialProperties[0]');
        expect(warning.gltfMaterialIndex, 0);

        final binding = _FakeBinding();
        final runtime = VrmRuntime(model)..bind(binding);
        runtime.expressions.setCustom('matcapshift', 0.5);
        runtime.update(0);
        expect(
          binding.materials[0]!.colors['matcapColor'],
          const VrmVector4(0.8, 0.35, 0.4, 0.9),
        );

        runtime.expressions.clear();
        runtime.motion.playProgrammaticPose(
          VrmProgrammaticPose(expressionWeights: const {'MATCAPSHIFT': 1}),
        );
        runtime.update(0);
        expect(
          binding.materials[0]!.colors['matcapColor'],
          const VrmVector4(1.0, 0.0, 0.0, 0.9),
        );
      },
    );

    test('keeps legacy unlit transparent depth write distinct from MToon', () {
      final json = _minimalVrm0Json(
        materials: [
          {'name': 'HairTip', 'alphaMode': 'BLEND'},
        ],
        materialProperties: [
          _vrm0MaterialProperty(
            name: 'HairTip',
            shader: 'VRM/UnlitTransparentZWrite',
          ),
        ],
      );

      final model = VrmModel.parseGlb(_glb(json));

      expect(
        model.preferredRenderModeForMaterial(0),
        GltfMaterialRenderMode.unlit,
      );
      expect(
        model.preferredRenderModeForMaterial(0, supportsMToon: false),
        GltfMaterialRenderMode.unlit,
      );
      expect(model.vrm0MaterialRequiresTransparentZWrite(0), isTrue);
      expect(model.vrm0MtoonFallbackWarning(0), isNull);
      final warning = model.vrm0TransparentZWriteFallbackWarning(0)!;
      expect(warning.code, 'vrm0.transparentZWriteFallback');
      expect(warning.jsonPath, r'$.extensions.VRM.materialProperties[0]');
      expect(warning.gltfMaterialIndex, 0);
      expect(
        model.vrm0TransparentZWriteFallbackWarning(
          0,
          supportsTransparentZWrite: true,
        ),
        isNull,
      );
    });

    test('keeps source indices after malformed legacy array entries', () {
      final json = _minimalVrm0Json();
      final bones = _vrm0HumanBones(json);
      bones.insert(0, 42);
      (bones[1]! as Map<String, Object?>).remove('node');

      final result = VrmModel.tryParseGlb(
        _glb(json),
        validation: VrmValidationMode.permissive,
      );

      expect(result.asset, isNotNull);
      expect(result.asset!.vrm0!.humanoid!.humanBones.first.sourceIndex, 1);
      expect(
        result.validation.errors
            .singleWhere(
              (diagnostic) => diagnostic.code == 'vrm0.invalidObject',
            )
            .jsonPath,
        r'$.extensions.VRM.humanoid.humanBones[0]',
      );
      expect(
        result.validation.errors
            .singleWhere(
              (diagnostic) => diagnostic.code == 'vrm0.humanoidBoneMissingNode',
            )
            .jsonPath,
        r'$.extensions.VRM.humanoid.humanBones[1].node',
      );
    });

    test('reports malformed legacy containers without crashing', () {
      final json = _minimalVrm0Json();
      final legacy = _vrm0Root(json)
        ..['meta'] = <Object?>[]
        ..['humanoid'] = 'bad'
        ..['firstPerson'] = 1
        ..['blendShapeMaster'] = false
        ..['secondaryAnimation'] = 'bad'
        ..['materialProperties'] = <String, Object?>{};
      final bytes = _glb(json);

      final permissive = VrmModel.tryParseGlb(
        bytes,
        validation: VrmValidationMode.permissive,
      );

      expect(permissive.asset, isNotNull);
      expect(VrmModel.tryParseGlb(bytes).asset, isNull);
      expect(
        permissive.validation.errors
            .where((diagnostic) => diagnostic.code == 'vrm0.invalidObject')
            .map((diagnostic) => diagnostic.jsonPath),
        containsAll([
          r'$.extensions.VRM.meta',
          r'$.extensions.VRM.humanoid',
          r'$.extensions.VRM.firstPerson',
          r'$.extensions.VRM.blendShapeMaster',
          r'$.extensions.VRM.secondaryAnimation',
        ]),
      );
      expect(
        permissive.validation.errors
            .where((diagnostic) => diagnostic.code == 'vrm0.invalidArray')
            .map((diagnostic) => diagnostic.jsonPath),
        contains(r'$.extensions.VRM.materialProperties'),
      );
      expect(legacy, isNotEmpty);
    });
  });
}

final class _Vrm0FallbackBinding implements VrmSceneBinding {
  const _Vrm0FallbackBinding(this.delegate);

  final _FakeBinding delegate;

  @override
  void beginFrame() => delegate.beginFrame();

  @override
  void commitFrame() => delegate.commitFrame();

  @override
  VrmMaterialBinding materialByGltfIndex(int materialIndex) =>
      delegate.materialByGltfIndex(materialIndex);

  @override
  VrmMeshBinding? meshByNodeIndex(int nodeIndex) =>
      delegate.meshByNodeIndex(nodeIndex);

  @override
  VrmNodeBinding nodeByGltfIndex(int nodeIndex) =>
      delegate.nodeByGltfIndex(nodeIndex);
}

final class _ComputedFallbackBinding implements VrmSceneBinding {
  _ComputedFallbackBinding(VrmModel model, VrmMatrix4 external)
    : state = _ComputedBindingState(model, external, applyModelRoot: false);

  final _ComputedBindingState state;

  @override
  void beginFrame() {}

  @override
  void commitFrame() {}

  @override
  VrmMaterialBinding materialByGltfIndex(int materialIndex) =>
      state.materials.putIfAbsent(materialIndex, _FakeMaterial.new);

  @override
  VrmMeshBinding? meshByNodeIndex(int nodeIndex) => null;

  @override
  VrmNodeBinding nodeByGltfIndex(int nodeIndex) => state.nodes[nodeIndex]!;
}

final class _ComputedModelRootBinding
    implements VrmModelRootBinding, VrmModelWorldBinding {
  _ComputedModelRootBinding(VrmModel model, VrmMatrix4 external)
    : state = _ComputedBindingState(model, external, applyModelRoot: true);

  final _ComputedBindingState state;

  @override
  VrmMatrix4 get modelRootMotionTransform => state.modelRoot;

  @override
  VrmMatrix4 get modelWorldTransform =>
      _vrm0TestMultiply(state.external, state.modelRoot);

  @override
  set modelRootMotionTransform(VrmMatrix4 value) {
    state.modelRoot = value;
  }

  @override
  void beginFrame() {}

  @override
  void commitFrame() {}

  @override
  VrmMaterialBinding materialByGltfIndex(int materialIndex) =>
      state.materials.putIfAbsent(materialIndex, _FakeMaterial.new);

  @override
  VrmMeshBinding? meshByNodeIndex(int nodeIndex) => null;

  @override
  VrmNodeBinding nodeByGltfIndex(int nodeIndex) => state.nodes[nodeIndex]!;
}

final class _ComputedBindingState {
  _ComputedBindingState(
    this.model,
    this.external, {
    required this.applyModelRoot,
  }) : parents = {
         for (final node in model.gltf.nodes)
           for (final child in node.children) child: node.index,
       } {
    nodes = {
      for (final node in model.gltf.nodes)
        node.index: _ComputedNodeBinding(this, node.index),
    };
  }

  final VrmModel model;
  final VrmMatrix4 external;
  final bool applyModelRoot;
  final Map<int, int> parents;
  late final Map<int, _ComputedNodeBinding> nodes;
  final Map<int, _FakeMaterial> materials = {};
  VrmMatrix4 modelRoot = VrmMatrix4.identity();

  VrmMatrix4 worldTransform(int nodeIndex) {
    final chain = <int>[];
    final seen = <int>{};
    var current = nodeIndex;
    while (seen.add(current)) {
      chain.add(current);
      final parent = parents[current];
      if (parent == null) break;
      current = parent;
    }
    var result = external;
    if (applyModelRoot) result = _vrm0TestMultiply(result, modelRoot);
    for (final index in chain.reversed) {
      result = _vrm0TestMultiply(result, nodes[index]!.localTransform);
    }
    return result;
  }
}

final class _ComputedNodeBinding implements VrmNodeBinding {
  _ComputedNodeBinding(this.state, this.nodeIndex);

  final _ComputedBindingState state;
  final int nodeIndex;

  @override
  String? get debugName => 'node$nodeIndex';

  @override
  VrmMatrix4 localTransform = VrmMatrix4.identity();

  @override
  VrmMatrix4 get worldTransform => state.worldTransform(nodeIndex);
}

VrmMatrix4 _vrm0TestMultiply(VrmMatrix4 left, VrmMatrix4 right) {
  final a = left.storage;
  final b = right.storage;
  return VrmMatrix4([
    for (var column = 0; column < 4; column++)
      for (var row = 0; row < 4; row++)
        a[row] * b[column * 4] +
            a[row + 4] * b[column * 4 + 1] +
            a[row + 8] * b[column * 4 + 2] +
            a[row + 12] * b[column * 4 + 3],
  ]);
}

Map<String, Object?> _minimalVrm0Json({
  List<Object?> meshes = const [],
  List<Object?> materials = const [],
  Map<int, int> nodeMesh = const {},
  Map<String, Object?>? firstPerson,
  Map<String, Object?>? blendShapeMaster,
  Map<String, Object?>? secondaryAnimation,
  List<Object?>? materialProperties,
}) {
  final nodes = _nodes(nodeMesh);
  nodes[1]['children'] = [15];
  nodes.add({
    'name': 'chest',
    'children': [16, 9, 12],
  });
  nodes.add({
    'name': 'neck',
    'children': [2],
  });
  final humanBones = <Object?>[
    for (final entry in _boneNodes.entries)
      <String, Object?>{'bone': entry.key.specName, 'node': entry.value},
    <String, Object?>{'bone': 'chest', 'node': 15},
    <String, Object?>{'bone': 'neck', 'node': 16},
  ];

  return {
    'asset': {'version': '2.0', 'generator': 'UniVRM'},
    'extensionsUsed': <Object?>['VRM'],
    'extensionsRequired': <Object?>['VRM'],
    'scene': 0,
    'scenes': [
      {
        'nodes': [0],
      },
    ],
    'nodes': nodes,
    if (meshes.isNotEmpty) 'meshes': meshes,
    if (materials.isNotEmpty) 'materials': materials,
    'extensions': {
      'VRM': {
        'exporterVersion': 'UniVRM-0.99.4',
        'specVersion': '0.0',
        'meta': {
          'title': 'Legacy Avatar',
          'version': '1.2.3',
          'author': 'Legacy Author',
          'contactInformation': 'author@example.com',
          'reference': 'https://example.com/avatar',
          'texture': -1,
          'allowedUserName': 'Everyone',
          'violentUssageName': 'Disallow',
          'sexualUssageName': 'Disallow',
          'commercialUssageName': 'Allow',
          'otherPermissionUrl': 'https://example.com/permissions',
          'licenseName': 'CC_BY',
          'otherLicenseUrl': 'https://example.com/license',
        },
        'humanoid': {
          'humanBones': humanBones,
          'armStretch': 0.05,
          'legStretch': 0.05,
          'upperArmTwist': 0.5,
          'lowerArmTwist': 0.5,
          'upperLegTwist': 0.5,
          'lowerLegTwist': 0.5,
          'feetSpacing': 0.0,
          'hasTranslationDoF': false,
        },
        'firstPerson':
            firstPerson ??
            {
              'firstPersonBone': 2,
              'firstPersonBoneOffset': {'x': 0.0, 'y': 0.06, 'z': 0.0},
              'meshAnnotations': <Object?>[],
              'lookAtTypeName': 'Bone',
              'lookAtHorizontalInner': _vrm0DegreeMap(),
              'lookAtHorizontalOuter': _vrm0DegreeMap(),
              'lookAtVerticalDown': _vrm0DegreeMap(),
              'lookAtVerticalUp': _vrm0DegreeMap(),
            },
        'blendShapeMaster':
            blendShapeMaster ?? {'blendShapeGroups': <Object?>[]},
        'secondaryAnimation':
            secondaryAnimation ??
            {'boneGroups': <Object?>[], 'colliderGroups': <Object?>[]},
        'materialProperties': materialProperties ?? <Object?>[],
      },
    },
  };
}

Map<String, Object?> _vrm0Root(Map<String, Object?> json) =>
    (json['extensions']! as Map<String, Object?>)['VRM']!
        as Map<String, Object?>;

List<Object?> _vrm0HumanBones(Map<String, Object?> json) =>
    (_vrm0Root(json)['humanoid']! as Map<String, Object?>)['humanBones']!
        as List<Object?>;

Map<String, Object?> _vrm0DegreeMap({
  List<double> curve = const [0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0],
  double xRange = 90.0,
  double yRange = 1.0,
}) => {'curve': curve, 'xRange': xRange, 'yRange': yRange};

Map<String, Object?> _vrm0MaterialProperty({
  required String name,
  String shader = 'VRM/MToon',
  int renderQueue = 2000,
  Map<String, double> floatProperties = const {},
  Map<String, List<double>> vectorProperties = const {},
  Map<String, int> textureProperties = const {},
  Map<String, bool> keywordMap = const {},
  Map<String, String> tagMap = const {},
}) => {
  'name': name,
  'shader': shader,
  'renderQueue': renderQueue,
  'floatProperties': floatProperties,
  'vectorProperties': vectorProperties,
  'textureProperties': textureProperties,
  'keywordMap': keywordMap,
  'tagMap': tagMap,
};
