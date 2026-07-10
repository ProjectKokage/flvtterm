part of '../flvtterm.dart';

/// VRM 1.0 humanoid bone names.
enum VrmHumanoidBone {
  /// Hips bone.
  hips('hips', true),

  /// Spine bone.
  spine('spine', true),

  /// Chest bone.
  chest('chest', false),

  /// Upper chest bone.
  upperChest('upperChest', false),

  /// Neck bone.
  neck('neck', false),

  /// Head bone.
  head('head', true),

  /// Left eye bone.
  leftEye('leftEye', false),

  /// Right eye bone.
  rightEye('rightEye', false),

  /// Jaw bone.
  jaw('jaw', false),

  /// Left upper leg bone.
  leftUpperLeg('leftUpperLeg', true),

  /// Left lower leg bone.
  leftLowerLeg('leftLowerLeg', true),

  /// Left foot bone.
  leftFoot('leftFoot', true),

  /// Left toes bone.
  leftToes('leftToes', false),

  /// Right upper leg bone.
  rightUpperLeg('rightUpperLeg', true),

  /// Right lower leg bone.
  rightLowerLeg('rightLowerLeg', true),

  /// Right foot bone.
  rightFoot('rightFoot', true),

  /// Right toes bone.
  rightToes('rightToes', false),

  /// Left shoulder bone.
  leftShoulder('leftShoulder', false),

  /// Left upper arm bone.
  leftUpperArm('leftUpperArm', true),

  /// Left lower arm bone.
  leftLowerArm('leftLowerArm', true),

  /// Left hand bone.
  leftHand('leftHand', true),

  /// Right shoulder bone.
  rightShoulder('rightShoulder', false),

  /// Right upper arm bone.
  rightUpperArm('rightUpperArm', true),

  /// Right lower arm bone.
  rightLowerArm('rightLowerArm', true),

  /// Right hand bone.
  rightHand('rightHand', true),

  /// Left thumb metacarpal bone.
  leftThumbMetacarpal('leftThumbMetacarpal', false),

  /// Left thumb proximal bone.
  leftThumbProximal('leftThumbProximal', false),

  /// Left thumb distal bone.
  leftThumbDistal('leftThumbDistal', false),

  /// Left index proximal bone.
  leftIndexProximal('leftIndexProximal', false),

  /// Left index intermediate bone.
  leftIndexIntermediate('leftIndexIntermediate', false),

  /// Left index distal bone.
  leftIndexDistal('leftIndexDistal', false),

  /// Left middle proximal bone.
  leftMiddleProximal('leftMiddleProximal', false),

  /// Left middle intermediate bone.
  leftMiddleIntermediate('leftMiddleIntermediate', false),

  /// Left middle distal bone.
  leftMiddleDistal('leftMiddleDistal', false),

  /// Left ring proximal bone.
  leftRingProximal('leftRingProximal', false),

  /// Left ring intermediate bone.
  leftRingIntermediate('leftRingIntermediate', false),

  /// Left ring distal bone.
  leftRingDistal('leftRingDistal', false),

  /// Left little proximal bone.
  leftLittleProximal('leftLittleProximal', false),

  /// Left little intermediate bone.
  leftLittleIntermediate('leftLittleIntermediate', false),

  /// Left little distal bone.
  leftLittleDistal('leftLittleDistal', false),

  /// Right thumb metacarpal bone.
  rightThumbMetacarpal('rightThumbMetacarpal', false),

  /// Right thumb proximal bone.
  rightThumbProximal('rightThumbProximal', false),

  /// Right thumb distal bone.
  rightThumbDistal('rightThumbDistal', false),

  /// Right index proximal bone.
  rightIndexProximal('rightIndexProximal', false),

  /// Right index intermediate bone.
  rightIndexIntermediate('rightIndexIntermediate', false),

  /// Right index distal bone.
  rightIndexDistal('rightIndexDistal', false),

  /// Right middle proximal bone.
  rightMiddleProximal('rightMiddleProximal', false),

  /// Right middle intermediate bone.
  rightMiddleIntermediate('rightMiddleIntermediate', false),

  /// Right middle distal bone.
  rightMiddleDistal('rightMiddleDistal', false),

  /// Right ring proximal bone.
  rightRingProximal('rightRingProximal', false),

  /// Right ring intermediate bone.
  rightRingIntermediate('rightRingIntermediate', false),

  /// Right ring distal bone.
  rightRingDistal('rightRingDistal', false),

  /// Right little proximal bone.
  rightLittleProximal('rightLittleProximal', false),

  /// Right little intermediate bone.
  rightLittleIntermediate('rightLittleIntermediate', false),

  /// Right little distal bone.
  rightLittleDistal('rightLittleDistal', false);

  const VrmHumanoidBone(this.specName, this.isRequired);

  /// Raw VRM spec name.
  final String specName;

  /// Whether VRM 1.0 requires this bone.
  final bool isRequired;

  static final Map<String, VrmHumanoidBone> _bySpecName = {
    for (final value in values) value.specName: value,
  };

  /// Looks up a bone by raw VRM spec name.
  static VrmHumanoidBone? fromSpecName(String name) => _bySpecName[name];
}

/// VRM meta avatar permission.
enum VrmMetaAvatarPermission {
  /// Only the author may perform as this avatar.
  onlyAuthor('onlyAuthor'),

  /// Only separately licensed users may perform as this avatar.
  onlySeparatelyLicensedPerson('onlySeparatelyLicensedPerson'),

