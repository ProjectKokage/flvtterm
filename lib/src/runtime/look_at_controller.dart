import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../math_types.dart';
import '../matrix_math.dart';
import '../safe_list_index.dart';
import '../vrm/vrm_assets.dart';
import '../vrm/vrm_enums.dart';
import '../vrm/vrm_types.dart';
import '../vrm0/vrm_coordinate_convention.dart';
import 'constraint_math.dart';
import 'expression_controller.dart';
import 'look_at_math.dart';
import 'runtime_transform_helpers.dart';
import 'scene_binding.dart';

/// Controls VRM LookAt output for expression or eye-bone models.
final class VrmLookAtController {
  /// Creates a LookAt controller for [model].
  VrmLookAtController(this.model);

  /// Parsed model backing this controller.
  final VrmModel model;

  var _active = false;
  var _yawDegrees = 0.0;
  var _pitchDegrees = 0.0;
  VrmVector3? _targetModel;
  VrmVector3? _targetWorld;
  VrmMatrix4? _modelWorldTransform;
  YawPitch? _motionYawPitch;

  /// Sets LookAt directly from yaw and pitch in degrees.
  void setYawPitch({required double yawDegrees, required double pitchDegrees}) {
    _active = true;
    _targetModel = null;
    _targetWorld = null;
    _modelWorldTransform = null;
    _yawDegrees = yawDegrees;
    _pitchDegrees = pitchDegrees;
  }

  /// Sets a model-space gaze target.
  void lookAtModel(VrmVector3 target) {
    _active = true;
    _targetModel = target;
    _targetWorld = null;
    _modelWorldTransform = null;
  }

  /// Sets a world-space gaze target.
  ///
  /// Pass [modelWorldTransform] when the avatar root is moved or rotated in the
  /// renderer world. If omitted, world space is treated as model space.
  void lookAtWorld(VrmVector3 target, {VrmMatrix4? modelWorldTransform}) {
    _active = true;
    _targetModel = null;
    _targetWorld = target;
    _modelWorldTransform = modelWorldTransform;
  }

  /// Clears the application-set LookAt target or yaw/pitch.
  void clear() {
    _active = false;
    _targetModel = null;
    _targetWorld = null;
    _modelWorldTransform = null;
    _yawDegrees = 0;
    _pitchDegrees = 0;
  }

  /// Sets the gaze direction the playing motion asks for; null clears it.
  @internal
  void setMotionYawPitch(YawPitch? yawPitch) {
    _motionYawPitch = yawPitch;
  }

  VrmMatrix4? _effectiveModelWorldTransform(VrmSceneBinding binding) {
    final rootMotion = binding is VrmModelRootBinding
        ? binding.modelRootMotionTransform
        : null;
    final appTransform = _modelWorldTransform;
    if (appTransform == null) return rootMotion;
    if (rootMotion == null) return appTransform;
    return multiplyMatrices(appTransform, rootMotion);
  }

  /// Applies the current LookAt output.
  void applyTo(VrmSceneBinding binding, VrmExpressionController expressions) {
    final settings = model.vrm.lookAt;
    if (settings == null) {
      expressions.setLookAtInputs(const {});
      return;
    }

    final yawPitch = _active
        ? (_targetModel != null
              ? _yawPitchForTarget(
                  binding,
                  settings,
                  runtimePointToSourceModel(model.sourceVersion, _targetModel!),
                )
              : _targetWorld != null
              ? _yawPitchForTarget(
                  binding,
                  settings,
                  worldTargetToModel(
                    _targetWorld!,
                    _effectiveModelWorldTransform(binding),
                  ),
                )
              : YawPitch(_yawDegrees, _pitchDegrees))
        : _motionYawPitch;
    if (yawPitch == null) {
      expressions.setLookAtInputs(const {});
      return;
    }

    switch (settings.type) {
      case VrmLookAtType.expression:
        expressions.setLookAtInputs(
          _lookAtExpressionWeights(settings, yawPitch),
        );
      case VrmLookAtType.bone:
        expressions.setLookAtInputs(const {});
        _applyBoneLookAt(binding, settings, yawPitch);
    }
  }

  YawPitch _yawPitchForTarget(
    VrmSceneBinding binding,
    VrmLookAt settings,
    VrmVector3 target,
  ) {
    final head =
        settings.originNode ?? model.vrm.humanoid.nodeFor(VrmHumanoidBone.head);
    final local = head == null
        ? target -
              VrmVector3(
                settings.offsetFromHeadBone[0],
                settings.offsetFromHeadBone[1],
                settings.offsetFromHeadBone[2],
              )
        : _targetInLookAtSpace(binding, head, settings, target);
    final runtimeLocal = sourceDirectionToRuntime(model.sourceVersion, local);
    final yaw = math.atan2(runtimeLocal.x, runtimeLocal.z) * 180 / math.pi;
    final xz = math.sqrt(
      runtimeLocal.x * runtimeLocal.x + runtimeLocal.z * runtimeLocal.z,
    );
    final pitch = math.atan2(-runtimeLocal.y, xz) * 180 / math.pi;
    return YawPitch(yaw, pitch);
  }

