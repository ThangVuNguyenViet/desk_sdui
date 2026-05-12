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

  if (expr is MethodInvocation && expr.target != null) {
    final receiver = lowerExpression(expr.target!);
    final bucket = coreTypeBucket(expr.target!.staticType);
    final methodName = expr.methodName.name;
    final qualifiedName = bucket != null ? '$bucket.$methodName' : methodName;
    final args = expr.argumentList.arguments
        .map((a) => lowerExpression(a.argumentExpression))
        .toList();
    return MethodCallNode(receiver: receiver, name: qualifiedName, args: args);
  }

  if (expr is FunctionExpression) {
    return lowerLambda(expr, inActionContext: false);
  }

  if (expr is SwitchExpression) {
    return _lowerSwitchExpression(expr);
  }

  throw LoweringError('unsupported expression: ${expr.runtimeType}', expr);
}

/// Lowers a [FunctionExpression] to a [LambdaNode]. Called from
/// [lowerExpression] (always `inActionContext: false`) and from the widget
/// lowerer when the expression appears in an argument position.
LambdaNode lowerLambda(FunctionExpression expr, {bool inActionContext = false}) {
  // 1. Extract params — only simple positional params allowed.
  final rawParams = expr.parameters?.parameters ?? <FormalParameter>[];
  final params = <String>[];
  for (final p in rawParams) {
    if (p is! RegularFormalParameter) {
      throw LoweringError(
        'LambdaNode: only simple positional parameters are supported '
        '(no defaults, no named, no optional). Got ${p.runtimeType}.',
        p,
      );
    }
    params.add(p.name!.lexeme);
  }

  // 2. Determine if async.
  final body = expr.body;
  final isAsync = body.isAsynchronous;

  // 3. Reject async lambdas outside action context.
  if (isAsync && !inActionContext) {
    throw LoweringError(
      'Async lambdas are only allowed inside async event handlers '
      '(ActionSequenceNode bodies). This lambda is being constructed in a '
      'per-frame path.',
      expr,
    );
  }

  // 4. Lower body.
  final IrNode loweredBody;
  if (body is ExpressionFunctionBody) {
    // Reject await in sync context (already guarded by isAsync above, but
    // also catch `await` in a sync body).
    if (!isAsync && _containsAwait(body.expression)) {
      throw LoweringError(
        'AwaitExpression inside a sync LambdaNode body is not supported.',
        expr,
      );
    }
    loweredBody = lowerExpression(body.expression);
  } else if (body is BlockFunctionBody) {
    final stmts = body.block.statements;
    if (stmts.length == 1 && stmts.first is ReturnStatement) {
      final ret = stmts.first as ReturnStatement;
      if (ret.expression == null) {
        throw LoweringError(
          'LambdaNode bodies must be a single expression (or a block with a '
          'single return). Use ActionSequenceNode for async sequences.',
          expr,
        );
      }
      loweredBody = lowerExpression(ret.expression!);
    } else {
      throw LoweringError(
        'LambdaNode bodies must be a single expression (or a block with a '
        'single return). Use ActionSequenceNode for async sequences.',
        expr,
      );
    }
  } else {
    throw LoweringError(
      'LambdaNode: unsupported body shape ${body.runtimeType}.',
      expr,
    );
  }

  return LambdaNode(params: params, body: loweredBody, isAsync: isAsync);
}

bool _containsAwait(Expression expr) {
  if (expr is AwaitExpression) return true;
  // Simple recursive check for common nested shapes.
  return false;
}

// ---------------------------------------------------------------------------
// Switch expression lowering
// ---------------------------------------------------------------------------

var _switchCounter = 0;

IrNode _lowerSwitchExpression(SwitchExpression expr) {
  final scrutName = '__scrut${_switchCounter++}__';
  final scrut = lowerExpression(expr.expression);

  // Find the default (wildcard) case if present.
  IrNode? defaultBranch;
  final nonDefaultCases = <SwitchExpressionCase>[];
  for (final c in expr.cases) {
    final p = c.guardedPattern.pattern;
    if (_isWildcardOrDefault(p)) {
      defaultBranch = lowerExpression(c.expression);
    } else {
      nonDefaultCases.add(c);
    }
  }

  if (defaultBranch == null) {
    throw LoweringError(
      'Non-exhaustive switch expression in @Screen body: '
      'a wildcard arm `_ => ...` is required.',
      expr,
    );
  }

  // Right-fold the non-default cases into ConditionalNodes.
  final scrutRef = RefNode([scrutName]);
  IrNode acc = defaultBranch;
  for (final c in nonDefaultCases.reversed) {
    final p = c.guardedPattern.pattern;
    final test = _lowerCaseTest(p, scrutRef, expr);
    final body = _lowerCaseBody(p, scrutRef, lowerExpression(c.expression), expr);
    acc = ConditionalNode(
      condition: test,
      thenBranch: body,
      elseBranch: acc,
    );
  }

  return LetNode(name: scrutName, value: scrut, body: acc);
}

bool _isWildcardOrDefault(DartPattern p) {
  if (p is WildcardPattern) return true;
  // A ConstantPattern with null literal is NOT wildcard.
  return false;
}

IrNode _lowerCaseTest(DartPattern p, IrNode scrutRef, AstNode origin) {
  if (p is ConstantPattern) {
    return CompareOpNode(
      op: CompareOp.eq,
      left: scrutRef,
      right: lowerExpression(p.expression),
    );
  }
  if (p is ObjectPattern) {
    final typeName = p.type.name.lexeme;
    return IsTypeNode(receiver: scrutRef, typeName: typeName);
  }
  throw LoweringError(
    'Unsupported pattern type in switch expression: ${p.runtimeType}. '
    'Supported: ConstantPattern, ObjectPattern, WildcardPattern.',
    origin,
  );
}

IrNode _lowerCaseBody(
    DartPattern p, IrNode scrutRef, IrNode body, AstNode origin) {
  if (p is ObjectPattern && p.fields.isNotEmpty) {
    // Wrap each field binding in a LetNode around the body.
    var wrapped = body;
    for (final field in p.fields.reversed) {
      final getter = field.effectiveName;
      if (getter == null) {
        throw LoweringError(
          'PatternField in ObjectPattern has no effective name. '
          'Only shorthand `:final name` bindings are supported.',
          origin,
        );
      }
      // The variable name bound in this scope — same as the field name
      // for shorthand patterns like `:final data`.
      final bindName = _patternFieldVariableName(field) ?? getter;
      wrapped = LetNode(
        name: bindName,
        value: MemberAccessNode(target: scrutRef, name: getter),
        body: wrapped,
      );
    }
    return wrapped;
  }
  return body;
}

/// Returns the variable name declared by a pattern field's sub-pattern,
/// or null if the sub-pattern doesn't declare a variable.
String? _patternFieldVariableName(PatternField field) {
  final p = field.pattern;
  if (p is VariablePattern) return p.name.lexeme;
  // Wildcard sub-pattern or other: no binding.
  return null;
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
