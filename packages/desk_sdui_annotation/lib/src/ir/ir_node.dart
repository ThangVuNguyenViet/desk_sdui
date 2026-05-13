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
/// - Statement nodes ([StatementNode] and its subclasses) — imperative
///   statements executed by the runtime's `executeStatement` path; yield
///   [ControlFlow] signals rather than values.
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

/// Base for IR statement nodes. Statements are executed by
/// `executeStatement(node, env, runtime)` which returns a [ControlFlow]
/// signal rather than a value. Expression-as-statement is handled by the
/// `default:` arm of `executeStatement` via `evalExpression`.
@immutable
sealed class StatementNode extends IrNode {
  const StatementNode();
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
///
/// Each element of [steps] is either an [ActionStepNode] (a plain call/await)
/// or a [TryStepNode] (a try/catch block).
final class ActionSequenceNode extends IrNode {
  const ActionSequenceNode({required this.steps});
  final List<IrNode> steps;

  @override
  bool operator ==(Object other) =>
      other is ActionSequenceNode && _listEquals(other.steps, steps);
  @override
  int get hashCode => Object.hashAll(steps);
  @override
  String toString() => 'ActionSequenceNode(${steps.length} steps)';
}

/// A try/catch step within an ActionSequenceNode. The resolver wraps the
/// `trySteps` in a Dart try/catch; on exception, it binds `exceptionBind`
/// (if non-null) into the local env and runs `catchSteps`.
final class TryStepNode extends IrNode {
  const TryStepNode({
    required this.trySteps,
    required this.catchSteps,
    this.exceptionBind,
  });
  final List<ActionStepNode> trySteps;
  final List<ActionStepNode> catchSteps;
  final String? exceptionBind;

  @override
  bool operator ==(Object other) =>
      other is TryStepNode &&
      _listEquals(other.trySteps, trySteps) &&
      _listEquals(other.catchSteps, catchSteps) &&
      other.exceptionBind == exceptionBind;
  @override
  int get hashCode =>
      Object.hash(Object.hashAll(trySteps), Object.hashAll(catchSteps), exceptionBind);
  @override
  String toString() =>
      'TryStepNode(try ${trySteps.length} catch (${exceptionBind ?? "_"}) ${catchSteps.length})';
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
///
/// [typeArgs] carries the explicit generic type arguments of the constructor
/// invocation (e.g. `['MyType']` for `MyWidget<MyType>(...)`). `null` means
/// no explicit type args were present in source. An empty list is never
/// emitted; treat it as `null` if encountered.
final class WidgetNode extends IrNode {
  const WidgetNode({
    required this.name,
    required this.args,
    this.key,
    this.listenablePaths = const {},
    this.typeArgs,
  });

  final String name;
  final Map<String, IrNode> args;
  final IrNode? key;
  final Set<String> listenablePaths;

  /// Explicit generic type arguments, or `null` if none. Simple names only
  /// (no library URIs, no nested generics). E.g. `['MyType']`, `['String', 'int']`.
  final List<String>? typeArgs;

  @override
  bool operator ==(Object other) =>
      other is WidgetNode &&
      other.name == name &&
      _mapEquals(other.args, args) &&
      other.key == key &&
      _setEquals(other.listenablePaths, listenablePaths) &&
      _listEquals(other.typeArgs, typeArgs);

  @override
  int get hashCode => Object.hash(
        name,
        Object.hashAll(args.entries),
        key,
        Object.hashAll(listenablePaths),
        typeArgs == null ? null : Object.hashAll(typeArgs!),
      );

  @override
  String toString() => typeArgs != null
      ? 'WidgetNode($name<${typeArgs!.join(', ')}>)'
      : 'WidgetNode($name)';
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

/// Binds `name = value` and evaluates `body` in the extended env.
/// Lowered from `final name = value; <body>` in @Screen bodies. Single-
/// assignment — no re-binding within the same scope.
final class LetNode extends ExpressionNode {
  const LetNode({required this.name, required this.value, required this.body});
  final String name;
  final IrNode value;
  final IrNode body;

