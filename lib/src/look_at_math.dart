part of '../flvtterm.dart';

final class _YawPitch {
  const _YawPitch(this.yawDegrees, this.pitchDegrees);

  final double yawDegrees;
  final double pitchDegrees;
}

double _rangeMap(double value, VrmLookAtRangeMap rangeMap) {
  if (rangeMap.inputMaxValue == 0) {
    return value == 0 ? 0 : rangeMap.outputScale;
  }
  return math.min(value, rangeMap.inputMaxValue) /
      rangeMap.inputMaxValue *
      rangeMap.outputScale;
}
