import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_scene/scene.dart' as scene;
import 'package:flvtterm/flvtterm.dart';

import 'flutter_scene_skin_reduction.dart';

/// Imports a GLB through Flutter Scene while replaying resources already
/// resolved and validated by flvtterm core.
///
/// Returns the imported root with the skin reduction the import applied, if
/// any, so the binding packs its own vertex data the same way.
/// [jointPaletteCapacity] is the largest skin the renderer animates; null
/// leaves every skin as authored.
Future<({scene.Node root, FlutterSceneSkinReduction? skinReduction})>
importResolvedFlutterSceneGlb(
  Uint8List originalBytes,
  VrmModel model, {
  int? jointPaletteCapacity,
}) async {
  final resolved = FlutterSceneResolvedImport.fromGltf(
    model.gltf,
    jointPaletteCapacity: jointPaletteCapacity,
  );
  if (resolved == null) {
    return (
      root: await scene.Node.fromGlbBytes(originalBytes),
      skinReduction: null,
    );
  }
  return (
    root: await scene.Node.fromGltfBytes(
      resolved.gltfJson,
      resolveUri: resolved.resolveUri,
    ),
    skinReduction: resolved.skinReduction,
  );
}

/// Renderer input reconstructed from a parsed GLB, preserving core geometry.
///
/// Flutter Scene's GLB entry point cannot accept a URI resolver. When a GLB
/// references an external buffer or image, this value rewrites the parsed JSON
/// to use Flutter Scene's resolver-aware glTF entry point and serves the exact
/// bytes that flvtterm core already resolved. Optional Draco and meshopt hints
/// use core-validated ordinary geometry; required compression remains unsupported.
/// VRM-owned required names are normalized for the glTF-only renderer while
/// unrelated required extensions remain subject to its validation. A skin
/// larger than the renderer's joint palette is replaced per mesh node by the
/// joints that mesh weights ([FlutterSceneSkinReduction]).
final class FlutterSceneResolvedImport {
  FlutterSceneResolvedImport._(
    this.gltfJson,
    Map<String, Uint8List> resources,
    this.skinReduction,
  ) : _resources = Map.unmodifiable(resources);

