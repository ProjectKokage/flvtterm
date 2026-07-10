part of '../flvtterm.dart';

List<double>? _readAccessorNumbers(
  GltfAsset gltf,
  int accessorIndex, {
  bool requireFloat = false,
  bool applyNormalization = true,
}) {
  final accessor = gltf.accessors.elementAtOrNull(accessorIndex);
  if (accessor == null) return null;
  if (requireFloat && (accessor.componentType != 5126 || accessor.normalized)) {
    return null;
  }
  final componentSize = _componentByteSize(accessor.componentType);
  final componentCount = accessor.componentCount;
  final count = accessor.count;
  if (componentSize == null ||
      componentCount == null ||
      count == null ||
      count <= 0) {
    return null;
  }

  final values = accessor.bufferView == null
      ? List<double>.filled(count * componentCount, 0.0)
      : _readAccessorBaseValues(
          gltf,
          accessor,
          componentSize,
          componentCount,
          count,
          applyNormalization: applyNormalization,
        );
  if (values == null) return null;

  final sparse = accessor.sparse;
  if (sparse != null && sparse.count != null && sparse.count! > 0) {
    final sparseCount = sparse.count!;
    if (sparseCount > count) return null;
    final indices = _readSparseIndices(gltf, sparse, sparseCount);
    final replacements = _readSparseValues(
      gltf,
      accessor,
      sparse,
      sparseCount,
      componentSize,
      componentCount,
      applyNormalization: applyNormalization,
    );
    if (indices == null || replacements == null) return null;
    for (var i = 0; i < sparseCount; i++) {
      final target = indices[i];
      if (target < 0 || target >= count) return null;
      for (var component = 0; component < componentCount; component++) {
        values[target * componentCount + component] =
            replacements[i * componentCount + component];
      }
    }
  }
  return values;
}

List<double>? _readAccessorBaseValues(
  GltfAsset gltf,
  GltfAccessor accessor,
  int componentSize,
  int componentCount,
  int count, {
  required bool applyNormalization,
}) {
  final view = gltf.bufferViews.elementAtOrNull(accessor.bufferView!);
  final bytes = _bufferBytes(gltf, view?.buffer);
  if (view == null || bytes == null) return null;
  final byteLength = view.byteLength;
  if (byteLength == null) return null;
  final minimumStride = _accessorTightStride(
    accessor.type,
    componentSize,
    componentCount,
  );
  final stride = view.byteStride ?? minimumStride;
  final start = view.byteOffset + accessor.byteOffset;
  final end = view.byteOffset + byteLength;
  if (start < 0 || end > bytes.length || stride < minimumStride) {
    return null;
  }
  return _readNumberBlock(
    bytes,
    start: start,
    end: end,
    count: count,
    componentCount: componentCount,
    componentSize: componentSize,
    componentType: accessor.componentType,
    accessorType: accessor.type,
    stride: stride,
    normalized: applyNormalization && accessor.normalized,
  );
}

List<int>? _readSparseIndices(
  GltfAsset gltf,
  GltfAccessorSparse sparse,
  int count,
) {
  final componentSize = _componentByteSize(sparse.indicesComponentType);
  final view = gltf.bufferViews.elementAtOrNull(sparse.indicesBufferView ?? -1);
  final bytes = _bufferBytes(gltf, view?.buffer);
  if (componentSize == null || view == null || bytes == null) return null;
  final byteLength = view.byteLength;
  if (byteLength == null) return null;
  final start = view.byteOffset + sparse.indicesByteOffset;
  final end = view.byteOffset + byteLength;
  if (start < 0 || start + count * componentSize > end || end > bytes.length) {
    return null;
  }
  final data = ByteData.sublistView(bytes);
  return [
    for (var i = 0; i < count; i++)
      _readComponent(
            data,
            start + i * componentSize,
            sparse.indicesComponentType,
          )?.round() ??
          -1,
  ];
}

