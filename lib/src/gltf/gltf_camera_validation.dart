part of '../../flvtterm.dart';

void _validateGltfCameras(GltfAsset gltf, _DiagnosticSink sink) {
  final rawCameras = _list(gltf.json['cameras']);
  for (final camera in gltf.cameras) {
    final raw = _object(rawCameras.elementAtOrNull(camera.index));
    final type = raw['type'];
    if (type == null) {
      sink.error(
        'gltf.missingCameraType',
        'Camera type is required.',
        jsonPath: '\$.cameras[${camera.index}].type',
      );
    } else if (type is! String || GltfCameraType.fromSpecName(type) == null) {
      sink.error(
        'gltf.invalidCameraType',
        'Camera type must be perspective or orthographic.',
        jsonPath: '\$.cameras[${camera.index}].type',
      );
    }

    final hasPerspective = raw.containsKey('perspective');
    final hasOrthographic = raw.containsKey('orthographic');
    if (hasPerspective && hasOrthographic) {
      sink.error(
        'gltf.invalidCameraProjection',
        'Camera must not define both perspective and orthographic.',
        jsonPath: '\$.cameras[${camera.index}]',
      );
    }
    if (camera.type == GltfCameraType.perspective) {
      _validateCameraProjectionObject(raw, 'perspective', sink, camera.index);
      _validatePerspectiveCamera(camera, raw, sink);
    } else if (camera.type == GltfCameraType.orthographic) {
      _validateCameraProjectionObject(raw, 'orthographic', sink, camera.index);
      _validateOrthographicCamera(camera, raw, sink);
    }
  }
}

void _validateCameraProjectionObject(
  Map<String, Object?> raw,
  String key,
  _DiagnosticSink sink,
  int cameraIndex,
) {
  if (!raw.containsKey(key)) {
    sink.error(
      'gltf.missingCameraProjection',
      'Camera $key projection is required for its type.',
      jsonPath: '\$.cameras[$cameraIndex].$key',
    );
  } else if (raw[key] is! Map) {
    sink.error(
      'gltf.invalidCameraProjection',
      'Camera $key projection must be a JSON object.',
      jsonPath: '\$.cameras[$cameraIndex].$key',
    );
  }
}

void _validatePerspectiveCamera(
  GltfCamera camera,
  Map<String, Object?> rawCamera,
  _DiagnosticSink sink,
) {
  if (rawCamera['perspective'] is! Map) return;
  final raw = _object(rawCamera['perspective']);
  if (!_positive(raw['yfov']) ||
      !_positive(raw['znear']) ||
      (raw.containsKey('aspectRatio') && !_positive(raw['aspectRatio'])) ||
      (raw.containsKey('zfar') && !_positive(raw['zfar'])) ||
      (camera.perspective?.zfar != null &&
          camera.perspective?.znear != null &&
          camera.perspective!.zfar! <= camera.perspective!.znear!)) {
    sink.error(
      'gltf.invalidCameraPerspective',
      'Perspective camera yfov and znear must be positive, and zfar must be greater than znear when present.',
      jsonPath: '\$.cameras[${camera.index}].perspective',
    );
  }
  final yfov = raw['yfov'];
  if (yfov is num && yfov >= math.pi) {
    sink.warning(
      'gltf.largeCameraPerspectiveYfov',
      'Perspective camera yfov should be less than pi.',
      jsonPath: '\$.cameras[${camera.index}].perspective.yfov',
    );
  }
}

void _validateOrthographicCamera(
  GltfCamera camera,
  Map<String, Object?> rawCamera,
  _DiagnosticSink sink,
) {
  if (rawCamera['orthographic'] is! Map) return;
  final raw = _object(rawCamera['orthographic']);
  if (!_nonZero(raw['xmag']) ||
      !_nonZero(raw['ymag']) ||
      !_positive(raw['zfar']) ||
      !_nonNegative(raw['znear']) ||
      (camera.orthographic?.zfar != null &&
          camera.orthographic?.znear != null &&
          camera.orthographic!.zfar! <= camera.orthographic!.znear!)) {
    sink.error(
      'gltf.invalidCameraOrthographic',
      'Orthographic camera xmag and ymag must be non-zero, znear must be non-negative, and zfar must be greater than znear.',
      jsonPath: '\$.cameras[${camera.index}].orthographic',
    );
  }
  if (_negative(raw['xmag']) || _negative(raw['ymag'])) {
    sink.warning(
      'gltf.negativeCameraOrthographicMagnification',
      'Orthographic camera xmag and ymag should not be negative.',
      jsonPath: '\$.cameras[${camera.index}].orthographic',
    );
  }
}

bool _positive(Object? value) => value is num && value > 0;

bool _nonNegative(Object? value) => value is num && value >= 0;

bool _nonZero(Object? value) => value is num && value != 0;

bool _negative(Object? value) => value is num && value < 0;