  /// Returns `null` when the GLB needs no resource, extension or skin
  /// adaptation.
  ///
  /// [jointPaletteCapacity] is the largest skin the renderer animates. The
  /// renderer owns that bound, so the caller supplies it; null leaves every
  /// skin as authored.
  static FlutterSceneResolvedImport? fromGltf(
    GltfAsset gltf, {
    int? jointPaletteCapacity,
  }) {
    final hasExternalResource =
        gltf.buffers.any((buffer) => _isExternalUri(buffer.uri)) ||
        gltf.images.any((image) => _isExternalUri(image.uri));
    final hasVrmExtension = gltf.extensionsRequired.any(
      _flvttermOwnedExtensions.contains,
    );
    final hasCompression =
        gltf.extensionsUsed.any(_compressionExtensions.contains) ||
        gltf.extensionsRequired.any(_compressionExtensions.contains) ||
        gltf.buffers.any((b) => b.extensions.containsKey(_meshoptExtension)) ||
        gltf.bufferViews.any(
          (b) => b.extensions.containsKey(_meshoptExtension),
        ) ||
        gltf.meshes.any(
          (mesh) => mesh.primitives.any(
            (primitive) => primitive.extensions.containsKey(_dracoExtension),
          ),
        );
    final needsSkinReduction =
        jointPaletteCapacity != null &&
        gltfNeedsSkinReduction(gltf, jointPaletteCapacity);
    if (!hasExternalResource &&
        !hasVrmExtension &&
        !hasCompression &&
        !needsSkinReduction) {
      return null;
    }

    final decoded = jsonDecode(jsonEncode(gltf.json));
    if (decoded is! Map<String, Object?>) {
      throw StateError('Parsed glTF JSON root is not an object.');
    }

    // Core and this adapter consume these VRM extensions. Keep their data in
    // the model, but do not ask the glTF-only renderer to implement them too.
    // Unknown required extensions remain required and fail renderer validation.
    if (hasVrmExtension) {
      decoded['extensionsRequired'] = gltf.extensionsRequired
          .where((name) => !_flvttermOwnedExtensions.contains(name))
          .toList();
    }

    final resources = <String, Uint8List>{};
    final reservedUris = {for (final image in gltf.images) ?image.uri};

    for (final buffer in gltf.buffers) {
      final data = buffer.data;
      if (data == null) {
        throw StateError(
          'glTF buffer ${buffer.index} was not resolved for Flutter Scene.',
        );
      }
      final buffers = decoded['buffers'];
      if (buffers is! List ||
          buffer.index >= buffers.length ||
          buffers[buffer.index] is! Map) {
        throw StateError('Parsed glTF buffer metadata is unavailable.');
      }
      final syntheticUri = _uniqueBufferUri(reservedUris);
      (buffers[buffer.index] as Map)['uri'] = syntheticUri;
      reservedUris.add(syntheticUri);
      resources[syntheticUri] = data;
    }

    for (final image in gltf.images) {
      final uri = image.uri;
      if (!_isExternalUri(uri)) continue;
      final data = image.data;
      if (data == null) {
        throw StateError(
          'glTF image ${image.index} URI $uri was not resolved for Flutter '
          'Scene.',
        );
      }
      final existing = resources[uri];
      if (existing != null && !listEquals(existing, data)) {
        throw StateError(
          'glTF URI $uri resolved to conflicting byte payloads.',
        );
      }
      resources[uri!] = data;
    }

    if (hasCompression) {
      // Core supports ordinary fallback geometry, not compressed streams. Check
      // that fallback before removing optional decoder hints. Required codecs
      // retain core's unsupported-extension diagnostic even in permissive mode.
      final validation = GltfAsset.tryParse(
        bytes: Uint8List.fromList(utf8.encode(jsonEncode(decoded))),
        validation: VrmValidationMode.permissive,
        uriResolver: (uri) => resources[uri],
      ).validation;
      final requiredCompression = gltf.extensionsRequired.any(
        _compressionExtensions.contains,
      );
      if (requiredCompression ||
          validation.errors.any(
            (diagnostic) =>
                diagnostic.code != 'gltf.unsupportedRequiredExtension',
          )) {
        throw VrmInvalidAssetException(
          'Flutter Scene requires core-validated uncompressed fallback geometry.',
          validation,
        );
      }
      for (final key in ['buffers', 'bufferViews']) {
        for (final item in _jsonObjects(decoded[key])) {
          _jsonObject(item['extensions'])?.remove(_meshoptExtension);
        }
      }
      for (final mesh in _jsonObjects(decoded['meshes'])) {
        for (final primitive in _jsonObjects(mesh['primitives'])) {
          _jsonObject(primitive['extensions'])?.remove(_dracoExtension);
        }
      }
      decoded['extensionsUsed'] = gltf.extensionsUsed
          .where((name) => !_compressionExtensions.contains(name))
          .toList();
    }

    final skinReduction = needsSkinReduction
        ? reduceOversizedSkins(
            gltf,
            decoded,
            resources,
            reservedUris,
            jointPaletteCapacity: jointPaletteCapacity,
          )
        : null;

    return FlutterSceneResolvedImport._(
      Uint8List.fromList(utf8.encode(jsonEncode(decoded))),
      resources,
      skinReduction,
    );
  }

  /// Reconstructed JSON glTF bytes passed to Flutter Scene.
  final Uint8List gltfJson;

  /// Per-node joint subsets substituted for oversized skins, or null when
  /// every skin fits the renderer's palette as authored.
  final FlutterSceneSkinReduction? skinReduction;

  final Map<String, Uint8List> _resources;

  /// Resolves a renderer resource from the bytes accepted by core parsing.
  Future<Uint8List> resolveUri(String uri) async {
    final bytes = _resources[uri];
    if (bytes == null) {
      throw StateError('Flutter Scene requested unresolved glTF URI $uri.');
    }
    return bytes;
  }
}

const _dracoExtension = 'KHR_draco_mesh_compression';
const _meshoptExtension = 'EXT_meshopt_compression';
const _compressionExtensions = {_dracoExtension, _meshoptExtension};

const _flvttermOwnedExtensions = {
  'VRM',
  'VRMC_vrm',
  'VRMC_springBone',
  'VRMC_node_constraint',
  'VRMC_materials_mtoon',
};

bool _isExternalUri(String? uri) => uri != null && !uri.startsWith('data:');

String _uniqueBufferUri(Set<String> reserved) {
  var suffix = 0;
  while (true) {
    final candidate = '__flvtterm_glb_buffer_$suffix.bin';
    if (!reserved.contains(candidate)) return candidate;
    suffix++;
  }
}

/// The decoded JSON objects of an array, or none when the member is absent.
Iterable<Map<Object?, Object?>> _jsonObjects(Object? value) =>
    (value as List<Object?>? ?? const <Object?>[])
        .cast<Map<Object?, Object?>>();

Map<Object?, Object?>? _jsonObject(Object? value) =>
    value as Map<Object?, Object?>?;
