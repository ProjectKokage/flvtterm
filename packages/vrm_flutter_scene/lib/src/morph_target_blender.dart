// Package-internal morph composition. The public adapter API remains in
// flutter_scene_vrm_binding.dart.
// ignore_for_file: public_member_api_docs

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flvtterm/flvtterm.dart';

final class MorphTargetPrimitiveBuildResult {
  const MorphTargetPrimitiveBuildResult._({this.data, this.failure});

  factory MorphTargetPrimitiveBuildResult.success(
    MorphTargetPrimitiveData data,
  ) => MorphTargetPrimitiveBuildResult._(data: data);

  factory MorphTargetPrimitiveBuildResult.unsupported(String failure) =>
      MorphTargetPrimitiveBuildResult._(failure: failure);

  final MorphTargetPrimitiveData? data;
  final String? failure;
}

final class MorphTargetPrimitiveData {
  MorphTargetPrimitiveData({
    required this.vertexCount,
    required this.strideFloats,
    required this.isSkinned,
    required Float32List baseVertices,
    required List<Float32List?> positionDeltas,
    required List<Float32List?> normalDeltas,
  }) : baseVertices = Float32List.fromList(baseVertices),
       positionDeltas = List.unmodifiable(positionDeltas),
       normalDeltas = List.unmodifiable(normalDeltas),
       normalDeltaHasEffect = List.unmodifiable([
         for (final delta in normalDeltas)
           delta != null && delta.any((value) => value != 0),
       ]);

  final int vertexCount;
  final int strideFloats;
  final bool isSkinned;
  final Float32List baseVertices;
  final List<Float32List?> positionDeltas;
  final List<Float32List?> normalDeltas;
  final List<bool> normalDeltaHasEffect;

  int get targetCount => positionDeltas.length;
}

final class MorphTargetDataFactory {
  MorphTargetDataFactory(this.gltf);

  final GltfAsset gltf;
  final Map<(int, bool, bool), Float32List?> _accessorCache = {};

