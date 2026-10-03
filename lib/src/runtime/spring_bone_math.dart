import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../gltf/gltf_scene_types.dart';
import '../math_types.dart';
import '../matrix_math.dart';
import 'scene_binding.dart';

@internal
VrmVector3 springVector(List<double> value) => VrmVector3(
  value.isEmpty ? 0 : value[0],
  value.length < 2 ? 0 : value[1],
  value.length < 3 ? 0 : value[2],
);

@internal
double springPathUniformScale(SpringNodePath path, VrmMatrix4? rootTransform) {
  var scale = rootTransform == null
      ? 1.0
      : _springMatrixUniformScale(rootTransform);
  for (final binding in path.bindings) {
    scale *= _springMatrixUniformScale(binding.localTransform);
  }
  return scale;
}

double _springMatrixUniformScale(VrmMatrix4 matrix) {
  final m = matrix.storage;
  final determinant =
      m[0] * (m[5] * m[10] - m[9] * m[6]) -
      m[4] * (m[1] * m[10] - m[9] * m[2]) +
      m[8] * (m[1] * m[6] - m[5] * m[2]);
  if (!determinant.isFinite) return 1;
  return math.pow(determinant.abs(), 1 / 3).toDouble();
}

@internal
VrmVector3 springRestPathPoint(SpringNodePath path, VrmVector3 point) =>
    _springTransformPoint(path, point, rest: true, reference: false);

@internal
VrmVector3 springInverseRestPathPoint(SpringNodePath path, VrmVector3 point) =>
    _springInverseTransformPoint(path, point, rest: true, reference: false);

@internal
VrmMatrix4? springRootTransform(VrmSceneBinding? binding) {
  if (binding is VrmModelWorldBinding) {
    final transform = binding.modelWorldTransform;
    return isIdentityMatrix(transform) ? null : transform;
  }
  if (binding is! VrmModelRootBinding) return null;
  final transform = binding.modelRootMotionTransform;
  return isIdentityMatrix(transform) ? null : transform;
}

VrmVector3 _springModelToWorld(VrmMatrix4? rootTransform, VrmVector3 point) =>
    rootTransform == null ? point : transformPoint(rootTransform, point);

@internal
VrmVector3 springInitialTail(
  SpringNodePath? centerPath,
  VrmMatrix4? rootTransform,
  VrmVector3 restModelTail,
) => centerPath == null
    ? _springModelToWorld(rootTransform, restModelTail)
    : _springInverseTransformPoint(
        centerPath,
        restModelTail,
        rest: true,
        reference: false,
      );

@internal
void springReferenceWorldPointInto(
  SpringNodePath path,
  VrmVector3 point,
  VrmMatrix4? rootTransform,
  SpringVector3 out,
) {
  _springTransformPointInto(
    path,
    point.x,
    point.y,
    point.z,
    rest: false,
    reference: true,
    out: out,
  );
  _springModelToWorldInto(rootTransform, out.x, out.y, out.z, out);
}

@internal
void springPathWorldPointInto(
  SpringNodePath path,
  VrmVector3 point,
  VrmMatrix4? rootTransform,
  SpringVector3 out,
) {
  _springTransformPointInto(
    path,
    point.x,
    point.y,
    point.z,
    rest: false,
    reference: false,
    out: out,
  );
  _springModelToWorldInto(rootTransform, out.x, out.y, out.z, out);
}

@internal
void springCenterToWorldInto(
  SpringNodePath? centerPath,
  VrmMatrix4? rootTransform,
  SpringVector3 point,
  SpringVector3 out,
) {
  if (centerPath == null) {
    out.copyFrom(point);
    return;
  }
  _springTransformPointInto(
    centerPath,
    point.x,
    point.y,
    point.z,
    rest: false,
    reference: false,
    out: out,
  );
  _springModelToWorldInto(rootTransform, out.x, out.y, out.z, out);
}

@internal
void springWorldToCenterInto(
  SpringNodePath? centerPath,
  VrmMatrix4? rootTransform,
  SpringVector3 point,
  SpringVector3 out,
) {
  if (centerPath == null) {
    out.copyFrom(point);
    return;
  }
  _springWorldToModelInto(rootTransform, point.x, point.y, point.z, out);
  _springInverseTransformPointInto(
    centerPath,
    out.x,
    out.y,
    out.z,
    rest: false,
    reference: false,
    out: out,
  );
}

@internal
void springWorldToReferenceLocalInto(
  SpringNodePath path,
  VrmMatrix4? rootTransform,
  SpringVector3 point,
  SpringVector3 out,
) {
  _springWorldToModelInto(rootTransform, point.x, point.y, point.z, out);
  _springInverseTransformPointInto(
    path,
    out.x,
    out.y,
    out.z,
    rest: false,
    reference: true,
    out: out,
  );
}

