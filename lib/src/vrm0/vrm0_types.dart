part of '../../flvtterm.dart';

/// Parsed legacy `extensions.VRM` data from a VRM 0.x asset.
final class Vrm0Extension {
  Vrm0Extension._({
    required this.exporterVersion,
    required this.specVersion,
    required this.meta,
    required this.humanoid,
    required this.firstPerson,
    required this.blendShapeMaster,
    required this.secondaryAnimation,
    required List<Vrm0MaterialProperty> materialProperties,
    required Map<String, Object?> raw,
  }) : materialProperties = List.unmodifiable(materialProperties),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Version string reported by the exporter that created the asset.
  final String? exporterVersion;

  /// Legacy VRM specification version, normally `0.0`.
  final String? specVersion;

  /// Legacy model metadata, when present.
  final Vrm0Meta? meta;

  /// Legacy humanoid configuration, when present.
  final Vrm0Humanoid? humanoid;

  /// Legacy first-person and gaze configuration, when present.
  final Vrm0FirstPerson? firstPerson;

  /// Legacy blend-shape expression configuration, when present.
  final Vrm0BlendShapeMaster? blendShapeMaster;

  /// Legacy secondary-animation configuration, when present.
  final Vrm0SecondaryAnimation? secondaryAnimation;

  /// Legacy material properties in source array order.
  final List<Vrm0MaterialProperty> materialProperties;

  /// Original `extensions.VRM` JSON object.
  final Map<String, Object?> raw;
}