  @override
  bool operator ==(Object other) =>
      other is LetNode &&
      other.name == name &&
      other.value == value &&
      other.body == body;
  @override
  int get hashCode => Object.hash(name, value, body);
  @override
  String toString() => 'LetNode($name = $value in $body)';
}

/// `name = value`. Mutates the cell bound at `name` in the current env.
/// Codegen guarantees `name` resolves to a writable cell (lowerer rejects
/// assignment against `final`-bound names). Returns the RHS value.
final class AssignNode extends ExpressionNode {
  const AssignNode({required this.name, required this.value});
  final String name;
  final IrNode value;

  @override
  bool operator ==(Object other) =>
      other is AssignNode && other.name == name && other.value == value;
  @override
  int get hashCode => Object.hash(name, value);
  @override
  String toString() => 'AssignNode($name = $value)';
}

/// Evaluates each step in [steps] in order (synchronously), then evaluates
/// and returns [returnExpr]. Used by cascade lowering: each step is a
/// side-effecting call on the cascade receiver, and [returnExpr] references
/// the receiver (typically via a Let-bound name).
///
/// Distinct from [ActionSequenceNode]: this is synchronous and returns a value
/// (the receiver). [ActionSequenceNode] is async and returns a `Future<void>
/// Function()` for event-handler slots.
final class SequenceNode extends ExpressionNode {
  const SequenceNode({required this.steps, required this.returnExpr});
  final List<IrNode> steps;
  final IrNode returnExpr;

  @override
  bool operator ==(Object other) =>
      other is SequenceNode &&
      _listEquals(other.steps, steps) &&
      other.returnExpr == returnExpr;
  @override
  int get hashCode => Object.hash(Object.hashAll(steps), returnExpr);
  @override
  String toString() => 'SequenceNode(${steps.length} steps, return $returnExpr)';
}

/// Synthesizes a Dart `Function` at resolve time. Captures the current env
/// (Map<String, Object?>) and produces a callable that, when invoked, extends
/// the captured env with the call-site param values and resolves `body`.
final class LambdaNode extends ExpressionNode {
  const LambdaNode({
    required this.params,
    required this.body,
    this.isAsync = false,
  });
  final List<String> params;
  final IrNode body;
  final bool isAsync;

  @override
  bool operator ==(Object other) =>
      other is LambdaNode &&
      _listEquals(other.params, params) &&
      other.body == body &&
      other.isAsync == isAsync;
  @override
  int get hashCode => Object.hash(Object.hashAll(params), body, isAsync);
  @override
  String toString() =>
      'LambdaNode(${isAsync ? "async " : ""}(${params.join(", ")}) => $body)';
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

/// Non-null type test: `receiver is TypeName`. Resolved by checking the
/// runtime type against a registered Dart type name. Type names are matched
/// by simple name string — payload generics are erased.
final class IsTypeNode extends ExpressionNode {
  const IsTypeNode({required this.receiver, required this.typeName});
  final IrNode receiver;
  final String typeName;

  @override
  bool operator ==(Object other) =>
      other is IsTypeNode &&
      other.receiver == receiver &&
      other.typeName == typeName;
  @override
  int get hashCode => Object.hash(receiver, typeName);
  @override
  String toString() => 'IsTypeNode($receiver is $typeName)';
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
///
/// [typeArgs] carries explicit generic type arguments on the call, e.g.
/// `vm.fetch<MyType>()` → `typeArgs: ['MyType']`. `null` means no explicit
/// type args. Builders that don't care about generics may ignore this.
final class MethodCallNode extends IrNode {
  const MethodCallNode({
    required this.receiver,
    required this.name,
    required this.args,
    this.typeArgs,
  });

  final IrNode? receiver;

  /// Receiver-type-keyed handler name, e.g. `'String.toUpperCase'`.
  /// For static methods (receiver is null), this is the qualified function name,
  /// e.g. `'Theme.of'`.
  final String name;
  final List<IrNode> args;

  /// Explicit generic type arguments, or `null` if none. Simple names only
  /// (no library URIs, no nested generics).
  final List<String>? typeArgs;

  @override
  bool operator ==(Object other) =>
      other is MethodCallNode &&
      other.receiver == receiver &&
      other.name == name &&
      _listEquals(other.args, args) &&
      _listEquals(other.typeArgs, typeArgs);

  @override
  int get hashCode => Object.hash(
        receiver,
        name,
        Object.hashAll(args),
        typeArgs == null ? null : Object.hashAll(typeArgs!),
      );

