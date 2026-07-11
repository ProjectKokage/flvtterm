part of '../../flvtterm.dart';

VrmExtension _normalizeVrm0Extension(
  GltfAsset gltf,
  Vrm0Extension legacy,
  _DiagnosticSink sink,
) {
  final humanoid = _normalizeVrm0Humanoid(gltf, legacy.humanoid, sink);
  final firstPerson = _normalizeVrm0FirstPerson(gltf, legacy.firstPerson, sink);

  return VrmExtension._(
    sourceVersion: VrmSourceVersion.vrm0,
    specVersion: legacy.specVersion,
    meta: _normalizeVrm0Meta(gltf, legacy.meta, sink),
    humanoid: humanoid,
    firstPerson: firstPerson,
    expressions: _normalizeVrm0Expressions(gltf, legacy, sink),
    lookAt: _normalizeVrm0LookAt(
      legacy.firstPerson,
      firstPerson.firstPersonBone,
      sink,
    ),
    raw: legacy.raw,
  );
}

VrmMeta _normalizeVrm0Meta(
  GltfAsset gltf,
  Vrm0Meta? legacy,
  _DiagnosticSink sink,
) {
  final thumbnailImage = _vrm0ThumbnailImage(gltf, legacy?.texture, sink);
  final author = legacy?.author;
  final reference = legacy?.reference;

  return VrmMeta._(
    name: legacy?.title,
    version: legacy?.version,
    authors: author == null || author.isEmpty ? const [] : [author],
    copyrightInformation: null,
    contactInformation: legacy?.contactInformation,
    references: reference == null || reference.isEmpty ? const [] : [reference],
    thirdPartyLicenses: null,
    thumbnailImage: thumbnailImage,
    licenseUrl: legacy?.otherLicenseUrl,
    avatarPermission: _vrm0AvatarPermission(legacy?.allowedUserName),
    allowExcessivelyViolentUsage: _vrm0UsageAllowed(legacy?.violentUssageName),
    allowExcessivelySexualUsage: _vrm0UsageAllowed(legacy?.sexualUssageName),
    commercialUsage: _vrm0UsageAllowed(legacy?.commercialUssageName)
        ? VrmMetaCommercialUsage.personalProfit
        : VrmMetaCommercialUsage.personalNonProfit,
    allowPoliticalOrReligiousUsage: false,
    allowAntisocialOrHateUsage: false,
    creditNotation: VrmMetaCreditNotation.required,
    allowRedistribution: false,
    modification: VrmMetaModification.prohibited,
    otherLicenseUrl: legacy?.otherLicenseUrl,
    raw: legacy?.raw ?? const {},
  );
}

int? _vrm0ThumbnailImage(
  GltfAsset gltf,
  int? textureIndex,
  _DiagnosticSink sink,
) {
  if (textureIndex == null) return null;
  if (textureIndex < 0 || textureIndex >= gltf.textures.length) {
    sink.error(
      'vrm0.metaInvalidThumbnailTexture',
      'VRM.meta.texture must reference a glTF texture.',
      jsonPath: r'$.extensions.VRM.meta.texture',
    );
    return null;
  }
  final imageIndex = gltf.textures[textureIndex].source;
  if (imageIndex == null ||
      imageIndex < 0 ||
      imageIndex >= gltf.images.length) {
    sink.error(
      'vrm0.metaThumbnailTextureMissingImage',
      'VRM.meta.texture must reference a texture with a valid source image.',
      jsonPath: r'$.extensions.VRM.meta.texture',
    );
    return null;
  }
  return imageIndex;
}

VrmMetaAvatarPermission _vrm0AvatarPermission(String? value) =>
    switch (value?.toLowerCase()) {
      'everyone' => VrmMetaAvatarPermission.everyone,
      'explicitlylicensedperson' =>
        VrmMetaAvatarPermission.onlySeparatelyLicensedPerson,
      _ => VrmMetaAvatarPermission.onlyAuthor,
    };

bool _vrm0UsageAllowed(String? value) => value?.toLowerCase() == 'allow';