  MorphTargetPrimitiveBuildResult build(GltfMeshPrimitive primitive) {
    if (primitive.mode != 4) {
      return MorphTargetPrimitiveBuildResult.unsupported(
        'Only TRIANGLES morph primitives are supported.',
      );
    }
    final positionIndex = primitive.attributes['POSITION'];
    final normalIndex = primitive.attributes['NORMAL'];
    if (positionIndex == null || normalIndex == null) {
      return MorphTargetPrimitiveBuildResult.unsupported(
        'Morph primitives require authored POSITION and NORMAL attributes; '
        'Flutter Scene deindexes generated-normal geometry internally.',
      );
    }
    final positionAccessor = gltf.accessors.elementAtOrNull(positionIndex);
    final vertexCount = positionAccessor?.count;
    if (vertexCount == null || vertexCount <= 0) {
      return MorphTargetPrimitiveBuildResult.unsupported(
        'The POSITION accessor has no usable vertex count.',
      );
    }
    final positions = _readExact(
      positionIndex,
      vertexCount * 3,
      requireFloat: true,
    );
    final normals = _readExact(
      normalIndex,
      vertexCount * 3,
      requireFloat: true,
    );
    if (positions == null || normals == null) {
      return MorphTargetPrimitiveBuildResult.unsupported(
        'POSITION and NORMAL must be finite FLOAT VEC3 accessors with '
        'matching vertex counts.',
      );
    }

    final jointsIndex = primitive.attributes['JOINTS_0'];
    final weightsIndex = primitive.attributes['WEIGHTS_0'];
    if ((jointsIndex == null) != (weightsIndex == null)) {
      return MorphTargetPrimitiveBuildResult.unsupported(
        'JOINTS_0 and WEIGHTS_0 must either both be present or both be absent.',
      );
    }
    final isSkinned = jointsIndex != null;
    final joints = jointsIndex == null
        ? null
        : _readExact(jointsIndex, vertexCount * 4, applyNormalization: false);
    final skinWeights = weightsIndex == null
        ? null
        : _readExact(weightsIndex, vertexCount * 4);
    if (isSkinned && (joints == null || skinWeights == null)) {
      return MorphTargetPrimitiveBuildResult.unsupported(
        'Skin attributes must be finite VEC4 accessors matching POSITION.',
      );
    }

    final texCoords = switch (primitive.attributes['TEXCOORD_0']) {
      final index? => _readExact(index, vertexCount * 2),
      null => Float32List(vertexCount * 2),
    };
    if (texCoords == null) {
      return MorphTargetPrimitiveBuildResult.unsupported(
        'TEXCOORD_0 must be a finite VEC2 accessor matching POSITION.',
      );
    }

    final colors = _readColors(primitive.attributes['COLOR_0'], vertexCount);
    if (colors == null) {
      return MorphTargetPrimitiveBuildResult.unsupported(
        'COLOR_0 must be a finite VEC3 or VEC4 accessor matching POSITION.',
      );
    }

    final positionDeltas = <Float32List?>[];
    final normalDeltas = <Float32List?>[];
    for (final target in primitive.targets) {
      final unsupportedSemantics = target.keys.where(
        (semantic) => semantic != 'POSITION' && semantic != 'NORMAL',
      );
      if (unsupportedSemantics.isNotEmpty) {
        return MorphTargetPrimitiveBuildResult.unsupported(
          'Morph semantics ${unsupportedSemantics.join(', ')} are not '
          'represented by Flutter Scene 0.17.0 vertex layouts.',
        );
      }
      final positionDelta = switch (target['POSITION']) {
        final index? => _readExact(index, vertexCount * 3, requireFloat: true),
        null => null,
      };
      final normalDelta = switch (target['NORMAL']) {
        final index? => _readExact(index, vertexCount * 3, requireFloat: true),
        null => null,
      };
      if ((target.containsKey('POSITION') && positionDelta == null) ||
          (target.containsKey('NORMAL') && normalDelta == null)) {
        return MorphTargetPrimitiveBuildResult.unsupported(
          'Morph POSITION and NORMAL deltas must be finite FLOAT VEC3 '
          'accessors matching the base vertex count.',
        );
      }
      positionDeltas.add(positionDelta);
      normalDeltas.add(normalDelta);
    }

    final strideFloats = isSkinned ? 20 : 12;
    final base = Float32List(vertexCount * strideFloats);
    for (var vertex = 0; vertex < vertexCount; vertex++) {
      final output = vertex * strideFloats;
      final vec3 = vertex * 3;
      final vec2 = vertex * 2;
      final vec4 = vertex * 4;
      base[output] = positions[vec3];
      base[output + 1] = positions[vec3 + 1];
      base[output + 2] = positions[vec3 + 2];
      base[output + 3] = normals[vec3];
      base[output + 4] = normals[vec3 + 1];
      base[output + 5] = normals[vec3 + 2];
      base[output + 6] = texCoords[vec2];
      base[output + 7] = texCoords[vec2 + 1];
      base[output + 8] = colors[vec4];
      base[output + 9] = colors[vec4 + 1];
      base[output + 10] = colors[vec4 + 2];
      base[output + 11] = colors[vec4 + 3];
      if (isSkinned) {
        base[output + 12] = joints![vec4];
        base[output + 13] = joints[vec4 + 1];
        base[output + 14] = joints[vec4 + 2];
        base[output + 15] = joints[vec4 + 3];
        base[output + 16] = skinWeights![vec4];
        base[output + 17] = skinWeights[vec4 + 1];
        base[output + 18] = skinWeights[vec4 + 2];
        base[output + 19] = skinWeights[vec4 + 3];
      }
    }
    return MorphTargetPrimitiveBuildResult.success(
      MorphTargetPrimitiveData(
        vertexCount: vertexCount,
        strideFloats: strideFloats,
        isSkinned: isSkinned,
        baseVertices: base,
        positionDeltas: positionDeltas,
        normalDeltas: normalDeltas,
      ),
    );
  }

