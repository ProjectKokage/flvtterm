part of '../../flvtterm.dart';

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
      final sourceCurrent = _matrixRotation(
        sourceBinding.localTransform,
        fallback: sourceNode.restRotation,
      );
      final targetRotation = switch (constraint.kind!) {
        VrmNodeConstraintKind.rotation => _rotationConstraint(
          sourceRest: sourceNode.restRotation,
          sourceCurrent: sourceCurrent,
          destinationRest: destinationNode.restRotation,
        ),
        VrmNodeConstraintKind.roll => _rollConstraint(
          sourceRest: sourceNode.restRotation,
          sourceCurrent: sourceCurrent,
          destinationRest: destinationNode.restRotation,
          axis: constraint.rollAxis,
        ),
        VrmNodeConstraintKind.aim => _aimConstraint(
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
        final outputRotation = _slerp(
          destinationNode.restRotation,
          targetRotation,
          _clamp01(constraint.weight),
        );
        final current = destinationBinding.localTransform;
        destinationBinding.localTransform = _trsMatrix(
          _matrixTranslation(current),
          outputRotation,
          _matrixScale(current),
        );
      }
    }
  }

  List<double> _parentWorldRotation(VrmSceneBinding binding, int? parent) {
    if (parent == null) return const [0, 0, 0, 1];
    return _matrixRotation(
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
  final parents = _nodeParents(gltf);
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
        !_constraintHasValidWeight(constraint) ||
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