VrmHumanoid _normalizeVrm0Humanoid(
  GltfAsset gltf,
  Vrm0Humanoid? legacy,
  _DiagnosticSink sink,
) {
  if (legacy == null) {
    sink.error(
      'vrm0.missingHumanoid',
      'VRM.humanoid is required for a runtime humanoid avatar.',
      jsonPath: r'$.extensions.VRM.humanoid',
    );
    return VrmHumanoid._(humanBones: const {}, raw: const {});
  }

  final humanBones = <VrmHumanoidBone, VrmHumanBone>{};
  final usedNodes = <int, VrmHumanoidBone>{};
  final sourceIndices = <VrmHumanoidBone, int>{};

  for (var i = 0; i < legacy.humanBones.length; i++) {
    final source = legacy.humanBones[i];
    final bone = _vrm0HumanoidBone(source);
    final node = source.node;
    final path = '\$.extensions.VRM.humanoid.humanBones[${source.sourceIndex}]';
    if (source.bone == null) {
      sink.error(
        'vrm0.humanoidBoneMissingName',
        'Legacy humanoid bone entries must specify bone.',
        jsonPath: '$path.bone',
      );
      continue;
    }
    if (bone == null) {
      sink.error(
        'vrm0.unknownHumanoidBone',
        'Unknown legacy humanoid bone "${source.bone}".',
        jsonPath: '$path.bone',
      );
      continue;
    }
    if (node == null) {
      sink.error(
        'vrm0.humanoidBoneMissingNode',
        'Legacy humanoid bone ${bone.specName} must specify a node.',
        jsonPath: '$path.node',
      );
      continue;
    }
    if (node < 0 || node >= gltf.nodes.length) {
      sink.error(
        'vrm0.invalidHumanoidNode',
        'Legacy humanoid bone ${bone.specName} references invalid node $node.',
        jsonPath: '$path.node',
        gltfNodeIndex: node,
      );
      continue;
    }
    final previousForBone = humanBones[bone];
    if (previousForBone != null) {
      sink.error(
        'vrm0.duplicateHumanoidBone',
        'Legacy humanoid bone ${bone.specName} is assigned more than once.',
        jsonPath: '$path.bone',
        gltfNodeIndex: node,
      );
      continue;
    }
    final previousBone = usedNodes[node];
    if (previousBone != null) {
      sink.error(
        'vrm0.duplicateHumanoidNode',
        'Node $node is assigned to both ${previousBone.specName} and ${bone.specName}.',
        jsonPath: '$path.node',
        gltfNodeIndex: node,
      );
      continue;
    }
    usedNodes[node] = bone;
    sourceIndices[bone] = source.sourceIndex;
    humanBones[bone] = VrmHumanBone(bone: bone, node: node, raw: source.raw);
  }

  for (final requiredBone in _vrm0RequiredHumanoidBones) {
    if (humanBones.containsKey(requiredBone)) continue;
    sink.error(
      'vrm0.missingRequiredHumanoidBone',
      'VRM 0.x requires humanoid bone ${requiredBone.specName}.',
      jsonPath: r'$.extensions.VRM.humanoid.humanBones',
    );
  }

  _validateVrm0HumanoidTransforms(gltf, humanBones, sourceIndices, sink);
  _validateVrm0HumanoidParents(gltf, humanBones, sourceIndices, sink);
  return VrmHumanoid._(humanBones: humanBones, raw: legacy.raw);
}

void _validateVrm0HumanoidTransforms(
  GltfAsset gltf,
  Map<VrmHumanoidBone, VrmHumanBone> humanBones,
  Map<VrmHumanoidBone, int> sourceIndices,
  _DiagnosticSink sink,
) {
  for (final entry in humanBones.entries) {
    final bone = entry.key;
    final nodeIndex = entry.value.node;
    final node = gltf.nodes[nodeIndex];
    final sourceIndex = sourceIndices[bone]!;
    final path = '\$.extensions.VRM.humanoid.humanBones[$sourceIndex].node';
    if (node.restScale.any((component) => component <= 0) ||
        _hasReflectedMatrixBasis(node.matrix)) {
      sink.error(
        'vrm0.nonPositiveHumanoidScale',
        'Legacy humanoid bone ${bone.specName} must have positive scale.',
        jsonPath: path,
        gltfNodeIndex: nodeIndex,
      );
    }
    if (node.restScale.any((component) => (component - 1).abs() > 1e-5)) {
      sink.error(
        'vrm0.nonUnitHumanoidScale',
        'VRM 0.x normalized humanoid bone ${bone.specName} must have unit scale.',
        jsonPath: path,
        gltfNodeIndex: nodeIndex,
      );
    }
    final rotation = node.restRotation;
    final isIdentity =
        _nearlyZero(rotation[0]) &&
        _nearlyZero(rotation[1]) &&
        _nearlyZero(rotation[2]) &&
        (rotation[3].abs() - 1).abs() <= 1e-5;
    if (!isIdentity) {
      sink.error(
        'vrm0.nonIdentityHumanoidRotation',
        'VRM 0.x normalized humanoid bone ${bone.specName} must have identity local rotation.',
        jsonPath: path,
        gltfNodeIndex: nodeIndex,
      );
    }
  }
}

