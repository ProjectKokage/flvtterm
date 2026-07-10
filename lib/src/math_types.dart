part of '../flvtterm.dart';

/// Immutable two-component vector used by renderer-neutral bindings.
final class VrmVector2 {
  /// Creates a vector.
  const VrmVector2(this.x, this.y);

  /// Zero vector.
  static const zero = VrmVector2(0, 0);

  /// Unit scale vector.
  static const one = VrmVector2(1, 1);

  /// X component.
  final double x;

  /// Y component.
  final double y;

  /// Linear interpolation.
  static VrmVector2 lerp(VrmVector2 a, VrmVector2 b, double t) =>
      VrmVector2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);

  @override
  bool operator ==(Object other) =>
      other is VrmVector2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'VrmVector2($x, $y)';
}

/// Immutable three-component vector used by LookAt targets.
final class VrmVector3 {
  /// Creates a vector.
  const VrmVector3(this.x, this.y, this.z);

  /// Zero vector.
  static const zero = VrmVector3(0, 0, 0);

  /// X component.
  final double x;

  /// Y component.
  final double y;

  /// Z component.
  final double z;

  /// Adds another vector.
  VrmVector3 operator +(VrmVector3 other) =>
      VrmVector3(x + other.x, y + other.y, z + other.z);

  /// Subtracts another vector.
  VrmVector3 operator -(VrmVector3 other) =>
      VrmVector3(x - other.x, y - other.y, z - other.z);

  /// Multiplies this vector by [scale].
  VrmVector3 operator *(double scale) =>
      VrmVector3(x * scale, y * scale, z * scale);

  @override
  bool operator ==(Object other) =>
      other is VrmVector3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'VrmVector3($x, $y, $z)';
}

/// Immutable four-component vector used by renderer-neutral bindings.
final class VrmVector4 {
  /// Creates a vector.
  const VrmVector4(this.x, this.y, this.z, this.w);

  /// Zero vector.
  static const zero = VrmVector4(0, 0, 0, 0);

  /// Opaque white color.
  static const white = VrmVector4(1, 1, 1, 1);

  /// X component.
  final double x;

  /// Y component.
  final double y;

  /// Z component.
  final double z;

  /// W component.
  final double w;

  /// Linear interpolation.
  static VrmVector4 lerp(VrmVector4 a, VrmVector4 b, double t) => VrmVector4(
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    a.z + (b.z - a.z) * t,
    a.w + (b.w - a.w) * t,
  );

  /// Adds another vector.
  VrmVector4 operator +(VrmVector4 other) =>
      VrmVector4(x + other.x, y + other.y, z + other.z, w + other.w);

  /// Subtracts another vector.
  VrmVector4 operator -(VrmVector4 other) =>
      VrmVector4(x - other.x, y - other.y, z - other.z, w - other.w);

  /// Multiplies all components by [scale].
  VrmVector4 operator *(double scale) =>
      VrmVector4(x * scale, y * scale, z * scale, w * scale);

  @override
  bool operator ==(Object other) =>
      other is VrmVector4 &&
      other.x == x &&
      other.y == y &&
      other.z == z &&
      other.w == w;

  @override
  int get hashCode => Object.hash(x, y, z, w);

  @override
  String toString() => 'VrmVector4($x, $y, $z, $w)';
}

/// Immutable 4x4 matrix storage used by renderer-neutral bindings.
final class VrmMatrix4 {
  /// Creates a matrix from 16 column-major values.
  VrmMatrix4(Iterable<double> values)
    : storage = List<double>.unmodifiable(values) {
    if (storage.length != 16) {
      throw ArgumentError.value(storage.length, 'values.length', 'must be 16');
    }
  }

  /// Creates an identity matrix.
  factory VrmMatrix4.identity() =>
      VrmMatrix4(const [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

  /// Unmodifiable column-major matrix storage.
  final List<double> storage;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VrmMatrix4) return false;
    for (var i = 0; i < storage.length; i++) {
      if (storage[i] != other.storage[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(storage);

  @override
  String toString() => 'VrmMatrix4($storage)';
}
