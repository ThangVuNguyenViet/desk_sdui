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
      // Named core accessors take priority over numeric index parsing.
      switch (seg) {
        case 'length':
          current = current.length;
          continue;
        case 'isEmpty':
          current = current.isEmpty;
          continue;
        case 'isNotEmpty':
          current = current.isNotEmpty;
          continue;
        case 'first':
          current = current.isEmpty ? null : current.first;
          continue;
        case 'last':
          current = current.isEmpty ? null : current.last;
          continue;
      }
      final i = int.tryParse(seg);
      if (i == null || i < 0 || i >= current.length) return null;
      current = current[i];
      continue;
    }
    if (current is String) {
      switch (seg) {
        case 'length':
          current = current.length;
          continue;
        case 'isEmpty':
          current = current.isEmpty;
          continue;
        case 'isNotEmpty':
          current = current.isNotEmpty;
          continue;
      }
      // Unknown String accessor — return null gracefully rather than throw.
      return null;
    }
    if (current is Iterable) {
      // Materialise once so length/isEmpty/isNotEmpty are O(1) for most
      // concrete types; for lazy iterables this is acceptable at resolve time.
      final list = current.toList();
      switch (seg) {
        case 'length':
          current = list.length;
          continue;
        case 'isEmpty':
          current = list.isEmpty;
          continue;
        case 'isNotEmpty':
          current = list.isNotEmpty;
          continue;
        case 'first':
          current = list.isEmpty ? null : list.first;
          continue;
        case 'last':
          current = list.isEmpty ? null : list.last;
          continue;
      }
      // Unknown Iterable accessor — return null gracefully.
      return null;
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
