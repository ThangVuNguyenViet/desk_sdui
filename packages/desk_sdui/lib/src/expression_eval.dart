import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';
import 'ref_resolver.dart';
import 'runtime.dart';

Object? evalExpression(
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

    case CompareOpNode(:final op, :final left, :final right):
      final l = evalExpression(left, input, runtime);
      final r = evalExpression(right, input, runtime);
      return switch (op) {
        CompareOp.eq => l == r,
        CompareOp.neq => l != r,
        CompareOp.lt => (l! as num) < (r! as num),
        CompareOp.lte => (l! as num) <= (r! as num),
        CompareOp.gt => (l! as num) > (r! as num),
        CompareOp.gte => (l! as num) >= (r! as num),
      };

    case ArithOpNode(:final op, :final left, :final right):
      final l = evalExpression(left, input, runtime)! as num;
      final r = evalExpression(right, input, runtime)! as num;
      return switch (op) {
        ArithOp.add => l + r,
        ArithOp.sub => l - r,
        ArithOp.mul => l * r,
        ArithOp.div => l / r,
        ArithOp.mod => l % r,
        ArithOp.intDiv => l ~/ r,
      };

    case LogicOpNode(:final op, :final left, :final right):
      final l = evalExpression(left, input, runtime)! as bool;
      return switch (op) {
        LogicOp.and => l && (evalExpression(right, input, runtime)! as bool),
        LogicOp.or => l || (evalExpression(right, input, runtime)! as bool),
      };

    case NotOpNode(:final operand):
      return !(evalExpression(operand, input, runtime)! as bool);

    case CoalesceOpNode(:final left, :final right):
      final l = evalExpression(left, input, runtime);
      return l ?? evalExpression(right, input, runtime);

    case GetterNode(:final receiver, :final name):
      final r = evalExpression(receiver, input, runtime);
      final handler = runtime.resolveGetter(name);
      if (handler != null) return handler(r);
      throw StateError('No getter registered for "$name" (receiver: ${r.runtimeType})');

    case LetNode(:final name, :final value, :final body):
      final v = evalExpression(value, input, runtime);
      return evalExpression(body, {...input, name: v}, runtime);

    case SequenceNode(:final steps, :final returnExpr):
      for (final step in steps) {
        evalExpression(step, input, runtime);
        // Side effect: step is a method call on the receiver. Return value ignored.
      }
      return evalExpression(returnExpr, input, runtime);

    case MethodCallNode(:final receiver, :final name, :final args):
      if (receiver == null) {
        if (!runtime.hasFunction(name)) {
          throw StateError('Function "$name" not registered.');
        }
        final resolvedArgs = <String, Object?>{};
        for (var i = 0; i < args.length; i++) {
          resolvedArgs['arg$i'] = evalExpression(args[i], input, runtime);
        }
        return runtime.invokeFunction(name, resolvedArgs);
      }
      final resolvedReceiver = evalExpression(receiver, input, runtime);
      final resolvedArgs = <String, Object?>{};
      for (var i = 0; i < args.length; i++) {
        resolvedArgs['arg$i'] = evalExpression(args[i], input, runtime);
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
      if (!isAsync) {
        if (params.isEmpty) {
          return () => evalExpression(body, input, runtime);
        }
        if (params.length == 1) {
          return (Object? a0) =>
              evalExpression(body, {...input, params[0]: a0}, runtime);
        }
        if (params.length == 2) {
          return (Object? a0, Object? a1) => evalExpression(
                body,
                {...input, params[0]: a0, params[1]: a1},
                runtime,
              );
        }
        // >2 params: variadic fallback via List.
        return (List<Object?> args) {
          var env = input;
          for (var i = 0; i < params.length; i++) {
            env = {...env, params[i]: args[i]};
          }
          return evalExpression(body, env, runtime);
        };
      }
      // Async path: closures return Future<Object?>. Only valid in action
      // context; the lowerer already rejected production outside
      // ActionSequenceNode bodies.
      if (params.isEmpty) {
        return () async => evalExpression(body, input, runtime);
      }
      if (params.length == 1) {
        return (Object? a0) async =>
            evalExpression(body, {...input, params[0]: a0}, runtime);
      }
      if (params.length == 2) {
        return (Object? a0, Object? a1) async => evalExpression(
              body,
              {...input, params[0]: a0, params[1]: a1},
              runtime,
            );
      }
      throw StateError('LambdaNode: only 0-2 params supported for async');

    case MemberAccessNode(:final target, :final name):
      final t = evalExpression(target, input, runtime);
      if (t is Map) return t[name];
      throw StateError('MemberAccess on non-map ${t.runtimeType}');

    case IndexAccessNode(:final target, :final key):
      final t = evalExpression(target, input, runtime);
      final k = evalExpression(key, input, runtime);
      if (t is List) return t[k! as int];
      if (t is Map) return t[k];
      // Handle MaterialColor indexing (e.g., Colors.grey[300])
      if (t is MaterialColor && k is int) {
        return t[k];
      }
      throw StateError('IndexAccess on ${t.runtimeType}');

    case LengthOfNode(:final target):
      final t = evalExpression(target, input, runtime);
      if (t is String) return t.length;
      if (t is List) return t.length;
      if (t is Map) return t.length;
      throw StateError('LengthOf on ${t.runtimeType}');

    case IsNullCheckNode(:final operand):
      return evalExpression(operand, input, runtime) == null;

    case IsTypeNode(:final receiver, :final typeName):
      final r = evalExpression(receiver, input, runtime);
      return runtime.checkType(typeName, r);

    case StringInterpNode(:final parts):
      final buf = StringBuffer();
      for (final p in parts) {
        if (p is String) {
          buf.write(p);
        } else if (p is IrNode) {
          buf.write(evalExpression(p, input, runtime) ?? '');
        }
      }
      return buf.toString();

    case MethodCallNode(:final receiver, :final name, :final args):
      if (receiver == null) {
        final resolvedArgs = <String, Object?>{};
        for (var i = 0; i < args.length; i++) {
          resolvedArgs['arg$i'] = evalExpression(args[i], input, runtime);
        }
        return runtime.invokeFunction(name, resolvedArgs);
      }
      final resolvedReceiver = evalExpression(receiver, input, runtime);
      final resolvedArgs = <String, Object?>{};
      for (var i = 0; i < args.length; i++) {
        resolvedArgs['arg$i'] = evalExpression(args[i], input, runtime);
      }
      final handler = runtime.resolveMethodHandler(name);
      if (handler == null) {
        throw StateError(
          'Method "$name" not registered. '
          'Add it to a @Screen body or @Register annotation.',
        );
      }
      return handler(resolvedReceiver, resolvedArgs);

    default:
      throw StateError('evalExpression: unsupported node $node');
  }
}
