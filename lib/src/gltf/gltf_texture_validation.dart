import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../diagnostics.dart';
import '../json_values.dart';
import '../safe_list_index.dart';
import 'gltf_accessor_validation.dart';
import 'gltf_buffer_validation.dart';
import 'gltf_node_constraint_validation.dart';
import 'gltf_resource_types.dart';
import 'gltf_types.dart';

const _gltfImageMimeTypes = {'image/jpeg', 'image/png'};
const _samplerMagFilters = {9728, 9729};
const _samplerMinFilters = {9728, 9729, 9984, 9985, 9986, 9987};
const _samplerWrapModes = {33071, 33648, 10497};

@internal
void validateGltfTextureResources(GltfAsset gltf, DiagnosticSink sink) {
  final rawTextures = jsonList(gltf.json['textures']);
  for (final texture in gltf.textures) {
    final raw = jsonObject(rawTextures.elementAtOrNull(texture.index));
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
      validateIndex(
        texture.sampler!,
        gltf.samplers.length,
        sink,
        'gltf.invalidTextureSampler',
        _texturePath(texture.index, '.sampler'),
      );
    }
    if (texture.source != null) {
      validateIndex(
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

  final rawSamplers = jsonList(gltf.json['samplers']);
  for (final sampler in gltf.samplers) {
    final raw = jsonObject(rawSamplers.elementAtOrNull(sampler.index));
    if (hasInvalidSamplerField(raw, 'magFilter', _samplerMagFilters)) {
      sink.error(
        'gltf.invalidSamplerMagFilter',
        'Sampler magFilter must be NEAREST or LINEAR.',
        jsonPath: _samplerPath(sampler.index, '.magFilter'),
      );
    }
    if (hasInvalidSamplerField(raw, 'minFilter', _samplerMinFilters)) {
      sink.error(
        'gltf.invalidSamplerMinFilter',
        'Sampler minFilter is not a valid glTF filter mode.',
        jsonPath: _samplerPath(sampler.index, '.minFilter'),
      );
    }
    if (hasInvalidSamplerField(raw, 'wrapS', _samplerWrapModes)) {
      sink.error(
        'gltf.invalidSamplerWrapS',
        'Sampler wrapS is not a valid glTF wrap mode.',
        jsonPath: _samplerPath(sampler.index, '.wrapS'),
      );
    }
    if (hasInvalidSamplerField(raw, 'wrapT', _samplerWrapModes)) {
      sink.error(
        'gltf.invalidSamplerWrapT',
        'Sampler wrapT is not a valid glTF wrap mode.',
        jsonPath: _samplerPath(sampler.index, '.wrapT'),
      );
    }
  }

  final rawImages = jsonList(gltf.json['images']);
  for (final image in gltf.images) {
    final raw = jsonObject(rawImages.elementAtOrNull(image.index));
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
      final unresolved = gltf.hasUriResolver;
      sink.error(
        unresolved
            ? 'gltf.unresolvedExternalImageUri'
            : 'gltf.unsupportedExternalImageUri',
        unresolved
            ? unresolvedUriMessage(
                'External image URI was not resolved.',
                gltf.uriResolverFailures['\$.images[${image.index}].uri'],
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
            !_gltfImageMimeTypes.contains(dataUriMediaType(image.uri!)))) {
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
      final mediaType = dataUriMediaType(image.uri!);
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
    _validateImageData(image, sink);
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
      validateIndex(
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

void _validateImageData(GltfImage image, DiagnosticSink sink) {
  final mimeType = image.mimeType ?? dataUriMediaType(image.uri ?? '');
  if (!_gltfImageMimeTypes.contains(mimeType)) return;
  // The parser resolved the image's bytes, from its URI or its bufferView.
  final bytes = image.data;
  if (bytes == null || bytes.isEmpty) return;
  final valid = switch (mimeType) {
    'image/png' => hasPngSignature(bytes),
    'image/jpeg' => hasJpegSignature(bytes),
    _ => true,
  };
  if (valid) return;
  sink.error(
    'gltf.invalidImageData',
    'Image data must match its declared MIME type.',
    jsonPath: '\$.images[${image.index}]',
  );
}

@internal
bool hasPngSignature(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length < signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  return true;
}

@internal
bool hasJpegSignature(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xff &&
    bytes[1] == 0xd8 &&
    bytes[2] == 0xff;
