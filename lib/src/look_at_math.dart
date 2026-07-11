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
  final normalized =
      math.min(value, rangeMap.inputMaxValue) / rangeMap.inputMaxValue;
  final curve = rangeMap.curve;
  return (curve.length >= 4 && curve.length % 4 == 0
          ? _evaluateVrm0LookAtCurve(curve, normalized)
          : normalized) *
      rangeMap.outputScale;
}

double _evaluateVrm0LookAtCurve(List<double> curve, double time) {
  final firstTime = curve[0];
  if (time <= firstTime) return curve[1];
  final last = curve.length - 4;
  if (time >= curve[last]) return curve[last + 1];

  for (var offset = 0; offset + 7 < curve.length; offset += 4) {
    final startTime = curve[offset];
    final endTime = curve[offset + 4];
    if (time > endTime) continue;
    final duration = endTime - startTime;
    if (duration <= 0) return curve[offset + 5];
    final t = (time - startTime) / duration;
    final t2 = t * t;
    final t3 = t2 * t;
    final startValue = curve[offset + 1];
    final startOutTangent = curve[offset + 3];
    final endValue = curve[offset + 5];
    final endInTangent = curve[offset + 6];
    return (2 * t3 - 3 * t2 + 1) * startValue +
        (t3 - 2 * t2 + t) * duration * startOutTangent +
        (-2 * t3 + 3 * t2) * endValue +
        (t3 - t2) * duration * endInTangent;
  }
  return curve[last + 1];
}