void _validateVrm0HumanoidParents(
  GltfAsset gltf,
  Map<VrmHumanoidBone, VrmHumanBone> humanBones,
  Map<VrmHumanoidBone, int> sourceIndices,
  _DiagnosticSink sink,
) {
  final parents = _nodeParents(gltf);
  for (final entry in humanBones.entries) {
    final expectedParent = _nearestAssignedHumanoidParent(
      entry.key,
      humanBones,
    );
    if (expectedParent == null) continue;
    final parentNode = humanBones[expectedParent]?.node;
    if (parentNode != null &&
        _isDescendantOf(entry.value.node, parentNode, parents)) {
      continue;
    }
    sink.error(
      'vrm0.invalidHumanoidParent',
      '${entry.key.specName} must be a descendant of ${expectedParent.specName}.',
      jsonPath:
          '\$.extensions.VRM.humanoid.humanBones[${sourceIndices[entry.key]}].node',
      gltfNodeIndex: entry.value.node,
    );
  }
}

VrmHumanoidBone? _vrm0HumanoidBone(Vrm0HumanBone source) {
  return switch (source.bone) {
    'leftThumbProximal' => VrmHumanoidBone.leftThumbMetacarpal,
    'leftThumbIntermediate' => VrmHumanoidBone.leftThumbProximal,
    'leftThumbDistal' => VrmHumanoidBone.leftThumbDistal,
    'rightThumbProximal' => VrmHumanoidBone.rightThumbMetacarpal,
    'rightThumbIntermediate' => VrmHumanoidBone.rightThumbProximal,
    'rightThumbDistal' => VrmHumanoidBone.rightThumbDistal,
    final String name =>
      VrmHumanoidBone.fromSpecName(name) ?? source.normalizedBone,
    null => source.normalizedBone,
  };
}

const _vrm0RequiredHumanoidBones = <VrmHumanoidBone>{
  VrmHumanoidBone.hips,
  VrmHumanoidBone.spine,
  VrmHumanoidBone.chest,
  VrmHumanoidBone.neck,
  VrmHumanoidBone.head,
  VrmHumanoidBone.leftUpperLeg,
  VrmHumanoidBone.leftLowerLeg,
  VrmHumanoidBone.leftFoot,
  VrmHumanoidBone.rightUpperLeg,
  VrmHumanoidBone.rightLowerLeg,
  VrmHumanoidBone.rightFoot,
  VrmHumanoidBone.leftUpperArm,
  VrmHumanoidBone.leftLowerArm,
  VrmHumanoidBone.leftHand,
  VrmHumanoidBone.rightUpperArm,
  VrmHumanoidBone.rightLowerArm,
  VrmHumanoidBone.rightHand,
};

VrmFirstPerson _normalizeVrm0FirstPerson(
  GltfAsset gltf,
  Vrm0FirstPerson? legacy,
  _DiagnosticSink sink,
) {
  final annotations = <VrmFirstPersonMeshAnnotation>[];
  for (var i = 0; i < (legacy?.meshAnnotations.length ?? 0); i++) {
    final source = legacy!.meshAnnotations[i];
    final mesh = source.mesh;
    final path =
        '\$.extensions.VRM.firstPerson.meshAnnotations[${source.sourceIndex}]';
    if (mesh == null) continue;
    final nodes = _vrm0NodesForMesh(
      gltf,
      mesh,
      sink,
      path: '$path.mesh',
      purpose: 'first-person annotation',
    );
    final type = _vrm0FirstPersonAnnotationType(
      source.firstPersonFlag,
      sink,
      '$path.firstPersonFlag',
    );
    annotations.addAll([
      for (final node in nodes)
        VrmFirstPersonMeshAnnotation(node: node, type: type, raw: source.raw),
    ]);
  }

  return VrmFirstPerson._(
    firstPersonBone: _vrm0NodeOrNull(
      gltf,
      legacy?.firstPersonBone,
      sink,
      r'$.extensions.VRM.firstPerson.firstPersonBone',
      'vrm0.invalidFirstPersonBone',
    ),
    meshAnnotations: annotations,
    raw: legacy?.raw ?? const {},
  );
}

VrmFirstPersonMeshAnnotationType _vrm0FirstPersonAnnotationType(
  String? value,
  _DiagnosticSink sink,
  String path,
) {
  final normalized = value?.toLowerCase();
  return switch (normalized) {
    'thirdpersononly' => VrmFirstPersonMeshAnnotationType.thirdPersonOnly,
    'firstpersononly' => VrmFirstPersonMeshAnnotationType.firstPersonOnly,
    'both' => VrmFirstPersonMeshAnnotationType.both,
    'auto' || null => VrmFirstPersonMeshAnnotationType.auto,
    _ => () {
      sink.warning(
        'vrm0.unknownFirstPersonFlag',
        'Unknown legacy first-person flag "$value" was treated as Auto.',
        jsonPath: path,
      );
      return VrmFirstPersonMeshAnnotationType.auto;
    }(),
  };
}

