import 'runtime.dart';

/// Walks a pre-split path through nested maps and lists and returns the leaf.
/// Only handles data-shape traversal; property accessors on primitives are
/// lowered to GetterNode (see expression_eval.dart).
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
      'resolveRef: cannot traverse "$seg" into ${current.runtimeType} '
      '(expected Map or List). Property accessors must be lowered as '
      'GetterNode, not appended to RefNode paths.',
    );
  }
  return current;
}

/// Resolves a path that may start with a Flutter class name (Icons, Colors,
/// CrossAxisAlignment, …). Constants are looked up via Runtime.resolveConstant.
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
      if (path.length == 2) return v;
      return resolveRef(path.sublist(2), {'__root__': v});
    }
  }
  return resolveRef(path, input);
}
