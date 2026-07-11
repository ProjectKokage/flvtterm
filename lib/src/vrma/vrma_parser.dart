part of '../../flvtterm.dart';

VrmAnimationExtension? _parseVrmaExtension(
  GltfAsset gltf,
  _DiagnosticSink sink,
) {
  final rootExtensions = _object(gltf.json['extensions']);
  if (rootExtensions.containsKey('VRMC_vrm')) {
    sink.warning(
      'vrma.embeddedVrmExtension',
      'VRMC_vrm_animation is intended for separate animation-only glTF files, not VRM model assets.',
      jsonPath: r'$.extensions.VRMC_vrm',
    );
  }
  final extensionValue = rootExtensions['VRMC_vrm_animation'];
  if (extensionValue != null && extensionValue is! Map) {
    sink.error(
      'vrma.invalidExtensionObject',
      'Root extensions.VRMC_vrm_animation must be a JSON object.',
      jsonPath: r'$.extensions.VRMC_vrm_animation',
    );
    return null;
  }
  final raw = _object(extensionValue);
  if (extensionValue == null) {
    sink.error(
      'vrma.missingExtension',
      'Root extensions.VRMC_vrm_animation is required.',
      jsonPath: r'$.extensions.VRMC_vrm_animation',
    );
    return null;
  }
  final specVersion = _string(raw['specVersion']);
  if (!raw.containsKey('specVersion')) {
    sink.error(
      'vrma.missingSpecVersion',
      'VRMC_vrm_animation.specVersion is required.',
      jsonPath: r'$.extensions.VRMC_vrm_animation.specVersion',
    );
  } else if (specVersion != '1.0') {
    sink.error(
      'vrma.unsupportedSpecVersion',
      'VRMC_vrm_animation.specVersion must be "1.0".',
      jsonPath: r'$.extensions.VRMC_vrm_animation.specVersion',
    );
  }

  if (raw['humanoid'] is Map &&
      !_object(raw['humanoid']).containsKey('humanBones')) {
    sink.error(
      'vrma.missingHumanoidHumanBones',
      'VRMC_vrm_animation.humanoid.humanBones is required when humanoid is present.',
      jsonPath: r'$.extensions.VRMC_vrm_animation.humanoid.humanBones',
    );
  }
  final humanoid = _parseHumanoid(
    raw.containsKey('humanoid') ? raw['humanoid'] : const <String, Object?>{},
    gltf,
    sink,
    r'$.extensions.VRMC_vrm_animation.humanoid',
    validateRequiredBones: raw['humanoid'] is Map,
  );
  final expressionsRaw = _vrmaExpressions(
    raw.containsKey('expressions')
        ? raw['expressions']
        : const <String, Object?>{},
    sink,
  );
  final presetExpressions = <VrmExpressionPreset, int>{};
  final customExpressions = <String, int>{};
  for (final entry in _vrmaExpressionGroup(
    expressionsRaw,
    'preset',
    sink,
  ).entries) {
    final preset = VrmExpressionPreset.fromSpecName(entry.key);
    if (preset == null) {
      sink.warning(
        'vrma.unknownPresetExpression',
        'Unknown VRMA preset expression "${entry.key}" was ignored.',
        jsonPath: _vrmaExpressionPath('preset', entry.key),
      );
      continue;
    }
    if (const {
      VrmExpressionPreset.lookUp,
      VrmExpressionPreset.lookDown,
      VrmExpressionPreset.lookLeft,
      VrmExpressionPreset.lookRight,
    }.contains(preset)) {
      sink.error(
        'vrma.invalidLookExpressionTarget',
        '${preset.specName} must use VRMA LookAt, not expression animation.',
        jsonPath: _vrmaExpressionPath('preset', preset.specName),
      );
      continue;
    }
    final node = _parseVrmaExpressionNode(
      entry.key,
      entry.value,
      gltf,
      sink,
      group: 'preset',
    );
    if (node != null) presetExpressions[preset] = node;
  }
  for (final entry in _vrmaExpressionGroup(
    expressionsRaw,
    'custom',
    sink,
  ).entries) {
    if (VrmExpressionPreset.fromSpecName(entry.key) != null) {
      sink.error(
        'vrma.customExpressionPresetCollision',
        'Custom expression "${entry.key}" collides with a preset expression.',
        jsonPath: _vrmaExpressionPath('custom', entry.key),
      );
      continue;
    }
    final node = _parseVrmaExpressionNode(
      entry.key,
      entry.value,
      gltf,
      sink,
      group: 'custom',
    );
    if (node != null) customExpressions[entry.key] = node;
  }

  final hasLookAt = raw.containsKey('lookAt');
  final lookAtValue = raw['lookAt'];
  final lookAt = _vrmaLookAt(
    hasLookAt ? lookAtValue : const <String, Object?>{},
    sink,
  );
  final lookAtNode = _int(lookAt['node']);
  if (lookAt.containsKey('node') && lookAtNode == null) {
    sink.error(
      'vrma.invalidLookAtNode',
      'VRMA LookAt node must be an integer.',
      jsonPath: r'$.extensions.VRMC_vrm_animation.lookAt.node',
    );
  }
  if (lookAtNode != null) {
    _validateIndex(
      lookAtNode,
      gltf.nodes.length,
      sink,
      'vrma.invalidLookAtNode',
      r'$.extensions.VRMC_vrm_animation.lookAt.node',
    );
  }
  final validLookAtNode =
      lookAtNode != null && lookAtNode >= 0 && lookAtNode < gltf.nodes.length;
  if (lookAt.containsKey('offsetFromHeadBone') &&
      _doubleList(lookAt['offsetFromHeadBone'], 3, const []).length != 3) {
    sink.error(
      'vrma.invalidLookAtOffset',
      'VRMA LookAt offsetFromHeadBone must contain three numbers.',
      jsonPath: r'$.extensions.VRMC_vrm_animation.lookAt.offsetFromHeadBone',
    );
  }
  return VrmAnimationExtension._(
    specVersion: specVersion,
    humanoid: humanoid,
    presetExpressions: presetExpressions,
    customExpressions: customExpressions,
    lookAt: validLookAtNode ? lookAtNode : null,
    offsetFromHeadBone: _doubleList(lookAt['offsetFromHeadBone'], 3, const [
      0,
      0,
      0,
    ]),
    raw: raw,
  );
}

