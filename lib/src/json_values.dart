import 'package:meta/meta.dart';

import 'math_types.dart';

@internal
Map<String, Object?> jsonObject(Object? value) {
  if (value is! Map) return const {};
  return immutableJsonValue(value) as Map<String, Object?>;
}

/// The maps and lists [immutableJsonValue] produced. They are deeply
/// unmodifiable already, so freezing one again returns it unchanged instead
/// of copying its whole subtree.
final _frozenJson = Expando<bool>();

@internal
Object? immutableJsonValue(Object? value) {
  if (value is Map) {
    if (_frozenJson[value] ?? false) return value;
    final frozen = Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        if (entry.key is String)
          entry.key as String: immutableJsonValue(entry.value),
    });
    _frozenJson[frozen] = true;
    return frozen;
  }
  if (value is List) {
    if (_frozenJson[value] ?? false) return value;
    final frozen = List<Object?>.unmodifiable([
      for (final item in value) immutableJsonValue(item),
    ]);
    _frozenJson[frozen] = true;
    return frozen;
  }
  return value;
}

@internal
List<Object?> jsonList(Object? value) =>
    value is List ? value.cast<Object?>() : const [];

@internal
String? jsonString(Object? value) => value is String ? value : null;

@internal
int? jsonInt(Object? value) => value is int ? value : null;

@internal
double? jsonDouble(Object? value) => value is num ? value.toDouble() : null;

@internal
bool? jsonBool(Object? value) => value is bool ? value : null;

@internal
List<String> jsonStringList(Object? value) => List.unmodifiable([
  for (final item in jsonList(value))
    if (item is String) item,
]);

@internal
List<int> jsonIntList(Object? value) => List.unmodifiable([
  for (final item in jsonList(value))
    if (item is int) item,
]);

@internal
Map<String, int> jsonIntMap(Object? value) => Map.unmodifiable({
  for (final entry in jsonObject(value).entries)
    if (entry.value is int) entry.key: entry.value as int,
});

@internal
List<double> jsonDoubleList(Object? value, int length, List<double> fallback) {
  final result = [
    for (final item in jsonList(value))
      if (item is num) item.toDouble(),
  ];
  return result.length == length ? List.unmodifiable(result) : fallback;
}

@internal
List<double> jsonDoubleValues(Object? value) => List.unmodifiable([
  for (final item in jsonList(value))
    if (item is num) item.toDouble(),
]);

@internal
VrmVector2 jsonVector2(Object? value, VrmVector2 fallback) {
  final list = jsonDoubleList(value, 2, const []);
  return list.length == 2 ? VrmVector2(list[0], list[1]) : fallback;
}

@internal
VrmVector4 jsonVector4(Object? value, VrmVector4 fallback) {
  final list = jsonDoubleList(value, 4, const []);
  return list.length == 4
      ? VrmVector4(list[0], list[1], list[2], list[3])
      : fallback;
}

@internal
VrmVector4 jsonVector3As4(Object? value, VrmVector4 fallback) {
  final list = jsonDoubleList(value, 3, const []);
  return list.length == 3 ? VrmVector4(list[0], list[1], list[2], 1) : fallback;
}