List<double>? _readSparseValues(
  GltfAsset gltf,
  GltfAccessor accessor,
  GltfAccessorSparse sparse,
  int count,
  int componentSize,
  int componentCount, {
  required bool applyNormalization,
}) {
  final view = gltf.bufferViews.elementAtOrNull(sparse.valuesBufferView ?? -1);
  final bytes = _bufferBytes(gltf, view?.buffer);
  if (view == null || bytes == null) return null;
  final byteLength = view.byteLength;
  if (byteLength == null) return null;
  final start = view.byteOffset + sparse.valuesByteOffset;
  final end = view.byteOffset + byteLength;
  return _readNumberBlock(
    bytes,
    start: start,
    end: end,
    count: count,
    componentCount: componentCount,
    componentSize: componentSize,
    componentType: accessor.componentType,
    accessorType: accessor.type,
    stride: _accessorTightStride(accessor.type, componentSize, componentCount),
    normalized: applyNormalization && accessor.normalized,
  );
}

List<double>? _readNumberBlock(
  Uint8List bytes, {
  required int start,
  required int end,
  required int count,
  required int componentCount,
  required int componentSize,
  required int? componentType,
  required String? accessorType,
  required int stride,
  required bool normalized,
}) {
  final minimumStride = _accessorTightStride(
    accessorType,
    componentSize,
    componentCount,
  );
  final elementByteLength = _accessorLastElementByteLength(
    accessorType,
    componentSize,
    componentCount,
  );
  if (start < 0 || end > bytes.length || stride < minimumStride) {
    return null;
  }
  final data = ByteData.sublistView(bytes);
  final values = <double>[];
  for (var element = 0; element < count; element++) {
    final elementOffset = start + element * stride;
    if (elementOffset + elementByteLength > end) return null;
    for (var component = 0; component < componentCount; component++) {
      final offset =
          elementOffset +
          _accessorComponentByteOffset(
            accessorType,
            component,
            componentSize,
            componentCount,
          );
      final value = _readComponent(data, offset, componentType);
      if (value == null) return null;
      values.add(
        normalized ? _normalizeComponent(value, componentType) : value,
      );
    }
  }
  return values;
}

int _accessorTightStride(
  String? accessorType,
  int componentSize,
  int componentCount,
) {
  final columns = _accessorMatrixColumnCount(accessorType);
  if (columns == null) return componentSize * componentCount;
  final rows = componentCount ~/ columns;
  return _align4(rows * componentSize) * columns;
}

int _accessorLastElementByteLength(
  String? accessorType,
  int componentSize,
  int componentCount,
) {
  final columns = _accessorMatrixColumnCount(accessorType);
  if (columns == null) return componentSize * componentCount;
  final rows = componentCount ~/ columns;
  return _align4(rows * componentSize) * (columns - 1) + rows * componentSize;
}

int _accessorComponentByteOffset(
  String? accessorType,
  int component,
  int componentSize,
  int componentCount,
) {
  final columns = _accessorMatrixColumnCount(accessorType);
  if (columns == null) return component * componentSize;
  final rows = componentCount ~/ columns;
  final column = component ~/ rows;
  final row = component % rows;
  return column * _align4(rows * componentSize) + row * componentSize;
}

int? _accessorMatrixColumnCount(String? accessorType) => switch (accessorType) {
  'MAT2' => 2,
  'MAT3' => 3,
  'MAT4' => 4,
  _ => null,
};

int _align4(int value) => (value + 3) & ~3;

Uint8List? _bufferBytes(GltfAsset gltf, int? bufferIndex) {
  if (bufferIndex == null) return null;
  return gltf.buffers.elementAtOrNull(bufferIndex)?._data;
}

int? _componentByteSize(int? componentType) {
  return switch (componentType) {
    5120 || 5121 => 1,
    5122 || 5123 => 2,
    5125 || 5126 => 4,
    _ => null,
  };
}

double? _readComponent(ByteData data, int offset, int? componentType) {
  return switch (componentType) {
    5120 => data.getInt8(offset).toDouble(),
    5121 => data.getUint8(offset).toDouble(),
    5122 => data.getInt16(offset, Endian.little).toDouble(),
    5123 => data.getUint16(offset, Endian.little).toDouble(),
    5125 => data.getUint32(offset, Endian.little).toDouble(),
    5126 => data.getFloat32(offset, Endian.little),
    _ => null,
  };
}

double _normalizeComponent(double value, int? componentType) {
  return switch (componentType) {
    5120 => math.max(-1, value / 127),
    5121 => value / 255,
    5122 => math.max(-1, value / 32767),
    5123 => value / 65535,
    5125 => value / 4294967295,
    _ => value,
  };
}