void _springTransformPointInto(
  SpringNodePath path,
  double x,
  double y,
  double z, {
  required bool rest,
  required bool reference,
  required SpringVector3 out,
}) {
  for (var index = 0; index < path.nodes.length; index++) {
    final matrix = rest || (reference && index == 0)
        ? path.nodes[index].restTransform
        : path.bindings[index].localTransform;
    final m = matrix.storage;
    final nextX = x * m[0] + y * m[4] + z * m[8] + m[12];
    final nextY = x * m[1] + y * m[5] + z * m[9] + m[13];
    final nextZ = x * m[2] + y * m[6] + z * m[10] + m[14];
    x = nextX;
    y = nextY;
    z = nextZ;
  }
  out.set(x, y, z);
}

void _springInverseTransformPointInto(
  SpringNodePath path,
  double x,
  double y,
  double z, {
  required bool rest,
  required bool reference,
  required SpringVector3 out,
}) {
  for (var index = path.nodes.length - 1; index >= 0; index--) {
    final matrix = rest || (reference && index == 0)
        ? path.nodes[index].restTransform
        : path.bindings[index].localTransform;
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
    if (determinant.abs() < 1e-12) continue;
    final inverseDeterminant = 1 / determinant;
    final translatedX = x - m[12];
    final translatedY = y - m[13];
    final translatedZ = z - m[14];
    final nextX =
        ((e * i - f * h) * translatedX +
            (c * h - b * i) * translatedY +
            (b * f - c * e) * translatedZ) *
        inverseDeterminant;
    final nextY =
        ((f * g - d * i) * translatedX +
            (a * i - c * g) * translatedY +
            (c * d - a * f) * translatedZ) *
        inverseDeterminant;
    final nextZ =
        ((d * h - e * g) * translatedX +
            (b * g - a * h) * translatedY +
            (a * e - b * d) * translatedZ) *
        inverseDeterminant;
    x = nextX;
    y = nextY;
    z = nextZ;
  }
  out.set(x, y, z);
}

void _springModelToWorldInto(
  VrmMatrix4? rootTransform,
  double x,
  double y,
  double z,
  SpringVector3 out,
) {
  if (rootTransform == null) {
    out.set(x, y, z);
    return;
  }
  final m = rootTransform.storage;
  out.set(
    x * m[0] + y * m[4] + z * m[8] + m[12],
    x * m[1] + y * m[5] + z * m[9] + m[13],
    x * m[2] + y * m[6] + z * m[10] + m[14],
  );
}

void _springWorldToModelInto(
  VrmMatrix4? rootTransform,
  double x,
  double y,
  double z,
  SpringVector3 out,
) {
  if (rootTransform == null) {
    out.set(x, y, z);
    return;
  }
  final m = rootTransform.storage;
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
  if (determinant.abs() < 1e-12) {
    out.set(x, y, z);
    return;
  }
  final inverseDeterminant = 1 / determinant;
  final translatedX = x - m[12];
  final translatedY = y - m[13];
  final translatedZ = z - m[14];
  out.set(
    ((e * i - f * h) * translatedX +
            (c * h - b * i) * translatedY +
            (b * f - c * e) * translatedZ) *
        inverseDeterminant,
    ((f * g - d * i) * translatedX +
            (a * i - c * g) * translatedY +
            (c * d - a * f) * translatedZ) *
        inverseDeterminant,
    ((d * h - e * g) * translatedX +
            (b * g - a * h) * translatedY +
            (a * e - b * d) * translatedZ) *
        inverseDeterminant,
  );
}

@internal
void springConstrainTail(
  SpringVector3 head,
  SpringVector3 tail,
  double length,
) {
  final x = tail.x - head.x;
  final y = tail.y - head.y;
  final z = tail.z - head.z;
  final distance = math.sqrt(x * x + y * y + z * z);
  if (distance == 0) {
    tail.copyFrom(head);
    return;
  }
  final scale = length / distance;
  tail.set(head.x + x * scale, head.y + y * scale, head.z + z * scale);
}

@internal
void springPushOutOfSphere(
  SpringVector3 point,
  SpringVector3 center,
  double radius,
) {
  final x = point.x - center.x;
  final y = point.y - center.y;
  final z = point.z - center.z;
  final distance = math.sqrt(x * x + y * y + z * z);
  if (distance >= radius) return;
  if (distance == 0) {
    point.set(center.x, center.y + radius, center.z);
    return;
  }
  final scale = radius / distance;
  point.set(center.x + x * scale, center.y + y * scale, center.z + z * scale);
}

@internal
void springPushOutOfCapsule(
  SpringVector3 point,
  SpringVector3 start,
  SpringVector3 end,
  double radius,
) {
  final segmentX = end.x - start.x;
  final segmentY = end.y - start.y;
  final segmentZ = end.z - start.z;
  final lengthSquared =
      segmentX * segmentX + segmentY * segmentY + segmentZ * segmentZ;
  if (lengthSquared == 0) {
    springPushOutOfSphere(point, start, radius);
    return;
  }
  final pointX = point.x - start.x;
  final pointY = point.y - start.y;
  final pointZ = point.z - start.z;
  final t = math.max(
    0.0,
    math.min(
      1.0,
      (pointX * segmentX + pointY * segmentY + pointZ * segmentZ) /
          lengthSquared,
    ),
  );
  final centerX = start.x + segmentX * t;
  final centerY = start.y + segmentY * t;
  final centerZ = start.z + segmentZ * t;
  final x = point.x - centerX;
  final y = point.y - centerY;
  final z = point.z - centerZ;
  final distance = math.sqrt(x * x + y * y + z * z);
  if (distance >= radius) return;
  if (distance == 0) {
    point.set(centerX, centerY + radius, centerZ);
    return;
  }
  final scale = radius / distance;
  point.set(centerX + x * scale, centerY + y * scale, centerZ + z * scale);
}

