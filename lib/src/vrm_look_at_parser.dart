part of '../flvtterm.dart';

VrmLookAt? _parseLookAt(Object? value, _DiagnosticSink sink) {
  if (value is! Map) {
    sink.error(
      'vrm.invalidLookAtObject',
      'VRMC_vrm.lookAt must be a JSON object.',
      jsonPath: r'$.extensions.VRMC_vrm.lookAt',
    );
    return null;
  }
  final raw = _object(value);
  final type = _string(raw['type']);
  final invalidType =
      raw.containsKey('type') &&
      (type == null ||
          !VrmLookAtType.values.any((value) => value.specName == type));
  if (invalidType) {
    sink.error(
      'vrm.invalidLookAtType',
      'LookAt type must be bone or expression.',
      jsonPath: r'$.extensions.VRMC_vrm.lookAt.type',
    );
  }
  if (raw.containsKey('offsetFromHeadBone') &&
      _doubleList(raw['offsetFromHeadBone'], 3, const []).length != 3) {
    sink.error(
      'vrm.invalidLookAtOffset',
      'LookAt offsetFromHeadBone must contain three numbers.',
      jsonPath: r'$.extensions.VRMC_vrm.lookAt.offsetFromHeadBone',
    );
  }
  final rangeMapHorizontalInner = _parseRangeMap(
    raw,
    sink,
    'rangeMapHorizontalInner',
  );
  final rangeMapHorizontalOuter = _parseRangeMap(
    raw,
    sink,
    'rangeMapHorizontalOuter',
  );
  final rangeMapVerticalDown = _parseRangeMap(
    raw,
    sink,
    'rangeMapVerticalDown',
  );
  final rangeMapVerticalUp = _parseRangeMap(raw, sink, 'rangeMapVerticalUp');
  if (invalidType) return null;
  return VrmLookAt._(
    type: VrmLookAtType.fromSpecName(type),
    offsetFromHeadBone: _doubleList(raw['offsetFromHeadBone'], 3, const [
      0,
      0,
      0,
    ]),
    rangeMapHorizontalInner: rangeMapHorizontalInner,
    rangeMapHorizontalOuter: rangeMapHorizontalOuter,
    rangeMapVerticalDown: rangeMapVerticalDown,
    rangeMapVerticalUp: rangeMapVerticalUp,
    raw: raw,
  );
}

VrmLookAtRangeMap _parseRangeMap(
  Map<String, Object?> parent,
  _DiagnosticSink sink,
  String field,
) {
  final value = parent[field];
  if (parent.containsKey(field) && value is! Map) {
    sink.error(
      'vrm.invalidLookAtRangeMapObject',
      'LookAt $field must be a JSON object.',
      jsonPath: '\$.extensions.VRMC_vrm.lookAt.$field',
    );
    return VrmLookAtRangeMap(inputMaxValue: 0, outputScale: 0);
  }
  final raw = _object(value);
  final inputMaxValue = _double(raw['inputMaxValue']);
  final outputScale = _double(raw['outputScale']);
  if (raw.containsKey('inputMaxValue') &&
      (inputMaxValue == null || inputMaxValue < 0 || inputMaxValue > 180)) {
    sink.error(
      'vrm.invalidLookAtRangeMapInput',
      'LookAt range map inputMaxValue must be a number in the range 0..180.',
      jsonPath: '\$.extensions.VRMC_vrm.lookAt.$field.inputMaxValue',
    );
  }
  if (raw.containsKey('outputScale') && outputScale == null) {
    sink.error(
      'vrm.invalidLookAtRangeMapOutput',
      'LookAt range map outputScale must be a number.',
      jsonPath: '\$.extensions.VRMC_vrm.lookAt.$field.outputScale',
    );
  }
  return VrmLookAtRangeMap(
    inputMaxValue: inputMaxValue ?? 0,
    outputScale: outputScale ?? 0,
    raw: raw,
  );
}