/// Legacy VRM 0.x model metadata.
final class Vrm0Meta {
  Vrm0Meta._({
    required this.title,
    required this.version,
    required this.author,
    required this.contactInformation,
    required this.reference,
    required this.texture,
    required this.allowedUserName,
    required this.violentUssageName,
    required this.sexualUssageName,
    required this.commercialUssageName,
    required this.otherPermissionUrl,
    required this.licenseName,
    required this.otherLicenseUrl,
    required Map<String, Object?> raw,
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Model title.
  final String? title;

  /// Model version supplied by the author.
  final String? version;

  /// Model author.
  final String? author;

  /// Author contact information.
  final String? contactInformation;

  /// Reference or original-work information.
  final String? reference;

  /// glTF texture index used as the model thumbnail.
  final int? texture;

  /// Raw legacy avatar-user permission name.
  final String? allowedUserName;

  /// Raw legacy violent-usage permission name.
  ///
  /// The field spelling intentionally matches the VRM 0.x schema.
  final String? violentUssageName;

  /// Raw legacy sexual-usage permission name.
  ///
  /// The field spelling intentionally matches the VRM 0.x schema.
  final String? sexualUssageName;

  /// Raw legacy commercial-usage permission name.
  ///
  /// The field spelling intentionally matches the VRM 0.x schema.
  final String? commercialUssageName;

  /// URL for additional usage permissions.
  final String? otherPermissionUrl;

  /// Raw legacy redistribution or modification license name.
  final String? licenseName;

  /// URL for a license not represented by [licenseName].
  final String? otherLicenseUrl;

  /// Original legacy metadata JSON object.
  final Map<String, Object?> raw;
}

/// Legacy VRM 0.x humanoid configuration.
final class Vrm0Humanoid {
  Vrm0Humanoid._({
    required List<Vrm0HumanBone> humanBones,
    required this.armStretch,
    required this.legStretch,
    required this.upperArmTwist,
    required this.lowerArmTwist,
    required this.upperLegTwist,
    required this.lowerLegTwist,
    required this.feetSpacing,
    required this.hasTranslationDoF,
    required Map<String, Object?> raw,
  }) : humanBones = List.unmodifiable(humanBones),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Humanoid bone assignments in source array order.
  final List<Vrm0HumanBone> humanBones;

  /// Unity humanoid arm-stretch setting.
  final double? armStretch;

  /// Unity humanoid leg-stretch setting.
  final double? legStretch;

  /// Unity humanoid upper-arm twist setting.
  final double? upperArmTwist;

  /// Unity humanoid lower-arm twist setting.
  final double? lowerArmTwist;

  /// Unity humanoid upper-leg twist setting.
  final double? upperLegTwist;

  /// Unity humanoid lower-leg twist setting.
  final double? lowerLegTwist;

  /// Unity humanoid feet-spacing setting.
  final double? feetSpacing;

  /// Whether the legacy Unity humanoid allows translation degrees of freedom.
  final bool? hasTranslationDoF;

  /// Original legacy humanoid JSON object.
  final Map<String, Object?> raw;
}

/// One legacy VRM 0.x humanoid bone assignment.
final class Vrm0HumanBone {
  Vrm0HumanBone._({
    required this.sourceIndex,
    required this.bone,
    required this.normalizedBone,
    required this.node,
    required this.useDefaultValues,
    required this.min,
    required this.max,
    required this.center,
    required this.axisLength,
    required Map<String, Object?> raw,
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Index of this entry in the source `humanBones` array.
  final int sourceIndex;

  /// Raw VRM 0.x humanoid bone name.
  final String? bone;

  /// Corresponding normalized VRM humanoid bone, when recognized.
  final VrmHumanoidBone? normalizedBone;

  /// Assigned glTF node index.
  final int? node;

  /// Unity `HumanLimit.useDefaultValues` setting.
  final bool? useDefaultValues;

  /// Unity `HumanLimit.min` vector.
  final VrmVector3? min;

  /// Unity `HumanLimit.max` vector.
  final VrmVector3? max;

  /// Unity `HumanLimit.center` vector.
  final VrmVector3? center;

  /// Unity `HumanLimit.axisLength` setting.
  final double? axisLength;

  /// Original legacy humanoid-bone JSON object.
  final Map<String, Object?> raw;
}

/// Legacy VRM 0.x first-person and gaze configuration.
final class Vrm0FirstPerson {
  Vrm0FirstPerson._({
    required this.firstPersonBone,
    required this.firstPersonBoneOffset,
    required List<Vrm0MeshAnnotation> meshAnnotations,
    required this.lookAtTypeName,
    required this.lookAtHorizontalInner,
    required this.lookAtHorizontalOuter,
    required this.lookAtVerticalDown,
    required this.lookAtVerticalUp,
    required Map<String, Object?> raw,
  }) : meshAnnotations = List.unmodifiable(meshAnnotations),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// glTF node used as the first-person reference bone.
  final int? firstPersonBone;

  /// HMD and gaze offset from [firstPersonBone].
  final VrmVector3? firstPersonBoneOffset;

  /// Per-mesh visibility annotations in source array order.
  final List<Vrm0MeshAnnotation> meshAnnotations;

  /// Raw legacy gaze controller type name, such as `Bone` or `BlendShape`.
  final String? lookAtTypeName;

  /// Horizontal inner-eye gaze mapping.
  final Vrm0DegreeMap? lookAtHorizontalInner;

  /// Horizontal outer-eye gaze mapping.
  final Vrm0DegreeMap? lookAtHorizontalOuter;

  /// Downward gaze mapping.
  final Vrm0DegreeMap? lookAtVerticalDown;

  /// Upward gaze mapping.
  final Vrm0DegreeMap? lookAtVerticalUp;

  /// Original legacy first-person JSON object.
  final Map<String, Object?> raw;
}

/// One legacy VRM 0.x first-person mesh annotation.
final class Vrm0MeshAnnotation {
  Vrm0MeshAnnotation._({
    required this.sourceIndex,
    required this.mesh,
    required this.firstPersonFlag,
    required Map<String, Object?> raw,
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Index of this entry in the source `meshAnnotations` array.
  final int sourceIndex;

  /// Target glTF mesh index.
  final int? mesh;

  /// Raw legacy visibility flag.
  final String? firstPersonFlag;

  /// Original legacy mesh-annotation JSON object.
  final Map<String, Object?> raw;
}

/// Legacy VRM 0.x gaze degree map.
final class Vrm0DegreeMap {
  Vrm0DegreeMap._({
    required List<double> curve,
    required this.xRange,
    required this.yRange,
    required Map<String, Object?> raw,
  }) : curve = List.unmodifiable(curve),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Serialized legacy animation-curve values.
  final List<double> curve;

  /// Input clamp range in degrees.
  final double? xRange;

  /// Output range produced from [xRange].
  final double? yRange;

  /// Original legacy degree-map JSON object.
  final Map<String, Object?> raw;
}

/// Legacy VRM 0.x blend-shape expression collection.
final class Vrm0BlendShapeMaster {
  Vrm0BlendShapeMaster._({
    required List<Vrm0BlendShapeGroup> blendShapeGroups,
    required Map<String, Object?> raw,
  }) : blendShapeGroups = List.unmodifiable(blendShapeGroups),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Blend-shape groups in source array order.
  final List<Vrm0BlendShapeGroup> blendShapeGroups;

  /// Original legacy blend-shape-master JSON object.
  final Map<String, Object?> raw;
}

/// One legacy VRM 0.x blend-shape expression group.
final class Vrm0BlendShapeGroup {
  Vrm0BlendShapeGroup._({
    required this.sourceIndex,
    required this.name,
    required this.presetName,
    required List<Vrm0BlendShapeBind> binds,
    required List<Vrm0MaterialValueBind> materialValues,
    required this.isBinary,
    required Map<String, Object?> raw,
  }) : binds = List.unmodifiable(binds),
       materialValues = List.unmodifiable(materialValues),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Index of this entry in the source `blendShapeGroups` array.
  final int sourceIndex;

  /// Custom or display name of the expression group.
  final String? name;

  /// Raw legacy preset name.
  final String? presetName;

  /// Morph-target bindings in source array order.
  final List<Vrm0BlendShapeBind> binds;

  /// Material-value bindings in source array order.
  final List<Vrm0MaterialValueBind> materialValues;

  /// Whether the expression permits only binary output values.
  final bool? isBinary;

  /// Original legacy blend-shape-group JSON object.
  final Map<String, Object?> raw;
}

/// One legacy VRM 0.x morph-target binding.
final class Vrm0BlendShapeBind {
  Vrm0BlendShapeBind._({
    required this.sourceIndex,
    required this.mesh,
    required this.index,
    required this.weight,
    required Map<String, Object?> raw,
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Index of this entry in its source `binds` array.
  final int sourceIndex;

  /// Target glTF mesh index.
  final int? mesh;

  /// Target morph index.
  final int? index;

  /// Legacy morph weight in the range `0` to `100`.
  final double? weight;

  /// Original legacy blend-shape-bind JSON object.
  final Map<String, Object?> raw;
}

/// One legacy VRM 0.x expression material-value binding.
final class Vrm0MaterialValueBind {
  Vrm0MaterialValueBind._({
    required this.sourceIndex,
    required this.materialName,
    required this.propertyName,
    required List<double> targetValue,
    required Map<String, Object?> raw,
  }) : targetValue = List.unmodifiable(targetValue),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Index of this entry in its source `materialValues` array.
  final int sourceIndex;

  /// Name of the target material.
  final String? materialName;

  /// Raw Unity shader property name.
  final String? propertyName;

  /// Property target value.
  final List<double> targetValue;

  /// Original legacy material-value-bind JSON object.
  final Map<String, Object?> raw;
}

/// Legacy VRM 0.x secondary-animation configuration.
final class Vrm0SecondaryAnimation {
  Vrm0SecondaryAnimation._({
    required List<Vrm0SpringBoneGroup> boneGroups,
    required List<Vrm0ColliderGroup> colliderGroups,
    required Map<String, Object?> raw,
  }) : boneGroups = List.unmodifiable(boneGroups),
       colliderGroups = List.unmodifiable(colliderGroups),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Spring-bone groups in source array order.
  final List<Vrm0SpringBoneGroup> boneGroups;

  /// Collider groups in source array order.
  final List<Vrm0ColliderGroup> colliderGroups;

  /// Original legacy secondary-animation JSON object.
  final Map<String, Object?> raw;
}

/// One legacy VRM 0.x spring-bone group.
final class Vrm0SpringBoneGroup {
  Vrm0SpringBoneGroup._({
    required this.sourceIndex,
    required this.comment,
    required this.stiffiness,
    required this.gravityPower,
    required this.gravityDir,
    required this.dragForce,
    required this.center,
    required this.hitRadius,
    required List<int> bones,
    required List<int> boneSourceIndices,
    required List<int> colliderGroups,
    required List<int> colliderGroupSourceIndices,
    required Map<String, Object?> raw,
  }) : bones = List.unmodifiable(bones),
       boneSourceIndices = List.unmodifiable(boneSourceIndices),
       colliderGroups = List.unmodifiable(colliderGroups),
       colliderGroupSourceIndices = List.unmodifiable(
         colliderGroupSourceIndices,
       ),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Index of this entry in the source `boneGroups` array.
  final int sourceIndex;

  /// Optional source annotation.
  final String? comment;

  /// Legacy spring stiffness.
  ///
  /// The field spelling intentionally matches the VRM 0.x schema.
  final double? stiffiness;

  /// Gravity strength.
  final double? gravityPower;

  /// Gravity direction.
  final VrmVector3? gravityDir;

  /// Verlet drag factor.
  final double? dragForce;

  /// Optional center glTF node index.
  final int? center;

  /// Collision radius for joints in this group.
  final double? hitRadius;

  /// Spring root glTF node indices.
  final List<int> bones;

  /// Source-array index corresponding to each entry in [bones].
  final List<int> boneSourceIndices;

  /// Referenced legacy collider-group indices.
  final List<int> colliderGroups;

  /// Source-array index corresponding to each entry in [colliderGroups].
  final List<int> colliderGroupSourceIndices;

  /// Original legacy spring-bone-group JSON object.
  final Map<String, Object?> raw;
}

/// One legacy VRM 0.x collider group.
final class Vrm0ColliderGroup {
  Vrm0ColliderGroup._({
    required this.sourceIndex,
    required this.node,
    required List<Vrm0Collider> colliders,
    required Map<String, Object?> raw,
  }) : colliders = List.unmodifiable(colliders),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Index of this entry in the source `colliderGroups` array.
  final int sourceIndex;

  /// glTF node that owns this collider group.
  final int? node;

  /// Sphere colliders in source array order.
  final List<Vrm0Collider> colliders;

  /// Original legacy collider-group JSON object.
  final Map<String, Object?> raw;
}

/// One legacy VRM 0.x sphere collider.
final class Vrm0Collider {
  Vrm0Collider._({
    required this.sourceIndex,
    required this.offset,
    required this.radius,
    required Map<String, Object?> raw,
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Index of this entry in its source `colliders` array.
  final int sourceIndex;

  /// Collider offset in the legacy left-handed node-local coordinates.
  final VrmVector3? offset;

  /// Sphere radius.
  final double? radius;

  /// Original legacy collider JSON object.
  final Map<String, Object?> raw;
}

/// One legacy VRM 0.x material property entry.
final class Vrm0MaterialProperty {
  Vrm0MaterialProperty._({
    required this.name,
    required this.shader,
    required this.renderQueue,
    required Map<String, double> floatProperties,
    required Map<String, List<double>> vectorProperties,
    required Map<String, int> textureProperties,
    required Map<String, bool> keywordMap,
    required Map<String, String> tagMap,
    required Map<String, Object?> raw,
  }) : floatProperties = Map.unmodifiable(floatProperties),
       vectorProperties = Map.unmodifiable({
         for (final entry in vectorProperties.entries)
           entry.key: List<double>.unmodifiable(entry.value),
       }),
       textureProperties = Map.unmodifiable(textureProperties),
       keywordMap = Map.unmodifiable(keywordMap),
       tagMap = Map.unmodifiable(tagMap),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Source material name.
  final String? name;

  /// Source Unity shader name.
  final String? shader;

  /// Source Unity render queue.
  final int? renderQueue;

  /// Scalar shader properties by raw Unity property name.
  final Map<String, double> floatProperties;

  /// Vector shader properties by raw Unity property name.
  final Map<String, List<double>> vectorProperties;

  /// Texture indices by raw Unity property name.
  final Map<String, int> textureProperties;

  /// Shader keyword states by raw Unity keyword name.
  final Map<String, bool> keywordMap;

  /// Shader tags by raw Unity tag name.
  final Map<String, String> tagMap;

  /// Original legacy material-property JSON object.
  final Map<String, Object?> raw;
}
