import 'package:meta/meta.dart';

import 'arith_op.dart';
import 'compare_op.dart';
import 'logic_op.dart';

/// Base class for every node in a desk_sdui IR (Intermediate Representation)
/// tree.
///
/// The IR is a sealed discriminated-union — each concrete subclass represents
/// one kind of build-time-known fragment of a screen:
///
/// - [LiteralNode] — a const value (`42`, `'hello'`, `EdgeInsets.all(8)`).
/// - [RefNode] — a data binding (`data.headline`, evaluated at render time
///   against the screen's data input).
/// - `WidgetNode` / `ValueCtorNode` — a constructor call producing a widget
///   or a const value, with named/positional argument sub-nodes.
/// - Iteration and conditional nodes — `for` and `if` constructs lifted from
///   the original Dart source.
/// - Expression nodes ([ExpressionNode] and its subclasses) — arithmetic,
///   comparison, and logical operations evaluated by the runtime.
///
/// Because the union is sealed, the runtime resolver and the generator can
/// `switch` exhaustively over [IrNode] without a default arm — adding a new
/// node type is a compile-time-checked change across all dispatch sites.
@immutable
sealed class IrNode {
  const IrNode();
}

/// Base for IR expression nodes (Tier 1 — pre-built AST, evaluated by the
/// runtime in O(1) per node via sealed-switch).
@immutable
sealed class ExpressionNode extends IrNode {
  const ExpressionNode();
}

/// A literal value. The value must be a const-constructible primitive
/// (bool, int, double, String, null) or a recognized const Dart value type
/// (e.g., `EdgeInsets.all(8)`, `Color(0xFF...)`).
final class LiteralNode extends IrNode {
  const LiteralNode(this.value);

  final Object? value;

  @override
  bool operator ==(Object other) =>
      other is LiteralNode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'LiteralNode($value)';
}

/// A const-folded subtree. Differs from `LiteralNode` in that its value is
/// a constructed object (a Flutter widget, typically) rather than a scalar.
/// Emitted by the lowerer's const-fold pass.
final class ConstNode extends IrNode {
  const ConstNode(this.value);

  /// The const-constructed value. The codec round-trips this as a typed
  /// reference (it is NOT serialized as a generic value — only the lowerer
  /// knows what const value lives here, encoded as a stable id).
  final Object? value;

  @override
  bool operator ==(Object other) => other is ConstNode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ConstNode($value)';
}

/// Reads a value from the resolver's input map by walking [path]. If
/// [reactive] is true, the runtime subscribes to the listenable at the
/// resolved value.
final class RefNode extends IrNode {
  const RefNode(this.path, {this.reactive = false});

  final List<String> path;
  final bool reactive;

  @override
  bool operator ==(Object other) =>
      other is RefNode &&
      _listEquals(other.path, path) &&
      other.reactive == reactive;

  @override
  int get hashCode => Object.hash(Object.hashAll(path), reactive);

  @override
  String toString() => 'RefNode($path, reactive: $reactive)';
}

/// A sequence of async-aware steps. Resolved into a `Future<void> Function()`
/// that runs the steps in order. Only appears as the resolved value of an
/// EventNode slot — never as a regular expression.
final class ActionSequenceNode extends IrNode {
  const ActionSequenceNode({required this.steps});
  final List<ActionStepNode> steps;

  @override
  bool operator ==(Object other) =>
      other is ActionSequenceNode && _listEquals(other.steps, steps);
  @override
  int get hashCode => Object.hashAll(steps);
  @override
  String toString() => 'ActionSequenceNode(${steps.length} steps)';
}

/// One step of an ActionSequenceNode: a method/function call, optionally
/// awaited, optionally binding its result to a name for later steps.
final class ActionStepNode extends IrNode {
  const ActionStepNode({
    required this.call,
    required this.awaitResult,
    this.bindResult,
  });
  final IrNode call;        // typically MethodCallNode; future: WidgetMethodNode, etc.
  final bool awaitResult;
  final String? bindResult;

  @override
  bool operator ==(Object other) =>
      other is ActionStepNode &&
      other.call == call &&
      other.awaitResult == awaitResult &&
      other.bindResult == bindResult;
  @override
  int get hashCode => Object.hash(call, awaitResult, bindResult);
  @override
  String toString() =>
      'ActionStepNode(${awaitResult ? "await " : ""}$call${bindResult != null ? " as $bindResult" : ""})';
}

