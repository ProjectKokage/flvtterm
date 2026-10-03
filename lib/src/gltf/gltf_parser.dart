import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../diagnostics.dart';
import '../json_values.dart';
import '../math_types.dart';
import 'accessor_reader.dart';
import 'gltf_camera_types.dart';
import 'gltf_mesh_types.dart';
import 'gltf_node_constraint_types.dart';
import 'gltf_node_constraint_validation.dart';
import 'gltf_resource_types.dart';
import 'gltf_scene_types.dart';
import 'gltf_types.dart';

@internal
List<GltfBuffer> parseBuffers(
  Object? value,
  DiagnosticSink sink,
  Uint8List? binaryChunk,
  GltfUriResolver? uriResolver,
  Map<String, String> uriResolverFailures,
) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      _parseBuffer(
        i,
        list[i],
        sink,
        binaryChunk,
        uriResolver,
        uriResolverFailures,
      ),
  ];
}

GltfBuffer _parseBuffer(
  int index,
  Object? value,
  DiagnosticSink sink,
  Uint8List? binaryChunk,
  GltfUriResolver? uriResolver,
  Map<String, String> uriResolverFailures,
) {
  final raw = jsonObject(value);
  final uri = jsonString(raw['uri']);
  final byteLength = jsonInt(raw['byteLength']);
  final data = index == 0 && binaryChunk != null
      ? binaryChunk
      : _decodeBufferBytes(uri, index, sink, uriResolver, uriResolverFailures);
  return GltfBuffer.internal(
    index: index,
    name: jsonString(raw['name']),
    uri: uri,
    byteLength: byteLength,
    data: _declaredBufferBytes(data, byteLength),
    extensions: jsonObject(raw['extensions']),
    extras: raw['extras'],
  );
}

Uint8List? _declaredBufferBytes(Uint8List? bytes, int? byteLength) {
  if (bytes == null) return null;
  if (byteLength == null || byteLength < 1 || byteLength > bytes.length) {
    return bytes;
  }
  if (byteLength == bytes.length) return bytes;
  return Uint8List.sublistView(bytes, 0, byteLength);
}

Uint8List? _decodeBufferBytes(
  String? uri,
  int bufferIndex,
  DiagnosticSink sink,
  GltfUriResolver? uriResolver,
  Map<String, String> uriResolverFailures,
) {
  if (uri == null) return null;
  if (uri.startsWith('data:')) {
    return _decodeDataUri(
      uri,
      sink,
      code: 'gltf.invalidBufferDataUri',
      jsonPath: '\$.buffers[$bufferIndex].uri',
      missingCommaMessage: 'Buffer data URI is missing a comma separator.',
      invalidPayloadPrefix: 'Could not decode buffer $bufferIndex data URI',
    );
  }
  if (uriResolver == null) return null;
  try {
    return _ownedCopy(uriResolver(uri));
  } catch (error) {
    uriResolverFailures['\$.buffers[$bufferIndex].uri'] = error.toString();
    return null;
  }
}

/// Copies bytes a caller's resolver returned, so the asset owns them.
Uint8List? _ownedCopy(Uint8List? bytes) =>
    bytes == null ? null : Uint8List.fromList(bytes).asUnmodifiableView();

Uint8List? _decodeDataUri(
  String uri,
  DiagnosticSink sink, {
  required String code,
  required String jsonPath,
  required String missingCommaMessage,
  required String invalidPayloadPrefix,
}) {
  final comma = uri.indexOf(',');
  if (comma < 0) {
    sink.error(code, missingCommaMessage, jsonPath: jsonPath);
    return null;
  }
  try {
    // The decoded bytes are new, so the asset owns them without a copy.
    final dataUri = UriData.parse(_normalizeDataUriBase64Marker(uri, comma));
    if (dataUri.isBase64) return dataUri.contentAsBytes().asUnmodifiableView();
    final payload = uri.substring(comma + 1);
    return Uint8List.fromList(
      utf8.encode(Uri.decodeComponent(payload)),
    ).asUnmodifiableView();
  } on FormatException catch (error) {
    sink.error(
      code,
      '$invalidPayloadPrefix: ${error.message}',
      jsonPath: jsonPath,
    );
    return null;
  } on ArgumentError catch (error) {
    sink.error(
      code,
      '$invalidPayloadPrefix: ${error.message}',
      jsonPath: jsonPath,
    );
    return null;
  }
}

