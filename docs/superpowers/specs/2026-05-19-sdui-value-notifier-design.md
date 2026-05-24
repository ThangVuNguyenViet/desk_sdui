# SDUI Demo App — ValueNotifier State Management Design

## Date
2026-05-19

## Problem

The SDUI framework evaluates screen IR into a widget tree. When event handlers mutate state (e.g., `Counter.count++`), the framework needs a way to know the state changed and trigger a rebuild. The current `setState` callback approach fails because:

1. The framework caches input values in `Cell` objects during IR evaluation
2. Subsequent rebuilds read from those cached cells, not the live object
3. Calling `setState()` rebuilds the widget tree, but the IR re-evaluation still sees stale cached values

This causes button presses to execute the action (e.g., `incrementCount` runs, `count` increments to 1, 2, 3...) but the UI remains stuck at the initial value ("0").

## Goal

Replace imperative `setState` callbacks with `ValueNotifier` so that state mutations are observable and automatically trigger widget rebuilds.

## Constraints

- All packages must analyze cleanly (0 errors)
- Demo app must build and run without crashes
- Preserve existing test suite (206+ tests passing)
- No changes to the code generator needed (Counter stays a plain mutable class)
- fdb integration must continue to work for automated UI testing

## Architecture

```
┌─────────────────────────────────────┐
│  DemoApp                            │
│  ├─ _counter: ValueNotifier<Counter>│
│  ├─ _actions: CounterActions        │
│  └─ build: ValueListenableBuilder   │
│       valueListenable: _counter     │
│       builder: (_, counter, __) =>  │
│         SduiScreen(inputs: {        │
│           'c': counter,             │
│           'a': _actions             │
│         })                          │
└─────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  CounterActions.incrementCount(c)   │
│  ├─ c.count++                       │
│  └─ _notifier.value = c  ◄──────────┼── triggers ValueListenableBuilder
└─────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  ValueListenableBuilder rebuilds    │
│  SduiScreen with fresh counter ref  │
│  IR re-evaluates, reads c.count=1   │
│  UI updates to "1"                  │
└─────────────────────────────────────┘
```

## Design Decisions

### 1. ValueNotifier vs ChangeNotifier

**Chosen**: `ValueNotifier<Counter>`

**Why**: `ValueNotifier` is the simplest Flutter-native observable. It exposes a `.value` setter that automatically notifies listeners. `ChangeNotifier` would require adding getters/setters to every field of `Counter`, which is unnecessary boilerplate for a demo app.

**Trade-off**: `ValueNotifier` requires the actions class to call `_notifier.value = c` after mutation, which is slightly less ergonomic than `ChangeNotifier` fields that auto-notify. But it's simpler overall.

### 2. Counter stays a plain mutable class

**Decision**: Do NOT modify `Counter` to be observable. Keep it as a plain mutable Dart class.

**Why**: The code generator expects plain mutable classes for `@Register`. Adding `ChangeNotifier` or making fields private with getters/setters would break the generator's lowering logic (it generates `Counter.count` accesses, not `_count` accesses).

### 3. CounterActions holds the ValueNotifier

**Decision**: `CounterActions` receives `ValueNotifier<Counter>` in its constructor and calls `_notifier.value = c` after each mutation.

**Why**: This centralizes the notification logic in one place. Every action method follows the same pattern: mutate `c`, then `_notifier.value = c`. It's explicit and easy to understand.

### 4. DemoApp wraps SduiScreen in ValueListenableBuilder

**Decision**: The top-level `DemoApp` creates `_counter = ValueNotifier(Counter())` and wraps the `SduiScreen` in `ValueListenableBuilder<Counter>`.

**Why**: This is the standard Flutter pattern for observable state. The `ValueListenableBuilder` rebuilds whenever `_counter.value` is reassigned, passing the latest `Counter` instance down to `SduiScreen`.

### 5. Framework: make registerPayloadClass idempotent

**Decision**: Change `registerPayloadClass` in `runtime.dart` to silently skip if already registered, instead of throwing `StateError`.

