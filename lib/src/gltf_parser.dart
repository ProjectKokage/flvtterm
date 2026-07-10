part of '../flvtterm.dart';

List<GltfBuffer> _parseBuffers(
  Object? value,
  _DiagnosticSink sink,
  Uint8List? binaryChunk,
  GltfUriResolver? uriResolver,
  Map<String, String> uriResolverFailures,
) {
  final list = _list(value);
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
  _DiagnosticSink sink,
  Uint8List? binaryChunk,
  GltfUriResolver? uriResolver,
  Map<String, String> uriResolverFailures,
) {
  final raw = _object(value);
  final uri = _string(raw['uri']);
  final byteLength = _int(raw['byteLength']);
  final data = index == 0 && binaryChunk != null
      ? binaryChunk
      : _decodeBufferBytes(uri, index, sink, uriResolver, uriResolverFailures);
  return GltfBuffer._(
    index: index,
    name: _string(raw['name']),
    uri: uri,
    byteLength: byteLength,
    data: _declaredBufferBytes(data, byteLength),
    extensions: _object(raw['extensions']),
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
  _DiagnosticSink sink,
  GltfUriResolver? uriResolver,
  Map<String, String> uriResolverFailures,
) {
  if (uri == null) return null;
  if (uri.startsWith('data:')) {
    return _decodeBufferDataUri(uri, bufferIndex, sink);
  }
  if (uriResolver == null) return null;
  try {
    return uriResolver(uri);
  } catch (error) {
    uriResolverFailures['\$.buffers[$bufferIndex].uri'] = error.toString();
    return null;
  }
}

Uint8List? _decodeBufferDataUri(
  String? uri,
  int bufferIndex,
  _DiagnosticSink sink,
) {
  if (uri == null || !uri.startsWith('data:')) return null;
  final comma = uri.indexOf(',');
  if (comma < 0) {
    sink.error(
      'gltf.invalidBufferDataUri',
      'Buffer data URI is missing a comma separator.',
      jsonPath: '\$.buffers[$bufferIndex].uri',
    );
    return null;
  }

  final metadata = uri.substring(5, comma).toLowerCase();
  final payload = uri.substring(comma + 1);
  try {
    if (metadata.split(';').contains('base64')) {
      return Uint8List.fromList(base64.decode(payload));
    }
    return Uint8List.fromList(utf8.encode(Uri.decodeComponent(payload)));
  } on FormatException catch (error) {
    sink.error(
      'gltf.invalidBufferDataUri',
      'Could not decode buffer $bufferIndex data URI: ${error.message}',
      jsonPath: '\$.buffers[$bufferIndex].uri',
    );
    return null;
  } on ArgumentError catch (error) {
    sink.error(
      'gltf.invalidBufferDataUri',
      'Could not decode buffer $bufferIndex data URI: ${error.message}',
      jsonPath: '\$.buffers[$bufferIndex].uri',
    );
    return null;
  }
}

List<GltfBufferView> _parseBufferViews(Object? value) {
  final list = _list(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfBufferView._(
        index: i,
        name: _string(_object(list[i])['name']),
        buffer: _int(_object(list[i])['buffer']),
        byteOffset: _int(_object(list[i])['byteOffset']) ?? 0,
        byteLength: _int(_object(list[i])['byteLength']),
        byteStride: _int(_object(list[i])['byteStride']),
        target: _int(_object(list[i])['target']),
        extensions: _object(_object(list[i])['extensions']),
        extras: _object(list[i])['extras'],
      ),
  ];
}

List<GltfCamera> _parseCameras(Object? value) {
  final list = _list(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfCamera._(
        index: i,
        name: _string(_object(list[i])['name']),
        type: GltfCameraType.fromSpecName(_string(_object(list[i])['type'])),
        perspective: _parseCameraPerspective(_object(list[i])['perspective']),
        orthographic: _parseCameraOrthographic(
          _object(list[i])['orthographic'],
        ),
        extensions: _object(_object(list[i])['extensions']),
        extras: _object(list[i])['extras'],
      ),
  ];
}

GltfCameraPerspective? _parseCameraPerspective(Object? value) {
  final raw = _object(value);
  if (raw.isEmpty) return null;
  return GltfCameraPerspective._(
    aspectRatio: _double(raw['aspectRatio']),
    yfov: _double(raw['yfov']),
    zfar: _double(raw['zfar']),
    znear: _double(raw['znear']),
    extensions: _object(raw['extensions']),
    extras: raw['extras'],
  );
}

GltfCameraOrthographic? _parseCameraOrthographic(Object? value) {
  final raw = _object(value);
  if (raw.isEmpty) return null;
  return GltfCameraOrthographic._(
    xmag: _double(raw['xmag']),
    ymag: _double(raw['ymag']),
    zfar: _double(raw['zfar']),
    znear: _double(raw['znear']),
    extensions: _object(raw['extensions']),
    extras: raw['extras'],
  );
}

List<GltfScene> _parseScenes(Object? value, _DiagnosticSink sink) {
  final list = _list(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfScene._(
        index: i,
        name: _string(_object(list[i])['name']),
        nodes: _parseIndexList(
          _object(list[i])['nodes'],
          sink,
          code: 'gltf.invalidSceneNode',
          jsonPath: '\$.scenes[$i].nodes',
          message: 'Scene node references must be integers.',
        ),
        extensions: _object(_object(list[i])['extensions']),
        extras: _object(list[i])['extras'],
      ),
  ];
}

List<GltfNode> _parseNodes(Object? value, _DiagnosticSink sink) {
  final list = _list(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfNode._(
        index: i,
        name: _string(_object(list[i])['name']),
        children: _parseIndexList(
          _object(list[i])['children'],
          sink,
          code: 'gltf.invalidNodeChild',
          jsonPath: '\$.nodes[$i].children',
          message: 'Node child references must be integers.',
        ),
        camera: _int(_object(list[i])['camera']),
        mesh: _int(_object(list[i])['mesh']),
        skin: _int(_object(list[i])['skin']),
        matrix: _parseNodeMatrix(_object(list[i])['matrix']),
        translation: _doubleList(_object(list[i])['translation'], 3, const [
          0,
          0,
          0,
        ]),
        rotation: _doubleList(_object(list[i])['rotation'], 4, const [
          0,
          0,
          0,
          1,
        ]),
        scale: _doubleList(_object(list[i])['scale'], 3, const [1, 1, 1]),
        weights: _doubleValues(_object(list[i])['weights']),
        nodeConstraint: _parseNodeConstraint(
          i,
          _object(_object(list[i])['extensions']),
          sink,
        ),
        extensions: _object(_object(list[i])['extensions']),
        extras: _object(list[i])['extras'],
      ),
  ];
}

VrmMatrix4? _parseNodeMatrix(Object? value) {
  if (value == null) return null;
  final values = _doubleList(value, 16, const []);
  return values.length == 16 ? VrmMatrix4(values) : null;
}

VrmNodeConstraint? _parseNodeConstraint(
  int nodeIndex,
  Map<String, Object?> extensions,
  _DiagnosticSink sink,
) {
  if (!extensions.containsKey('VRMC_node_constraint')) return null;
  final value = extensions['VRMC_node_constraint'];
  if (value is! Map) {
    sink.error(
      'constraint.invalidExtensionObject',
      'VRMC_node_constraint must be a JSON object.',
      jsonPath: _nodeConstraintPath(nodeIndex, ''),
      gltfNodeIndex: nodeIndex,
    );
    return null;
  }
  final raw = _object(value);
  if (raw.containsKey('constraint') && raw['constraint'] is! Map) {
    sink.error(
      'constraint.invalidConstraintObject',
      'VRMC_node_constraint.constraint must be a JSON object.',
      jsonPath: _nodeConstraintPath(nodeIndex, '.constraint'),
      gltfNodeIndex: nodeIndex,
    );
  }
  final constraint = _object(raw['constraint']);
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
      jsonPath: _nodeConstraintPath(nodeIndex, '.constraint.${kind.specName}'),
      gltfNodeIndex: nodeIndex,
    );
  }
  final parameters = switch (kind) {
    VrmNodeConstraintKind.roll => _object(constraint['roll']),
    VrmNodeConstraintKind.aim => _object(constraint['aim']),
    VrmNodeConstraintKind.rotation => _object(constraint['rotation']),
    null => const <String, Object?>{},
  };
  return VrmNodeConstraint._(
    destinationNode: nodeIndex,
    specVersion: _string(raw['specVersion']),
    kind: kind,
    declaredKindCount: declaredKinds.length,
    source: _int(parameters['source']),
    weight: _double(parameters['weight']) ?? 1,
    rollAxis: VrmNodeConstraintRollAxis.fromSpecName(
      _string(parameters['rollAxis']),
    ),
    aimAxis: VrmNodeConstraintAimAxis.fromSpecName(
      _string(parameters['aimAxis']),
    ),
    raw: raw,
  );
}