String _normalizeDataUriBase64Marker(String uri, int comma) {
  final metadata = uri.substring(0, comma);
  if (!metadata.toLowerCase().endsWith(';base64') ||
      metadata.endsWith(';base64')) {
    return uri;
  }
  return '${metadata.substring(0, metadata.length - 'base64'.length)}base64${uri.substring(comma)}';
}

@internal
List<GltfBufferView> parseBufferViews(Object? value) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfBufferView.internal(
        index: i,
        name: jsonString(jsonObject(list[i])['name']),
        buffer: jsonInt(jsonObject(list[i])['buffer']),
        byteOffset: jsonInt(jsonObject(list[i])['byteOffset']) ?? 0,
        byteLength: jsonInt(jsonObject(list[i])['byteLength']),
        byteStride: jsonInt(jsonObject(list[i])['byteStride']),
        target: jsonInt(jsonObject(list[i])['target']),
        extensions: jsonObject(jsonObject(list[i])['extensions']),
        extras: jsonObject(list[i])['extras'],
      ),
  ];
}

@internal
List<GltfCamera> parseCameras(Object? value) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfCamera.internal(
        index: i,
        name: jsonString(jsonObject(list[i])['name']),
        type: GltfCameraType.fromSpecName(
          jsonString(jsonObject(list[i])['type']),
        ),
        perspective: _parseCameraPerspective(
          jsonObject(list[i])['perspective'],
        ),
        orthographic: _parseCameraOrthographic(
          jsonObject(list[i])['orthographic'],
        ),
        extensions: jsonObject(jsonObject(list[i])['extensions']),
        extras: jsonObject(list[i])['extras'],
      ),
  ];
}

GltfCameraPerspective? _parseCameraPerspective(Object? value) {
  final raw = jsonObject(value);
  if (raw.isEmpty) return null;
  return GltfCameraPerspective.internal(
    aspectRatio: jsonDouble(raw['aspectRatio']),
    yfov: jsonDouble(raw['yfov']),
    zfar: jsonDouble(raw['zfar']),
    znear: jsonDouble(raw['znear']),
    extensions: jsonObject(raw['extensions']),
    extras: raw['extras'],
  );
}

GltfCameraOrthographic? _parseCameraOrthographic(Object? value) {
  final raw = jsonObject(value);
  if (raw.isEmpty) return null;
  return GltfCameraOrthographic.internal(
    xmag: jsonDouble(raw['xmag']),
    ymag: jsonDouble(raw['ymag']),
    zfar: jsonDouble(raw['zfar']),
    znear: jsonDouble(raw['znear']),
    extensions: jsonObject(raw['extensions']),
    extras: raw['extras'],
  );
}

@internal
List<GltfScene> parseScenes(Object? value, DiagnosticSink sink) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfScene.internal(
        index: i,
        name: jsonString(jsonObject(list[i])['name']),
        nodes: _parseIndexList(
          jsonObject(list[i])['nodes'],
          sink,
          code: 'gltf.invalidSceneNode',
          jsonPath: '\$.scenes[$i].nodes',
          message: 'Scene node references must be integers.',
        ),
        extensions: jsonObject(jsonObject(list[i])['extensions']),
        extras: jsonObject(list[i])['extras'],
      ),
  ];
}