VrmLookAt? _normalizeVrm0LookAt(
  Vrm0FirstPerson? legacy,
  int? firstPersonBone,
  _DiagnosticSink sink,
) {
  if (legacy == null ||
      (legacy.lookAtTypeName == null &&
          legacy.lookAtHorizontalInner == null &&
          legacy.lookAtHorizontalOuter == null &&
          legacy.lookAtVerticalDown == null &&
          legacy.lookAtVerticalUp == null)) {
    return null;
  }

  final lookAtType = switch (legacy.lookAtTypeName?.toLowerCase()) {
    'blendshape' => VrmLookAtType.expression,
    'bone' || null => VrmLookAtType.bone,
    final String unknown => () {
      sink.warning(
        'vrm0.unknownLookAtType',
        'Unknown legacy LookAt type "$unknown" was treated as Bone.',
        jsonPath: r'$.extensions.VRM.firstPerson.lookAtTypeName',
      );
      return VrmLookAtType.bone;
    }(),
  };
  final defaultOutputScale = lookAtType == VrmLookAtType.bone ? 10.0 : 1.0;

  return VrmLookAt._(
    type: lookAtType,
    originNode: firstPersonBone,
    offsetFromHeadBone: _vrm0VectorList(
      legacy.firstPersonBoneOffset,
      VrmVector3.zero,
    ),
    rangeMapHorizontalInner: _normalizeVrm0DegreeMap(
      legacy.lookAtHorizontalInner,
      sink,
      'lookAtHorizontalInner',
      defaultOutputScale,
    ),
    rangeMapHorizontalOuter: _normalizeVrm0DegreeMap(
      legacy.lookAtHorizontalOuter,
      sink,
      'lookAtHorizontalOuter',
      defaultOutputScale,
    ),
    rangeMapVerticalDown: _normalizeVrm0DegreeMap(
      legacy.lookAtVerticalDown,
      sink,
      'lookAtVerticalDown',
      defaultOutputScale,
    ),
    rangeMapVerticalUp: _normalizeVrm0DegreeMap(
      legacy.lookAtVerticalUp,
      sink,
      'lookAtVerticalUp',
      defaultOutputScale,
    ),
    raw: legacy.raw,
  );
}

VrmLookAtRangeMap _normalizeVrm0DegreeMap(
  Vrm0DegreeMap? legacy,
  _DiagnosticSink sink,
  String field,
  double defaultOutputScale,
) {
  var curve = legacy?.curve ?? const <double>[];
  if (curve.length % 4 != 0 || curve.any((value) => !value.isFinite)) {
    sink.warning(
      'vrm0.invalidLookAtCurve',
      'Legacy LookAt $field curve must contain finite time, value, in-tangent, and out-tangent groups.',
      jsonPath: '\$.extensions.VRM.firstPerson.$field.curve',
    );
    curve = const [];
  }
  final input = legacy?.xRange;
  final output = legacy?.yRange;
  return VrmLookAtRangeMap(
    inputMaxValue: input != null && input.isFinite ? input : 90,
    outputScale: output != null && output.isFinite
        ? output
        : defaultOutputScale,
    curve: curve,
    raw: legacy?.raw ?? const {},
  );
}

