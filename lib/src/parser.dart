part of '../flvtterm.dart';

final class _Parser {
  static VrmParseResult<GltfAsset> parseGltf(
    Uint8List bytes,
    VrmValidationMode mode, {
    GltfUriResolver? uriResolver,
  }) {
    final sink = _DiagnosticSink();
    final gltf = _looksLikeGlb(bytes)
        ? _parseGlb(bytes, sink, uriResolver: uriResolver)
        : _parseGltfJsonBytes(bytes, sink, uriResolver: uriResolver);
    if (gltf != null) {
      _validateRequiredExtensions(gltf, sink, _supportedGltfExtensions);
    }
    final result = VrmValidationResult(sink.diagnostics);
    return VrmParseResult(
      asset: mode == VrmValidationMode.strict && result.hasErrors ? null : gltf,
      validation: result,
    );
  }

  static VrmParseResult<VrmModel> parseVrmGlb(
    Uint8List bytes,
    VrmValidationMode mode, {
    GltfUriResolver? uriResolver,
  }) {
    final sink = _DiagnosticSink();
    final gltf = _parseGlb(bytes, sink, uriResolver: uriResolver);
    if (gltf == null) {
      return VrmParseResult(
        asset: null,
        validation: VrmValidationResult(sink.diagnostics),
      );
    }

    _validateRequiredExtensions(gltf, sink, _supportedVrmExtensions);
    final rootExtensions = _object(gltf.json['extensions']);
    final hasVrm1 = rootExtensions.containsKey('VRMC_vrm');
    final hasVrm0 = rootExtensions.containsKey('VRM');
    if (hasVrm1 && hasVrm0) {
      sink.error(
        'vrm.ambiguousVersionExtensions',
        'A model must not declare both VRMC_vrm and legacy VRM root extensions; VRMC_vrm takes precedence in permissive mode.',
        jsonPath: r'$.extensions',
      );
    }

    VrmExtension? vrm;
    Vrm0Extension? vrm0;
    VrmSpringBone? springBone;
    if (hasVrm1 || !hasVrm0) {
      vrm = _parseVrmExtension(gltf, sink);
      springBone = _parseSpringBone(gltf.json, sink);
      if (springBone != null) {
        _validateSpringBone(gltf, springBone, sink);
      }
    } else {
      vrm0 = _parseVrm0Extension(gltf, sink, mode);
      if (vrm0 != null) {
        vrm = _normalizeVrm0Extension(gltf, vrm0, sink);
        springBone = _normalizeVrm0SpringBone(gltf, vrm0, sink);
      }
    }
    VrmModel? model;
    if (vrm != null) {
      model = VrmModel._(
        gltf: gltf,
        vrm: vrm,
        vrm0: vrm0,
        springBone: springBone,
        validation: VrmValidationResult(sink.diagnostics),
      );
    }

    final result = VrmValidationResult(sink.diagnostics);
    return VrmParseResult(
      asset: mode == VrmValidationMode.strict && result.hasErrors
          ? null
          : model,
      validation: result,
    );
  }

  static VrmParseResult<VrmAnimationAsset> parseVrma(
    Uint8List bytes,
    VrmValidationMode mode, {
    GltfUriResolver? uriResolver,
  }) {
    final sink = _DiagnosticSink();
    final gltf = _looksLikeGlb(bytes)
        ? _parseGlb(bytes, sink, uriResolver: uriResolver)
        : _parseGltfJsonBytes(bytes, sink, uriResolver: uriResolver);
    if (gltf == null) {
      return VrmParseResult(
        asset: null,
        validation: VrmValidationResult(sink.diagnostics),
      );
    }

    _validateRequiredExtensions(gltf, sink, _supportedVrmaExtensions);
    final animation = _parseVrmaExtension(gltf, sink);
    VrmAnimationAsset? asset;
    if (animation != null) {
      _validateVrmaAnimationRules(gltf, animation, sink);
      asset = VrmAnimationAsset._(
        gltf: gltf,
        animation: animation,
        validation: VrmValidationResult(sink.diagnostics),
      );
    }

    final result = VrmValidationResult(sink.diagnostics);
    return VrmParseResult(
      asset: mode == VrmValidationMode.strict && result.hasErrors
          ? null
          : asset,
      validation: result,
    );
  }
}

final class _DiagnosticSink {
  final diagnostics = <VrmDiagnostic>[];