List<GltfMesh> _parseMeshes(Object? value) {
  final list = _list(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfMesh._(
        index: i,
        name: _string(_object(list[i])['name']),
        primitives: _parsePrimitives(_object(list[i])['primitives']),
        weights: _doubleValues(_object(list[i])['weights']),
        extensions: _object(_object(list[i])['extensions']),
        extras: _object(list[i])['extras'],
      ),
  ];
}

List<GltfMeshPrimitive> _parsePrimitives(Object? value) {
  final list = _list(value);
  return [
    for (final primitive in list)
      GltfMeshPrimitive._(
        mode: _int(_object(primitive)['mode']) ?? 4,
        material: _int(_object(primitive)['material']),
        indices: _int(_object(primitive)['indices']),
        attributes: _intMap(_object(primitive)['attributes']),
        targets: [
          for (final target in _list(_object(primitive)['targets']))
            _intMap(target),
        ],
        extensions: _object(_object(primitive)['extensions']),
        extras: _object(primitive)['extras'],
      ),
  ];
}

List<GltfSkin> _parseSkins(Object? value, _DiagnosticSink sink) {
  final list = _list(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfSkin._(
        index: i,
        name: _string(_object(list[i])['name']),
        joints: _parseIndexList(
          _object(list[i])['joints'],
          sink,
          code: 'gltf.invalidSkinJoint',
          jsonPath: '\$.skins[$i].joints',
          message: 'Skin joint references must be integers.',
        ),
        skeleton: _int(_object(list[i])['skeleton']),
        inverseBindMatrices: _int(_object(list[i])['inverseBindMatrices']),
        extensions: _object(_object(list[i])['extensions']),
        extras: _object(list[i])['extras'],
      ),
  ];
}

