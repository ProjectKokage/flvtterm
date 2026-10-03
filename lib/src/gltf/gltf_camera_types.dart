import 'package:meta/meta.dart';

import '../json_values.dart';

/// glTF camera projection type.
enum GltfCameraType {
  /// Perspective projection.
  perspective('perspective'),

  /// Orthographic projection.
  orthographic('orthographic');

  const GltfCameraType(this.specName);

  /// Raw glTF camera type name.
  final String specName;

  /// Looks up a camera type by raw glTF name.
  static GltfCameraType? fromSpecName(String? name) {
    for (final value in values) {
      if (value.specName == name) return value;
    }
    return null;
  }
}

/// Parsed glTF camera.
final class GltfCamera {
  /// Creates the value from parsed data. Only flvtterm calls this.
  @internal
  GltfCamera.internal({
    required this.index,
    required this.name,
    required this.type,
    required this.perspective,
    required this.orthographic,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : extensions = immutableJsonValue(extensions) as Map<String, Object?>,
       extras = immutableJsonValue(extras);

  /// glTF camera index.
  final int index;

  /// Optional camera name.
  final String? name;

  /// Projection type.
  final GltfCameraType? type;

  /// Perspective projection parameters.
  final GltfCameraPerspective? perspective;

  /// Orthographic projection parameters.
  final GltfCameraOrthographic? orthographic;

  /// Camera extensions, preserved.
  final Map<String, Object?> extensions;

  /// Camera extras, preserved.
  final Object? extras;
}

/// Parsed glTF perspective camera parameters.
final class GltfCameraPerspective {
  /// Creates the value from parsed data. Only flvtterm calls this.
  @internal
  GltfCameraPerspective.internal({
    required this.aspectRatio,
    required this.yfov,
    required this.zfar,
    required this.znear,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : extensions = immutableJsonValue(extensions) as Map<String, Object?>,
       extras = immutableJsonValue(extras);

  /// Aspect ratio, if fixed by the asset.
  final double? aspectRatio;

  /// Vertical field of view in radians.
  final double? yfov;

  /// Far clipping plane distance.
  final double? zfar;

  /// Near clipping plane distance.
  final double? znear;

  /// Perspective camera extensions, preserved.
  final Map<String, Object?> extensions;

  /// Perspective camera extras, preserved.
  final Object? extras;
}

/// Parsed glTF orthographic camera parameters.
final class GltfCameraOrthographic {
  /// Creates the value from parsed data. Only flvtterm calls this.
  @internal
  GltfCameraOrthographic.internal({
    required this.xmag,
    required this.ymag,
    required this.zfar,
    required this.znear,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : extensions = immutableJsonValue(extensions) as Map<String, Object?>,
       extras = immutableJsonValue(extras);

  /// Horizontal magnification.
  final double? xmag;

  /// Vertical magnification.
  final double? ymag;

  /// Far clipping plane distance.
  final double? zfar;

  /// Near clipping plane distance.
  final double? znear;

  /// Orthographic camera extensions, preserved.
  final Map<String, Object?> extensions;

  /// Orthographic camera extras, preserved.
  final Object? extras;
}
