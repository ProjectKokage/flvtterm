part of '../flvtterm.dart';

VrmMeta _parseMeta(Object? value, GltfAsset gltf, _DiagnosticSink sink) {
  if (value is! Map) {
    sink.error(
      'vrm.metaInvalidObject',
      'VRMC_vrm.meta must be a JSON object.',
      jsonPath: r'$.extensions.VRMC_vrm.meta',
    );
  }
  final raw = _object(value);
  final name = _string(raw['name']);
  final version = _parseMetaString(raw, 'version', sink);
  final authors = _stringList(raw['authors']);
  final copyrightInformation = _parseMetaString(
    raw,
    'copyrightInformation',
    sink,
  );
  final contactInformation = _parseMetaString(raw, 'contactInformation', sink);
  final references = _parseMetaStringList(raw, 'references', sink);
  final thirdPartyLicenses = _parseMetaString(raw, 'thirdPartyLicenses', sink);
  final thumbnailImage = _parseMetaThumbnailImage(raw, gltf, sink);
  final licenseUrl = _string(raw['licenseUrl']);
  final rawAuthors = _list(raw['authors']);
  if (raw.containsKey('name') && raw['name'] is! String) {
    sink.error(
      'vrm.metaInvalidString',
      'VRMC_vrm.meta.name must be a string.',
      jsonPath: r'$.extensions.VRMC_vrm.meta.name',
    );
  }
  if (!raw.containsKey('name') || (raw['name'] is String && name!.isEmpty)) {
    sink.error(
      'vrm.metaMissingName',
      'VRMC_vrm.meta.name is required.',
      jsonPath: r'$.extensions.VRMC_vrm.meta.name',
    );
  }
  if (!raw.containsKey('authors') ||
      (raw['authors'] is List && authors.isEmpty)) {
    sink.error(
      'vrm.metaMissingAuthors',
      'VRMC_vrm.meta.authors must contain at least one author.',
      jsonPath: r'$.extensions.VRMC_vrm.meta.authors',
    );
  }
  if (raw.containsKey('authors') && raw['authors'] is! List) {
    sink.error(
      'vrm.metaInvalidAuthors',
      'VRMC_vrm.meta.authors must be an array of non-empty strings.',
      jsonPath: r'$.extensions.VRMC_vrm.meta.authors',
    );
  }
  for (var i = 0; i < rawAuthors.length; i++) {
    final author = rawAuthors[i];
    if (author is String && author.isNotEmpty) continue;
    sink.error(
      'vrm.metaInvalidAuthors',
      'VRMC_vrm.meta.authors entries must be non-empty strings.',
      jsonPath: '\$.extensions.VRMC_vrm.meta.authors[$i]',
    );
  }
  if (!raw.containsKey('licenseUrl')) {
    sink.error(
      'vrm.metaMissingLicenseUrl',
      'VRMC_vrm.meta.licenseUrl is required.',
      jsonPath: r'$.extensions.VRMC_vrm.meta.licenseUrl',
    );
  }
  if (raw.containsKey('licenseUrl') && raw['licenseUrl'] is! String) {
    sink.error(
      'vrm.metaInvalidString',
      'VRMC_vrm.meta.licenseUrl must be a string.',
      jsonPath: r'$.extensions.VRMC_vrm.meta.licenseUrl',
    );
  }
  return VrmMeta._(
    name: name,
    version: version,
    authors: authors,
    copyrightInformation: copyrightInformation,
    contactInformation: contactInformation,
    references: references,
    thirdPartyLicenses: thirdPartyLicenses,
    thumbnailImage: thumbnailImage,
    licenseUrl: licenseUrl,
    avatarPermission: _parseMetaEnum(
      raw,
      'avatarPermission',
      VrmMetaAvatarPermission.values,
      (value) => value.specName,
      VrmMetaAvatarPermission.onlyAuthor,
      sink,
    ),
    allowExcessivelyViolentUsage: _parseMetaBool(
      raw,
      'allowExcessivelyViolentUsage',
      sink,
    ),
    allowExcessivelySexualUsage: _parseMetaBool(
      raw,
      'allowExcessivelySexualUsage',
      sink,
    ),
    commercialUsage: _parseMetaEnum(
      raw,
      'commercialUsage',
      VrmMetaCommercialUsage.values,
      (value) => value.specName,
      VrmMetaCommercialUsage.personalNonProfit,
      sink,
    ),
    allowPoliticalOrReligiousUsage: _parseMetaBool(
      raw,
      'allowPoliticalOrReligiousUsage',
      sink,
    ),
    allowAntisocialOrHateUsage: _parseMetaBool(
      raw,
      'allowAntisocialOrHateUsage',
      sink,
    ),
    creditNotation: _parseMetaEnum(
      raw,
      'creditNotation',
      VrmMetaCreditNotation.values,
      (value) => value.specName,
      VrmMetaCreditNotation.required,
      sink,
    ),
    allowRedistribution: _parseMetaBool(raw, 'allowRedistribution', sink),
    modification: _parseMetaEnum(
      raw,
      'modification',
      VrmMetaModification.values,
      (value) => value.specName,
      VrmMetaModification.prohibited,
      sink,
    ),
    otherLicenseUrl: _parseMetaString(raw, 'otherLicenseUrl', sink),
    raw: raw,
  );
}