@internal
List<GltfNode> parseNodes(Object? value, DiagnosticSink sink) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfNode.internal(
        index: i,
        name: jsonString(jsonObject(list[i])['name']),
        children: _parseIndexList(
          jsonObject(list[i])['children'],
          sink,
          code: 'gltf.invalidNodeChild',
          jsonPath: '\$.nodes[$i].children',
          message: 'Node child references must be integers.',
        ),
        camera: jsonInt(jsonObject(list[i])['camera']),
        mesh: jsonInt(jsonObject(list[i])['mesh']),
        skin: jsonInt(jsonObject(list[i])['skin']),
        matrix: _parseNodeMatrix(jsonObject(list[i])['matrix']),
        translation: jsonDoubleList(
          jsonObject(list[i])['translation'],
          3,
          const [0, 0, 0],
        ),
        rotation: jsonDoubleList(jsonObject(list[i])['rotation'], 4, const [
          0,
          0,
          0,
          1,
        ]),
        scale: jsonDoubleList(jsonObject(list[i])['scale'], 3, const [1, 1, 1]),
        weights: jsonDoubleValues(jsonObject(list[i])['weights']),
        nodeConstraint: _parseNodeConstraint(
          i,
          jsonObject(jsonObject(list[i])['extensions']),
          sink,
        ),
        extensions: jsonObject(jsonObject(list[i])['extensions']),
        extras: jsonObject(list[i])['extras'],
      ),
  ];
}

VrmMatrix4? _parseNodeMatrix(Object? value) {
  if (value == null) return null;
  final values = jsonDoubleList(value, 16, const []);
  return values.length == 16 ? VrmMatrix4(values) : null;
}

VrmNodeConstraint? _parseNodeConstraint(
  int nodeIndex,
  Map<String, Object?> extensions,
  DiagnosticSink sink,
) {
  if (!extensions.containsKey('VRMC_node_constraint')) return null;
  final value = extensions['VRMC_node_constraint'];
  if (value is! Map) {
    sink.error(
      'constraint.invalidExtensionObject',
      'VRMC_node_constraint must be a JSON object.',
      jsonPath: nodeConstraintPath(nodeIndex, ''),
      gltfNodeIndex: nodeIndex,
    );
    return null;
  }
  final raw = jsonObject(value);
  if (raw.containsKey('constraint') && raw['constraint'] is! Map) {
    sink.error(
      'constraint.invalidConstraintObject',
      'VRMC_node_constraint.constraint must be a JSON object.',
      jsonPath: nodeConstraintPath(nodeIndex, '.constraint'),
      gltfNodeIndex: nodeIndex,
    );
  }
  final constraint = jsonObject(raw['constraint']);
  final declaredKinds = [
    if (constraint.containsKey('roll')) VrmNodeConstraintKind.roll,
    if (constraint.containsKey('aim')) VrmNodeConstraintKind.aim,
    if (constraint.containsKey('rotation')) VrmNodeConstraintKind.rotation,
  ];
  final kind = declaredKinds.isEmpty ? null : declaredKinds.first;
  if (kind != null && constraint[kind.specName] is! Map) {
    sink.error(
      'constraint.invalidKindObject',
      'Node constraint ${kind.specName} must be a JSON object.',
      jsonPath: nodeConstraintPath(nodeIndex, '.constraint.${kind.specName}'),
      gltfNodeIndex: nodeIndex,
    );
  }
  final parameters = switch (kind) {
    VrmNodeConstraintKind.roll => jsonObject(constraint['roll']),
    VrmNodeConstraintKind.aim => jsonObject(constraint['aim']),
    VrmNodeConstraintKind.rotation => jsonObject(constraint['rotation']),
    null => const <String, Object?>{},
  };
  return VrmNodeConstraint.internal(
    destinationNode: nodeIndex,
    specVersion: jsonString(raw['specVersion']),
    kind: kind,
    declaredKindCount: declaredKinds.length,
    source: jsonInt(parameters['source']),
    weight: jsonDouble(parameters['weight']) ?? 1,
    rollAxis: VrmNodeConstraintRollAxis.fromSpecName(
      jsonString(parameters['rollAxis']),
    ),
    aimAxis: VrmNodeConstraintAimAxis.fromSpecName(
      jsonString(parameters['aimAxis']),
    ),
    raw: raw,
  );
}

@internal
List<GltfMesh> parseMeshes(Object? value) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfMesh.internal(
        index: i,
        name: jsonString(jsonObject(list[i])['name']),
        primitives: _parsePrimitives(jsonObject(list[i])['primitives']),
        weights: jsonDoubleValues(jsonObject(list[i])['weights']),
        extensions: jsonObject(jsonObject(list[i])['extensions']),
        extras: jsonObject(list[i])['extras'],
      ),
  ];
}