  void error(
    String code,
    String message, {
    String? jsonPath,
    int? gltfNodeIndex,
    int? gltfMaterialIndex,
  }) {
    diagnostics.add(
      VrmDiagnostic(
        severity: const VrmError(),
        code: code,
        message: message,
        jsonPath: jsonPath,
        gltfNodeIndex: gltfNodeIndex,
        gltfMaterialIndex: gltfMaterialIndex,
      ),
    );
  }

  void warning(
    String code,
    String message, {
    String? jsonPath,
    int? gltfNodeIndex,
    int? gltfMaterialIndex,
  }) {
    diagnostics.add(
      VrmDiagnostic(
        severity: const VrmWarning(),
        code: code,
        message: message,
        jsonPath: jsonPath,
        gltfNodeIndex: gltfNodeIndex,
        gltfMaterialIndex: gltfMaterialIndex,
      ),
    );
  }
}

const _glbMagic = 0x46546c67;
const _glbVersion = 2;
const _jsonChunkType = 0x4e4f534a;
const _binChunkType = 0x004e4942;

const _supportedGltfExtensions = {
  'VRMC_materials_mtoon',
  'VRMC_node_constraint',
  'KHR_materials_unlit',
  'KHR_texture_transform',
  'KHR_materials_emissive_strength',
};

const _supportedVrmExtensions = {
  'VRM',
  'VRMC_vrm',
  'VRMC_materials_mtoon',
  'VRMC_springBone',
  'VRMC_node_constraint',
  'KHR_materials_unlit',
  'KHR_texture_transform',
  'KHR_materials_emissive_strength',
};

const _supportedVrmaExtensions = {
  'VRMC_vrm_animation',
  'KHR_materials_unlit',
  'KHR_texture_transform',
  'KHR_materials_emissive_strength',
};

bool _looksLikeGlb(Uint8List bytes) {
  if (bytes.length < 4) return false;
  return ByteData.sublistView(bytes).getUint32(0, Endian.little) == _glbMagic;
}

GltfAsset? _parseGlb(
  Uint8List bytes,
  _DiagnosticSink sink, {
  GltfUriResolver? uriResolver,
}) {
  if (bytes.length < 12) {
    sink.error('glb.tooShort', 'GLB header must be at least 12 bytes.');
    return null;
  }

  final data = ByteData.sublistView(bytes);
  final magic = data.getUint32(0, Endian.little);
  final version = data.getUint32(4, Endian.little);
  final declaredLength = data.getUint32(8, Endian.little);

  if (magic != _glbMagic) {
    sink.error('glb.badMagic', 'GLB magic must be "glTF".');
    return null;
  }
  if (version != _glbVersion) {
    sink.error('glb.badVersion', 'Only GLB version 2 is supported.');
  }
  if (declaredLength != bytes.length) {
    sink.error(
      'glb.badLength',
      'GLB declared length $declaredLength does not match ${bytes.length}.',
    );
    if (declaredLength > bytes.length) return null;
  }

  final parseLength = math.min(declaredLength, bytes.length);
  var offset = 12;
  Uint8List? jsonChunk;
  Uint8List? binChunk;
  var chunkIndex = 0;
  while (offset < parseLength) {
    if (offset + 8 > parseLength) {
      sink.error('glb.truncatedChunkHeader', 'GLB chunk header is truncated.');
      return null;
    }
    final chunkLength = data.getUint32(offset, Endian.little);
    final chunkType = data.getUint32(offset + 4, Endian.little);
    offset += 8;
    if (chunkLength % 4 != 0) {
      sink.error(
        'glb.invalidChunkLength',
        'GLB chunk $chunkIndex length must be aligned to 4 bytes.',
      );
    }
    if (offset + chunkLength > parseLength) {
      sink.error('glb.truncatedChunk', 'GLB chunk $chunkIndex is truncated.');
      return null;
    }
    final chunk = Uint8List.sublistView(bytes, offset, offset + chunkLength);
    if (chunkIndex == 0 && chunkType != _jsonChunkType) {
      sink.error('glb.firstChunkNotJson', 'First GLB chunk must be JSON.');
      return null;
    }
    if (chunkType == _jsonChunkType) {
      if (jsonChunk == null) {
        _validateJsonChunkPadding(chunk, sink);
        jsonChunk = chunk;
      } else {
        sink.error(
          'glb.duplicateJsonChunk',
          'GLB must contain exactly one JSON chunk.',
        );
      }
    } else if (chunkType == _binChunkType) {
      if (chunkIndex != 1) {
        sink.error(
          'glb.binChunkNotSecond',
          'GLB BIN chunk must immediately follow the JSON chunk.',
        );
      }
      if (binChunk == null) {
        binChunk = chunk;
      } else {
        sink.error(
          'glb.duplicateBinChunk',
          'GLB must contain at most one BIN chunk.',
        );
      }
    } else {
      sink.warning('glb.unknownChunk', 'Unknown GLB chunk type $chunkType.');
    }
    offset += chunkLength;
    chunkIndex++;
  }

  if (jsonChunk == null) {
    sink.error('glb.missingJson', 'GLB does not contain a JSON chunk.');
    return null;
  }

  try {
    return _parseGltfJsonString(
      utf8.decode(jsonChunk),
      binChunk,
      sink,
      uriResolver: uriResolver,
    );
  } on FormatException catch (error) {
    sink.error('gltf.badUtf8', 'Could not decode glTF JSON: ${error.message}');
    return null;
  }
}

