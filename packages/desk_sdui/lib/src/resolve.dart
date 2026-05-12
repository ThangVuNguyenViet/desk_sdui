import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'cell.dart';
import 'expression_eval.dart';
import 'ref_resolver.dart';
import 'runtime.dart';

/// Resolves an IR node to a Widget. May recurse.
Widget resolveNode(
  BuildContext context,
  IrNode node,
  Map<String, Object?> input,
  Runtime runtime,
) {
  switch (node) {
    case IrStatefulNode():
      // Stable key so Flutter element-reuse assigns the State<> by IR
      // identity (the lowerer-emitted `id`, typically the screen name)
      // rather than by sibling position. Without this, two stateful sibling
      // subscreens — or an AnimatedSwitcher / conditional that swaps two
      // stateful subtrees at the same position — would mis-assign cell
      // state. Falls back to `ObjectKey(node)` when the IR carries no `id`
      // (legacy/hand-written IR); reference identity is still correct,
      // it just isn't JSON-codec stable.
      final key = node.id != null ? ValueKey<String>(node.id!) : ObjectKey(node);
      return _StatefulIrHost(
        key: key,
        node: node,
        input: input,
        runtime: runtime,
      );

    case ConstNode(:final value):
      if (value is Widget) return value;
      throw StateError('ConstNode at widget position must hold a Widget');

    case WidgetNode(
        :final name,
        :final args,
        :final key,
        :final listenablePaths,
        :final typeArgs,
      ):
      if (listenablePaths.isNotEmpty) {
        return _resolveReactiveWidget(
          context,
          name,
          args,
          key,
          listenablePaths,
          input,
          runtime,
          typeArgs: typeArgs,
        );
      }
      return _buildWidget(context, name, args, key, input, runtime, typeArgs: typeArgs);

    case BuiltinWidgetNode(:final name, :final args, :final key):
      return _buildWidget(context, name, args, key, input, runtime);

    case ConditionalNode(
        :final condition,
        :final thenBranch,
        :final elseBranch,
      ):
      final cond = evalExpression(condition, input, runtime);
      if (cond == true) {
        return _resolveBranch(context, thenBranch, input, runtime);
      }
      if (elseBranch != null) {
        return _resolveBranch(context, elseBranch, input, runtime);
      }
      return const SizedBox.shrink();

    case SpreadNode(:final source):
      return _resolveBranch(context, source, input, runtime);

    case LetNode(:final name, :final value, :final body):
      final v = evalExpression(value, input, runtime);
      return resolveNode(context, body, {...input, name: v}, runtime);

    case LiteralNode(:final value):
      if (value is Widget) return value;
      throw StateError(
        'LiteralNode at widget position holds non-widget $value',
      );

    case BlockNode():
      // Execute the block's statements over a cell-backed copy of `input`
      // until a ReturnNode produces a widget IrNode, then recurse into
      // resolveNode on that IR. The runtime uses `executeStatement` for
      // side-effecting statements (LetStatementNode, AssignNode-as-stmt,
      // IfStatementNode, etc.) and intercepts the terminating `FlowReturn`.
      return _resolveBlockAtWidgetPosition(context, node, input, runtime);

    default:
      throw StateError('resolveNode: $node not valid at widget position');
  }
}

