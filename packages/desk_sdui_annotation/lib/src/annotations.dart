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
