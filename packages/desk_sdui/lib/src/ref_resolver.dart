import 'runtime.dart';

/// Walks a pre-split path through nested maps/lists and returns the leaf.
///
/// Codegen emits paths like `['data','items','0','title']`; per-build cost
/// is one `Map.[]` or `List.[]` per segment.
Object? resolveRef(List<String> path, Map<String, Object?> input) {
  Object? current = input;
  for (final seg in path) {
    if (current == null) return null;
    if (current is Map) {
      final getters = current['__getters__'];
      if (getters is Map && getters.containsKey(seg)) {
        final g = getters[seg];
        if (g is Function) {
          current = Function.apply(g, const []);
          continue;
        }
      }
      current = current[seg];
      continue;
    }
    if (current is List) {
      final i = int.tryParse(seg);
      if (i == null || i < 0 || i >= current.length) return null;
      current = current[i];
      continue;
    }
    throw StateError(
      'resolveRef: cannot traverse segment "$seg" into ${current.runtimeType} '
      '(expected Map or List). Input contract is Map<String, Object?>.',
    );
  }
  return current;
}

/// Resolves a reference path that may start with a Flutter class name
/// (e.g., ['Icons', 'arrow_back_ios_new'], ['CrossAxisAlignment', 'start']).
///
/// Constants are looked up via [runtime].resolveConstant using the codegen key
/// shape `'ClassName.memberName'`. Falls back to a plain [resolveRef] walk
/// when no constant is registered for the path.
Object? resolveFlutterRef(
  List<String> path,
  Map<String, Object?> input,
  Runtime runtime,
) {
  if (path.isEmpty) return null;
  if (path.length >= 2) {
    final key = '${path[0]}.${path[1]}';
    final v = runtime.resolveConstant(key);
    if (v != null) {
      // Walk any remaining path segments into the constant (rare, e.g. a
      // constant that is itself a struct).
      if (path.length == 2) return v;
      return resolveRef(path.sublist(2), {'__root__': v});
    }
  }
  return resolveRef(path, input);
}