/// Resolves a [BlockNode] root by running [executeStatement] until a
/// [FlowReturn] is produced; the returned value is expected to be an
/// [IrNode] (the widget IR from a `return <widget>;` statement) which is
/// then resolved as a widget via [resolveNode].
///
/// Special cases:
/// - [FlowNormal] (fell off the end without returning) → StateError.
/// - [FlowBreak] / [FlowContinue] at the root → StateError.
/// - [FlowReturn] with a non-IrNode payload → StateError.
///
/// The block's return-expression is NOT evaluated as a value (it's a widget
/// constructor IrNode); instead we recurse via [resolveNode] on the raw IR.
/// This requires special handling: we walk statements directly here rather
/// than calling the generic [executeStatement] (which would try to
/// evaluate the return-value IR as an expression). We delegate to
/// [executeStatement] for non-ReturnNode statements so all the
/// scope/control-flow semantics live in one place.
Widget _resolveBlockAtWidgetPosition(
  BuildContext context,
  BlockNode node,
  Map<String, Object?> input,
  Runtime runtime,
) {
  // Cell-backed shallow-copy of input, scoped to this block.
  final env = toEnv(input);
  for (final stmt in node.statements) {
    if (stmt is ReturnNode) {
      final value = stmt.value;
      if (value == null) {
        throw StateError(
          'BlockNode at widget position: bare `return;` not allowed — '
          'every screen path must `return <widget>;`',
        );
      }
      // Render the returned widget IR using the current env's value map.
      return resolveNode(context, value, _envToInput(env), runtime);
    }
    if (stmt is BreakNode) {
      throw StateError(
        'BlockNode at widget position: `break` at screen root is illegal.',
      );
    }
    if (stmt is ContinueNode) {
      throw StateError(
        'BlockNode at widget position: `continue` at screen root is illegal.',
      );
    }
    if (stmt is IfStatementNode) {
      // If-statement at widget position: an early-return branch must yield a
      // widget; the falling-through branch continues the block.
      final maybe = _resolveIfAtWidgetPosition(context, stmt, env, runtime);
      if (maybe != null) return maybe;
      continue;
    }
    // Side-effecting statement (LetStatementNode, AssignNode-as-statement,
    // nested BlockNode, etc.): delegate to executeStatement and observe its
    // control-flow signal.
    final flow = executeStatement(stmt, env, runtime);
    switch (flow) {
      case FlowNormal():
        continue;
      case FlowReturn(:final value):
        if (value is! IrNode) {
          throw StateError(
            'BlockNode at widget position: return value must be a widget '
            'IrNode (got ${value.runtimeType}).',
          );
        }
        return resolveNode(context, value, _envToInput(env), runtime);
      case FlowBreak():
        throw StateError(
          'BlockNode at widget position: `break` at screen root is illegal.',
        );
      case FlowContinue():
        throw StateError(
          'BlockNode at widget position: `continue` at screen root is illegal.',
        );
    }
  }
  throw StateError(
    'BlockNode at widget position fell through without a return — '
    'every code path must `return <widget>;`',
  );
}

/// Handles an [IfStatementNode] at widget position. If a branch terminates
/// with a `return <widget>;`, returns the resolved widget. Otherwise returns
/// null (the if-statement was a no-op for widget production; the enclosing
/// block continues to the next statement).
Widget? _resolveIfAtWidgetPosition(
  BuildContext context,
  IfStatementNode node,
  Map<String, Cell> env,
  Runtime runtime,
) {
  final c = evalExpressionWithEnv(node.cond, env, runtime);
  final branch = (c == true) ? node.then : node.else_;
  if (branch == null) return null;
  return _resolveStatementBranchAtWidgetPosition(context, branch, env, runtime);
}

