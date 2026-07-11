part of '../../flvtterm.dart';

/// Parsed glTF mesh.
final class GltfMesh {
  GltfMesh._({
    required this.index,
    required this.name,
    required List<GltfMeshPrimitive> primitives,
    required List<double> weights,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : primitives = List.unmodifiable(primitives),
       weights = List.unmodifiable(weights),
       extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// glTF mesh index.
  final int index;

  /// Optional mesh name.
  final String? name;

  /// Mesh primitives.
  final List<GltfMeshPrimitive> primitives;

  /// Default morph target weights for mesh instances.
  final List<double> weights;

  /// Mesh extensions, preserved.
  final Map<String, Object?> extensions;

  /// Mesh extras, preserved.
  final Object? extras;
}

/// Parsed glTF mesh primitive.
final class GltfMeshPrimitive {
  GltfMeshPrimitive._({
    required this.mode,
    required this.material,
    required this.indices,
    required Map<String, int> attributes,
    required List<Map<String, int>> targets,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : attributes = Map.unmodifiable(attributes),
       targets = List.unmodifiable(targets),
       extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// Primitive drawing mode. Defaults to triangles (`4`).
  final int mode;

  /// Referenced material index, if any.
  final int? material;

  /// Referenced index accessor, if any.
  final int? indices;

  /// Attribute semantic to accessor index.
  final Map<String, int> attributes;

  /// Morph target attribute maps.
  final List<Map<String, int>> targets;

  /// Primitive extensions, preserved.
  final Map<String, Object?> extensions;

  /// Primitive extras, preserved.
  final Object? extras;
}
