part of '../../flvtterm.dart';

const _vrm0Path = r'$.extensions.VRM';

const _vrm0AllowedUserNames = {
  'OnlyAuthor',
  'ExplicitlyLicensedPerson',
  'Everyone',
};
const _vrm0UsagePermissionNames = {'Disallow', 'Allow'};
const _vrm0LicenseNames = {
  'Redistribution_Prohibited',
  'CC0',
  'CC_BY',
  'CC_BY_NC',
  'CC_BY_SA',
  'CC_BY_NC_SA',
  'CC_BY_ND',
  'CC_BY_NC_ND',
  'Other',
};
const _vrm0FirstPersonFlags = {
  'Auto',
  'Both',
  'ThirdPersonOnly',
  'FirstPersonOnly',
};
const _vrm0LookAtTypes = {'Bone', 'BlendShape'};
const _vrm0BlendShapePresets = {
  'unknown',
  'neutral',
  'a',
  'i',
  'u',
  'e',
  'o',
  'blink',
  'joy',
  'angry',
  'sorrow',
  'fun',
  'lookup',
  'lookdown',
  'lookleft',
  'lookright',
  'blink_l',
  'blink_r',
  // Accepted by the official UniVRM migration path for real-world 0.x files.
  'surprised',
};

Vrm0Extension? _parseVrm0Extension(
  GltfAsset gltf,
  _DiagnosticSink sink,
  VrmValidationMode mode,
) {
  if (!gltf.extensions.containsKey('VRM')) return null;
  final extensionValue = gltf.extensions['VRM'];
  if (extensionValue is! Map) {
    sink.error(
      'vrm0.invalidExtensionObject',
      'extensions.VRM must be a JSON object.',
      jsonPath: _vrm0Path,
    );
    return null;
  }

  final raw = _object(extensionValue);
  String? specVersion;
  if (!raw.containsKey('specVersion')) {
    const code = 'vrm0.missingSpecVersion';
    const message = 'Legacy extensions.VRM.specVersion is missing.';
    if (mode == VrmValidationMode.strict) {
      sink.error(code, message, jsonPath: '$_vrm0Path.specVersion');
    } else {
      sink.warning(code, message, jsonPath: '$_vrm0Path.specVersion');
    }
  } else {
    final value = raw['specVersion'];
    if (value is! String) {
      sink.error(
        'vrm0.invalidSpecVersion',
        'Legacy extensions.VRM.specVersion must be a string.',
        jsonPath: '$_vrm0Path.specVersion',
      );
      return null;
    }
    if (value != '0.0') {
      sink.error(
        'vrm0.unsupportedSpecVersion',
        'Unsupported legacy VRM specVersion "$value"; only "0.0" is supported.',
        jsonPath: '$_vrm0Path.specVersion',
      );
      return null;
    }
    specVersion = value;
  }

  return Vrm0Extension._(
    exporterVersion: _vrm0String(raw, 'exporterVersion', sink, _vrm0Path),
    specVersion: specVersion,
    meta: raw.containsKey('meta')
        ? _parseVrm0Meta(raw['meta'], gltf, sink, '$_vrm0Path.meta')
        : null,
    humanoid: raw.containsKey('humanoid')
        ? _parseVrm0Humanoid(raw['humanoid'], gltf, sink, '$_vrm0Path.humanoid')
        : null,
    firstPerson: raw.containsKey('firstPerson')
        ? _parseVrm0FirstPerson(
            raw['firstPerson'],
            gltf,
            sink,
            '$_vrm0Path.firstPerson',
          )
        : null,
    blendShapeMaster: raw.containsKey('blendShapeMaster')
        ? _parseVrm0BlendShapeMaster(
            raw['blendShapeMaster'],
            gltf,
            sink,
            '$_vrm0Path.blendShapeMaster',
          )
        : null,
    secondaryAnimation: raw.containsKey('secondaryAnimation')
        ? _parseVrm0SecondaryAnimation(
            raw['secondaryAnimation'],
            gltf,
            sink,
            '$_vrm0Path.secondaryAnimation',
          )
        : null,
    materialProperties: raw.containsKey('materialProperties')
        ? _parseVrm0MaterialProperties(
            raw['materialProperties'],
            gltf,
            sink,
            '$_vrm0Path.materialProperties',
          )
        : const [],
    raw: raw,
  );
}