@internal
void springLocalRotation(
  VrmVector3 from,
  SpringVector3 to,
  List<double> initialRotation,
  List<double> out,
) {
  final fromLength = math.sqrt(
    from.x * from.x + from.y * from.y + from.z * from.z,
  );
  final toLength = math.sqrt(to.x * to.x + to.y * to.y + to.z * to.z);
  final ax = fromLength == 0 ? 0.0 : from.x / fromLength;
  final ay = fromLength == 0 ? 0.0 : from.y / fromLength;
  final az = fromLength == 0 ? 0.0 : from.z / fromLength;
  final bx = toLength == 0 ? 0.0 : to.x / toLength;
  final by = toLength == 0 ? 0.0 : to.y / toLength;
  final bz = toLength == 0 ? 0.0 : to.z / toLength;
  final dot = ax * bx + ay * by + az * bz;
  var dx = 0.0;
  var dy = 0.0;
  var dz = 0.0;
  var dw = 1.0;
  if (dot < 0.999999) {
    if (dot < -0.999999) {
      final fallbackX = ax.abs() < 0.9 ? 1.0 : 0.0;
      final fallbackY = ax.abs() < 0.9 ? 0.0 : 1.0;
      dx = ay * 0 - az * fallbackY;
      dy = az * fallbackX - ax * 0;
      dz = ax * fallbackY - ay * fallbackX;
      final length = math.sqrt(dx * dx + dy * dy + dz * dz);
      if (length != 0) {
        dx /= length;
        dy /= length;
        dz /= length;
      }
      dw = 0;
    } else {
      dx = ay * bz - az * by;
      dy = az * bx - ax * bz;
      dz = ax * by - ay * bx;
      dw = 1 + dot;
      final length = math.sqrt(dx * dx + dy * dy + dz * dz + dw * dw);
      if (length != 0) {
        dx /= length;
        dy /= length;
        dz /= length;
        dw /= length;
      }
    }
  }

  final axq = initialRotation[0];
  final ayq = initialRotation[1];
  final azq = initialRotation[2];
  final awq = initialRotation[3];
  var x = awq * dx + axq * dw + ayq * dz - azq * dy;
  var y = awq * dy - axq * dz + ayq * dw + azq * dx;
  var z = awq * dz + axq * dy - ayq * dx + azq * dw;
  var w = awq * dw - axq * dx - ayq * dy - azq * dz;
  final length = math.sqrt(x * x + y * y + z * z + w * w);
  if (length != 0) {
    x /= length;
    y /= length;
    z /= length;
    w /= length;
  }
  out[0] = x;
  out[1] = y;
  out[2] = z;
  out[3] = w;
}

@internal
VrmMatrix4 springOutputTransform(VrmMatrix4 current, List<double> rotation) {
  final m = current.storage;
  final tx = m[12];
  final ty = m[13];
  final tz = m[14];
  final sx = math.sqrt(m[0] * m[0] + m[1] * m[1] + m[2] * m[2]);
  final sy = math.sqrt(m[4] * m[4] + m[5] * m[5] + m[6] * m[6]);
  final sz = math.sqrt(m[8] * m[8] + m[9] * m[9] + m[10] * m[10]);
  final x = rotation[0];
  final y = rotation[1];
  final z = rotation[2];
  final w = rotation[3];
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
    tx,
    ty,
    tz,
    1,
  ]);
}

VrmVector3 _springTransformPoint(
  SpringNodePath path,
  VrmVector3 point, {
  required bool rest,
  required bool reference,
}) {
  final result = SpringVector3();
  _springTransformPointInto(
    path,
    point.x,
    point.y,
    point.z,
    rest: rest,
    reference: reference,
    out: result,
  );
  return VrmVector3(result.x, result.y, result.z);
}

VrmVector3 _springInverseTransformPoint(
  SpringNodePath path,
  VrmVector3 point, {
  required bool rest,
  required bool reference,
}) {
  final result = SpringVector3();
  _springInverseTransformPointInto(
    path,
    point.x,
    point.y,
    point.z,
    rest: rest,
    reference: reference,
    out: result,
  );
  return VrmVector3(result.x, result.y, result.z);
}

@internal
final class SpringVector3 {
  SpringVector3() : x = 0, y = 0, z = 0;

  SpringVector3.from(VrmVector3 value) : x = value.x, y = value.y, z = value.z;

  double x;
  double y;
  double z;

  void set(double x, double y, double z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }

  void copyFrom(SpringVector3 other) {
    x = other.x;
    y = other.y;
    z = other.z;
  }
}

@internal
final class SpringNodePath {
  const SpringNodePath(this.nodes, this.bindings);

  final List<GltfNode> nodes;
  final List<VrmNodeBinding> bindings;
}
