import 'dart:math' as math;

import '../gltf/animation_math.dart';
import '../gltf/gltf_accessor_validation.dart';
import '../gltf/gltf_scene_types.dart';
import '../json_values.dart';
import '../math_types.dart';
import '../safe_list_index.dart';
import '../vrm/spring_bone_parser.dart';
import '../vrm/spring_bone_types.dart';
import '../vrm/vrm_assets.dart';
import '../vrm/vrm_enums.dart';
import '../vrm/vrm_humanoid_parser.dart';
import '../vrm0/vrm_coordinate_convention.dart';
import 'scene_binding.dart';
import 'spring_bone_math.dart';

/// Evaluates `VRMC_springBone` procedural joint motion.
final class VrmSpringBoneController {
  /// Creates a SpringBone controller for [model].
  VrmSpringBoneController(this.model) : _parents = nodeParents(model.gltf);

  /// Parsed model backing this controller.
  final VrmModel model;

  final Map<int, int> _parents;
  final List<_SpringJointState> _states = [];
  VrmSceneBinding? _binding;
  var _initialized = false;
  var _stepAccumulatorSeconds = 0.0;

  /// Optional fixed step in seconds. When null, each update uses its frame dt.
  double? fixedTimeStepSeconds;

  /// Maximum fixed substeps consumed by one frame.
  ///
  /// Excess whole-step backlog is discarded.
  int maxSubSteps = 4;

  /// Clears simulated state so the next frame starts from the rest pose.
  void reset() {
    _binding = null;
    _clearSimulation();
  }

  void _clearSimulation() {
    _states.clear();
    _initialized = false;
    _stepAccumulatorSeconds = 0;
  }

  /// Applies one deterministic SpringBone step to [binding].
  void applyTo(VrmSceneBinding binding, double deltaSeconds) {
    if (!identical(_binding, binding)) {
      _clearSimulation();
      _binding = binding;
    }
    final springBone = model.springBone;
    if (springBone == null || springBone.springs.isEmpty) return;
    if (springBone.sourceVersion == VrmSourceVersion.vrm1 &&
        springBone.specVersion != '1.0') {
      return;
    }
    if (springBone.sourceVersion == VrmSourceVersion.vrm0 &&
        springBone.specVersion != '0.0') {
      return;
    }
    if (!_initialized) {
      _initialize(springBone, binding);
    }
    final dt = deltaSeconds.isFinite ? math.max(0.0, deltaSeconds) : 0.0;
    final fixedStep = fixedTimeStepSeconds;
    if (fixedStep != null && fixedStep.isFinite && fixedStep > 0) {
      _stepAccumulatorSeconds += dt;
      var steps = 0;
      final stepLimit = maxSubSteps < 0 ? 0 : maxSubSteps;
      while (_stepAccumulatorSeconds >= fixedStep && steps < stepLimit) {
        _step(fixedStep);
        _stepAccumulatorSeconds -= fixedStep;
        steps++;
      }
      if (_stepAccumulatorSeconds >= fixedStep) {
        _stepAccumulatorSeconds %= fixedStep;
      }
      if (steps == 0) _step(0);
      return;
    }
    _step(dt);
  }