  VrmVector3 _targetInLookAtSpace(
    VrmSceneBinding binding,
    int head,
    VrmLookAt settings,
    VrmVector3 target,
  ) {
    final headTransform = modelTransformForNode(
      model.gltf,
      head,
      (node) => binding.nodeByGltfIndex(node.index).localTransform,
    );
    if (headTransform == null) return target;
    final offset = VrmVector3(
      settings.offsetFromHeadBone[0],
      settings.offsetFromHeadBone[1],
      settings.offsetFromHeadBone[2],
    );
    final origin = transformPoint(headTransform, offset);
    final restTransform = modelTransformForNode(
      model.gltf,
      head,
      (node) => node.restTransform,
    );
    final currentRotation = matrixRotation(
      headTransform,
      fallback: const [0, 0, 0, 1],
    );
    final restRotation = restTransform == null
        ? const [0.0, 0.0, 0.0, 1.0]
        : matrixRotation(restTransform, fallback: const [0, 0, 0, 1]);
    final lookAtRotation = quatMultiply(
      currentRotation,
      quatInverse(restRotation),
    );
    final delta = target - origin;
    final local = rotateVector(quatInverse(lookAtRotation), [
      delta.x,
      delta.y,
      delta.z,
    ]);
    return VrmVector3(local[0], local[1], local[2]);
  }

  Map<String, double> _lookAtExpressionWeights(
    VrmLookAt settings,
    YawPitch yawPitch,
  ) {
    final weights = <String, double>{
      'lookLeft': 0,
      'lookRight': 0,
      'lookDown': 0,
      'lookUp': 0,
    };
    if (yawPitch.yawDegrees > 0) {
      weights['lookLeft'] = rangeMap(
        yawPitch.yawDegrees.abs(),
        settings.rangeMapHorizontalOuter,
      );
    } else if (yawPitch.yawDegrees < 0) {
      weights['lookRight'] = rangeMap(
        yawPitch.yawDegrees.abs(),
        settings.rangeMapHorizontalOuter,
      );
    }
    if (yawPitch.pitchDegrees > 0) {
      weights['lookDown'] = rangeMap(
        yawPitch.pitchDegrees.abs(),
        settings.rangeMapVerticalDown,
      );
    } else if (yawPitch.pitchDegrees < 0) {
      weights['lookUp'] = rangeMap(
        yawPitch.pitchDegrees.abs(),
        settings.rangeMapVerticalUp,
      );
    }
    return weights;
  }

  void _applyBoneLookAt(
    VrmSceneBinding binding,
    VrmLookAt settings,
    YawPitch yawPitch,
  ) {
    final leftEye = model.vrm.humanoid.nodeFor(VrmHumanoidBone.leftEye);
    final rightEye = model.vrm.humanoid.nodeFor(VrmHumanoidBone.rightEye);
    if (leftEye != null) {
      _applyEyeBone(
        binding,
        leftEye,
        _eyeYaw(
          yawPitch.yawDegrees,
          positiveYawMap: settings.rangeMapHorizontalOuter,
          negativeYawMap: settings.rangeMapHorizontalInner,
        ),
        _eyePitch(yawPitch.pitchDegrees, settings),
      );
    }
    if (rightEye != null) {
      _applyEyeBone(
        binding,
        rightEye,
        _eyeYaw(
          yawPitch.yawDegrees,
          positiveYawMap: settings.rangeMapHorizontalInner,
          negativeYawMap: settings.rangeMapHorizontalOuter,
        ),
        _eyePitch(yawPitch.pitchDegrees, settings),
      );
    }
  }

  void _applyEyeBone(
    VrmSceneBinding binding,
    int nodeIndex,
    double yawDegrees,
    double pitchDegrees,
  ) {
    final node = model.gltf.nodes.elementAtOrNull(nodeIndex);
    if (node == null) return;
    final lookRotation = runtimeRotationToSource(
      model.sourceVersion,
      yawPitchQuaternion(yawDegrees, pitchDegrees),
    );
    final current = binding.nodeByGltfIndex(nodeIndex).localTransform;
    binding.nodeByGltfIndex(nodeIndex).localTransform = trsMatrix(
      matrixTranslation(current),
      quatMultiply(
        matrixRotation(current, fallback: node.restRotation),
        lookRotation,
      ),
      matrixScale(current),
    );
  }

  double _eyeYaw(
    double yawDegrees, {
    required VrmLookAtRangeMap positiveYawMap,
    required VrmLookAtRangeMap negativeYawMap,
  }) {
    if (yawDegrees > 0) return rangeMap(yawDegrees.abs(), positiveYawMap);
    if (yawDegrees < 0) return -rangeMap(yawDegrees.abs(), negativeYawMap);
    return 0;
  }

  double _eyePitch(double pitchDegrees, VrmLookAt settings) {
    if (pitchDegrees > 0) {
      return rangeMap(pitchDegrees.abs(), settings.rangeMapVerticalDown);
    }
    if (pitchDegrees < 0) {
      return -rangeMap(pitchDegrees.abs(), settings.rangeMapVerticalUp);
    }
    return 0;
  }
}
