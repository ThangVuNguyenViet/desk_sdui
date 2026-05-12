import 'package:analyzer/dart/ast/ast.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import '../diagnostics.dart';
import 'widget_lowerer.dart';
import 'expression_lowerer.dart';

class ScreenLowerResult {
  ScreenLowerResult({
    required this.name,
    required this.root,
    required this.params,
    required this.reactiveParams,
    required this.methodRefs,
    required this.widgetRefs,
    required this.fnRefs,
  });

  final String name;
  final IrNode root;
  final List<({String name, String type})> params;
  final List<String> reactiveParams;

  /// Method references indexed by input name.
  /// e.g. `{'vm': ['increment', 'decrement']}`
  final Map<String, List<String>> methodRefs;
  final Set<String> widgetRefs;
  final Set<String> fnRefs;

  ScreenLowerResult copyWith({IrNode? root}) {
    return ScreenLowerResult(
      name: name,
      root: root ?? this.root,
      params: params,
      reactiveParams: reactiveParams,
      methodRefs: methodRefs,
      widgetRefs: widgetRefs,
      fnRefs: fnRefs,
    );
  }
}

class ScreenAnnotationData {
  ScreenAnnotationData({required this.name});
  final String name;
}

ScreenLowerResult lowerScreen(FunctionDeclaration fn, ScreenAnnotationData ann) {
  final body = fn.functionExpression.body;
  final IrNode rootIr;
  if (body is ExpressionFunctionBody) {
    rootIr = _lowerExpression(body.expression);
  } else if (body is BlockFunctionBody) {
    rootIr = _lowerBlockBody(body, fn);
  } else {
    throw LoweringError(
      '@Screen body must be a single return statement or expression body; '
      'got ${body.runtimeType}',
      fn,
    );
  }

  final params = <({String name, String type})>[];
  for (final p in fn.functionExpression.parameters!.parameters) {
    final paramName = p.name!.lexeme;
    final paramType = 'dynamic';
    params.add((name: paramName, type: paramType));
  }

  final reactiveParams = <String>[];
  final widgetRefs = <String>{};
  final methodRefs = <String, List<String>>{};
  final fnRefs = <String>{};

  _collectRefs(rootIr, widgetRefs, methodRefs, fnRefs);

  return ScreenLowerResult(
    name: ann.name,
    root: rootIr,
    params: params,
    reactiveParams: reactiveParams,
    methodRefs: methodRefs,
    widgetRefs: widgetRefs,
    fnRefs: fnRefs,
  );
}

IrNode _lowerExpression(Expression expr) => lowerExpressionOrWidget(expr);

/// Dispatches an [Expression] to either the widget lowerer (for widget
/// constructors and capitalized factory invocations) or the regular
/// expression lowerer. Exposed so that lowerers in other files (e.g. the
/// switch-expression lowerer in `expression_lowerer.dart`) can lower bodies
/// that may contain widgets.
IrNode lowerExpressionOrWidget(Expression expr) {
  if (expr is InstanceCreationExpression) {
    return lowerWidgetInstance(expr);
  } else if (expr is MethodInvocation && expr.target == null) {
    final name = expr.methodName.name;
    if (name.isNotEmpty && name[0] == name[0].toUpperCase()) {
      return lowerWidgetInvocation(expr);
    } else {
      return lowerExpression(expr);
    }
  } else {
    return lowerExpression(expr);
  }
}

IrNode _lowerBlockBody(BlockFunctionBody body, FunctionDeclaration fn) {
  final stmts = body.block.statements;
  if (stmts.isEmpty) {
    throw LoweringError(
      '@Screen body must end with a return statement.',
      fn,
    );
  }
  final returnStmt = stmts.last;
  if (returnStmt is! ReturnStatement || returnStmt.expression == null) {
    throw LoweringError(
      '@Screen body must end with a return statement.',
      fn,
    );
  }
  IrNode acc = _lowerExpression(returnStmt.expression!);
  for (final stmt in stmts.take(stmts.length - 1).toList().reversed) {
    if (stmt is! VariableDeclarationStatement) {
      throw LoweringError(
        '@Screen body may only contain final locals before the return.',
        fn,
      );
    }
    final decl = stmt.variables;
    if (!decl.isFinal) {
      throw LoweringError(
        "@Screen locals must be 'final' (single-assignment). "
        'Use a registered VM method for mutable state.',
        fn,
      );
    }
    if (decl.variables.length != 1) {
      throw LoweringError(
        '@Screen locals: declare one variable per statement.',
        fn,
      );
    }
    final v = decl.variables.single;
    if (v.initializer == null) {
      throw LoweringError(
        '@Screen locals must have an initializer.',
        fn,
      );
    }
    acc = LetNode(
      name: v.name.lexeme,
      value: lowerExpression(v.initializer!),
      body: acc,
    );
  }
  return acc;
}