VrmExpressions _normalizeVrm0Expressions(
  GltfAsset gltf,
  Vrm0Extension legacy,
  _DiagnosticSink sink,
) {
  final preset = <VrmExpressionPreset, VrmExpression>{};
  final custom = <String, VrmExpression>{};
  final groups = legacy.blendShapeMaster?.blendShapeGroups ?? const [];
  final declaredPresets = <VrmExpressionPreset>{
    for (final group in groups)
      if (_vrm0ExpressionPreset(group.presetName)
          case final VrmExpressionPreset value)
        value,
  };

  for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    final group = groups[groupIndex];
    final sourceGroupIndex = group.sourceIndex;
    final normalizedPreset = _vrm0ExpressionPreset(group.presetName);
    final customName = group.name;
    if (normalizedPreset == null &&
        (customName == null || customName.isEmpty)) {
      sink.warning(
        'vrm0.expressionMissingName',
        'Legacy custom expression group $sourceGroupIndex has no usable name.',
        jsonPath:
            '\$.extensions.VRM.blendShapeMaster.blendShapeGroups[$sourceGroupIndex]',
      );
      continue;
    }

    final expressionName = normalizedPreset?.specName ?? customName!;
    final morphTargetBinds = <VrmMorphTargetBind>[];
    for (var bindIndex = 0; bindIndex < group.binds.length; bindIndex++) {
      final binds = _normalizeVrm0MorphTargetBinds(
        gltf,
        group.binds[bindIndex],
        sink,
        sourceGroupIndex,
        group.binds[bindIndex].sourceIndex,
      );
      morphTargetBinds.addAll(binds);
    }

    final materialColorBinds = <VrmMaterialColorBind>[];
    final textureTransformBinds = <VrmTextureTransformBind>[];
    for (
      var bindIndex = 0;
      bindIndex < group.materialValues.length;
      bindIndex++
    ) {
      _normalizeVrm0MaterialValueBind(
        gltf,
        legacy,
        group.materialValues[bindIndex],
        sink,
        sourceGroupIndex,
        group.materialValues[bindIndex].sourceIndex,
        materialColorBinds,
        textureTransformBinds,
      );
    }

    final expression = VrmExpression._(
      name: expressionName,
      isBinary: group.isBinary ?? false,
      morphTargetBinds: morphTargetBinds,
      materialColorBinds: materialColorBinds,
      textureTransformBinds: textureTransformBinds,
      overrideMouth: VrmExpressionOverrideMode.none,
      overrideBlink: VrmExpressionOverrideMode.none,
      overrideLookAt: VrmExpressionOverrideMode.none,
      raw: group.raw,
    );

    if (normalizedPreset != null) {
      if (preset.containsKey(normalizedPreset)) {
        sink.warning(
          'vrm0.duplicatePresetExpression',
          'Legacy preset ${normalizedPreset.specName} is declared more than once; the first declaration was retained.',
          jsonPath:
              '\$.extensions.VRM.blendShapeMaster.blendShapeGroups[$sourceGroupIndex].presetName',
        );
      } else {
        preset[normalizedPreset] = expression;
      }
    } else {
      VrmExpressionPreset? presetCollision;
      for (final candidate in declaredPresets) {
        if (candidate.specName.toUpperCase() == customName!.toUpperCase()) {
          presetCollision = candidate;
          break;
        }
      }
      if (presetCollision != null) {
        sink.warning(
          'vrm0.customExpressionPresetCollision',
          'Legacy custom expression "$customName" collides with normalized preset ${presetCollision.specName}; the preset was retained in the runtime view.',
          jsonPath:
              '\$.extensions.VRM.blendShapeMaster.blendShapeGroups[$sourceGroupIndex].name',
        );
        continue;
      }
      final duplicateKey = custom.keys.where(
        (key) => key.toUpperCase() == customName!.toUpperCase(),
      );
      if (duplicateKey.isNotEmpty) {
        sink.warning(
          'vrm0.duplicateCustomExpression',
          'Legacy custom expression "$customName" collides case-insensitively with "${duplicateKey.first}"; the first declaration was retained.',
          jsonPath:
              '\$.extensions.VRM.blendShapeMaster.blendShapeGroups[$sourceGroupIndex].name',
        );
      } else {
        custom[customName!] = expression;
      }
    }
  }

  return VrmExpressions._(
    preset: preset,
    custom: custom,
    raw: legacy.blendShapeMaster?.raw ?? const {},
  );
}

VrmExpressionPreset? _vrm0ExpressionPreset(String? value) {
  return switch (value?.toLowerCase()) {
    'neutral' => VrmExpressionPreset.neutral,
    'a' => VrmExpressionPreset.aa,
    'i' => VrmExpressionPreset.ih,
    'u' => VrmExpressionPreset.ou,
    'e' => VrmExpressionPreset.ee,
    'o' => VrmExpressionPreset.oh,
    'blink' => VrmExpressionPreset.blink,
    'joy' => VrmExpressionPreset.happy,
    'angry' => VrmExpressionPreset.angry,
    'sorrow' => VrmExpressionPreset.sad,
    'fun' => VrmExpressionPreset.relaxed,
    'surprised' => VrmExpressionPreset.surprised,
    'lookup' => VrmExpressionPreset.lookUp,
    'lookdown' => VrmExpressionPreset.lookDown,
    'lookleft' => VrmExpressionPreset.lookLeft,
    'lookright' => VrmExpressionPreset.lookRight,
    'blink_l' => VrmExpressionPreset.blinkLeft,
    'blink_r' => VrmExpressionPreset.blinkRight,
    'unknown' => null,
    _ => null,
  };
}

