part of '../../flvtterm.dart';

VrmVector3 _runtimePointToSourceModel(
  VrmSourceVersion version,
  VrmVector3 value,
) => switch (version) {
  VrmSourceVersion.vrm0 => VrmVector3(-value.x, value.y, -value.z),
  VrmSourceVersion.vrm1 => value,
};

VrmVector3 _sourceDirectionToRuntime(
  VrmSourceVersion version,
  VrmVector3 value,
) => switch (version) {
  VrmSourceVersion.vrm0 => VrmVector3(-value.x, value.y, -value.z),
  VrmSourceVersion.vrm1 => value,
};

List<double> _runtimeRotationToSource(
  VrmSourceVersion version,
  List<double> rotation,
) {
  if (version == VrmSourceVersion.vrm1) return rotation;
  const basis = <double>[0, 1, 0, 0];
  return _quatMultiply(_quatMultiply(_quatInverse(basis), rotation), basis);
}
