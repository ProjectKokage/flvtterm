import '../gltf/animation_math.dart';
import '../gltf/gltf_node_constraint_types.dart';
import '../gltf/gltf_node_constraint_validation.dart';
import '../gltf/gltf_scene_types.dart';
import '../gltf/gltf_types.dart';
import '../matrix_math.dart';
import '../safe_list_index.dart';
import '../vrm/vrm_assets.dart';
import '../vrm/vrm_humanoid_parser.dart';
import 'constraint_math.dart';
import 'scene_binding.dart';

/// Evaluates `VRMC_node_constraint` runtime rotations.
final class VrmNodeConstraintController {
  /// Creates a constraint controller for [model].
  VrmNodeConstraintController(this.model)
    : _plan = _buildConstraintPlan(model.gltf);

  /// Parsed model backing this controller.
  final VrmModel model;
  final List<_RunnableNodeConstraint> _plan;

  /// Applies all node constraints to [binding].
  void applyTo(VrmSceneBinding binding) {
    for (final entry in _plan) {
      final constraint = entry.constraint;
      final sourceNode = entry.source;
      final destinationNode = entry.destination;
      final sourceBinding = binding.nodeByGltfIndex(sourceNode.index);
      final destinationBinding = binding.nodeByGltfIndex(destinationNode.index);
      final sourceCurrent = matrixRotation(
        sourceBinding.localTransform,
        fallback: sourceNode.restRotation,
      );
      final targetRotation = switch (constraint.kind!) {
        VrmNodeConstraintKind.rotation => rotationConstraint(
          sourceRest: sourceNode.restRotation,
          sourceCurrent: sourceCurrent,
          destinationRest: destinationNode.restRotation,
        ),
        VrmNodeConstraintKind.roll => rollConstraint(
          sourceRest: sourceNode.restRotation,
          sourceCurrent: sourceCurrent,
          destinationRest: destinationNode.restRotation,
          axis: constraint.rollAxis,
        ),
        VrmNodeConstraintKind.aim => aimConstraint(
          source: sourceBinding,
          destination: destinationBinding,
          destinationRest: destinationNode.restRotation,
          parentWorldRotation: _parentWorldRotation(
            binding,
            entry.destinationParent,
          ),
          axis: constraint.aimAxis,
        ),
      };
      if (targetRotation != null) {
        final outputRotation = slerp(
          destinationNode.restRotation,
          targetRotation,
          clamp01(constraint.weight),
        );
        final current = destinationBinding.localTransform;
        destinationBinding.localTransform = trsMatrix(
          matrixTranslation(current),
          outputRotation,
          matrixScale(current),
        );
      }
    }
  }

  List<double> _parentWorldRotation(VrmSceneBinding binding, int? parent) {
    if (parent == null) return const [0, 0, 0, 1];
    return matrixRotation(
      binding.nodeByGltfIndex(parent).worldTransform,
      fallback: const [0, 0, 0, 1],
    );
  }
}

final class _RunnableNodeConstraint {
  const _RunnableNodeConstraint({
    required this.constraint,
    required this.source,
    required this.destination,
    required this.destinationParent,
  });

  final VrmNodeConstraint constraint;
  final GltfNode source;
  final GltfNode destination;
  final int? destinationParent;
}

List<_RunnableNodeConstraint> _buildConstraintPlan(GltfAsset gltf) {
  final nodes = gltf.nodes;
  final parents = nodeParents(gltf);
  final candidates = <int, _RunnableNodeConstraint>{};
  for (final destination in nodes) {
    final constraint = destination.nodeConstraint;
    final sourceIndex = constraint?.source;
    final source = sourceIndex == null
        ? null
        : nodes.elementAtOrNull(sourceIndex);
    if (constraint == null ||
        constraint.specVersion != '1.0' ||
        constraint.declaredKindCount != 1 ||
        constraint.kind == null ||
        !constraintHasValidWeight(constraint) ||
        source == null ||
        source.index == destination.index) {
      continue;
    }
    candidates[destination.index] = _RunnableNodeConstraint(
      constraint: constraint,
      source: source,
      destination: destination,
      destinationParent: parents[destination.index],
    );
  }

  final cyclicOrDependent = <int>{};
  for (final destination in candidates.keys) {
    final path = <int>[];
    final seen = <int>{};
    var current = destination;
    while (candidates.containsKey(current)) {
      if (cyclicOrDependent.contains(current) || !seen.add(current)) {
        cyclicOrDependent.addAll(path);
        break;
      }
      path.add(current);
      current = candidates[current]!.source.index;
    }
  }
  candidates.removeWhere(
    (destination, _) => cyclicOrDependent.contains(destination),
  );

  final ordered = <_RunnableNodeConstraint>[];
  final added = <int>{};
  void addWithDependencies(int destination) {
    if (!added.add(destination)) return;
    final candidate = candidates[destination];
    if (candidate == null) return;
    if (candidates.containsKey(candidate.source.index)) {
      addWithDependencies(candidate.source.index);
    }
    ordered.add(candidate);
  }

  for (final destination in candidates.keys) {
    addWithDependencies(destination);
  }
  return List.unmodifiable(ordered);
}
