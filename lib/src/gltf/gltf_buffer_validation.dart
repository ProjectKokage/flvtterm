part of '../../flvtterm.dart';

void _validateGltfBuffers(GltfAsset gltf, _DiagnosticSink sink) {
  final rawBuffers = _list(gltf.json['buffers']);
  for (final buffer in gltf.buffers) {
    final raw = _object(rawBuffers.elementAtOrNull(buffer.index));
    if (buffer.byteLength == null || buffer.byteLength! < 1) {
      sink.error(
        'gltf.invalidBufferByteLength',
        'Buffer byteLength must be a positive integer.',
        jsonPath: '\$.buffers[${buffer.index}].byteLength',
      );
    }
    if (raw.containsKey('uri') && raw['uri'] is! String) {
      sink.error(
        'gltf.invalidBufferUri',
        'Buffer uri must be a string.',
        jsonPath: _bufferPath(buffer.index, '.uri'),
      );
    }
    if (buffer.uri != null && buffer.index == 0 && gltf.binaryChunk != null) {
      sink.error(
        'gltf.invalidGlbBufferUri',
        'GLB buffer 0 must not define uri when backed by a BIN chunk.',
        jsonPath: r'$.buffers[0].uri',
      );
    }
    if (buffer.uri == null &&
        !(buffer.index == 0 && gltf.binaryChunk != null)) {
      sink.error(
        'gltf.missingBufferUri',
        'Buffer uri is required when the buffer is not backed by a GLB BIN chunk.',
        jsonPath: _bufferPath(buffer.index, '.uri'),
      );
    }
    if (buffer.uri != null &&
        !buffer.uri!.startsWith('data:') &&
        !(buffer.index == 0 && gltf.binaryChunk != null) &&
        buffer.data == null) {
      final unresolved = gltf._hasUriResolver;
      sink.error(
        unresolved
            ? 'gltf.unresolvedExternalBufferUri'
            : 'gltf.unsupportedExternalBufferUri',
        unresolved
            ? _unresolvedUriMessage(
                'External buffer URI was not resolved.',
                gltf._uriResolverFailures['\$.buffers[${buffer.index}].uri'],
              )
            : 'External buffer URIs require a GltfUriResolver.',
        jsonPath: '\$.buffers[${buffer.index}].uri',
      );
    }
    if (buffer.uri != null && buffer.uri!.startsWith('data:')) {
      final mediaType = _dataUriMediaType(buffer.uri!);
      if (mediaType != null && !_gltfBufferMimeTypes.contains(mediaType)) {
        sink.error(
          'gltf.invalidBufferDataUri',
          'Buffer data URI media type must be application/octet-stream or application/gltf-buffer.',
          jsonPath: _bufferPath(buffer.index, '.uri'),
        );
      }
      if (mediaType != null && !_dataUriIsBase64(buffer.uri!)) {
        sink.error(
          'gltf.invalidBufferDataUri',
          'Buffer data URI must use base64 encoding.',
          jsonPath: _bufferPath(buffer.index, '.uri'),
        );
      }
    }
    final bufferBytes = _bufferBytes(gltf, buffer.index);
    if (buffer.byteLength != null &&
        bufferBytes != null &&
        buffer.byteLength! > bufferBytes.length) {
      sink.error(
        'gltf.bufferOutOfRange',
        'Buffer byteLength exceeds the available buffer data.',
        jsonPath: '\$.buffers[${buffer.index}].byteLength',
      );
    }
    if (buffer.index == 0 &&
        gltf.binaryChunk != null &&
        buffer.byteLength != null &&
        gltf.binaryChunk!.length > buffer.byteLength! + 3) {
      sink.error(
        'gltf.invalidGlbBinChunkLength',
        'GLB BIN chunk may be at most 3 bytes larger than buffer 0 byteLength.',
        jsonPath: r'$.buffers[0].byteLength',
      );
    }
    if (buffer.index == 0 &&
        gltf.binaryChunk != null &&
        buffer.byteLength != null &&
        buffer.byteLength! < gltf.binaryChunk!.length &&
        !_hasZeroPadding(gltf.binaryChunk!, buffer.byteLength!)) {
      sink.error(
        'gltf.invalidGlbBinChunkPadding',
        'GLB BIN chunk padding bytes must be zeros.',
        jsonPath: r'$.buffers[0].byteLength',
      );
    }
  }
}

