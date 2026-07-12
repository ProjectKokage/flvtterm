// Flutter Scene 0.17.0 deliberately keeps reusable GPU buffer types internal.
// This package is exact-version pinned while this compatibility seam exists.
// ignore_for_file: implementation_imports, public_member_api_docs

import 'dart:typed_data';

import 'package:flutter_scene/scene.dart' as scene;
import 'package:flutter_scene/src/gpu/gpu.dart' as gpu;

import 'morph_target_blender.dart';

final class FlutterSceneMorphTargetPrimitive {
  FlutterSceneMorphTargetPrimitive._({
    required this.blender,
    required scene.Geometry geometry,
    required gpu.DeviceBuffer vertexBuffer,
  }) : _geometry = geometry,
       _vertexBuffer = vertexBuffer;

  /// Allocates and fills the reusable buffer without mutating [geometry].
  ///
  /// Call [activate] only after every primitive in the mesh has prepared
  /// successfully so an allocation failure cannot leave a partial binding.
  factory FlutterSceneMorphTargetPrimitive.prepare(
    scene.Geometry geometry,
    MorphTargetPrimitiveData data,
  ) {
    final geometryMatches = data.isSkinned
        ? geometry is scene.SkinnedGeometry
        : geometry is scene.UnskinnedGeometry &&
              geometry is! scene.SkinnedGeometry;
    if (!geometryMatches) {
      throw StateError(
        'Flutter Scene geometry layout does not match the parsed glTF '
        '${data.isSkinned ? 'skinned' : 'unskinned'} vertex layout.',
      );
    }

    final blender = MorphTargetBlender(data);
    final bytes = ByteData.sublistView(blender.workingVertices);
    final buffer = gpu.gpuContext.createDeviceBuffer(
      gpu.StorageMode.hostVisible,
      bytes.lengthInBytes,
    );
    if (!buffer.overwrite(bytes)) {
      throw StateError('Flutter Scene rejected the initial morph vertex data.');
    }
    buffer.flush(offsetInBytes: 0, lengthInBytes: bytes.lengthInBytes);
    return FlutterSceneMorphTargetPrimitive._(
      blender: blender,
      geometry: geometry,
      vertexBuffer: buffer,
    );
  }

  final MorphTargetBlender blender;
  final scene.Geometry _geometry;
  final gpu.DeviceBuffer _vertexBuffer;
  bool _active = false;
  int uploadCount = 0;

  /// Rebinds the already prepared buffer to the imported geometry.
  void activate() {
    if (_active) return;
    final lengthInBytes = blender.workingVertices.lengthInBytes;
    _geometry
      ..setVertices(
        gpu.BufferView(
          _vertexBuffer,
          offsetInBytes: 0,
          lengthInBytes: lengthInBytes,
        ),
        blender.data.vertexCount,
      )
      // Runtime GLB skinned geometry is intentionally unbounded. Extending
      // that conservative behavior to every morph primitive prevents stale
      // neutral bounds from culling an active target.
      ..setLocalBounds(null, null);
    _active = true;
  }

  bool setWeight(int morphIndex, double weight) =>
      blender.setWeight(morphIndex, weight);

  bool commit() {
    if (!_active) return false;
    if (!blender.commit()) return false;
    final bytes = ByteData.sublistView(blender.workingVertices);
    if (!_vertexBuffer.overwrite(bytes)) {
      throw StateError('Flutter Scene rejected updated morph vertex data.');
    }
    _vertexBuffer.flush(offsetInBytes: 0, lengthInBytes: bytes.lengthInBytes);
    uploadCount++;
    return true;
  }
}