  Float32List? _readColors(int? accessorIndex, int vertexCount) {
    if (accessorIndex == null) {
      final colors = Float32List(vertexCount * 4);
      for (var vertex = 0; vertex < vertexCount; vertex++) {
        colors[vertex * 4] = 1;
        colors[vertex * 4 + 1] = 1;
        colors[vertex * 4 + 2] = 1;
        colors[vertex * 4 + 3] = 1;
      }
      return colors;
    }
    final accessor = gltf.accessors.elementAtOrNull(accessorIndex);
    final components = accessor?.componentCount;
    if (components != 3 && components != 4) return null;
    final values = _readExact(accessorIndex, vertexCount * components!);
    if (values == null || components == 4) return values;
    final colors = Float32List(vertexCount * 4);
    for (var vertex = 0; vertex < vertexCount; vertex++) {
      colors[vertex * 4] = values[vertex * 3];
      colors[vertex * 4 + 1] = values[vertex * 3 + 1];
      colors[vertex * 4 + 2] = values[vertex * 3 + 2];
      colors[vertex * 4 + 3] = 1;
    }
    return colors;
  }

  Float32List? _readExact(
    int accessorIndex,
    int expectedLength, {
    bool requireFloat = false,
    bool applyNormalization = true,
  }) {
    final cacheKey = (accessorIndex, requireFloat, applyNormalization);
    if (_accessorCache.containsKey(cacheKey)) {
      final cached = _accessorCache[cacheKey];
      return cached?.length == expectedLength ? cached : null;
    }
    final values = gltf.readAccessorNumbers(
      accessorIndex,
      requireFloat: requireFloat,
      applyNormalization: applyNormalization,
    );
    final result = values == null || values.any((value) => !value.isFinite)
        ? null
        : Float32List.fromList(values);
    _accessorCache[cacheKey] = result;
    return result?.length == expectedLength ? result : null;
  }
}

final class MorphTargetBlender {
  MorphTargetBlender(this.data)
    : requestedWeights = Float64List(data.targetCount),
      _appliedWeights = Float64List(data.targetCount),
      workingVertices = Float32List.fromList(data.baseVertices);

  final MorphTargetPrimitiveData data;
  final Float64List requestedWeights;
  final Float64List _appliedWeights;
  final Float32List workingVertices;
  int revision = 0;

  bool setWeight(int morphIndex, double weight) {
    if (morphIndex < 0 || morphIndex >= requestedWeights.length) return false;
    if (!weight.isFinite) return false;
    requestedWeights[morphIndex] = weight;
    return true;
  }

  bool commit() {
    var changed = false;
    for (var index = 0; index < requestedWeights.length; index++) {
      if (requestedWeights[index] != _appliedWeights[index]) {
        changed = true;
        break;
      }
    }
    if (!changed) return false;

    workingVertices.setAll(0, data.baseVertices);
    var normalsChanged = false;
    for (var target = 0; target < requestedWeights.length; target++) {
      final weight = requestedWeights[target];
      if (weight == 0) continue;
      final positionDelta = data.positionDeltas[target];
      final normalDelta = data.normalDeltas[target];
      if (positionDelta != null) {
        _addDelta(positionDelta, weight, attributeOffset: 0);
      }
      if (normalDelta != null) {
        _addDelta(normalDelta, weight, attributeOffset: 3);
        normalsChanged = normalsChanged || data.normalDeltaHasEffect[target];
      }
    }
    if (normalsChanged) _renormalizeNormals();
    _appliedWeights.setAll(0, requestedWeights);
    revision++;
    return true;
  }

  void _addDelta(
    Float32List delta,
    double weight, {
    required int attributeOffset,
  }) {
    for (var vertex = 0; vertex < data.vertexCount; vertex++) {
      final source = vertex * 3;
      final output = vertex * data.strideFloats + attributeOffset;
      workingVertices[output] += delta[source] * weight;
      workingVertices[output + 1] += delta[source + 1] * weight;
      workingVertices[output + 2] += delta[source + 2] * weight;
    }
  }

  void _renormalizeNormals() {
    for (var vertex = 0; vertex < data.vertexCount; vertex++) {
      final offset = vertex * data.strideFloats + 3;
      final x = workingVertices[offset];
      final y = workingVertices[offset + 1];
      final z = workingVertices[offset + 2];
      final length = math.sqrt(x * x + y * y + z * z);
      if (length.isFinite && length > 1e-12) {
        workingVertices[offset] = x / length;
        workingVertices[offset + 1] = y / length;
        workingVertices[offset + 2] = z / length;
      } else {
        workingVertices[offset] = data.baseVertices[offset];
        workingVertices[offset + 1] = data.baseVertices[offset + 1];
        workingVertices[offset + 2] = data.baseVertices[offset + 2];
      }
    }
  }
}