/// Resolves a statement-branch (a `then`/`else_` body of an [IfStatementNode])
/// that *may* return a widget. Returns the widget if a `return <widget>;` is
/// hit; returns null if the branch fell through normally.
Widget? _resolveStatementBranchAtWidgetPosition(
  BuildContext context,
  IrNode branch,
  Map<String, Cell> env,
  Runtime runtime,
) {
  if (branch is ReturnNode) {
    final value = branch.value;
    if (value == null) {
      throw StateError(
        'BlockNode at widget position: bare `return;` not allowed — '
        'every screen path must `return <widget>;`',
      );
    }
    return resolveNode(context, value, _envToInput(env), runtime);
  }
  if (branch is BlockNode) {
    // Walk the nested block with a fresh scoped env clone.
    final scoped = Map<String, Cell>.of(env);
    for (final s in branch.statements) {
      if (s is ReturnNode) {
        final value = s.value;
        if (value == null) {
          throw StateError(
            'BlockNode at widget position: bare `return;` not allowed.',
          );
        }
        return resolveNode(context, value, _envToInput(scoped), runtime);
      }
      if (s is IfStatementNode) {
        final maybe = _resolveIfAtWidgetPosition(context, s, scoped, runtime);
        if (maybe != null) return maybe;
        continue;
      }
      if (s is BreakNode || s is ContinueNode) {
        throw StateError(
          'BlockNode at widget position: `break`/`continue` at screen root is illegal.',
        );
      }
      final flow = executeStatement(s, scoped, runtime);
      switch (flow) {
        case FlowNormal():
          continue;
        case FlowReturn(:final value):
          if (value is! IrNode) {
            throw StateError(
              'BlockNode at widget position: return value must be a widget '
              'IrNode (got ${value.runtimeType}).',
            );
          }
          return resolveNode(context, value, _envToInput(scoped), runtime);
        case FlowBreak():
        case FlowContinue():
          throw StateError(
            'BlockNode at widget position: `break`/`continue` at screen root is illegal.',
          );
      }
    }
    return null; // fell through
  }
  // Single-statement branch (e.g. `if (cond) someCall();`): delegate to
  // executeStatement; only FlowReturn produces a widget here.
  final flow = executeStatement(branch, env, runtime);
  switch (flow) {
    case FlowNormal():
      return null;
    case FlowReturn(:final value):
      if (value is! IrNode) {
        throw StateError(
          'BlockNode at widget position: return value must be a widget '
          'IrNode (got ${value.runtimeType}).',
        );
      }
      return resolveNode(context, value, _envToInput(env), runtime);
    case FlowBreak():
    case FlowContinue():
      throw StateError(
        'BlockNode at widget position: `break`/`continue` at screen root is illegal.',
      );
  }
}

/// Converts a cell-backed env to a value map for callers that take
/// `Map<String, Object?>` inputs (e.g. [resolveNode]).
Map<String, Object?> _envToInput(Map<String, Cell> env) {
  return {for (final e in env.entries) e.key: e.value.value};
}

