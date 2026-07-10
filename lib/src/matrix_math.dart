part of '../flvtterm.dart';

VrmMatrix4 _trsMatrix(
  List<double> translation,
  List<double> rotation,
  List<double> scale,
) {
  final x = rotation[0];
  final y = rotation[1];
  final z = rotation[2];
  final w = rotation[3];
  final sx = scale[0];
  final sy = scale[1];
  final sz = scale[2];
  final xx = x * x;
  final xy = x * y;
  final xz = x * z;
  final xw = x * w;
  final yy = y * y;
  final yz = y * z;
  final yw = y * w;
  final zz = z * z;
  final zw = z * w;

  return VrmMatrix4([
    (1 - 2 * (yy + zz)) * sx,
    2 * (xy + zw) * sx,
    2 * (xz - yw) * sx,
    0,
    2 * (xy - zw) * sy,
    (1 - 2 * (xx + zz)) * sy,
    2 * (yz + xw) * sy,
    0,
    2 * (xz + yw) * sz,
    2 * (yz - xw) * sz,
    (1 - 2 * (xx + yy)) * sz,
    0,
    translation[0],
    translation[1],
    translation[2],
    1,
  ]);
}

List<double> _matrixTranslation(
  VrmMatrix4 matrix, {
  required List<double> fallback,
}) {
  if (_isIdentityMatrix(matrix)) return fallback;
  return [matrix.storage[12], matrix.storage[13], matrix.storage[14]];
}

VrmVector3 _matrixPosition(VrmMatrix4 matrix, {required VrmVector3 fallback}) {
  if (_isIdentityMatrix(matrix)) return fallback;
  return VrmVector3(matrix.storage[12], matrix.storage[13], matrix.storage[14]);
}

VrmMatrix4 _multiplyMatrices(VrmMatrix4 a, VrmMatrix4 b) {
  final left = a.storage;
  final right = b.storage;
  return VrmMatrix4([
    for (var column = 0; column < 4; column++)
      for (var row = 0; row < 4; row++)
        left[row] * right[column * 4] +
            left[row + 4] * right[column * 4 + 1] +
            left[row + 8] * right[column * 4 + 2] +
            left[row + 12] * right[column * 4 + 3],
  ]);
}

VrmVector3 _transformPoint(VrmMatrix4 matrix, VrmVector3 point) {
  final m = matrix.storage;
  return VrmVector3(
    point.x * m[0] + point.y * m[4] + point.z * m[8] + m[12],
    point.x * m[1] + point.y * m[5] + point.z * m[9] + m[13],
    point.x * m[2] + point.y * m[6] + point.z * m[10] + m[14],
  );
}

List<double> _matrixScale(VrmMatrix4 matrix, {required List<double> fallback}) {
  if (_isIdentityMatrix(matrix)) return fallback;
  final m = matrix.storage;
  return [
    math.sqrt(m[0] * m[0] + m[1] * m[1] + m[2] * m[2]),
    math.sqrt(m[4] * m[4] + m[5] * m[5] + m[6] * m[6]),
    math.sqrt(m[8] * m[8] + m[9] * m[9] + m[10] * m[10]),
  ];
}

List<double> _matrixRotation(
  VrmMatrix4 matrix, {
  required List<double> fallback,
}) {
  if (_isIdentityMatrix(matrix)) return fallback;
  final m = matrix.storage;
  final scale = _matrixScale(matrix, fallback: const [1, 1, 1]);
  final m00 = m[0] / scale[0];
  final m01 = m[4] / scale[1];
  final m02 = m[8] / scale[2];
  final m10 = m[1] / scale[0];
  final m11 = m[5] / scale[1];
  final m12 = m[9] / scale[2];
  final m20 = m[2] / scale[0];
  final m21 = m[6] / scale[1];
  final m22 = m[10] / scale[2];
  final trace = m00 + m11 + m22;
  if (trace > 0) {
    final s = math.sqrt(trace + 1) * 2;
    return _normalize([
      (m21 - m12) / s,
      (m02 - m20) / s,
      (m10 - m01) / s,
      0.25 * s,
    ]);
  }
  if (m00 > m11 && m00 > m22) {
    final s = math.sqrt(1 + m00 - m11 - m22) * 2;
    return _normalize([
      0.25 * s,
      (m01 + m10) / s,
      (m02 + m20) / s,
      (m21 - m12) / s,
    ]);
  }
  if (m11 > m22) {
    final s = math.sqrt(1 + m11 - m00 - m22) * 2;
    return _normalize([
      (m01 + m10) / s,
      0.25 * s,
      (m12 + m21) / s,
      (m02 - m20) / s,
    ]);
  }
  final s = math.sqrt(1 + m22 - m00 - m11) * 2;
  return _normalize([
    (m02 + m20) / s,
    (m12 + m21) / s,
    0.25 * s,
    (m10 - m01) / s,
  ]);
}

bool _isIdentityMatrix(VrmMatrix4 matrix) {
  final m = matrix.storage;
  const identity = [
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
  ];
  for (var i = 0; i < identity.length; i++) {
    if (m[i] != identity[i]) return false;
  }
  return true;
}
