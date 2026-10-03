part of '../../flvtterm.dart';

/// Plays renderer-neutral motion sources into a runtime binding.
///
/// The active `play*` source is the override layer. Programmatic additive
/// layers can be stacked on top with [addAdditiveProgrammaticPose].
final class VrmMotionController {
  /// Creates a motion controller for [model].
  VrmMotionController(this.model)
    : _evaluator = GltfAnimationEvaluator(model.gltf),
      _modelRestWorldRotations = _restWorldRotations(model.gltf);

  /// Parsed model backing this controller.
  final VrmModel model;

  /// Retargeter used for VRMA and sampled humanoid motion.
  VrmHumanoidRetargeter vrmaRetargeter = const VrmFkHumanoidRetargeter();

  /// Keeps hanging hands clear of the avatar's hips and thighs.
  ///
  /// Joint rotations alone can put a hanging hand inside the thigh of an
  /// avatar whose proportions differ from the motion's. When true, each upper
  /// arm within 60 degrees of hanging down turns outward about the body's
  /// forward axis through the shoulder, by at most 25 degrees, until the
  /// wrist is 3 cm (scaled by height from 1.6 m) beyond the widest skin bound
  /// to the hips or upper legs at hand height, measured once per avatar at
  /// rest. A hand already clear is left alone; the turn fades in between 60
  /// and 30 degrees from hanging, so raised arms keep their joint angles.
  /// Applies to the played VRMA or sampled humanoid motion, not to additive
  /// layers.
  bool keepHandsClear = false;

  final GltfAnimationEvaluator _evaluator;
  final Map<int, List<double>> _modelRestWorldRotations;

  int? _animationIndex;
  VrmAnimationAsset? _vrma;
  VrmSampledHumanoidMotion? _sampledHumanoid;
  VrmProgrammaticPose? _programmaticPose;
  VrmProceduralMotion? _proceduralMotion;
  final _additiveLayers = <_AdditiveMotionLayer>[];
  var _nextAdditiveLayerId = 0;
  GltfAnimationEvaluator? _vrmaEvaluator;
  _VrmaRetargetPlan? _vrmaRetargetPlan;
  GltfAnimationEvaluator? _externalGltfEvaluator;
  Set<int>? _nodeMask;
  var _vrmaHipsTranslationScale = 1.0;
  var _timeSeconds = 0.0;
  var _fadeInSeconds = 0.0;
  var _fadeElapsedSeconds = 0.0;
  var _fadeOutSeconds = 0.0;
  var _fadeOutElapsedSeconds = 0.0;
  _MotionSnapshot? _crossFadeFrom;
  _MotionSnapshot? _fadeOutFrom;
  var _stopping = false;
  var _loop = false;
  var _priority = 0;
  var _paused = false;
  var _playing = false;

  /// Playback speed multiplier.
  double speed = 1.0;

  /// Called once when a non-looping clip reaches its start or end.
  void Function()? onCompleted;

  /// Called once per update when looping playback wraps past either end.
  void Function()? onLooped;

  /// Whether a clip is currently playing.
  bool get isPlaying => _playing;

  /// Whether playback is paused.
  bool get isPaused => _paused;

  /// Current local clip time in seconds.
  double get timeSeconds => _timeSeconds;

  /// Current local clip position.
  Duration get position => _durationFromSeconds(_timeSeconds);

  /// Current clip duration in seconds.
  double get durationSeconds => _activeDurationSeconds;

  /// Current clip duration.
  Duration get duration => _durationFromSeconds(durationSeconds);

  /// Current clip progress in `[0, 1]`.
  double get normalizedProgress {
    final duration = durationSeconds;
    return duration <= 0 ? 0 : _clamp01(_timeSeconds / duration);
  }

  /// Samples only the override source's model-root translation at its current
  /// position. Additive layers and application placement are excluded.
  ///
  /// [blended] includes an in-progress crossfade or release. Set it to false
  /// to inspect the unblended target before rendering, for example for stage
  /// bounds. This evaluates the source callback without advancing its clock;
  /// callers must keep procedural/sampled callbacks deterministic and available.
  VrmVector3? sampleModelRootTranslation({bool blended = true}) {
    if (!blended && _stopping) return null;
    final snapshot = blended ? _captureSnapshot() : _captureRawSnapshot();
    final value = snapshot?.modelRootPose?.translation;
    if (!_hasFiniteLength(value, 3)) return null;
    return VrmVector3(value![0], value[1], value[2]);
  }