Vrm0Meta? _parseVrm0Meta(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path,
) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x meta');
  if (raw == null) return null;
  return Vrm0Meta._(
    title: _vrm0String(raw, 'title', sink, path),
    version: _vrm0String(raw, 'version', sink, path),
    author: _vrm0String(raw, 'author', sink, path),
    contactInformation: _vrm0String(raw, 'contactInformation', sink, path),
    reference: _vrm0String(raw, 'reference', sink, path),
    texture: _vrm0Index(
      raw,
      'texture',
      gltf.textures.length,
      sink,
      path,
      kind: 'texture',
      allowMinusOne: true,
    ),
    allowedUserName: _vrm0EnumString(
      raw,
      'allowedUserName',
      _vrm0AllowedUserNames,
      sink,
      path,
    ),
    violentUssageName: _vrm0EnumString(
      raw,
      'violentUssageName',
      _vrm0UsagePermissionNames,
      sink,
      path,
    ),
    sexualUssageName: _vrm0EnumString(
      raw,
      'sexualUssageName',
      _vrm0UsagePermissionNames,
      sink,
      path,
    ),
    commercialUssageName: _vrm0EnumString(
      raw,
      'commercialUssageName',
      _vrm0UsagePermissionNames,
      sink,
      path,
    ),
    otherPermissionUrl: _vrm0String(raw, 'otherPermissionUrl', sink, path),
    licenseName: _vrm0EnumString(
      raw,
      'licenseName',
      _vrm0LicenseNames,
      sink,
      path,
    ),
    otherLicenseUrl: _vrm0String(raw, 'otherLicenseUrl', sink, path),
    raw: raw,
  );
}

Vrm0Humanoid? _parseVrm0Humanoid(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path,
) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x humanoid');
  if (raw == null) return null;
  final humanBones = <Vrm0HumanBone>[];
  if (raw.containsKey('humanBones')) {
    final values = _vrm0Array(raw['humanBones'], sink, '$path.humanBones');
    if (values != null) {
      for (var i = 0; i < values.length; i++) {
        final bone = _parseVrm0HumanBone(
          values[i],
          gltf,
          sink,
          '$path.humanBones[$i]',
          sourceIndex: i,
        );
        if (bone != null) humanBones.add(bone);
      }
    }
  }
  return Vrm0Humanoid._(
    humanBones: humanBones,
    armStretch: _vrm0Number(raw, 'armStretch', sink, path),
    legStretch: _vrm0Number(raw, 'legStretch', sink, path),
    upperArmTwist: _vrm0Number(raw, 'upperArmTwist', sink, path),
    lowerArmTwist: _vrm0Number(raw, 'lowerArmTwist', sink, path),
    upperLegTwist: _vrm0Number(raw, 'upperLegTwist', sink, path),
    lowerLegTwist: _vrm0Number(raw, 'lowerLegTwist', sink, path),
    feetSpacing: _vrm0Number(raw, 'feetSpacing', sink, path),
    hasTranslationDoF: _vrm0Boolean(raw, 'hasTranslationDoF', sink, path),
    raw: raw,
  );
}

Vrm0HumanBone? _parseVrm0HumanBone(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path, {
  required int sourceIndex,
}) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x human bone');
  if (raw == null) return null;
  final bone = _vrm0String(raw, 'bone', sink, path);
  final normalizedBone = bone == null ? null : _vrm0NormalizeBone(bone);
  if (bone != null && normalizedBone == null) {
    sink.error(
      'vrm0.invalidHumanBoneName',
      '"$bone" is not a VRM 0.x humanoid bone name.',
      jsonPath: '$path.bone',
    );
  }
  return Vrm0HumanBone._(
    sourceIndex: sourceIndex,
    bone: bone,
    normalizedBone: normalizedBone,
    node: _vrm0Index(raw, 'node', gltf.nodes.length, sink, path, kind: 'node'),
    useDefaultValues: _vrm0Boolean(raw, 'useDefaultValues', sink, path),
    min: _vrm0VectorMember(raw, 'min', sink, path),
    max: _vrm0VectorMember(raw, 'max', sink, path),
    center: _vrm0VectorMember(raw, 'center', sink, path),
    axisLength: _vrm0Number(raw, 'axisLength', sink, path),
    raw: raw,
  );
}

VrmHumanoidBone? _vrm0NormalizeBone(String bone) {
  return switch (bone) {
    'leftThumbProximal' => VrmHumanoidBone.leftThumbMetacarpal,
    'leftThumbIntermediate' => VrmHumanoidBone.leftThumbProximal,
    'leftThumbMetacarpal' => null,
    'rightThumbProximal' => VrmHumanoidBone.rightThumbMetacarpal,
    'rightThumbIntermediate' => VrmHumanoidBone.rightThumbProximal,
    'rightThumbMetacarpal' => null,
    _ => VrmHumanoidBone.fromSpecName(bone),
  };
}