  void _step(double dt) {
    final rootTransform = springRootTransform(_binding);
    for (final state in _states) {
      final scratch = state.scratch;
      final head = scratch.head;
      final referenceTail = scratch.referenceTail;
      springReferenceWorldPointInto(
        state.nodePath,
        VrmVector3.zero,
        rootTransform,
        head,
      );
      springReferenceWorldPointInto(
        state.nodePath,
        state.initialLocalTail,
        rootTransform,
        referenceTail,
      );
      final axisX = referenceTail.x - head.x;
      final axisY = referenceTail.y - head.y;
      final axisZ = referenceTail.z - head.z;
      final boneLength = math.sqrt(
        axisX * axisX + axisY * axisY + axisZ * axisZ,
      );
      if (boneLength == 0) continue;
      final inverseBoneLength = 1 / boneLength;
      final currentTail = scratch.currentTail;
      springCenterToWorldInto(
        state.centerPath,
        rootTransform,
        state.currentTail,
        currentTail,
      );
      final nextTail = scratch.nextTail..copyFrom(currentTail);
      if (dt > 0) {
        final inertiaScale = 1 - clamp01(state.joint.dragForce);
        final temporary = scratch.temporary;
        temporary.set(
          state.currentTail.x +
              (state.currentTail.x - state.previousTail.x) * inertiaScale,
          state.currentTail.y +
              (state.currentTail.y - state.previousTail.y) * inertiaScale,
          state.currentTail.z +
              (state.currentTail.z - state.previousTail.z) * inertiaScale,
        );
        springCenterToWorldInto(
          state.centerPath,
          rootTransform,
          temporary,
          nextTail,
        );
        final stiffness = state.joint.stiffness * dt * inverseBoneLength;
        nextTail.set(
          nextTail.x + axisX * stiffness + state.gravity.x * dt,
          nextTail.y + axisY * stiffness + state.gravity.y * dt,
          nextTail.z + axisZ * stiffness + state.gravity.z * dt,
        );
        springConstrainTail(head, nextTail, boneLength);
      }

      final scaledHitRadius =
          state.joint.hitRadius *
          springPathUniformScale(state.nodePath, rootTransform);
      for (final collider in state.colliders) {
        _collideSpringTail(
          collider: collider,
          tail: nextTail,
          hitRadius: scaledHitRadius,
          rootTransform: rootTransform,
          scratch: scratch,
        );
        springConstrainTail(head, nextTail, boneLength);
      }

      if (dt > 0 ||
          nextTail.x != currentTail.x ||
          nextTail.y != currentTail.y ||
          nextTail.z != currentTail.z) {
        state.previousTail.copyFrom(state.currentTail);
        springWorldToCenterInto(
          state.centerPath,
          rootTransform,
          nextTail,
          state.currentTail,
        );
      }
      final localTail = scratch.localTail;
      springWorldToReferenceLocalInto(
        state.nodePath,
        rootTransform,
        nextTail,
        localTail,
      );
      springLocalRotation(
        state.boneAxis,
        localTail,
        state.initialLocalRotation,
        state.rotationScratch,
      );
      final nodeBinding = state.nodePath.bindings.first;
      final current = nodeBinding.localTransform;
      nodeBinding.localTransform = springOutputTransform(
        current,
        state.rotationScratch,
      );
    }
  }

