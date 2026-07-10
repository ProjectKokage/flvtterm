part of '../flvtterm.dart';

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

  /// Retargeter used for VRMA humanoid motion.
  VrmHumanoidRetargeter vrmaRetargeter = const VrmFkHumanoidRetargeter();

  final GltfAnimationEvaluator _evaluator;
  final Map<int, List<double>> _modelRestWorldRotations;

  int? _animationIndex;
  VrmAnimationAsset? _vrma;
  VrmProgrammaticPose? _programmaticPose;
  VrmProceduralMotion? _proceduralMotion;
  final _additiveLayers = <_AdditiveMotionLayer>[];
  var _nextAdditiveLayerId = 0;
  GltfAnimationEvaluator? _vrmaEvaluator;
  Map<int, List<double>> _vrmaRestWorldRotations = const {};
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

  /// Plays any supported motion source through one entry point.
  ///
  /// Pass an [int] for an embedded glTF animation index, a [GltfAsset] for an
  /// external generic glTF animation, a [VrmAnimationAsset] for VRMA, or a
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
      'Expected int, GltfAsset, VrmAnimationAsset, VrmProgrammaticPose, or VrmProceduralMotion.',
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
    _prepareCrossFade(fadeIn);
    _animationIndex = animationIndex;
    _vrma = null;
    _programmaticPose = null;
    _proceduralMotion = null;
    _vrmaEvaluator = null;
    _vrmaRestWorldRotations = const {};
    _externalGltfEvaluator = null;
    _nodeMask = _resolveNodeMask(nodeMask, humanoidMask);
    _vrmaHipsTranslationScale = 1;
    _loop = loop;
    this.speed = _finiteOrZero(speed);
    _priority = priority;
    _timeSeconds = _startTimeSeconds(startTime, startTimeSeconds);
    _startFade(fadeIn);
    _paused = false;
    _playing = true;
    _clampOrWrapTime();
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
    _prepareCrossFade(fadeIn);
    _animationIndex = index;
    _vrma = animation;
    _programmaticPose = null;
    _proceduralMotion = null;
    _vrmaEvaluator = GltfAnimationEvaluator(animation.gltf);
    _vrmaRestWorldRotations = _restWorldRotations(animation.gltf);
    _externalGltfEvaluator = null;
    _nodeMask = _resolveNodeMask(nodeMask, humanoidMask);
    _vrmaHipsTranslationScale = hipsTranslationScale.isFinite
        ? hipsTranslationScale
        : 1;
    _loop = loop;
    this.speed = _finiteOrZero(speed);
    _priority = priority;
    _timeSeconds = _startTimeSeconds(startTime, startTimeSeconds);
    _startFade(fadeIn);
    _paused = false;
    _playing = true;
    _clampOrWrapTime();
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
    _prepareCrossFade(fadeIn);
    _animationIndex = animationIndex;
    _vrma = null;
    _programmaticPose = null;
    _proceduralMotion = null;
    _vrmaEvaluator = null;
    _vrmaRestWorldRotations = const {};
    _externalGltfEvaluator = GltfAnimationEvaluator(animationAsset);
    _nodeMask = _resolveNodeMask(nodeMask, humanoidMask);
    _vrmaHipsTranslationScale = 1;
    _loop = loop;
    this.speed = _finiteOrZero(speed);
    _priority = priority;
    _timeSeconds = _startTimeSeconds(startTime, startTimeSeconds);
    _startFade(fadeIn);
    _paused = false;
    _playing = true;
    _clampOrWrapTime();
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
    _prepareCrossFade(fadeIn);
    _animationIndex = null;
    _vrma = null;
    _programmaticPose = pose;
    _proceduralMotion = null;
    _vrmaEvaluator = null;
    _vrmaRestWorldRotations = const {};
    _externalGltfEvaluator = null;
    _nodeMask = _resolveNodeMask(nodeMask, humanoidMask);
    _vrmaHipsTranslationScale = 1;
    _loop = false;
    speed = 0;
    _priority = priority;
    _timeSeconds = 0;
    _startFade(fadeIn);
    _paused = false;
    _playing = true;
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
    _prepareCrossFade(fadeIn);
    _animationIndex = null;
    _vrma = null;
    _programmaticPose = null;
    _proceduralMotion = motion;
    _vrmaEvaluator = null;
    _vrmaRestWorldRotations = const {};
    _externalGltfEvaluator = null;
    _nodeMask = _resolveNodeMask(nodeMask, humanoidMask);
    _vrmaHipsTranslationScale = 1;
    _loop = false;
    this.speed = _finiteOrZero(speed);
    _priority = priority;
    _timeSeconds = _startTimeSeconds(startTime, startTimeSeconds);
    _startFade(fadeIn);
    _paused = false;
    _playing = true;
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
    _animationIndex = null;
    _vrma = null;
    _programmaticPose = null;
    _proceduralMotion = null;
    _vrmaEvaluator = null;
    _vrmaRestWorldRotations = const {};
    _externalGltfEvaluator = null;
    _nodeMask = null;
    _vrmaHipsTranslationScale = 1;
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
    if (_animationIndex == null && _proceduralMotion == null) return;
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
    _clearIfFadeOutFinished();
    _clearFinishedCrossFade();
  }

  double get _activeDurationSeconds {
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
    _fadeElapsedSeconds = _fadeInSeconds == 0 ? 0 : 0;
    _fadeOutSeconds = 0;
    _fadeOutElapsedSeconds = 0;
    _fadeOutFrom = null;
    _stopping = false;
  }

  void _prepareCrossFade(Duration fadeIn) {
    _crossFadeFrom = fadeIn > Duration.zero ? _captureSnapshot() : null;
  }

  double get _fadeWeight {
    final fadeIn = _fadeInSeconds == 0
        ? 1.0
        : _clamp01(_fadeElapsedSeconds / _fadeInSeconds);
    final fadeOut = !_stopping || _fadeOutSeconds == 0
        ? 1.0
        : 1 - _clamp01(_fadeOutElapsedSeconds / _fadeOutSeconds);
    return fadeIn * fadeOut;
  }

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