Vrm0FirstPerson? _parseVrm0FirstPerson(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path,
) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x firstPerson');
  if (raw == null) return null;
  final annotations = <Vrm0MeshAnnotation>[];
  if (raw.containsKey('meshAnnotations')) {
    final values = _vrm0Array(
      raw['meshAnnotations'],
      sink,
      '$path.meshAnnotations',
    );
    if (values != null) {
      for (var i = 0; i < values.length; i++) {
        final annotation = _parseVrm0MeshAnnotation(
          values[i],
          gltf,
          sink,
          '$path.meshAnnotations[$i]',
          sourceIndex: i,
        );
        if (annotation != null) annotations.add(annotation);
      }
    }
  }
  return Vrm0FirstPerson._(
    firstPersonBone: _vrm0Index(
      raw,
      'firstPersonBone',
      gltf.nodes.length,
      sink,
      path,
      kind: 'node',
      allowMinusOne: true,
    ),
    firstPersonBoneOffset: _vrm0VectorMember(
      raw,
      'firstPersonBoneOffset',
      sink,
      path,
    ),
    meshAnnotations: annotations,
    lookAtTypeName: _vrm0EnumString(
      raw,
      'lookAtTypeName',
      _vrm0LookAtTypes,
      sink,
      path,
    ),
    lookAtHorizontalInner: raw.containsKey('lookAtHorizontalInner')
        ? _parseVrm0DegreeMap(
            raw['lookAtHorizontalInner'],
            sink,
            '$path.lookAtHorizontalInner',
          )
        : null,
    lookAtHorizontalOuter: raw.containsKey('lookAtHorizontalOuter')
        ? _parseVrm0DegreeMap(
            raw['lookAtHorizontalOuter'],
            sink,
            '$path.lookAtHorizontalOuter',
          )
        : null,
    lookAtVerticalDown: raw.containsKey('lookAtVerticalDown')
        ? _parseVrm0DegreeMap(
            raw['lookAtVerticalDown'],
            sink,
            '$path.lookAtVerticalDown',
          )
        : null,
    lookAtVerticalUp: raw.containsKey('lookAtVerticalUp')
        ? _parseVrm0DegreeMap(
            raw['lookAtVerticalUp'],
            sink,
            '$path.lookAtVerticalUp',
          )
        : null,
    raw: raw,
  );
}

Vrm0MeshAnnotation? _parseVrm0MeshAnnotation(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path, {
  required int sourceIndex,
}) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x mesh annotation');
  if (raw == null) return null;
  return Vrm0MeshAnnotation._(
    sourceIndex: sourceIndex,
    mesh: _vrm0Index(raw, 'mesh', gltf.meshes.length, sink, path, kind: 'mesh'),
    firstPersonFlag: _vrm0EnumString(
      raw,
      'firstPersonFlag',
      _vrm0FirstPersonFlags,
      sink,
      path,
    ),
    raw: raw,
  );
}

Vrm0DegreeMap? _parseVrm0DegreeMap(
  Object? value,
  _DiagnosticSink sink,
  String path,
) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x degree map');
  if (raw == null) return null;
  var curve = const <double>[];
  if (raw.containsKey('curve')) {
    curve = _vrm0NumberList(raw['curve'], sink, '$path.curve');
    if (curve.isNotEmpty && (curve.length < 4 || curve.length % 4 != 0)) {
      sink.error(
        'vrm0.invalidDegreeMapCurve',
        'Degree-map curve must contain time, value, in-tangent, and out-tangent tuples.',
        jsonPath: '$path.curve',
      );
      curve = const [];
    } else {
      for (var offset = 4; offset < curve.length; offset += 4) {
        if (curve[offset] > curve[offset - 4]) continue;
        sink.error(
          'vrm0.invalidDegreeMapCurve',
          'Degree-map curve key times must be strictly increasing.',
          jsonPath: '$path.curve[$offset]',
        );
        curve = const [];
        break;
      }
    }
  }
  final xRange = _vrm0Number(raw, 'xRange', sink, path);
  final yRange = _vrm0Number(raw, 'yRange', sink, path);
  return Vrm0DegreeMap._(
    curve: curve,
    xRange: xRange,
    yRange: yRange,
    raw: raw,
  );
}

Vrm0BlendShapeMaster? _parseVrm0BlendShapeMaster(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path,
) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x blendShapeMaster');
  if (raw == null) return null;
  final groups = <Vrm0BlendShapeGroup>[];
  if (raw.containsKey('blendShapeGroups')) {
    final values = _vrm0Array(
      raw['blendShapeGroups'],
      sink,
      '$path.blendShapeGroups',
    );
    if (values != null) {
      for (var i = 0; i < values.length; i++) {
        final group = _parseVrm0BlendShapeGroup(
          values[i],
          gltf,
          sink,
          '$path.blendShapeGroups[$i]',
          sourceIndex: i,
        );
        if (group != null) groups.add(group);
      }
    }
  }
  return Vrm0BlendShapeMaster._(blendShapeGroups: groups, raw: raw);
}

