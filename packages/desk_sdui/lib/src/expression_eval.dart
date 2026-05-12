import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';
import 'cell.dart';
import 'ref_resolver.dart';
import 'runtime.dart';

/// Public entry point. Converts [input] to the internal cell-backed env and
/// delegates to [evalExpressionWithEnv].
Object? evalExpression(
  IrNode node,
  Map<String, Object?> input,
  Runtime runtime,
) {
  return evalExpressionWithEnv(node, toEnv(input), runtime);
}

/// Internal evaluator. [env] is a mutable cell-backed environment; only
/// this function and trusted internal callers (resolve.dart action sequence
/// runner) should call this directly.
Object? evalExpressionWithEnv(
  IrNode node,
  Map<String, Cell> env,
  Runtime runtime,
) {
  switch (node) {
    case LiteralNode(:final value):
      return value;
    case ConstNode(:final value):
      return value;
    case RefNode(:final path):
      return resolveFlutterRef(path, _unwrapEnv(env), runtime);

    case CompareOpNode(:final op, :final left, :final right):
      final l = evalExpressionWithEnv(left, env, runtime);
      final r = evalExpressionWithEnv(right, env, runtime);
      return switch (op) {
        CompareOp.eq => l == r,
        CompareOp.neq => l != r,
        CompareOp.lt => (l! as num) < (r! as num),
        CompareOp.lte => (l! as num) <= (r! as num),
        CompareOp.gt => (l! as num) > (r! as num),
        CompareOp.gte => (l! as num) >= (r! as num),
      };

    case ArithOpNode(:final op, :final left, :final right):
      final l = evalExpressionWithEnv(left, env, runtime)! as num;
      final r = evalExpressionWithEnv(right, env, runtime)! as num;
      return switch (op) {
        ArithOp.add => l + r,
        ArithOp.sub => l - r,
        ArithOp.mul => l * r,
        ArithOp.div => l / r,
        ArithOp.mod => l % r,
        ArithOp.intDiv => l ~/ r,
      };

    case LogicOpNode(:final op, :final left, :final right):
      final l = evalExpressionWithEnv(left, env, runtime)! as bool;
      return switch (op) {
        LogicOp.and =>
          l && (evalExpressionWithEnv(right, env, runtime)! as bool),
        LogicOp.or =>
          l || (evalExpressionWithEnv(right, env, runtime)! as bool),
      };

    case NotOpNode(:final operand):
      return !(evalExpressionWithEnv(operand, env, runtime)! as bool);

    case CoalesceOpNode(:final left, :final right):
      final l = evalExpressionWithEnv(left, env, runtime);
      return l ?? evalExpressionWithEnv(right, env, runtime);

    case GetterNode(:final receiver, :final name):
      final r = evalExpressionWithEnv(receiver, env, runtime);
      final handler = runtime.resolveGetter(name);
      if (handler != null) return handler(r);
      throw StateError(
        'No getter registered for "$name" (receiver: ${r.runtimeType})',
      );

    case LetNode(:final name, :final value, :final body):
      final v = evalExpressionWithEnv(value, env, runtime);
      return evalExpressionWithEnv(body, {...env, name: Cell(v)}, runtime);

    case AssignNode(:final name, :final value):
      final cell = env[name];
      if (cell == null) {
        throw StateError(
          'AssignNode: no binding for "$name" (lowerer bug — should have rejected)',
        );
      }
      final v = evalExpressionWithEnv(value, env, runtime);
      cell.value = v;
      return v;

    case SequenceNode(:final steps, :final returnExpr):
      for (final step in steps) {
        evalExpressionWithEnv(step, env, runtime);
        // Side effect: step is a method call on the receiver. Return value ignored.
      }
      return evalExpressionWithEnv(returnExpr, env, runtime);

    case MethodCallNode(:final receiver, :final name, :final args):
      if (receiver == null) {
        if (!runtime.hasFunction(name)) {
          throw StateError('Function "$name" not registered.');
        }
        final resolvedArgs = <String, Object?>{};
        for (var i = 0; i < args.length; i++) {
          resolvedArgs['arg$i'] = evalExpressionWithEnv(args[i], env, runtime);
        }
        return runtime.invokeFunction(name, resolvedArgs);
      }
      final resolvedReceiver = evalExpressionWithEnv(receiver, env, runtime);
      final resolvedArgs = <String, Object?>{};
      for (var i = 0; i < args.length; i++) {
        resolvedArgs['arg$i'] = evalExpressionWithEnv(args[i], env, runtime);
      }
      final handler = runtime.resolveMethodHandler(name);
      if (handler == null) {
        throw StateError(
          'Method "$name" not registered in runtime. '
          'Register it via registerMethod() or core_accessors.',
        );
      }
      return handler(resolvedReceiver, resolvedArgs);

    case LambdaNode(:final params, :final body, :final isAsync):
      // Lambdas capture the current env (Map<String, Cell>). Because cells are
      // mutable objects, lambdas see live values of mutable bindings at call time.
      final capturedEnv = env;
      if (!isAsync) {
        if (params.isEmpty) {
          return () => evalExpressionWithEnv(body, capturedEnv, runtime);
        }
        if (params.length == 1) {
          return (Object? a0) => evalExpressionWithEnv(
                body,
                {...capturedEnv, params[0]: Cell(a0)},
                runtime,
              );
        }
        if (params.length == 2) {
          return (Object? a0, Object? a1) => evalExpressionWithEnv(
                body,
                {
                  ...capturedEnv,
                  params[0]: Cell(a0),
                  params[1]: Cell(a1),
                },
                runtime,
              );
        }
        // >2 params: variadic fallback via List.
        return (List<Object?> args) {
          var lambdaEnv = capturedEnv;
          for (var i = 0; i < params.length; i++) {
            lambdaEnv = {...lambdaEnv, params[i]: Cell(args[i])};
          }
          return evalExpressionWithEnv(body, lambdaEnv, runtime);
        };
      }
      // Async path: closures return Future<Object?>. Only valid in action
      // context; the lowerer already rejected production outside
      // ActionSequenceNode bodies.
      if (params.isEmpty) {
        return () async => evalExpressionWithEnv(body, capturedEnv, runtime);
      }
      if (params.length == 1) {
        return (Object? a0) async => evalExpressionWithEnv(
              body,
              {...capturedEnv, params[0]: Cell(a0)},
              runtime,
            );
      }
      if (params.length == 2) {
        return (Object? a0, Object? a1) async => evalExpressionWithEnv(
              body,
              {...capturedEnv, params[0]: Cell(a0), params[1]: Cell(a1)},
              runtime,
            );
      }
      throw StateError('LambdaNode: only 0-2 params supported for async');

    case MemberAccessNode(:final target, :final name):
      final t = evalExpressionWithEnv(target, env, runtime);
      if (t is Map) return t[name];
      throw StateError('MemberAccess on non-map ${t.runtimeType}');

    case IndexAccessNode(:final target, :final key):
      final t = evalExpressionWithEnv(target, env, runtime);
      final k = evalExpressionWithEnv(key, env, runtime);
      if (t is List) return t[k! as int];
      if (t is Map) return t[k];
      // Handle MaterialColor indexing (e.g., Colors.grey[300])
      if (t is MaterialColor && k is int) {
        return t[k];
      }
      throw StateError('IndexAccess on ${t.runtimeType}');

    case LengthOfNode(:final target):
      final t = evalExpressionWithEnv(target, env, runtime);
      if (t is String) return t.length;
      if (t is List) return t.length;
      if (t is Map) return t.length;
      throw StateError('LengthOf on ${t.runtimeType}');

    case IsNullCheckNode(:final operand):
      return evalExpressionWithEnv(operand, env, runtime) == null;

    case IsTypeNode(:final receiver, :final typeName):
      final r = evalExpressionWithEnv(receiver, env, runtime);
      return runtime.checkType(typeName, r);

    case StringInterpNode(:final parts):
      final buf = StringBuffer();
      for (final p in parts) {
        if (p is String) {
          buf.write(p);
        } else if (p is IrNode) {
          buf.write(evalExpressionWithEnv(p, env, runtime) ?? '');
        }
      }
      return buf.toString();

    default:
      throw StateError('evalExpression: unsupported node $node');
  }
}

/// Unwraps a `Map<String, Cell>` env to `Map<String, Object?>` for callers
/// that need the raw value map (e.g., `resolveFlutterRef`).
Map<String, Object?> _unwrapEnv(Map<String, Cell> env) {
  return {for (final e in env.entries) e.key: e.value.value};
}