List<GltfMeshPrimitive> _parsePrimitives(Object? value) {
  final list = jsonList(value);
  return [
    for (final primitive in list)
      GltfMeshPrimitive.internal(
        mode: jsonInt(jsonObject(primitive)['mode']) ?? 4,
        material: jsonInt(jsonObject(primitive)['material']),
        indices: jsonInt(jsonObject(primitive)['indices']),
        attributes: jsonIntMap(jsonObject(primitive)['attributes']),
        targets: [
          for (final target in jsonList(jsonObject(primitive)['targets']))
            jsonIntMap(target),
        ],
        extensions: jsonObject(jsonObject(primitive)['extensions']),
        extras: jsonObject(primitive)['extras'],
      ),
  ];
}

@internal
List<GltfSkin> parseSkins(Object? value, DiagnosticSink sink) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfSkin.internal(
        index: i,
        name: jsonString(jsonObject(list[i])['name']),
        joints: _parseIndexList(
          jsonObject(list[i])['joints'],
          sink,
          code: 'gltf.invalidSkinJoint',
          jsonPath: '\$.skins[$i].joints',
          message: 'Skin joint references must be integers.',
        ),
        skeleton: jsonInt(jsonObject(list[i])['skeleton']),
        inverseBindMatrices: jsonInt(
          jsonObject(list[i])['inverseBindMatrices'],
        ),
        extensions: jsonObject(jsonObject(list[i])['extensions']),
        extras: jsonObject(list[i])['extras'],
      ),
  ];
}

@internal
List<GltfAccessor> parseAccessors(Object? value) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfAccessor.internal(
        index: i,
        name: jsonString(jsonObject(list[i])['name']),
        bufferView: jsonInt(jsonObject(list[i])['bufferView']),
        byteOffset: jsonInt(jsonObject(list[i])['byteOffset']) ?? 0,
        count: jsonInt(jsonObject(list[i])['count']),
        componentType: jsonInt(jsonObject(list[i])['componentType']),
        type: jsonString(jsonObject(list[i])['type']),
        normalized: jsonBool(jsonObject(list[i])['normalized']) ?? false,
        minimum: jsonObject(list[i]).containsKey('min')
            ? jsonDoubleValues(jsonObject(list[i])['min'])
            : null,
        maximum: jsonObject(list[i]).containsKey('max')
            ? jsonDoubleValues(jsonObject(list[i])['max'])
            : null,
        sparse: _parseAccessorSparse(jsonObject(list[i])['sparse']),
        extensions: jsonObject(jsonObject(list[i])['extensions']),
        extras: jsonObject(list[i])['extras'],
      ),
  ];
}

GltfAccessorSparse? _parseAccessorSparse(Object? value) {
  final raw = jsonObject(value);
  if (raw.isEmpty) return null;
  final indices = jsonObject(raw['indices']);
  final values = jsonObject(raw['values']);
  return GltfAccessorSparse.internal(
    count: jsonInt(raw['count']),
    indicesBufferView: jsonInt(indices['bufferView']),
    indicesByteOffset: jsonInt(indices['byteOffset']) ?? 0,
    indicesComponentType: jsonInt(indices['componentType']),
    indicesExtensions: jsonObject(indices['extensions']),
    indicesExtras: indices['extras'],
    valuesBufferView: jsonInt(values['bufferView']),
    valuesByteOffset: jsonInt(values['byteOffset']) ?? 0,
    valuesExtensions: jsonObject(values['extensions']),
    valuesExtras: values['extras'],
    extensions: jsonObject(raw['extensions']),
    extras: raw['extras'],
  );
}

@internal
List<GltfTexture> parseTextures(Object? value) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfTexture.internal(
        index: i,
        name: jsonString(jsonObject(list[i])['name']),
        source: jsonInt(jsonObject(list[i])['source']),
        sampler: jsonInt(jsonObject(list[i])['sampler']),
        extensions: jsonObject(jsonObject(list[i])['extensions']),
        extras: jsonObject(list[i])['extras'],
      ),
  ];
}