Vrm0BlendShapeGroup? _parseVrm0BlendShapeGroup(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path, {
  required int sourceIndex,
}) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x blend-shape group');
  if (raw == null) return null;
  final binds = <Vrm0BlendShapeBind>[];
  if (raw.containsKey('binds')) {
    final values = _vrm0Array(raw['binds'], sink, '$path.binds');
    if (values != null) {
      for (var i = 0; i < values.length; i++) {
        final bind = _parseVrm0BlendShapeBind(
          values[i],
          gltf,
          sink,
          '$path.binds[$i]',
          sourceIndex: i,
        );
        if (bind != null) binds.add(bind);
      }
    }
  }
  final materialValues = <Vrm0MaterialValueBind>[];
  if (raw.containsKey('materialValues')) {
    final values = _vrm0Array(
      raw['materialValues'],
      sink,
      '$path.materialValues',
    );
    if (values != null) {
      for (var i = 0; i < values.length; i++) {
        final bind = _parseVrm0MaterialValueBind(
          values[i],
          sink,
          '$path.materialValues[$i]',
          sourceIndex: i,
        );
        if (bind != null) materialValues.add(bind);
      }
    }
  }
  return Vrm0BlendShapeGroup._(
    sourceIndex: sourceIndex,
    name: _vrm0String(raw, 'name', sink, path),
    presetName: _vrm0EnumString(
      raw,
      'presetName',
      _vrm0BlendShapePresets,
      sink,
      path,
    ),
    binds: binds,
    materialValues: materialValues,
    isBinary: _vrm0Boolean(raw, 'isBinary', sink, path),
    raw: raw,
  );
}

Vrm0BlendShapeBind? _parseVrm0BlendShapeBind(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path, {
  required int sourceIndex,
}) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x blend-shape bind');
  if (raw == null) return null;
  final mesh = _vrm0Index(
    raw,
    'mesh',
    gltf.meshes.length,
    sink,
    path,
    kind: 'mesh',
  );
  var morphIndex = _vrm0NonNegativeInteger(raw, 'index', sink, path);
  if (mesh != null && morphIndex != null) {
    final targetMesh = gltf.meshes[mesh];
    if (targetMesh.primitives.isEmpty ||
        targetMesh.primitives.any(
          (primitive) => morphIndex! >= primitive.targets.length,
        )) {
      sink.error(
        'vrm0.morphTargetIndexOutOfRange',
        'Blend-shape bind index $morphIndex is outside mesh $mesh morph targets.',
        jsonPath: '$path.index',
      );
      morphIndex = null;
    }
  }
  return Vrm0BlendShapeBind._(
    sourceIndex: sourceIndex,
    mesh: mesh,
    index: morphIndex,
    weight: _vrm0Number(raw, 'weight', sink, path, minimum: 0, maximum: 100),
    raw: raw,
  );
}

Vrm0MaterialValueBind? _parseVrm0MaterialValueBind(
  Object? value,
  _DiagnosticSink sink,
  String path, {
  required int sourceIndex,
}) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x material-value bind');
  if (raw == null) return null;
  return Vrm0MaterialValueBind._(
    sourceIndex: sourceIndex,
    materialName: _vrm0String(raw, 'materialName', sink, path),
    propertyName: _vrm0String(raw, 'propertyName', sink, path),
    targetValue: raw.containsKey('targetValue')
        ? _vrm0NumberList(raw['targetValue'], sink, '$path.targetValue')
        : const [],
    raw: raw,
  );
}

Vrm0SecondaryAnimation? _parseVrm0SecondaryAnimation(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path,
) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x secondaryAnimation');
  if (raw == null) return null;

  final colliderGroups = <Vrm0ColliderGroup>[];
  var colliderGroupCount = 0;
  if (raw.containsKey('colliderGroups')) {
    final values = _vrm0Array(
      raw['colliderGroups'],
      sink,
      '$path.colliderGroups',
    );
    if (values != null) {
      colliderGroupCount = values.length;
      for (var i = 0; i < values.length; i++) {
        final group = _parseVrm0ColliderGroup(
          values[i],
          gltf,
          sink,
          '$path.colliderGroups[$i]',
          sourceIndex: i,
        );
        // Collider-group indices refer to source array positions, so retain a
        // placeholder for malformed entries instead of shifting later groups.
        colliderGroups.add(
          group ??
              Vrm0ColliderGroup._(
                sourceIndex: i,
                node: null,
                colliders: const [],
                raw: const {},
              ),
        );
      }
    }
  }

  final boneGroups = <Vrm0SpringBoneGroup>[];
  if (raw.containsKey('boneGroups')) {
    final values = _vrm0Array(raw['boneGroups'], sink, '$path.boneGroups');
    if (values != null) {
      for (var i = 0; i < values.length; i++) {
        final group = _parseVrm0SpringBoneGroup(
          values[i],
          gltf,
          colliderGroupCount,
          sink,
          '$path.boneGroups[$i]',
          sourceIndex: i,
        );
        if (group != null) boneGroups.add(group);
      }
    }
  }

  return Vrm0SecondaryAnimation._(
    boneGroups: boneGroups,
    colliderGroups: colliderGroups,
    raw: raw,
  );
}

