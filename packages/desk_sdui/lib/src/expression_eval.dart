import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';
import 'ref_resolver.dart';

Object? evalExpression(IrNode node, Map<String, Object?> input) {
  switch (node) {
    case LiteralNode(:final value):
      return value;
    case ConstNode(:final value):
      return value;
    case RefNode(:final path):
      return resolveFlutterRef(path, input);

    case CompareOpNode(:final op, :final left, :final right):
      final l = evalExpression(left, input);
      final r = evalExpression(right, input);
      return switch (op) {
        CompareOp.eq => l == r,
        CompareOp.neq => l != r,
        CompareOp.lt => (l! as num) < (r! as num),
        CompareOp.lte => (l! as num) <= (r! as num),
        CompareOp.gt => (l! as num) > (r! as num),
        CompareOp.gte => (l! as num) >= (r! as num),
      };

    case ArithOpNode(:final op, :final left, :final right):
      final l = evalExpression(left, input)! as num;
      final r = evalExpression(right, input)! as num;
      return switch (op) {
        ArithOp.add => l + r,
        ArithOp.sub => l - r,
        ArithOp.mul => l * r,
        ArithOp.div => l / r,
        ArithOp.mod => l % r,
      };

    case LogicOpNode(:final op, :final left, :final right):
      final l = evalExpression(left, input)! as bool;
      return switch (op) {
        LogicOp.and => l && (evalExpression(right, input)! as bool),
        LogicOp.or => l || (evalExpression(right, input)! as bool),
      };

    case NotOpNode(:final operand):
      return !(evalExpression(operand, input)! as bool);

    case CoalesceOpNode(:final left, :final right):
      final l = evalExpression(left, input);
      return l ?? evalExpression(right, input);

    case MemberAccessNode(:final target, :final name):
      final t = evalExpression(target, input);
      if (t is Map) return t[name];
      throw StateError('MemberAccess on non-map ${t.runtimeType}');

    case IndexAccessNode(:final target, :final key):
      final t = evalExpression(target, input);
      final k = evalExpression(key, input);
      if (t is List) return t[k! as int];
      if (t is Map) return t[k];
      // Handle MaterialColor indexing (e.g., Colors.grey[300])
      if (t is MaterialColor && k is int) {
        return t[k];
      }
      throw StateError('IndexAccess on ${t.runtimeType}');

    case LengthOfNode(:final target):
      final t = evalExpression(target, input);
      if (t is String) return t.length;
      if (t is List) return t.length;
      if (t is Map) return t.length;
      throw StateError('LengthOf on ${t.runtimeType}');

    case IsNullCheckNode(:final operand):
      return evalExpression(operand, input) == null;

    case StringInterpNode(:final parts):
      final buf = StringBuffer();
      for (final p in parts) {
        if (p is String) {
          buf.write(p);
        } else if (p is IrNode) {
          buf.write(evalExpression(p, input) ?? '');
        }
      }
      return buf.toString();

    default:
      throw StateError('evalExpression: unsupported node $node');
  }
}