String _bufferPath(int bufferIndex, String suffix) =>
    '\$.buffers[$bufferIndex]$suffix';

String _unresolvedUriMessage(String fallback, String? failure) {
  return failure == null ? fallback : '$fallback $failure';
}

bool _hasZeroPadding(Uint8List bytes, int start) {
  for (var i = start; i < bytes.length; i++) {
    if (bytes[i] != 0) return false;
  }
  return true;
}

void _validateGltfBufferViews(GltfAsset gltf, _DiagnosticSink sink) {
  final vertexAttributeBufferViewUseCounts =
      _vertexAttributeBufferViewUseCounts(gltf);
  _validateBufferViewDataKinds(gltf, sink);
  final rawBufferViews = _list(gltf.json['bufferViews']);
  for (final view in gltf.bufferViews) {
    final raw = _object(rawBufferViews.elementAtOrNull(view.index));
    if (!raw.containsKey('buffer')) {
      sink.error(
        'gltf.bufferViewMissingBuffer',
        'bufferView.buffer is required.',
        jsonPath: _bufferViewPath(view.index, '.buffer'),
      );
    } else if (raw['buffer'] is! int) {
      sink.error(
        'gltf.invalidBufferViewBuffer',
        'bufferView.buffer must be an integer.',
        jsonPath: _bufferViewPath(view.index, '.buffer'),
      );
    } else {
      _validateIndex(
        view.buffer!,
        gltf.buffers.length,
        sink,
        'gltf.invalidBufferViewBuffer',
        _bufferViewPath(view.index, '.buffer'),
      );
    }
    final hasInvalidRange =
        (raw.containsKey('byteOffset') && raw['byteOffset'] is! int) ||
        !raw.containsKey('byteLength') ||
        raw['byteLength'] is! int ||
        view.byteOffset < 0 ||
        (view.byteLength != null && view.byteLength! < 1);
    if (hasInvalidRange) {
      sink.error(
        'gltf.invalidBufferViewRange',
        'bufferView byteOffset must be non-negative and byteLength must be positive.',
        jsonPath: '\$.bufferViews[${view.index}]',
      );
    }
    if (raw.containsKey('byteStride') && raw['byteStride'] is! int) {
      sink.error(
        'gltf.invalidBufferViewStride',
        'bufferView.byteStride must be an integer.',
        jsonPath: _bufferViewPath(view.index, '.byteStride'),
      );
    } else if (view.byteStride != null &&
        (view.byteStride! < 4 ||
            view.byteStride! > 252 ||
            view.byteStride! % 4 != 0)) {
      sink.error(
        'gltf.invalidBufferViewStride',
        'bufferView.byteStride must be a multiple of 4 between 4 and 252.',
        jsonPath: _bufferViewPath(view.index, '.byteStride'),
      );
    } else if (view.byteStride != null &&
        !vertexAttributeBufferViewUseCounts.containsKey(view.index)) {
      sink.error(
        'gltf.invalidBufferViewStride',
        'bufferView.byteStride may only be defined for vertex attribute data.',
        jsonPath: _bufferViewPath(view.index, '.byteStride'),
      );
    } else if (view.byteStride == null &&
        (vertexAttributeBufferViewUseCounts[view.index] ?? 0) > 1) {
      sink.error(
        'gltf.missingBufferViewStride',
        'bufferView.byteStride is required when multiple vertex attributes share a bufferView.',
        jsonPath: _bufferViewPath(view.index, '.byteStride'),
      );
    }
    if (raw.containsKey('target') &&
        (raw['target'] is! int ||
            (view.target != 34962 && view.target != 34963))) {
      sink.error(
        'gltf.invalidBufferViewTarget',
        'bufferView.target must be ARRAY_BUFFER or ELEMENT_ARRAY_BUFFER.',
        jsonPath: _bufferViewPath(view.index, '.target'),
      );
    }
    final bufferIndex = view.buffer;
    final byteLength = view.byteLength;
    final declaredBufferLength = bufferIndex == null
        ? null
        : gltf.buffers.elementAtOrNull(bufferIndex)?.byteLength;
    if (byteLength != null &&
        declaredBufferLength != null &&
        view.byteOffset + byteLength > declaredBufferLength) {
      sink.error(
        'gltf.bufferViewOutOfRange',
        'bufferView range exceeds its buffer byteLength.',
        jsonPath: _bufferViewPath(view.index, '.byteLength'),
      );
    }
  }
}