@internal
List<GltfImage> parseImages(
  Object? value,
  DiagnosticSink sink,
  List<GltfBuffer> buffers,
  List<GltfBufferView> bufferViews,
  GltfUriResolver? uriResolver,
  Map<String, String> uriResolverFailures,
) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      _parseImage(
        i,
        list[i],
        sink,
        buffers,
        bufferViews,
        uriResolver,
        uriResolverFailures,
      ),
  ];
}

GltfImage _parseImage(
  int index,
  Object? value,
  DiagnosticSink sink,
  List<GltfBuffer> buffers,
  List<GltfBufferView> bufferViews,
  GltfUriResolver? uriResolver,
  Map<String, String> uriResolverFailures,
) {
  final raw = jsonObject(value);
  final uri = jsonString(raw['uri']);
  final bufferView = jsonInt(raw['bufferView']);
  return GltfImage.internal(
    index: index,
    name: jsonString(raw['name']),
    uri: uri,
    bufferView: bufferView,
    mimeType: jsonString(raw['mimeType']),
    data:
        _decodeImageBytes(uri, index, sink, uriResolver, uriResolverFailures) ??
        gltfBufferViewBytes(buffers, bufferViews, bufferView),
    extensions: jsonObject(raw['extensions']),
    extras: raw['extras'],
  );
}

Uint8List? _decodeImageBytes(
  String? uri,
  int imageIndex,
  DiagnosticSink sink,
  GltfUriResolver? uriResolver,
  Map<String, String> uriResolverFailures,
) {
  if (uri == null) return null;
  if (uri.startsWith('data:')) {
    return _decodeDataUri(
      uri,
      sink,
      code: 'gltf.invalidImageDataUri',
      jsonPath: '\$.images[$imageIndex].uri',
      missingCommaMessage: 'Image data URI is missing a comma separator.',
      invalidPayloadPrefix: 'Could not decode image data URI',
    );
  }
  if (uriResolver == null) return null;
  try {
    return _ownedCopy(uriResolver(uri));
  } catch (error) {
    uriResolverFailures['\$.images[$imageIndex].uri'] = error.toString();
    return null;
  }
}

@internal
List<GltfSampler> parseSamplers(Object? value) {
  final list = jsonList(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfSampler.internal(
        index: i,
        name: jsonString(jsonObject(list[i])['name']),
        magFilter: jsonInt(jsonObject(list[i])['magFilter']),
        minFilter: jsonInt(jsonObject(list[i])['minFilter']),
        wrapS: jsonInt(jsonObject(list[i])['wrapS']) ?? 10497,
        wrapT: jsonInt(jsonObject(list[i])['wrapT']) ?? 10497,
        extensions: jsonObject(jsonObject(list[i])['extensions']),
        extras: jsonObject(list[i])['extras'],
      ),
  ];
}

@internal
List<String> parseRootStringList(
  Map<String, Object?> json,
  String key,
  String code,
  DiagnosticSink sink,
) {
  if (!json.containsKey(key)) return const [];
  final value = json[key];
  final path = '\$.$key';
  if (value is! List) {
    sink.error(code, '$key must be an array of strings.', jsonPath: path);
    return const [];
  }
  if (value.isEmpty) {
    sink.error(code, '$key must contain at least one string.', jsonPath: path);
    return const [];
  }

  final result = <String>[];
  for (var i = 0; i < value.length; i++) {
    final item = value[i];
    if (item is String) {
      result.add(item);
    } else {
      sink.error(code, '$key entries must be strings.', jsonPath: '$path[$i]');
    }
  }
  return List.unmodifiable(result);
}

List<int> _parseIndexList(
  Object? value,
  DiagnosticSink sink, {
  required String code,
  required String jsonPath,
  required String message,
}) {
  if (value == null) return const [];
  if (value is! List) {
    sink.error(code, message, jsonPath: jsonPath);
    return const [];
  }
  if (value.isEmpty) {
    sink.error(code, message, jsonPath: jsonPath);
    return const [];
  }

  final result = <int>[];
  for (var i = 0; i < value.length; i++) {
    final item = value[i];
    if (item is int) {
      result.add(item);
    } else {
      sink.error(code, message, jsonPath: '$jsonPath[$i]');
    }
  }
  return List.unmodifiable(result);
}
