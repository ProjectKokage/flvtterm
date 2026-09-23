part of '../../flvtterm.dart';

GltfNodePose? _capturedNodePose(VrmMatrix4 matrix) {
  final values = matrix.storage;
  if (values.any((value) => !value.isFinite)) return null;
  final scale = _matrixScale(matrix);
  if (scale.any((value) => value < 1e-12 || !value.isFinite)) return null;
  final determinant =
      values[0] * (values[5] * values[10] - values[9] * values[6]) -
      values[4] * (values[1] * values[10] - values[9] * values[2]) +
      values[8] * (values[1] * values[6] - values[5] * values[2]);
  if (!determinant.isFinite || determinant.abs() < 1e-12) return null;
  if (determinant < 0) scale[0] = -scale[0];
  final normalized = VrmMatrix4([
    for (var column = 0; column < 4; column++)
      for (var row = 0; row < 4; row++)
        column < 3 && row < 3
            ? values[column * 4 + row] / scale[column]
            : (column == row ? 1.0 : 0.0),
  ]);
  final rotation = _matrixRotation(normalized, fallback: const [0, 0, 0, 1]);
  final translation = _matrixTranslation(matrix);
  final reconstructed = _trsMatrix(translation, rotation, scale).storage;
  for (var i = 0; i < 16; i++) {
    if (!reconstructed[i].isFinite ||
        (reconstructed[i] - values[i]).abs() >
            1e-8 * math.max(1, values[i].abs())) {
      return null;
    }
  }
  return GltfNodePose(
    translation: translation,
    rotation: rotation,
    scale: scale,
  );
}

VrmVector3 _worldTargetToModel(
  VrmVector3 target,
  VrmMatrix4? modelWorldTransform,
) {
  if (modelWorldTransform == null) return target;
  return _inverseTransformPoint(modelWorldTransform, target);
}

VrmVector3 _inverseTransformPoint(VrmMatrix4 matrix, VrmVector3 point) {
  final m = matrix.storage;
  final a = m[0];
  final b = m[4];
  final c = m[8];
  final d = m[1];
  final e = m[5];
  final f = m[9];
  final g = m[2];
  final h = m[6];
  final i = m[10];
  final determinant =
      a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
  if (determinant.abs() < 1e-12) return point;
  final invDeterminant = 1 / determinant;
  final x = point.x - m[12];
  final y = point.y - m[13];
  final z = point.z - m[14];
  return VrmVector3(
    ((e * i - f * h) * x + (c * h - b * i) * y + (b * f - c * e) * z) *
        invDeterminant,
    ((f * g - d * i) * x + (a * i - c * g) * y + (c * d - a * f) * z) *
        invDeterminant,
    ((d * h - e * g) * x + (b * g - a * h) * y + (a * e - b * d) * z) *
        invDeterminant,
  );
}

VrmMatrix4? _modelTransformForNode(
  GltfAsset gltf,
  int nodeIndex,
  VrmMatrix4 Function(GltfNode node) localTransform,
) {
  final parents = _nodeParents(gltf);
  var current = nodeIndex;
  final chain = <GltfNode>[];
  while (true) {
    final node = gltf.nodes.elementAtOrNull(current);
    if (node == null) break;
    chain.add(node);
    final parent = parents[current];
    if (parent == null) break;
    current = parent;
  }
  if (chain.isEmpty) return null;
  var result = VrmMatrix4.identity();
  for (final node in chain.reversed) {
    result = _multiplyMatrices(result, localTransform(node));
  }
  return result;
}