  /// Anyone may perform as this avatar.
  everyone('everyone');

  const VrmMetaAvatarPermission(this.specName);

  /// Raw VRM spec name.
  final String specName;
}

/// VRM meta commercial usage permission.
enum VrmMetaCommercialUsage {
  /// Personal non-profit use only.
  personalNonProfit('personalNonProfit'),

  /// Personal for-profit use is allowed.
  personalProfit('personalProfit'),

  /// Corporate use is allowed.
  corporation('corporation');

  const VrmMetaCommercialUsage(this.specName);

  /// Raw VRM spec name.
  final String specName;
}

/// VRM meta credit notation requirement.
enum VrmMetaCreditNotation {
  /// Credit notation is required.
  required('required'),

  /// Credit notation is unnecessary.
  unnecessary('unnecessary');

  const VrmMetaCreditNotation(this.specName);

  /// Raw VRM spec name.
  final String specName;
}

/// VRM meta modification permission.
enum VrmMetaModification {
  /// Modification is prohibited.
  prohibited('prohibited'),

  /// Modification is allowed.
  allowModification('allowModification'),

  /// Modification and redistribution are allowed.
  allowModificationRedistribution('allowModificationRedistribution');

  const VrmMetaModification(this.specName);

  /// Raw VRM spec name.
  final String specName;
}

/// VRM 1.0 preset expression names.
enum VrmExpressionPreset {
  /// Happy emotion.
  happy('happy'),

  /// Angry emotion.
  angry('angry'),

  /// Sad emotion.
  sad('sad'),

  /// Relaxed emotion.
  relaxed('relaxed'),

  /// Surprised emotion.
  surprised('surprised'),

  /// A lip-sync viseme.
  aa('aa'),

  /// I lip-sync viseme.
  ih('ih'),

  /// U lip-sync viseme.
  ou('ou'),

  /// E lip-sync viseme.
  ee('ee'),

  /// O lip-sync viseme.
  oh('oh'),

  /// Both-eye blink.
  blink('blink'),

  /// Left-eye blink.
  blinkLeft('blinkLeft'),

  /// Right-eye blink.
  blinkRight('blinkRight'),

  /// Gaze up expression.
  lookUp('lookUp'),

  /// Gaze down expression.
  lookDown('lookDown'),

  /// Gaze left expression.
  lookLeft('lookLeft'),

  /// Gaze right expression.
  lookRight('lookRight'),

  /// Compatibility neutral expression.
  neutral('neutral');

  const VrmExpressionPreset(this.specName);

  /// Raw VRM spec name.
  final String specName;

  static final Map<String, VrmExpressionPreset> _bySpecName = {
    for (final value in values) value.specName: value,
  };

  /// Looks up a preset by raw VRM spec name.
  static VrmExpressionPreset? fromSpecName(String name) => _bySpecName[name];
}

/// High-level emotion expression names.
enum VrmEmotion {
  /// Happy emotion.
  happy(VrmExpressionPreset.happy),

  /// Angry emotion.
  angry(VrmExpressionPreset.angry),

  /// Sad emotion.
  sad(VrmExpressionPreset.sad),

  /// Relaxed emotion.
  relaxed(VrmExpressionPreset.relaxed),

  /// Surprised emotion.
  surprised(VrmExpressionPreset.surprised);

  const VrmEmotion(this.preset);

  /// Matching VRM preset expression.
  final VrmExpressionPreset preset;
}

/// Lip-sync preset convenience names.
enum VrmLipSyncPreset {
  /// A viseme.
  aa('aa'),

  /// I viseme.
  ih('ih'),

  /// U viseme.
  ou('ou'),

  /// E viseme.
  ee('ee'),

  /// O viseme.
  oh('oh');

  const VrmLipSyncPreset(this.specName);

  /// Matching VRM expression preset name.
  final String specName;
}

/// Alias used by high-level lip-sync APIs.
typedef VrmViseme = VrmLipSyncPreset;

/// VRM expression procedural override mode.
enum VrmExpressionOverrideMode {
  /// Do not affect procedural expressions.
  none('none'),

  /// Force affected procedural expressions to zero while active.
  block('block'),

  /// Attenuate affected procedural expressions by this expression weight.
  blend('blend');

  const VrmExpressionOverrideMode(this.specName);

  /// Raw VRM spec name.
  final String specName;

  /// Looks up an override mode by raw spec name.
  static VrmExpressionOverrideMode fromSpecName(String? name) {
    for (final value in values) {
      if (value.specName == name) return value;
    }
    return none;
  }
}

/// VRM first-person mesh annotation type.
enum VrmFirstPersonMeshAnnotationType {
  /// Visible only in third person.
  thirdPersonOnly('thirdPersonOnly'),

  /// Visible only in first person.
  firstPersonOnly('firstPersonOnly'),

  /// Visible in both first and third person.
  both('both'),

  /// Implementation should infer from head skinning.
  auto('auto');

  const VrmFirstPersonMeshAnnotationType(this.specName);

  /// Raw VRM spec name.
  final String specName;

  /// Looks up an annotation type by raw spec name.
  static VrmFirstPersonMeshAnnotationType fromSpecName(String? name) {
    for (final value in values) {
      if (value.specName == name) return value;
    }
    return auto;
  }
}

/// Runtime camera perspective for first-person mesh visibility.
enum VrmFirstPersonView {
  /// VR/HMD-style first-person view.
  firstPerson,

  /// Third-person or external camera view.
  thirdPerson,
}