/// Calls a bound method on the resolver's input map. Args are themselves
/// IrNodes (literals, refs, etc.) resolved at call time.
final class EventNode extends IrNode {
  const EventNode(this.target, {this.args = const {}});

  final List<String> target;
  final Map<String, IrNode> args;

  @override
  bool operator ==(Object other) =>
      other is EventNode &&
      _listEquals(other.target, target) &&
      _mapEquals(other.args, args);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(target), Object.hashAll(args.entries));

  @override
  String toString() => 'EventNode($target, args: $args)';
}

/// A registered widget invocation. [name] is the registered widget id;
/// [args] map argument names to IrNodes; [key] is an optional ValueKey
/// expression. [listenablePaths] is metadata emitted by the lowerer's
/// reactive-scope-hoisting pass.
final class WidgetNode extends IrNode {
  const WidgetNode({
    required this.name,
    required this.args,
    this.key,
    this.listenablePaths = const {},
  });

  final String name;
  final Map<String, IrNode> args;
  final IrNode? key;
  final Set<String> listenablePaths;

  @override
  bool operator ==(Object other) =>
      other is WidgetNode &&
      other.name == name &&
      _mapEquals(other.args, args) &&
      other.key == key &&
      _setEquals(other.listenablePaths, listenablePaths);

  @override
  int get hashCode => Object.hash(
        name,
        Object.hashAll(args.entries),
        key,
        Object.hashAll(listenablePaths),
      );

  @override
  String toString() => 'WidgetNode($name)';
}

/// A built-in widget — same shape as [WidgetNode] but reserved for SDK
/// primitives the runtime ships unconditionally. Distinct subtype so the
/// resolver can fast-path and the codegen can refuse to override builtins.
final class BuiltinWidgetNode extends IrNode {
  const BuiltinWidgetNode({
    required this.name,
    required this.args,
    this.key,
  });

  final String name;
  final Map<String, IrNode> args;
  final IrNode? key;

  @override
  bool operator ==(Object other) =>
      other is BuiltinWidgetNode &&
      other.name == name &&
      _mapEquals(other.args, args) &&
      other.key == key;

  @override
  int get hashCode => Object.hash(name, Object.hashAll(args.entries), key);

  @override
  String toString() => 'BuiltinWidgetNode($name)';
}

/// A list of IrNodes. Used inside `args` slots that take child lists.
final class ListNode extends IrNode {
  const ListNode(this.children);

  final List<IrNode> children;

  @override
  bool operator ==(Object other) =>
      other is ListNode && _listEquals(other.children, children);

  @override
  int get hashCode => Object.hashAll(children);

  @override
  String toString() => 'ListNode(${children.length} items)';
}

/// Map literal in the IR (rare; mostly for typed constructor args like
/// `style: TextStyle(...)`).
final class MapNode extends IrNode {
  const MapNode(this.entries);

  final Map<IrNode, IrNode> entries;

  @override
  bool operator ==(Object other) =>
      other is MapNode && _mapEquals(other.entries, entries);

  @override
  int get hashCode => Object.hashAll(entries.entries);

  @override
  String toString() => 'MapNode(${entries.length} entries)';
}

/// Dart record literal in the IR (positional + named fields).
final class RecordNode extends IrNode {
  const RecordNode({
    this.positional = const [],
    this.named = const {},
  });

  final List<IrNode> positional;
  final Map<String, IrNode> named;

  @override
  bool operator ==(Object other) =>
      other is RecordNode &&
      _listEquals(other.positional, positional) &&
      _mapEquals(other.named, named);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(positional),
        Object.hashAll(named.entries),
      );

  @override
  String toString() => 'RecordNode(positional: $positional, named: $named)';
}

/// `if (cond) then else else?` and ternary `cond ? then : else`.
final class ConditionalNode extends IrNode {
  const ConditionalNode({
    required this.condition,
    required this.thenBranch,
    this.elseBranch,
  });

  final IrNode condition;
  final IrNode thenBranch;
  final IrNode? elseBranch;

  @override
  bool operator ==(Object other) =>
      other is ConditionalNode &&
      other.condition == condition &&
      other.thenBranch == thenBranch &&
      other.elseBranch == elseBranch;

  @override
  int get hashCode => Object.hash(condition, thenBranch, elseBranch);

