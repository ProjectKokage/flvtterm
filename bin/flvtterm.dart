import 'dart:io';
import 'dart:typed_data';

import 'package:flvtterm/flvtterm.dart';

void main(List<String> arguments) {
  exitCode = _run(arguments);
}

int _run(List<String> arguments) {
  if (arguments.length == 1 && arguments.single == '--help') {
    stdout.writeln(
      'usage: dart run flvtterm <asset.vrm|asset.vrma|asset.gltf|asset.glb>',
    );
    return 0;
  }
  if (arguments.length != 1) {
    stderr.writeln(
      'usage: dart run flvtterm <asset.vrm|asset.vrma|asset.gltf|asset.glb>',
    );
    return 64;
  }

  final file = File(arguments.single);
  if (!file.existsSync()) {
    stderr.writeln('file not found: ${file.path}');
    return 66;
  }

  final result = _parse(
    file.path,
    file.readAsBytesSync(),
    _localResolver(file),
  );
  for (final diagnostic in result.validation.diagnostics) {
    stdout.writeln(diagnostic);
  }
  stdout.writeln(
    '${result.kind}: ${result.validation.errors.length} errors, '
    '${result.validation.warnings.length} warnings',
  );
  return result.validation.hasErrors ? 1 : 0;
}

({String kind, VrmValidationResult validation}) _parse(
  String path,
  Uint8List bytes,
  GltfUriResolver uriResolver,
) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.vrm')) {
    final result = VrmModel.tryParseGlb(
      bytes,
      validation: VrmValidationMode.permissive,
      uriResolver: uriResolver,
    );
    return (kind: 'VRM', validation: result.validation);
  }
  if (lower.endsWith('.vrma')) {
    final result = VrmAnimationAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
      uriResolver: uriResolver,
    );
    return (kind: 'VRMA', validation: result.validation);
  }
  final result = GltfAsset.tryParse(
    bytes: bytes,
    validation: VrmValidationMode.permissive,
    uriResolver: uriResolver,
  );
  if (result.asset?.extensions.containsKey('VRMC_vrm_animation') ?? false) {
    final vrma = VrmAnimationAsset.tryParse(
      bytes: bytes,
      validation: VrmValidationMode.permissive,
      uriResolver: uriResolver,
    );
    return (kind: 'VRMA', validation: vrma.validation);
  }
  if (_isGlb(bytes) &&
      ((result.asset?.extensions.containsKey('VRMC_vrm') ?? false) ||
          (result.asset?.extensions.containsKey('VRM') ?? false))) {
    final vrm = VrmModel.tryParseGlb(
      bytes,
      validation: VrmValidationMode.permissive,
      uriResolver: uriResolver,
    );
    return (kind: 'VRM', validation: vrm.validation);
  }
  return (kind: 'glTF', validation: result.validation);
}

bool _isGlb(Uint8List bytes) =>
    bytes.length >= 4 &&
    ByteData.sublistView(bytes).getUint32(0, Endian.little) == 0x46546c67;

GltfUriResolver _localResolver(File source) {
  final baseDirectory = source.parent.absolute;
  final baseUri = baseDirectory.uri;
  final basePath = _withTrailingSeparator(
    baseDirectory.resolveSymbolicLinksSync(),
  );
  return (uri) {
    final parsed = Uri.tryParse(uri);
    if (parsed == null) return null;
    if (parsed.hasScheme) return null;
    final resolved = baseUri.resolveUri(parsed);
    final file = File.fromUri(resolved);
    if (!file.existsSync()) return null;
    final resolvedPath = file.resolveSymbolicLinksSync();
    if (!resolvedPath.startsWith(basePath)) return null;
    return File(resolvedPath).readAsBytesSync();
  };
}

String _withTrailingSeparator(String path) {
  final separator = Platform.pathSeparator;
  return path.endsWith(separator) ? path : '$path$separator';
}
