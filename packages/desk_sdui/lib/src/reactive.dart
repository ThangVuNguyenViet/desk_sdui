import 'package:flutter/foundation.dart';

/// Installs a getter shim at [path] in [input] that reads from the
/// [ValueListenable] found in [reactiveMap] under the joined path string.
///
/// This is called inside a `ListenableBuilder` callback so that each rebuild
/// reads the latest `listenable.value`.
void installReactiveGetter(
  Map<String, Object?> input,
  List<String> path,
  Map<String, Object?> reactiveMap,
) {
  final pathStr = path.join('.');
  final listenable = reactiveMap[pathStr];
  if (listenable is! ValueListenable) return;
  var cursor = input;
  for (var i = 0; i < path.length - 1; i++) {
    final next = cursor[path[i]];
    if (next is Map) {
      cursor = Map<String, Object?>.of(next.cast<String, Object?>());
      input[path[i]] = cursor;
    } else {
      final fresh = <String, Object?>{};
      cursor[path[i]] = fresh;
      cursor = fresh;
    }
  }
  final getters =
      (cursor['__getters__'] as Map?)?.cast<String, Object?>() ?? {};
  getters[path.last] = () => listenable.value;
  cursor['__getters__'] = getters;
}