Vrm0SpringBoneGroup? _parseVrm0SpringBoneGroup(
  Object? value,
  GltfAsset gltf,
  int colliderGroupCount,
  _DiagnosticSink sink,
  String path, {
  required int sourceIndex,
}) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x spring-bone group');
  if (raw == null) return null;
  final bones = raw.containsKey('bones')
      ? _vrm0IndexList(
          raw['bones'],
          gltf.nodes.length,
          sink,
          '$path.bones',
          kind: 'node',
        )
      : (values: const <int>[], sourceIndices: const <int>[]);
  final colliderGroups = raw.containsKey('colliderGroups')
      ? _vrm0IndexList(
          raw['colliderGroups'],
          colliderGroupCount,
          sink,
          '$path.colliderGroups',
          kind: 'collider group',
        )
      : (values: const <int>[], sourceIndices: const <int>[]);
  return Vrm0SpringBoneGroup._(
    sourceIndex: sourceIndex,
    comment: _vrm0String(raw, 'comment', sink, path),
    stiffiness: _vrm0Number(raw, 'stiffiness', sink, path, minimum: 0),
    gravityPower: _vrm0Number(raw, 'gravityPower', sink, path, minimum: 0),
    gravityDir: _vrm0VectorMember(raw, 'gravityDir', sink, path),
    dragForce: _vrm0Number(
      raw,
      'dragForce',
      sink,
      path,
      minimum: 0,
      maximum: 1,
    ),
    center: _vrm0Index(
      raw,
      'center',
      gltf.nodes.length,
      sink,
      path,
      kind: 'node',
      allowMinusOne: true,
    ),
    hitRadius: _vrm0Number(raw, 'hitRadius', sink, path, minimum: 0),
    bones: bones.values,
    boneSourceIndices: bones.sourceIndices,
    colliderGroups: colliderGroups.values,
    colliderGroupSourceIndices: colliderGroups.sourceIndices,
    raw: raw,
  );
}

Vrm0ColliderGroup? _parseVrm0ColliderGroup(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path, {
  required int sourceIndex,
}) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x collider group');
  if (raw == null) return null;
  final colliders = <Vrm0Collider>[];
  if (raw.containsKey('colliders')) {
    final values = _vrm0Array(raw['colliders'], sink, '$path.colliders');
    if (values != null) {
      for (var i = 0; i < values.length; i++) {
        final collider = _parseVrm0Collider(
          values[i],
          sink,
          '$path.colliders[$i]',
          sourceIndex: i,
        );
        if (collider != null) colliders.add(collider);
      }
    }
  }
  return Vrm0ColliderGroup._(
    sourceIndex: sourceIndex,
    node: _vrm0Index(raw, 'node', gltf.nodes.length, sink, path, kind: 'node'),
    colliders: colliders,
    raw: raw,
  );
}

Vrm0Collider? _parseVrm0Collider(
  Object? value,
  _DiagnosticSink sink,
  String path, {
  required int sourceIndex,
}) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x collider');
  if (raw == null) return null;
  return Vrm0Collider._(
    sourceIndex: sourceIndex,
    offset: _vrm0VectorMember(raw, 'offset', sink, path),
    radius: _vrm0Number(raw, 'radius', sink, path, minimum: 0),
    raw: raw,
  );
}

List<Vrm0MaterialProperty> _parseVrm0MaterialProperties(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path,
) {
  final values = _vrm0Array(value, sink, path);
  if (values == null) return const [];
  if (values.length != gltf.materials.length) {
    sink.error(
      'vrm0.materialPropertyCountMismatch',
      'materialProperties has ${values.length} entries, but glTF has ${gltf.materials.length} materials.',
      jsonPath: path,
    );
  }
  return List<Vrm0MaterialProperty>.unmodifiable([
    for (var i = 0; i < values.length; i++)
      _parseVrm0MaterialProperty(values[i], gltf, sink, '$path[$i]', i) ??
          Vrm0MaterialProperty._(
            name: null,
            shader: null,
            renderQueue: null,
            floatProperties: const {},
            vectorProperties: const {},
            textureProperties: const {},
            keywordMap: const {},
            tagMap: const {},
            raw: const {},
          ),
  ]);
}

