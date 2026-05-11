import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import '../diagnostics.dart';

IrNode lowerExpression(Expression expr) {
  if (expr is ParenthesizedExpression) {
    return lowerExpression(expr.expression);
  }

  if (expr is IntegerLiteral) return LiteralNode(expr.value);
  if (expr is DoubleLiteral) return LiteralNode(expr.value);
  if (expr is BooleanLiteral) return LiteralNode(expr.value);
  if (expr is NullLiteral) return const LiteralNode(null);
  if (expr is SimpleStringLiteral) return LiteralNode(expr.value);

  if (expr is StringInterpolation) {
    final parts = <Object>[];
    for (final element in expr.elements) {
      if (element is InterpolationString) {
        if (element.value.isNotEmpty) parts.add(element.value);
      } else if (element is InterpolationExpression) {
        parts.add(lowerExpression(element.expression));
      }
    }
    return StringInterpNode(parts);
  }

  if (expr is SimpleIdentifier && expr.name == '_') {
    return const LiteralNode(null);
  }

  if (expr is SimpleIdentifier) {
    return RefNode([expr.name]);
  }

  if (expr is PrefixedIdentifier) {
    if (expr.identifier.name == 'length') {
      return LengthOfNode(lowerExpression(expr.prefix));
    }
    final target = lowerExpression(expr.prefix);
    final bucket = coreTypeBucket(expr.prefix.staticType);
    if (target is RefNode && bucket == null) {
      return RefNode([...target.path, expr.identifier.name]);
    }
    if (bucket != null) {
      return GetterNode(
        receiver: target,
        name: '$bucket.${expr.identifier.name}',
      );
    }
    return MemberAccessNode(target: target, name: expr.identifier.name);
  }

  if (expr is PropertyAccess) {
    if (expr.propertyName.name == 'length') {
      return LengthOfNode(lowerExpression(expr.target!));
    }
    final target = lowerExpression(expr.target!);
    final bucket = coreTypeBucket(expr.target!.staticType);
    if (target is RefNode && bucket == null) {
      return RefNode([...target.path, expr.propertyName.name]);
    }
    if (bucket != null) {
      return GetterNode(
        receiver: target,
        name: '$bucket.${expr.propertyName.name}',
      );
    }
    return MemberAccessNode(target: target, name: expr.propertyName.name);
  }

  if (expr is IndexExpression) {
    return IndexAccessNode(
      target: lowerExpression(expr.target!),
      key: lowerExpression(expr.index),
    );
  }

  if (expr is BinaryExpression) {
    final left = lowerExpression(expr.leftOperand);
    final right = lowerExpression(expr.rightOperand);
    switch (expr.operator.lexeme) {
      case '+':
        return ArithOpNode(op: ArithOp.add, left: left, right: right);
      case '-':
        return ArithOpNode(op: ArithOp.sub, left: left, right: right);
      case '*':
        return ArithOpNode(op: ArithOp.mul, left: left, right: right);
      case '/':
        return ArithOpNode(op: ArithOp.div, left: left, right: right);
      case '~/':
        return ArithOpNode(op: ArithOp.intDiv, left: left, right: right);
      case '%':
        return ArithOpNode(op: ArithOp.mod, left: left, right: right);
      case '==':
        if (right is LiteralNode && right.value == null) {
          return IsNullCheckNode(left);
        }
        return CompareOpNode(op: CompareOp.eq, left: left, right: right);
      case '!=':
        return CompareOpNode(op: CompareOp.neq, left: left, right: right);
      case '<':
        return CompareOpNode(op: CompareOp.lt, left: left, right: right);
      case '<=':
        return CompareOpNode(op: CompareOp.lte, left: left, right: right);
      case '>':
        return CompareOpNode(op: CompareOp.gt, left: left, right: right);
      case '>=':
        return CompareOpNode(op: CompareOp.gte, left: left, right: right);
      case '&&':
        return LogicOpNode(op: LogicOp.and, left: left, right: right);
      case '||':
        return LogicOpNode(op: LogicOp.or, left: left, right: right);
      case '??':
        return CoalesceOpNode(left: left, right: right);
    }
    throw LoweringError(
      'unsupported binary operator ${expr.operator.lexeme}',
      expr,
    );
  }

  if (expr is PrefixExpression && expr.operator.lexeme == '!') {
    return NotOpNode(lowerExpression(expr.operand));
  }

  if (expr is PrefixExpression && expr.operator.lexeme == '-') {
    return ArithOpNode(
      op: ArithOp.sub,
      left: LiteralNode(0),
      right: lowerExpression(expr.operand),
    );
  }

  if (expr is ConditionalExpression) {
    return ConditionalNode(
      condition: lowerExpression(expr.condition),
      thenBranch: lowerExpression(expr.thenExpression),
      elseBranch: lowerExpression(expr.elseExpression),
    );
  }

  if (expr is ListLiteral) {
    return ListNode(
      expr.elements.map((e) => lowerExpression(e as Expression)).toList(),
    );
  }

  throw LoweringError('unsupported expression: ${expr.runtimeType}', expr);
}

/// Returns the core-type bucket name used as the GetterNode key prefix
/// (e.g. 'String', 'Iterable', 'List', 'Map', 'num', 'int', 'double', 'bool',
/// 'DateTime', 'Duration'). Returns null when the type is not a recognized
/// core type (in that case the expression-lowerer should keep folding into
/// RefNode or emit MemberAccessNode as before).
String? coreTypeBucket(DartType? type) {
  if (type == null || type is DynamicType || type is InvalidType) return null;
  final el = type.element;
  if (el == null) return null;
  final lib = el.library?.identifier ?? '';
  if (!lib.startsWith('dart:core') && !lib.startsWith('dart:async')) return null;
  final name = el.name;
  if (name == null) return null;
  // Direct buckets. `List`/`Set` route to themselves; subtypes resolve via
  // the runtime `Iterable.*` registration at dispatch time (callers fall
  // back through DartType.allSupertypes inspection — handled below).
  const direct = {
    'String', 'List', 'Set', 'Map', 'Iterable',
    'num', 'int', 'double', 'bool', 'DateTime', 'Duration',
  };
  if (direct.contains(name)) return name;
  // Fallback: walk supertypes for Iterable<T>, Map<K,V>, num.
  if (type is InterfaceType) {
    for (final sup in type.allSupertypes) {
      final n = sup.element.name;
      if (direct.contains(n)) return n;
    }
  }
  return null;
}
