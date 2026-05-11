import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
    case ConstNode(:final value):
      if (value is Widget) return value;
      throw StateError('ConstNode at widget position must hold a Widget');

    case WidgetNode(
        :final name,
        :final args,
        :final key,
        :final listenablePaths,
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
        );
      }
      return _buildWidget(context, name, args, key, input, runtime);

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

    case LiteralNode(:final value):
      if (value is Widget) return value;
      throw StateError(
        'LiteralNode at widget position holds non-widget $value',
      );

    default:
      throw StateError('resolveNode: $node not valid at widget position');
  }
}

/// Resolves a non-widget argument (any IrNode used as a property value).
Object? _resolveArg(
  BuildContext context,
  IrNode node,
  Map<String, Object?> input,
  Runtime runtime,
) {
  switch (node) {
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

    case WidgetNode(:final name, :final args):
    case BuiltinWidgetNode(:final name, :final args):
      final fn = runtime.fnFor(name);
      if (fn != null) {
        final fnArgs = <String, Object?>{};
        args.forEach((k, v) {
          fnArgs[k] = _resolveArg(context, v, input, runtime);
        });
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
        return valueBuilder(resolvedArgs);
      }
      return resolveNode(context, node, input, runtime);

    case MethodCallNode(:final receiver, :final name, :final args):
      final resolvedReceiver = _resolveArg(context, receiver, input, runtime);
      final resolvedArgs = <String, Object?>{};
      for (var i = 0; i < args.length; i++) {
        resolvedArgs['arg$i'] = _resolveArg(context, args[i], input, runtime);
      }
      final handler = runtime.resolveMethodHandler(name);
      if (handler == null) {
        throw StateError(
          'Method "$name" not registered. '
          'Add it to a @Screen body or @Register annotation.',
        );
      }
      return handler(resolvedReceiver, resolvedArgs);

    case ValueCtorNode(:final name, :final args):
      final resolvedArgs = <String, Object?>{};
      for (var i = 0; i < args.length; i++) {
        resolvedArgs['arg$i'] = _resolveArg(context, args[i], input, runtime);
      }
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

    default:
      return evalExpression(node, input, runtime);
  }
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
  Runtime runtime,
) {
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
  return builder(context, resolvedArgs);
}

Widget _resolveReactiveWidget(
  BuildContext context,
  String name,
  Map<String, IrNode> args,
  IrNode? key,
  Set<String> listenablePaths,
  Map<String, Object?> input,
  Runtime runtime,
) {
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
      return _buildWidget(ctx, name, args, key, scopedInput, runtime);
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
