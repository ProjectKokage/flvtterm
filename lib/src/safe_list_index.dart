part of '../flvtterm.dart';

extension _SafeListIndex<T> on List<T> {
  T? elementAtOrNull(int index) =>
      index < 0 || index >= length ? null : this[index];
}