List<VrmMorphTargetBind> _normalizeVrm0MorphTargetBinds(
  GltfAsset gltf,
  Vrm0BlendShapeBind source,
  _DiagnosticSink sink,
  int groupIndex,
  int bindIndex,
) {
  final path =
      '\$.extensions.VRM.blendShapeMaster.blendShapeGroups[$groupIndex].binds[$bindIndex]';
  final mesh = source.mesh;
  final morph = source.index;
  final weight = source.weight;
  if (mesh == null || morph == null || weight == null) return const [];
  final nodes = _vrm0NodesForMesh(
    gltf,
    mesh,
    sink,
    path: '$path.mesh',
    purpose: 'morph target bind',
  );
  if (nodes.isEmpty) return const [];
  final gltfMesh = gltf.meshes.elementAtOrNull(mesh);
  if (morph < 0 ||
      gltfMesh == null ||
      gltfMesh.primitives.any(
        (primitive) => morph >= primitive.targets.length,
      )) {
    sink.error(
      'vrm0.invalidMorphTargetIndex',
      'Legacy morph target index $morph is outside mesh $mesh.',
      jsonPath: '$path.index',
      gltfNodeIndex: nodes.first,
    );
    return const [];
  }
  if (!weight.isFinite || weight < 0 || weight > 100) {
    sink.warning(
      'vrm0.invalidMorphTargetWeight',
      'Legacy morph target weights should be in [0, 100]; the value was clamped.',
      jsonPath: '$path.weight',
      gltfNodeIndex: nodes.first,
    );
  }
  return List.unmodifiable([
    for (final node in nodes)
      VrmMorphTargetBind(
        node: node,
        index: morph,
        weight: weight.isFinite ? _clamp01(weight / 100) : 0,
        raw: source.raw,
      ),
  ]);
}

void _normalizeVrm0MaterialValueBind(
  GltfAsset gltf,
  Vrm0Extension legacy,
  Vrm0MaterialValueBind source,
  _DiagnosticSink sink,
  int groupIndex,
  int bindIndex,
  List<VrmMaterialColorBind> colorBinds,
  List<VrmTextureTransformBind> textureBinds,
) {
  final path =
      '\$.extensions.VRM.blendShapeMaster.blendShapeGroups[$groupIndex].materialValues[$bindIndex]';
  final material = _vrm0MaterialIndex(
    gltf,
    legacy.materialProperties,
    source.materialName,
    sink,
    '$path.materialName',
  );
  if (material == null) return;
  final property = source.propertyName;
  if (property == null) return;

  final colorType = _vrm0MaterialColorTypes[property];
  if (colorType != null) {
    final target = _vrm0ColorTarget(source.targetValue);
    if (target == null) {
      sink.warning(
        'vrm0.invalidMaterialColorTarget',
        'Legacy material color target must contain three or four numbers.',
        jsonPath: '$path.targetValue',
        gltfMaterialIndex: material,
      );
      return;
    }
    colorBinds.add(
      VrmMaterialColorBind(
        material: material,
        type: colorType,
        targetValue: target,
        raw: source.raw,
      ),
    );
    return;
  }

  final uvBase = _vrm0BaseTextureTransform(gltf, legacy, material);
  final uv = _vrm0TextureTransform(
    property,
    source.targetValue,
    baseScale: uvBase.$1,
    baseOffset: uvBase.$2,
  );
  if (uv != null) {
    textureBinds.add(
      VrmTextureTransformBind(
        material: material,
        scale: uv.$1,
        offset: uv.$2,
        raw: source.raw,
      ),
    );
    return;
  }

  sink.warning(
    'vrm0.unsupportedMaterialValueProperty',
    'Legacy expression material property "$property" is preserved but is not supported by the normalized runtime.',
    jsonPath: '$path.propertyName',
    gltfMaterialIndex: material,
  );
}

const _vrm0MaterialColorTypes = <String, String>{
  '_Color': 'color',
  '_EmissionColor': 'emissionColor',
  '_ShadeColor': 'shadeColor',
  '_MatCapColor': 'matcapColor',
  '_RimColor': 'rimColor',
  '_OutlineColor': 'outlineColor',
};

VrmVector4? _vrm0ColorTarget(List<double> values) {
  if (values.any((value) => !value.isFinite)) return null;
  return switch (values.length) {
    3 => VrmVector4(values[0], values[1], values[2], 1),
    4 => VrmVector4(values[0], values[1], values[2], values[3]),
    _ => null,
  };
}

(VrmVector2, VrmVector2)? _vrm0TextureTransform(
  String property,
  List<double> values, {
  required VrmVector2 baseScale,
  required VrmVector2 baseOffset,
}) {
  if (values.length != 4 || values.any((value) => !value.isFinite)) {
    return null;
  }
  final scaleX = values[0];
  final scaleY = values[1];
  final offsetX = values[2];
  final offsetY = 1 - values[3] - scaleY;
  if (property == '_MainTex_ST') {
    return (VrmVector2(scaleX, scaleY), VrmVector2(offsetX, offsetY));
  }
  if (property == '_MainTex_ST_S') {
    return (VrmVector2(scaleX, baseScale.y), VrmVector2(offsetX, baseOffset.y));
  }
  if (property == '_MainTex_ST_T') {
    return (VrmVector2(baseScale.x, scaleY), VrmVector2(baseOffset.x, offsetY));
  }
  return null;
}

