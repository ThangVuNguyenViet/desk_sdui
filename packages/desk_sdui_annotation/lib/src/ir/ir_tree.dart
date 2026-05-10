import 'package:meta/meta.dart';

import 'ir_node.dart';

/// Root container for a full screen's IR. Carries the screen's identifier,
/// a schema version (used to gate runtime compatibility), and the root node.
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