Vrm0MaterialProperty? _parseVrm0MaterialProperty(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
  String path,
  int materialIndex,
) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x material property');
  if (raw == null) return null;
  return Vrm0MaterialProperty._(
    name: _vrm0String(raw, 'name', sink, path),
    shader: _vrm0String(raw, 'shader', sink, path),
    renderQueue: _vrm0Integer(raw, 'renderQueue', sink, path),
    floatProperties: raw.containsKey('floatProperties')
        ? _vrm0NumberMap(
            raw['floatProperties'],
            sink,
            '$path.floatProperties',
            materialIndex,
          )
        : const {},
    vectorProperties: raw.containsKey('vectorProperties')
        ? _vrm0VectorMap(
            raw['vectorProperties'],
            sink,
            '$path.vectorProperties',
            materialIndex,
          )
        : const {},
    textureProperties: raw.containsKey('textureProperties')
        ? _vrm0TextureMap(
            raw['textureProperties'],
            gltf.textures.length,
            sink,
            '$path.textureProperties',
            materialIndex,
          )
        : const {},
    keywordMap: raw.containsKey('keywordMap')
        ? _vrm0BooleanMap(
            raw['keywordMap'],
            sink,
            '$path.keywordMap',
            materialIndex,
          )
        : const {},
    tagMap: raw.containsKey('tagMap')
        ? _vrm0StringMap(raw['tagMap'], sink, '$path.tagMap', materialIndex)
        : const {},
    raw: raw,
  );
}

Map<String, Object?>? _vrm0Object(
  Object? value,
  _DiagnosticSink sink,
  String path,
  String description,
) {
  if (value is Map) return _object(value);
  sink.error(
    'vrm0.invalidObject',
    '$description must be a JSON object.',
    jsonPath: path,
  );
  return null;
}

List<Object?>? _vrm0Array(Object? value, _DiagnosticSink sink, String path) {
  if (value is List) return _list(value);
  sink.error(
    'vrm0.invalidArray',
    'The value must be a JSON array.',
    jsonPath: path,
  );
  return null;
}

String? _vrm0String(
  Map<String, Object?> raw,
  String field,
  _DiagnosticSink sink,
  String path,
) {
  if (!raw.containsKey(field)) return null;
  final value = raw[field];
  if (value is String) return value;
  sink.error(
    'vrm0.invalidString',
    '$field must be a string.',
    jsonPath: '$path.$field',
  );
  return null;
}

String? _vrm0EnumString(
  Map<String, Object?> raw,
  String field,
  Set<String> allowed,
  _DiagnosticSink sink,
  String path,
) {
  final value = _vrm0String(raw, field, sink, path);
  if (value != null && !allowed.contains(value)) {
    if (allowed.any(
      (candidate) => candidate.toLowerCase() == value.toLowerCase(),
    )) {
      sink.warning(
        'vrm0.nonCanonicalEnumCase',
        '$field uses non-canonical casing "$value".',
        jsonPath: '$path.$field',
      );
      return value;
    }
    sink.error(
      'vrm0.invalidEnumValue',
      '$field has unsupported value "$value".',
      jsonPath: '$path.$field',
    );
  }
  return value;
}

bool? _vrm0Boolean(
  Map<String, Object?> raw,
  String field,
  _DiagnosticSink sink,
  String path,
) {
  if (!raw.containsKey(field)) return null;
  final value = raw[field];
  if (value is bool) return value;
  sink.error(
    'vrm0.invalidBoolean',
    '$field must be a boolean.',
    jsonPath: '$path.$field',
  );
  return null;
}

int? _vrm0Integer(
  Map<String, Object?> raw,
  String field,
  _DiagnosticSink sink,
  String path,
) {
  if (!raw.containsKey(field)) return null;
  final value = raw[field];
  if (value is int) return value;
  sink.error(
    'vrm0.invalidInteger',
    '$field must be an integer.',
    jsonPath: '$path.$field',
  );
  return null;
}

int? _vrm0NonNegativeInteger(
  Map<String, Object?> raw,
  String field,
  _DiagnosticSink sink,
  String path,
) {
  final value = _vrm0Integer(raw, field, sink, path);
  if (value != null && value < 0) {
    sink.error(
      'vrm0.negativeIndex',
      '$field must be non-negative.',
      jsonPath: '$path.$field',
    );
    return null;
  }
  return value;
}

