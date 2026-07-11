part of '../flvtterm.dart';

VrmFirstPerson _parseFirstPerson(
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink,
) {
  if (value is! Map) {
    sink.error(
      'vrm.invalidFirstPersonObject',
      'VRMC_vrm.firstPerson must be a JSON object.',
      jsonPath: r'$.extensions.VRMC_vrm.firstPerson',
    );
  }
  final raw = _object(value);
  final annotations = <VrmFirstPersonMeshAnnotation>[];
  final rawAnnotations = raw['meshAnnotations'];
  if (raw.containsKey('meshAnnotations') &&
      (rawAnnotations is! List || rawAnnotations.isEmpty)) {
    sink.error(
      'vrm.invalidFirstPersonMeshAnnotations',
      'firstPerson.meshAnnotations must be a non-empty array when present.',
      jsonPath: r'$.extensions.VRMC_vrm.firstPerson.meshAnnotations',
    );
  }
  final annotationsJson = _list(rawAnnotations);
  for (var i = 0; i < annotationsJson.length; i++) {
    final item = annotationsJson[i];
    final annotationPath =
        '\$.extensions.VRMC_vrm.firstPerson.meshAnnotations[$i]';
    if (item is! Map) {
      sink.error(
        'vrm.invalidFirstPersonMeshAnnotationObject',
        'First-person mesh annotations must be JSON objects.',
        jsonPath: annotationPath,
      );
      continue;
    }
    final object = _object(item);
    final nodeValue = object['node'];
    final typeValue = object['type'];
    final node = _int(nodeValue);
    final type = _string(typeValue);
    var valid = true;
    if (!object.containsKey('node')) {
      valid = false;
      sink.error(
        'vrm.firstPersonMeshAnnotationMissingNode',
        'First-person mesh annotation node is required.',
        jsonPath: '$annotationPath.node',
      );
    } else if (nodeValue is! int) {
      valid = false;
      sink.error(
        'vrm.invalidFirstPersonMeshNode',
        'First-person mesh annotation node must be an integer.',
        jsonPath: '$annotationPath.node',
      );
    }
    if (!object.containsKey('type')) {
      valid = false;
      sink.error(
        'vrm.firstPersonMeshAnnotationMissingType',
        'First-person mesh annotation type is required.',
        jsonPath: '$annotationPath.type',
      );
    } else if (typeValue is! String) {
      valid = false;
      sink.error(
        'vrm.invalidFirstPersonMeshAnnotationType',
        'First-person mesh annotation type must be a string.',
        jsonPath: '$annotationPath.type',
      );
    }
    if (node == null) continue;
    if (type != null &&
        !VrmFirstPersonMeshAnnotationType.values.any(
          (value) => value.specName == type,
        )) {
      valid = false;
      sink.error(
        'vrm.invalidFirstPersonMeshAnnotationType',
        'First-person mesh annotation type is not a VRM 1.0 annotation type.',
        jsonPath: '$annotationPath.type',
      );
    }
    _validateIndex(
      node,
      gltf.nodes.length,
      sink,
      'vrm.invalidFirstPersonMeshNode',
      '$annotationPath.node',
    );
    if (node < 0 || node >= gltf.nodes.length) valid = false;
    if (valid && gltf.nodes[node].mesh == null) {
      valid = false;
      sink.error(
        'vrm.firstPersonMeshNodeMissingMesh',
        'First-person mesh annotation node must reference a mesh.',
        jsonPath: '$annotationPath.node',
        gltfNodeIndex: node,
      );
    }
    if (!valid) continue;
    annotations.add(
      VrmFirstPersonMeshAnnotation(
        node: node,
        type: VrmFirstPersonMeshAnnotationType.fromSpecName(type),
        raw: object,
      ),
    );
  }
  return VrmFirstPerson._(
    firstPersonBone: null,
    meshAnnotations: List.unmodifiable(annotations),
    raw: raw,
  );
}
