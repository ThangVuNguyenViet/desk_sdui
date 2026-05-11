# desk_sdui_generator

build_runner codegen for desk_sdui — lowers `@Screen` functions to IR.

## Server-side compilation

If your server already runs Dart, you can skip `build_runner` entirely and
invoke the lowering pass directly:

```dart
import 'package:desk_sdui_generator/desk_sdui_generator.dart';

final result = await compileToIr(
  screenSource: '''
    @Screen('counter')
    Widget counter(CounterData data) => Text('${data.value}');
  ''',
  dataModelSource: '''
    class CounterData {
      final int value;
      const CounterData(this.value);
    }
  ''',
  catalogSource: '''
    @Register([Text])
    class _Catalog {}
  ''',
);

switch (result) {
  case CompileSuccess(:final ir):
    // ir is Map<String, Object?> — the same JSON IR that build_runner emits
    await saveToCache(ir);
  case CompileFailure(:final errors):
    for (final e in errors) {
      log.severe(e);
    }
}
```

Requirements:

- The host package must depend on `flutter` (transitively is fine) so that
  `package:flutter/material.dart` can be resolved by the analyzer.
- Widget types referenced in the screen body must be listed in
  `catalogSource` via `@Register([...])`, exactly as they would be in the
  `build_runner` path.
- There is no CLI, no separate package, and no network transport. The function
  is synchronous with respect to the caller; the returned `Future` resolves
  once the analyzer pass and lowering are complete.