int? _parseVrmaExpressionNode(
  String name,
  Object? value,
  GltfAsset gltf,
  _DiagnosticSink sink, {
  required String group,
}) {
  final isPreset = group == 'preset';
  final invalidNodeCode = isPreset
      ? 'vrma.invalidPresetExpressionNode'
      : 'vrma.invalidCustomExpressionNode';
  if (value != null && value is! Map) {
    sink.error(
      isPreset
          ? 'vrma.invalidPresetExpressionObject'
          : 'vrma.invalidCustomExpressionObject',
      'VRMA $group expression "$name" must be a JSON object.',
      jsonPath: _vrmaExpressionPath(group, name),
    );
  }
  final expression = _object(value);
  final path = _vrmaExpressionPath(group, name, '.node');
  if (!expression.containsKey('node')) {
    sink.error(
      isPreset
          ? 'vrma.presetExpressionMissingNode'
          : 'vrma.customExpressionMissingNode',
      'VRMA $group expression must specify a node.',
      jsonPath: path,
    );
    return null;
  }
  final node = _int(expression['node']);
  if (node == null) {
    sink.error(
      invalidNodeCode,
      'VRMA $group expression node must be an integer.',
      jsonPath: path,
    );
    return null;
  }
  _validateIndex(node, gltf.nodes.length, sink, invalidNodeCode, path);
  return node >= 0 && node < gltf.nodes.length ? node : null;
}

Map<String, Object?> _vrmaExpressions(Object? value, _DiagnosticSink sink) {
  if (value is! Map) {
    sink.error(
      'vrma.invalidExpressionsObject',
      'VRMC_vrm_animation.expressions must be a JSON object.',
      jsonPath: r'$.extensions.VRMC_vrm_animation.expressions',
    );
  }
  return _object(value);
}

Map<String, Object?> _vrmaExpressionGroup(
  Map<String, Object?> raw,
  String field,
  _DiagnosticSink sink,
) {
  if (!raw.containsKey(field)) return const {};
  final value = raw[field];
  if (value is Map) return value.cast<String, Object?>();
  sink.error(
    'vrma.invalidExpressionGroup',
    'VRMC_vrm_animation.expressions.$field must be a JSON object.',
    jsonPath: '\$.extensions.VRMC_vrm_animation.expressions.$field',
  );
  return const {};
}

Map<String, Object?> _vrmaLookAt(Object? value, _DiagnosticSink sink) {
  if (value is! Map) {
    sink.error(
      'vrma.invalidLookAtObject',
      'VRMC_vrm_animation.lookAt must be a JSON object.',
      jsonPath: r'$.extensions.VRMC_vrm_animation.lookAt',
    );
  }
  return _object(value);
}

String _vrmaExpressionPath(String group, String name, [String suffix = '']) =>
    '\$.extensions.VRMC_vrm_animation.expressions.$group.$name$suffix';