  @override
  String toString() => 'MethodCallNode(${receiver ?? 'null'}.$name(${args.length} args))';
}

/// Value-type constructor invocation: `name(args)`. Resolved at runtime via
/// Runtime.invokeValueBuilder(name, args). Used for non-Widget value classes
/// like EdgeInsets, BoxDecoration, Color when not const-folded.
///
/// [typeArgs] carries explicit generic type arguments of the constructor, e.g.
/// `List<MyType>()` → `typeArgs: ['MyType']`. `null` means no explicit type
/// args were present in source. Builders that don't care about generics may
/// ignore this. If the IR ctor invocation carried generic type args, they
/// appear in `args` under the reserved key `__typeArgs__` as a `List<String>`
/// of simple type names when passed to a registered [SduiValueBuilder].
final class ValueCtorNode extends IrNode {
  const ValueCtorNode({
    required this.name,
    required this.args,
    this.typeArgs,
  });

  /// Qualified constructor name, e.g. `'EdgeInsets.all'`, `'BoxDecoration'`.
  final String name;
  final List<IrNode> args;

  /// Explicit generic type arguments, or `null` if none. Simple names only
  /// (no library URIs, no nested generics). E.g. `['MyType']`, `['String', 'int']`.
  final List<String>? typeArgs;

  @override
  bool operator ==(Object other) =>
      other is ValueCtorNode &&
      other.name == name &&
      _listEquals(other.args, args) &&
      _listEquals(other.typeArgs, typeArgs);

  @override
  int get hashCode => Object.hash(
        name,
        Object.hashAll(args),
        typeArgs == null ? null : Object.hashAll(typeArgs!),
      );

  @override
  String toString() => typeArgs != null
      ? 'ValueCtorNode($name<${typeArgs!.join(', ')}>(${args.length} args))'
      : 'ValueCtorNode($name(${args.length} args))';
}

// ─────────────────────────── statement nodes ────────────────────────────

/// A sequence of statements executed in order. Execution stops early if any
/// statement yields a non-[FlowNormal] control-flow signal. Introduces a
/// nested lexical scope: bindings added by [LetStatementNode]s inside the
/// block are visible only within this block (the resolver clones env on entry
/// and discards the clone on exit).
final class BlockNode extends StatementNode {
  const BlockNode({required this.statements});
  final List<IrNode> statements;

  @override
  bool operator ==(Object other) =>
      other is BlockNode && _listEquals(other.statements, statements);
  @override
  int get hashCode => Object.hashAll(statements);
  @override
  String toString() => 'BlockNode(${statements.length} stmts)';
}

/// `if (cond) then [else else_]` — statement form. Evaluates [cond] as a
/// boolean expression; if true, executes [then]; if false and [else_] is
/// non-null, executes [else_]; otherwise returns [FlowNormal].
final class IfStatementNode extends StatementNode {
  const IfStatementNode({
    required this.cond,
    required this.then,
    this.else_,
  });
  final IrNode cond;

  /// The then-branch. Typed as [IrNode] (NOT [BlockNode]) because bare
  /// `if (x) return y;` (no braces) lowers to a non-Block branch — typically
  /// a single [ReturnNode] or expression-statement. Curly-brace bodies still
  /// nest a [BlockNode] here.
  final IrNode then;

  /// The else-branch. Same typing rationale as [then]: bare `else return y;`
  /// lowers to a non-Block branch; `else { ... }` nests a [BlockNode];
  /// `else if (...)` nests another [IfStatementNode].
  final IrNode? else_;

  @override
  bool operator ==(Object other) =>
      other is IfStatementNode &&
      other.cond == cond &&
      other.then == then &&
      other.else_ == else_;
  @override
  int get hashCode => Object.hash(cond, then, else_);
  @override
  String toString() => 'IfStatementNode($cond ? $then : $else_)';
}

/// `break;` — signals [FlowBreak] to the enclosing loop. Labeled break is not
/// supported (rejected by the lowerer with a diagnostic).
final class BreakNode extends StatementNode {
  const BreakNode();

  @override
  bool operator ==(Object other) => other is BreakNode;
  @override
  int get hashCode => runtimeType.hashCode;
  @override
  String toString() => 'BreakNode()';
}

/// `continue;` — signals [FlowContinue] to the enclosing loop. Labeled
/// continue is not supported (rejected by the lowerer with a diagnostic).
final class ContinueNode extends StatementNode {
  const ContinueNode();

