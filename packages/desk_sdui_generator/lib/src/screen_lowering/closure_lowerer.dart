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
