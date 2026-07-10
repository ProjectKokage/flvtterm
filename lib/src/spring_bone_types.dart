part of '../flvtterm.dart';

/// Parsed `VRMC_springBone` root extension.
final class VrmSpringBone {
  VrmSpringBone._({
    required this.specVersion,
    required List<VrmSpringBoneCollider> colliders,
    required List<VrmSpringBoneColliderGroup> colliderGroups,
    required List<VrmSpringBoneSpring> springs,
    required Map<String, Object?> raw,
  }) : colliders = List.unmodifiable(colliders),
       colliderGroups = List.unmodifiable(colliderGroups),
       springs = List.unmodifiable(springs),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// VRMC_springBone spec version.
  final String? specVersion;

  /// Collider definitions.
  final List<VrmSpringBoneCollider> colliders;

  /// Collider group definitions.
  final List<VrmSpringBoneColliderGroup> colliderGroups;

  /// Spring chain definitions.
  final List<VrmSpringBoneSpring> springs;

  /// Raw extension object, preserved.
  final Map<String, Object?> raw;
}

/// SpringBone collider shape kind.
enum VrmSpringBoneColliderShapeType {
  /// Sphere collider.
  sphere('sphere'),

  /// Capsule collider.
  capsule('capsule');

  const VrmSpringBoneColliderShapeType(this.specName);

  /// Raw shape key.
  final String specName;
}

/// SpringBone collider shape.
final class VrmSpringBoneColliderShape {
  VrmSpringBoneColliderShape._({
    required this.type,
    required this.declaredShapeCount,
    required List<double> offset,
    required this.radius,
    required List<double>? tail,
    required Map<String, Object?> raw,
  }) : offset = List.unmodifiable(offset),
       tail = tail == null ? null : List.unmodifiable(tail),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Collider shape type.
  final VrmSpringBoneColliderShapeType? type;

  /// Number of shape keys declared by the source JSON.
  final int declaredShapeCount;

  /// Shape offset in collider-node local space.
  final List<double> offset;

  /// Shape radius.
  final double radius;

  /// Capsule tail in collider-node local space.
  final List<double>? tail;

  /// Raw shape object, preserved.
  final Map<String, Object?> raw;
}

/// SpringBone collider.
final class VrmSpringBoneCollider {
  VrmSpringBoneCollider._({
    required this.index,
    required this.node,
    required this.shape,
    required Map<String, Object?> raw,
  }) : raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Collider index.
  final int index;

  /// Target node index.
  final int? node;

  /// Collider shape.
  final VrmSpringBoneColliderShape shape;

  /// Raw collider object, preserved.
  final Map<String, Object?> raw;
}

/// SpringBone collider group.
final class VrmSpringBoneColliderGroup {
  VrmSpringBoneColliderGroup._({
    required this.index,
    required this.name,
    required List<int> colliders,
    required Map<String, Object?> raw,
  }) : colliders = List.unmodifiable(colliders),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Collider group index.
  final int index;

  /// Optional group name.
  final String? name;

  /// Collider indices.
  final List<int> colliders;

  /// Raw collider group object, preserved.
  final Map<String, Object?> raw;
}

/// SpringBone spring chain.
final class VrmSpringBoneSpring {
  VrmSpringBoneSpring._({
    required this.index,
    required this.name,
    required List<VrmSpringBoneJoint> joints,
    required List<int> colliderGroups,
    required this.center,
    required Map<String, Object?> raw,
  }) : joints = List.unmodifiable(joints),
       colliderGroups = List.unmodifiable(colliderGroups),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Spring index.
  final int index;

  /// Optional spring name.
  final String? name;

  /// Joint chain.
  final List<VrmSpringBoneJoint> joints;

  /// Collider group indices used by this spring.
  final List<int> colliderGroups;

  /// Optional center node index.
  final int? center;

  /// Raw spring object, preserved.
  final Map<String, Object?> raw;
}

/// SpringBone joint settings.
final class VrmSpringBoneJoint {
  VrmSpringBoneJoint._({
    required this.index,
    required this.node,
    required this.hitRadius,
    required this.stiffness,
    required this.gravityPower,
    required List<double> gravityDir,
    required this.dragForce,
    required Map<String, Object?> raw,
  }) : gravityDir = List.unmodifiable(gravityDir),
       raw = _immutableJsonValue(raw) as Map<String, Object?>;

  /// Joint index within its spring.
  final int index;

  /// Joint node index.
  final int? node;

  /// Collision radius of the spring joint.
  final double hitRadius;

  /// Force returning the joint to the initial pose.
  final double stiffness;

  /// Gravity strength.
  final double gravityPower;

  /// Gravity direction.
  final List<double> gravityDir;

  /// Drag force in `[0, 1]`.
  final double dragForce;

  /// Raw joint object, preserved.
  final Map<String, Object?> raw;
}