double? _vrm0Number(
  Map<String, Object?> raw,
  String field,
  _DiagnosticSink sink,
  String path, {
  double? minimum,
  double? maximum,
}) {
  if (!raw.containsKey(field)) return null;
  return _vrm0NumberValue(
    raw[field],
    sink,
    '$path.$field',
    field,
    minimum: minimum,
    maximum: maximum,
  );
}

double? _vrm0NumberValue(
  Object? value,
  _DiagnosticSink sink,
  String path,
  String description, {
  double? minimum,
  double? maximum,
  int? gltfMaterialIndex,
}) {
  if (value is! num) {
    sink.error(
      'vrm0.invalidNumber',
      '$description must be a number.',
      jsonPath: path,
      gltfMaterialIndex: gltfMaterialIndex,
    );
    return null;
  }
  final result = value.toDouble();
  if (!result.isFinite) {
    sink.error(
      'vrm0.nonFiniteNumber',
      '$description must be finite.',
      jsonPath: path,
      gltfMaterialIndex: gltfMaterialIndex,
    );
    return null;
  }
  if ((minimum != null && result < minimum) ||
      (maximum != null && result > maximum)) {
    final range = minimum != null && maximum != null
        ? '[$minimum, $maximum]'
        : minimum != null
        ? 'at least $minimum'
        : 'at most $maximum';
    sink.error(
      'vrm0.numberOutOfRange',
      '$description must be $range.',
      jsonPath: path,
      gltfMaterialIndex: gltfMaterialIndex,
    );
    return null;
  }
  return result;
}

int? _vrm0Index(
  Map<String, Object?> raw,
  String field,
  int count,
  _DiagnosticSink sink,
  String path, {
  required String kind,
  bool allowMinusOne = false,
}) {
  final value = _vrm0Integer(raw, field, sink, path);
  if (value == null) return null;
  if (allowMinusOne && value == -1) return null;
  if (value < 0 || value >= count) {
    sink.error(
      'vrm0.indexOutOfRange',
      '$field references $kind index $value, but the valid range is 0 through ${count - 1}.',
      jsonPath: '$path.$field',
      gltfNodeIndex: kind == 'node' ? value : null,
    );
    return null;
  }
  return value;
}

({List<int> values, List<int> sourceIndices}) _vrm0IndexList(
  Object? value,
  int count,
  _DiagnosticSink sink,
  String path, {
  required String kind,
}) {
  final values = _vrm0Array(value, sink, path);
  if (values == null) {
    return (values: const <int>[], sourceIndices: const <int>[]);
  }
  final result = <int>[];
  final sourceIndices = <int>[];
  for (var i = 0; i < values.length; i++) {
    final item = values[i];
    if (item is! int) {
      sink.error(
        'vrm0.invalidInteger',
        '$kind index must be an integer.',
        jsonPath: '$path[$i]',
      );
      continue;
    }
    if (item < 0 || item >= count) {
      sink.error(
        'vrm0.indexOutOfRange',
        '$kind index $item is outside the valid range 0 through ${count - 1}.',
        jsonPath: '$path[$i]',
        gltfNodeIndex: kind == 'node' ? item : null,
      );
      continue;
    }
    result.add(item);
    sourceIndices.add(i);
  }
  return (
    values: List.unmodifiable(result),
    sourceIndices: List.unmodifiable(sourceIndices),
  );
}

VrmVector3? _vrm0VectorMember(
  Map<String, Object?> raw,
  String field,
  _DiagnosticSink sink,
  String path,
) {
  if (!raw.containsKey(field)) return null;
  return _parseVrm0Vector(raw[field], sink, '$path.$field');
}

VrmVector3? _parseVrm0Vector(Object? value, _DiagnosticSink sink, String path) {
  final raw = _vrm0Object(value, sink, path, 'VRM 0.x vector');
  if (raw == null) return null;
  final x = raw.containsKey('x')
      ? _vrm0NumberValue(raw['x'], sink, '$path.x', 'x')
      : null;
  final y = raw.containsKey('y')
      ? _vrm0NumberValue(raw['y'], sink, '$path.y', 'y')
      : null;
  final z = raw.containsKey('z')
      ? _vrm0NumberValue(raw['z'], sink, '$path.z', 'z')
      : null;
  for (final component in const ['x', 'y', 'z']) {
    if (!raw.containsKey(component)) {
      sink.error(
        'vrm0.missingVectorComponent',
        'Vector component $component is missing.',
        jsonPath: '$path.$component',
      );
    }
  }
  return x == null || y == null || z == null ? null : VrmVector3(x, y, z);
}

