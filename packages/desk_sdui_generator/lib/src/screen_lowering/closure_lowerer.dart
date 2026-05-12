import 'package:analyzer/dart/ast/ast.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import '../diagnostics.dart';
import 'expression_lowerer.dart';

/// Lowers a closure/tear-off expression to an EventNode.
/// Rejects anything outside the whitelist with a LoweringError.
IrNode lowerClosure(Expression expr) {
  if (expr is PrefixedIdentifier) {
    return EventNode([expr.prefix.name, expr.identifier.name]);
  }
  if (expr is PropertyAccess && expr.target is SimpleIdentifier) {
    return EventNode([
      (expr.target as SimpleIdentifier).name,
      expr.propertyName.name,
    ]);
  }

  if (expr is FunctionExpression) {
    final body = expr.body;

    // Async block body: `() async { ... }` → ActionSequenceNode
    if (body is BlockFunctionBody && body.isAsynchronous) {
      return _lowerActionSequence(body.block, expr);
    }

    if (body is! ExpressionFunctionBody) {
      throw LoweringError(
        'closure must be expression-bodied (`() => x`, not `() { return x; }`)',
        expr,
      );
    }
    final inner = body.expression;
    if (inner is MethodInvocation) {
      final target = _extractTarget(inner);
      if (target == null) {
        throw LoweringError(
          'closure body must call a method like `controller.foo(...)`',
          inner,
        );
      }
      final args = <String, IrNode>{};
      final params = expr.parameters?.parameters ?? <FormalParameter>[];
      for (var i = 0; i < inner.argumentList.arguments.length; i++) {
        final a = inner.argumentList.arguments[i].argumentExpression;
        args['arg$i'] = _lowerCallArg(a, params, expr);
      }
      return EventNode(target, args: args.isEmpty ? const {} : args);
    }
    throw LoweringError(
      'closure body must be a single method call; extract more complex logic to a ViewModel method',
      inner,
    );
  }

  if (expr is MethodInvocation) {
    final target = _extractTarget(expr);
    if (target != null) {
      final args = <String, IrNode>{};
      for (var i = 0; i < expr.argumentList.arguments.length; i++) {
        args['arg$i'] =
            lowerExpression(expr.argumentList.arguments[i].argumentExpression);
      }
      return EventNode(target, args: args.isEmpty ? const {} : args);
    }
  }

  throw LoweringError('unsupported closure shape', expr);
}

List<String>? _extractTarget(MethodInvocation call) {
  final target = call.target;
  if (target is SimpleIdentifier) {
    return [target.name, call.methodName.name];
  }
  if (target is PrefixedIdentifier) {
    return [target.prefix.name, target.identifier.name, call.methodName.name];
  }
  return null;
}

/// Whether the lowerer is currently descending into an ActionSequenceNode's
/// step calls. Set to true inside [_lowerActionSequence].
/// TODO(LambdaNode): gate async-bearing lambdas on this flag.
bool inActionContext = false;

ActionSequenceNode _lowerActionSequence(Block block, AstNode origin) {
  final steps = <ActionStepNode>[];
  final prev = inActionContext;
  inActionContext = true;
  try {
    for (final stmt in block.statements) {
      steps.add(_lowerStep(stmt));
    }
  } finally {
    inActionContext = prev;
  }
  return ActionSequenceNode(steps: steps);
}

ActionStepNode _lowerStep(Statement stmt) {
  // `final x = await call();` — bind result
  if (stmt is VariableDeclarationStatement) {
    final decls = stmt.variables.variables;
    final keyword = stmt.variables.keyword?.lexeme;
    if (decls.length != 1 || keyword != 'final') {
      throw LoweringError(
        'Async event handler bodies must be a sequence of (optionally-awaited) calls, optionally binding the result to a final local. Got: ${stmt.runtimeType}',
        stmt,
      );
    }
    final decl = decls.single;
    final init = decl.initializer;
    if (init is! AwaitExpression) {
      throw LoweringError(
        'Async event handler bodies must be a sequence of (optionally-awaited) calls, optionally binding the result to a final local. Got: ${stmt.runtimeType}',
        stmt,
      );
    }
    final call = init.expression;
    return ActionStepNode(
      call: _lowerCallExpression(call, stmt),
      awaitResult: true,
      bindResult: decl.name.lexeme,
    );
  }

  // `await call();` or `call();`
  if (stmt is ExpressionStatement) {
    final expr = stmt.expression;
    if (expr is AwaitExpression) {
      return ActionStepNode(
        call: _lowerCallExpression(expr.expression, stmt),
        awaitResult: true,
      );
    }
    return ActionStepNode(
      call: _lowerCallExpression(expr, stmt),
      awaitResult: false,
    );
  }

  throw LoweringError(
    'Async event handler bodies must be a sequence of (optionally-awaited) calls, optionally binding the result to a final local. Got: ${stmt.runtimeType}',
    stmt,
  );
}

IrNode _lowerCallExpression(Expression expr, AstNode origin) {
  if (expr is MethodInvocation) {
    final target = _extractTarget(expr);
    if (target != null) {
      final args = <IrNode>[];
      for (final arg in expr.argumentList.arguments) {
        args.add(lowerExpression(arg.argumentExpression));
      }
      return MethodCallNode(
        receiver: target.length >= 2
            ? RefNode(target.sublist(0, target.length - 1))
            : null,
        name: target.last,
        args: args,
      );
    }
  }
  // fallback: try general expression lowering
  try {
    return lowerExpression(expr);
  } catch (_) {
    throw LoweringError(
      'Async event handler step must be a method call. Got: ${expr.runtimeType}',
      expr,
    );
  }
}

IrNode _lowerCallArg(
  Expression arg,
  List<FormalParameter> params,
  FunctionExpression closure,
) {
  if (arg is SimpleIdentifier) {
    final paramIndex = params.indexWhere((p) => p.name?.lexeme == arg.name);
    if (paramIndex >= 0 && arg.name != '_') {
      return RefNode(['_callback_arg_$paramIndex']);
    }
    return lowerExpression(arg);
  }
  if (arg is IntegerLiteral || arg is StringLiteral || arg is BooleanLiteral) {
    return lowerExpression(arg);
  }
  if (arg is PrefixedIdentifier || arg is PropertyAccess) {
    return lowerExpression(arg);
  }
  throw LoweringError(
    'unsupported closure arg shape — extract `${arg.toSource()}` to a top-level fn or controller method',
    arg,
  );
}