(VrmVector2, VrmVector2) _vrm0BaseTextureTransform(
  GltfAsset gltf,
  Vrm0Extension legacy,
  int material,
) {
  final values = legacy.materialProperties
      .elementAtOrNull(material)
      ?.vectorProperties['_MainTex'];
  if (values != null && values.length >= 4) {
    final scale = VrmVector2(values[0], values[1]);
    return (scale, VrmVector2(values[2], 1 - values[3] - scale.y));
  }
  final gltfMaterial = gltf.materials.elementAtOrNull(material);
  if (gltfMaterial == null) return (VrmVector2.one, VrmVector2.zero);
  final base = _baseTextureTransform(gltfMaterial);
  return (base.scale, base.offset);
}

int? _vrm0MaterialIndex(
  GltfAsset gltf,
  List<Vrm0MaterialProperty> materialProperties,
  String? name,
  _DiagnosticSink sink,
  String path,
) {
  if (name == null) return null;
  final matches = <int>[];
  for (
    var i = 0;
    i < materialProperties.length && i < gltf.materials.length;
    i++
  ) {
    if (materialProperties[i].name == name) matches.add(i);
  }
  if (matches.isEmpty) {
    for (final material in gltf.materials) {
      if (material.name == name) matches.add(material.index);
    }
  }
  if (matches.isEmpty) {
    sink.warning(
      'vrm0.materialNameNotFound',
      'Legacy material expression target "$name" does not match a material.',
      jsonPath: path,
    );
    return null;
  }
  if (matches.length > 1) {
    sink.warning(
      'vrm0.ambiguousMaterialName',
      'Legacy material expression target "$name" matches multiple materials; material ${matches.first} was selected.',
      jsonPath: path,
      gltfMaterialIndex: matches.first,
    );
  }
  return matches.first;
}

List<int> _vrm0NodesForMesh(
  GltfAsset gltf,
  int mesh,
  _DiagnosticSink sink, {
  required String path,
  required String purpose,
}) {
  if (mesh < 0 || mesh >= gltf.meshes.length) return const [];
  final nodes = <int>[
    for (final node in gltf.nodes)
      if (node.mesh == mesh) node.index,
  ];
  if (nodes.isEmpty) {
    sink.error(
      'vrm0.meshHasNoNode',
      'Legacy $purpose mesh $mesh is not referenced by a glTF node.',
      jsonPath: path,
    );
    return const [];
  }
  return List.unmodifiable(nodes);
}

int? _vrm0NodeOrNull(
  GltfAsset gltf,
  int? node,
  _DiagnosticSink sink,
  String path,
  String code,
) {
  if (node == null || node == -1) return null;
  if (node < 0 || node >= gltf.nodes.length) {
    sink.error(
      code,
      'Legacy node index $node is outside the glTF node array.',
      jsonPath: path,
      gltfNodeIndex: node,
    );
    return null;
  }
  return node;
}