**Why**: When `ValueListenableBuilder` triggers a rebuild, `SduiScreen` re-resolves the IR tree, which re-registers the `Counter` payload class. The idempotent registration prevents a crash on every rebuild.

### 6. Remove kNotifyChangedKey from SduiScreen

**Decision**: Remove the `kNotifyChangedKey` hook from `SduiScreen._composeInput`.

**Why**: With `ValueListenableBuilder`, rebuilds are driven externally by the observable state. The screen no longer needs an internal rebuild hook.

## Data Flow

1. **Initial build**: `DemoApp` creates `_counter = ValueNotifier(Counter())`, `_actions = CounterActions(_counter)`. `ValueListenableBuilder` builds `SduiScreen` with `inputs: {'c': _counter.value, 'a': _actions}`. The IR evaluates `Counter.count` → `0`, UI shows "0".

2. **Button tap**: `fdb tap @2` triggers the `EventNode(['a', 'incrementCount'])` handler. The handler resolves to `CounterActions.incrementCount(c)` where `c` is the current `Counter` instance.

3. **Mutation**: `incrementCount` does `c.count = c.count + 1` (now `count=1`), then `_notifier.value = c`.

4. **Notification**: `ValueNotifier.value = c` calls `notifyListeners()`, which triggers `ValueListenableBuilder` to rebuild.

5. **Rebuild**: `ValueListenableBuilder` calls its builder with the updated `Counter` instance. `SduiScreen` receives `inputs: {'c': counter, 'a': _actions}` where `counter.count == 1`.

6. **IR re-evaluation**: `SduiScreen` resolves the IR tree. `GetterNode(receiver: RefNode(['c']), name: 'Counter.count')` reads `input['c'].count` → `1`. UI shows "1".

## Error Handling

- **Payload class already registered**: Fixed by making `registerPayloadClass` idempotent. No action needed by caller.
- **Missing ValueNotifier**: `CounterActions` constructor requires `ValueNotifier<Counter>`. Passing `null` would be a compile error.
- **Disposed ValueNotifier**: If `DemoApp` disposes `_counter` while actions are still running, the next `_notifier.value = c` would be a no-op (listener list is empty).

## Testing

1. **Unit test**: Verify `CounterActions.incrementCount` increments `c.count` and assigns to `_notifier.value`.
2. **Widget test**: Pump `DemoApp`, tap the `+` button, verify the counter text changes from "0" to "1".
3. **fdb integration test**: Launch app via `fdb`, tap `@2` (increment), verify via `fdb describe` that visible text changes from "0" to "1".

## Files Changed

- `packages/desk_sdui_demo/lib/main.dart`: Use `ValueNotifier<Counter>`, wrap in `ValueListenableBuilder`
- `packages/desk_sdui_demo/lib/screens/counter_demo.dart`: `CounterActions` accepts `ValueNotifier<Counter>`, calls `_notifier.value = c` after mutations
- `packages/desk_sdui/lib/src/runtime.dart`: Make `registerPayloadClass` and `registerPayloadMixin` idempotent
- `packages/desk_sdui/lib/src/sdui_screen.dart`: Remove `kNotifyChangedKey` hook
- `packages/desk_sdui/lib/src/resolve.dart`: Remove `kNotifyChangedKey` wrapper around `EventNode`/`ActionSequenceNode`

## Dependencies

No new dependencies. `ValueNotifier` and `ValueListenableBuilder` are part of `package:flutter/foundation.dart`.

## Migration Notes

- Remove all debug print statements before committing
- The `_StatefulIrHost` in `resolve.dart` still uses `setState` for its internal state cells — this is fine because it's managing its own isolated state, not external state
- The `fdb_helper` integration continues to work as-is

## Success Criteria

- [ ] `fdb launch` starts the app successfully
- [ ] `fdb describe` shows "0" initially
- [ ] `fdb tap @2` (increment) changes visible text from "0" to "1"
- [ ] `fdb tap @1` (decrement) changes visible text from "1" to "0"
- [ ] Multiple taps update the counter correctly (0 → 1 → 2 → 3 → ...)
- [ ] `dart analyze` passes with 0 errors
- [ ] Existing tests pass