String? _parseMetaString(
  Map<String, Object?> raw,
  String field,
  _DiagnosticSink sink,
) {
  if (raw.containsKey(field) && raw[field] is! String) {
    sink.error(
      'vrm.metaInvalidString',
      'VRMC_vrm.meta.$field must be a string.',
      jsonPath: '\$.extensions.VRMC_vrm.meta.$field',
    );
  }
  return _string(raw[field]);
}

List<String> _parseMetaStringList(
  Map<String, Object?> raw,
  String field,
  _DiagnosticSink sink,
) {
  if (!raw.containsKey(field)) return const [];
  final value = raw[field];
  final values = _stringList(value);
  if (value is! List || value.isEmpty || values.length != value.length) {
    sink.error(
      'vrm.metaInvalidStringList',
      'VRMC_vrm.meta.$field must be a non-empty array of strings.',
      jsonPath: '\$.extensions.VRMC_vrm.meta.$field',
    );
    return const [];
  }
  return List.unmodifiable(values);
}

int? _parseMetaThumbnailImage(
  Map<String, Object?> raw,
  GltfAsset gltf,
  _DiagnosticSink sink,
) {
  if (!raw.containsKey('thumbnailImage')) return null;
  final value = raw['thumbnailImage'];
  if (value is! int) {
    sink.error(
      'vrm.metaInvalidThumbnailImage',
      'VRMC_vrm.meta.thumbnailImage must be a glTF image index.',
      jsonPath: r'$.extensions.VRMC_vrm.meta.thumbnailImage',
    );
    return null;
  }
  _validateIndex(
    value,
    gltf.images.length,
    sink,
    'vrm.metaInvalidThumbnailImage',
    r'$.extensions.VRMC_vrm.meta.thumbnailImage',
  );
  if (value < 0 || value >= gltf.images.length) return null;
  _validateMetaThumbnailDimensions(gltf.images[value], sink);
  return value;
}

void _validateMetaThumbnailDimensions(GltfImage image, _DiagnosticSink sink) {
  final bytes = image.data;
  if (bytes == null) return;
  final dimensions = _imageDimensions(bytes);
  if (dimensions == null || dimensions.width == dimensions.height) return;
  sink.error(
    'vrm.metaThumbnailNotSquare',
    'VRMC_vrm.meta.thumbnailImage must reference a square image; image ${image.index} is ${dimensions.width} x ${dimensions.height}.',
    jsonPath: r'$.extensions.VRMC_vrm.meta.thumbnailImage',
  );
}

bool _parseMetaBool(
  Map<String, Object?> raw,
  String field,
  _DiagnosticSink sink,
) {
  if (raw.containsKey(field) && raw[field] is! bool) {
    sink.error(
      'vrm.metaInvalidBoolean',
      'VRMC_vrm.meta.$field must be a boolean.',
      jsonPath: '\$.extensions.VRMC_vrm.meta.$field',
    );
  }
  return _bool(raw[field]) ?? false;
}

T _parseMetaEnum<T>(
  Map<String, Object?> raw,
  String field,
  List<T> values,
  String Function(T value) specName,
  T fallback,
  _DiagnosticSink sink,
) {
  if (!raw.containsKey(field)) return fallback;
  final value = raw[field];
  if (value is String) {
    for (final entry in values) {
      if (specName(entry) == value) return entry;
    }
  }
  sink.error(
    'vrm.metaInvalidEnum',
    'VRMC_vrm.meta.$field is not a valid VRM 1.0 value.',
    jsonPath: '\$.extensions.VRMC_vrm.meta.$field',
  );
  return fallback;
}
