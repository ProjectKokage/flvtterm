part of '../flvtterm.dart';

/// VRMC_node_constraint kind.
enum VrmNodeConstraintKind {
  /// Roll constraint.
  roll('roll'),

  /// Aim constraint.
  aim('aim'),

  /// Rotation constraint.
  rotation('rotation');

  const VrmNodeConstraintKind(this.specName);

  /// Raw constraint object key.
  final String specName;
}

/// Roll axis for a node constraint.
enum VrmNodeConstraintRollAxis {
  /// X axis.
  x('X'),

  /// Y axis.
  y('Y'),

  /// Z axis.
  z('Z');

  const VrmNodeConstraintRollAxis(this.specName);

  /// Raw spec name.
  final String specName;

  /// Looks up a roll axis by raw spec name.
  static VrmNodeConstraintRollAxis? fromSpecName(String? name) {
    for (final value in values) {
      if (value.specName == name) return value;
    }
    return null;
  }
}

/// Aim axis for a node constraint.
enum VrmNodeConstraintAimAxis {
  /// Positive X axis.
  positiveX('PositiveX'),

  /// Negative X axis.
  negativeX('NegativeX'),

  /// Positive Y axis.
  positiveY('PositiveY'),

  /// Negative Y axis.
  negativeY('NegativeY'),

  /// Positive Z axis.
  positiveZ('PositiveZ'),

  /// Negative Z axis.
  negativeZ('NegativeZ');

  const VrmNodeConstraintAimAxis(this.specName);

  /// Raw spec name.
  final String specName;

  /// Looks up an aim axis by raw spec name.
  static VrmNodeConstraintAimAxis? fromSpecName(String? name) {
    for (final value in values) {
      if (value.specName == name) return value;
    }
    return null;
  }
}

/// Parsed `VRMC_node_constraint` extension on a glTF node.
final class VrmNodeConstraint {
  VrmNodeConstraint._({
    required this.destinationNode,
    required this.specVersion,
    required this.kind,
    required this.declaredKindCount,
    required this.source,
    required this.weight,
    required this.rollAxis,
    required this.aimAxis,
    required Map<String, Object?> raw,
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Node index being constrained.
  final int destinationNode;

  /// VRMC_node_constraint spec version.
  final String? specVersion;

  /// Constraint kind parsed from the extension.
  final VrmNodeConstraintKind? kind;

  /// Number of constraint kinds declared by the source JSON.
  final int declaredKindCount;

  /// Source node index.
  final int? source;

  /// Constraint weight.
  final double weight;

  /// Roll axis, for roll constraints.
  final VrmNodeConstraintRollAxis? rollAxis;

  /// Aim axis, for aim constraints.
  final VrmNodeConstraintAimAxis? aimAxis;

  /// Raw extension object, preserved.
  final Map<String, Object?> raw;
}