void _collectRefs(
  IrNode node,
  Set<String> widgetRefs,
  Map<String, List<String>> methodRefs,
  Set<String> fnRefs,
) {
  switch (node) {
    case WidgetNode():
      widgetRefs.add(node.name);
      for (final child in node.args.values) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
      if (node.key != null) {
        _collectRefs(node.key!, widgetRefs, methodRefs, fnRefs);
      }
    case BuiltinWidgetNode():
      for (final child in node.args.values) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
      if (node.key != null) {
        _collectRefs(node.key!, widgetRefs, methodRefs, fnRefs);
      }
    case ListNode():
      for (final child in node.children) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
    case MapNode():
      for (final entry in node.entries.entries) {
        _collectRefs(entry.key, widgetRefs, methodRefs, fnRefs);
        _collectRefs(entry.value, widgetRefs, methodRefs, fnRefs);
      }
    case RecordNode():
      for (final child in node.positional) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
      for (final child in node.named.values) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
    case ConditionalNode():
      _collectRefs(node.condition, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.thenBranch, widgetRefs, methodRefs, fnRefs);
      if (node.elseBranch != null) {
        _collectRefs(node.elseBranch!, widgetRefs, methodRefs, fnRefs);
      }
    case ForNode():
      _collectRefs(node.source, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.body, widgetRefs, methodRefs, fnRefs);
    case SpreadNode():
      _collectRefs(node.source, widgetRefs, methodRefs, fnRefs);
    case EventNode():
      if (node.target.length >= 2) {
        final inputName = node.target.first;
        final methodName = node.target.last;
        methodRefs.putIfAbsent(inputName, () => []);
        if (!methodRefs[inputName]!.contains(methodName)) {
          methodRefs[inputName]!.add(methodName);
        }
      }
      for (final arg in node.args.values) {
        _collectRefs(arg, widgetRefs, methodRefs, fnRefs);
      }
    case CompareOpNode():
      _collectRefs(node.left, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.right, widgetRefs, methodRefs, fnRefs);
    case ArithOpNode():
      _collectRefs(node.left, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.right, widgetRefs, methodRefs, fnRefs);
    case LogicOpNode():
      _collectRefs(node.left, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.right, widgetRefs, methodRefs, fnRefs);
    case NotOpNode():
      _collectRefs(node.operand, widgetRefs, methodRefs, fnRefs);
    case CoalesceOpNode():
      _collectRefs(node.left, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.right, widgetRefs, methodRefs, fnRefs);
    case GetterNode():
      _collectRefs(node.receiver, widgetRefs, methodRefs, fnRefs);
    case LetNode():
      _collectRefs(node.value, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.body, widgetRefs, methodRefs, fnRefs);
    case AssignNode():
      _collectRefs(node.value, widgetRefs, methodRefs, fnRefs);
    case LambdaNode():
      _collectRefs(node.body, widgetRefs, methodRefs, fnRefs);
    case MemberAccessNode():
      _collectRefs(node.target, widgetRefs, methodRefs, fnRefs);
    case IndexAccessNode():
      _collectRefs(node.target, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.key, widgetRefs, methodRefs, fnRefs);
    case LengthOfNode():
      _collectRefs(node.target, widgetRefs, methodRefs, fnRefs);
    case IsNullCheckNode():
      _collectRefs(node.operand, widgetRefs, methodRefs, fnRefs);
    case IsTypeNode():
      _collectRefs(node.receiver, widgetRefs, methodRefs, fnRefs);
    case StringInterpNode():
      for (final part in node.parts) {
        if (part is IrNode) {
          _collectRefs(part, widgetRefs, methodRefs, fnRefs);
        }
      }
    case MethodCallNode():
      if (node.receiver != null) {
        _collectRefs(node.receiver!, widgetRefs, methodRefs, fnRefs);
      }
      for (final arg in node.args) {
        _collectRefs(arg, widgetRefs, methodRefs, fnRefs);
      }
    case ValueCtorNode():
      for (final arg in node.args) {
        _collectRefs(arg, widgetRefs, methodRefs, fnRefs);
      }
    case SequenceNode():
      for (final step in node.steps) {
        _collectRefs(step, widgetRefs, methodRefs, fnRefs);
      }
      _collectRefs(node.returnExpr, widgetRefs, methodRefs, fnRefs);
    case LiteralNode():
    case ConstNode():
    case RefNode():
      break;
    case ActionSequenceNode():
      for (final step in node.steps) {
        _collectRefs(step, widgetRefs, methodRefs, fnRefs);
      }
    case ActionStepNode():
      _collectRefs(node.call, widgetRefs, methodRefs, fnRefs);
    case TryStepNode():
      for (final s in node.trySteps) {
        _collectRefs(s.call, widgetRefs, methodRefs, fnRefs);
      }
      for (final s in node.catchSteps) {
        _collectRefs(s.call, widgetRefs, methodRefs, fnRefs);
      }
  }
}
