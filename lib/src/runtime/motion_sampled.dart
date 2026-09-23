part of '../../flvtterm.dart';

/// One immutable source-local humanoid sample, before semantic retargeting.
///
/// Rotations use glTF XYZW unit quaternions. [hipsTranslation] is the absolute
/// source hips translation, not a rest delta or a destination/world position.
/// This source owns no expressions, gaze, scales or arbitrary glTF node IDs.
final class VrmHumanoidSample {
  /// Copies and validates the bounded semantic pose.
  VrmHumanoidSample({
    required Map<VrmHumanoidBone, VrmVector4> rotations,
    this.hipsTranslation,
  }) : rotations = Map.unmodifiable(rotations) {
    for (final entry in this.rotations.entries) {
      final q = entry.value;
      final norm = q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w;
      if (entry.key == VrmHumanoidBone.leftEye ||
          entry.key == VrmHumanoidBone.rightEye ||
          !norm.isFinite ||
          (norm - 1).abs() > 1e-3) {
        throw ArgumentError(
          'Sampled humanoid rotations must be finite unit body quaternions.',
        );
      }
    }
    final hips = hipsTranslation;
    if (hips != null &&
        (!hips.x.isFinite || !hips.y.isFinite || !hips.z.isFinite)) {
      throw ArgumentError('Sampled hips translation must be finite.');
    }
  }

  /// Absolute source-local rotations keyed by humanoid semantics.
  final Map<VrmHumanoidBone, VrmVector4> rotations;

  /// Absolute source hips translation, when this sample owns root motion.
  final VrmVector3? hipsTranslation;
}

/// A caller-sampled humanoid source using the same binding and FK math as VRMA.
///
/// [restPose] supplies only immutable source nodes and humanoid assignments;
/// its animation, expression and gaze tracks are never evaluated. It may be a
/// metadata-only VRMA with no animation data. The sampler owns interpolation,
/// streaming buffers and availability. No network, file or queue is owned here.
///
/// The sampler must return a valid pose for each requested time in [duration].
/// Live callers should advance/seek only over available samples and handle
/// underrun before evaluation; this type never extrapolates missing poses.
/// To use an external clock, set motion speed to zero and seek explicitly.
final class VrmSampledHumanoidMotion {
  /// Creates one binding source without copying a clip or per-packet VRMA data.
  VrmSampledHumanoidMotion({
    required this.restPose,
    required this.duration,
    required VrmHumanoidSample Function(double timeSeconds) sample,
  }) : _sample = sample {
    if (duration.inMicroseconds <= 0 || duration.inMicroseconds >= 1 << 53) {
      throw ArgumentError.value(
        duration,
        'duration',
        'Must be positive and exactly representable.',
      );
    }
  }

  /// Immutable source rest nodes and semantic assignments.
  final VrmAnimationAsset restPose;

  /// Exact playable duration; supplied endpoint samples may bracket this time.
  final Duration duration;

  final VrmHumanoidSample Function(double timeSeconds) _sample;

  double get _durationSeconds =>
      duration.inMicroseconds / Duration.microsecondsPerSecond;

  GltfAnimationFrame _evaluate(double timeSeconds) {
    final sample = _sample(timeSeconds);
    final assignments = restPose.animation.humanoid.humanBones;
    final hipsNode = assignments[VrmHumanoidBone.hips]?.node;
    if (sample.hipsTranslation != null && hipsNode == null) {
      throw StateError('Sampled source has no hips assignment.');
    }
    final poses = <int, GltfNodePose>{};
    for (final entry in sample.rotations.entries) {
      final node = assignments[entry.key]?.node;
      if (node == null) {
        throw StateError('Sampled bone is absent from its source rest pose.');
      }
      final q = entry.value;
      poses[node] = GltfNodePose(rotation: [q.x, q.y, q.z, q.w]);
    }
    final hips = sample.hipsTranslation;
    if (hips != null) {
      poses[hipsNode!] = GltfNodePose(
        rotation: poses[hipsNode]?.rotation,
        translation: [hips.x, hips.y, hips.z],
      );
    }
    return GltfAnimationFrame._(nodePoses: poses, morphWeights: const {});
  }
}

/// Sampled humanoid playback through the controller's shared VRMA retargeter.
extension VrmSampledHumanoidPlayback on VrmMotionController {
  /// Plays a sampled source through the ordinary priority, fade and mask owner.
  void playSampledHumanoidMotion(
    VrmSampledHumanoidMotion source, {
    bool loop = false,
    double speed = 1,
    double startTimeSeconds = 0,
    Duration? startTime,
    int priority = 0,
    double hipsTranslationScale = 1,
    Set<int>? nodeMask,
    Set<VrmHumanoidBone>? humanoidMask,
    Duration fadeIn = Duration.zero,
  }) {
    if (_shouldIgnorePlay(priority)) return;
    _prepareSourceReplacement(fadeIn);
    _sampledHumanoid = source;
    _vrmaRetargetPlan = _VrmaRetargetPlan.humanoidOnly(
      model,
      source.restPose,
      destinationRestWorldRotations: _modelRestWorldRotations,
    );
    _startPlayback(
      loop: loop,
      speed: speed,
      startTimeSeconds: _startTimeSeconds(startTime, startTimeSeconds),
      priority: priority,
      nodeMask: nodeMask,
      humanoidMask: humanoidMask,
      fadeIn: fadeIn,
      hipsTranslationScale: hipsTranslationScale,
    );
  }

  _MotionSnapshot _sampledSnapshot(VrmSampledHumanoidMotion source) =>
      _snapshotVrmaFrame(this, source.restPose, source._evaluate(_timeSeconds));
}