void _validateJsonChunkPadding(Uint8List chunk, _DiagnosticSink sink) {
  for (var i = chunk.length - 1; i >= 0; i--) {
    final byte = chunk[i];
    if (byte == 0x20) continue;
    if (byte < 0x20) {
      sink.error(
        'glb.invalidJsonChunkPadding',
        'GLB JSON chunk padding bytes must be spaces.',
      );
    }
    return;
  }
}

GltfAsset? _parseGltfJsonBytes(
  Uint8List bytes,
  _DiagnosticSink sink, {
  GltfUriResolver? uriResolver,
}) {
  try {
    return _parseGltfJsonString(
      utf8.decode(bytes),
      null,
      sink,
      uriResolver: uriResolver,
    );
  } on FormatException catch (error) {
    sink.error('gltf.badUtf8', 'Could not decode glTF JSON: ${error.message}');
    return null;
  }
}

GltfAsset? _parseGltfJsonString(
  String source,
  Uint8List? binaryChunk,
  _DiagnosticSink sink, {
  GltfUriResolver? uriResolver,
}) {
  Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    sink.error('gltf.badJson', 'Could not parse glTF JSON: ${error.message}');
    return null;
  }
  if (decoded is! Map) {
    sink.error('gltf.rootNotObject', 'glTF JSON root must be an object.');
    return null;
  }
  final json = decoded.cast<String, Object?>();
  final assetObject = _validateAssetObject(json, sink);
  if (assetObject != null) {
    final versionValue = assetObject['version'];
    final version = _string(versionValue);
    final validVersion = version != null && _versionParts(version) != null;
    if (!validVersion) {
      sink.error(
        'gltf.invalidAssetVersion',
        'glTF asset.version must be a version string.',
        jsonPath: r'$.asset.version',
      );
    } else if (version != '2.0') {
      sink.error(
        'gltf.unsupportedVersion',
        'glTF asset.version must be "2.0".',
        jsonPath: r'$.asset.version',
      );
    }
    final minVersion = assetObject['minVersion'];
    if (minVersion != null &&
        (minVersion is! String ||
            _versionParts(minVersion) == null ||
            (validVersion &&
                !_versionIsLessThanOrEqual(minVersion, version)))) {
      sink.error(
        'gltf.invalidAssetMinVersion',
        'glTF asset.minVersion must be a version string not greater than asset.version.',
        jsonPath: r'$.asset.minVersion',
      );
    }
    for (final MapEntry(key: name, value: code) in const {
      'copyright': 'gltf.invalidAssetCopyright',
      'generator': 'gltf.invalidAssetGenerator',
    }.entries) {
      if (assetObject.containsKey(name) && assetObject[name] is! String) {
        sink.error(
          code,
          'glTF asset.$name must be a string.',
          jsonPath: r'$.asset.' + name,
        );
      }
    }
  }
  _validateExtensionsObjects(json, sink, r'$');
  _validateRootArrays(json, sink);
  final extensionsUsed = _parseRootStringList(
    json,
    'extensionsUsed',
    'gltf.invalidExtensionsUsed',
    sink,
  );
  final extensionsRequired = _parseRootStringList(
    json,
    'extensionsRequired',
    'gltf.invalidExtensionsRequired',
    sink,
  );

  final uriResolverFailures = <String, String>{};
  final buffers = _parseBuffers(
    json['buffers'],
    sink,
    binaryChunk,
    uriResolver,
    uriResolverFailures,
  );
  final bufferViews = _parseBufferViews(json['bufferViews']);
  final gltf = GltfAsset._(
    json: json,
    binaryChunk: binaryChunk,
    extensions: _object(json['extensions']),
    extras: json['extras'],
    hasUriResolver: uriResolver != null,
    uriResolverFailures: uriResolverFailures,
    extensionsUsed: extensionsUsed,
    extensionsRequired: extensionsRequired,
    buffers: buffers,
    bufferViews: bufferViews,
    cameras: _parseCameras(json['cameras']),
    scene: _int(json['scene']),
    scenes: _parseScenes(json['scenes'], sink),
    nodes: _parseNodes(json['nodes'], sink),
    meshes: _parseMeshes(json['meshes']),
    materials: _parseMaterials(json['materials']),
    skins: _parseSkins(json['skins'], sink),
    accessors: _parseAccessors(json['accessors']),
    textures: _parseTextures(json['textures']),
    images: _parseImages(
      json['images'],
      sink,
      buffers,
      bufferViews,
      uriResolver,
      uriResolverFailures,
    ),
    samplers: _parseSamplers(json['samplers']),
    animations: _parseAnimations(json['animations'], sink),
  );
  _validateGltfReferences(gltf, sink);
  _validateMToonMaterials(gltf, sink);
  _validateNodeConstraints(gltf, sink);
  return gltf;
}