/// Resolves a non-widget argument (any IrNode used as a property value).
Object? _resolveArg(
  BuildContext context,
  IrNode node,
  Map<String, Object?> input,
  Runtime runtime,
) {
  switch (node) {
    case IrStatefulNode():
      // A nested stateful subscreen used as a widget-position child. Route
      // through resolveNode so the [_StatefulIrHost] keying applies even
      // here (sibling subscreens via composed `Pair(top: stateful, bottom:
      // stateful)` etc.).
      return resolveNode(context, node, input, runtime);
    case LiteralNode(:final value):
      return value;
    case ConstNode(:final value):
      return value;
    case RefNode(:final path):
      return resolveFlutterRef(path, input, runtime);

    case ListNode(:final children):
      final out = <Object?>[];
      for (final child in children) {
        if (child is SpreadNode) {
          final spread = _resolveArg(context, child.source, input, runtime);
          if (spread is List) {
            out.addAll(spread);
          } else {
            throw StateError('SpreadNode source did not resolve to List');
          }
        } else if (child is WidgetNode ||
            child is BuiltinWidgetNode ||
            child is ConstNode) {
          out.add(resolveNode(context, child, input, runtime));
        } else if (child is ForNode) {
          out.addAll(_expandFor(context, child, input, runtime));
        } else if (child is ConditionalNode) {
          final cond = evalExpression(child.condition, input, runtime);
          if (cond == true) {
            out.add(
              resolveNode(context, child.thenBranch, input, runtime),
            );
          } else if (child.elseBranch != null) {
            out.add(
              resolveNode(context, child.elseBranch!, input, runtime),
            );
          }
        } else {
          out.add(_resolveArg(context, child, input, runtime));
        }
      }
      return out;

    case MapNode(:final entries):
      return entries.map(
        (k, v) => MapEntry(
          _resolveArg(context, k, input, runtime),
          _resolveArg(context, v, input, runtime),
        ),
      );

    case ForNode():
      return _expandFor(context, node, input, runtime);

    case WidgetNode(:final name, :final args, :final typeArgs):
      final fn = runtime.fnFor(name);
      if (fn != null) {
        final fnArgs = <String, Object?>{};
        args.forEach((k, v) {
          fnArgs[k] = _resolveArg(context, v, input, runtime);
        });
        if (typeArgs != null) fnArgs['__typeArgs__'] = typeArgs;
        return Function.apply(fn, [fnArgs]);
      }
      // Qualified value-ctor names (e.g. `'EdgeInsets.only'`) are registered
      // via `registerValueBuilder`, not `registerWidget`. Try that path before
      // falling through to the widget resolver.
      final valueBuilder = runtime.resolveValueBuilder(name);
      if (valueBuilder != null) {
        final resolvedArgs = <String, Object?>{};
        args.forEach((k, v) {
          resolvedArgs[k] = _resolveArg(context, v, input, runtime);
        });
        if (typeArgs != null) resolvedArgs['__typeArgs__'] = typeArgs;
        return valueBuilder(resolvedArgs);
      }
      return resolveNode(context, node, input, runtime);
    case BuiltinWidgetNode(:final name, :final args):
      final fn = runtime.fnFor(name);
      if (fn != null) {
        final fnArgs = <String, Object?>{};
        args.forEach((k, v) {
          fnArgs[k] = _resolveArg(context, v, input, runtime);
        });
        return Function.apply(fn, [fnArgs]);
      }
      final valueBuilder = runtime.resolveValueBuilder(name);
      if (valueBuilder != null) {
        final resolvedArgs = <String, Object?>{};
        args.forEach((k, v) {
          resolvedArgs[k] = _resolveArg(context, v, input, runtime);
        });
        return valueBuilder(resolvedArgs);
      }
      return resolveNode(context, node, input, runtime);

    case MethodCallNode(:final receiver, :final name, :final args, :final typeArgs):
      if (receiver == null) {
        final resolvedArgs = <String, Object?>{};
        for (var i = 0; i < args.length; i++) {
          resolvedArgs['arg$i'] = _resolveArg(context, args[i], input, runtime);
        }
        if (typeArgs != null) resolvedArgs['__typeArgs__'] = typeArgs;
        return runtime.invokeFunction(name, resolvedArgs);
      }
      final resolvedReceiver = _resolveArg(context, receiver, input, runtime);
      final resolvedArgs = <String, Object?>{};
      for (var i = 0; i < args.length; i++) {
        resolvedArgs['arg$i'] = _resolveArg(context, args[i], input, runtime);
      }
      if (typeArgs != null) resolvedArgs['__typeArgs__'] = typeArgs;
      final handler = runtime.resolveMethodHandler(name);
      if (handler == null) {
        throw StateError(
          'Method "$name" not registered. '
          'Add it to a @Screen body or @Register annotation.',
        );
      }
      return handler(resolvedReceiver, resolvedArgs);

    case ValueCtorNode(:final name, :final args, :final typeArgs):
      final resolvedArgs = <String, Object?>{};
      for (var i = 0; i < args.length; i++) {
        resolvedArgs['arg$i'] = _resolveArg(context, args[i], input, runtime);
      }
      if (typeArgs != null) resolvedArgs['__typeArgs__'] = typeArgs;
      final builder = runtime.resolveValueBuilder(name);
      if (builder == null) {
        throw StateError(
          'Value constructor "$name" not registered. '
          'Add it to a @Screen body or @Register annotation.',
        );
      }
      return builder(resolvedArgs);

    case EventNode():
      return _bindEvent(node, input, runtime);

    case ActionSequenceNode(:final steps):
      final setStateHook = input[kStatefulSetStateKey];
      return () async {
        var localEnv = toEnv(input);
        for (final step in steps) {
          localEnv = await _runActionStep(step, localEnv, runtime);
        }
        if (setStateHook is void Function()) setStateHook();
      };

    default:
      return evalExpression(node, input, runtime);
  }
}