  @override
  bool operator ==(Object other) => other is ContinueNode;
  @override
  int get hashCode => runtimeType.hashCode;
  @override
  String toString() => 'ContinueNode()';
}

/// `return [value];` — signals [FlowReturn] to the enclosing function entry.
/// [value] is null for bare `return;`.
final class ReturnNode extends StatementNode {
  const ReturnNode({this.value});
  final IrNode? value;

  @override
  bool operator ==(Object other) =>
      other is ReturnNode && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'ReturnNode($value)';
}

/// Declares a new local variable binding at statement position. Inserts
/// `name → Cell(value)` into the current scope's env. Scoping is enforced by
/// [BlockNode]'s clone-env-on-entry / discard-on-exit strategy.
///
/// [isFinal] is informational (the lowerer enforces it at codegen time;
/// the resolver does not re-check).
final class LetStatementNode extends StatementNode {
  const LetStatementNode({
    required this.name,
    required this.value,
    required this.isFinal,
  });
  final String name;
  final IrNode value;
  final bool isFinal;

  @override
  bool operator ==(Object other) =>
      other is LetStatementNode &&
      other.name == name &&
      other.value == value &&
      other.isFinal == isFinal;
  @override
  int get hashCode => Object.hash(name, value, isFinal);
  @override
  String toString() =>
      'LetStatementNode(${isFinal ? 'final' : 'var'} $name = $value)';
}

/// `while (condition) body` — loop form. Condition is evaluated before each
/// iteration; if false initially, body never runs. [FlowBreak] exits the loop;
/// [FlowContinue] re-evaluates the condition; [FlowReturn] propagates up.
final class WhileNode extends StatementNode {
  const WhileNode({required this.condition, required this.body});
  final IrNode condition;
  final IrNode body; // typically BlockNode

  @override
  bool operator ==(Object other) =>
      other is WhileNode &&
      other.condition == condition &&
      other.body == body;
  @override
  int get hashCode => Object.hash(condition, body);
  @override
  String toString() => 'WhileNode($condition)';
}

/// `do { body } while (condition);` — loop form. Body runs at least once;
/// condition is evaluated after each iteration. Same flow-signal semantics as
/// [WhileNode].
final class DoNode extends StatementNode {
  const DoNode({required this.body, required this.condition});
  final IrNode body;
  final IrNode condition;

  @override
  bool operator ==(Object other) =>
      other is DoNode &&
      other.body == body &&
      other.condition == condition;
  @override
  int get hashCode => Object.hash(body, condition);
  @override
  String toString() => 'DoNode($condition)';
}

/// C-style `for (init; condition; update) body`. Distinct from collection-for
/// ([ForNode]), which stays sugar over `for (x in xs)`.
///
/// [init] is typically a [LetStatementNode] introducing the loop variable.
/// [condition] is null for an infinite loop (`for (;;)`).
/// [update] is an expression evaluated (discarded) after each body execution.
///
/// [ImperativeForNode] introduces a fresh scope for the loop variable — like
/// Dart's `for (int i = 0; ...; ...)` where `i` is block-scoped to the loop.
final class ImperativeForNode extends StatementNode {
  const ImperativeForNode({
    this.init,
    this.condition,
    this.update,
    required this.body,
  });
  final IrNode? init;       // LetStatementNode or expression-statement
  final IrNode? condition;  // null = infinite loop until break
  final IrNode? update;     // expression evaluated after each iteration
  final IrNode body;

  @override
  bool operator ==(Object other) =>
      other is ImperativeForNode &&
      other.init == init &&
      other.condition == condition &&
      other.update == update &&
      other.body == body;
  @override
  int get hashCode => Object.hash(init, condition, update, body);
  @override
  String toString() => 'ImperativeForNode($init; $condition; $update)';
}

// ────────────────────────── payload function nodes ──────────────────────────

/// A payload-private function declaration. Lives in a per-file local function
/// table (a [ScreenWithFunctionsNode]); never registered globally. Call sites
/// use [PayloadFunctionCallNode].
final class PayloadFunctionNode extends IrNode {
  const PayloadFunctionNode({
    required this.name,
    required this.params,
    required this.body,
  });
  final String name;
  final List<String> params;
  final IrNode body; // BlockNode or expression

