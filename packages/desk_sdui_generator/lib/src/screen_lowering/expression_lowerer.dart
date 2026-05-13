import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import '../diagnostics.dart';
import 'ast_to_ir.dart' show lowerExpressionOrWidget, lowerStatement, isPayloadFn;

// ---------------------------------------------------------------------------
// Binding-kind tracking for block bodies
// ---------------------------------------------------------------------------

enum BindingKind { finalBinding, varBinding }

/// Scope stack for the current @Screen block body. Each frame maps a variable
/// name to its [BindingKind]. Pushed by [_lowerBlockBody] in ast_to_ir.dart
/// before lowering the body, cleared afterwards.
///
/// Only one frame is active at a time (BlockNode / nested scopes are Feature 9).
final List<Map<String, BindingKind>> _scopeStack = [];

/// Push a new scope frame. Called before entering a block body.
void pushScope(Map<String, BindingKind> bindings) => _scopeStack.add(bindings);

/// Pop the innermost scope frame. Called after leaving a block body.
/// Asserts the stack is non-empty so imbalanced push/pop surfaces in dev.
void popScope() {
  assert(_scopeStack.isNotEmpty, 'popScope called with empty scope stack');
  _scopeStack.removeLast();
}

/// Look up the [BindingKind] for [name] by walking the scope stack outwards.
/// Returns null if [name] has no visible binding.
BindingKind? lookupBinding(String name) {
  for (var i = _scopeStack.length - 1; i >= 0; i--) {
    final kind = _scopeStack[i][name];
    if (kind != null) return kind;
  }
  return null;
}

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

  // Free function call with no target: check payload functions first, then
  // registered globals (MethodCallNode).
  if (expr is MethodInvocation && expr.target == null) {
    final name = expr.methodName.name;
    if (isPayloadFn(name)) {
      return PayloadFunctionCallNode(
        name: name,
        args: expr.argumentList.arguments
            .map((a) => lowerExpression(a.argumentExpression))
            .toList(),
      );
    }
    // Not a payload fn. Free-function lowering for unknown lowercase names
    // is intentionally not handled here — this lowerer is only reached for
    // expressions in non-arg positions where free function dispatch isn't a
    // supported shape. The fall-through to the LoweringError at the bottom
    // is the correct behavior. Free-function call sites that ARE allowed
    // (widget invocations like `Text(...)`, static methods like `Theme.of`)
    // are intercepted earlier in `lowerExpressionOrWidget` / `widget_lowerer`.
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

  if (expr is CascadeExpression) {
    return _lowerCascade(expr);
  }

  if (expr is AssignmentExpression) {
    return _lowerAssignment(expr);
  }

  if (expr is PostfixExpression) {
    return _lowerPostfix(expr);
  }

  if (expr is PrefixExpression &&
      (expr.operator.lexeme == '++' || expr.operator.lexeme == '--')) {
    return _lowerPrefix(expr);
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
    } else if (!isAsync) {
      // Sync block body with multiple statements (or a single non-return
      // statement). Per Plan #11 this is required to support inline event
      // handlers that mutate stateful fields, e.g.
      //   onPressed: () { count = count + 1; }
      // Lower the block to a BlockNode; the runtime evaluator dispatches a
      // BlockNode-bodied LambdaNode via executeStatement.
      final loweredStmts = stmts.map(lowerStatement).toList();
      loweredBody = BlockNode(statements: loweredStmts);
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
      defaultBranch = lowerExpressionOrWidget(c.expression);
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
    final body = _lowerCaseBody(p, scrutRef, lowerExpressionOrWidget(c.expression), expr);
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

// ---------------------------------------------------------------------------
// Cascade expression lowering
// ---------------------------------------------------------------------------

var _cascadeCounter = 0;

IrNode _lowerCascade(CascadeExpression expr) {
  // Reject null-aware cascade (?..): not supported.
  if (expr.isNullAware) {
    throw LoweringError(
      'Null-aware cascades (?..a()) are not supported in @Screen bodies. '
      'Use a non-null receiver or guard with an if expression.',
      expr,
    );
  }

  final receiver = lowerExpression(expr.target);
  final casName = '__cas${_cascadeCounter++}__';
  final ref = RefNode([casName]);

  final steps = <IrNode>[];
  for (final section in expr.cascadeSections) {
    steps.add(_lowerCascadeSection(section, ref, expr));
  }

  return LetNode(
    name: casName,
    value: receiver,
    body: SequenceNode(steps: steps, returnExpr: ref),
  );
}

IrNode _lowerCascadeSection(Expression section, RefNode receiver, AstNode origin) {
  if (section is MethodInvocation) {
    // section.target is null for cascade sections (the cascade target is implicit).
    final methodName = section.methodName.name;
    final args = section.argumentList.arguments
        .map((a) => lowerExpression(a.argumentExpression))
        .toList();
    return MethodCallNode(
      receiver: receiver,
      name: methodName,
      args: args,
    );
  }
  if (section is AssignmentExpression) {
    final lhs = section.leftHandSide;
    if (lhs is PropertyAccess && lhs.isCascaded) {
      final setterName = lhs.propertyName.name;
      // Lower as MethodCallNode named '<setter>=' (Dart setter dispatch convention).
      return MethodCallNode(
        receiver: receiver,
        name: '$setterName=',
        args: [lowerExpression(section.rightHandSide)],
      );
    }
    throw LoweringError(
      'Unsupported cascade section: ${section.runtimeType}. '
      'Only method invocations (..a()) and simple setter assignments (..foo = x) are supported.',
      origin,
    );
  }
  throw LoweringError(
    'Unsupported cascade section: ${section.runtimeType}. '
    'Only method invocations (..a()) and setter assignments (..foo = x) are supported.',
    origin,
  );
}

// ---------------------------------------------------------------------------
// Assignment expression lowering
// ---------------------------------------------------------------------------

IrNode _lowerAssignment(AssignmentExpression expr) {
  final lhs = expr.leftHandSide;
  final op = expr.operator.lexeme;

  // --- simple-identifier assignment: local variable assignment ---
  if (lhs is SimpleIdentifier) {
    final name = lhs.name;

    // --- compound assignments: x += e  →  AssignNode(x, ArithOpNode(+, x, e)) ---
    if (op != '=') {
      final ref = RefNode([name]);
      final rhs = lowerExpression(expr.rightHandSide);

      IrNode compoundValue;
      switch (op) {
        case '+=':
          compoundValue = ArithOpNode(op: ArithOp.add, left: ref, right: rhs);
        case '-=':
          compoundValue = ArithOpNode(op: ArithOp.sub, left: ref, right: rhs);
        case '*=':
          compoundValue = ArithOpNode(op: ArithOp.mul, left: ref, right: rhs);
        case '/=':
          compoundValue = ArithOpNode(op: ArithOp.div, left: ref, right: rhs);
        case '~/=':
          compoundValue = ArithOpNode(op: ArithOp.intDiv, left: ref, right: rhs);
        case '%=':
          compoundValue = ArithOpNode(op: ArithOp.mod, left: ref, right: rhs);
        default:
          throw LoweringError(
            'Unsupported compound assignment operator "$op". '
            'Supported: =, +=, -=, *=, /=, ~/=, %=.',
            expr,
          );
      }
      return _buildAssignNode(name, compoundValue, expr);
    }

    // --- simple assignment: x = e ---
    return _buildAssignNode(name, lowerExpression(expr.rightHandSide), expr);
  }

  // --- property-access assignment: vm.count = 0, vm.name = 'a' ---
  if (op != '=') {
    // Compound assignments on fields: vm.count += 5
    final receiverType = lhs is PrefixedIdentifier
        ? lhs.prefix.staticType
        : lhs is PropertyAccess
            ? lhs.target?.staticType
            : null;
    final typeBucket = coreTypeBucket(receiverType);
    if (typeBucket != null) {
      throw LoweringError(
        'Compound assignment on core types (${receiverType?.getDisplayString()}) '
        'is not supported.',
        expr,
      );
    }
    final className = _classNameForType(receiverType);
    if (className == null) {
      throw LoweringError(
        'Compound assignment to ${lhs.toSource()}: receiver type '
        '${receiverType?.getDisplayString(withNullability: false)} is '
        'not a registered class. Register the owner type with @Register or '
        'use a registered setter method.',
        expr,
      );
    }

    final fieldName = lhs is PrefixedIdentifier
        ? lhs.identifier.name
        : lhs is PropertyAccess
            ? lhs.propertyName.name
            : '';
    final receiverExpr =
        lhs is PrefixedIdentifier ? lhs.prefix : (lhs as PropertyAccess).target!;
    // Lower the receiver exactly once and share the same IrNode between the
    // GetterNode (read-back of the current value) and the SetterCallNode
    // target. Lowering twice would be structurally wrong: any receiver
    // expression with side effects would be evaluated twice at runtime.
    final loweredReceiver = lowerExpression(receiverExpr);
    final rhs = lowerExpression(expr.rightHandSide);
    final currentValue = GetterNode(
      receiver: loweredReceiver,
      name: '$className.$fieldName',
    );

    IrNode compoundValue;
    switch (op) {
      case '+=':
        compoundValue = ArithOpNode(op: ArithOp.add, left: currentValue, right: rhs);
      case '-=':
        compoundValue = ArithOpNode(op: ArithOp.sub, left: currentValue, right: rhs);
      case '*=':
        compoundValue =
            ArithOpNode(op: ArithOp.mul, left: currentValue, right: rhs);
      case '/=':
        compoundValue =
            ArithOpNode(op: ArithOp.div, left: currentValue, right: rhs);
      case '~/=':
        compoundValue =
            ArithOpNode(op: ArithOp.intDiv, left: currentValue, right: rhs);
      case '%=':
        compoundValue =
            ArithOpNode(op: ArithOp.mod, left: currentValue, right: rhs);
      default:
        throw LoweringError(
          'Unsupported compound assignment operator "$op". '
          'Supported: =, +=, -=, *=, /=, ~/=, %=.',
          expr,
        );
    }

    return SetterCallNode(
      target: loweredReceiver,
      setterKey: '$className.$fieldName',
      value: compoundValue,
    );
  }

  // Simple assignment on property: vm.count = 0
  if (lhs is PrefixedIdentifier) {
    return _lowerSetterAssignment(
      receiverExpr: lhs.prefix,
      fieldName: lhs.identifier.name,
      value: expr.rightHandSide,
    );
  }
  if (lhs is PropertyAccess && lhs.target != null) {
    return _lowerSetterAssignment(
      receiverExpr: lhs.target!,
      fieldName: lhs.propertyName.name,
      value: expr.rightHandSide,
    );
  }

  // Cascade-style setters (..text = 'x') route through Cascades (Feature 7).
  throw LoweringError(
    'Unsupported assignment target: ${lhs.runtimeType}',
    expr,
  );
}

/// Lower a property-access setter assignment (vm.count = 0).
///
/// Returns a [SetterCallNode] that will be dispatched through the runtime's
/// setter registry at evaluation time.
SetterCallNode _lowerSetterAssignment({
  required Expression receiverExpr,
  required String fieldName,
  required Expression value,
}) {
  final receiverType = receiverExpr.staticType;
  final typeBucket = coreTypeBucket(receiverType);
  if (typeBucket != null) {
    throw LoweringError(
      'Assignment to ${receiverExpr.toSource()}.$fieldName: receiver type '
      '${receiverType?.getDisplayString(withNullability: false)} is a core '
      'type. Core types do not support field assignment.',
      receiverExpr,
    );
  }
  final className = _classNameForType(receiverType);
  if (className == null) {
    throw LoweringError(
      'Assignment to ${receiverExpr.toSource()}.$fieldName: receiver type '
      '${receiverType?.getDisplayString(withNullability: false)} is not a '
      'registered class. Register the owner type with @Register or use a '
      'registered setter method.',
      receiverExpr,
    );
  }
  return SetterCallNode(
    target: lowerExpression(receiverExpr),
    setterKey: '$className.$fieldName',
    value: lowerExpression(value),
  );
}

/// Map a DartType to its registered class name, or null if not registered.
///
/// Returns the simple class name (e.g. 'Vm') if the type is a registered class,
/// or null if it's not registered, is a core type, or is null/dynamic/invalid.
String? _classNameForType(DartType? type) {
  if (type == null || type is DynamicType || type is InvalidType) return null;
  final el = type.element;
  if (el == null) return null;
  // If it's a core type, return null (core types aren't registered as setters).
  if (coreTypeBucket(type) != null) return null;
  // For user-defined types, return the simple class name.
  final name = el.name;
  if (name == null) return null;
  return name;
}

/// Validates the binding kind and constructs an [AssignNode].
IrNode _buildAssignNode(String name, IrNode value, AstNode origin) {
  final kind = lookupBinding(name);
  if (kind == null) {
    throw LoweringError(
      'Assignment to "$name": no local binding visible at this site. '
      'Was the variable declared in an outer scope that does not reach here?',
      origin,
    );
  }
  if (kind == BindingKind.finalBinding) {
    throw LoweringError(
      'Cannot assign to final local "$name". Declare it with `var` or an explicit type.',
      origin,
    );
  }
  return AssignNode(name: name, value: value);
}

// ---------------------------------------------------------------------------
// Postfix increment/decrement: x++, x--
// ---------------------------------------------------------------------------

IrNode _lowerPostfix(PostfixExpression expr) {
  final op = expr.operator.lexeme;
  if (op != '++' && op != '--') {
    throw LoweringError(
      'Unsupported postfix operator "$op".',
      expr,
    );
  }

  final operand = expr.operand;

  // Post-increment as expression (result consumed): unsupported.
  // Check if the parent is an ExpressionStatement — if not, it's expression form.
  final parent = expr.parent;
  if (parent is! ExpressionStatement) {
    throw LoweringError(
      'Pre/post increment as an expression is not supported. '
      'Use `x${op[0]}${op[0]};` as a statement, or '
      '`x = x ${op == '++' ? '+' : '-'} 1; final t = x ${op == '++' ? '-' : '+'} 1;` '
      'to capture the pre-value.',
      expr,
    );
  }

  if (operand is! SimpleIdentifier) {
    throw LoweringError(
      'Only simple-identifier operands are supported for $op (got ${operand.runtimeType}).',
      expr,
    );
  }

  final name = operand.name;
  return _buildAssignNode(
    name,
    ArithOpNode(
      op: op == '++' ? ArithOp.add : ArithOp.sub,
      left: RefNode([name]),
      right: const LiteralNode(1),
    ),
    expr,
  );
}

// ---------------------------------------------------------------------------
// Prefix increment/decrement: ++x, --x
// ---------------------------------------------------------------------------

IrNode _lowerPrefix(PrefixExpression expr) {
  final op = expr.operator.lexeme;
  final operand = expr.operand;

  // Prefix as expression (result consumed): unsupported.
  final parent = expr.parent;
  if (parent is! ExpressionStatement) {
    throw LoweringError(
      'Pre/post increment as an expression is not supported. '
      'Use `${op}x;` as a statement, or '
      '`x = x ${op == '++' ? '+' : '-'} 1; final t = x;` '
      'to capture the new value.',
      expr,
    );
  }

  if (operand is! SimpleIdentifier) {
    throw LoweringError(
      'Only simple-identifier operands are supported for $op (got ${operand.runtimeType}).',
      expr,
    );
  }

  final name = operand.name;
  return _buildAssignNode(
    name,
    ArithOpNode(
      op: op == '++' ? ArithOp.add : ArithOp.sub,
      left: RefNode([name]),
      right: const LiteralNode(1),
    ),
    expr,
  );
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
