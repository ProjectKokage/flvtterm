part of '../flvtterm.dart';

Map<String, Object?> _object(Object? value) {
  if (value is! Map) return const {};
  return _immutableJsonValue(value) as Map<String, Object?>;
}

Object? _immutableJsonValue(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        if (entry.key is String)
          entry.key as String: _immutableJsonValue(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable([
      for (final item in value) _immutableJsonValue(item),
    ]);
  }
  return value;
}

List<Object?> _list(Object? value) =>
    value is List ? value.cast<Object?>() : const [];

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : null;

double? _double(Object? value) => value is num ? value.toDouble() : null;

bool? _bool(Object? value) => value is bool ? value : null;

List<String> _stringList(Object? value) => List.unmodifiable([
  for (final item in _list(value))
    if (item is String) item,
]);

List<int> _intList(Object? value) => List.unmodifiable([
  for (final item in _list(value))
    if (item is int) item,
]);

Map<String, int> _intMap(Object? value) => Map.unmodifiable({
  for (final entry in _object(value).entries)
    if (entry.value is int) entry.key: entry.value as int,
});

List<double> _doubleList(Object? value, int length, List<double> fallback) {
  final result = [
    for (final item in _list(value))
      if (item is num) item.toDouble(),
  ];
  return result.length == length ? List.unmodifiable(result) : fallback;
}

List<double> _doubleValues(Object? value) => List.unmodifiable([
  for (final item in _list(value))
    if (item is num) item.toDouble(),
]);

VrmVector2 _vector2(Object? value, VrmVector2 fallback) {
  final list = _doubleList(value, 2, const []);
  return list.length == 2 ? VrmVector2(list[0], list[1]) : fallback;
}

VrmVector4 _vector4(Object? value, VrmVector4 fallback) {
  final list = _doubleList(value, 4, const []);
  return list.length == 4
      ? VrmVector4(list[0], list[1], list[2], list[3])
      : fallback;
}

VrmVector4 _vector3As4(Object? value, VrmVector4 fallback) {
  final list = _doubleList(value, 3, const []);
  return list.length == 3 ? VrmVector4(list[0], list[1], list[2], 1) : fallback;
}

final class _MorphKey {
  const _MorphKey(this.node, this.primitive, this.morph);

  final int node;
  final int primitive;
  final int morph;

  @override
  bool operator ==(Object other) =>
      other is _MorphKey &&
      other.node == node &&
      other.primitive == primitive &&
      other.morph == morph;

  @override
  int get hashCode => Object.hash(node, primitive, morph);
}

final class _MaterialColorKey {
  const _MaterialColorKey(this.material, this.type);

  final int material;
  final String type;

  @override
  bool operator ==(Object other) =>
      other is _MaterialColorKey &&
      other.material == material &&
      other.type == type;

  @override
  int get hashCode => Object.hash(material, type);
}

final class _TextureTransformAccum {
  _TextureTransformAccum({
    this.scale = VrmVector2.one,
    this.offset = VrmVector2.zero,
  });

  VrmVector2 scale;
  VrmVector2 offset;
}

final class _SpringJointState {
  _SpringJointState({
    required this.centerPath,
    required this.nodePath,
    required this.joint,
    required this.colliders,
    required VrmVector3 previousTail,
    required VrmVector3 currentTail,
    required this.boneAxis,
    required this.initialLocalTail,
    required this.initialLocalRotation,
    required VrmVector3 gravity,
  }) : previousTail = _SpringVector3.from(previousTail),
       currentTail = _SpringVector3.from(currentTail),
       gravity = _SpringVector3.from(gravity);

  final _SpringNodePath? centerPath;
  final _SpringNodePath nodePath;
  final VrmSpringBoneJoint joint;
  final List<_SpringColliderState> colliders;
  final _SpringVector3 previousTail;
  final _SpringVector3 currentTail;
  final VrmVector3 boneAxis;
  final VrmVector3 initialLocalTail;
  final List<double> initialLocalRotation;
  final _SpringVector3 gravity;
  final _SpringScratch scratch = _SpringScratch();
  final List<double> rotationScratch = List<double>.filled(4, 0);
}

final class _SpringVector3 {
  _SpringVector3() : x = 0, y = 0, z = 0;

  _SpringVector3.from(VrmVector3 value) : x = value.x, y = value.y, z = value.z;

  double x;
  double y;
  double z;

  void set(double x, double y, double z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }

  void copyFrom(_SpringVector3 other) {
    x = other.x;
    y = other.y;
    z = other.z;
  }
}

final class _SpringScratch {
  final _SpringVector3 head = _SpringVector3();
  final _SpringVector3 referenceTail = _SpringVector3();
  final _SpringVector3 currentTail = _SpringVector3();
  final _SpringVector3 nextTail = _SpringVector3();
  final _SpringVector3 temporary = _SpringVector3();
  final _SpringVector3 localTail = _SpringVector3();
  final _SpringVector3 colliderStart = _SpringVector3();
  final _SpringVector3 colliderEnd = _SpringVector3();
}

final class _SpringNodePath {
  const _SpringNodePath(this.nodes, this.bindings);

  final List<GltfNode> nodes;
  final List<VrmNodeBinding> bindings;
}

final class _SpringColliderState {
  const _SpringColliderState({
    required this.type,
    required this.nodePath,
    required this.offset,
    required this.tail,
    required this.radius,
  });

  final VrmSpringBoneColliderShapeType type;
  final _SpringNodePath nodePath;
  final VrmVector3 offset;
  final VrmVector3 tail;
  final double radius;
}

extension on List<GltfBuffer> {
  GltfBuffer? elementAtOrNull(int index) =>
      index < 0 || index >= length ? null : this[index];
}

extension on List<GltfNode> {
  GltfNode? elementAtOrNull(int index) =>
      index < 0 || index >= length ? null : this[index];
}

extension on List<GltfMesh> {
  GltfMesh? elementAtOrNull(int index) =>
      index < 0 || index >= length ? null : this[index];
}

extension on List<GltfMaterial> {
  GltfMaterial? elementAtOrNull(int index) =>
      index < 0 || index >= length ? null : this[index];
}

extension on List<GltfSkin> {
  GltfSkin? elementAtOrNull(int index) =>
      index < 0 || index >= length ? null : this[index];
}

extension on List<GltfAccessor> {
  GltfAccessor? elementAtOrNull(int index) =>
      index < 0 || index >= length ? null : this[index];
}

extension on List<VrmSpringBoneCollider> {
  VrmSpringBoneCollider? elementAtOrNull(int index) =>
      index < 0 || index >= length ? null : this[index];
}

extension on List<VrmSpringBoneColliderGroup> {
  VrmSpringBoneColliderGroup? elementAtOrNull(int index) =>
      index < 0 || index >= length ? null : this[index];
}

extension on VrmVector2 {
  VrmVector2 operator +(VrmVector2 other) =>
      VrmVector2(x + other.x, y + other.y);

  VrmVector2 operator -(VrmVector2 other) =>
      VrmVector2(x - other.x, y - other.y);

  VrmVector2 operator *(double scale) => VrmVector2(x * scale, y * scale);
}
