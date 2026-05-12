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

  // Detect whether this is a "simple" body (old path: (VarDecl)* ExprStmt*
  // ReturnStmt) or a "block" body that requires the new BlockNode path. The
  // new path is taken whenever any statement is NOT a VarDecl / ExprStmt /
  // ReturnStmt (e.g. IfStatement, nested Block, BreakStatement, etc.).
  final hasComplexStatement = stmts.any(
    (s) =>
        s is! VariableDeclarationStatement &&
        s is! ExpressionStatement &&
        s is! ReturnStatement,
  );

  if (hasComplexStatement) {
    // New block-body path: lower all statements to a BlockNode.
    return _lowerGeneralBlock(stmts);
  }

  // Legacy simple path: (VarDecl)* ExpressionStatement* ReturnStatement.
  // Kept for backward compatibility with existing screens. New screens
  // that only have var decls + assignments + return will still use this path.
  final returnStmt = stmts.last;
  if (returnStmt is! ReturnStatement || returnStmt.expression == null) {
    throw LoweringError(
      '@Screen body must end with a return statement.',
      fn,
    );
  }
  // First pass — collect binding kinds for every declared local.
  final bindings = <String, BindingKind>{};
  for (final stmt in stmts.take(stmts.length - 1)) {
    if (stmt is VariableDeclarationStatement) {
      final decl = stmt.variables;
      for (final v in decl.variables) {
        final name = v.name.lexeme;
        if (name.startsWith('__')) {
          throw LoweringError(
            'Local name "$name" is reserved: names beginning with "__" are '
            'used internally by the lowerer. Pick a different name.',
            v,
          );
        }
        bindings[name] =
            decl.isFinal ? BindingKind.finalBinding : BindingKind.varBinding;
      }
    }
  }

  pushScope(bindings);
  try {
    IrNode acc = _lowerExpression(returnStmt.expression!);
    for (final stmt in stmts.take(stmts.length - 1).toList().reversed) {
      if (stmt is VariableDeclarationStatement) {
        final decl = stmt.variables;
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
        continue;
      }
      if (stmt is ExpressionStatement) {
        final lowered = lowerExpression(stmt.expression);
        acc = LetNode(name: '__stmt__', value: lowered, body: acc);
        continue;
      }
      throw LoweringError(
        '@Screen body: only local declarations and assignment statements '
        'are supported before the return. Got ${stmt.runtimeType}.',
        fn,
      );
    }
    return acc;
  } finally {
    popScope();
  }
}

/// Lowers a general block statement list (containing if/else, nested blocks,
/// etc.) to a [BlockNode]. All variable declarations in the block are
/// collected first (for scope tracking) then each statement is lowered.
IrNode _lowerGeneralBlock(List<Statement> stmts) {
  // Collect top-level variable declarations in this block for scope tracking.
  final bindings = <String, BindingKind>{};
  for (final stmt in stmts) {
    if (stmt is VariableDeclarationStatement) {
      final decl = stmt.variables;
      for (final v in decl.variables) {
        final name = v.name.lexeme;
        if (name.startsWith('__')) {
          throw LoweringError(
            'Local name "$name" is reserved: names beginning with "__" are '
            'used internally by the lowerer. Pick a different name.',
            v,
          );
        }
        bindings[name] =
            decl.isFinal ? BindingKind.finalBinding : BindingKind.varBinding;
      }
    }
  }

  pushScope(bindings);
  try {
    final lowered = stmts.map(lowerStatement).toList();
    return BlockNode(statements: lowered);
  } finally {
    popScope();
  }
}

/// Lowers a single [Statement] to an [IrNode].
IrNode lowerStatement(Statement stmt) {
  if (stmt is ReturnStatement) {
    return ReturnNode(
      value: stmt.expression == null ? null : _lowerExpression(stmt.expression!),
    );
  }
  if (stmt is BreakStatement) {
    if (stmt.label != null) {
      throw LoweringError('Labeled break is not supported.', stmt);
    }
    return const BreakNode();
  }
  if (stmt is ContinueStatement) {
    if (stmt.label != null) {
      throw LoweringError('Labeled continue is not supported.', stmt);
    }
    return const ContinueNode();
  }
  if (stmt is IfStatement) {
    return IfStatementNode(
      cond: _lowerExpression(stmt.expression),
      then: lowerStatement(stmt.thenStatement),
      else_: stmt.elseStatement == null
          ? null
          : lowerStatement(stmt.elseStatement!),
    );
  }
  if (stmt is Block) {
    return _lowerGeneralBlock(stmt.statements);
  }
  if (stmt is VariableDeclarationStatement) {
    return _lowerVarDeclStatement(stmt);
  }
  if (stmt is ExpressionStatement) {
    return _lowerExpression(stmt.expression);
  }
  if (stmt is LabeledStatement) {
    final labelName = stmt.labels.isNotEmpty
        ? stmt.labels.first.name.lexeme
        : '<unknown>';
    throw LoweringError(
      'Labeled statements are not supported in @Screen bodies. '
      'Remove the label "$labelName".',
      stmt,
    );
  }
  throw LoweringError(
    'Unsupported statement: ${stmt.runtimeType}',
    stmt,
  );
}

/// Lowers a [VariableDeclarationStatement] to a [LetStatementNode].
IrNode _lowerVarDeclStatement(VariableDeclarationStatement stmt) {
  final decl = stmt.variables;
  if (decl.variables.length != 1) {
    throw LoweringError(
      '@Screen locals: declare one variable per statement.',
      stmt,
    );
  }
  final v = decl.variables.single;
  if (v.initializer == null) {
    throw LoweringError(
      '@Screen locals must have an initializer.',
      stmt,
    );
  }
  return LetStatementNode(
    name: v.name.lexeme,
    value: lowerExpression(v.initializer!),
    isFinal: decl.isFinal,
  );
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
    case BlockNode():
      for (final s in node.statements) {
        _collectRefs(s, widgetRefs, methodRefs, fnRefs);
      }
    case IfStatementNode():
      _collectRefs(node.cond, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.then, widgetRefs, methodRefs, fnRefs);
      if (node.else_ != null) {
        _collectRefs(node.else_!, widgetRefs, methodRefs, fnRefs);
      }
    case BreakNode():
    case ContinueNode():
      break;
    case ReturnNode():
      if (node.value != null) {
        _collectRefs(node.value!, widgetRefs, methodRefs, fnRefs);
      }
    case LetStatementNode():
      _collectRefs(node.value, widgetRefs, methodRefs, fnRefs);
  }
}
