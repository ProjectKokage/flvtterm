part of '../../flvtterm.dart';

double _clamp01(double value) {
  if (value.isNaN || value <= 0) return 0;
  if (value >= 1) return 1;
  return value;
}

int? _accessorComponentCount(String? type) {
  return switch (type) {
    'SCALAR' => 1,
    'VEC2' => 2,
    'VEC3' => 3,
    'VEC4' => 4,
    'MAT2' => 4,
    'MAT3' => 9,
    'MAT4' => 16,
    _ => null,
  };
}

List<double> _samplerValue(
  List<double> output,
  int key,
  int valueDimension,
  String interpolation,
) {
  final frameStride = interpolation == 'CUBICSPLINE'
      ? valueDimension * 3
      : valueDimension;
  final valueOffset = interpolation == 'CUBICSPLINE' ? valueDimension : 0;
  final start = key * frameStride + valueOffset;
  return List.unmodifiable(output.sublist(start, start + valueDimension));
}

List<double> _lerpList(List<double> a, List<double> b, double t) {
  return List.unmodifiable([
    for (var i = 0; i < a.length; i++) a[i] + (b[i] - a[i]) * t,
  ]);
}

List<double> _cubicSpline(
  List<double> output,
  int key,
  int valueDimension,
  double t,
  double duration,
) {
  final frameStride = valueDimension * 3;
  final current = key * frameStride;
  final next = (key + 1) * frameStride;
  final t2 = t * t;
  final t3 = t2 * t;
  final a = 2 * t3 - 3 * t2 + 1;
  final b = duration * (t3 - 2 * t2 + t);
  final c = -2 * t3 + 3 * t2;
  final d = duration * (t3 - t2);
  return List.unmodifiable([
    for (var i = 0; i < valueDimension; i++)
      a * output[current + valueDimension + i] +
          b * output[current + valueDimension * 2 + i] +
          c * output[next + valueDimension + i] +
          d * output[next + i],
  ]);
}

List<double> _slerp(List<double> a, List<double> b, double t) {
  var dot = 0.0;
  for (var i = 0; i < 4; i++) {
    dot += a[i] * b[i];
  }
  final target = List<double>.of(b);
  if (dot < 0) {
    dot = -dot;
    for (var i = 0; i < target.length; i++) {
      target[i] = -target[i];
    }
  }
  if (dot > 0.9995) {
    return _normalize(_lerpList(a, target, t));
  }
  final theta = math.acos(_clamp01(dot));
  final sinTheta = math.sin(theta);
  final scaleA = math.sin((1 - t) * theta) / sinTheta;
  final scaleB = math.sin(t * theta) / sinTheta;
  return _normalize([
    for (var i = 0; i < 4; i++) a[i] * scaleA + target[i] * scaleB,
  ]);
}

List<double> _normalize(List<double> value) {
  var lengthSquared = 0.0;
  for (final component in value) {
    lengthSquared += component * component;
  }
  if (lengthSquared == 0) return List.unmodifiable(value);
  final invLength = 1 / math.sqrt(lengthSquared);
  return List.unmodifiable([
    for (final component in value) component * invLength,
  ]);
}