/// Runs one step of an [ActionSequenceNode] and returns the updated env.
///
/// Handles both [ActionStepNode] (plain call/await) and [TryStepNode]
/// (try/catch block). Throws [StateError] for unknown step kinds.
Future<Map<String, Cell>> _runActionStep(
  IrNode step,
  Map<String, Cell> env,
  Runtime runtime,
) async {
  if (step is ActionStepNode) {
    final result = evalExpressionWithEnv(step.call, env, runtime);
    final value = step.awaitResult && result is Future ? await result : result;
    if (step.bindResult != null) {
      return {...env, step.bindResult!: Cell(value)};
    }
    return env;
  }
  if (step is TryStepNode) {
    try {
      var e = env;
      for (final s in step.trySteps) {
        e = await _runActionStep(s, e, runtime);
      }
      // Try succeeded: return the try-branch env to the outer sequence.
      return e;
    } catch (err) {
      var e = step.exceptionBind != null
          ? {...env, step.exceptionBind!: Cell(err)}
          : env;
      for (final s in step.catchSteps) {
        e = await _runActionStep(s, e, runtime);
      }
      // Catch's local bindings don't leak to the outer scope.
      return env;
    }
  }
  throw StateError('Unknown action step kind: ${step.runtimeType}');
}

/// Resolves a branch (then/else/spread) which may be a single widget or a list.
Widget _resolveBranch(
  BuildContext context,
  IrNode node,
  Map<String, Object?> input,
  Runtime runtime,
) {
  if (node is ListNode) {
    if (node.children.isEmpty) return const SizedBox.shrink();
    if (node.children.length == 1) {
      return resolveNode(context, node.children.first, input, runtime);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: node.children
          .map((c) => resolveNode(context, c, input, runtime))
          .toList(),
    );
  }
  return resolveNode(context, node, input, runtime);
}

List<Object?> _expandFor(
  BuildContext context,
  ForNode node,
  Map<String, Object?> input,
  Runtime runtime,
) {
  final source = evalExpression(node.source, input, runtime);
  if (source is! Iterable) {
    throw StateError('ForNode source did not resolve to Iterable');
  }
  final out = <Object?>[];
  for (final raw in source) {
    final scoped = Map<String, Object?>.of(input);
    if (node.variables != null) {
      if (raw is Map) {
        scoped[node.variables![0]] = raw['first'];
        scoped[node.variables![1]] = raw['second'];
      } else {
        throw StateError(
          'ForNode.destructured requires Map<String, _> source items',
        );
      }
    } else {
      scoped[node.variable!] = raw;
    }
    out.add(_resolveArg(context, node.body, scoped, runtime));
  }
  return out;
}

Object? _bindEvent(
  EventNode node,
  Map<String, Object?> input,
  Runtime runtime,
) {
  // Check if it's a registered function first (e.g., BorderRadius.circular)
  final fnName = node.target.last;
  final fn = runtime.fnFor(fnName);
  if (fn != null) {
    final fnArgs = <String, Object?>{};
    node.args.forEach((k, v) {
      fnArgs[k] = evalExpression(v, input, runtime);
    });
    return Function.apply(fn, [fnArgs]);
  }

  final methods = input['__methods__'];
  if (methods is Map) {
    final key = node.target.join('.');
    final methodFn = methods[key];
    if (methodFn is Function) {
      if (node.args.isEmpty) return methodFn;
      final positional = <Object?>[];
      for (var i = 0;; i++) {
        final argKey = 'arg$i';
        if (!node.args.containsKey(argKey)) break;
        positional.add(evalExpression(node.args[argKey]!, input, runtime));
      }
      return () => Function.apply(methodFn, positional);
    }
  }
  throw StateError(
    'EventNode target ${node.target.join('.')} not bound',
  );
}

Widget _buildWidget(
  BuildContext context,
  String name,
  Map<String, IrNode> args,
  IrNode? key,
  Map<String, Object?> input,
  Runtime runtime, {
  List<String>? typeArgs,
}) {
  final builder = runtime.widgetFor(name);
  if (builder == null) {
    throw StateError('Widget "$name" is not registered');
  }
  final resolvedArgs = <String, Object?>{};
  args.forEach((k, v) {
    resolvedArgs[k] = _resolveArg(context, v, input, runtime);
  });
  if (key != null) {
    resolvedArgs['key'] = _resolveArg(context, key, input, runtime);
  }
  if (typeArgs != null) resolvedArgs['__typeArgs__'] = typeArgs;
  return builder(context, resolvedArgs);
}