Map<String, Object?>? _validateAssetObject(
  Map<String, Object?> json,
  _DiagnosticSink sink,
) {
  if (!json.containsKey('asset')) {
    sink.error(
      'gltf.missingAsset',
      'glTF asset metadata is required.',
      jsonPath: r'$.asset',
    );
    return null;
  }
  final value = json['asset'];
  if (value is Map) return value.cast<String, Object?>();
  sink.error(
    'gltf.invalidAssetObject',
    'glTF asset metadata must be a JSON object.',
    jsonPath: r'$.asset',
  );
  return null;
}

bool _versionIsLessThanOrEqual(String value, String limit) {
  final version = _versionParts(value);
  final max = _versionParts(limit);
  if (version == null || max == null) return false;
  final length = math.max(version.length, max.length);
  for (var i = 0; i < length; i++) {
    final left = i < version.length ? version[i] : 0;
    final right = i < max.length ? max[i] : 0;
    if (left != right) return left < right;
  }
  return true;
}

List<int>? _versionParts(String value) {
  final parts = value.split('.');
  if (parts.length != 2) return null;
  final result = <int>[];
  for (final part in parts) {
    if (part.isEmpty) return null;
    final number = int.tryParse(part);
    if (number == null || number < 0) return null;
    result.add(number);
  }
  return result;
}

void _validateExtensionsObjects(
  Object? value,
  _DiagnosticSink sink,
  String path,
) {
  if (value is Map) {
    final object = value.cast<String, Object?>();
    if (object.containsKey('extensions') && object['extensions'] is! Map) {
      sink.error(
        'gltf.invalidExtensionsObject',
        'extensions must be a JSON object.',
        jsonPath: '$path.extensions',
      );
    }
    for (final entry in object.entries) {
      _validateExtensionsObjects(entry.value, sink, '$path.${entry.key}');
    }
  } else if (value is List) {
    for (var i = 0; i < value.length; i++) {
      _validateExtensionsObjects(value[i], sink, '$path[$i]');
    }
  }
}

void _validateRootArrays(Map<String, Object?> json, _DiagnosticSink sink) {
  for (final key in const [
    'accessors',
    'animations',
    'buffers',
    'bufferViews',
    'cameras',
    'images',
    'materials',
    'meshes',
    'nodes',
    'samplers',
    'scenes',
    'skins',
    'textures',
  ]) {
    if (!json.containsKey(key)) continue;
    final value = json[key];
    if (value is! List) {
      sink.error(
        'gltf.invalidRootArray',
        '$key must be an array.',
        jsonPath: '\$.$key',
      );
    } else if (value.isEmpty) {
      sink.error(
        'gltf.emptyRootArray',
        '$key must contain at least one item.',
        jsonPath: '\$.$key',
      );
    } else {
      for (var i = 0; i < value.length; i++) {
        final item = value[i];
        if (item is Map) {
          if (item.containsKey('name') && item['name'] is! String) {
            sink.error(
              'gltf.invalidName',
              '$key name must be a string.',
              jsonPath: '\$.$key[$i].name',
            );
          }
          continue;
        }
        sink.error(
          'gltf.invalidRootArrayItem',
          '$key entries must be JSON objects.',
          jsonPath: '\$.$key[$i]',
        );
      }
    }
  }
}