  @override
  String toString() =>
      'ConditionalNode($condition ? $thenBranch : $elseBranch)';
}

/// `for (final x in xs) body` — single-variable form.
/// `for (final (i, x) in xs.indexed) body` — destructured form (use
/// [ForNode.destructured]).
final class ForNode extends IrNode {
  const ForNode({
    required String this.variable,
    required this.source,
    required this.body,
  }) : variables = null;

  const ForNode.destructured({
    required List<String> this.variables,
    required this.source,
    required this.body,
  }) : variable = null;

  final String? variable;
  final List<String>? variables;
  final IrNode source;
  final IrNode body;

  @override
  bool operator ==(Object other) =>
      other is ForNode &&
      other.variable == variable &&
      _listEquals(other.variables, variables) &&
      other.source == source &&
      other.body == body;

  @override
  int get hashCode => Object.hash(
        variable,
        variables == null ? null : Object.hashAll(variables!),
        source,
        body,
      );

  @override
  String toString() {
    final v = variable ?? variables;
    return 'ForNode($v in $source)';
  }
}

/// `...somelist` inside a list literal.
final class SpreadNode extends IrNode {
  const SpreadNode(this.source);

  final IrNode source;

  @override
  bool operator ==(Object other) =>
      other is SpreadNode && other.source == source;

  @override
  int get hashCode => source.hashCode;

  @override
  String toString() => 'SpreadNode($source)';
}

// ─────────────────────────── expression nodes ───────────────────────────

/// `a == b`, `a != b`, `<`, `<=`, `>`, `>=` — the [op] selects which.
final class CompareOpNode extends ExpressionNode {
  const CompareOpNode({
    required this.op,
    required this.left,
    required this.right,
  });

  final CompareOp op;
  final IrNode left;
  final IrNode right;

  @override
  bool operator ==(Object other) =>
      other is CompareOpNode &&
      other.op == op &&
      other.left == left &&
      other.right == right;

  @override
  int get hashCode => Object.hash(op, left, right);

  @override
  String toString() => 'CompareOpNode($left ${op.name} $right)';
}

/// `+`, `-`, `*`, `/`, `%`.
final class ArithOpNode extends ExpressionNode {
  const ArithOpNode({
    required this.op,
    required this.left,
    required this.right,
  });

  final ArithOp op;
  final IrNode left;
  final IrNode right;

  @override
  bool operator ==(Object other) =>
      other is ArithOpNode &&
      other.op == op &&
      other.left == left &&
      other.right == right;

  @override
  int get hashCode => Object.hash(op, left, right);

  @override
  String toString() => 'ArithOpNode($left ${op.name} $right)';
}

/// `&&`, `||`.
final class LogicOpNode extends ExpressionNode {
  const LogicOpNode({
    required this.op,
    required this.left,
    required this.right,
  });

  final LogicOp op;
  final IrNode left;
  final IrNode right;

  @override
  bool operator ==(Object other) =>
      other is LogicOpNode &&
      other.op == op &&
      other.left == left &&
      other.right == right;

  @override
  int get hashCode => Object.hash(op, left, right);

  @override
  String toString() => 'LogicOpNode($left ${op.name} $right)';
}

/// `!operand`.
final class NotOpNode extends ExpressionNode {
  const NotOpNode(this.operand);

  final IrNode operand;

  @override
  bool operator ==(Object other) =>
      other is NotOpNode && other.operand == operand;

  @override
  int get hashCode => operand.hashCode;

  @override
  String toString() => 'NotOpNode(!$operand)';
}

/// `a ?? b`.
final class CoalesceOpNode extends ExpressionNode {
  const CoalesceOpNode({
    required this.left,
    required this.right,
  });

  final IrNode left;
  final IrNode right;

  @override
  bool operator ==(Object other) =>
      other is CoalesceOpNode && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);

  @override
  String toString() => 'CoalesceOpNode($left ?? $right)';
}

/// `receiver.name` where `name` is resolved through Runtime.invokeGetter,
/// not by walking a data path. `name` is the qualified handler key, e.g.
/// `'String.isNotEmpty'`, `'Iterable.first'`. Emitted by the lowerer when
/// the receiver's static type is a known core type.
final class GetterNode extends ExpressionNode {
  const GetterNode({required this.receiver, required this.name});
  final IrNode receiver;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is GetterNode && other.receiver == receiver && other.name == name;
  @override
  int get hashCode => Object.hash(receiver, name);
  @override
  String toString() => 'GetterNode($receiver.$name)';
}

