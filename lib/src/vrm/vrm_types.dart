part of '../../flvtterm.dart';

/// Runtime-facing VRM extension data normalized from VRM 0.x or VRM 1.0.
final class VrmExtension {
  VrmExtension._({
    required this.sourceVersion,
    required this.specVersion,
    required this.meta,
    required this.humanoid,
    required this.firstPerson,
    required this.expressions,
    required this.lookAt,
    required Map<String, Object?> raw,
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Specification family from which this data was parsed.
  final VrmSourceVersion sourceVersion;

  /// Source extension specification version.
  final String? specVersion;

  /// Model metadata.
  final VrmMeta meta;

  /// Humanoid bone mapping.
  final VrmHumanoid humanoid;

  /// First-person visibility settings.
  final VrmFirstPerson firstPerson;

  /// Expression definitions.
  final VrmExpressions expressions;

  /// LookAt settings.
  final VrmLookAt? lookAt;

  /// Raw extension object, preserved.
  final Map<String, Object?> raw;
}

/// VRM model metadata.
final class VrmMeta {
  VrmMeta._({
    required this.name,
    required this.version,
    required List<String> authors,
    required this.copyrightInformation,
    required this.contactInformation,
    required List<String> references,
    required this.thirdPartyLicenses,
    required this.thumbnailImage,
    required this.licenseUrl,
    required this.avatarPermission,
    required this.allowExcessivelyViolentUsage,
    required this.allowExcessivelySexualUsage,
    required this.commercialUsage,
    required this.allowPoliticalOrReligiousUsage,
    required this.allowAntisocialOrHateUsage,
    required this.creditNotation,
    required this.allowRedistribution,
    required this.modification,
    required this.otherLicenseUrl,
    required Map<String, Object?> raw,
  }) : authors = List.unmodifiable(authors),
       references = List.unmodifiable(references),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Model name.
  final String? name;

  /// Model version.
  final String? version;

  /// Model authors.
  final List<String> authors;

  /// Copyright information.
  final String? copyrightInformation;

  /// Author contact information.
  final String? contactInformation;

  /// References or original works.
  final List<String> references;

  /// Third-party license text.
  final String? thirdPartyLicenses;

  /// glTF image index for the thumbnail.
  final int? thumbnailImage;

  /// License URL.
  final String? licenseUrl;

  /// Who may use the model as an avatar.
  final VrmMetaAvatarPermission avatarPermission;

  /// Whether excessively violent usage is allowed.
  final bool allowExcessivelyViolentUsage;

  /// Whether excessively sexual usage is allowed.
  final bool allowExcessivelySexualUsage;

  /// Commercial usage permission.
  final VrmMetaCommercialUsage commercialUsage;

  /// Whether political or religious usage is allowed.
  final bool allowPoliticalOrReligiousUsage;

  /// Whether antisocial or hate usage is allowed.
  final bool allowAntisocialOrHateUsage;

  /// Credit notation requirement.
  final VrmMetaCreditNotation creditNotation;

  /// Whether redistribution is allowed.
  final bool allowRedistribution;

  /// Modification permission.
  final VrmMetaModification modification;

  /// Other license URL.
  final String? otherLicenseUrl;

  /// Raw meta object, preserved.
  final Map<String, Object?> raw;
}

/// VRM humanoid mapping.
final class VrmHumanoid {
  VrmHumanoid._({
    required Map<VrmHumanoidBone, VrmHumanBone> humanBones,
    required Map<String, Object?> raw,
  }) : humanBones = Map.unmodifiable(humanBones),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Bone assignments by semantic humanoid bone.
  final Map<VrmHumanoidBone, VrmHumanBone> humanBones;

  /// Raw humanoid object, preserved.
  final Map<String, Object?> raw;

  /// Returns the glTF node assigned to [bone], if present.
  int? nodeFor(VrmHumanoidBone bone) => humanBones[bone]?.node;
}

/// One humanoid bone assignment.
final class VrmHumanBone {
  /// Creates a humanoid bone assignment.
  VrmHumanBone({
    required this.bone,
    required this.node,
    Map<String, Object?> raw = const {},
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Semantic humanoid bone.
  final VrmHumanoidBone bone;

  /// Assigned glTF node index.
  final int node;

  /// Raw human bone assignment object, preserved.
  final Map<String, Object?> raw;
}

/// VRM first-person settings.
final class VrmFirstPerson {
  VrmFirstPerson._({
    required this.firstPersonBone,
    required List<VrmFirstPersonMeshAnnotation> meshAnnotations,
    required Map<String, Object?> raw,
  }) : meshAnnotations = List.unmodifiable(meshAnnotations),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Node used for `auto` visibility classification.
  ///
  /// VRM 0.x may declare any node. VRM 1.0 leaves this null and uses the
  /// humanoid head bone.
  final int? firstPersonBone;

  /// Mesh annotation entries.
  final List<VrmFirstPersonMeshAnnotation> meshAnnotations;

  /// Raw first-person object, preserved.
  final Map<String, Object?> raw;

  /// Returns the visibility annotation for [node], defaulting to `auto`.
  VrmFirstPersonMeshAnnotationType typeForNode(int node) {
    for (final annotation in meshAnnotations) {
      if (annotation.node == node) return annotation.type;
    }
    return VrmFirstPersonMeshAnnotationType.auto;
  }
}

/// First-person visibility annotation for a mesh node.
final class VrmFirstPersonMeshAnnotation {
  /// Creates a mesh annotation.
  VrmFirstPersonMeshAnnotation({
    required this.node,
    required this.type,
    Map<String, Object?> raw = const {},
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Target glTF node index.
  final int node;

  /// Visibility policy.
  final VrmFirstPersonMeshAnnotationType type;

  /// Raw mesh annotation object, preserved.
  final Map<String, Object?> raw;
}

/// VRM expression definitions.
final class VrmExpressions {
  VrmExpressions._({
    required Map<VrmExpressionPreset, VrmExpression> preset,
    required Map<String, VrmExpression> custom,
    required Map<String, Object?> raw,
  }) : preset = Map.unmodifiable(preset),
       custom = Map.unmodifiable(custom),
       raw = _immutableJsonValue(raw) as Map<String, Object?>,
       all = Map.unmodifiable({
         for (final entry in preset.entries) entry.key.specName: entry.value,
         ...custom,
       });

  /// Preset expressions.
  final Map<VrmExpressionPreset, VrmExpression> preset;

  /// Custom expressions by custom name.
  final Map<String, VrmExpression> custom;

  /// Raw expressions object, preserved.
  final Map<String, Object?> raw;

  /// All expressions by raw expression name.
  final Map<String, VrmExpression> all;
}

/// One VRM expression definition.
final class VrmExpression {
  VrmExpression._({
    required this.name,
    required this.isBinary,
    required List<VrmMorphTargetBind> morphTargetBinds,
    required List<VrmMaterialColorBind> materialColorBinds,
    required List<VrmTextureTransformBind> textureTransformBinds,
    required this.overrideMouth,
    required this.overrideBlink,
    required this.overrideLookAt,
    required Map<String, Object?> raw,
  }) : morphTargetBinds = List.unmodifiable(morphTargetBinds),
       materialColorBinds = List.unmodifiable(materialColorBinds),
       textureTransformBinds = List.unmodifiable(textureTransformBinds),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Raw expression name.
  final String name;

  /// Whether input weights are thresholded to 0 or 1.
  final bool isBinary;

  /// Morph target binds.
  final List<VrmMorphTargetBind> morphTargetBinds;

  /// Material color binds.
  final List<VrmMaterialColorBind> materialColorBinds;

  /// Texture transform binds.
  final List<VrmTextureTransformBind> textureTransformBinds;

  /// Lip-sync override behavior.
  final VrmExpressionOverrideMode overrideMouth;

  /// Blink override behavior.
  final VrmExpressionOverrideMode overrideBlink;

  /// LookAt-expression override behavior.
  final VrmExpressionOverrideMode overrideLookAt;

  /// Raw expression object, preserved.
  final Map<String, Object?> raw;
}

/// Morph target bind in a VRM expression.
final class VrmMorphTargetBind {
  /// Creates a morph target bind.
  VrmMorphTargetBind({
    required this.node,
    required this.index,
    required this.weight,
    Map<String, Object?> raw = const {},
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Target node index.
  final int node;

  /// Target morph index.
  final int index;

  /// Morph weight at full expression weight.
  final double weight;

  /// Raw bind object, preserved.
  final Map<String, Object?> raw;
}

/// Material color bind in a VRM expression.
final class VrmMaterialColorBind {
  /// Creates a material color bind.
  VrmMaterialColorBind({
    required this.material,
    required this.type,
    required this.targetValue,
    Map<String, Object?> raw = const {},
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Target material index.
  final int material;

  /// VRM material parameter type.
  final String type;

  /// Target color-like value.
  final VrmVector4 targetValue;

  /// Raw bind object, preserved.
  final Map<String, Object?> raw;
}

/// Texture transform bind in a VRM expression.
final class VrmTextureTransformBind {
  /// Creates a texture transform bind.
  VrmTextureTransformBind({
    required this.material,
    required this.scale,
    required this.offset,
    Map<String, Object?> raw = const {},
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Target material index.
  final int material;

  /// Target UV scale.
  final VrmVector2 scale;

  /// Target UV offset.
  final VrmVector2 offset;

  /// Raw bind object, preserved.
  final Map<String, Object?> raw;
}

/// VRM LookAt target type.
enum VrmLookAtType {
  /// Drive eye bones.
  bone('bone'),

  /// Drive gaze expression presets.
  expression('expression');

  const VrmLookAtType(this.specName);

  /// Raw VRM spec name.
  final String specName;

  /// Looks up a LookAt type by raw spec name.
  static VrmLookAtType fromSpecName(String? name) {
    for (final value in values) {
      if (value.specName == name) return value;
    }
    return bone;
  }
}

/// VRM LookAt settings.
final class VrmLookAt {
  VrmLookAt._({
    required this.type,
    required this.originNode,
    required List<double> offsetFromHeadBone,
    required this.rangeMapHorizontalInner,
    required this.rangeMapHorizontalOuter,
    required this.rangeMapVerticalDown,
    required this.rangeMapVerticalUp,
    required Map<String, Object?> raw,
  }) : offsetFromHeadBone = List.unmodifiable(offsetFromHeadBone),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// LookAt target type.
  final VrmLookAtType type;

  /// Optional source node used as the gaze origin.
  ///
  /// This preserves VRM 0.x `firstPersonBone`. When null, the humanoid head is
  /// used as required by VRM 1.0.
  final int? originNode;

  /// Offset from the gaze origin node in that node's local space.
  ///
  /// The origin is the humanoid head for VRM 1.0 and [originNode] when a
  /// legacy VRM 0.x asset declares `firstPersonBone`.
  final List<double> offsetFromHeadBone;

  /// Horizontal inner range map.
  final VrmLookAtRangeMap rangeMapHorizontalInner;

  /// Horizontal outer range map.
  final VrmLookAtRangeMap rangeMapHorizontalOuter;

  /// Vertical down range map.
  final VrmLookAtRangeMap rangeMapVerticalDown;

  /// Vertical up range map.
  final VrmLookAtRangeMap rangeMapVerticalUp;

  /// Raw source container, preserved.
  ///
  /// This is the `lookAt` object for VRM 1.0 and the containing
  /// `firstPerson` object for VRM 0.x.
  final Map<String, Object?> raw;
}

/// VRM LookAt range map.
final class VrmLookAtRangeMap {
  /// Creates a range map.
  VrmLookAtRangeMap({
    required this.inputMaxValue,
    required this.outputScale,
    List<double> curve = const [],
    Map<String, Object?> raw = const {},
  }) : curve = List.unmodifiable(curve),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Max input angle value.
  final double inputMaxValue;

  /// Output scale.
  final double outputScale;

  /// Packed VRM 0.x curve keys as `time, value, inTangent, outTangent`.
  ///
  /// VRM 1.0 range maps are linear and leave this list empty.
  final List<double> curve;

  /// Raw range map object, preserved.
  final Map<String, Object?> raw;
}
