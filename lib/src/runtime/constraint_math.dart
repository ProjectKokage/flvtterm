import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../gltf/animation_math.dart';
import '../gltf/gltf_node_constraint_types.dart';
import '../matrix_math.dart';
import 'look_at_math.dart';
import 'scene_binding.dart';

@internal
List<double> yawPitchQuaternion(double yawDegrees, double pitchDegrees) {
  final yaw = yawDegrees * math.pi / 180;
  final pitch = pitchDegrees * math.pi / 180;
  final yawQuat = [0.0, math.sin(yaw / 2), 0.0, math.cos(yaw / 2)];
  final pitchQuat = [math.sin(pitch / 2), 0.0, 0.0, math.cos(pitch / 2)];
  return quatMultiply(yawQuat, pitchQuat);
}

@internal
YawPitch yawPitchFromExtrinsicZxy(List<double> rotation) {
  final q = normalizeList(rotation);
  final x = q[0];
  final y = q[1];
  final z = q[2];
  final w = q[3];
  final r02 = 2 * (x * z + y * w);
  final r12 = 2 * (y * z - x * w);
  final r22 = 1 - 2 * (x * x + y * y);
  final pitch = math.asin(math.max(-1, math.min(1, -r12)));
  final yaw = math.atan2(r02, r22);
  return YawPitch(yaw * 180 / math.pi, pitch * 180 / math.pi);
}

@internal
List<double> quatMultiply(List<double> a, List<double> b) {
  final ax = a[0];
  final ay = a[1];
  final az = a[2];
  final aw = a[3];
  final bx = b[0];
  final by = b[1];
  final bz = b[2];
  final bw = b[3];
  return normalizeList([
    aw * bx + ax * bw + ay * bz - az * by,
    aw * by - ax * bz + ay * bw + az * bx,
    aw * bz + ax * by - ay * bx + az * bw,
    aw * bw - ax * bx - ay * by - az * bz,
  ]);
}

@internal
List<double> quatInverse(List<double> value) {
  final lengthSquared =
      value[0] * value[0] +
      value[1] * value[1] +
      value[2] * value[2] +
      value[3] * value[3];
  if (lengthSquared == 0) return const [0, 0, 0, 1];
  return [
    -value[0] / lengthSquared,
    -value[1] / lengthSquared,
    -value[2] / lengthSquared,
    value[3] / lengthSquared,
  ];
}

@internal
List<double> rotationConstraint({
  required List<double> sourceRest,
  required List<double> sourceCurrent,
  required List<double> destinationRest,
}) {
  final sourceDelta = quatMultiply(quatInverse(sourceRest), sourceCurrent);
  return quatMultiply(destinationRest, sourceDelta);
}

@internal
List<double>? rollConstraint({
  required List<double> sourceRest,
  required List<double> sourceCurrent,
  required List<double> destinationRest,
  required VrmNodeConstraintRollAxis? axis,
}) {
  if (axis == null) return null;
  final rollAxis = _rollAxisVector(axis);
  final sourceDelta = quatMultiply(quatInverse(sourceRest), sourceCurrent);
  final sourceDeltaInParent = quatMultiply(
    quatMultiply(sourceRest, sourceDelta),
    quatInverse(sourceRest),
  );
  final sourceDeltaInDestination = quatMultiply(
    quatMultiply(quatInverse(destinationRest), sourceDeltaInParent),
    destinationRest,
  );
  final to = rotateVector(sourceDeltaInDestination, rollAxis);
  final fromTo = _fromToQuaternion(rollAxis, to);
  return quatMultiply(
    destinationRest,
    quatMultiply(quatInverse(fromTo), sourceDeltaInDestination),
  );
}

@internal
List<double>? aimConstraint({
  required VrmNodeBinding source,
  required VrmNodeBinding destination,
  required List<double> destinationRest,
  required List<double> parentWorldRotation,
  required VrmNodeConstraintAimAxis? axis,
}) {
  if (axis == null) return null;
  final restWorldRotation = quatMultiply(parentWorldRotation, destinationRest);
  final from = rotateVector(restWorldRotation, _aimAxisVector(axis));
  final sourcePosition = matrixPosition(source.worldTransform);
  final destinationPosition = matrixPosition(destination.worldTransform);
  final to = sourcePosition - destinationPosition;
  final aim = _fromToQuaternion(from, [to.x, to.y, to.z]);
  return quatMultiply(
    quatMultiply(
      quatMultiply(quatInverse(parentWorldRotation), aim),
      parentWorldRotation,
    ),
    destinationRest,
  );
}

List<double> _rollAxisVector(VrmNodeConstraintRollAxis axis) {
  return switch (axis) {
    VrmNodeConstraintRollAxis.x => const [1, 0, 0],
    VrmNodeConstraintRollAxis.y => const [0, 1, 0],
    VrmNodeConstraintRollAxis.z => const [0, 0, 1],
  };
}

List<double> _aimAxisVector(VrmNodeConstraintAimAxis axis) {
  return switch (axis) {
    VrmNodeConstraintAimAxis.positiveX => const [1, 0, 0],
    VrmNodeConstraintAimAxis.negativeX => const [-1, 0, 0],
    VrmNodeConstraintAimAxis.positiveY => const [0, 1, 0],
    VrmNodeConstraintAimAxis.negativeY => const [0, -1, 0],
    VrmNodeConstraintAimAxis.positiveZ => const [0, 0, 1],
    VrmNodeConstraintAimAxis.negativeZ => const [0, 0, -1],
  };
}

@internal
List<double> rotateVector(List<double> rotation, List<double> vector) {
  final qVector = [vector[0], vector[1], vector[2], 0.0];
  final rotated = quatMultiply(
    quatMultiply(rotation, qVector),
    quatInverse(rotation),
  );
  return [rotated[0], rotated[1], rotated[2]];
}

List<double> _fromToQuaternion(List<double> from, List<double> to) {
  final a = normalizeVector(from);
  final b = normalizeVector(to);
  final dot = vectorDot(a, b);
  if (dot > 0.999999) return const [0, 0, 0, 1];
  if (dot < -0.999999) {
    final fallbackAxis = a[0].abs() < 0.9
        ? const [1.0, 0.0, 0.0]
        : const [0.0, 1.0, 0.0];
    final axis = normalizeVector(vectorCross(a, fallbackAxis));
    return [axis[0], axis[1], axis[2], 0.0];
  }
  final cross = vectorCross(a, b);
  return normalizeList([cross[0], cross[1], cross[2], 1 + dot]);
}

@internal
List<double> normalizeVector(List<double> value) {
  final length = math.sqrt(vectorDot(value, value));
  if (length == 0) return const [0, 0, 0];
  return [value[0] / length, value[1] / length, value[2] / length];
}

@internal
double vectorDot(List<double> a, List<double> b) =>
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

@internal
List<double> vectorCross(List<double> a, List<double> b) => [
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];
