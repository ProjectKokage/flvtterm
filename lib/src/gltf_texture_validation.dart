part of '../flvtterm.dart';

void _validateGltfTextureResources(GltfAsset gltf, _DiagnosticSink sink) {
  final rawTextures = _list(gltf.json['textures']);
  for (final texture in gltf.textures) {
    final raw = _object(rawTextures.elementAtOrNull(texture.index));
    if (raw.containsKey('sampler') && raw['sampler'] is! int) {
      sink.error(
        'gltf.invalidTextureSampler',
        'Texture sampler must be an integer.',
        jsonPath: _texturePath(texture.index, '.sampler'),
      );
    }
    if (raw.containsKey('source') && raw['source'] is! int) {
      sink.error(
        'gltf.invalidTextureSource',
        'Texture source must be an integer.',
        jsonPath: _texturePath(texture.index, '.source'),
      );
    }
    if (texture.sampler != null) {
      _validateIndex(
        texture.sampler!,
        gltf.samplers.length,
        sink,
        'gltf.invalidTextureSampler',
        _texturePath(texture.index, '.sampler'),
      );
    }
    if (texture.source != null) {
      _validateIndex(
        texture.source!,
        gltf.images.length,
        sink,
        'gltf.invalidTextureSource',
        _texturePath(texture.index, '.source'),
      );
    } else if (texture.extensions.isEmpty) {
      sink.warning(
        'gltf.textureWithoutSource',
        'Texture without source needs an extension-defined image source.',
        jsonPath: _texturePath(texture.index, ''),
      );
    }
  }

  final rawSamplers = _list(gltf.json['samplers']);
  for (final sampler in gltf.samplers) {
    final raw = _object(rawSamplers.elementAtOrNull(sampler.index));
    if (_hasInvalidSamplerField(raw, 'magFilter', _samplerMagFilters)) {
      sink.error(
        'gltf.invalidSamplerMagFilter',
        'Sampler magFilter must be NEAREST or LINEAR.',
        jsonPath: _samplerPath(sampler.index, '.magFilter'),
      );
    }
    if (_hasInvalidSamplerField(raw, 'minFilter', _samplerMinFilters)) {
      sink.error(
        'gltf.invalidSamplerMinFilter',
        'Sampler minFilter is not a valid glTF filter mode.',
        jsonPath: _samplerPath(sampler.index, '.minFilter'),
      );
    }
    if (_hasInvalidSamplerField(raw, 'wrapS', _samplerWrapModes)) {
      sink.error(
        'gltf.invalidSamplerWrapS',
        'Sampler wrapS is not a valid glTF wrap mode.',
        jsonPath: _samplerPath(sampler.index, '.wrapS'),
      );
    }
    if (_hasInvalidSamplerField(raw, 'wrapT', _samplerWrapModes)) {
      sink.error(
        'gltf.invalidSamplerWrapT',
        'Sampler wrapT is not a valid glTF wrap mode.',
        jsonPath: _samplerPath(sampler.index, '.wrapT'),
      );
    }
  }

  final rawImages = _list(gltf.json['images']);
  for (final image in gltf.images) {
    final raw = _object(rawImages.elementAtOrNull(image.index));
    final hasUri = raw.containsKey('uri');
    final hasBufferView = raw.containsKey('bufferView');
    if (!hasUri && !hasBufferView) {
      sink.error(
        'gltf.missingImageSource',
        'Image must define either uri or bufferView.',
        jsonPath: _imagePath(image.index, ''),
      );
    }
    if (hasUri && raw['uri'] is! String) {
      sink.error(
        'gltf.invalidImageUri',
        'Image uri must be a string.',
        jsonPath: _imagePath(image.index, '.uri'),
      );
    }
    if (image.uri != null &&
        !image.uri!.startsWith('data:') &&
        image.data == null) {
      final unresolved = gltf._hasUriResolver;
      sink.error(
        unresolved
            ? 'gltf.unresolvedExternalImageUri'
            : 'gltf.unsupportedExternalImageUri',
        unresolved
            ? _unresolvedUriMessage(
                'External image URI was not resolved.',
                gltf._uriResolverFailures['\$.images[${image.index}].uri'],
              )
            : 'External image URIs require a GltfUriResolver.',
        jsonPath: '\$.images[${image.index}].uri',
      );
    }
    if (hasBufferView && raw['bufferView'] is! int) {
      sink.error(
        'gltf.invalidImageBufferView',
        'Image bufferView must be an integer.',
        jsonPath: _imagePath(image.index, '.bufferView'),
      );
    }
    final hasInvalidMimeType =
        raw.containsKey('mimeType') &&
        (raw['mimeType'] is! String ||
            !_gltfImageMimeTypes.contains(raw['mimeType']));
    if (hasInvalidMimeType ||
        (!hasInvalidMimeType &&
            image.uri != null &&
            image.uri!.startsWith('data:') &&
            !_gltfImageMimeTypes.contains(_dataUriMediaType(image.uri!)))) {
      sink.error(
        'gltf.invalidImageMimeType',
        'Image mimeType must be image/jpeg or image/png.',
        jsonPath: _imagePath(
          image.index,
          hasInvalidMimeType ? '.mimeType' : '.uri',
        ),
      );
    }
    if (!hasInvalidMimeType &&
        image.uri != null &&
        image.uri!.startsWith('data:')) {
      final mediaType = _dataUriMediaType(image.uri!);
      if (image.mimeType != null &&
          mediaType != null &&
          mediaType != image.mimeType) {
        sink.error(
          'gltf.imageMimeTypeMismatch',
          'Image data URI media type must match image.mimeType.',
          jsonPath: '\$.images[${image.index}].mimeType',
        );
      }
    }
    _validateImageData(image, gltf, sink);
    if (hasUri && hasBufferView) {
      sink.error(
        'gltf.invalidImageSource',
        'Image must not define both uri and bufferView.',
        jsonPath: _imagePath(image.index, ''),
      );
    }
    if (hasBufferView &&
        !raw.containsKey('mimeType') &&
        image.bufferView != null) {
      sink.error(
        'gltf.missingImageMimeType',
        'Image mimeType is required when bufferView is used.',
        jsonPath: _imagePath(image.index, '.mimeType'),
      );
    }
    if (image.bufferView != null) {
      _validateIndex(
        image.bufferView!,
        gltf.bufferViews.length,
        sink,
        'gltf.invalidImageBufferView',
        _imagePath(image.index, '.bufferView'),
      );
    }
  }
}