List<GltfAccessor> _parseAccessors(Object? value) {
  final list = _list(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfAccessor._(
        index: i,
        name: _string(_object(list[i])['name']),
        bufferView: _int(_object(list[i])['bufferView']),
        byteOffset: _int(_object(list[i])['byteOffset']) ?? 0,
        count: _int(_object(list[i])['count']),
        componentType: _int(_object(list[i])['componentType']),
        type: _string(_object(list[i])['type']),
        normalized: _bool(_object(list[i])['normalized']) ?? false,
        minimum: _object(list[i]).containsKey('min')
            ? _doubleValues(_object(list[i])['min'])
            : null,
        maximum: _object(list[i]).containsKey('max')
            ? _doubleValues(_object(list[i])['max'])
            : null,
        sparse: _parseAccessorSparse(_object(list[i])['sparse']),
        extensions: _object(_object(list[i])['extensions']),
        extras: _object(list[i])['extras'],
      ),
  ];
}

GltfAccessorSparse? _parseAccessorSparse(Object? value) {
  final raw = _object(value);
  if (raw.isEmpty) return null;
  final indices = _object(raw['indices']);
  final values = _object(raw['values']);
  return GltfAccessorSparse._(
    count: _int(raw['count']),
    indicesBufferView: _int(indices['bufferView']),
    indicesByteOffset: _int(indices['byteOffset']) ?? 0,
    indicesComponentType: _int(indices['componentType']),
    indicesExtensions: _object(indices['extensions']),
    indicesExtras: indices['extras'],
    valuesBufferView: _int(values['bufferView']),
    valuesByteOffset: _int(values['byteOffset']) ?? 0,
    valuesExtensions: _object(values['extensions']),
    valuesExtras: values['extras'],
    extensions: _object(raw['extensions']),
    extras: raw['extras'],
  );
}

List<GltfTexture> _parseTextures(Object? value) {
  final list = _list(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfTexture._(
        index: i,
        name: _string(_object(list[i])['name']),
        source: _int(_object(list[i])['source']),
        sampler: _int(_object(list[i])['sampler']),
        extensions: _object(_object(list[i])['extensions']),
        extras: _object(list[i])['extras'],
      ),
  ];
}

