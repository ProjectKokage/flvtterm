part of '../../flvtterm.dart';

bool _constraintHasValidWeight(VrmNodeConstraint constraint) {
  final parameters = _nodeConstraintParameters(constraint);
  return (!parameters.containsKey('weight') ||
          _double(parameters['weight']) != null) &&
      constraint.weight >= 0 &&
      constraint.weight <= 1;
}

void _validateNodeConstraints(GltfAsset gltf, _DiagnosticSink sink) {
  final constraints = <int, VrmNodeConstraint>{};
  for (final node in gltf.nodes) {
    final constraint = node.nodeConstraint;
    if (constraint == null) continue;
    constraints[node.index] = constraint;

    if (!constraint.raw.containsKey('specVersion')) {
      sink.error(
        'constraint.missingSpecVersion',
        'VRMC_node_constraint.specVersion is required.',
        jsonPath: _nodeConstraintPath(node.index, '.specVersion'),
        gltfNodeIndex: node.index,
      );
    } else if (constraint.specVersion != '1.0') {
      sink.error(
        'constraint.unsupportedSpecVersion',
        'VRMC_node_constraint.specVersion must be "1.0".',
        jsonPath: _nodeConstraintPath(node.index, '.specVersion'),
        gltfNodeIndex: node.index,
      );
    }
    final hasConstraint = constraint.raw.containsKey('constraint');
    if (!hasConstraint) {
      sink.error(
        'constraint.missingConstraint',
        'VRMC_node_constraint.constraint is required.',
        jsonPath: _nodeConstraintPath(node.index, '.constraint'),
        gltfNodeIndex: node.index,
      );
    } else if (constraint.declaredKindCount != 1) {
      sink.error(
        'constraint.invalidKindCount',
        'A node constraint must declare exactly one of roll, aim, or rotation.',
        jsonPath: _nodeConstraintPath(node.index, '.constraint'),
        gltfNodeIndex: node.index,
      );
    }
    final source = constraint.source;
    final parameters = _nodeConstraintParameters(constraint);
    final hasSource = parameters.containsKey('source');
    if (hasSource && parameters['source'] is! int) {
      sink.error(
        'constraint.invalidSource',
        'A node constraint source must be an integer node index.',
        jsonPath: _nodeConstraintParameterPath(constraint, '.source'),
        gltfNodeIndex: node.index,
      );
    }
    if (source == null && !hasSource) {
      sink.error(
        'constraint.missingSource',
        'A node constraint must specify a source node.',
        jsonPath: _nodeConstraintParameterPath(constraint, '.source'),
        gltfNodeIndex: node.index,
      );
    }
    if (source != null) {
      _validateIndex(
        source,
        gltf.nodes.length,
        sink,
        'constraint.invalidSource',
        _nodeConstraintParameterPath(constraint, '.source'),
        gltfNodeIndex: node.index,
      );
      if (source == node.index) {
        sink.error(
          'constraint.selfSource',
          'A node constraint source must not be the destination node.',
          jsonPath: _nodeConstraintParameterPath(constraint, '.source'),
          gltfNodeIndex: node.index,
        );
      }
    }
    if ((parameters.containsKey('weight') &&
            _double(parameters['weight']) == null) ||
        constraint.weight < 0 ||
        constraint.weight > 1) {
      sink.error(
        'constraint.invalidWeight',
        'A node constraint weight must be in [0, 1].',
        jsonPath: _nodeConstraintParameterPath(constraint, '.weight'),
        gltfNodeIndex: node.index,
      );
    }
    if (constraint.kind == VrmNodeConstraintKind.roll &&
        constraint.rollAxis == null) {
      sink.error(
        'constraint.invalidRollAxis',
        'A roll constraint must specify rollAxis X, Y, or Z.',
        jsonPath: _nodeConstraintParameterPath(constraint, '.rollAxis'),
        gltfNodeIndex: node.index,
      );
    }
    if (constraint.kind == VrmNodeConstraintKind.aim &&
        constraint.aimAxis == null) {
      sink.error(
        'constraint.invalidAimAxis',
        'An aim constraint must specify a valid aimAxis.',
        jsonPath: _nodeConstraintParameterPath(constraint, '.aimAxis'),
        gltfNodeIndex: node.index,
      );
    }
  }

  final reported = <int>{};
  for (final nodeIndex in constraints.keys) {
    final stack = <int>{};
    var current = nodeIndex;
    while (true) {
      if (!stack.add(current)) {
        if (reported.add(current)) {
          sink.error(
            'constraint.cycle',
            'Node constraints must not form cycles.',
            jsonPath: _nodeConstraintPath(current, '.constraint'),
            gltfNodeIndex: current,
          );
        }
        break;
      }
      final source = constraints[current]?.source;
      if (source == null || !constraints.containsKey(source)) break;
      current = source;
    }
  }
}

String _nodeConstraintPath(int nodeIndex, String suffix) =>
    '\$.nodes[$nodeIndex].extensions.VRMC_node_constraint$suffix';

String _nodeConstraintParameterPath(
  VrmNodeConstraint constraint,
  String suffix,
) {
  final kind = constraint.kind;
  final kindPath = kind == null ? '' : '.${kind.specName}';
  return _nodeConstraintPath(
    constraint.destinationNode,
    '.constraint$kindPath$suffix',
  );
}

Map<String, Object?> _nodeConstraintParameters(VrmNodeConstraint constraint) {
  final rawConstraint = _object(constraint.raw['constraint']);
  return switch (constraint.kind) {
    VrmNodeConstraintKind.roll => _object(rawConstraint['roll']),
    VrmNodeConstraintKind.aim => _object(rawConstraint['aim']),
    VrmNodeConstraintKind.rotation => _object(rawConstraint['rotation']),
    null => const <String, Object?>{},
  };
}

void _validateIndex(
  int index,
  int length,
  _DiagnosticSink sink,
  String code,
  String jsonPath, {
  int? gltfNodeIndex,
  int? gltfMaterialIndex,
}) {
  if (index < 0 || index >= length) {
    sink.error(
      code,
      'Index $index is outside range 0..${length - 1}.',
      jsonPath: jsonPath,
      gltfNodeIndex: gltfNodeIndex,
      gltfMaterialIndex: gltfMaterialIndex,
    );
  }
}