Widget _resolveReactiveWidget(
  BuildContext context,
  String name,
  Map<String, IrNode> args,
  IrNode? key,
  Set<String> listenablePaths,
  Map<String, Object?> input,
  Runtime runtime, {
  List<String>? typeArgs,
}) {
  final reactiveMap = input['__reactive__'] as Map<String, Object?>?;
  if (reactiveMap == null) {
    throw StateError(
      'WidgetNode "$name" declares listenablePaths but input '
      'has no __reactive__ map',
    );
  }
  final listenables = <Listenable>[];
  for (final pathStr in listenablePaths) {
    final l = reactiveMap[pathStr];
    if (l is Listenable) listenables.add(l);
  }
  return ListenableBuilder(
    listenable: Listenable.merge(listenables),
    builder: (ctx, _) {
      final scopedInput = Map<String, Object?>.of(input);
      for (final pathStr in listenablePaths) {
        _installReactiveGetter(
          scopedInput,
          pathStr.split('.'),
          reactiveMap,
        );
      }
      return _buildWidget(ctx, name, args, key, scopedInput, runtime, typeArgs: typeArgs);
    },
  );
}

void _installReactiveGetter(
  Map<String, Object?> input,
  List<String> path,
  Map<String, Object?> reactiveMap,
) {
  final pathStr = path.join('.');
  final listenable = reactiveMap[pathStr];
  if (listenable is! ValueListenable) return;
  var cursor = input;
  for (var i = 0; i < path.length - 1; i++) {
    final next = cursor[path[i]];
    if (next is Map) {
      cursor = Map<String, Object?>.of(next.cast<String, Object?>());
      input[path[i]] = cursor;
    } else {
      final fresh = <String, Object?>{};
      cursor[path[i]] = fresh;
      cursor = fresh;
    }
  }
  final getters =
      (cursor['__getters__'] as Map?)?.cast<String, Object?>() ?? {};
  getters[path.last] = () => listenable.value;
  cursor['__getters__'] = getters;
}

/// Host widget for an [IrStatefulNode] — owns the field cells across builds
/// and rebuilds whenever an event handler invokes `setState`. The cells are
/// initialized once in [initState] using the field initializers; on every
/// subsequent build, the cells (as `Map<String, Cell>`) are merged into the
/// input env so the body sees their current values. Event handlers that
/// mutate any of those cells then trigger a rebuild via the [kStatefulSetStateKey]
/// callback installed in the input.
class _StatefulIrHost extends StatefulWidget {
  const _StatefulIrHost({
    super.key,
    required this.node,
    required this.input,
    required this.runtime,
  });

  final IrStatefulNode node;
  final Map<String, Object?> input;
  final Runtime runtime;

  @override
  State<_StatefulIrHost> createState() => _StatefulIrHostState();
}

class _StatefulIrHostState extends State<_StatefulIrHost> {
  late final Map<String, Cell> _stateCells;

  @override
  void initState() {
    super.initState();
    // Initialize each field's cell once, in declaration order. Each
    // initializer evaluates against an env that contains the original
    // VM inputs plus the previously-initialized fields.
    _stateCells = <String, Cell>{};
    final initEnv = toEnv(widget.input);
    for (final field in widget.node.fields) {
      final value = evalExpressionWithEnv(
        field.initializer,
        {...initEnv, ..._stateCells},
        widget.runtime,
      );
      _stateCells[field.name] = Cell(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Compose the per-build input: VM inputs + persistent state cells (under
    // `kStateCellsKey` — toEnv splices them in) + the setState hook event
    // handlers will invoke.
    final scopedInput = <String, Object?>{
      ...widget.input,
      // Expose each cell's current value at its name as well, so consumers
      // that only read the value map (without entering toEnv) still see it.
      for (final entry in _stateCells.entries) entry.key: entry.value.value,
      kStateCellsKey: _stateCells,
      kStatefulSetStateKey: _scheduleRebuild,
    };
    return resolveNode(context, widget.node.body, scopedInput, widget.runtime);
  }

  /// Called by event handlers (wrapped at resolve time) after they've run.
  /// Triggers a rebuild so the body re-resolves against the new cell values.
  void _scheduleRebuild() {
    if (!mounted) return;
    setState(() {});
  }
}