List<GltfImage> _parseImages(
  Object? value,
  _DiagnosticSink sink,
  List<GltfBuffer> buffers,
  List<GltfBufferView> bufferViews,
  GltfUriResolver? uriResolver,
  Map<String, String> uriResolverFailures,
) {
  final list = _list(value);
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
  _DiagnosticSink sink,
  List<GltfBuffer> buffers,
  List<GltfBufferView> bufferViews,
  GltfUriResolver? uriResolver,
  Map<String, String> uriResolverFailures,
) {
  final raw = _object(value);
  final uri = _string(raw['uri']);
  final bufferView = _int(raw['bufferView']);
  return GltfImage._(
    index: index,
    name: _string(raw['name']),
    uri: uri,
    bufferView: bufferView,
    mimeType: _string(raw['mimeType']),
    data:
        _decodeImageBytes(uri, index, sink, uriResolver, uriResolverFailures) ??
        _imageBufferViewBytes(bufferView, buffers, bufferViews),
    extensions: _object(raw['extensions']),
    extras: raw['extras'],
  );
}

Uint8List? _imageBufferViewBytes(
  int? bufferViewIndex,
  List<GltfBuffer> buffers,
  List<GltfBufferView> bufferViews,
) {
  if (bufferViewIndex == null) return null;
  final view = bufferViews.elementAtOrNull(bufferViewIndex);
  final bytes = buffers.elementAtOrNull(view?.buffer ?? -1)?.data;
  final length = view?.byteLength;
  if (view == null || bytes == null || length == null) return null;
  final start = view.byteOffset;
  final end = start + length;
  if (start < 0 || length < 0 || end > bytes.length) return null;
  return Uint8List.sublistView(bytes, start, end);
}

Uint8List? _decodeImageBytes(
  String? uri,
  int imageIndex,
  _DiagnosticSink sink,
  GltfUriResolver? uriResolver,
  Map<String, String> uriResolverFailures,
) {
  if (uri == null) return null;
  if (uri.startsWith('data:')) {
    return _decodeImageDataUri(uri, imageIndex, sink);
  }
  if (uriResolver == null) return null;
  try {
    return uriResolver(uri);
  } catch (error) {
    uriResolverFailures['\$.images[$imageIndex].uri'] = error.toString();
    return null;
  }
}

Uint8List? _decodeImageDataUri(
  String uri,
  int imageIndex,
  _DiagnosticSink sink,
) {
  final comma = uri.indexOf(',');
  if (comma < 0) {
    sink.error(
      'gltf.invalidImageDataUri',
      'Image data URI is missing a comma separator.',
      jsonPath: '\$.images[$imageIndex].uri',
    );
    return null;
  }
  final metadata = uri.substring(5, comma).toLowerCase();
  final payload = uri.substring(comma + 1);
  try {
    if (metadata.split(';').contains('base64')) {
      return Uint8List.fromList(base64.decode(payload));
    }
    return Uint8List.fromList(utf8.encode(Uri.decodeComponent(payload)));
  } on FormatException catch (error) {
    sink.error(
      'gltf.invalidImageDataUri',
      'Could not decode image data URI: ${error.message}',
      jsonPath: '\$.images[$imageIndex].uri',
    );
    return null;
  } on ArgumentError catch (error) {
    sink.error(
      'gltf.invalidImageDataUri',
      'Could not decode image data URI: ${error.message}',
      jsonPath: '\$.images[$imageIndex].uri',
    );
    return null;
  }
}

List<GltfSampler> _parseSamplers(Object? value) {
  final list = _list(value);
  return [
    for (var i = 0; i < list.length; i++)
      GltfSampler._(
        index: i,
        name: _string(_object(list[i])['name']),
        magFilter: _int(_object(list[i])['magFilter']),
        minFilter: _int(_object(list[i])['minFilter']),
        wrapS: _int(_object(list[i])['wrapS']) ?? 10497,
        wrapT: _int(_object(list[i])['wrapT']) ?? 10497,
        extensions: _object(_object(list[i])['extensions']),
        extras: _object(list[i])['extras'],
      ),
  ];
}

List<String> _parseRootStringList(
  Map<String, Object?> json,
  String key,
  String code,
  _DiagnosticSink sink,
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
  _DiagnosticSink sink, {
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
