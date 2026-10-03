import 'package:meta/meta.dart';

import '../math_types.dart';
import '../runtime/constraint_math.dart';
import '../vrm/vrm_enums.dart';

@internal
VrmVector3 runtimePointToSourceModel(
  VrmSourceVersion version,
  VrmVector3 value,
) => switch (version) {
  VrmSourceVersion.vrm0 => VrmVector3(-value.x, value.y, -value.z),
  VrmSourceVersion.vrm1 => value,
};

@internal
VrmVector3 sourceDirectionToRuntime(
  VrmSourceVersion version,
  VrmVector3 value,
) => switch (version) {
  VrmSourceVersion.vrm0 => VrmVector3(-value.x, value.y, -value.z),
  VrmSourceVersion.vrm1 => value,
};

@internal
List<double> runtimeRotationToSource(
  VrmSourceVersion version,
  List<double> rotation,
) {
  if (version == VrmSourceVersion.vrm1) return rotation;
  const basis = <double>[0, 1, 0, 0];
  return quatMultiply(quatMultiply(quatInverse(basis), rotation), basis);
}