  void _initialize(VrmSpringBone springBone, VrmSceneBinding binding) {
    _states.clear();
    final duplicateJointNodes = _duplicateSpringJointNodes(springBone);
    final paths = <int, SpringNodePath>{};
    final rootTransform = springRootTransform(binding);

    SpringNodePath? resolvePath(int? nodeIndex) {
      if (nodeIndex == null) return null;
      return paths.putIfAbsent(nodeIndex, () {
        final nodes = <GltfNode>[];
        final bindings = <VrmNodeBinding>[];
        final seen = <int>{};
        int? current = nodeIndex;
        while (current != null && seen.add(current)) {
          final node = model.gltf.nodes.elementAtOrNull(current);
          if (node == null) break;
          nodes.add(node);
          bindings.add(binding.nodeByGltfIndex(current));
          current = _parents[current];
        }
        return SpringNodePath(
          List.unmodifiable(nodes),
          List.unmodifiable(bindings),
        );
      });
    }

    for (final spring in springBone.springs) {
      if (!_springHasRunnableJoints(springBone, spring, duplicateJointNodes)) {
        continue;
      }
      final colliders = <_SpringColliderState>[];
      for (final groupIndex in spring.colliderGroups) {
        final group = springBone.colliderGroups.elementAtOrNull(groupIndex);
        for (final colliderIndex in group?.colliders ?? const <int>[]) {
          final collider = springBone.colliders.elementAtOrNull(colliderIndex);
          if (!_springColliderIsRunnable(collider)) continue;
          final shape = collider!.shape;
          final nodePath = resolvePath(collider.node)!;
          colliders.add(
            _SpringColliderState(
              type: shape.type!,
              nodePath: nodePath,
              offset: springVector(shape.offset),
              tail: springVector(shape.tail ?? const [0, 0, 0]),
              radius: shape.radius,
            ),
          );
        }
      }
      final immutableColliders = List<_SpringColliderState>.unmodifiable(
        colliders,
      );
      final centerPath = resolvePath(spring.center);

      void addState(
        VrmSpringBoneJoint joint,
        GltfNode gltfNode,
        SpringNodePath nodePath,
        VrmVector3 initialLocalTail,
        VrmVector3 restModelTail,
      ) {
        final length = math.sqrt(
          initialLocalTail.x * initialLocalTail.x +
              initialLocalTail.y * initialLocalTail.y +
              initialLocalTail.z * initialLocalTail.z,
        );
        if (length == 0) return;
        final simulationTail = springInitialTail(
          centerPath,
          rootTransform,
          restModelTail,
        );
        _states.add(
          _SpringJointState(
            centerPath: centerPath,
            nodePath: nodePath,
            joint: joint,
            colliders: immutableColliders,
            previousTail: simulationTail,
            currentTail: simulationTail,
            boneAxis: initialLocalTail * (1 / length),
            initialLocalTail: initialLocalTail,
            initialLocalRotation: gltfNode.restRotation,
            gravity:
                sourceDirectionToRuntime(
                  model.sourceVersion,
                  springVector(joint.gravityDir),
                ) *
                joint.gravityPower,
          ),
        );
      }

      void addStateWithNodeTail(
        VrmSpringBoneJoint joint,
        GltfNode gltfNode,
        SpringNodePath nodePath,
        int tailNode,
      ) {
        final tailPath = resolvePath(tailNode);
        if (tailPath == null) return;
        final tail = springRestPathPoint(tailPath, VrmVector3.zero);
        addState(
          joint,
          gltfNode,
          nodePath,
          springInverseRestPathPoint(nodePath, tail),
          tail,
        );
      }

      void addLegacyLeafState(
        VrmSpringBoneJoint joint,
        GltfNode gltfNode,
        SpringNodePath nodePath,
        double terminalLength,
      ) {
        final head = springRestPathPoint(nodePath, VrmVector3.zero);
        final parentPath = resolvePath(_parents[gltfNode.index]);
        final parentHead = parentPath == null
            ? VrmVector3.zero
            : springRestPathPoint(parentPath, VrmVector3.zero);
        final direction = head - parentHead;
        final directionLength = math.sqrt(
          direction.x * direction.x +
              direction.y * direction.y +
              direction.z * direction.z,
        );
        if (directionLength == 0) return;
        final tail = head + direction * (terminalLength / directionLength);
        addState(
          joint,
          gltfNode,
          nodePath,
          springInverseRestPathPoint(nodePath, tail),
          tail,
        );
      }

      if (springBone.sourceVersion == VrmSourceVersion.vrm0) {
        final terminalLength = spring.legacyTerminalLength ?? 0;
        for (final joint in spring.joints) {
          final node = joint.node;
          final gltfNode = node == null
              ? null
              : model.gltf.nodes.elementAtOrNull(node);
          if (gltfNode == null) continue;
          final nodePath = resolvePath(node)!;
          if (gltfNode.children.isNotEmpty) {
            addStateWithNodeTail(
              joint,
              gltfNode,
              nodePath,
              gltfNode.children.first,
            );
          } else if (terminalLength > 0) {
            addLegacyLeafState(joint, gltfNode, nodePath, terminalLength);
          }
        }
      } else {
        for (var i = 0; i + 1 < spring.joints.length; i++) {
          final joint = spring.joints[i];
          final node = joint.node;
          final tailNode = spring.joints[i + 1].node;
          if (node == null || tailNode == null) continue;
          final gltfNode = model.gltf.nodes.elementAtOrNull(node);
          if (gltfNode == null) continue;
          addStateWithNodeTail(joint, gltfNode, resolvePath(node)!, tailNode);
        }
      }
    }
    _states.sort((a, b) {
      final depth = a.nodePath.nodes.length.compareTo(b.nodePath.nodes.length);
      if (depth != 0) return depth;
      return a.nodePath.nodes.first.index.compareTo(
        b.nodePath.nodes.first.index,
      );
    });
    _initialized = true;
  }

  bool _springHasRunnableJoints(
    VrmSpringBone springBone,
    VrmSpringBoneSpring spring,
    Set<int> duplicateJointNodes,
  ) {
    if (spring.joints.isEmpty) return false;
    for (var i = 0; i < spring.joints.length; i++) {
      final node = spring.joints[i].node;
      if (node == null || model.gltf.nodes.elementAtOrNull(node) == null) {
        return false;
      }
      if (duplicateJointNodes.contains(node)) return false;
      if (springBone.sourceVersion == VrmSourceVersion.vrm1 &&
          i > 0 &&
          !isDescendantOf(node, spring.joints[i - 1].node!, _parents)) {
        return false;
      }
      if (!_springJointParametersAreValid(spring.joints[i])) return false;
    }
    final center = spring.center;
    if (center == null) return true;
    if (model.gltf.nodes.elementAtOrNull(center) == null) return false;
    if (springBone.sourceVersion == VrmSourceVersion.vrm0) return true;
    final firstNode = spring.joints.first.node!;
    if (center != firstNode && !isDescendantOf(firstNode, center, _parents)) {
      return false;
    }
    for (final otherSpring in springBone.springs) {
      if (otherSpring.index == spring.index) continue;
      for (final joint in otherSpring.joints) {
        final otherNode = joint.node;
        if (otherNode == null) continue;
        if (center == otherNode ||
            isDescendantOf(center, otherNode, _parents)) {
          return false;
        }
      }
    }
    return true;
  }

