import 'core_accessors.dart';
import 'runtime.dart';

// Global singleton runtime instance for core accessor resolution.
// Initialized on first use via _getDefaultRuntime().
Runtime? _defaultRuntime;

/// Returns or creates the default runtime for core accessor resolution.
Runtime _getDefaultRuntime() {
  if (_defaultRuntime == null) {
    _defaultRuntime = Runtime();
    registerCoreAccessors(_defaultRuntime!);
  }
  return _defaultRuntime!;
}

/// Walks a pre-split path through nested maps and lists and returns the leaf.
/// Handles data-shape traversal and core property accessors (String.isEmpty,
/// List.length, etc.) via the registered getter registry.
Object? resolveRef(List<String> path, Map<String, Object?> input,
    [Runtime? runtime]) {
  runtime ??= _getDefaultRuntime();
  Object? current = input;

  for (var i = 0; i < path.length; i++) {
    final seg = path[i];
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

    // Handle String accessors via registered getters
    if (current is String) {
      final getter = runtime.resolveGetter('String.$seg');
      if (getter != null) {
        return getter(current);
      }
      return null;
    }

    // Handle Iterable/List accessors via registered getters
    // This must come before the raw List index check to properly handle
    // property accesses like 'isNotEmpty' or 'first'.
    if (current is Iterable) {
      // Try List-specific getter first (for List-only properties), then Iterable
      final getter = runtime.resolveGetter('List.$seg') ??
          runtime.resolveGetter('Iterable.$seg');
      if (getter != null) {
        return getter(current);
      }
      // If not a registered getter, fall through to index parsing for Lists
      if (current is List) {
        final idx = int.tryParse(seg);
        if (idx == null || idx < 0 || idx >= current.length) return null;
        current = current[idx];
        continue;
      }
      // Iterable but not List and getter not found
      return null;
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
      return resolveRef(path.sublist(2), {'__root__': v}, runtime);
    }
  }
  return resolveRef(path, input, runtime);
}