String _bufferViewPath(int viewIndex, String suffix) =>
    '\$.bufferViews[$viewIndex]$suffix';

Map<int, int> _vertexAttributeBufferViewUseCounts(GltfAsset gltf) {
  final accessorsByBufferView = <int, Set<int>>{};
  void addAccessorBufferView(int accessorIndex) {
    final bufferView = gltf.accessors
        .elementAtOrNull(accessorIndex)
        ?.bufferView;
    if (bufferView != null) {
      accessorsByBufferView
          .putIfAbsent(bufferView, () => <int>{})
          .add(accessorIndex);
    }
  }

  for (final mesh in gltf.meshes) {
    for (final primitive in mesh.primitives) {
      for (final accessor in primitive.attributes.values) {
        addAccessorBufferView(accessor);
      }
      for (final target in primitive.targets) {
        for (final accessor in target.values) {
          addAccessorBufferView(accessor);
        }
      }
    }
  }
  return {
    for (final entry in accessorsByBufferView.entries)
      entry.key: entry.value.length,
  };
}

void _validateBufferViewDataKinds(GltfAsset gltf, _DiagnosticSink sink) {
  final kindsByView = <int, Set<String>>{};
  void addKind(int? accessorIndex, String kind) {
    final view = accessorIndex == null
        ? null
        : gltf.accessors.elementAtOrNull(accessorIndex)?.bufferView;
    if (view == null || view < 0 || view >= gltf.bufferViews.length) return;
    kindsByView.putIfAbsent(view, () => <String>{}).add(kind);
  }

  for (final image in gltf.images) {
    final view = image.bufferView;
    if (view == null || view < 0 || view >= gltf.bufferViews.length) continue;
    kindsByView.putIfAbsent(view, () => <String>{}).add('image');
  }
  for (final skin in gltf.skins) {
    addKind(skin.inverseBindMatrices, 'inverseBindMatrices');
  }
  for (final mesh in gltf.meshes) {
    for (final primitive in mesh.primitives) {
      addKind(primitive.indices, 'indices');
      for (final accessor in primitive.attributes.values) {
        addKind(accessor, 'attributes');
      }
      for (final target in primitive.targets) {
        for (final accessor in target.values) {
          addKind(accessor, 'attributes');
        }
      }
    }
  }

  for (final entry in kindsByView.entries) {
    if (entry.value.length < 2) continue;
    sink.error(
      'gltf.mixedBufferViewData',
      'A bufferView used for images, vertex indices, vertex attributes, or inverse bind matrices must contain only one kind of data.',
      jsonPath: '\$.bufferViews[${entry.key}]',
    );
  }
}

String? _dataUriMediaType(String uri) {
  final comma = uri.indexOf(',');
  if (comma < 0) return null;
  return uri.substring(5, comma).toLowerCase().split(';').first;
}

bool _dataUriIsBase64(String uri) {
  final comma = uri.indexOf(',');
  if (comma < 0) return false;
  return uri.substring(5, comma).toLowerCase().split(';').contains('base64');
}