VrmSpringBone? _normalizeVrm0SpringBone(
  GltfAsset gltf,
  Vrm0Extension legacy,
  _DiagnosticSink sink,
) {
  final secondary = legacy.secondaryAnimation;
  if (secondary == null) return null;

  final colliders = <VrmSpringBoneCollider>[];
  final colliderGroups = <VrmSpringBoneColliderGroup>[];
  for (
    var groupIndex = 0;
    groupIndex < secondary.colliderGroups.length;
    groupIndex++
  ) {
    final sourceGroup = secondary.colliderGroups[groupIndex];
    final sourceGroupIndex = sourceGroup.sourceIndex;
    final node = _vrm0NodeOrNull(
      gltf,
      sourceGroup.node,
      sink,
      '\$.extensions.VRM.secondaryAnimation.colliderGroups[$sourceGroupIndex].node',
      'vrm0.invalidColliderNode',
    );
    final groupColliderIndices = <int>[];
    for (
      var colliderIndex = 0;
      colliderIndex < sourceGroup.colliders.length;
      colliderIndex++
    ) {
      final source = sourceGroup.colliders[colliderIndex];
      final normalizedIndex = colliders.length;
      groupColliderIndices.add(normalizedIndex);
      final offset = _vrm0VectorList(source.offset, VrmVector3.zero);
      final radius = source.radius ?? 0;
      colliders.add(
        VrmSpringBoneCollider._(
          index: normalizedIndex,
          node: node,
          shape: VrmSpringBoneColliderShape._(
            type: VrmSpringBoneColliderShapeType.sphere,
            declaredShapeCount: 1,
            offset: offset,
            radius: radius.isFinite && radius >= 0 ? radius : 0,
            tail: null,
            raw: source.raw,
          ),
          raw: source.raw,
        ),
      );
    }
    colliderGroups.add(
      VrmSpringBoneColliderGroup._(
        index: groupIndex,
        name: null,
        colliders: groupColliderIndices,
        raw: sourceGroup.raw,
      ),
    );
  }

  final springs = <VrmSpringBoneSpring>[];
  final jointOwners = <int, int>{};
  for (
    var groupIndex = 0;
    groupIndex < secondary.boneGroups.length;
    groupIndex++
  ) {
    final source = secondary.boneGroups[groupIndex];
    final sourceGroupIndex = source.sourceIndex;
    final center = _vrm0NodeOrNull(
      gltf,
      source.center,
      sink,
      '\$.extensions.VRM.secondaryAnimation.boneGroups[$sourceGroupIndex].center',
      'vrm0.invalidSpringCenter',
    );
    for (var rootIndex = 0; rootIndex < source.bones.length; rootIndex++) {
      final root = source.bones[rootIndex];
      final sourceRootIndex = source.boneSourceIndices[rootIndex];
      final subtree = _vrm0SpringSubtree(
        gltf,
        root,
        sink,
        sourceGroupIndex,
        sourceRootIndex,
      );
      if (subtree.isEmpty) continue;
      final springIndex = springs.length;
      for (final node in subtree) {
        final previousOwner = jointOwners[node];
        if (previousOwner != null) {
          sink.error(
            'vrm0.overlappingSpringChain',
            'Legacy SpringBone node $node is shared by spring chains $previousOwner and $springIndex.',
            jsonPath:
                '\$.extensions.VRM.secondaryAnimation.boneGroups[$sourceGroupIndex].bones[$sourceRootIndex]',
            gltfNodeIndex: node,
          );
        } else {
          jointOwners[node] = springIndex;
        }
      }
      springs.add(
        VrmSpringBoneSpring._(
          index: springIndex,
          name: source.comment,
          joints: [
            for (var jointIndex = 0; jointIndex < subtree.length; jointIndex++)
              VrmSpringBoneJoint._(
                index: jointIndex,
                node: subtree[jointIndex],
                hitRadius: source.hitRadius ?? 0,
                stiffness: source.stiffiness ?? 1,
                gravityPower: source.gravityPower ?? 0,
                gravityDir: _vrm0VectorList(
                  source.gravityDir,
                  const VrmVector3(0, -1, 0),
                ),
                dragForce: source.dragForce ?? 0.4,
                raw: source.raw,
              ),
          ],
          colliderGroups: [
            for (final colliderGroup in source.colliderGroups)
              if (colliderGroup >= 0 && colliderGroup < colliderGroups.length)
                colliderGroup,
          ],
          center: center,
          legacyTerminalLength: 0.07,
          raw: source.raw,
        ),
      );
    }
  }
  return VrmSpringBone._(
    sourceVersion: VrmSourceVersion.vrm0,
    specVersion: '0.0',
    colliders: colliders,
    colliderGroups: colliderGroups,
    springs: springs,
    raw: secondary.raw,
  );
}

List<int> _vrm0SpringSubtree(
  GltfAsset gltf,
  int root,
  _DiagnosticSink sink,
  int groupIndex,
  int rootIndex,
) {
  final path =
      '\$.extensions.VRM.secondaryAnimation.boneGroups[$groupIndex].bones[$rootIndex]';
  if (root < 0 || root >= gltf.nodes.length) {
    sink.error(
      'vrm0.invalidSpringRoot',
      'Legacy SpringBone root $root is outside the glTF node array.',
      jsonPath: path,
      gltfNodeIndex: root,
    );
    return const [];
  }
  final subtree = <int>[];
  final visited = <int>{};
  final active = <int>{};
  int? cycleNode;

  void visit(int nodeIndex) {
    if (nodeIndex < 0 || nodeIndex >= gltf.nodes.length) return;
    if (active.contains(nodeIndex)) {
      cycleNode ??= nodeIndex;
      return;
    }
    if (!visited.add(nodeIndex)) return;
    active.add(nodeIndex);
    subtree.add(nodeIndex);
    for (final child in gltf.nodes[nodeIndex].children) {
      visit(child);
    }
    active.remove(nodeIndex);
  }

  visit(root);
  if (cycleNode != null) {
    sink.error(
      'vrm0.springChainCycle',
      'Legacy SpringBone subtree rooted at node $root contains a cycle.',
      jsonPath: path,
      gltfNodeIndex: cycleNode,
    );
  }
  return List.unmodifiable(subtree);
}

List<double> _vrm0VectorList(VrmVector3? value, VrmVector3 fallback) {
  final source = value ?? fallback;
  return List.unmodifiable([source.x, source.y, -source.z]);
}
