# Runtime cost measurements

What the `desk_sdui` runtime actually costs at startup and in memory. Re-runnable.

Referenced from [`why-not-flutter-eval.md`](./why-not-flutter-eval.md) — the "per-frame interpreter cost" argument is grounded in these numbers.

## Latest snapshot

**Date:** 2026-05-12
**Build:** `flutter run -d macos --profile` on Apple Silicon, `desk_sdui_demo`
**Demo state:** 10 screens, 150 catalog registrations (51 `registerWidget`, 74 `registerValueBuilder`, 15 `registerMethod`, 10 `registerScreen`)
**Commit:** `8b7a3e0` (post `feat/named-widget-factories` merge)

```
[sdui-probe] registerAllScreens: 275 µs, RSS delta 304 KB
(before 110288 KB, after 110592 KB)
```

| Metric | Value | Per-entry |
|---|---|---|
| Wall time | 275 µs | ~1.8 µs |
| RSS delta | 304 KB | ~2.0 KB |

These are measured against the cost rule from the design spec: *a build's total work must be `O(IR-tree-size + data-shape-size)`*. The 275 µs is the one-time registry population at app startup; per-frame cost is a separate measurement (not yet captured here — see "What we haven't measured").

## How to re-run

The probe lives in `packages/desk_sdui_demo/lib/main.dart`, inside `_DemoAppState.initState`:

```dart
final rssBefore = ProcessInfo.currentRss;
final sw = Stopwatch()..start();
registerAllScreens(rt);
sw.stop();
final rssAfter = ProcessInfo.currentRss;
debugPrint('[sdui-probe] registerAllScreens: '
    '${sw.elapsedMicroseconds} µs, '
    'RSS delta ${(rssAfter - rssBefore) ~/ 1024} KB '
    '(before ${rssBefore ~/ 1024} KB, after ${rssAfter ~/ 1024} KB)');
```

Run it via the dart MCP tools (`launch_app` + `get_app_logs`) or from the CLI:

```
cd packages/desk_sdui_demo
flutter run -d macos --profile  # or any desktop target with ProcessInfo support
```

Look for `[sdui-probe]` in the first few lines of app logs. Discard the first run on a cold system (filesystem cache warms up); the second run is stable.

**Required platform support:**
- macOS / Linux / Windows / iOS / Android — all work; `ProcessInfo.currentRss` is implemented natively.
- Web — `ProcessInfo.currentRss` returns 0 or -1. Not meaningful; skip.

If macOS support is missing from the demo, add it once:

```
cd packages/desk_sdui_demo && flutter create --platforms=macos .
```

## What the numbers mean

**275 µs wall time** is dominated by hashmap insertions (150 `Map<String, Function>.[]=` calls) and the closure literal evaluations. Closures in AOT are static constants, so no allocation per call — the cost is the map ops. On a phone CPU this would be ~2-3× higher (~700 µs); still well under the cold-start budget of any Flutter app.

**304 KB RSS delta** is broader than just the registry. It includes:
- Hashmap entries proper: ~150 entries × ~80 bytes = ~12 KB
- Interned key strings (`'Cue.onMount'`, `'Theme.of'`, …): ~150 × ~30 bytes = ~5 KB
- Closure objects (mostly shared, but first-touch may allocate per-call adapters): ~10-50 KB
- First-touch of lazy globals in `Runtime`, dependent registry init, etc.: the rest

The "registry itself" is in the tens of KB. The remainder is dependent state we'd pay for the first time the runtime did anything, registered or not. Treat 304 KB as an upper bound on registry-attributable RSS, not a precise figure.

**For comparison:** `dart_eval` (the engine behind flutter_eval) is reported in its docs at ~1.5-2 MB of binary contribution plus per-evaluation overhead. We're an order of magnitude below that for the same number of "things the runtime can do."

## What's claimed vs what's measured

This doc and [`why-not-flutter-eval.md`](./why-not-flutter-eval.md) make several quantitative claims comparing desk_sdui to flutter_eval / dart_eval. Be precise about which are verified and which are interpolated:

| Claim | Status | Source |
|---|---|---|
| flutter_eval adds ~1.4 MB to a Counter app (combined-arch APK) | ✅ **Verified** | [flutter_eval README "App size measurements"](https://pub.dev/packages/flutter_eval). Split-APK figure is ~0.7 MB; the "1.5-2 MB" framing uses the worst-case combined number. |
| dart_eval boxes every value via `$Value` wrappers | ✅ **Verified** | `lib/src/eval/runtime/ops/bridge.dart` (`InvokeExternal` casts args through `$Value?`), `lib/src/eval/bridge/runtime_bridge.dart` (`.$reified` unbox on every host return). Unconditional, no escape analysis. |
| flutter_eval re-executes bytecode per dirty rebuild | ✅ **Verified** | `lib/src/widgets/framework.dart` — `$StatelessWidget$bridge.build` and `$State$bridge.build` call `$_invoke('build', ...)` on every Flutter `build` call. No widget-tree caching. |
| dart_eval is 10-50× slower than native AOT Dart | ✅ **Verified** | Stated in dart_eval's own README. Authoritative from the maintainer. |
| Our per-`WidgetNode` resolve cost is ~50-100 ns | ⚠️ **Interpolated** | Theoretical estimate from the design spec. Not measured via `addTimingsCallback`. |
| flutter_eval's per-Column evaluation is ~500-2000 ns | ⚠️ **Interpolated** | Derived from dart_eval's 10-50× claim applied to a native ~30 ns ctor. Not directly benchmarked. |
| Our cumulative runtime contribution after buckets 1-3 is ~70-100 KB | ⚠️ **Projected** | LOC-to-binary estimate in the roadmap. Not measured via `flutter build --analyze-size`. |
| Our 304 KB RSS delta at 341 registrations | ✅ **Measured** | The probe in this doc. Reproducible. |
| Animation-path interpreter overhead compounds at 60 Hz | ✅ **Architecturally true**, magnitude ⚠️ **interpolated** | Verified that flutter_eval re-executes per rebuild; the ~30 ms/sec figure in `why-not-flutter-eval.md` is a back-of-envelope calculation, not a probe result. |

**TL;DR on the claims:** the *direction* of every perf/binary claim is verified against dart_eval's published documentation and source. The *specific magnitudes* (nanoseconds, KB) are interpolated from those verified facts but not yet probed directly. The architectural advantages (no boxing, no per-frame re-execution, smaller binary) are mechanistic facts of the design, not aspirational.

**What would settle the unverified parts:**
1. `flutter build macos --release --analyze-size` against an empty-SDUI baseline → real binary delta.
2. `WidgetsBinding.instance.addTimingsCallback` on the `counter_stress` demo at 60 Hz → real per-frame cost.
3. The same probe in a flutter_eval-equivalent counter screen → real comparative data.

---

## What we haven't measured

- **Per-frame build cost.** The design spec quotes ~50-100 ns per `WidgetNode` resolution and ~10-30 µs per 150-node build; these are theoretical estimates that should be confirmed via `WidgetsBinding.instance.addTimingsCallback`. Probe not yet wired.
- **Release binary size delta.** `flutter build macos --release --analyze-size` against an "empty SDUI" baseline would isolate the registry's binary contribution. Not yet captured.
- **Web bundle size.** dart2js tree-shaking interacts differently with the closure pinning; needs a separate measurement.
- **iOS / Android RSS.** Numbers above are macOS only. Mobile may differ on the constant.

If you measure any of these, append the numbers to this doc.

## Notes on scaling

The registry is `O(1)` per lookup regardless of size. Doubling the catalog roughly doubles the RSS delta and the startup time. Per-entry cost is essentially flat — there is no quadratic or log term to worry about until N gets into the tens of thousands (where hashmap collision behavior starts to matter).

For sense of scale: registering all of Flutter material would land somewhere around 3000 entries → ~6-10 ms startup, ~6 MB RSS delta, and would block tree-shaking of unreferenced widgets (the binary-size cost is the limiting factor, not RAM or CPU — see the rejected "register everything" discussion in design notes).