String _texturePath(int textureIndex, String suffix) =>
    '\$.textures[$textureIndex]$suffix';

String _samplerPath(int samplerIndex, String suffix) =>
    '\$.samplers[$samplerIndex]$suffix';

String _imagePath(int imageIndex, String suffix) =>
    '\$.images[$imageIndex]$suffix';

void _validateImageData(GltfImage image, GltfAsset gltf, _DiagnosticSink sink) {
  final mimeType = image.mimeType ?? _dataUriMediaType(image.uri ?? '');
  if (!_gltfImageMimeTypes.contains(mimeType)) return;
  final bytes = _imageBytes(image, gltf, sink);
  if (bytes == null || bytes.isEmpty) return;
  final valid = switch (mimeType) {
    'image/png' => _hasPngSignature(bytes),
    'image/jpeg' => _hasJpegSignature(bytes),
    _ => true,
  };
  if (valid) return;
  sink.error(
    'gltf.invalidImageData',
    'Image data must match its declared MIME type.',
    jsonPath: '\$.images[${image.index}]',
  );
}

Uint8List? _imageBytes(GltfImage image, GltfAsset gltf, _DiagnosticSink sink) {
  if (image.data != null) return image.data;
  final bufferView = image.bufferView;
  if (bufferView == null) return null;
  final view = gltf.bufferViews.elementAtOrNull(bufferView);
  final source = _bufferBytes(gltf, view?.buffer);
  final length = view?.byteLength;
  if (view == null || source == null || length == null) return null;
  final start = view.byteOffset;
  final end = start + length;
  if (start < 0 || length < 0 || end > source.length) return null;
  return Uint8List.sublistView(source, start, end);
}

bool _hasPngSignature(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length < signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  return true;
}

bool _hasJpegSignature(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xff &&
    bytes[1] == 0xd8 &&
    bytes[2] == 0xff;
