part of '../flvtterm.dart';

/// Parsed glTF scene.
final class GltfScene {
  GltfScene._({
    required this.index,
    required this.name,
    required List<int> nodes,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : nodes = List.unmodifiable(nodes),
       extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// glTF scene index.
  final int index;

  /// Optional scene name.
  final String? name;

  /// Root node indices for the scene.
  final List<int> nodes;

  /// Scene extensions, preserved.
  final Map<String, Object?> extensions;

  /// Scene extras, preserved.
  final Object? extras;
}

/// Parsed glTF node.
final class GltfNode {
  GltfNode._({
    required this.index,
    required this.name,
    required List<int> children,
    required this.camera,
    required this.mesh,
    required this.skin,
    required this.matrix,
    required List<double> translation,
    required List<double> rotation,
    required List<double> scale,
    required List<double> weights,
    required this.nodeConstraint,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : children = List.unmodifiable(children),
       translation = List.unmodifiable(translation),
       rotation = List.unmodifiable(rotation),
       scale = List.unmodifiable(scale),
       weights = List.unmodifiable(weights),
       extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// glTF node index.
  final int index;

  /// Optional glTF node name.
  final String? name;

  /// Child node indices.
  final List<int> children;

  /// Referenced camera index, if any.
  final int? camera;

  /// Referenced mesh index, if any.
  final int? mesh;

  /// Referenced skin index, if any.
  final int? skin;

  /// Local matrix transform, when the node uses matrix form.
  final VrmMatrix4? matrix;

  /// Local translation, defaulting to `[0, 0, 0]`.
  final List<double> translation;

  /// Local rotation quaternion, defaulting to `[0, 0, 0, 1]`.
  final List<double> rotation;

  /// Local scale, defaulting to `[1, 1, 1]`.
  final List<double> scale;

  /// Initial morph target weights for this node.
  final List<double> weights;

  /// VRMC_node_constraint metadata, when present.
  final VrmNodeConstraint? nodeConstraint;

  /// Unknown or known node extensions, preserved.
  final Map<String, Object?> extensions;

  /// Node extras, preserved.
  final Object? extras;

  /// Rest local translation after applying matrix fallback.
  List<double> get restTranslation => matrix == null
      ? translation
      : _matrixTranslation(matrix!, fallback: translation);

  /// Rest local rotation after applying matrix fallback.
  List<double> get restRotation =>
      matrix == null ? rotation : _matrixRotation(matrix!, fallback: rotation);

  /// Rest local scale after applying matrix fallback.
  List<double> get restScale =>
      matrix == null ? scale : _matrixScale(matrix!, fallback: scale);

  /// Rest local transform.
  VrmMatrix4 get restTransform =>
      matrix ?? _trsMatrix(translation, rotation, scale);
}