List<double> _vrm0NumberList(
  Object? value,
  _DiagnosticSink sink,
  String path, {
  int? gltfMaterialIndex,
}) {
  final values = _vrm0Array(value, sink, path);
  if (values == null) return const [];
  final result = <double>[];
  var valid = true;
  for (var i = 0; i < values.length; i++) {
    final number = _vrm0NumberValue(
      values[i],
      sink,
      '$path[$i]',
      'Array value',
      gltfMaterialIndex: gltfMaterialIndex,
    );
    if (number == null) {
      valid = false;
    } else {
      result.add(number);
    }
  }
  return valid ? List.unmodifiable(result) : const [];
}

Map<String, double> _vrm0NumberMap(
  Object? value,
  _DiagnosticSink sink,
  String path,
  int materialIndex,
) {
  final raw = _vrm0Map(value, sink, path, materialIndex);
  if (raw == null) return const {};
  final result = <String, double>{};
  for (final entry in raw.entries) {
    final number = _vrm0NumberValue(
      entry.value,
      sink,
      '$path.${entry.key}',
      'Material float property "${entry.key}"',
      gltfMaterialIndex: materialIndex,
    );
    if (number != null) result[entry.key] = number;
  }
  return Map.unmodifiable(result);
}

Map<String, List<double>> _vrm0VectorMap(
  Object? value,
  _DiagnosticSink sink,
  String path,
  int materialIndex,
) {
  final raw = _vrm0Map(value, sink, path, materialIndex);
  if (raw == null) return const {};
  final result = <String, List<double>>{};
  for (final entry in raw.entries) {
    if (entry.value is! List) {
      sink.error(
        'vrm0.invalidMapValue',
        'Material vector property "${entry.key}" must be an array.',
        jsonPath: '$path.${entry.key}',
        gltfMaterialIndex: materialIndex,
      );
      continue;
    }
    final values = _vrm0NumberList(
      entry.value,
      sink,
      '$path.${entry.key}',
      gltfMaterialIndex: materialIndex,
    );
    if (values.length == (entry.value as List).length) {
      result[entry.key] = values;
    }
  }
  return Map.unmodifiable(result);
}

Map<String, int> _vrm0TextureMap(
  Object? value,
  int textureCount,
  _DiagnosticSink sink,
  String path,
  int materialIndex,
) {
  final raw = _vrm0Map(value, sink, path, materialIndex);
  if (raw == null) return const {};
  final result = <String, int>{};
  for (final entry in raw.entries) {
    final texture = entry.value;
    if (texture is! int) {
      sink.error(
        'vrm0.invalidMapValue',
        'Material texture property "${entry.key}" must be an integer.',
        jsonPath: '$path.${entry.key}',
        gltfMaterialIndex: materialIndex,
      );
      continue;
    }
    if (texture == -1) {
      result[entry.key] = texture;
      continue;
    }
    if (texture < 0 || texture >= textureCount) {
      sink.error(
        'vrm0.indexOutOfRange',
        'Material texture property "${entry.key}" references texture index $texture outside the valid range.',
        jsonPath: '$path.${entry.key}',
        gltfMaterialIndex: materialIndex,
      );
      continue;
    }
    result[entry.key] = texture;
  }
  return Map.unmodifiable(result);
}

Map<String, bool> _vrm0BooleanMap(
  Object? value,
  _DiagnosticSink sink,
  String path,
  int materialIndex,
) {
  final raw = _vrm0Map(value, sink, path, materialIndex);
  if (raw == null) return const {};
  final result = <String, bool>{};
  for (final entry in raw.entries) {
    if (entry.value is bool) {
      result[entry.key] = entry.value as bool;
    } else {
      sink.error(
        'vrm0.invalidMapValue',
        'Material keyword "${entry.key}" must be a boolean.',
        jsonPath: '$path.${entry.key}',
        gltfMaterialIndex: materialIndex,
      );
    }
  }
  return Map.unmodifiable(result);
}

Map<String, String> _vrm0StringMap(
  Object? value,
  _DiagnosticSink sink,
  String path,
  int materialIndex,
) {
  final raw = _vrm0Map(value, sink, path, materialIndex);
  if (raw == null) return const {};
  final result = <String, String>{};
  for (final entry in raw.entries) {
    if (entry.value is String) {
      result[entry.key] = entry.value as String;
    } else {
      sink.error(
        'vrm0.invalidMapValue',
        'Material tag "${entry.key}" must be a string.',
        jsonPath: '$path.${entry.key}',
        gltfMaterialIndex: materialIndex,
      );
    }
  }
  return Map.unmodifiable(result);
}

Map<String, Object?>? _vrm0Map(
  Object? value,
  _DiagnosticSink sink,
  String path,
  int materialIndex,
) {
  if (value is Map) return _object(value);
  sink.error(
    'vrm0.invalidMap',
    'Material property map must be a JSON object.',
    jsonPath: path,
    gltfMaterialIndex: materialIndex,
  );
  return null;
}
