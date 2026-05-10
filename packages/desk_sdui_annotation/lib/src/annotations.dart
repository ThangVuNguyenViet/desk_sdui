import 'package:meta/meta.dart';

/// Marks a function as an SDUI screen. The function's body is lowered to
/// IR by `desk_sdui_generator` at build time.
///
/// The [name] is the screen's identifier — used both in the generated
/// `ScreenBinding` and as the filename stem for the published `.sdui.json` blob.
@immutable
class Screen {
  const Screen(this.name);

  /// Stable identifier for this screen.
  final String name;

  @override
  bool operator ==(Object other) => other is Screen && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'Screen($name)';
}

/// Pre-registers widget / value types with the SDUI [Runtime] even when no
/// `@Screen` body in this binary directly references them.
///
/// This is needed for **network-only screens** — screens whose IR is fetched
/// at runtime and therefore never appear in static `@Screen` function bodies.
/// Place this annotation on any private sentinel class (e.g. `_SduiCoverage`)
/// in a file that is part of your app's build:
///
/// ```dart
/// @RegisterForSdui([PageView, SliverList, CupertinoButton])
/// class _SduiCoverage {}
/// ```
///
/// `desk_sdui_generator` discovers all classes annotated with
/// `@RegisterForSdui` and emits a `registerSduiCoverage(rt)` call (invoked
/// automatically from `registerAllScreens`) that registers each listed type
/// exactly as if it had been found in a `@Screen` body.
@immutable
class RegisterForSdui {
  const RegisterForSdui(this.types);

  /// The list of widget / value types to pre-register with the SDUI runtime.
  final List<Type> types;
}