/// `a.b` — accesses a property on the target.
final class MemberAccessNode extends ExpressionNode {
  const MemberAccessNode({
    required this.target,
    required this.name,
  });

  final IrNode target;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is MemberAccessNode && other.target == target && other.name == name;

  @override
  int get hashCode => Object.hash(target, name);

  @override
  String toString() => 'MemberAccessNode($target.$name)';
}

/// `a[k]` — index lookup (List, Map, etc.).
final class IndexAccessNode extends ExpressionNode {
  const IndexAccessNode({
    required this.target,
    required this.key,
  });

  final IrNode target;
  final IrNode key;

  @override
  bool operator ==(Object other) =>
      other is IndexAccessNode && other.target == target && other.key == key;

  @override
  int get hashCode => Object.hash(target, key);

  @override
  String toString() => 'IndexAccessNode($target[$key])';
}

/// `xs.length` — kept as its own node because length is so common and cheap
/// to special-case at runtime.
final class LengthOfNode extends ExpressionNode {
  const LengthOfNode(this.target);

  final IrNode target;

  @override
  bool operator ==(Object other) =>
      other is LengthOfNode && other.target == target;

  @override
  int get hashCode => target.hashCode;

  @override
  String toString() => 'LengthOfNode($target.length)';
}

/// `a == null` — separate from CompareOpNode because the runtime fast-paths
/// null checks without unboxing.
final class IsNullCheckNode extends ExpressionNode {
  const IsNullCheckNode(this.operand);

  final IrNode operand;

  @override
  bool operator ==(Object other) =>
      other is IsNullCheckNode && other.operand == operand;

  @override
  int get hashCode => operand.hashCode;

  @override
  String toString() => 'IsNullCheckNode($operand == null)';
}

/// `'hello $name!'` — parts is an alternating list of `String` literals and
/// `IrNode`s for the interpolation slots.
final class StringInterpNode extends ExpressionNode {
  const StringInterpNode(this.parts);

  /// Each element is either a `String` (literal text) or an `IrNode`
  /// (an interpolation slot).
  final List<Object> parts;

  @override
  bool operator ==(Object other) =>
      other is StringInterpNode && _partsEquals(other.parts, parts);

  @override
  int get hashCode => Object.hashAll(parts);

  @override
  String toString() => 'StringInterpNode(${parts.length} parts)';
}

/// Method invocation: `receiver.name(args)`. Resolved at runtime via
/// Runtime.invokeMethod(name, receiver, args).
final class MethodCallNode extends IrNode {
  const MethodCallNode({
    required this.receiver,
    required this.name,
    required this.args,
  });

  final IrNode? receiver;

  /// Receiver-type-keyed handler name, e.g. `'String.toUpperCase'`.
  /// For static methods (receiver is null), this is the qualified function name,
  /// e.g. `'Theme.of'`.
  final String name;
  final List<IrNode> args;

  @override
  bool operator ==(Object other) =>
      other is MethodCallNode &&
      other.receiver == receiver &&
      other.name == name &&
      _listEquals(other.args, args);

  @override
  int get hashCode => Object.hash(receiver, name, Object.hashAll(args));

  @override
  String toString() => 'MethodCallNode(${receiver ?? 'null'}.$name(${args.length} args))';
}

/// Value-type constructor invocation: `name(args)`. Resolved at runtime via
/// Runtime.invokeValueBuilder(name, args). Used for non-Widget value classes
/// like EdgeInsets, BoxDecoration, Color when not const-folded.
final class ValueCtorNode extends IrNode {
  const ValueCtorNode({
    required this.name,
    required this.args,
  });

  /// Qualified constructor name, e.g. `'EdgeInsets.all'`, `'BoxDecoration'`.
  final String name;
  final List<IrNode> args;

  @override
  bool operator ==(Object other) =>
      other is ValueCtorNode &&
      other.name == name &&
      _listEquals(other.args, args);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(args));

  @override
  String toString() => 'ValueCtorNode($name(${args.length} args))';
}

// ───────────────────────────── helpers ─────────────────────────────

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

bool _setEquals<T>(Set<T>? a, Set<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final item in a) {
    if (!b.contains(item)) return false;
  }
  return true;
}

bool _partsEquals(List<Object> a, List<Object> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
