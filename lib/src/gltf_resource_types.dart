part of '../flvtterm.dart';

/// Parsed glTF buffer.
final class GltfBuffer {
  GltfBuffer._({
    required this.index,
    required this.name,
    required this.uri,
    required this.byteLength,
    required Uint8List? data,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : _data = data == null
           ? null
           : Uint8List.fromList(data).asUnmodifiableView(),
       extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// glTF buffer index.
  final int index;

  /// Optional buffer name.
  final String? name;

  /// Buffer URI, if any.
  final String? uri;

  /// Declared buffer byte length.
  final int? byteLength;

  final Uint8List? _data;

  /// Resolved buffer bytes for GLB BIN, data URI, or caller-resolved URI data.
  Uint8List? get data => _data;

  /// Buffer extensions, preserved.
  final Map<String, Object?> extensions;

  /// Buffer extras, preserved.
  final Object? extras;
}

/// Parsed glTF bufferView.
final class GltfBufferView {
  GltfBufferView._({
    required this.index,
    required this.name,
    required this.buffer,
    required this.byteOffset,
    required this.byteLength,
    required this.byteStride,
    required this.target,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// glTF bufferView index.
  final int index;

  /// Optional bufferView name.
  final String? name;

  /// Referenced buffer index.
  final int? buffer;

  /// Byte offset into the buffer.
  final int byteOffset;

  /// Byte length of the view.
  final int? byteLength;

  /// Optional byte stride.
  final int? byteStride;

  /// Optional GPU buffer target hint.
  final int? target;

  /// BufferView extensions, preserved.
  final Map<String, Object?> extensions;

  /// BufferView extras, preserved.
  final Object? extras;
}

/// Parsed glTF skin.
final class GltfSkin {
  GltfSkin._({
    required this.index,
    required this.name,
    required List<int> joints,
    required this.skeleton,
    required this.inverseBindMatrices,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : joints = List.unmodifiable(joints),
       extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// glTF skin index.
  final int index;

  /// Optional skin name.
  final String? name;

  /// Joint node indices.
  final List<int> joints;

  /// Optional skeleton root node index.
  final int? skeleton;

  /// Optional inverse bind matrix accessor index.
  final int? inverseBindMatrices;

  /// Skin extensions, preserved.
  final Map<String, Object?> extensions;

  /// Skin extras, preserved.
  final Object? extras;
}

/// Parsed glTF accessor.
final class GltfAccessor {
  GltfAccessor._({
    required this.index,
    required this.name,
    required this.bufferView,
    required this.byteOffset,
    required this.count,
    required this.componentType,
    required this.type,
    required this.normalized,
    required List<double>? minimum,
    required List<double>? maximum,
    required this.sparse,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : minimum = minimum == null ? null : List.unmodifiable(minimum),
       maximum = maximum == null ? null : List.unmodifiable(maximum),
       extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// glTF accessor index.
  final int index;

  /// Optional accessor name.
  final String? name;

  /// Optional bufferView index.
  final int? bufferView;

  /// Byte offset into the bufferView.
  final int byteOffset;

  /// Accessor element count.
  final int? count;

  /// glTF component type integer.
  final int? componentType;

  /// glTF accessor type string.
  final String? type;

  /// Whether integer values should be normalized.
  final bool normalized;

  /// Optional accessor component minima.
  final List<double>? minimum;

  /// Optional accessor component maxima.
  final List<double>? maximum;

  /// Sparse accessor overrides, if present.
  final GltfAccessorSparse? sparse;

  /// Accessor extensions, preserved.
  final Map<String, Object?> extensions;

  /// Accessor extras, preserved.
  final Object? extras;

  /// Number of scalar components in one accessor element.
  int? get componentCount => _accessorComponentCount(type);
}

/// Parsed glTF sparse accessor metadata.
final class GltfAccessorSparse {
  GltfAccessorSparse._({
    required this.count,
    required this.indicesBufferView,
    required this.indicesByteOffset,
    required this.indicesComponentType,
    required Map<String, Object?> indicesExtensions,
    required Object? indicesExtras,
    required this.valuesBufferView,
    required this.valuesByteOffset,
    required Map<String, Object?> valuesExtensions,
    required Object? valuesExtras,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : indicesExtensions =
           _immutableJsonValue(indicesExtensions) as Map<String, Object?>,
       indicesExtras = _immutableJsonValue(indicesExtras),
       valuesExtensions =
           _immutableJsonValue(valuesExtensions) as Map<String, Object?>,
       valuesExtras = _immutableJsonValue(valuesExtras),
       extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// Number of sparse elements.
  final int? count;

  /// BufferView containing sparse element indices.
  final int? indicesBufferView;

  /// Byte offset into the sparse indices bufferView.
  final int indicesByteOffset;

  /// Component type for sparse indices.
  final int? indicesComponentType;

  /// Sparse indices extensions, preserved.
  final Map<String, Object?> indicesExtensions;

  /// Sparse indices extras, preserved.
  final Object? indicesExtras;

  /// BufferView containing replacement values.
  final int? valuesBufferView;

  /// Byte offset into the sparse values bufferView.
  final int valuesByteOffset;

  /// Sparse values extensions, preserved.
  final Map<String, Object?> valuesExtensions;

  /// Sparse values extras, preserved.
  final Object? valuesExtras;

  /// Sparse accessor extensions, preserved.
  final Map<String, Object?> extensions;

  /// Sparse accessor extras, preserved.
  final Object? extras;
}

/// Parsed glTF texture.
final class GltfTexture {
  GltfTexture._({
    required this.index,
    required this.name,
    required this.source,
    required this.sampler,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// glTF texture index.
  final int index;

  /// Optional texture name.
  final String? name;

  /// Referenced image index, if any.
  final int? source;

  /// Referenced sampler index, if any.
  final int? sampler;

  /// Texture extensions, preserved.
  final Map<String, Object?> extensions;

  /// Texture extras, preserved.
  final Object? extras;
}

/// Parsed glTF image.
final class GltfImage {
  GltfImage._({
    required this.index,
    required this.name,
    required this.uri,
    required this.bufferView,
    required this.mimeType,
    required Uint8List? data,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : _data = data == null
           ? null
           : Uint8List.fromList(data).asUnmodifiableView(),
       extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// glTF image index.
  final int index;

  /// Optional image name.
  final String? name;

  /// Image URI, if any.
  final String? uri;

  /// Referenced bufferView index, if any.
  final int? bufferView;

  /// Image MIME type, if any.
  final String? mimeType;

  final Uint8List? _data;

  /// Resolved image bytes for `data:`, caller-resolved URI, or bufferView images.
  Uint8List? get data => _data;

  /// Image extensions, preserved.
  final Map<String, Object?> extensions;

  /// Image extras, preserved.
  final Object? extras;
}

/// Parsed glTF texture sampler.
final class GltfSampler {
  GltfSampler._({
    required this.index,
    required this.name,
    required this.magFilter,
    required this.minFilter,
    required this.wrapS,
    required this.wrapT,
    required Map<String, Object?> extensions,
    required Object? extras,
  }) : extensions = _immutableJsonValue(extensions) as Map<String, Object?>,
       extras = _immutableJsonValue(extras);

  /// glTF sampler index.
  final int index;

  /// Optional sampler name.
  final String? name;

  /// Magnification filter enum value.
  final int? magFilter;

  /// Minification filter enum value.
  final int? minFilter;

  /// S-axis wrap enum value.
  final int? wrapS;

  /// T-axis wrap enum value.
  final int? wrapT;

  /// Sampler extensions, preserved.
  final Map<String, Object?> extensions;

  /// Sampler extras, preserved.
  final Object? extras;
}
