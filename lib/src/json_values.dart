part of '../flvtterm.dart';

Map<String, Object?> _object(Object? value) {
  if (value is! Map) return const {};
  return _immutableJsonValue(value) as Map<String, Object?>;
}

/// The maps and lists [_immutableJsonValue] produced. They are deeply
/// unmodifiable already, so freezing one again returns it unchanged instead
/// of copying its whole subtree.
final _frozenJson = Expando<bool>();

Object? _immutableJsonValue(Object? value) {
  if (value is Map) {
    if (_frozenJson[value] ?? false) return value;
    final frozen = Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        if (entry.key is String)
          entry.key as String: _immutableJsonValue(entry.value),
    });
    _frozenJson[frozen] = true;
    return frozen;
  }
  if (value is List) {
    if (_frozenJson[value] ?? false) return value;
    final frozen = List<Object?>.unmodifiable([
      for (final item in value) _immutableJsonValue(item),
    ]);
    _frozenJson[frozen] = true;
    return frozen;
  }
  return value;
}

List<Object?> _list(Object? value) =>
    value is List ? value.cast<Object?>() : const [];

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : null;

double? _double(Object? value) => value is num ? value.toDouble() : null;

bool? _bool(Object? value) => value is bool ? value : null;

List<String> _stringList(Object? value) => List.unmodifiable([
  for (final item in _list(value))
    if (item is String) item,
]);

List<int> _intList(Object? value) => List.unmodifiable([
  for (final item in _list(value))
    if (item is int) item,
]);

Map<String, int> _intMap(Object? value) => Map.unmodifiable({
  for (final entry in _object(value).entries)
    if (entry.value is int) entry.key: entry.value as int,
});

List<double> _doubleList(Object? value, int length, List<double> fallback) {
  final result = [
    for (final item in _list(value))
      if (item is num) item.toDouble(),
  ];
  return result.length == length ? List.unmodifiable(result) : fallback;
}

List<double> _doubleValues(Object? value) => List.unmodifiable([
  for (final item in _list(value))
    if (item is num) item.toDouble(),
]);

VrmVector2 _vector2(Object? value, VrmVector2 fallback) {
  final list = _doubleList(value, 2, const []);
  return list.length == 2 ? VrmVector2(list[0], list[1]) : fallback;
}

VrmVector4 _vector4(Object? value, VrmVector4 fallback) {
  final list = _doubleList(value, 4, const []);
  return list.length == 4
      ? VrmVector4(list[0], list[1], list[2], list[3])
      : fallback;
}

VrmVector4 _vector3As4(Object? value, VrmVector4 fallback) {
  final list = _doubleList(value, 3, const []);
  return list.length == 3 ? VrmVector4(list[0], list[1], list[2], 1) : fallback;
}
