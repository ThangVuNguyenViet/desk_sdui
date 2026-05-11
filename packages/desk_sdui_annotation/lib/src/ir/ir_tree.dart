import 'package:meta/meta.dart';

import 'ir_node.dart';

/// Root container for a full screen's IR (Intermediate Representation).
///
/// The IR is the portable, JSON-serializable tree that desk_sdui's generator
/// produces from each `@Screen` Dart function. At runtime, the desk_sdui
/// [Runtime] walks this tree and materializes a Flutter widget tree.
///
/// An [IrTree] carries:
/// - [name] — the screen's stable identifier (matches `@Screen('...')`).
/// - [version] — a schema version, used to gate runtime compatibility.
/// - [root] — the root [IrNode] of the widget tree.
///
/// Trees can be loaded from local assets, fetched over the network, or
/// composed server-side; the [Runtime] accepts any path because the
/// in-memory representation is the same.
@immutable
class IrTree {
  const IrTree({
    required this.name,
    required this.version,
    required this.root,
  });

  /// Stable identifier (matches the `@Screen('...')` argument).
  final String name;

  /// Schema version. Bumped when the IR shape changes incompatibly.
  /// Runtime refuses to load a tree whose [version] is newer than what it
  /// supports.
  final int version;

  /// The screen's root node.
  final IrNode root;

  @override
  bool operator ==(Object other) =>
      other is IrTree &&
      other.name == name &&
      other.version == version &&
      other.root == root;

  @override
  int get hashCode => Object.hash(name, version, root);

  @override
  String toString() => 'IrTree($name, v$version)';
}

/// Current IR schema version. Bump when adding/changing nodes incompatibly.
const int currentIrVersion = 1;