  Set<int> _duplicateSpringJointNodes(VrmSpringBone springBone) {
    final seen = <int>{};
    final duplicates = <int>{};
    for (final spring in springBone.springs) {
      for (final joint in spring.joints) {
        final node = joint.node;
        if (node != null && !seen.add(node)) duplicates.add(node);
      }
    }
    return duplicates;
  }

  bool _springJointParametersAreValid(VrmSpringBoneJoint joint) {
    if (joint.hitRadius < 0 ||
        joint.stiffness < 0 ||
        joint.gravityPower < 0 ||
        joint.dragForce < 0 ||
        joint.dragForce > 1) {
      return false;
    }
    final rawGravityDir = jsonList(joint.raw['gravityDir']);
    return rawGravityDir.isEmpty ||
        (rawGravityDir.length == 3 &&
            rawGravityDir.every((value) => value is num));
  }

  bool _springColliderIsRunnable(VrmSpringBoneCollider? collider) {
    final node = collider?.node;
    final shape = collider?.shape;
    final shapeParameters = shape == null
        ? const <String, Object?>{}
        : springColliderShapeParameters(shape);
    return collider != null &&
        node != null &&
        model.gltf.nodes.elementAtOrNull(node) != null &&
        shape != null &&
        shape.declaredShapeCount == 1 &&
        shape.type != null &&
        shape.radius >= 0 &&
        (!shapeParameters.containsKey('offset') ||
            !hasInvalidNumberListLength(shapeParameters['offset'], 3)) &&
        (shape.type != VrmSpringBoneColliderShapeType.capsule ||
            !shapeParameters.containsKey('tail') ||
            !hasInvalidNumberListLength(shapeParameters['tail'], 3));
  }

  void _collideSpringTail({
    required _SpringColliderState collider,
    required SpringVector3 tail,
    required double hitRadius,
    required VrmMatrix4? rootTransform,
    required _SpringScratch scratch,
  }) {
    springPathWorldPointInto(
      collider.nodePath,
      collider.offset,
      rootTransform,
      scratch.colliderStart,
    );
    final collisionRadius =
        collider.radius *
            springPathUniformScale(collider.nodePath, rootTransform) +
        hitRadius;
    switch (collider.type) {
      case VrmSpringBoneColliderShapeType.sphere:
        springPushOutOfSphere(tail, scratch.colliderStart, collisionRadius);
        break;
      case VrmSpringBoneColliderShapeType.capsule:
        springPathWorldPointInto(
          collider.nodePath,
          collider.tail,
          rootTransform,
          scratch.colliderEnd,
        );
        springPushOutOfCapsule(
          tail,
          scratch.colliderStart,
          scratch.colliderEnd,
          collisionRadius,
        );
        break;
    }
  }
}

final class _SpringJointState {
  _SpringJointState({
    required this.centerPath,
    required this.nodePath,
    required this.joint,
    required this.colliders,
    required VrmVector3 previousTail,
    required VrmVector3 currentTail,
    required this.boneAxis,
    required this.initialLocalTail,
    required this.initialLocalRotation,
    required VrmVector3 gravity,
  }) : previousTail = SpringVector3.from(previousTail),
       currentTail = SpringVector3.from(currentTail),
       gravity = SpringVector3.from(gravity);

  final SpringNodePath? centerPath;
  final SpringNodePath nodePath;
  final VrmSpringBoneJoint joint;
  final List<_SpringColliderState> colliders;
  final SpringVector3 previousTail;
  final SpringVector3 currentTail;
  final VrmVector3 boneAxis;
  final VrmVector3 initialLocalTail;
  final List<double> initialLocalRotation;
  final SpringVector3 gravity;
  final _SpringScratch scratch = _SpringScratch();
  final List<double> rotationScratch = List<double>.filled(4, 0);
}

final class _SpringScratch {
  final SpringVector3 head = SpringVector3();
  final SpringVector3 referenceTail = SpringVector3();
  final SpringVector3 currentTail = SpringVector3();
  final SpringVector3 nextTail = SpringVector3();
  final SpringVector3 temporary = SpringVector3();
  final SpringVector3 localTail = SpringVector3();
  final SpringVector3 colliderStart = SpringVector3();
  final SpringVector3 colliderEnd = SpringVector3();
}

final class _SpringColliderState {
  const _SpringColliderState({
    required this.type,
    required this.nodePath,
    required this.offset,
    required this.tail,
    required this.radius,
  });

  final VrmSpringBoneColliderShapeType type;
  final SpringNodePath nodePath;
  final VrmVector3 offset;
  final VrmVector3 tail;
  final double radius;
}
