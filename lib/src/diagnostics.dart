part of '../flvtterm.dart';

/// How strictly asset validation should affect parsing.
enum VrmValidationMode {
  /// Reject assets that have validation errors.
  strict,

  /// Return parsed data when possible and keep validation errors as diagnostics.
  permissive,
}

/// Base class for validation diagnostic severities.
sealed class VrmDiagnosticSeverity {
  const VrmDiagnosticSeverity();

  /// Stable lowercase severity name.
  String get name;
}

/// Informational diagnostic.
final class VrmInfo extends VrmDiagnosticSeverity {
  /// Creates an informational diagnostic severity.
  const VrmInfo();

  @override
  String get name => 'info';
}

/// Warning diagnostic.
final class VrmWarning extends VrmDiagnosticSeverity {
  /// Creates a warning diagnostic severity.
  const VrmWarning();

  @override
  String get name => 'warning';
}

/// Error diagnostic.
final class VrmError extends VrmDiagnosticSeverity {
  /// Creates an error diagnostic severity.
  const VrmError();

  @override
  String get name => 'error';
}

/// A structured validation message for a VRM, VRMA, or glTF asset.
final class VrmDiagnostic {
  /// Creates a validation diagnostic.
  const VrmDiagnostic({
    required this.severity,
    required this.code,
    required this.message,
    this.jsonPath,
    this.gltfNodeIndex,
    this.gltfMaterialIndex,
  });

  /// Diagnostic severity.
  final VrmDiagnosticSeverity severity;

  /// Stable machine-readable diagnostic code.
  final String code;

  /// Human-readable diagnostic message.
  final String message;

  /// JSON path related to the diagnostic, when known.
  final String? jsonPath;

  /// glTF node index related to the diagnostic, when known.
  final int? gltfNodeIndex;

  /// glTF material index related to the diagnostic, when known.
  final int? gltfMaterialIndex;

  /// Whether this diagnostic is an error.
  bool get isError => severity is VrmError;

  @override
  String toString() {
    final path = jsonPath == null ? '' : ' at $jsonPath';
    return '${severity.name}: $code$path: $message';
  }
}

/// Validation diagnostics collected while parsing or checking an asset.
final class VrmValidationResult {
  /// Creates a validation result.
  VrmValidationResult(Iterable<VrmDiagnostic> diagnostics)
    : diagnostics = List.unmodifiable(diagnostics);

  /// No validation diagnostics.
  static final empty = VrmValidationResult(const []);

  /// All diagnostics in encounter order.
  final List<VrmDiagnostic> diagnostics;

  /// Diagnostics with error severity.
  Iterable<VrmDiagnostic> get errors => diagnostics.where((d) => d.isError);

  /// Diagnostics with warning severity.
  Iterable<VrmDiagnostic> get warnings =>
      diagnostics.where((d) => d.severity is VrmWarning);

  /// Diagnostics with info severity.
  Iterable<VrmDiagnostic> get infos =>
      diagnostics.where((d) => d.severity is VrmInfo);

  /// Whether any error diagnostics were reported.
  bool get hasErrors => diagnostics.any((d) => d.isError);
}

/// Result of a non-throwing parse operation.
final class VrmParseResult<T> {
  /// Creates a parse result.
  const VrmParseResult({required this.asset, required this.validation});

  /// Parsed asset, or null when parsing could not produce a usable asset.
  final T? asset;

  /// Diagnostics collected during parsing.
  final VrmValidationResult validation;

  /// Whether an asset was produced.
  bool get hasAsset => asset != null;
}

/// Thrown by strict convenience parsers when an asset has validation errors.
final class VrmInvalidAssetException implements Exception {
  /// Creates an invalid asset exception.
  const VrmInvalidAssetException(this.message, this.validation);

  /// Summary message.
  final String message;

  /// Validation diagnostics that explain the failure.
  final VrmValidationResult validation;

  @override
  String toString() => '$message\n${validation.errors.join('\n')}';
}
