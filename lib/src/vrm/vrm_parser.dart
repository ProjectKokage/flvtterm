import 'package:meta/meta.dart';

import '../diagnostics.dart';
import '../gltf/gltf_types.dart';
import '../json_values.dart';
import 'vrm_enums.dart';
import 'vrm_expression_parser.dart';
import 'vrm_first_person_parser.dart';
import 'vrm_humanoid_parser.dart';
import 'vrm_look_at_parser.dart';
import 'vrm_meta_parser.dart';
import 'vrm_types.dart';

@internal
VrmExtension? parseVrmExtension(GltfAsset gltf, DiagnosticSink sink) {
  final rootExtensions = jsonObject(gltf.json['extensions']);
  if (rootExtensions.containsKey('VRMC_vrm_animation')) {
    sink.warning(
      'vrm.embeddedVrmaExtension',
      'VRMC_vrm_animation is intended for separate VRMA files, not VRM model assets.',
      jsonPath: r'$.extensions.VRMC_vrm_animation',
    );
  }
  final extensionValue = rootExtensions['VRMC_vrm'];
  if (extensionValue != null && extensionValue is! Map) {
    sink.error(
      'vrm.invalidExtensionObject',
      'Root extensions.VRMC_vrm must be a JSON object.',
      jsonPath: r'$.extensions.VRMC_vrm',
    );
    return null;
  }
  final raw = jsonObject(extensionValue);
  if (extensionValue == null) {
    sink.error(
      'vrm.missingExtension',
      'Root extensions.VRMC_vrm is required.',
      jsonPath: r'$.extensions.VRMC_vrm',
    );
    return null;
  }

  final specVersion = jsonString(raw['specVersion']);
  if (!raw.containsKey('specVersion')) {
    sink.error(
      'vrm.missingSpecVersion',
      'VRMC_vrm.specVersion is required.',
      jsonPath: r'$.extensions.VRMC_vrm.specVersion',
    );
  } else if (specVersion != '1.0') {
    sink.error(
      'vrm.unsupportedSpecVersion',
      'VRMC_vrm.specVersion must be "1.0".',
      jsonPath: r'$.extensions.VRMC_vrm.specVersion',
    );
  }
  if (!raw.containsKey('meta')) {
    sink.error(
      'vrm.missingMeta',
      'VRMC_vrm.meta is required.',
      jsonPath: r'$.extensions.VRMC_vrm.meta',
    );
  }
  if (!raw.containsKey('humanoid')) {
    sink.error(
      'vrm.missingHumanoid',
      'VRMC_vrm.humanoid is required.',
      jsonPath: r'$.extensions.VRMC_vrm.humanoid',
    );
  }

  final meta = parseMeta(
    raw.containsKey('meta') ? raw['meta'] : const <String, Object?>{},
    gltf,
    sink,
  );
  final humanoid = parseHumanoid(
    raw.containsKey('humanoid') ? raw['humanoid'] : const <String, Object?>{},
    gltf,
    sink,
    r'$.extensions.VRMC_vrm.humanoid',
  );
  final firstPerson = parseFirstPerson(
    raw.containsKey('firstPerson')
        ? raw['firstPerson']
        : const <String, Object?>{},
    gltf,
    sink,
  );
  final expressions = parseExpressions(
    raw.containsKey('expressions')
        ? raw['expressions']
        : const <String, Object?>{},
    gltf,
    sink,
  );
  final lookAt = raw.containsKey('lookAt')
      ? parseLookAt(raw['lookAt'], sink)
      : null;

  return VrmExtension.internal(
    sourceVersion: VrmSourceVersion.vrm1,
    specVersion: specVersion,
    meta: meta,
    humanoid: humanoid,
    firstPerson: firstPerson,
    expressions: expressions,
    lookAt: lookAt,
    raw: raw,
  );
}