  @override
  bool operator ==(Object other) =>
      other is PayloadFunctionNode &&
      other.name == name &&
      _listEquals(other.params, params) &&
      other.body == body;
  @override
  int get hashCode => Object.hash(name, Object.hashAll(params), body);
  @override
  String toString() =>
      'PayloadFunctionNode($name(${params.join(", ")}) => $body)';
}

/// Calls a payload-private function declared in the same file.
final class PayloadFunctionCallNode extends ExpressionNode {
  const PayloadFunctionCallNode({required this.name, required this.args});
  final String name;
  final List<IrNode> args;

  @override
  bool operator ==(Object other) =>
      other is PayloadFunctionCallNode &&
      other.name == name &&
      _listEquals(other.args, args);
  @override
  int get hashCode => Object.hash(name, Object.hashAll(args));
  @override
  String toString() => 'PayloadFunctionCallNode($name(${args.length} args))';
}

/// Wraps a screen body alongside its payload function declarations. Used as
/// the top-level root of a screen [IrTree] when the screen file defines one
/// or more top-level payload functions. The runtime entry builds a function
/// table from [functions] before resolving [screenBody].
final class ScreenWithFunctionsNode extends IrNode {
  const ScreenWithFunctionsNode({
    required this.functions,
    required this.screenBody,
  });
  final List<PayloadFunctionNode> functions;
  final IrNode screenBody; // IrStatefulNode, BlockNode, or expression

  @override
  bool operator ==(Object other) =>
      other is ScreenWithFunctionsNode &&
      _listEquals(other.functions, functions) &&
      other.screenBody == screenBody;
  @override
  int get hashCode => Object.hash(Object.hashAll(functions), screenBody);
  @override
  String toString() =>
      'ScreenWithFunctionsNode(${functions.length} fns, $screenBody)';
}

// ────────────────────────── screen-state nodes ──────────────────────────

/// A screen whose body owns mutable cross-build state. Generated as a
/// StatefulWidget + State<>. [fields] are initialized once in `initState`;
/// every subsequent build resolves [body] against an env that includes
/// the field cells merged with the VM inputs.
///
/// Only `var`-declared root-level locals in a `@Screen` body produce an
/// [IrStatefulNode]; `final` locals lower to [LetNode] (per-build derivation).
///
/// [id] is a stable, codegen-emitted identifier (per-screen unique). The
/// runtime host uses it as the `ValueKey` for the State<> so Flutter
/// element-reuse assigns cell state by IR identity, not by sibling position.
/// Without a stable key, two sibling stateful subscreens (or a conditional
/// swap pattern via AnimatedSwitcher / `if`) would mis-assign state. `null`
/// is tolerated by the runtime (it falls back to `ObjectKey(node)` for
/// reference identity), but every IR produced by the lowerer should carry
/// one.
final class IrStatefulNode extends IrNode {
  const IrStatefulNode({
    required this.fields,
    required this.body,
    this.id,
  });
  final List<IrStatefulFieldNode> fields;
  final IrNode body;
  final String? id;

  @override
  bool operator ==(Object other) =>
      other is IrStatefulNode &&
      other.id == id &&
      _listEquals(other.fields, fields) &&
      other.body == body;
  @override
  int get hashCode => Object.hash(id, Object.hashAll(fields), body);
  @override
  String toString() =>
      'IrStatefulNode(${id ?? "<no-id>"}, ${fields.length} fields)';
}

/// One field in an [IrStatefulNode]. The [initializer] is evaluated once in
/// `initState` against the VM inputs and previously-initialized fields
/// (declaration order). [isFinal] is informational — the lowerer enforces it
/// by excluding `final` vars from the stateful-field run.
final class IrStatefulFieldNode extends IrNode {
  const IrStatefulFieldNode({
    required this.name,
    required this.initializer,
    required this.isFinal,
  });
  final String name;
  final IrNode initializer;
  final bool isFinal;

  @override
  bool operator ==(Object other) =>
      other is IrStatefulFieldNode &&
      other.name == name &&
      other.initializer == initializer &&
      other.isFinal == isFinal;
  @override
  int get hashCode => Object.hash(name, initializer, isFinal);
  @override
  String toString() =>
      'IrStatefulFieldNode(${isFinal ? 'final' : 'var'} $name)';
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