  /// Plays any supported motion source through one entry point.
  ///
  /// Pass an [int] for an embedded glTF animation index, a [GltfAsset] for an
  /// external generic glTF animation, a [VrmAnimationAsset] for VRMA,
  /// a [VrmSampledHumanoidMotion] for sampled semantic motion, or a
  /// [VrmProgrammaticPose] for a static pose. A [VrmProceduralMotion] callback
  /// can drive procedural idle or app-owned motion.
  /// [nodeMask] limits transform and morph output to glTF node indices.
  /// [humanoidMask] adds destination nodes for the listed humanoid bones.
  /// Lower-priority play requests are ignored while a higher-priority source
  /// is active.
  void play(
    Object source, {
    int? animationIndex,
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
    if (source is VrmSampledHumanoidMotion) {
      playSampledHumanoidMotion(
        source,
        loop: loop,
        speed: speed,
        startTimeSeconds: startTimeSeconds,
        startTime: startTime,
        priority: priority,
        hipsTranslationScale: hipsTranslationScale,
        nodeMask: nodeMask,
        humanoidMask: humanoidMask,
        fadeIn: fadeIn,
      );
      return;
    }
    if (source is VrmAnimationAsset) {
      playVrmAnimation(
        source,
        animationIndex: animationIndex,
        loop: loop,
        speed: speed,
        startTimeSeconds: startTimeSeconds,
        startTime: startTime,
        priority: priority,
        hipsTranslationScale: hipsTranslationScale,
        nodeMask: nodeMask,
        humanoidMask: humanoidMask,
        fadeIn: fadeIn,
      );
      return;
    }
    if (source is VrmProgrammaticPose) {
      playProgrammaticPose(
        source,
        priority: priority,
        nodeMask: nodeMask,
        humanoidMask: humanoidMask,
        fadeIn: fadeIn,
      );
      return;
    }
    if (source is VrmProceduralMotion) {
      playProceduralMotion(
        source,
        speed: speed,
        startTimeSeconds: startTimeSeconds,
        startTime: startTime,
        priority: priority,
        nodeMask: nodeMask,
        humanoidMask: humanoidMask,
        fadeIn: fadeIn,
      );
      return;
    }
    if (source is GltfAsset) {
      if (source.animations.isEmpty) {
        throw StateError('glTF asset does not contain animations.');
      }
      final index = animationIndex ?? 0;
      playGltfAnimation(
        source,
        index,
        loop: loop,
        speed: speed,
        startTimeSeconds: startTimeSeconds,
        startTime: startTime,
        priority: priority,
        nodeMask: nodeMask,
        humanoidMask: humanoidMask,
        fadeIn: fadeIn,
      );
      return;
    }
    if (source is int) {
      playEmbeddedGltfAnimation(
        source,
        loop: loop,
        speed: speed,
        startTimeSeconds: startTimeSeconds,
        startTime: startTime,
        priority: priority,
        nodeMask: nodeMask,
        humanoidMask: humanoidMask,
        fadeIn: fadeIn,
      );
      return;
    }
    throw ArgumentError.value(
      source,
      'source',
      'Expected int, GltfAsset, VrmAnimationAsset, VrmSampledHumanoidMotion, VrmProgrammaticPose, or VrmProceduralMotion.',
    );
  }

  /// Plays an embedded glTF animation clip by index.
  ///
  /// [nodeMask] limits transform and morph output to glTF node indices.
  /// [humanoidMask] adds destination nodes for the listed humanoid bones.
  /// Lower-priority play requests are ignored while a higher-priority source
  /// is active.
  void playEmbeddedGltfAnimation(
    int animationIndex, {
    bool loop = false,
    double speed = 1,
    double startTimeSeconds = 0,
    Duration? startTime,
    int priority = 0,
    Set<int>? nodeMask,
    Set<VrmHumanoidBone>? humanoidMask,
    Duration fadeIn = Duration.zero,
  }) {
    if (_shouldIgnorePlay(priority)) return;
    if (model.gltf.animations.isEmpty) {
      throw StateError('VRM model does not contain embedded glTF animations.');
    }
    if (animationIndex < 0 || animationIndex >= model.gltf.animations.length) {
      throw RangeError.range(
        animationIndex,
        0,
        model.gltf.animations.length - 1,
        'animationIndex',
      );
    }
    _prepareSourceReplacement(fadeIn);
    _animationIndex = animationIndex;
    _startPlayback(
      loop: loop,
      speed: speed,
      startTimeSeconds: _startTimeSeconds(startTime, startTimeSeconds),
      priority: priority,
      nodeMask: nodeMask,
      humanoidMask: humanoidMask,
      fadeIn: fadeIn,
    );
  }

  /// Plays a VRM Animation asset through humanoid semantic retargeting.
  ///
  /// [nodeMask] limits retargeted transform output to destination glTF nodes.
  /// [humanoidMask] adds destination nodes for the listed humanoid bones.
  /// Lower-priority play requests are ignored while a higher-priority source
  /// is active.
  void playVrmAnimation(
    VrmAnimationAsset animation, {
    int? animationIndex,
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
    final index = animationIndex ?? animation.defaultAnimationIndex;
    if (index == null) {
      throw StateError('VRMA asset does not contain glTF animations.');
    }
    if (index < 0 || index >= animation.gltf.animations.length) {
      throw RangeError.range(
        index,
        0,
        animation.gltf.animations.length - 1,
        'animationIndex',
      );
    }
    _prepareSourceReplacement(fadeIn);
    _animationIndex = index;
    _vrma = animation;
    _vrmaEvaluator = GltfAnimationEvaluator(animation.gltf);
    _vrmaRetargetPlan = _VrmaRetargetPlan(
      model,
      animation,
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

  /// Plays an external generic glTF animation clip by matching glTF node index.
  ///
  /// [nodeMask] limits transform and morph output to glTF node indices.
  /// [humanoidMask] adds destination nodes for the listed humanoid bones.
  /// Lower-priority play requests are ignored while a higher-priority source
  /// is active.
  void playGltfAnimation(
    GltfAsset animationAsset,
    int animationIndex, {
    bool loop = false,
    double speed = 1,
    double startTimeSeconds = 0,
    Duration? startTime,
    int priority = 0,
    Set<int>? nodeMask,
    Set<VrmHumanoidBone>? humanoidMask,
    Duration fadeIn = Duration.zero,
  }) {
    if (_shouldIgnorePlay(priority)) return;
    if (animationAsset.animations.isEmpty) {
      throw StateError('glTF asset does not contain animations.');
    }
    if (animationIndex < 0 ||
        animationIndex >= animationAsset.animations.length) {
      throw RangeError.range(
        animationIndex,
        0,
        animationAsset.animations.length - 1,
        'animationIndex',
      );
    }
    _prepareSourceReplacement(fadeIn);
    _animationIndex = animationIndex;
    _externalGltfEvaluator = GltfAnimationEvaluator(animationAsset);
    _startPlayback(
      loop: loop,
      speed: speed,
      startTimeSeconds: _startTimeSeconds(startTime, startTimeSeconds),
      priority: priority,
      nodeMask: nodeMask,
      humanoidMask: humanoidMask,
      fadeIn: fadeIn,
    );
  }

  /// Plays a static programmatic pose.
  ///
  /// [nodeMask] limits transform and morph output to glTF node indices.
  /// [humanoidMask] adds destination nodes for the listed humanoid bones.
  /// Lower-priority play requests are ignored while a higher-priority source
  /// is active.
  void playProgrammaticPose(
    VrmProgrammaticPose pose, {
    int priority = 0,
    Set<int>? nodeMask,
    Set<VrmHumanoidBone>? humanoidMask,
    Duration fadeIn = Duration.zero,
  }) {
    if (_shouldIgnorePlay(priority)) return;
    _prepareSourceReplacement(fadeIn);
    _programmaticPose = pose;
    _startPlayback(
      loop: false,
      speed: 0,
      startTimeSeconds: 0,
      priority: priority,
      nodeMask: nodeMask,
      humanoidMask: humanoidMask,
      fadeIn: fadeIn,
    );
  }

  /// Plays a procedural pose callback, useful for idle or app-owned motion.
  ///
  /// The callback receives local motion time in seconds. [nodeMask] limits
  /// transform and morph output to glTF node indices. [humanoidMask] adds
  /// destination nodes for the listed humanoid bones. Lower-priority play
  /// requests are ignored while a higher-priority source is active.
  void playProceduralMotion(
    VrmProceduralMotion motion, {
    double speed = 1,
    double startTimeSeconds = 0,
    Duration? startTime,
    int priority = 0,
    Set<int>? nodeMask,
    Set<VrmHumanoidBone>? humanoidMask,
    Duration fadeIn = Duration.zero,
  }) {
    if (_shouldIgnorePlay(priority)) return;
    _prepareSourceReplacement(fadeIn);
    _proceduralMotion = motion;
    _startPlayback(
      loop: false,
      speed: speed,
      startTimeSeconds: _startTimeSeconds(startTime, startTimeSeconds),
      priority: priority,
      nodeMask: nodeMask,
      humanoidMask: humanoidMask,
      fadeIn: fadeIn,
    );
  }

  /// Stops playback and clears the active clip.
  void stop({Duration fadeOut = Duration.zero}) {
    if (fadeOut > Duration.zero && _hasActiveSource) {
      _fadeOutFrom = _captureSnapshot();
      _crossFadeFrom = null;
      _fadeOutSeconds = fadeOut.inMicroseconds / Duration.microsecondsPerSecond;
      _fadeOutElapsedSeconds = 0;
      _stopping = true;
      _playing = true;
      _paused = false;
      return;
    }
    _clearActiveClip();
  }

  /// Replaces programmatic additive layers with one programmatic pose.
  ///
  /// Translation and morph values are added as deltas; rotation is applied as
  /// a local delta; scale is multiplied from identity; expression weights are
  /// added and clamped. The additive layer remains active until cleared.
  void setAdditiveProgrammaticPose(
    VrmProgrammaticPose? pose, {
    double weight = 1,
  }) {
    clearAdditiveProgrammaticPose();
    if (pose != null) addAdditiveProgrammaticPose(pose, weight: weight);
  }

  /// Adds a programmatic additive pose layer.
  void addAdditiveProgrammaticPose(
    VrmProgrammaticPose pose, {
    double weight = 1,
  }) {
    addAdditiveLayer(pose, weight: weight);
  }

  /// Clears all additive programmatic pose layers.
  void clearAdditiveProgrammaticPose() {
    _additiveLayers.removeWhere((layer) => layer.source is VrmProgrammaticPose);
  }

  void _clearActiveClip() {
    _clearActiveSource();
    _timeSeconds = 0;
    _fadeInSeconds = 0;
    _fadeElapsedSeconds = 0;
    _fadeOutSeconds = 0;
    _fadeOutElapsedSeconds = 0;
    _crossFadeFrom = null;
    _fadeOutFrom = null;
    _stopping = false;
    _priority = 0;
    _playing = false;
    _paused = false;
  }

  void _clearActiveSource() {
    _animationIndex = null;
    _vrma = null;
    _sampledHumanoid = null;
    _programmaticPose = null;
    _proceduralMotion = null;
    _vrmaEvaluator = null;
    _vrmaRetargetPlan = null;
    _externalGltfEvaluator = null;
    _nodeMask = null;
    _vrmaHipsTranslationScale = 1;
  }

  void _startPlayback({
    required bool loop,
    required double speed,
    required double startTimeSeconds,
    required int priority,
    required Set<int>? nodeMask,
    required Set<VrmHumanoidBone>? humanoidMask,
    required Duration fadeIn,
    double hipsTranslationScale = 1,
  }) {
    _nodeMask = _resolveNodeMask(nodeMask, humanoidMask);
    _vrmaHipsTranslationScale = hipsTranslationScale.isFinite
        ? hipsTranslationScale
        : 1;
    _loop = loop;
    this.speed = _finiteOrZero(speed);
    _priority = priority;
    _timeSeconds = startTimeSeconds;
    _startFade(fadeIn);
    _paused = false;
    _playing = true;
    if (_animationIndex != null || _sampledHumanoid != null) _clampOrWrapTime();
  }

  /// Pauses playback.
  void pause() {
    if (_playing || _additiveLayers.isNotEmpty) _paused = true;
  }

  /// Resumes playback.
  void resume() {
    if (_playing || _additiveLayers.isNotEmpty) _paused = false;
  }

  /// Seeks the active clip.
  void seek(Duration position) {
    _timeSeconds = position.inMicroseconds / Duration.microsecondsPerSecond;
    if (_proceduralMotion != null) return;
    _clampOrWrapTime();
  }

  /// Advances playback time.
  void update(double deltaSeconds) {
    if (_paused) return;
    final dt = deltaSeconds.isFinite ? math.max(0.0, deltaSeconds) : 0.0;
    _updateAdditiveLayers(dt);
    if (!_playing || !_hasActiveSource) return;
    if (_stopping) {
      _fadeOutElapsedSeconds += dt;
      _clearIfFadeOutFinished();
      return;
    }
    _fadeElapsedSeconds += dt;
    if (_animationIndex == null &&
        _proceduralMotion == null &&
        _sampledHumanoid == null) {
      return;
    }
    _timeSeconds += dt * _finiteOrZero(speed);
    if (_proceduralMotion != null) return;
    _clampOrWrapTime(stopAtEnds: true, emitLoopEvent: true);
  }

  /// Applies the current animation frame to [binding].
  void applyTo(
    VrmSceneBinding binding,
    VrmExpressionController expressions,
    VrmLookAtController lookAt,
  ) {
    _evaluateAdditiveLayers();
    if (_stopping && _fadeOutFrom != null) {
      _applyFadeOutSnapshot(binding, expressions, lookAt);
      return;
    }
    final sampled = _sampledHumanoid;
    if (sampled != null) {
      _applyHumanoidMotionSnapshot(
        this,
        binding,
        expressions,
        lookAt,
        _sampledSnapshot(sampled),
      );
      return;
    }
    final animationIndex = _animationIndex;
    final programmaticPose = _programmaticPose;
    final proceduralMotion = _proceduralMotion;
    if (animationIndex == null &&
        programmaticPose == null &&
        proceduralMotion == null) {
      expressions._setMotionInputs(_additiveMotionInputs(const {}));
      lookAt._setMotionYawPitch(_additiveLookAt(null));
      _applyMorphWeights(binding, const {}, 1);
      _applyAdditiveNodePoses(binding);
      _applyModelRootPose(binding, null, 1);
      _clearFinishedCrossFade();
      return;
    }
    if (programmaticPose != null) {
      _applyProgrammaticPose(binding, expressions, lookAt, programmaticPose);
      return;
    }
    if (proceduralMotion != null) {
      _applyProgrammaticPose(
        binding,
        expressions,
        lookAt,
        proceduralMotion(_timeSeconds),
      );
      return;
    }
    final activeAnimationIndex = animationIndex!;
    final vrma = _vrma;
    if (vrma != null) {
      _applyVrmaMotion(
        this,
        binding,
        expressions,
        lookAt,
        vrma,
        activeAnimationIndex,
      );
      return;
    }
    final evaluator = _externalGltfEvaluator ?? _evaluator;
    final frame = evaluator.evaluate(activeAnimationIndex, _timeSeconds);
    final fade = _fadeWeight;

    expressions._setMotionInputs(
      _additiveMotionInputs(_blendMotionInputs(const {}, fade)),
    );
    lookAt._setMotionYawPitch(_additiveLookAt(_blendLookAt(null, fade)));
    _applyNodePoses(
      binding,
      frame.nodePoses,
      fade,
      from: _crossFadeFrom?.nodePoses,
    );
    _applyMorphWeights(
      binding,
      frame.morphWeights,
      fade,
      from: _crossFadeFrom?.morphWeights,
    );
    _applyAdditiveNodePoses(binding);
    _applyModelRootPose(
      binding,
      null,
      fade,
      from: _crossFadeFrom?.modelRootPose,
    );
    _clearFinishedCrossFade();
  }

  double get _activeDurationSeconds {
    final sampled = _sampledHumanoid;
    if (sampled != null) return sampled._durationSeconds;
    final animationIndex = _animationIndex;
    if (animationIndex == null) return 0;
    final evaluator = _vrmaEvaluator ?? _externalGltfEvaluator ?? _evaluator;
    return evaluator.duration(animationIndex);
  }

  void _clampOrWrapTime({bool stopAtEnds = false, bool emitLoopEvent = false}) {
    final duration = durationSeconds;
    if (duration <= 0) {
      _timeSeconds = 0;
      return;
    }
    if (_loop) {
      final wrapped = _timeSeconds >= duration || _timeSeconds < 0;
      _timeSeconds %= duration;
      if (_timeSeconds < 0) _timeSeconds += duration;
      if (emitLoopEvent && wrapped) onLooped?.call();
      return;
    }
    if (_timeSeconds < 0 || (stopAtEnds && speed < 0 && _timeSeconds <= 0)) {
      _timeSeconds = 0;
      if (stopAtEnds) _completePlayback();
    } else if (_timeSeconds > duration ||
        (stopAtEnds && speed > 0 && _timeSeconds >= duration)) {
      _timeSeconds = duration;
      if (stopAtEnds) _completePlayback();
    }
  }

  void _completePlayback() {
    if (!_playing) return;
    _playing = false;
    onCompleted?.call();
  }

  void _startFade(Duration fadeIn) {
    _fadeInSeconds = math.max(
      0.0,
      fadeIn.inMicroseconds / Duration.microsecondsPerSecond,
    );
    _fadeElapsedSeconds = 0;
    _fadeOutSeconds = 0;
    _fadeOutElapsedSeconds = 0;
    _fadeOutFrom = null;
    _stopping = false;
  }

  void _prepareSourceReplacement(Duration fadeIn) {
    _crossFadeFrom = fadeIn > Duration.zero ? _captureSnapshot() : null;
    _clearActiveSource();
  }

  double get _fadeWeight => _fadeInSeconds == 0
      ? 1.0
      : _clamp01(_fadeElapsedSeconds / _fadeInSeconds);

  double get _fadeOutProgress => _fadeOutSeconds == 0
      ? 1
      : _clamp01(_fadeOutElapsedSeconds / _fadeOutSeconds);

  void _clearIfFadeOutFinished() {
    if (_stopping && _fadeOutElapsedSeconds >= _fadeOutSeconds) {
      _clearActiveClip();
    }
  }

  void _clearFinishedCrossFade() {
    if (_fadeInSeconds == 0 || _fadeElapsedSeconds >= _fadeInSeconds) {
      _crossFadeFrom = null;
    }
  }

  bool get _hasActiveSource =>
      _sampledHumanoid != null ||
      _animationIndex != null ||
      _programmaticPose != null ||
      _proceduralMotion != null;

  bool _shouldIgnorePlay(int priority) => _playing && priority < _priority;

  bool _isNodeAllowed(int nodeIndex) =>
      _nodeMask == null || _nodeMask!.contains(nodeIndex);

  Set<int>? _resolveNodeMask(
    Set<int>? nodeMask,
    Set<VrmHumanoidBone>? humanoidMask,
  ) {
    if (nodeMask == null && humanoidMask == null) return null;
    return Set.unmodifiable({
      ...?nodeMask,
      for (final bone in humanoidMask ?? const <VrmHumanoidBone>{})
        ?model.vrm.humanoid.nodeFor(bone),
    });
  }

  double _finiteOrZero(double value) => value.isFinite ? value : 0.0;

  double _startTimeSeconds(Duration? startTime, double fallbackSeconds) =>
      startTime == null
      ? _finiteOrZero(fallbackSeconds)
      : startTime.inMicroseconds / Duration.microsecondsPerSecond;

  Duration _durationFromSeconds(double seconds) => Duration(
    microseconds: (_finiteOrZero(seconds) * Duration.microsecondsPerSecond)
        .round(),
  );
}

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

/// Additive motion-layer controls for [VrmMotionController].
extension VrmAdditiveMotionLayers on VrmMotionController {
  /// Number of active additive layers.
  int get additiveLayerCount => _additiveLayers.length;

  /// Returns one layer's latest weighted model-root translation.
  ///
  /// The value is isolated from every other base or additive layer and uses
  /// the latest frame evaluated by [VrmRuntime.update]. A layer without a
  /// finite humanoid hips-translation contribution, or an unknown [layerId],
  /// returns null.
  VrmVector3? additiveLayerModelRootTranslation(int layerId) {
    for (final layer in _additiveLayers) {
      if (layer.id != layerId) continue;
      final translation = layer.frame.modelRootPose?.translation;
      if (!_hasFiniteLength(translation, 3)) return null;
      final values = translation!;
      return VrmVector3(
        values[0] * layer.weight,
        values[1] * layer.weight,
        values[2] * layer.weight,
      );
    }
    return null;
  }

  /// Adds any supported motion [source] as an additive layer.
  ///
  /// An [int] selects an embedded glTF animation. [GltfAsset],
  /// [VrmAnimationAsset], [VrmSampledHumanoidMotion], [VrmProgrammaticPose],
  /// and [VrmProceduralMotion] use
  /// the same source forms accepted by [play]. Animated node and morph values
  /// are converted to deltas from the source rest pose before application.
  /// Returns an ID for updating, seeking, or removing the layer.
  int addAdditiveLayer(
    Object source, {
    int? animationIndex,
    bool loop = false,
    double speed = 1,
    double startTimeSeconds = 0,
    Duration? startTime,
    double weight = 1,
    double hipsTranslationScale = 1,
    Set<int>? nodeMask,
    Set<VrmHumanoidBone>? humanoidMask,
  }) {
    GltfAnimationEvaluator? evaluator;
    GltfAsset? referenceGltf;
    int? selectedAnimation;

    if (source is int) {
      selectedAnimation = source;
      evaluator = _evaluator;
      referenceGltf = model.gltf;
      _checkAdditiveAnimationIndex(
        selectedAnimation,
        model.gltf.animations,
        'VRM model does not contain embedded glTF animations.',
      );
    } else if (source is GltfAsset) {
      selectedAnimation = animationIndex ?? 0;
      evaluator = GltfAnimationEvaluator(source);
      referenceGltf = source;
      _checkAdditiveAnimationIndex(
        selectedAnimation,
        source.animations,
        'glTF asset does not contain animations.',
      );
    } else if (source is VrmAnimationAsset) {
      selectedAnimation = animationIndex ?? source.defaultAnimationIndex;
      if (selectedAnimation == null) {
        throw StateError('VRMA asset does not contain glTF animations.');
      }
      evaluator = GltfAnimationEvaluator(source.gltf);
      referenceGltf = source.gltf;
      _checkAdditiveAnimationIndex(
        selectedAnimation,
        source.gltf.animations,
        'VRMA asset does not contain glTF animations.',
      );
    } else if (source is VrmSampledHumanoidMotion) {
      referenceGltf = source.restPose.gltf;
    } else if (source is! VrmProgrammaticPose &&
        source is! VrmProceduralMotion) {
      throw ArgumentError.value(
        source,
        'source',
        'Expected int, GltfAsset, VrmAnimationAsset, VrmSampledHumanoidMotion, VrmProgrammaticPose, or VrmProceduralMotion.',
      );
    }

    final duration = source is VrmSampledHumanoidMotion
        ? source._durationSeconds
        : selectedAnimation == null
        ? 0.0
        : evaluator!.duration(selectedAnimation);
    final layer = _AdditiveMotionLayer(
      id: _nextAdditiveLayerId++,
      source: source,
      evaluator: evaluator,
      referenceGltf: referenceGltf,
      vrmaRetargetPlan: source is VrmAnimationAsset
          ? _VrmaRetargetPlan(
              model,
              source,
              destinationRestWorldRotations: _modelRestWorldRotations,
            )
          : source is VrmSampledHumanoidMotion
          ? _VrmaRetargetPlan.humanoidOnly(
              model,
              source.restPose,
              destinationRestWorldRotations: _modelRestWorldRotations,
            )
          : null,
      animationIndex: selectedAnimation,
      durationSeconds: duration,
      loop: loop,
      speed: _finiteOrZero(speed),
      timeSeconds: _startTimeSeconds(startTime, startTimeSeconds),
      weight: _clamp01(weight),
      hipsTranslationScale: hipsTranslationScale.isFinite
          ? hipsTranslationScale
          : 1,
      nodeMask: _resolveNodeMask(nodeMask, humanoidMask),
    );
    if (source is VrmProgrammaticPose) {
      layer.frame = _snapshotProgrammaticPose(source);
    }
    layer.normalizeTime();
    _additiveLayers.add(layer);
    return layer.id;
  }

  /// Updates an additive layer's blend weight. Returns false for an unknown ID.
  bool setAdditiveLayerWeight(int layerId, double weight) {
    for (final layer in _additiveLayers) {
      if (layer.id != layerId) continue;
      layer.weight = _clamp01(weight);
      return true;
    }
    return false;
  }

  /// Seeks an additive layer. Returns false for an unknown ID.
  bool seekAdditiveLayer(int layerId, Duration position) {
    for (final layer in _additiveLayers) {
      if (layer.id != layerId) continue;
      layer.timeSeconds =
          position.inMicroseconds / Duration.microsecondsPerSecond;
      layer.normalizeTime();
      return true;
    }
    return false;
  }

  /// Removes one additive layer. Returns false for an unknown ID.
  bool removeAdditiveLayer(int layerId) {
    final index = _additiveLayers.indexWhere((layer) => layer.id == layerId);
    if (index < 0) return false;
    _additiveLayers.removeAt(index);
    return true;
  }

  /// Removes every additive layer.
  void clearAdditiveLayers() {
    _additiveLayers.clear();
  }

  void _updateAdditiveLayers(double deltaSeconds) {
    for (final layer in _additiveLayers) {
      layer.advance(deltaSeconds);
    }
  }

  void _evaluateAdditiveLayers() {
    for (final layer in _additiveLayers) {
      final source = layer.source;
      if (source is VrmProgrammaticPose) continue;
      if (source is VrmProceduralMotion) {
        layer.frame = _snapshotProgrammaticPose(source(layer.timeSeconds));
        continue;
      }
      final sampled = source is VrmSampledHumanoidMotion ? source : null;
      final evaluated = sampled != null
          ? sampled._evaluate(layer.timeSeconds)
          : layer.evaluator!.evaluate(layer.animationIndex!, layer.timeSeconds);
      final humanoidSource =
          sampled?.restPose ?? (source is VrmAnimationAsset ? source : null);
      if (humanoidSource != null) {
        final retargeted = _snapshotVrmaFrame(
          this,
          humanoidSource,
          evaluated,
          isNodeAllowed: layer.allowsNode,
          hipsTranslationScale: layer.hipsTranslationScale,
          retargetPlan: layer.vrmaRetargetPlan,
          // A layer adds its change from rest to the base pose, whose own
          // arms are already spaced.
          spaceArms: false,
        );
        layer.frame = _relativeAdditiveSnapshot(
          retargeted,
          model.gltf,
          layer.allowsNode,
          preserveModelRoot: true,
        );
      } else {
        layer.frame = _relativeAdditiveSnapshot(
          _MotionSnapshot(
            nodePoses: evaluated.nodePoses,
            morphWeights: evaluated.morphWeights,
          ),
          layer.referenceGltf!,
          layer.allowsNode,
        );
      }
    }
  }

  void _checkAdditiveAnimationIndex(
    int index,
    List<GltfAnimation> animations,
    String emptyMessage,
  ) {
    if (animations.isEmpty) throw StateError(emptyMessage);
    if (index < 0 || index >= animations.length) {
      throw RangeError.range(index, 0, animations.length - 1, 'animationIndex');
    }
  }
}

final class _AdditiveMotionLayer {
  _AdditiveMotionLayer({
    required this.id,
    required this.source,
    required this.evaluator,
    required this.referenceGltf,
    required this.vrmaRetargetPlan,
    required this.animationIndex,
    required this.durationSeconds,
    required this.loop,
    required this.speed,
    required this.timeSeconds,
    required this.weight,
    required this.hipsTranslationScale,
    required this.nodeMask,
  });

  final int id;
  final Object source;
  final GltfAnimationEvaluator? evaluator;
  final GltfAsset? referenceGltf;
  final _VrmaRetargetPlan? vrmaRetargetPlan;
  final int? animationIndex;
  final double durationSeconds;
  final bool loop;
  final double speed;
  final double hipsTranslationScale;
  final Set<int>? nodeMask;
  double timeSeconds;
  double weight;
  _MotionSnapshot frame = const _MotionSnapshot();

  bool allowsNode(int nodeIndex) =>
      nodeMask == null || nodeMask!.contains(nodeIndex);

  void advance(double deltaSeconds) {
    if (source is VrmProgrammaticPose) return;
    timeSeconds += deltaSeconds * speed;
    if (source is! VrmProceduralMotion) normalizeTime();
  }

  void normalizeTime() {
    if (source is VrmProgrammaticPose || source is VrmProceduralMotion) return;
    if (durationSeconds <= 0) {
      timeSeconds = 0;
    } else if (loop) {
      timeSeconds %= durationSeconds;
      if (timeSeconds < 0) timeSeconds += durationSeconds;
    } else {
      timeSeconds = timeSeconds.clamp(0.0, durationSeconds).toDouble();
    }
  }
}

_MotionSnapshot _relativeAdditiveSnapshot(
  _MotionSnapshot source,
  GltfAsset reference,
  bool Function(int nodeIndex) allowsNode, {
  bool preserveModelRoot = false,
}) {
  final nodePoses = <int, GltfNodePose>{};
  for (final entry in source.nodePoses.entries) {
    if (!allowsNode(entry.key)) continue;
    final node = reference.nodes.elementAtOrNull(entry.key);
    if (node == null) continue;
    nodePoses[entry.key] = _relativeAdditiveNodePose(entry.value, node);
  }
  final morphWeights = <int, List<double>>{};
  for (final entry in source.morphWeights.entries) {
    if (!allowsNode(entry.key)) continue;
    final node = reference.nodes.elementAtOrNull(entry.key);
    final mesh = node?.mesh == null
        ? null
        : reference.meshes.elementAtOrNull(node!.mesh!);
    if (node == null || mesh == null) continue;
    final base = node.weights.isEmpty ? mesh.weights : node.weights;
    morphWeights[entry.key] = [
      for (var index = 0; index < entry.value.length; index++)
        entry.value[index] - (base.elementAtOrNull(index) ?? 0.0),
    ];
  }
  return _MotionSnapshot(
    nodePoses: Map.unmodifiable(nodePoses),
    modelRootPose: preserveModelRoot ? source.modelRootPose : null,
    morphWeights: Map.unmodifiable(morphWeights),
    expressionWeights: source.expressionWeights,
    lookAt: source.lookAt,
  );
}

GltfNodePose _relativeAdditiveNodePose(GltfNodePose pose, GltfNode rest) {
  final translation = pose.translation;
  final rotation = pose.rotation;
  final scale = pose.scale;
  return GltfNodePose(
    translation: translation != null && translation.length >= 3
        ? [
            translation[0] - rest.restTranslation[0],
            translation[1] - rest.restTranslation[1],
            translation[2] - rest.restTranslation[2],
          ]
        : null,
    rotation: rotation != null && rotation.length >= 4
        ? _quatMultiply(_quatInverse(rest.restRotation), rotation)
        : null,
    scale: scale != null && scale.length >= 3
        ? [
            _relativeScale(scale[0], rest.restScale[0]),
            _relativeScale(scale[1], rest.restScale[1]),
            _relativeScale(scale[2], rest.restScale[2]),
          ]
        : null,
  );
}

double _relativeScale(double value, double rest) =>
    rest == 0 ? 1 : value / rest;

extension _VrmMotionApply on VrmMotionController {
  void _applyFadeOutSnapshot(
    VrmSceneBinding binding,
    VrmExpressionController expressions,
    VrmLookAtController lookAt,
  ) {
    final source = _fadeOutFrom!;
    final progress = _fadeOutProgress;
    _applyNodePoses(binding, const {}, progress, from: source.nodePoses);
    _applyMorphWeights(binding, const {}, progress, from: source.morphWeights);
    expressions._setMotionInputs(
      _additiveMotionInputs({
        for (final entry in source.expressionWeights.entries)
          entry.key: entry.value * (1 - progress),
      }),
    );
    lookAt._setMotionYawPitch(
      _additiveLookAt(_lerpSnapshotLookAt(source.lookAt, null, progress)),
    );
    _applyAdditiveNodePoses(binding);
    _applyModelRootPose(binding, null, progress, from: source.modelRootPose);
    _clearIfFadeOutFinished();
  }

  void _applyProgrammaticPose(
    VrmSceneBinding binding,
    VrmExpressionController expressions,
    VrmLookAtController lookAt,
    VrmProgrammaticPose pose,
  ) {
    final fade = _fadeWeight;
    _applyNodePoses(
      binding,
      pose.nodePoses,
      fade,
      from: _crossFadeFrom?.nodePoses,
    );
    _applyMorphWeights(
      binding,
      pose.morphWeights,
      fade,
      from: _crossFadeFrom?.morphWeights,
    );
    expressions._setMotionInputs(
      _additiveMotionInputs(
        _blendMotionInputs({
          for (final entry in pose.expressionWeights.entries)
            entry.key: _clamp01(entry.value),
        }, fade),
      ),
    );
    final yaw = pose.lookAtYawDegrees;
    final pitch = pose.lookAtPitchDegrees;
    lookAt._setMotionYawPitch(
      _additiveLookAt(
        _blendLookAt(
          yaw == null || pitch == null ? null : _YawPitch(yaw, pitch),
          fade,
        ),
      ),
    );
    _applyAdditiveNodePoses(binding);
    _applyModelRootPose(
      binding,
      _programmaticRootPose(pose),
      fade,
      from: _crossFadeFrom?.modelRootPose,
    );
    _clearFinishedCrossFade();
  }

  void _applyNodePoses(
    VrmSceneBinding binding,
    Map<int, GltfNodePose> nodePoses,
    double fade, {
    Map<int, GltfNodePose>? from,
  }) {
    final fromPoses = from ?? const <int, GltfNodePose>{};
    final nodeIndices = {...fromPoses.keys, ...nodePoses.keys};
    for (final nodeIndex in nodeIndices) {
      final targetAllowed = _isNodeAllowed(nodeIndex);
      final fromPose = fromPoses[nodeIndex];
      if (!targetAllowed && fromPose == null) continue;
      final node = model.gltf.nodes.elementAtOrNull(nodeIndex);
      if (node == null) continue;
      final targetPose = targetAllowed ? nodePoses[nodeIndex] : null;
      binding.nodeByGltfIndex(nodeIndex).localTransform = _trsMatrix(
        _lerpList(
          _finiteListOr(fromPose?.translation, node.restTranslation, 3),
          _finiteListOr(targetPose?.translation, node.restTranslation, 3),
          fade,
        ),
        _slerp(
          _finiteListOr(fromPose?.rotation, node.restRotation, 4),
          _finiteListOr(targetPose?.rotation, node.restRotation, 4),
          fade,
        ),
        _lerpList(
          _finiteListOr(fromPose?.scale, node.restScale, 3),
          _finiteListOr(targetPose?.scale, node.restScale, 3),
          fade,
        ),
      );
    }
  }

  void _applyMorphWeights(
    VrmSceneBinding binding,
    Map<int, List<double>> morphWeights,
    double fade, {
    Map<int, List<double>>? from,
  }) {
    final fromWeights = from ?? const <int, List<double>>{};
    final nodeIndices = {
      ...fromWeights.keys,
      ...morphWeights.keys,
      for (final layer in _additiveLayers) ...layer.frame.morphWeights.keys,
    };
    for (final nodeIndex in nodeIndices) {
      final overrideAllowed = _isNodeAllowed(nodeIndex);
      final hasSource = fromWeights.containsKey(nodeIndex);
      final additiveMorphCount = _additiveMorphCount(nodeIndex);
      if (!overrideAllowed && !hasSource && additiveMorphCount == 0) continue;
      final meshIndex = model.gltf.nodes.elementAtOrNull(nodeIndex)?.mesh;
      if (meshIndex == null) continue;
      final mesh = model.gltf.meshes.elementAtOrNull(meshIndex);
      final meshBinding = binding.meshByNodeIndex(nodeIndex);
      if (mesh == null || meshBinding == null) continue;
      final node = model.gltf.nodes.elementAtOrNull(nodeIndex);
      final baseWeights = node == null || node.weights.isEmpty
          ? mesh.weights
          : node.weights;
      for (var primitive = 0; primitive < mesh.primitives.length; primitive++) {
        final target = overrideAllowed
            ? morphWeights[nodeIndex] ?? const <double>[]
            : const <double>[];
        final source = fromWeights[nodeIndex] ?? const <double>[];
        final requestedMorphCount = math.max(
          math.max(target.length, source.length),
          additiveMorphCount,
        );
        final morphCount = math.min(
          mesh.primitives[primitive].targets.length,
          requestedMorphCount,
        );
        for (var morph = 0; morph < morphCount; morph++) {
          final base = _finiteAtOr(baseWeights, morph, 0.0);
          final from = _finiteAtOr(source, morph, base);
          final to = _finiteAtOr(target, morph, base);
          meshBinding.setMorphWeight(
            primitiveIndex: primitive,
            morphIndex: morph,
            weight:
                from +
                (to - from) * fade +
                _additiveMorphDelta(nodeIndex, morph),
          );
        }
      }
    }
  }

  void _applyModelRootPose(
    VrmSceneBinding binding,
    GltfNodePose? pose,
    double fade, {
    GltfNodePose? from,
  }) {
    final hasAdditiveRoot = _additiveLayers.any(
      (layer) => layer.frame.modelRootPose != null,
    );
    if (pose == null && from == null && !hasAdditiveRoot) return;
    final translation = List<double>.of(
      _lerpList(
        _finiteListOr(from?.translation, const [0.0, 0.0, 0.0], 3),
        _finiteListOr(pose?.translation, const [0.0, 0.0, 0.0], 3),
        fade,
      ),
    );
    var rotation = _slerp(
      _finiteListOr(from?.rotation, const [0.0, 0.0, 0.0, 1.0], 4),
      _finiteListOr(pose?.rotation, const [0.0, 0.0, 0.0, 1.0], 4),
      fade,
    );
    final scale = List<double>.of(
      _lerpList(
        _finiteListOr(from?.scale, const [1.0, 1.0, 1.0], 3),
        _finiteListOr(pose?.scale, const [1.0, 1.0, 1.0], 3),
        fade,
      ),
    );
    for (final layer in _additiveLayers) {
      final additive = layer.frame.modelRootPose;
      if (additive == null) continue;
      final additiveTranslation = additive.translation;
      final additiveRotation = additive.rotation;
      final additiveScale = additive.scale;
      final weight = layer.weight;
      if (_hasFiniteLength(additiveTranslation, 3)) {
        final values = additiveTranslation!;
        translation[0] += values[0] * weight;
        translation[1] += values[1] * weight;
        translation[2] += values[2] * weight;
      }
      if (_hasFiniteLength(additiveRotation, 4)) {
        rotation = _quatMultiply(
          rotation,
          _slerp(const [0.0, 0.0, 0.0, 1.0], additiveRotation!, weight),
        );
      }
      if (_hasFiniteLength(additiveScale, 3)) {
        final values = additiveScale!;
        scale[0] *= 1 + (values[0] - 1) * weight;
        scale[1] *= 1 + (values[1] - 1) * weight;
        scale[2] *= 1 + (values[2] - 1) * weight;
      }
    }
    final transform = _trsMatrix(translation, rotation, scale);
    if (binding case final VrmModelRootBinding rootBinding) {
      rootBinding.modelRootMotionTransform = transform;
      return;
    }
    for (final nodeIndex in _sceneRootNodeIndices()) {
      final node = binding.nodeByGltfIndex(nodeIndex);
      node.localTransform = _multiplyMatrices(transform, node.localTransform);
    }
  }

  List<int> _sceneRootNodeIndices() {
    final sceneIndex =
        model.gltf.scene ?? (model.gltf.scenes.isEmpty ? null : 0);
    if (sceneIndex == null) return const [];
    return model.gltf.scenes.elementAtOrNull(sceneIndex)?.nodes ?? const [];
  }

  void _applyAdditiveNodePoses(VrmSceneBinding binding) {
    for (final layer in _additiveLayers) {
      for (final entry in layer.frame.nodePoses.entries) {
        if (!layer.allowsNode(entry.key)) continue;
        final gltfNode = model.gltf.nodes.elementAtOrNull(entry.key);
        if (gltfNode == null) continue;
        final node = binding.nodeByGltfIndex(entry.key);
        final current = node.localTransform;
        final translation = _matrixTranslation(current);
        final rotation = _matrixRotation(
          current,
          fallback: gltfNode.restRotation,
        );
        final scale = _matrixScale(current);
        final additive = entry.value;
        final additiveTranslation = additive.translation;
        final additiveRotation = additive.rotation;
        final additiveScale = additive.scale;
        final finiteAdditiveTranslation =
            _hasFiniteLength(additiveTranslation, 3)
            ? additiveTranslation!
            : null;
        final finiteAdditiveRotation = _hasFiniteLength(additiveRotation, 4)
            ? additiveRotation!
            : null;
        final finiteAdditiveScale = _hasFiniteLength(additiveScale, 3)
            ? additiveScale!
            : null;
        final weight = layer.weight;

        node.localTransform = _trsMatrix(
          finiteAdditiveTranslation == null
              ? translation
              : [
                  translation[0] + finiteAdditiveTranslation[0] * weight,
                  translation[1] + finiteAdditiveTranslation[1] * weight,
                  translation[2] + finiteAdditiveTranslation[2] * weight,
                ],
          finiteAdditiveRotation == null
              ? rotation
              : _quatMultiply(
                  rotation,
                  _slerp(
                    const [0.0, 0.0, 0.0, 1.0],
                    finiteAdditiveRotation,
                    weight,
                  ),
                ),
          finiteAdditiveScale == null
              ? scale
              : [
                  scale[0] * (1 + (finiteAdditiveScale[0] - 1) * weight),
                  scale[1] * (1 + (finiteAdditiveScale[1] - 1) * weight),
                  scale[2] * (1 + (finiteAdditiveScale[2] - 1) * weight),
                ],
        );
      }
    }
  }

  Map<String, double> _additiveMotionInputs(Map<String, double> base) {
    if (_additiveLayers.every(
      (layer) => layer.frame.expressionWeights.isEmpty,
    )) {
      return base;
    }
    final names = {...base.keys};
    for (final layer in _additiveLayers) {
      names.addAll(layer.frame.expressionWeights.keys);
    }
    return {
      for (final name in names) name: _clamp01(_additiveExpression(name, base)),
    };
  }

  int _additiveMorphCount(int nodeIndex) {
    var count = 0;
    for (final layer in _additiveLayers) {
      if (!layer.allowsNode(nodeIndex)) continue;
      count = math.max(count, layer.frame.morphWeights[nodeIndex]?.length ?? 0);
    }
    return count;
  }

  double _additiveMorphDelta(int nodeIndex, int morphIndex) {
    var delta = 0.0;
    for (final layer in _additiveLayers) {
      if (!layer.allowsNode(nodeIndex)) continue;
      final values = layer.frame.morphWeights[nodeIndex];
      if (values != null && morphIndex < values.length) {
        final value = values[morphIndex];
        if (value.isFinite) delta += value * layer.weight;
      }
    }
    return delta;
  }

  double _additiveExpression(String name, Map<String, double> base) {
    var value = base[name] ?? 0.0;
    for (final layer in _additiveLayers) {
      value += (layer.frame.expressionWeights[name] ?? 0.0) * layer.weight;
    }
    return value;
  }

  _YawPitch? _additiveLookAt(_YawPitch? base) {
    var hasValue = base != null;
    var yaw = base?.yawDegrees ?? 0.0;
    var pitch = base?.pitchDegrees ?? 0.0;
    for (final layer in _additiveLayers) {
      final additive = layer.frame.lookAt;
      if (additive == null) continue;
      hasValue = true;
      yaw += additive.yawDegrees * layer.weight;
      pitch += additive.pitchDegrees * layer.weight;
    }
    return hasValue ? _YawPitch(yaw, pitch) : null;
  }

  List<double> _finiteListOr(
    List<double>? value,
    List<double> fallback,
    int length,
  ) => _hasFiniteLength(value, length) ? value! : fallback;

  double _finiteAtOr(List<double> values, int index, double fallback) {
    if (index >= values.length) return fallback;
    final value = values[index];
    return value.isFinite ? value : fallback;
  }

  bool _hasFiniteLength(List<double>? value, int length) {
    if (value == null || value.length < length) return false;
    for (var i = 0; i < length; i++) {
      if (!value[i].isFinite) return false;
    }
    return true;
  }
}

extension _VrmMotionSnapshot on VrmMotionController {
  _MotionSnapshot? _captureSnapshot() {
    if (_stopping && _fadeOutFrom != null) {
      return _blendSnapshots(
        _fadeOutFrom,
        const _MotionSnapshot(),
        _fadeOutProgress,
      );
    }
    final target = _captureRawSnapshot();
    if (target == null) return null;
    final fade = _fadeWeight;
    if (fade >= 1) return target;
    final source = _crossFadeFrom;
    if (fade <= 0 && source != null) return source;
    return _blendSnapshots(source, target, fade);
  }

  _MotionSnapshot? _captureRawSnapshot() {
    final sampled = _sampledHumanoid;
    if (sampled != null) return _sampledSnapshot(sampled);
    final programmaticPose = _programmaticPose;
    if (programmaticPose != null) {
      return _maskedSnapshot(_snapshotProgrammaticPose(programmaticPose));
    }
    final proceduralMotion = _proceduralMotion;
    if (proceduralMotion != null) {
      return _maskedSnapshot(
        _snapshotProgrammaticPose(proceduralMotion(_timeSeconds)),
      );
    }

    final animationIndex = _animationIndex;
    if (animationIndex == null) return null;
    final vrma = _vrma;
    if (vrma != null) {
      return _captureVrmaMotionSnapshot(this, vrma, animationIndex);
    }
    final evaluator = _externalGltfEvaluator ?? _evaluator;
    final frame = evaluator.evaluate(animationIndex, _timeSeconds);
    return _maskedSnapshot(
      _MotionSnapshot(
        nodePoses: frame.nodePoses,
        morphWeights: frame.morphWeights,
      ),
    );
  }

  _MotionSnapshot _maskedSnapshot(_MotionSnapshot snapshot) {
    if (_nodeMask == null) return snapshot;
    return _MotionSnapshot(
      nodePoses: Map.unmodifiable({
        for (final entry in snapshot.nodePoses.entries)
          if (_isNodeAllowed(entry.key)) entry.key: entry.value,
      }),
      modelRootPose: snapshot.modelRootPose,
      morphWeights: Map.unmodifiable({
        for (final entry in snapshot.morphWeights.entries)
          if (_isNodeAllowed(entry.key)) entry.key: entry.value,
      }),
      expressionWeights: snapshot.expressionWeights,
      lookAt: snapshot.lookAt,
    );
  }

  _MotionSnapshot _snapshotProgrammaticPose(VrmProgrammaticPose pose) {
    final yaw = pose.lookAtYawDegrees;
    final pitch = pose.lookAtPitchDegrees;
    return _MotionSnapshot(
      nodePoses: pose.nodePoses,
      modelRootPose: _programmaticRootPose(pose),
      morphWeights: pose.morphWeights,
      expressionWeights: {
        for (final entry in pose.expressionWeights.entries)
          entry.key: _clamp01(entry.value),
      },
      lookAt: yaw == null || pitch == null ? null : _YawPitch(yaw, pitch),
    );
  }

  _MotionSnapshot _blendSnapshots(
    _MotionSnapshot? source,
    _MotionSnapshot target,
    double fade,
  ) {
    return _MotionSnapshot(
      nodePoses: _blendSnapshotNodePoses(
        source?.nodePoses ?? const {},
        target.nodePoses,
        fade,
      ),
      modelRootPose: _blendSnapshotRootPose(
        source?.modelRootPose,
        target.modelRootPose,
        fade,
      ),
      morphWeights: _blendSnapshotMorphWeights(
        source?.morphWeights ?? const {},
        target.morphWeights,
        fade,
      ),
      expressionWeights: _blendSnapshotExpressionWeights(
        source?.expressionWeights ?? const {},
        target.expressionWeights,
        fade,
      ),
      lookAt: _lerpSnapshotLookAt(source?.lookAt, target.lookAt, fade),
    );
  }

  Map<int, GltfNodePose> _blendSnapshotNodePoses(
    Map<int, GltfNodePose> source,
    Map<int, GltfNodePose> target,
    double fade,
  ) {
    final result = <int, GltfNodePose>{};
    for (final nodeIndex in {...source.keys, ...target.keys}) {
      final node = model.gltf.nodes.elementAtOrNull(nodeIndex);
      if (node == null) continue;
      final from = source[nodeIndex];
      final to = target[nodeIndex];
      result[nodeIndex] = GltfNodePose(
        translation: _lerpList(
          _snapshotListOr(from?.translation, node.restTranslation, 3),
          _snapshotListOr(to?.translation, node.restTranslation, 3),
          fade,
        ),
        rotation: _slerp(
          _snapshotListOr(from?.rotation, node.restRotation, 4),
          _snapshotListOr(to?.rotation, node.restRotation, 4),
          fade,
        ),
        scale: _lerpList(
          _snapshotListOr(from?.scale, node.restScale, 3),
          _snapshotListOr(to?.scale, node.restScale, 3),
          fade,
        ),
      );
    }
    return Map.unmodifiable(result);
  }

  GltfNodePose? _blendSnapshotRootPose(
    GltfNodePose? source,
    GltfNodePose? target,
    double fade,
  ) {
    if (source == null && target == null) return null;
    return GltfNodePose(
      translation: _lerpList(
        _snapshotListOr(source?.translation, const [0.0, 0.0, 0.0], 3),
        _snapshotListOr(target?.translation, const [0.0, 0.0, 0.0], 3),
        fade,
      ),
      rotation: _slerp(
        _snapshotListOr(source?.rotation, const [0.0, 0.0, 0.0, 1.0], 4),
        _snapshotListOr(target?.rotation, const [0.0, 0.0, 0.0, 1.0], 4),
        fade,
      ),
      scale: _lerpList(
        _snapshotListOr(source?.scale, const [1.0, 1.0, 1.0], 3),
        _snapshotListOr(target?.scale, const [1.0, 1.0, 1.0], 3),
        fade,
      ),
    );
  }

  Map<int, List<double>> _blendSnapshotMorphWeights(
    Map<int, List<double>> source,
    Map<int, List<double>> target,
    double fade,
  ) {
    final result = <int, List<double>>{};
    for (final nodeIndex in {...source.keys, ...target.keys}) {
      final node = model.gltf.nodes.elementAtOrNull(nodeIndex);
      final meshIndex = node?.mesh;
      final mesh = meshIndex == null
          ? null
          : model.gltf.meshes.elementAtOrNull(meshIndex);
      final base = node == null || node.weights.isEmpty
          ? mesh?.weights ?? const <double>[]
          : node.weights;
      final from = source[nodeIndex] ?? const <double>[];
      final to = target[nodeIndex] ?? const <double>[];
      final count = math.max(from.length, to.length);
      result[nodeIndex] = List<double>.unmodifiable([
        for (var index = 0; index < count; index++)
          _snapshotAt(from, index, _snapshotAt(base, index, 0.0)) * (1 - fade) +
              _snapshotAt(to, index, _snapshotAt(base, index, 0.0)) * fade,
      ]);
    }
    return Map.unmodifiable(result);
  }

  Map<String, double> _blendSnapshotExpressionWeights(
    Map<String, double> source,
    Map<String, double> target,
    double fade,
  ) {
    return Map.unmodifiable({
      for (final name in {...source.keys, ...target.keys})
        name: _clamp01(
          (source[name] ?? 0.0) * (1 - fade) + (target[name] ?? 0.0) * fade,
        ),
    });
  }

  Map<String, double> _blendMotionInputs(
    Map<String, double> target,
    double fade,
  ) {
    final source =
        _crossFadeFrom?.expressionWeights ?? const <String, double>{};
    return {
      for (final name in {...source.keys, ...target.keys})
        name: _clamp01(
          (source[name] ?? 0.0) * (1 - fade) + (target[name] ?? 0.0) * fade,
        ),
    };
  }

  _YawPitch? _blendLookAt(_YawPitch? target, double fade) =>
      _lerpSnapshotLookAt(_crossFadeFrom?.lookAt, target, fade);
}

GltfNodePose? _programmaticRootPose(VrmProgrammaticPose pose) {
  final root = pose.modelRootTranslation;
  return root == null
      ? null
      : GltfNodePose(translation: [root.x, root.y, root.z]);
}

_YawPitch? _lerpSnapshotLookAt(
  _YawPitch? source,
  _YawPitch? target,
  double fade,
) {
  if (source == null && target == null) return null;
  return _YawPitch(
    (source?.yawDegrees ?? 0.0) * (1 - fade) +
        (target?.yawDegrees ?? 0.0) * fade,
    (source?.pitchDegrees ?? 0.0) * (1 - fade) +
        (target?.pitchDegrees ?? 0.0) * fade,
  );
}

List<double> _snapshotListOr(
  List<double>? value,
  List<double> fallback,
  int length,
) {
  if (value == null || value.length < length) return fallback;
  for (var index = 0; index < length; index++) {
    if (!value[index].isFinite) return fallback;
  }
  return value;
}

double _snapshotAt(List<double> values, int index, double fallback) {
  if (index >= values.length) return fallback;
  final value = values[index];
  return value.isFinite ? value : fallback;
}

final class _MotionSnapshot {
  const _MotionSnapshot({
    this.nodePoses = const {},
    this.modelRootPose,
    this.morphWeights = const {},
    this.expressionWeights = const {},
    this.lookAt,
  });

  final Map<int, GltfNodePose> nodePoses;
  final GltfNodePose? modelRootPose;
  final Map<int, List<double>> morphWeights;
  final Map<String, double> expressionWeights;
  final _YawPitch? lookAt;
}

void _applyVrmaMotion(
  VrmMotionController controller,
  VrmSceneBinding binding,
  VrmExpressionController expressions,
  VrmLookAtController lookAt,
  VrmAnimationAsset vrma,
  int animationIndex,
) {
  final evaluator = controller._vrmaEvaluator;
  if (evaluator == null) return;
  final frame = evaluator.evaluate(animationIndex, controller._timeSeconds);
  final snapshot = _snapshotVrmaFrame(controller, vrma, frame);
  _applyHumanoidMotionSnapshot(
    controller,
    binding,
    expressions,
    lookAt,
    snapshot,
  );
}

void _applyHumanoidMotionSnapshot(
  VrmMotionController controller,
  VrmSceneBinding binding,
  VrmExpressionController expressions,
  VrmLookAtController lookAt,
  _MotionSnapshot snapshot,
) {
  final fade = controller._fadeWeight;
  controller._applyNodePoses(
    binding,
    snapshot.nodePoses,
    fade,
    from: controller._crossFadeFrom?.nodePoses,
  );
  expressions._setMotionInputs(
    controller._additiveMotionInputs(
      controller._blendMotionInputs(snapshot.expressionWeights, fade),
    ),
  );
  lookAt._setMotionYawPitch(
    controller._additiveLookAt(controller._blendLookAt(snapshot.lookAt, fade)),
  );
  controller._applyAdditiveNodePoses(binding);
  controller._applyModelRootPose(
    binding,
    snapshot.modelRootPose,
    fade,
    from: controller._crossFadeFrom?.modelRootPose,
  );
  controller._clearFinishedCrossFade();
}

_MotionSnapshot? _captureVrmaMotionSnapshot(
  VrmMotionController controller,
  VrmAnimationAsset vrma,
  int animationIndex,
) {
  final evaluator = controller._vrmaEvaluator;
  if (evaluator == null) return null;
  final frame = evaluator.evaluate(animationIndex, controller._timeSeconds);
  return _snapshotVrmaFrame(controller, vrma, frame);
}

_MotionSnapshot _snapshotVrmaFrame(
  VrmMotionController controller,
  VrmAnimationAsset vrma,
  GltfAnimationFrame frame, {
  bool Function(int nodeIndex)? isNodeAllowed,
  double? hipsTranslationScale,
  _VrmaRetargetPlan? retargetPlan,
  bool spaceArms = true,
}) {
  final model = controller.model;
  final allowsNode = isNodeAllowed ?? controller._isNodeAllowed;
  final nodePoses = <int, GltfNodePose>{};
  GltfNodePose? modelRootPose;
  final resolvedPlan =
      retargetPlan ??
      controller._vrmaRetargetPlan ??
      _VrmaRetargetPlan(
        model,
        vrma,
        destinationRestWorldRotations: controller._modelRestWorldRotations,
      );
  final sourcePoses = <_VrmaRetargetTarget, GltfNodePose>{
    for (final target in resolvedPlan.targets)
      if (allowsNode(target.destinationNode.index))
        target: ?target.sourcePose(frame),
  };
  final armSpacing = resolvedPlan.armSpacing;
  if (spaceArms && controller.keepHandsClear && armSpacing != null) {
    _spaceArms(armSpacing, sourcePoses);
  }
  for (final MapEntry(key: target, value: sourcePose) in sourcePoses.entries) {
    final retargeted = controller.vrmaRetargeter.retargetBone(
      bone: target.bone,
      sourcePose: sourcePose,
      sourceRestNode: target.sourceNode,
      sourceRestWorldRotation: target.sourceRestWorldRotation,
      destinationRestNode: target.destinationNode,
      destinationRestWorldRotation: target.destinationRestWorldRotation,
      hipsTranslationScale:
          hipsTranslationScale ?? controller._vrmaHipsTranslationScale,
    );
    if (retargeted.modelRootPose != null) {
      modelRootPose = retargeted.modelRootPose;
    }
    if (retargeted.nodePose != null) {
      nodePoses[target.destinationNode.index] = retargeted.nodePose!;
    }
  }

  final expressionWeights = <String, double>{};
  for (final target in resolvedPlan.expressionTargets) {
    final translation = frame.nodePoses[target.nodeIndex]?.translation;
    if (translation == null) continue;
    for (final expressionName in target.names) {
      expressionWeights[expressionName] = _clamp01(translation[0]);
    }
  }
  final lookAtNode = resolvedPlan.lookAtNode;
  final lookAtRotation = lookAtNode == null
      ? null
      : frame.nodePoses[lookAtNode]?.rotation;
  return _MotionSnapshot(
    nodePoses: Map.unmodifiable(nodePoses),
    modelRootPose: modelRootPose,
    expressionWeights: Map.unmodifiable(expressionWeights),
    lookAt: lookAtRotation == null
        ? null
        : _yawPitchFromExtrinsicZxy(lookAtRotation),
  );
}

/// Replaces the upper-arm poses in [sourcePoses] by [armSpacing]'s.
void _spaceArms(
  _ArmSpacing armSpacing,
  Map<_VrmaRetargetTarget, GltfNodePose> sourcePoses,
) {
  final normalized = <VrmHumanoidBone, List<double>>{
    for (final MapEntry(key: target, value: pose) in sourcePoses.entries)
      if (pose.rotation case final rotation?)
        target.bone: _normalizedHumanoidRotation(
          localRest: target.sourceNode.restRotation,
          worldRest: target.sourceRestWorldRotation,
          current: rotation,
        ),
  };
  final adjusted = armSpacing.adjust(normalized);
  for (final MapEntry(key: target, value: pose) in sourcePoses.entries) {
    if (!_armSpacingSides.any((side) => side.upperArm == target.bone) ||
        pose.rotation == null) {
      continue;
    }
    final rotation = adjusted[target.bone];
    if (rotation == null || identical(rotation, normalized[target.bone])) {
      continue;
    }
    sourcePoses[target] = GltfNodePose(
      translation: pose.translation,
      rotation: _humanoidLocalRotationFromNormalized(
        localRest: target.sourceNode.restRotation,
        worldRest: target.sourceRestWorldRotation,
        normalized: rotation,
      ),
      scale: pose.scale,
    );
  }
}
