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
///
/// ## Usage
///
/// Preferred (library-level, Dart 3.0+):
///
/// ```dart
/// @Register([Text, Column, ElevatedButton])
/// library;
/// ```
///
/// Alternative (carrier class — for files that don't own the library directive):
///
/// ```dart
/// @Register([Text, Column, ElevatedButton])
/// class _SduiCatalog {}
/// ```
///
/// Both forms produce the same registry contribution. Multiple catalogs in
/// the same package are unioned.
///
/// `desk_sdui_generator` discovers all `@Register` annotations and emits a
/// `registerSduiCatalog(rt)` call (invoked automatically from
/// `registerAllScreens`) that registers each listed type exactly as if it
/// had been found in a `@Screen` body.
@immutable
class Register {
  const Register(this.types);

  /// The list of widget / value types to pre-register with the SDUI runtime.
  final List<Type> types;
}
