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
      'RefResolver: cannot index segment "$seg" on ${current.runtimeType}',
    );
  }
  return current;
}
